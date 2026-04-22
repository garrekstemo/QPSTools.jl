"""
QPS-specific data types.

General-purpose types (`AbstractSpectroscopyData`, `TATrace`, `TASpectrum`,
`TAMatrix`, fit result types, etc.) are provided by SpectroscopyTools.jl.

This file defines QPS-specific types:
- `AxisType` — enum for raw LVM axis detection (time vs wavelength)
- `PumpProbeData` — raw LabVIEW LVM pump-probe container
- `AnnotatedSpectrum` — abstract type for JASCO spectra with sample metadata
"""

# =============================================================================
# Raw pump-probe instrument data (LabVIEW LVM files)
# =============================================================================

"""Axis type for raw LVM data: `time_axis` or `wavelength_axis`."""
@enum AxisType time_axis wavelength_axis

"""
    PumpProbeData

Raw pump-probe data from the LabVIEW spectrometer (LVM files).

This is an intermediate container used by `load_lvm`. Users typically don't
interact with this directly — use `load_ta_trace` or `load_ta_spectrum` instead,
which return `TATrace` / `TASpectrum`.

# Fields
- `time::Vector{Float64}` — Time axis (ps) or wavelength axis (nm)
- `on::Matrix{Float64}` — Pump-ON signals (n_points × n_channels)
- `off::Matrix{Float64}` — Pump-OFF signals (n_points × n_channels)
- `diff::Matrix{Float64}` — Lock-in difference (n_points × n_channels)
- `timestamp::String` — Acquisition timestamp from file header
- `axis_type::AxisType` — Whether x-axis is time or wavelength
"""
struct PumpProbeData
    time::Vector{Float64}
    on::Matrix{Float64}
    off::Matrix{Float64}
    diff::Matrix{Float64}
    timestamp::String
    axis_type::AxisType
end

"""Return the x-axis data from raw pump-probe data."""
xaxis(d::PumpProbeData) = d.time

"""Return an appropriate x-axis label based on axis type."""
xaxis_label(d::PumpProbeData) = d.axis_type == time_axis ? "Time (ps)" : "Wavelength (nm)"

# =============================================================================
# Abstract type for JASCO-backed spectra with sample metadata
# =============================================================================

"""
    AnnotatedSpectrum <: AbstractSpectroscopyData

Abstract base type for spectra with attached sample metadata.

Subtypes share common structure:
- `data::JASCOSpectrum` — Raw spectrum from JASCOFiles.jl
- `sample::Dict{String,Any}` — Sample metadata (kwargs from loader)
- `path::String` — File path

This enables shared fitting and analysis code while allowing
technique-specific defaults (axis labels, metadata display, etc.).

Inherits default implementations of `zdata` (returns nothing) and
`is_matrix` (returns false) from AbstractSpectroscopyData.
"""
abstract type AnnotatedSpectrum <: AbstractSpectroscopyData end

# Common interface for all AnnotatedSpectrum subtypes
spectrum_data(s::AnnotatedSpectrum) = s.data
sample_metadata(s::AnnotatedSpectrum) = s.sample
sample_id(s::AnnotatedSpectrum) = get(s.sample, "_id", "unknown")

"""
    xreversed(spec::AnnotatedSpectrum) -> Bool

Whether the x-axis should be reversed when plotting.
Default is `false`. `CavitySpectrum` overrides to `true` (high wavenumber on left).
"""
xreversed(::AnnotatedSpectrum) = false

# =============================================================================
# Shared processing for AnnotatedSpectrum subtypes
# =============================================================================

# Helper: reconstruct a JASCOSpectrum with new x,y from a subtract_spectrum NamedTuple
function _reconstruct_jasco(original::JASCOSpectrum, subtracted::NamedTuple)
    return JASCOSpectrum(original.title, original.date, original.spectrometer,
                         original.datatype, original.xunits, original.yunits,
                         subtracted.x, subtracted.y, original.metadata)
end

"""
    subtract_spectrum(spec::T, ref::T; scale=1.0, interpolate=false) where T<:AnnotatedSpectrum

Subtract a reference spectrum from a sample spectrum. Preserves sample metadata.
Returns a new spectrum of the same type with subtracted data.
"""
function subtract_spectrum(spec::T, ref::T; scale::Real=1.0, interpolate::Bool=false) where T<:AnnotatedSpectrum
    subtracted = subtract_spectrum(spec.data, ref.data; scale=scale, interpolate=interpolate)
    new_data = _reconstruct_jasco(spec.data, subtracted)
    return T(new_data, spec.sample, spec.path)
end

"""
    subtract_spectrum(spec::AnnotatedSpectrum, ref::JASCOSpectrum; scale=1.0, interpolate=false)

Subtract a raw JASCOSpectrum reference from an annotated spectrum.
"""
function subtract_spectrum(spec::T, ref::JASCOSpectrum; scale::Real=1.0, interpolate::Bool=false) where T<:AnnotatedSpectrum
    subtracted = subtract_spectrum(spec.data, ref; scale=scale, interpolate=interpolate)
    new_data = _reconstruct_jasco(spec.data, subtracted)
    return T(new_data, spec.sample, spec.path)
end

"""
    correct_baseline(spec::AnnotatedSpectrum; method=:arpls, kwargs...) -> NamedTuple

Apply baseline correction to an annotated spectrum.

Returns NamedTuple with fields `x`, `y` (corrected), and `baseline`.
"""
function correct_baseline(spec::AnnotatedSpectrum; method::Symbol=:arpls, kwargs...)
    return correct_baseline(spec.data.x, spec.data.y; method=method, kwargs...)
end

# =============================================================================
# Path-based loading helpers
# =============================================================================

"""
    _load_annotated_path(path::String, ::Type{T}; kwargs...) where T<:AnnotatedSpectrum

Load a JASCO file from path into an AnnotatedSpectrum subtype.
Any kwargs are stored in the sample dict for display and eLabFTW tagging.
"""
function _load_annotated_path(path::String, ::Type{T}; kwargs...) where T<:AnnotatedSpectrum
    full_path = abspath(path)
    isfile(full_path) || error("File not found: $full_path")
    spectrum = JASCOSpectrum(full_path)
    sample = Dict{String, Any}(string(k) => v for (k, v) in kwargs)
    return T(spectrum, sample, full_path)
end

# JASCO datatype → technique tag (used by eLabFTW auto-tagging)
const _JASCO_TECHNIQUE_TAG = Dict(
    "INFRARED SPECTRUM" => "ftir",
    "RAMAN SPECTRUM"    => "raman",
    "UV/VISIBLE SPECTRUM" => "uvvis",
)

_jasco_technique_tag(spec::JASCOSpectrum) = get(_JASCO_TECHNIQUE_TAG, spec.datatype, "spectroscopy")
_jasco_technique_tag(spec::AnnotatedSpectrum) = _jasco_technique_tag(spec.data)
