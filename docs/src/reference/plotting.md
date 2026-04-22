# Plotting

QPSTools wraps Makie with lab-standard themes, a palette, and a small set of keyword-driven layout helpers. The goal is a single [`plot_spectrum`](@ref) entry point that composes data, fits, peak markers, and residuals into layouts that are consistent across instruments. Convenience aliases (`plot_ftir`, `plot_raman`, `plot_cavity`, `plot_uvvis`) forward to the same core so each instrument's spectrum type gets its own title, axis labels, and orientation without extra boilerplate.

Backends are not a direct dependency — load `CairoMakie` for publication output or `GLMakie` for interactive exploration before calling any plot function.

## Themes and Styling

```@docs
qps_theme
print_theme
poster_theme
lab_colors
lab_linewidths
setup_poster_plot
```

## Spectrum Plotting

[`plot_spectrum`](@ref) dispatches on spectrum type and selects a layout from the supplied keyword arguments (`peaks`, `fit`, `residuals`, `context`). The instrument-specific aliases delegate to it, applying the right axis labels and reversed x-axis convention for FTIR/cavity spectra.

```@docs
plot_spectrum
plot_ftir
plot_raman
plot_cavity
plot_uvvis
plot_data
plot_spectra
```

## Kinetics and Transient Absorption

```@docs
plot_kinetics
plot_ta_heatmap
plot_chirp
plot_chirp!
plot_das
plot_das!
```

## Cavity / Polariton

```@docs
plot_dispersion
plot_dispersion!
plot_hopfield
plot_hopfield!
```

## PL / Raman Mapping

```@docs
plot_pl_map
plot_pl_spectra
```

## Multi-Spectrum Views

```@docs
plot_comparison
plot_waterfall
```

## Layer Functions

These draw onto an existing `Axis` rather than creating a new figure. Use them when you're composing a custom multi-panel layout and want the lab-standard peak markers or fit decomposition on a panel you control.

`plot_peaks!` consumes a `Vector{PeakInfo}` returned by `find_peaks`, and `plot_peak_decomposition!` consumes a [`MultiPeakFitResult`](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/reference/peak_fitting/) from `fit_peaks` — both types live in SpectroscopyTools.

```@docs
plot_peaks!
plot_peak_decomposition!
```
