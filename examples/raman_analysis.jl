# Raman Analysis Example
#
# MoSe2 flake: detect peaks, fit A₁g mode at two spatial positions,
# and produce a publication figure comparing center vs. edge.

using QPSTools
using CairoMakie
using FileIO

PROJECT_ROOT = dirname(@__DIR__)
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "raman")
mkpath(FIGDIR)
set_data_dir(joinpath(PROJECT_ROOT, "data"))

# =============================================================================
# 1. Load spectra at two positions on the flake
# =============================================================================

spec_center = load_raman(sample="center", material="MoSe2")
spec_edge = load_raman(sample="right", material="MoSe2")

# =============================================================================
# 2. Peak detection — confirm material identity
# =============================================================================

peaks = find_peaks(spec_center)
println(peak_table(peaks))

# =============================================================================
# 3. Fit the A₁g peak (~242 cm⁻¹) at both positions on the flake
# =============================================================================

fit_center = fit_peaks(spec_center, (225, 260))
fit_edge = fit_peaks(spec_edge, (225, 260))

report(fit_center)
report(fit_edge)

fig, ax = plot_raman(spec_center; peaks=peaks)
save(joinpath(FIGDIR, "mose2_peaks.png"), fig)

fig, ax, ax_res = plot_raman(spec_center; fit=fit_center, residuals=true)
save(joinpath(FIGDIR, "mose2_a1g_fit.png"), fig)

# =============================================================================
# 4. Publication figure
# =============================================================================

data_dir = get_data_dir()
img_center = load(joinpath(data_dir, "raman/MoSe2/MoSe2_x100_center.PNG"))
img_right = load(joinpath(data_dir, "raman/MoSe2/MoSe2_x100_right.PNG"))

set_theme!(print_theme())
fig = Figure(size=(900, 800))

# Row 1: microscopy images
ax1 = Axis(fig[1, 1], title="(a) Center", aspect=DataAspect())
image!(ax1, rotr90(img_center))
hidedecorations!(ax1)

ax2 = Axis(fig[1, 2], title="(b) Edge", aspect=DataAspect())
image!(ax2, rotr90(img_right))
hidedecorations!(ax2)

# Row 2: spectra overlay with fit region highlighted
ax3 = Axis(fig[2, 1:2],
    xlabel="Raman Shift (cm⁻¹)", ylabel="Intensity",
    title="(c) MoSe₂ Raman Spectra")
lines!(ax3, shift(spec_center), intensity(spec_center), label="Center")
lines!(ax3, shift(spec_edge), intensity(spec_edge), label="Edge")
vspan!(ax3, 225, 260, color=(:gray, 0.15))
axislegend(ax3, position=:rt)

# Row 3: A₁g peak fits + residuals
ax4 = Axis(fig[3, 1:2], ylabel="Intensity", title="(d) A₁g Peak Fits")
scatter!(ax4, xdata(fit_center), ydata(fit_center), label="Center")
lines!(ax4, xdata(fit_center), predict(fit_center), color=:red, label="Fit")
scatter!(ax4, xdata(fit_edge), ydata(fit_edge), label="Edge")
lines!(ax4, xdata(fit_edge), predict(fit_edge), color=:orange, label="Fit")
axislegend(ax4, position=:rt)

ax5 = Axis(fig[4, 1:2], xlabel="Raman Shift (cm⁻¹)", ylabel="Residual")
scatter!(ax5, xdata(fit_center), residuals(fit_center), label="Center")
scatter!(ax5, xdata(fit_edge), residuals(fit_edge), label="Edge")
hlines!(ax5, 0, color=:black, linestyle=:dash)
linkxaxes!(ax4, ax5)
hidexdecorations!(ax4, grid=false)

figpath = joinpath(FIGDIR, "mose2_raman.png")
save(figpath, fig)
println("\nFigure saved to $FIGDIR")

# =============================================================================
# 5. Log to eLabFTW
# =============================================================================
# Uncomment to upload results to the lab notebook.
# Requires ELABFTW_URL and ELABFTW_API_KEY environment variables.

#=
log_to_elab(
    title = "Raman: MoSe2 A₁g peak comparison",
    body = """
## Sample
MoSe₂ flake, two positions (center and right edge)

## A₁g Peak Fits

### Center
$(format_results(fit_center))

### Edge
$(format_results(fit_edge))
""",
    attachments = [figpath],
    tags = ["raman", "mose2", "tmdc", "a1g"]
)
=#
