# Cavity Spectroscopy

The lab-side cavity layer: a JASCO-backed [`CavitySpectrum`](@ref), [`load_cavity`](@ref), and a metadata-aware [`fit_cavity_spectrum`](@ref) dispatch. See [`src/cavity.jl`](https://github.com/garrekstemo/QPSTools.jl/blob/main/src/cavity.jl).

The physics and fitting (`fit_dispersion`, `cavity_mode_energy`, `polariton_branches`, `polariton_eigenvalues`, `hopfield_coefficients`, `compute_cavity_transmittance`, `cavity_transmittance`, `refractive_index`, `extinction_coeff`, and the `CavityFitResult` / `DispersionFitResult` types) live in [OpticalSpectroscopy.jl](https://garrekstemo.github.io/OpticalSpectroscopy.jl/) — see its Cavity & Polaritons reference page.

## Types

```@docs
CavitySpectrum
```

## Fitting

```@docs
fit_cavity_spectrum
```

## Plotting

```@docs
plot_dispersion
plot_dispersion!
plot_hopfield
plot_hopfield!
```
