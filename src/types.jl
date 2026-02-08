"""
QPS-specific data types.

General-purpose types (AbstractSpectroscopyData, TATrace, TASpectrum, TAMatrix,
fit result types, etc.) are provided by SpectroscopyTools.jl.

This file defines only QPS-specific types:
- `AnnotatedSpectrum` — abstract type for JASCO spectra with registry metadata
- `FTIRFitResult` — alias for `MultiPeakFitResult`
"""

# =============================================================================
# Abstract types for JASCO spectra
# =============================================================================

"""
    AnnotatedSpectrum <: AbstractSpectroscopyData

Abstract base type for spectra with attached sample metadata from the registry.

Subtypes share common structure:
- `data::JASCOSpectrum` — Raw spectrum from JASCOFiles.jl
- `sample::Dict{String,Any}` — Sample metadata from registry
- `path::String` — File path

This enables shared fitting and analysis code while allowing
technique-specific defaults (axis labels, metadata display, etc.).

Inherits default implementations of `zdata` (returns nothing) and
`is_matrix` (returns false) from AbstractSpectroscopyData.
"""
abstract type AnnotatedSpectrum <: AbstractSpectroscopyData end

"""Convenience alias: `FTIRFitResult === MultiPeakFitResult`."""
const FTIRFitResult = MultiPeakFitResult

# Common interface for all AnnotatedSpectrum subtypes
spectrum_data(s::AnnotatedSpectrum) = s.data
sample_metadata(s::AnnotatedSpectrum) = s.sample
sample_id(s::AnnotatedSpectrum) = get(s.sample, "_id", "unknown")

"""
    xreversed(spec::AnnotatedSpectrum) -> Bool

Whether the x-axis should be reversed when plotting.
Default is `false`. FTIR overrides to `true` (high wavenumber on left).
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
# Shared registry loading helpers
# =============================================================================

"""Load a single registry entry into an AnnotatedSpectrum subtype."""
function _load_annotated_entry(entry::Dict, ::Type{T}) where T<:AnnotatedSpectrum
    data_dir = get_data_dir()
    rel_path = entry["path"]
    full_path = joinpath(data_dir, rel_path)

    if !isfile(full_path)
        error("File not found: $full_path")
    end

    spectrum = JASCOSpectrum(full_path)
    return T(spectrum, entry, full_path)
end

"""Format and throw a 'no match' error for registry queries."""
function _annotated_no_match_error(category::Symbol, kwargs)
    println("\nNo $(category) entries match query:")
    for (k, v) in kwargs
        println("  $k = $v")
    end

    println("\nAvailable entries:")
    all_entries = query_registry(category)
    for entry in all_entries
        id = entry["_id"]
        detail = get(entry, "concentration", get(entry, "sample", get(entry, "material", "")))
        println("  $id ($detail)")
    end

    error("No matching $(category) data found")
end

"""Format and throw a 'multiple matches' error for registry queries."""
function _annotated_multiple_match_error(category::Symbol, matches, kwargs)
    println("\nMultiple $(category) entries match query:")
    for (k, v) in kwargs
        println("  $k = $v")
    end

    println("\nMatches:")
    for entry in matches
        id = entry["_id"]
        detail = get(entry, "concentration", get(entry, "sample", get(entry, "material", "")))
        println("  $id ($detail)")
    end

    error("Multiple matches found ($(length(matches))). Add more filters.")
end
