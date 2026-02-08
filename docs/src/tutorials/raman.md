# Tutorial: Raman Spectroscopy Analysis

This tutorial walks through a complete Raman analysis workflow: loading a spectrum, detecting peaks, fitting a single peak, and decomposing overlapping peaks. By the end you will have a labeled spectrum, fit parameters with uncertainties, and a multi-peak decomposition figure.

## Prerequisites

```julia
julia --project=.
using Revise
using QPS
using CairoMakie  # or GLMakie for interactive exploration
```

Your data directory must contain a Raman registry with at least one entry. See the registry documentation for setup.

## 1. Load a Spectrum

Load a Raman spectrum from the registry by querying sample metadata:

```julia
spec = load_raman(phase="crystal", composition="Co")
```

This returns a `RamanSpectrum` with the raw data and sample metadata. You can inspect it:

```julia
spec           # compact display: RamanSpectrum("Co_crystal", 2048 points)
spec.data.x    # Raman shift values (cm⁻¹)
spec.data.y    # intensity values
```

## 2. Label All Peaks

Before fitting, it helps to see where all the peaks are. `label_peaks` runs peak detection and produces a figure with labeled peak positions:

```julia
fig, peaks = label_peaks(spec)
save("figures/raman_labeled.pdf", fig)
```

The function returns both the figure and a vector of `PeakInfo` structs. Print a summary table:

```julia
println("Detected $(length(peaks)) peaks:")
println(peak_table(peaks))
```

Output looks like:

```
Detected 8 peaks:
  Position   Intensity   Prominence   Width
  --------------------------------------------------
     143.0      892.3         0.45     12.3
     175.2      654.1         0.22      8.5
     ...
```

Each `PeakInfo` has fields you can use to select peaks for fitting: `position`, `intensity`, `prominence`, `width`, `bounds`, and `index`.

!!! tip "Baseline correction during detection"
    `label_peaks` applies arPLS baseline correction by default for `AnnotatedSpectrum` types.
    For raw vectors, pass `baseline=:arpls` explicitly:
    ```julia
    fig, peaks = label_peaks(x, y; baseline=:arpls)
    ```

## 3. Fit a Single Peak

Pick the most prominent peak and define a fitting region around it:

```julia
peak = argmax(p -> p.prominence, peaks)
margin = peak.width
region = (peak.bounds[1] - margin, peak.bounds[2] + margin)

result = fit_peaks(spec, region)
```

`fit_peaks` automatically detects peaks within the region, fits a Lorentzian (default) plus linear baseline, and returns a `MultiPeakFitResult`.

### Inspect the Results

Print a formatted report:

```julia
report(result)
```

Access individual parameters:

```julia
pk = result[1]                # first (and only) peak
pk[:center].value             # peak position in cm⁻¹
pk[:center].err               # standard error
pk[:fwhm].value               # full width at half maximum
pk[:fwhm].ci                  # 95% confidence interval (lo, hi)
```

### Plot the Fit

```julia
fig = plot_peaks(result; residuals=true)
save("figures/raman_fit.pdf", fig)
```

This creates a two-panel figure: data + fit on top, residuals below. Check that:
- The fit line passes through the data
- Residuals scatter randomly around zero (no systematic pattern)

## 4. Multi-Peak Decomposition

When peaks overlap, fit them simultaneously. Select the two most prominent peaks and define a region that covers both:

```julia
sorted_peaks = sort(peaks, by=p -> p.prominence, rev=true)
top2 = sort(sorted_peaks[1:2], by=p -> p.position)

lo = top2[1].bounds[1] - top2[1].width
hi = top2[2].bounds[2] + top2[2].width

result2 = fit_peaks(spec, (lo, hi); n_peaks=2)
report(result2)
```

### Visualize the Decomposition

Use `plot_peak_decomposition!` to overlay individual peak curves on a custom figure:

```julia
fig = Figure(size=(700, 500))
ax = Axis(fig[1, 1],
    xlabel="Raman Shift (cm⁻¹)",
    ylabel="Intensity",
    title="Two-peak decomposition"
)
scatter!(ax, result2._x, result2._y, label="Data")
plot_peak_decomposition!(ax, result2)
axislegend(ax, position=:rt)

save("figures/raman_multipeak.pdf", fig)
```

This shows the composite fit, individual peak curves (dashed), and the baseline (dotted).

### Access Individual Peaks

```julia
result2[1][:center].value    # first peak center
result2[2][:center].value    # second peak center
predict_peak(result2, 1)     # curve for peak 1 only
predict_peak(result2, 2)     # curve for peak 2 only
predict_baseline(result2)    # baseline polynomial
```

## 5. Trying a Different Model

The default model is `lorentzian`. To use a Gaussian or Pseudo-Voigt instead:

```julia
result_g = fit_peaks(spec, region; model=gaussian)
result_v = fit_peaks(spec, region; model=pseudo_voigt)
```

Compare R² values to see which model fits best:

```julia
println("Lorentzian R² = ", round(result.r_squared, digits=5))
println("Gaussian R²   = ", round(result_g.r_squared, digits=5))
println("Voigt R²      = ", round(result_v.r_squared, digits=5))
```

See [Choose a Peak Model](@ref "Choose a Peak Model") for guidance on when to use each model.

## Summary

| Step | Function | What it does |
|------|----------|-------------|
| Load | `load_raman(; kwargs...)` | Query registry, return `RamanSpectrum` |
| Detect | `label_peaks(spec)` | Find all peaks, create labeled figure |
| Inspect | `peak_table(peaks)` | Print peak summary |
| Fit | `fit_peaks(spec, region)` | Fit peak(s) with baseline |
| Report | `report(result)` | Print formatted parameters |
| Plot | `plot_peaks(result)` | Data + fit + residuals figure |
| Decompose | `plot_peak_decomposition!(ax, result)` | Overlay individual peaks |

## Next Steps

- [Tutorial: FTIR Analysis](@ref "Tutorial: FTIR Spectroscopy Analysis") — subtraction and model comparison workflow
- [Tune Peak Detection Sensitivity](@ref "Tune Peak Detection Sensitivity") — adjust `min_prominence`, `window`, etc.
- [Fit Overlapping Peaks](@ref "Fit Overlapping Peaks") — more on multi-peak fitting
- [Fitting Statistics](@ref "Fitting Statistics Reference") — understanding uncertainties and fit quality
