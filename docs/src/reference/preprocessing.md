# Preprocessing

Spectrum subtraction, smoothing, and simple baseline correction utilities.

## Spectrum Subtraction

```@docs
subtract_spectrum
```

The `subtract` function provides typed dispatches for `FTIRSpectrum` and `RamanSpectrum` that preserve sample metadata:

```julia
corrected = subtract(spec, ref)              # Returns same type as spec
corrected = subtract(spec, ref, scale=0.95)  # Scale reference before subtracting
```

## Linear Baseline Correction

```@docs
linear_baseline_correction
```

## Smoothing

```@docs
smooth_data
savitzky_golay
```
