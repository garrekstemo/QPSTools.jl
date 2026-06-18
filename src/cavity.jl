"""
Lab-side helpers for steady-state spectra.

Steady-state spectra (FTIR, Raman, UV-Vis, cavity transmission) are loaded as
token-stamped `Spectrum`s by `load_spectrum` (src/io.jl) — QPSTools no longer
defines a `CavitySpectrum`/`AnnotatedSpectrum` type. This file holds the lab-side
helpers over OpticalSpectroscopy's generic `Spectrum`: the sample-metadata
accessor, the FTIR plotting orientation, and the auto-title.

The cavity physics, polariton models, and fitting (including the
`fit_cavity_spectrum(::Spectrum)` dispatch, which reads the `:cavity_length` and
`:yunit` tokens) all live in OpticalSpectroscopy (its src/cavity.jl). The
`load_spectrum` loader promotes a `cavity_length` keyword to the top-level
`:cavity_length` token so that dispatch can find it.
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
# (fit_cavity_spectrum — including its Spectrum dispatch — fit_dispersion,
# CavityFitResult, DispersionFitResult) all live in OpticalSpectroscopy and
# reach lab users through `using OpticalSpectroscopy`. A cavity transmission
# Spectrum carries L as the `:cavity_length` token (stamped by load_spectrum)
# and percent transmittance via the `:yunit` token, both of which the
# OpticalSpectroscopy dispatch reads.

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
