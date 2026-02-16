# PL Mapping Analysis
#
# Runnable version of bootstrap/templates/plmap_analysis.jl with real data.
# Produces a publication-quality 3-panel figure saved to figures/EXAMPLES/pl_map/.
#
# Ref: bootstrap/templates/plmap_analysis.jl

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(@__DIR__)
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "pl_map")
mkpath(FIGDIR)

filepath = joinpath(PROJECT_ROOT, "data", "PLmap", "CCDtmp_260129_111138.lvm")

# =============================================================================
# 1. Load raw scan and inspect spectra
# =============================================================================
# Integrating ALL CCD pixels buries the PL signal under laser scatter.
# First, look at individual spectra to find which pixels contain the PL peak.

m_raw = load_pl_map(filepath; nx=51, ny=51, step_size=2.16)
println(m_raw)

positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]
fig_spec, ax_spec = plot_pl_spectra(m_raw, positions; title="CCD Spectra")
save(joinpath(FIGDIR, "spectra_full.png"), fig_spec)

# From inspection: PL emission sits around pixels 950-1100.

# =============================================================================
# 2. Process: pixel range + background subtraction
# =============================================================================
# Reload integrating only PL pixels, then subtract a reference spectrum
# averaged from off-flake regions (auto mode uses bottom corners of the map).

m = load_pl_map(filepath; nx=51, ny=51, step_size=2.16, pixel_range=(950, 1100))
m = subtract_background(m)
centers = peak_centers(m)
m = normalize_intensity(m)
println(m)

# =============================================================================
# 3. Publication figure: representative spectra + PL intensity map
# =============================================================================

set_theme!(qps_theme())
fig = Figure(size=(1400, 400))

# (a) PL spectra at selected positions
ax1 = Axis(fig[1, 1], xlabel="CCD Pixel", ylabel="Counts",
    title="(a) PL Spectra")
for (i, pos) in enumerate(positions)
    spec = extract_spectrum(m_raw; x=pos[1], y=pos[2])
    lines!(ax1, spec.pixel, spec.signal, label="($(pos[1]), $(pos[2])) μm")
end
vspan!(ax1, 950, 1100, color=(:blue, 0.1))
axislegend(ax1, position=:rt)

# (b) Normalized PL intensity map
ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
    title="(b) PL Intensity", aspect=DataAspect())
hm = heatmap!(ax2, xdata(m), ydata(m), intensity(m); colormap=:hot)
Colorbar(fig[1, 3], hm, label="Normalized PL")
colsize!(fig.layout, 2, Aspect(1, 1.0))

# (c) PL peak center map
ax3 = Axis(fig[1, 4], xlabel="X (μm)", ylabel="Y (μm)",
    title="(c) Peak Center", aspect=DataAspect())
hm2 = heatmap!(ax3, xdata(m), ydata(m), centers; colormap=:viridis,
    nan_color=:transparent)
Colorbar(fig[1, 5], hm2, label="Peak Center (pixel)")
colsize!(fig.layout, 4, Aspect(1, 1.0))

figpath = joinpath(FIGDIR, "pl_map.png")
save(figpath, fig)
println("\nFigure saved to $FIGDIR")

# =============================================================================
# 4. Log to eLabFTW (optional)
# =============================================================================
# Uncomment to upload the figure and metadata to the lab notebook.
# Requires ELABFTW_URL and ELABFTW_API_KEY environment variables.

#=
log_to_elab(
    title = "PL Map: MoSe2 flake",
    body = """
## Measurement
- **Sample**: MoSe₂ on SiO₂/Si
- **Grid**: 51 x 51 (2.16 μm step)
- **PL pixel range**: 950-1100
- **Background**: auto (bottom corners)
""",
    attachments = [figpath],
    tags = ["pl-map", "mose2", "tmdc", "ccd"]
)
=#
