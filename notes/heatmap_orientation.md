# Makie Heatmap Orientation for TA Data

## The Problem

CCD-based broadband TA data is stored as a matrix with shape `(n_time, n_wavelength)`, typically something like `(151, 2048)`. Displaying this as a heatmap with the standard TA convention (wavelength on x, time on y) requires care to avoid rendering artifacts.

## Makie Convention

`heatmap(x, y, z)` expects `z[i, j]` to be plotted at position `(x[i], y[j])`, so `z` must have shape `(length(x), length(y))`.

For TA data with wavelength on x and time on y:
- x = wavelength (2048 elements)
- y = time (151 elements)
- z must be `(2048, 151)` = `data'` (transposed)

## CairoMakie Aliasing

With 2048 wavelength cells on the x-axis and a typical figure width of ~700 pixels, each cell is ~0.34 pixels wide. CairoMakie renders each cell as an individual rectangle, and sub-pixel rectangles alias: some screen pixels show a cell, others don't, creating a striped appearance where the signal looks narrower than it actually is.

GLMakie (GPU-rendered) handles this naturally with shader-based interpolation, so the same code looks fine interactively.

## The Fix

Use `interpolate=true` in the `heatmap!` call:

```julia
heatmap!(ax, wavelength, time, data'; colormap=:RdBu, colorrange=cr, interpolate=true)
```

This tells CairoMakie to interpolate between cells rather than rendering each one individually, matching GLMakie's behavior.

## Summary

```julia
# Correct (standard TA convention, CairoMakie-safe)
heatmap!(ax, matrix.wavelength, matrix.time, matrix.data';
    colormap=:RdBu, colorrange=(-max_abs, max_abs), interpolate=true)

# Also correct (natural matrix layout, no aliasing without interpolate)
heatmap!(ax, matrix.time, matrix.wavelength, matrix.data;
    colormap=:RdBu, colorrange=(-max_abs, max_abs))
```

Both are valid. QPSTools uses the first form to follow TA literature convention.
