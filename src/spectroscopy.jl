# QPS-specific spectroscopy dispatches
#
# General-purpose spectroscopy (normalize, smoothing, fitting, baseline,
# unit conversions, transforms, etc.) lives in OpticalSpectroscopy.jl. This
# file adds dispatches that are useful in the QPS lab context for
# JASCOSpectrum and AnnotatedSpectrum, plus the cavity transmittance model.

# ============================================================================
# TRANSMITTANCE ↔ ABSORBANCE: AnnotatedSpectrum dispatches
# ============================================================================

# JASCOFiles 2.0 owns the JASCOSpectrum conversion semantics: the
# transmittance scale is inferred from yunits ("TRANSMITTANCE" = %T,
# "TRANSMITTANCE_FRAC" = fractional), explicit percent overrides, output
# yunits is the canonical "ABSORBANCE", and nonpositive transmittance maps
# to NaN with a warning. These dispatches unwrap and rewrap the
# AnnotatedSpectrum around those methods. OpticalSpectroscopy's vector
# functions remain the owner for raw-vector math.

"""
    transmittance_to_absorbance(spec::AnnotatedSpectrum; percent=nothing)

Convert an annotated spectrum from transmittance to absorbance, `A = -log10(T)`.

The transmittance scale is inferred from the spectrum's `yunits`
(`"TRANSMITTANCE"` = percent, JASCO's convention; `"TRANSMITTANCE_FRAC"` =
fractional); pass `percent` explicitly to override. Returns a new spectrum
of the same type with `yunits = "ABSORBANCE"`; sample metadata and path are
preserved. Semantics from `JASCOFiles`.
"""
function transmittance_to_absorbance(spec::T; percent::Union{Bool,Nothing}=nothing) where T<:AnnotatedSpectrum
    new_data = JASCOFiles.transmittance_to_absorbance(spec.data; percent=percent)
    return T(new_data, spec.sample, spec.path)
end

"""
    absorbance_to_transmittance(spec::AnnotatedSpectrum; percent)

Convert an annotated spectrum from absorbance to transmittance, `T = 10^(-A)`.

`percent` is required: `percent=true` gives percent transmittance
(`yunits = "TRANSMITTANCE"`, JASCO's convention), `percent=false` fractional
(`yunits = "TRANSMITTANCE_FRAC"`). Returns a new spectrum of the same type;
sample metadata and path are preserved. Semantics from `JASCOFiles`.
"""
function absorbance_to_transmittance(spec::T; percent::Bool) where T<:AnnotatedSpectrum
    new_data = JASCOFiles.absorbance_to_transmittance(spec.data; percent=percent)
    return T(new_data, spec.sample, spec.path)
end

# ============================================================================
# SPECTRAL MATH: typed dispatches for AnnotatedSpectrum
# ============================================================================

"""
    savitzky_golay_smooth(spec::AnnotatedSpectrum; kwargs...)

Apply Savitzky-Golay smoothing to an annotated spectrum.
Returns `(x=..., y=...)` NamedTuple.
"""
function savitzky_golay_smooth(spec::AnnotatedSpectrum; kwargs...)
    return (x=xdata(spec), y=savitzky_golay_smooth(ydata(spec); kwargs...))
end

"""
    derivative(spec::AnnotatedSpectrum; kwargs...)

Compute the derivative of an annotated spectrum.
Returns `(x=..., y=...)` NamedTuple.
"""
function derivative(spec::AnnotatedSpectrum; kwargs...)
    return (x=xdata(spec), y=derivative(xdata(spec), ydata(spec); kwargs...))
end

"""
    band_area(spec::AnnotatedSpectrum, x_min, x_max)

Compute the band area of an annotated spectrum within [x_min, x_max].
"""
band_area(spec::AnnotatedSpectrum, x_min::Real, x_max::Real) =
    band_area(xdata(spec), ydata(spec), x_min, x_max)

"""
    normalize_area(spec::AnnotatedSpectrum)

Area-normalize an annotated spectrum. Returns `(x=..., y=...)` NamedTuple.
"""
function normalize_area(spec::AnnotatedSpectrum)
    return (x=xdata(spec), y=normalize_area(xdata(spec), ydata(spec)))
end

"""
    normalize_to_peak(spec::AnnotatedSpectrum, position; kwargs...)

Peak-normalize an annotated spectrum. Returns `(x=..., y=...)` NamedTuple.
"""
function normalize_to_peak(spec::AnnotatedSpectrum, position::Real; kwargs...)
    return (x=xdata(spec), y=normalize_to_peak(xdata(spec), ydata(spec), position; kwargs...))
end

"""
    estimate_snr(spec::AnnotatedSpectrum)

Estimate the SNR of an annotated spectrum.
"""
estimate_snr(spec::AnnotatedSpectrum) = estimate_snr(ydata(spec))

"""
    average_spectra(specs::AnnotatedSpectrum...; interpolate=false)

Average multiple annotated spectra. Uses `xdata`/`ydata` interface.
"""
function average_spectra(first::T, rest::T...; interpolate=false) where T<:AnnotatedSpectrum
    specs = (first, rest...)
    named = ((x=xdata(s), y=ydata(s)) for s in specs)
    return average_spectra(named...; interpolate)
end

