# Tutorial: FTIR Spectroscopy Analysis

This tutorial walks through an FTIR analysis workflow: loading spectra, subtracting a solvent reference, fitting a peak, and comparing Lorentzian vs Gaussian models. It builds on concepts from the [Raman tutorial](@ref "Tutorial: Raman Spectroscopy Analysis") and emphasizes solvent subtraction and model comparison — two tasks that are common in FTIR work but less frequent in Raman.

## Prerequisites

```julia
julia --project=.
using Revise
using QPS
using CairoMakie
```

Your data directory must contain an FTIR registry with sample and reference entries.

## 1. Load and Label Spectra

Load multiple FTIR spectra and label their peaks to survey the data:

```julia
samples = [
    (label="NH4SCN",  kw=(solute="NH4SCN", concentration="1.0M")),
    (label="DMF",     kw=(material="DMF",)),
    (label="DPPA",    kw=(solute="DPPA",)),
]

for s in samples
    spec_i = load_ftir(; s.kw...)
    fig, peaks = label_peaks(spec_i)
    save("figures/ftir_labeled_$(s.label).pdf", fig)
    println("$(s.label): $(length(peaks)) peaks detected")
end
```

Pick one sample for the rest of the analysis:

```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
```

## 2. Fit the CN Stretch

The CN stretch of SCN⁻ appears near 2060 cm⁻¹. Define a fitting region and fit:

```julia
result = fit_peaks(spec, (1950, 2150))
report(result)
```

The report shows the center, FWHM (or sigma), amplitude, and baseline parameters with uncertainties.

Visualize the fit with a residuals panel:

```julia
fig = plot_peaks(result; residuals=true)
save("figures/ftir_fit.pdf", fig)
```

Check the residuals for systematic patterns. Random scatter around zero indicates a good fit.

## 3. Solvent Subtraction

FTIR spectra of solutions include solvent absorption. Subtract the pure solvent reference to isolate solute features:

```julia
ref = load_ftir(material="DMF")
corrected = subtract(spec, ref)
```

`subtract` returns a new `FTIRSpectrum` with the solvent contribution removed. The sample metadata is preserved.

Now fit the same region on the corrected spectrum:

```julia
result_sub = fit_peaks(corrected, (1950, 2150))
report(result_sub)
```

Compare the peak center and width before and after subtraction:

```julia
println("Before subtraction:")
println("  center = ", round(result[1][:center].value, digits=1), " cm⁻¹")
println("  fwhm   = ", round(result[1][:fwhm].value, digits=1), " cm⁻¹")

println("After subtraction:")
println("  center = ", round(result_sub[1][:center].value, digits=1), " cm⁻¹")
println("  fwhm   = ", round(result_sub[1][:fwhm].value, digits=1), " cm⁻¹")
```

!!! tip "Scaling the reference"
    If the solvent and sample were measured at different pathlengths or concentrations,
    scale the reference before subtracting:
    ```julia
    corrected = subtract(spec, ref, scale=0.95)
    ```

## 4. Model Comparison: Lorentzian vs Gaussian

Different physical broadening mechanisms produce different line shapes. Fit the same data with both models:

```julia
result_lor = fit_peaks(spec, (1950, 2150))                   # Lorentzian (default)
result_gau = fit_peaks(spec, (1950, 2150); model=gaussian)   # Gaussian
```

Compare fit quality:

```julia
println("Lorentzian: R² = ", round(result_lor.r_squared, digits=5),
        "  RSS = ", round(result_lor.rss, digits=6))
println("Gaussian:   R² = ", round(result_gau.r_squared, digits=5),
        "  RSS = ", round(result_gau.rss, digits=6))
```

Print both reports side by side:

```julia
println("=== Lorentzian ===")
report(result_lor)

println("=== Gaussian ===")
report(result_gau)
```

The model with lower RSS (and higher R²) fits the data better. For solution-phase FTIR, Lorentzian line shapes are often a better description because the dominant broadening mechanism is collisional (homogeneous).

For a deeper discussion of when to use each model, see [Choose a Peak Model](@ref "Choose a Peak Model").

## 5. Publication Figure

Combine everything into a multi-panel figure:

```julia
set_theme!(print_theme())

fig = Figure(size=(900, 400))

# Panel A: Subtracted spectrum with fit
ax_a = Axis(fig[1, 1],
    xlabel="Wavenumber (cm⁻¹)",
    ylabel="Absorbance",
    title="(a) Solvent-subtracted",
    xreversed=true
)
scatter!(ax_a, result_sub._x, result_sub._y, label="Data")
lines!(ax_a, result_sub._x, predict(result_sub), color=:red, label="Fit")
axislegend(ax_a, position=:lt)

# Panel B: Residuals
ax_b = Axis(fig[1, 2],
    xlabel="Wavenumber (cm⁻¹)",
    ylabel="Residuals",
    title="(b) Residuals",
    xreversed=true
)
scatter!(ax_b, result_sub._x, residuals(result_sub))
hlines!(ax_b, 0, color=:black, linestyle=:dash)

save("figures/ftir_publication.pdf", fig)
```

## Summary

| Step | Function | What it does |
|------|----------|-------------|
| Load | `load_ftir(; kwargs...)` | Query registry, return `FTIRSpectrum` |
| Label | `label_peaks(spec)` | Detect and label all peaks |
| Subtract | `subtract(spec, ref)` | Remove solvent background |
| Fit | `fit_peaks(spec, region)` | Fit peak(s) in region |
| Compare | `fit_peaks(...; model=gaussian)` | Try different line shapes |
| Report | `report(result)` | Print formatted parameters |
| Plot | `plot_peaks(result)` | Data + fit + residuals |

## Next Steps

- [Choose a Peak Model](@ref "Choose a Peak Model") — Lorentzian, Gaussian, or Pseudo-Voigt?
- [Compare Fits Across Samples](@ref "Compare Fits Across Samples") — extract parameters from multiple samples
- [Fitting Statistics](@ref "Fitting Statistics Reference") — R², RSS, confidence intervals explained
- [Baseline Algorithms](@ref "Baseline Algorithms") — when to use arPLS, ALS, or SNIP
