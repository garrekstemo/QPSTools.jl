# QPS-specific spectroscopy dispatches
#
# General-purpose spectroscopy (normalize, smoothing, fitting, baseline,
# unit conversions, transforms, etc.) lives in OpticalSpectroscopy.jl. This
# file adds dispatches that are useful in the QPS lab context for
# JASCOSpectrum and AnnotatedSpectrum, plus the cavity transmittance model.

# ============================================================================
# TRANSMITTANCE ↔ ABSORBANCE: AnnotatedSpectrum dispatches
# ============================================================================

# The conversion NUMERICS are owned by OpticalSpectroscopy (single owner —
# JASCOFiles' JASCOSpectrum methods duplicate the math with the opposite
# percent default and deprecate implicit-default use). These dispatches call
# the OpticalSpectroscopy vector functions with percent passed EXPLICITLY,
# then reconstruct the JASCO wrapper. The default here is percent=true
# because JASCO instruments record percent transmittance (0–100).
# Note: OpticalSpectroscopy throws ArgumentError for nonpositive
# transmittance (JASCOFiles 1.x returned Inf for T = 0).

"""
    transmittance_to_absorbance(spec::AnnotatedSpectrum; percent=true)

Convert an annotated spectrum from transmittance to absorbance, `A = -log10(T)`.

JASCO instruments record percent transmittance (0–100), so `percent=true` is
the default; pass `percent=false` if the y-data is already fractional (0–1).
Returns a new spectrum of the same type with `yunits = "ABS"`; sample
metadata and path are preserved. Numerics from `OpticalSpectroscopy`.
"""
function transmittance_to_absorbance(spec::T; percent::Bool=true) where T<:AnnotatedSpectrum
    d = spec.data
    new_y = OpticalSpectroscopy.transmittance_to_absorbance(d.y; percent=percent)
    new_data = JASCOSpectrum(d.title, d.date, d.spectrometer, d.datatype,
                             d.xunits, "ABS", d.x, new_y, d.metadata)
    return T(new_data, spec.sample, spec.path)
end

"""
    absorbance_to_transmittance(spec::AnnotatedSpectrum; percent=true)

Convert an annotated spectrum from absorbance to transmittance, `T = 10^(-A)`.

Defaults to percent transmittance (`percent=true`, `yunits = "TRANSMITTANCE"`);
pass `percent=false` for fractional transmittance (`yunits =
"TRANSMITTANCE_FRAC"`). Returns a new spectrum of the same type; sample
metadata and path are preserved. Numerics from `OpticalSpectroscopy`.
"""
function absorbance_to_transmittance(spec::T; percent::Bool=true) where T<:AnnotatedSpectrum
    d = spec.data
    new_y = OpticalSpectroscopy.absorbance_to_transmittance(d.y; percent=percent)
    yunits = percent ? "TRANSMITTANCE" : "TRANSMITTANCE_FRAC"
    new_data = JASCOSpectrum(d.title, d.date, d.spectrometer, d.datatype,
                             d.xunits, yunits, d.x, new_y, d.metadata)
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

# ============================================================================
# CAVITY TRANSMITTANCE
# ============================================================================

"""
    cavity_transmittance(p, ν)

Fabry-Perot cavity transmittance with an absorbing medium as a function of frequency.

# Arguments
- `p`: Parameters [n, α, L, R, ϕ]
  - `n`: Refractive index
  - `α`: Absorption coefficient
  - `L`: Cavity length
  - `R`: Mirror reflectance (T = 1 - R assumed)
  - `ϕ`: Phase shift upon reflection
- `ν`: Frequency (independent variable)

```math
\\begin{aligned}
    T(\\nu) = \\frac{(1-R)^2 e^{-\\alpha L}}{1 + R^2 e^{-2\\alpha L} - 2R e^{-\\alpha L} \\cos(4\\pi n L \\nu + 2\\phi)}
\\end{aligned}
```

[https://en.wikipedia.org/wiki/Fabry%E2%80%93P%C3%A9rot_interferometer](https://en.wikipedia.org/wiki/Fabry%E2%80%93P%C3%A9rot_interferometer)
"""
function cavity_transmittance(p, ν)
    n, α, L, R, ϕ = p[1], p[2], p[3], p[4], p[5]
    T = 1 - R
    e = exp(-α * L)
    @. T^2 * e / (1 + R^2 * e^2 - 2 * R * e * cos(4π * n * L * ν + 2 * ϕ))
end
