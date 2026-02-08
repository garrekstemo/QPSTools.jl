# Fit with Baseline Correction

Peak fitting in `fit_peaks` includes a polynomial baseline by default, but for strongly curved backgrounds you may need to correct the baseline first.

## Built-In Baseline

`fit_peaks` fits peaks on top of a polynomial baseline. Control the polynomial order with `baseline_order`:

```julia
# Linear baseline (default)
result = fit_peaks(spec, region)

# Constant baseline (flat offset)
result = fit_peaks(spec, region; baseline_order=0)

# Quadratic baseline
result = fit_peaks(spec, region; baseline_order=2)
```

Access the fitted baseline:

```julia
bl = predict_baseline(result)       # baseline on fit region
bl_custom = predict_baseline(result, x)  # baseline on custom x
```

## Pre-Correction for Difficult Baselines

When the background is too complex for a low-order polynomial (e.g., fluorescence in Raman, broad solvent absorption in FTIR), correct the baseline before fitting.

### Using `correct_baseline`

```julia
corrected = correct_baseline(spec; method=:arpls, λ=1e6)

# corrected.x, corrected.y are the baseline-corrected data
result = fit_peaks(corrected.x, corrected.y)
```

### Using `find_peaks` with Baseline

Peak detection can apply baseline correction internally:

```julia
peaks = find_peaks(spec, baseline=:arpls)
```

This affects which peaks are detected but does not change the data passed to `fit_peaks`.

### Combining Both

For the best results with challenging data:

```julia
# 1. Correct baseline for accurate peak detection
peaks = find_peaks(spec, baseline=:arpls, min_prominence=0.05)

# 2. Fit on original data with polynomial baseline
result = fit_peaks(spec, region; peaks=peaks)
```

This uses baseline-corrected data for detection (finding the right peaks) but fits the original data (avoiding artifacts from baseline subtraction).

## See Also

- [`correct_baseline`](@ref) — unified baseline correction API
- [`fit_peaks`](@ref) — `baseline_order` parameter
- [Baseline Algorithms](@ref) — choosing between arPLS, ALS, and SNIP
