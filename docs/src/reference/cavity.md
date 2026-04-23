# Cavity Spectroscopy

Polariton dispersion fitting, Hopfield coefficients, and cavity transmittance modelling. See [`src/cavity.jl`](https://github.com/garrekstemo/QPSTools.jl/blob/main/src/cavity.jl).

## Types

```@docs
CavitySpectrum
CavityFitResult
DispersionFitResult
```

## Fitting

```@docs
fit_cavity_spectrum
fit_dispersion
```

## Cavity Physics

```@docs
compute_cavity_transmittance
cavity_transmittance
cavity_mode_energy
polariton_branches
polariton_eigenvalues
hopfield_coefficients
refractive_index
extinction_coeff
```

## Plotting

```@docs
plot_cavity
plot_dispersion
plot_dispersion!
plot_hopfield
plot_hopfield!
```
