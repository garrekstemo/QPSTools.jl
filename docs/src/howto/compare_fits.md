# Compare Fits Across Samples

Extract and compare peak parameters from multiple samples or conditions.

## Problem

You have several spectra (different concentrations, temperatures, etc.) and want to track how a peak parameter changes.

## Solution

### Fit Each Sample

```julia
concentrations = ["0.5M", "1.0M", "2.0M"]
results = Dict{String, MultiPeakFitResult}()

for conc in concentrations
    spec = load_ftir(solute="NH4SCN", concentration=conc)
    results[conc] = fit_peaks(spec, (1950, 2150))
end
```

### Extract Parameters

Build vectors of the parameter you want to compare:

```julia
centers = [results[c][1][:center].value for c in concentrations]
center_errs = [results[c][1][:center].err for c in concentrations]
fwhms = [results[c][1][:fwhm].value for c in concentrations]
fwhm_errs = [results[c][1][:fwhm].err for c in concentrations]
```

### Print a Comparison Table

```julia
println(rpad("Conc", 8), rpad("Center", 12), rpad("FWHM", 12), "R²")
for c in concentrations
    r = results[c]
    pk = r[1]
    println(
        rpad(c, 8),
        rpad(string(round(pk[:center].value, digits=1)), 12),
        rpad(string(round(pk[:fwhm].value, digits=1), " ± ",
                    round(pk[:fwhm].err, digits=1)), 12),
        round(r.r_squared, digits=5)
    )
end
```

### Plot the Trend

```julia
conc_values = [0.5, 1.0, 2.0]

fig = Figure(size=(500, 400))
ax = Axis(fig[1, 1],
    xlabel="Concentration (M)",
    ylabel="Peak center (cm⁻¹)"
)
errorbars!(ax, conc_values, centers, center_errs)
scatter!(ax, conc_values, centers)
save("figures/center_vs_conc.pdf", fig)
```

## Tips

- Use `report(result)` for each sample to quickly inspect individual fits
- Store results in a `Dict` or `Vector` for easy iteration
- For many samples, consider logging each fit to eLabFTW with [`log_to_elab`](@ref "eLabFTW Experiment Logging")

## See Also

- [`fit_peaks`](@ref) — full API reference
- [Fitting Statistics](@ref "Fitting Statistics Reference") — interpreting uncertainties
