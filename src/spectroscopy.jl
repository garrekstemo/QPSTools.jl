# QPS-specific spectroscopy dispatches
#
# General-purpose functions (normalize, time_index, calc_ΔA, smooth_data,
# savitzky_golay, calc_fwhm, subtract_spectrum for NamedTuple, etc.)
# are provided by SpectroscopyTools.jl.
#
# This file adds QPS-specific dispatches for JASCOSpectrum, FTIRSpectrum,
# and RamanSpectrum types.

# ============================================================================
# TRANSMITTANCE ↔ ABSORBANCE: JASCOSpectrum and AnnotatedSpectrum dispatches
# ============================================================================

"""
    transmittance_to_absorbance(spec::JASCOSpectrum; percent=true)

Convert a JASCOSpectrum from transmittance to absorbance.

JASCO instruments record percent transmittance (0–100) by default.
Set `percent=false` if the data is fractional transmittance (0–1).

Returns a new `JASCOSpectrum` with absorbance y-axis.
"""
function transmittance_to_absorbance(spec::JASCOSpectrum; percent::Bool=true)
    new_y = transmittance_to_absorbance(spec.y; percent=percent)
    return JASCOSpectrum(spec.title, spec.date, spec.spectrometer, spec.datatype,
                         spec.xunits, "ABS", spec.x, new_y, spec.metadata)
end

function transmittance_to_absorbance(spec::FTIRSpectrum; kwargs...)
    new_data = transmittance_to_absorbance(spec.data; kwargs...)
    return FTIRSpectrum(new_data, spec.sample, spec.path)
end

function transmittance_to_absorbance(spec::RamanSpectrum; kwargs...)
    new_data = transmittance_to_absorbance(spec.data; kwargs...)
    return RamanSpectrum(new_data, spec.sample, spec.path)
end

"""
    absorbance_to_transmittance(spec::JASCOSpectrum; percent=true)

Convert a JASCOSpectrum from absorbance to transmittance.

Returns a new `JASCOSpectrum` with transmittance y-axis. Defaults to percent
transmittance (`percent=true`).
"""
function absorbance_to_transmittance(spec::JASCOSpectrum; percent::Bool=true)
    new_y = absorbance_to_transmittance(spec.y; percent=percent)
    yunits = percent ? "TRANSMITTANCE" : "TRANSMITTANCE_FRAC"
    return JASCOSpectrum(spec.title, spec.date, spec.spectrometer, spec.datatype,
                         spec.xunits, yunits, spec.x, new_y, spec.metadata)
end

function absorbance_to_transmittance(spec::FTIRSpectrum; kwargs...)
    new_data = absorbance_to_transmittance(spec.data; kwargs...)
    return FTIRSpectrum(new_data, spec.sample, spec.path)
end

function absorbance_to_transmittance(spec::RamanSpectrum; kwargs...)
    new_data = absorbance_to_transmittance(spec.data; kwargs...)
    return RamanSpectrum(new_data, spec.sample, spec.path)
end

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

