# QPS-specific spectroscopy dispatches
#
# General-purpose spectroscopy (normalize, smoothing, fitting, baseline,
# unit conversions, transforms, etc.) lives in SpectroscopyTools.jl. This
# file adds dispatches that are useful in the QPS lab context for
# JASCOSpectrum and AnnotatedSpectrum, plus the cavity transmittance model.

# ============================================================================
# TRANSMITTANCE ↔ ABSORBANCE: AnnotatedSpectrum dispatches
# (JASCOSpectrum conversions live in JASCOFiles.)
# ============================================================================

# AnnotatedSpectrum dispatches delegate to JASCOFiles, which owns the
# JASCOSpectrum conversions. The integration layer's job is to reconstruct
# the wrapper around the converted inner data.
function transmittance_to_absorbance(spec::T; kwargs...) where T<:AnnotatedSpectrum
    new_data = JASCOFiles.transmittance_to_absorbance(spec.data; kwargs...)
    return T(new_data, spec.sample, spec.path)
end

function absorbance_to_transmittance(spec::T; kwargs...) where T<:AnnotatedSpectrum
    new_data = JASCOFiles.absorbance_to_transmittance(spec.data; kwargs...)
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
