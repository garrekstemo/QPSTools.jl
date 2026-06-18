# Cavity Spectroscopy

A cavity transmission spectrum is just an FTIR `Spectrum` loaded by
[`load_spectrum`](@ref) — QPSTools no longer defines a cavity type. Pass
`cavity_length` (and any descriptive sample kwargs like `mirror`, `angle`) and the
loader stamps `cavity_length` as the top-level `:cavity_length` token, so the fit
can pick it up as the cavity length `L`:

```julia
spec = load_spectrum("data/ftir/cavity.csv"; mirror="Au", angle=0, cavity_length=12e-4)
result = fit_cavity_spectrum(spec; oscillators=[(nu0=2055.0, Gamma=23.0)], n_bg=1.4)
```

The fit itself — `fit_cavity_spectrum` (including the `Spectrum` dispatch, which
reads the `:cavity_length` and `:yunit` tokens), plus `fit_dispersion`,
`cavity_mode_energy`, `polariton_branches`, `polariton_eigenvalues`,
`hopfield_coefficients`, `compute_cavity_transmittance`, `cavity_transmittance`,
`refractive_index`, `extinction_coeff`, and the `CavityFitResult` /
`DispersionFitResult` types — all live in
[OpticalSpectroscopy.jl](https://garrekstemo.github.io/OpticalSpectroscopy.jl/);
see its Cavity & Polaritons reference page. QPSTools contributes only the loader
above and the plotting layouts below.

## Plotting

```@docs
plot_dispersion
plot_dispersion!
plot_hopfield
plot_hopfield!
```
