# Raman Analysis Example
#
# Demonstrates the full Raman workflow: load → label → fit → decompose
# Run from project root: julia --project=. examples/raman_analysis.jl

using QPSTools
using CairoMakie

# =============================================================================
# 1. Load and label all peaks
# =============================================================================

spec = load_raman(phase="crystal", composition="Co")
println("Loaded: ", spec)

peaks = find_peaks(spec)
fig, ax = plot_spectrum(spec; peaks=peaks)
save("figures/EXAMPLES/raman/raman_labeled.pdf", fig)

println("\nDetected $(length(peaks)) peaks:")
println(peak_table(peaks))

# =============================================================================
# 2. Single peak fit
# =============================================================================

# Pick the most prominent peak and expand bounds for fitting
peak = argmax(p -> p.prominence, peaks)
margin = peak.width
region = (peak.bounds[1] - margin, peak.bounds[2] + margin)

result = fit_peaks(spec, region)
pk = result[1]

println()
report(result)

fig, ax, ax_res = plot_spectrum(spec; fit=result, residuals=true)
save("figures/EXAMPLES/raman/raman_fit.pdf", fig)

# =============================================================================
# 3. Multi-peak fit
# =============================================================================

# Fit two peaks in a wider region using the two most prominent detections
sorted_peaks = sort(peaks, by=p -> p.prominence, rev=true)
top2 = sort(sorted_peaks[1:2], by=p -> p.position)
lo = top2[1].bounds[1] - top2[1].width
hi = top2[2].bounds[2] + top2[2].width

result2 = fit_peaks(spec, (lo, hi); n_peaks=2)

println()
report(result2)

# Plot with individual peak curves shown
fig = Figure(size=(700, 500))
ax = Axis(fig[1, 1],
    xlabel="Raman Shift (cm⁻¹)",
    ylabel="Intensity",
    title="Two-peak decomposition"
)
scatter!(ax, result2._x, result2._y, color=lab_colors()[:primary], label="Data")
plot_peak_decomposition!(ax, result2)
axislegend(ax, position=:rt)

save("figures/EXAMPLES/raman/raman_multipeak.pdf", fig)

println("\nFigures saved to figures/EXAMPLES/raman/")

# =============================================================================
# 4. Log to eLabFTW (optional)
# =============================================================================

# Uncomment to log results to your lab notebook:
#
# log_to_elab(
#     title = "Raman: ZIF-62(Co) peak analysis",
#     body = """
# ## Sample
# ZIF-62(Co) crystal
#
# ## Single Peak Fit
# $(format_results(result))
#
# ## Two-Peak Decomposition
# $(format_results(result2))
# """,
#     attachments = [
#         "figures/EXAMPLES/raman/raman_fit.pdf",
#         "figures/EXAMPLES/raman/raman_multipeak.pdf"
#     ],
#     tags = ["raman", "zif-62", "mof"]
# )
