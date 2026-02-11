# PL Mapping Analysis
#
# Step-by-step workflow for CCD raster scan PL data (e.g., MoSe2 flakes):
#   1. Load the raw CCD raster scan
#   2. Inspect individual spectra to identify the PL emission pixels
#   3. Compare three processing approaches (raw → pixel range → background sub)
#   4. Calculate SNR to quantify each approach
#   5. Generate a publication-quality normalized PL map
#
# This example uses the PLmap test data shipped with QPSTools.
# The data is a 51×51 spatial grid where each point has a 2000-pixel CCD spectrum.

using QPSTools
using CairoMakie
using Statistics

PROJECT_ROOT = dirname(@__DIR__)
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "pl_map")
mkpath(FIGDIR)

filepath = joinpath(PROJECT_ROOT, "data", "PLmap", "CCDtmp_260129_111138.lvm")

# ============================================================================
# STEP 1: LOAD AND INSPECT THE RAW DATA
# ============================================================================
# Load the CCD raster scan. Each of the 2601 spatial points (51×51 grid) has
# a full 2000-pixel CCD spectrum. step_size is the Suruga stage step.
# TODO: verify actual step size — currently using 2.16 μm (estimated from image)

m = load_pl_map(filepath; nx=51, ny=51, step_size=2.16)

println("=== Raw Data ===")
println(m)

# ============================================================================
# STEP 2: INSPECT SPECTRA TO FIND THE PL EMISSION
# ============================================================================
# Before making a map, look at individual spectra to understand what the CCD
# is recording. This tells you which pixel range contains the PL emission.
#
# A typical CCD spectrum from a Raman/PL measurement has:
#   - Low pixels: strong laser/Rayleigh scatter (dominates total counts)
#   - Middle pixels: Raman bands and/or PL emission
#   - High pixels: baseline noise
#
# If you integrate over ALL pixels, the laser scatter dominates and the PL
# signal is buried. You need to identify the PL peak pixel range.

positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]
fig_spec, ax_spec = plot_pl_spectra(m, positions;
    title="Full CCD Spectra at Selected Positions")
save(joinpath(FIGDIR, "01_spectra_full.png"), fig_spec)

# Zoom into the PL region to identify the peak pixel range
fig_zoom, ax_zoom = plot_pl_spectra(m, positions;
    title="PL Emission Region (zoomed)")
xlims!(ax_zoom, 900, 1150)
save(joinpath(FIGDIR, "02_spectra_pl_region.png"), fig_zoom)

# From the zoomed plot, the PL emission sits around pixels 950–1100.
# This is the range we'll integrate over.
PL_RANGE = (950, 1100)

# ============================================================================
# STEP 3: THREE PROCESSING APPROACHES
# ============================================================================
# We compare three increasingly refined ways to build a PL intensity map.
# Each one improves contrast by removing a different source of background.
#
# Approach 1: Raw (all pixels)
#   Sum all 2000 CCD pixels per spectrum. The laser/Rayleigh scatter at low
#   pixel numbers dominates (~1200 counts/pixel vs ~50–100 for PL). Since the
#   scatter is roughly uniform across the map, it acts as a large DC offset
#   that compresses the PL contrast into a narrow range.
#
# Approach 2: PL pixel range only
#   Sum only the PL emission pixels (950–1100). This removes the laser
#   scatter, dramatically improving contrast. However, the CCD still records
#   a per-pixel baseline (dark current, readout noise, diffuse scatter) even
#   at off-flake positions, so the background is not zero.
#
# Approach 3: Pixel range + background subtraction
#   First subtract a reference spectrum (averaged from off-flake positions)
#   from every grid point, then integrate over the PL range. This zeros out
#   the per-pixel baseline so off-flake regions have near-zero intensity.
#
# After normalization to [0, 1], approaches 2 and 3 look visually identical
# because normalize() already removes the DC offset via min-max scaling.
# The background subtraction matters when you need absolute PL intensities
# (e.g., comparing samples or correlating with excitation power).

# Approach 1: Raw
m_raw = load_pl_map(filepath; nx=51, ny=51, step_size=2.16)

# Approach 2: PL pixel range only
m_pr = load_pl_map(filepath; nx=51, ny=51, step_size=2.16, pixel_range=PL_RANGE)

# Approach 3: Pixel range + background subtraction
# Auto mode averages the bottom corners of the map (away from flake and
# top-row artifact). You can also pass explicit positions:
#   subtract_background(m_pr; positions=[(-40, -40), (40, -40)])
m_bg = subtract_background(m_pr)

# Normalize all three for comparison
m_raw_norm = normalize(m_raw)
m_pr_norm = normalize(m_pr)
m_bg_norm = normalize(m_bg)

# Three-panel comparison figure
fig = Figure(size=(1400, 450))
ax1 = Axis(fig[1, 1], xlabel="X (μm)", ylabel="Y (μm)",
           title="Raw (all pixels)", aspect=DataAspect())
ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
           title="PL pixel range only", aspect=DataAspect())
ax3 = Axis(fig[1, 3], xlabel="X (μm)", ylabel="Y (μm)",
           title="Pixel range + background sub", aspect=DataAspect())

hm1 = heatmap!(ax1, m_raw_norm.x, m_raw_norm.y, m_raw_norm.intensity; colormap=:hot)
hm2 = heatmap!(ax2, m_pr_norm.x, m_pr_norm.y, m_pr_norm.intensity; colormap=:hot)
hm3 = heatmap!(ax3, m_bg_norm.x, m_bg_norm.y, m_bg_norm.intensity; colormap=:hot)
Colorbar(fig[1, 4], hm3, label="Normalized PL")

save(joinpath(FIGDIR, "03_comparison.png"), fig)

# ============================================================================
# STEP 4: SNR ANALYSIS
# ============================================================================
# Quantify the improvement from each processing step.
# SNR = (mean_flake - mean_background) / std_background
#
# The pixel range gives ~10× improvement over raw. Background subtraction
# gives identical SNR because it only shifts the mean (subtracting a constant
# from every point doesn't change the contrast or variance). Its value is in
# producing physically meaningful absolute intensities, not in SNR.

on_x, on_y = 21:31, 21:31   # center of map (on flake)
off_x, off_y = 1:10, 1:10   # bottom-left corner (off flake)

println("\n=== SNR Comparison ===")
println(rpad("Processing", 28), rpad("Signal", 12), rpad("Background", 12),
        rpad("Bg std", 10), rpad("Contrast", 12), "SNR")
println("-"^84)

for (name, m) in [("Raw (all pixels)", m_raw),
                   ("PL pixel range", m_pr),
                   ("Pixel range + bg sub", m_bg)]
    sig = mean(m.intensity[on_x, on_y])
    bg = mean(m.intensity[off_x, off_y])
    bg_std = std(m.intensity[off_x, off_y])
    contrast = sig - bg
    snr = contrast / bg_std

    println(rpad(name, 28),
            rpad(string(round(sig, digits=0)), 12),
            rpad(string(round(bg, digits=0)), 12),
            rpad(string(round(bg_std, digits=1)), 10),
            rpad(string(round(contrast, digits=0)), 12),
            string(round(snr, digits=1)))
end

# ============================================================================
# STEP 5: PUBLICATION-QUALITY PL MAP
# ============================================================================
# Use the pixel-range approach with normalization for the cleanest result.

fig_pub, ax_pub, hm_pub = plot_pl_map(m_pr_norm; title="PL Intensity Map")
save(joinpath(FIGDIR, "04_pl_map_publication.png"), fig_pub)

# ============================================================================
# SUMMARY
# ============================================================================

println("\nFigures saved to $FIGDIR")
println("  01_spectra_full.png       — full CCD spectra at selected positions")
println("  02_spectra_pl_region.png  — zoomed view of PL emission region")
println("  03_comparison.png         — three processing approaches side-by-side")
println("  04_pl_map_publication.png — final normalized PL intensity map")
