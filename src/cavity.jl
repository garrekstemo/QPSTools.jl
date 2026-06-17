"""
Lab-side dispatch for steady-state spectra.

Steady-state spectra (FTIR, Raman, UV-Vis, cavity transmission) are loaded as
token-stamped `Spectrum`s by `load_spectrum` (src/io.jl) — QPSTools no longer
defines a `CavitySpectrum`/`AnnotatedSpectrum` type. This file adds the lab-side
dispatch on top of OpticalSpectroscopy's generic `Spectrum`: the sample-metadata
accessor, FTIR plotting orientation, and the cavity-aware `fit_cavity_spectrum`.
The physics chain, polariton models, and fitting numerics live in
OpticalSpectroscopy (its src/cavity.jl).
"""

# =============================================================================
# Lab accessors over a token-stamped Spectrum
# =============================================================================

"""
    sample_metadata(s::Spectrum) -> Dict

Sample metadata attached at load time (the loader kwargs), stored under
`metadata[:sample]`. Empty for spectra loaded without sample kwargs.
"""
sample_metadata(s::Spectrum) = get(s.metadata, :sample, Dict{String,Any}())

"""
    xreversed(s::Spectrum) -> Bool

Whether the x-axis should be drawn reversed (FTIR convention: high wavenumber on
the left). Read from `metadata[:xreversed]`; defaults to `false`.
"""
xreversed(s::Spectrum) = get(s.metadata, :xreversed, false)

# =============================================================================
# Physics + fitting: OpticalSpectroscopy
# =============================================================================
# The cavity physics (cavity_transmittance, polariton branches/eigenvalues,
# Hopfield coefficients, dispersion model) and the fitting layer
# (fit_cavity_spectrum, fit_dispersion, CavityFitResult, DispersionFitResult)
# live in OpticalSpectroscopy. QPSTools adds the Spectrum-aware dispatch below.

"""
    fit_cavity_spectrum(spec::Spectrum; kwargs...)

Fit a cavity transmission `Spectrum`. Extracts wavenumber/transmittance,
auto-normalizes percent transmittance (0–100) to fractional, and pulls the
cavity length from sample metadata (`metadata[:sample]["cavity_length"]`) when
`L` is not given. Numerics from `OpticalSpectroscopy`.
"""
function fit_cavity_spectrum(spec::Spectrum; kwargs...)
    nu = xdata(spec)
    T = ydata(spec)
    if maximum(T) > 1.5
        T = T ./ 100.0
    end
    kw = Dict{Symbol, Any}(kwargs)
    sample = sample_metadata(spec)
    if !haskey(kw, :L) && haskey(sample, "cavity_length")
        kw[:L] = sample["cavity_length"]
    end
    return fit_cavity_spectrum(nu, T; kw...)
end

# =============================================================================
# Internal helpers
# =============================================================================

"""Auto-title from sample metadata (`sample - mirror - angle`), or `nothing`."""
function _sample_title(spec::Spectrum)
    sample = sample_metadata(spec)
    parts = String[]

    s = get(sample, "sample", nothing)
    m = get(sample, "mirror", nothing)
    a = get(sample, "angle", nothing)

    isnothing(s) || push!(parts, s)
    isnothing(m) || push!(parts, "$m mirror")
    isnothing(a) || push!(parts, "$(a) deg")

    return isempty(parts) ? nothing : join(parts, " - ")
end
