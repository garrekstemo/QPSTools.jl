# MoSe2 Raman Analysis
#
# Compare Raman spectra at two positions on a MoSe2 flake.
# Run from project root: julia --project=. examples/mose2_raman.jl

using QPSTools
using CairoMakie
using FileIO

mkpath("figures/EXAMPLES/raman")

# =============================================================================
# 1. Load spectra and label peaks
# =============================================================================

center = load_raman(material="MoSe2", sample="center")
right = load_raman(material="MoSe2", sample="right")

fig, peaks = label_peaks(center)
save("figures/EXAMPLES/raman/mose2_peaks.pdf", fig)
println(peak_table(peaks))

# =============================================================================
# 2. Fit the A₁g peak (~242 cm⁻¹) at both positions
# =============================================================================

result_center = fit_peaks(center, (225, 260))
result_right = fit_peaks(right, (225, 260))

println()
report(result_center)
report(result_right)

fig = plot_peaks(result_center; residuals=true)
save("figures/EXAMPLES/raman/mose2_a1g_fit.pdf", fig)

# =============================================================================
# 3. Publication figure: microscopy + spectra + peak fits
# =============================================================================

data_dir = get_data_dir()
img_center = load(joinpath(data_dir, "raman/MoSe2/MoSe2_x100_center.PNG"))
img_right = load(joinpath(data_dir, "raman/MoSe2/MoSe2_x100_right.PNG"))

set_theme!(publication_theme())
fig = Figure(size=(900, 800))

# Microscopy images
ax1 = Axis(fig[1, 1], title="(a) Center", aspect=DataAspect())
image!(ax1, rotr90(img_center))
hidedecorations!(ax1)

ax2 = Axis(fig[1, 2], title="(b) Right", aspect=DataAspect())
image!(ax2, rotr90(img_right))
hidedecorations!(ax2)

# Spectra overlay
ax3 = Axis(fig[2, 1:2], xlabel="Raman Shift (cm⁻¹)", ylabel="Intensity",
    title="(c) MoSe₂ Raman spectra")
lines!(ax3, xdata(center), ydata(center), label="Center")
lines!(ax3, xdata(right), ydata(right), label="Right")
vspan!(ax3, 225, 260, color=(:gray, 0.15))
axislegend(ax3, position=:rt)

# A₁g peak fits
ax4 = Axis(fig[3, 1:2], xlabel="Raman Shift (cm⁻¹)", ylabel="Intensity",
    title="(d) A₁g peak fits")
scatter!(ax4, result_center._x, result_center._y, label="Center")
lines!(ax4, result_center._x, predict(result_center), color=:red, label="Fit")
scatter!(ax4, result_right._x, result_right._y, label="Right")
lines!(ax4, result_right._x, predict(result_right), color=:orange, label="Fit")
axislegend(ax4, position=:rt)

save("figures/EXAMPLES/raman/mose2_publication.pdf", fig)

println("\nFigures saved to figures/EXAMPLES/raman/")

# =============================================================================
# 4. Log to eLabFTW (optional)
# =============================================================================

# Uncomment to log results to your lab notebook:
#
# log_to_elab(
#     title = "Raman: MoSe2 A₁g peak comparison",
#     body = """
# ## Sample
# MoSe₂ flake, two positions (center and right edge)
#
# ## A₁g Peak Fits
#
# ### Center
# $(format_results(result_center))
#
# ### Right
# $(format_results(result_right))
# """,
#     attachments = ["figures/EXAMPLES/raman/mose2_publication.pdf"],
#     tags = ["raman", "mose2", "tmdc", "a1g"]
# )
