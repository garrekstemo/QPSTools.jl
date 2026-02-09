# Baseline Correction Example
#
# Demonstrates baseline correction on ZIF-62 Raman spectra using
# the glass phase (curved fluorescence background) and crystal phase
# (sloped background). Shows full-spectrum and localized correction.

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(@__DIR__)
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "baseline")
mkpath(FIGDIR)
set_data_dir(joinpath(PROJECT_ROOT, "data"))

# =============================================================================
# 1. Full-spectrum baseline correction (glass — curved background)
# =============================================================================

glass = load_raman(material="ZIF-62", phase="glass", sample="glass_2a")
println("Loaded: ", glass)

# Correct with default method (ARPLS)
corrected = correct_baseline(glass)

fig = Figure(size=(800, 600))

ax1 = Axis(fig[1, 1], ylabel="Intensity", title="Raw spectrum + estimated baseline")
lines!(ax1, corrected.x, ydata(glass), label="Raw")
lines!(ax1, corrected.x, corrected.baseline, color=:red, label="Baseline (ARPLS)")
axislegend(ax1, position=:rt)

ax2 = Axis(fig[2, 1], xlabel="Raman Shift (cm⁻¹)", ylabel="Intensity",
    title="Baseline-corrected")
lines!(ax2, corrected.x, corrected.y)

linkxaxes!(ax1, ax2)
save(joinpath(FIGDIR, "full_spectrum_correction.png"), fig)
println("Saved full-spectrum correction")

# =============================================================================
# 2. Compare correction methods
# =============================================================================

methods = [:als, :arpls, :snip]

fig = Figure(size=(800, 800))

ax_raw = Axis(fig[1, 1], ylabel="Intensity", title="Raw spectrum")
lines!(ax_raw, xdata(glass), ydata(glass), color=:black)

for (i, m) in enumerate(methods)
    result = correct_baseline(glass; method=m)

    ax = Axis(fig[i + 1, 1], ylabel="Intensity", title="$(uppercase(string(m)))")
    lines!(ax, result.x, result.y)

    if i < length(methods)
        hidexdecorations!(ax, grid=false)
    else
        ax.xlabel = "Raman Shift (cm⁻¹)"
    end
end

linkxaxes!(contents(fig.layout)...)
save(joinpath(FIGDIR, "method_comparison.png"), fig)
println("Saved method comparison")

# =============================================================================
# 3. Localized correction + peak fitting (crystal — sloped background)
# =============================================================================

crystal = load_raman(material="ZIF-62", phase="crystal", composition="Co")
println("\nLoaded: ", crystal)

# Detect peaks to find interesting regions
peaks = find_peaks(crystal)
println("Detected $(length(peaks)) peaks")
println(peak_table(peaks))

# Pick the two most prominent peaks
sorted = sort(peaks, by=p -> p.prominence, rev=true)
top2 = sort(sorted[1:min(2, length(sorted))], by=p -> p.position)

# Define a region around the top peaks with some margin
margin = 30.0
lo = top2[1].position - margin
hi = top2[end].position + margin
region = (lo, hi)

# Correct baseline in just this region
x_full, y_full = xdata(crystal), ydata(crystal)
mask = lo .<= x_full .<= hi
x_region = x_full[mask]
y_region = y_full[mask]

corrected_region = correct_baseline(x_region, y_region; method=:arpls)

fig = Figure(size=(800, 600))

ax1 = Axis(fig[1, 1], ylabel="Intensity", title="Peak region with baseline")
lines!(ax1, x_region, y_region, label="Raw")
lines!(ax1, x_region, corrected_region.baseline, color=:red, label="Baseline")
axislegend(ax1, position=:rt)

ax2 = Axis(fig[2, 1], xlabel="Raman Shift (cm⁻¹)", ylabel="Intensity",
    title="Corrected — ready for peak fitting")
lines!(ax2, corrected_region.x, corrected_region.y)

linkxaxes!(ax1, ax2)
save(joinpath(FIGDIR, "localized_correction.png"), fig)
println("Saved localized correction")

# Fit peaks on the corrected data
result = fit_peaks(crystal, region)
report(result)

fig, ax, ax_res = plot_spectrum(crystal; fit=result, residuals=true)
save(joinpath(FIGDIR, "corrected_peak_fit.png"), fig)
println("Saved corrected peak fit")

println("\nFigures saved to $FIGDIR")
