# Cosmic Ray Detection & Removal
#
# Demonstrates automatic detection and removal of cosmic ray spikes in
# PL map spectra. Cosmic rays are single-pixel artifacts from high-energy
# particles hitting the CCD — they appear as sharp, narrow spikes that
# don't correlate with spatial neighbors.
#
# The algorithm uses modified z-scores on first differences (Whitaker-Hayes)
# for 1D detection, with spatial validation for PLMap data: if a spike
# appears at the same spectral channel in multiple neighboring pixels,
# it is recognized as a real feature and preserved.
#
# Works on:
#   - Any 1D spectrum (AbstractVector)
#   - PLMap (3D spectra array with spatial neighbor validation)

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(dirname(@__DIR__))
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "cosmic_rays")
mkpath(FIGDIR)

# =============================================================================
# 1. Detect cosmic rays on a single spectrum
# =============================================================================
# Useful for quick inspection of individual spectra from any measurement type.

filepath = joinpath(PROJECT_ROOT, "data", "PLmap", "CCDtmp_260129_111138.lvm")
m = load_pl_map(filepath; nx=51, ny=51, step_size=2.16)

# Extract a single spectrum
spec = extract_spectrum(m, 25, 25)

# Detect spikes
cr = detect_cosmic_rays(spec.signal; threshold=5.0)
println("1D detection: found $(cr.count) cosmic ray(s) at channels $(cr.indices)")

# Remove and compare
if cr.count > 0
    cleaned = remove_cosmic_rays(spec.signal, cr)

    fig = Figure(size=(800, 400))
    ax = Axis(fig[1, 1], xlabel="CCD Pixel", ylabel="Counts",
        title="Cosmic Ray Removal — Single Spectrum")
    lines!(ax, spec.pixel, spec.signal, color=:gray, alpha=0.5, label="Original")
    lines!(ax, spec.pixel, cleaned, color=:blue, label="Cleaned")

    # Mark spike locations
    for idx in cr.indices
        vlines!(ax, spec.pixel[idx], color=:red, linestyle=:dash, alpha=0.5)
    end
    axislegend(ax, position=:rt)

    save(joinpath(FIGDIR, "single_spectrum.png"), fig)
    println("Saved single spectrum comparison")
end

# =============================================================================
# 2. Detect cosmic rays across a full PL map
# =============================================================================
# Spatial validation prevents real spectral features (shared by neighbors)
# from being falsely flagged.

m = subtract_background(m)
cr_map = detect_cosmic_rays(m; threshold=5.0)

println("\nPLMap detection:")
println("  Total cosmic ray pixels: $(cr_map.count)")
println("  Affected spectra: $(cr_map.affected_spectra) / $(length(m.x) * length(m.y))")

# =============================================================================
# 3. Visualize: before/after + spike location map
# =============================================================================

m_clean = remove_cosmic_rays(m, cr_map)

# Per-pixel spike count for heatmap visualization
cr_counts = dropdims(sum(cr_map.mask; dims=3); dims=3)

set_theme!(qps_theme())
fig = Figure(size=(1400, 400))

# (a) PL intensity — original
ax1 = Axis(fig[1, 1], xlabel="X (μm)", ylabel="Y (μm)",
    title="(a) Original", aspect=DataAspect())
hm1 = heatmap!(ax1, xdata(m), ydata(m), intensity(m); colormap=:hot)
Colorbar(fig[1, 2], hm1, label="PL Intensity")
colsize!(fig.layout, 1, Aspect(1, 1.0))

# (b) Cosmic ray count per pixel
ax2 = Axis(fig[1, 3], xlabel="X (μm)", ylabel="Y (μm)",
    title="(b) Cosmic Ray Count", aspect=DataAspect())
hm2 = heatmap!(ax2, xdata(m), ydata(m), cr_counts; colormap=:inferno)
Colorbar(fig[1, 4], hm2, label="Spike Count")
colsize!(fig.layout, 3, Aspect(1, 1.0))

# (c) PL intensity — cleaned
ax3 = Axis(fig[1, 5], xlabel="X (μm)", ylabel="Y (μm)",
    title="(c) After Removal", aspect=DataAspect())
hm3 = heatmap!(ax3, xdata(m_clean), ydata(m_clean), intensity(m_clean); colormap=:hot)
Colorbar(fig[1, 6], hm3, label="PL Intensity")
colsize!(fig.layout, 5, Aspect(1, 1.0))

figpath = joinpath(FIGDIR, "plmap_cosmic_rays.png")
save(figpath, fig)
println("\nFigure saved to $FIGDIR")

# =============================================================================
# 4. Channel histogram — where do spikes cluster?
# =============================================================================

fig2 = Figure(size=(600, 300))
ax = Axis(fig2[1, 1], xlabel="Spectral Channel", ylabel="Cosmic Ray Count",
    title="Cosmic Ray Distribution Across Spectrum")
barplot!(ax, 1:length(cr_map.channel_counts), cr_map.channel_counts, color=:steelblue)
save(joinpath(FIGDIR, "channel_histogram.png"), fig2)
println("Saved channel histogram")

# =============================================================================
# 5. Threshold sensitivity
# =============================================================================
# Lower threshold → more detections (more aggressive). Higher → fewer (conservative).
# Compare detection counts at different thresholds.

println("\nThreshold sensitivity:")
for thresh in [3.0, 4.0, 5.0, 6.0, 7.0]
    cr_t = detect_cosmic_rays(m; threshold=thresh)
    println("  threshold=$thresh → $(cr_t.count) spikes in $(cr_t.affected_spectra) spectra")
end
