# Cavity Spectroscopy

The lab-side cavity layer: a metadata-aware `fit_cavity_spectrum` dispatch over a
token-stamped `Spectrum` loaded by [`load_spectrum`](@ref). A cavity
transmission spectrum is just an FTIR `Spectrum` carrying cavity sample metadata
(`mirror`, `cavity_length`, `angle`) — QPSTools no longer defines a cavity type.
See [`src/cavity.jl`](https://github.com/garrekstemo/QPSTools.jl/blob/main/src/cavity.jl).

The physics and fitting (`fit_dispersion`, `cavity_mode_energy`, `polariton_branches`, `polariton_eigenvalues`, `hopfield_coefficients`, `compute_cavity_transmittance`, `cavity_transmittance`, `refractive_index`, `extinction_coeff`, and the `CavityFitResult` / `DispersionFitResult` types) live in [OpticalSpectroscopy.jl](https://garrekstemo.github.io/OpticalSpectroscopy.jl/) — see its Cavity & Polaritons reference page.

## Fitting

```@docs
QPSTools.fit_cavity_spectrum(::QPSTools.Spectrum)
```

## Plotting

```@docs
plot_dispersion
plot_dispersion!
plot_hopfield
plot_hopfield!
```
