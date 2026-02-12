"""
Raman spectrum loading and analysis.

Provides `load_raman()` and `search_raman()` for registry-based loading,
plus `plot_raman()` for visualization.
"""

"""
    RamanSpectrum <: AnnotatedSpectrum

Raman spectrum with sample metadata from registry.

# Fields
- `data::JASCOSpectrum` — Raw spectrum from JASCOFiles.jl (includes instrument metadata)
- `sample::Dict{String,Any}` — Sample metadata from registry (laser, exposure, etc.)
- `path::String` — File path

# Accessing data
- Raman shift: `spec.data.x`
- Intensity: `spec.data.y`
- Sample info: `spec.sample["laser_nm"]`
- Instrument info: `spec.data.date`
"""
struct RamanSpectrum <: AnnotatedSpectrum
    data::JASCOSpectrum
    sample::Dict{String, Any}
    path::String
end

# AbstractSpectroscopyData interface
xdata(s::RamanSpectrum) = s.data.x
ydata(s::RamanSpectrum) = s.data.y
xlabel(::RamanSpectrum) = "Raman Shift (cm⁻¹)"
ylabel(::RamanSpectrum) = "Intensity"
source_file(s::RamanSpectrum) = basename(s.path)

# Semantic accessors
"""
    shift(s::RamanSpectrum) -> Vector{Float64}

Return the Raman shift axis (cm⁻¹).
"""
shift(s::RamanSpectrum) = xdata(s)

"""
    intensity(s::RamanSpectrum) -> Vector{Float64}

Return the Raman intensity (counts).
"""
intensity(s::RamanSpectrum) = ydata(s)

function Base.show(io::IO, spec::RamanSpectrum)
    id = get(spec.sample, "_id", "unknown")
    n = length(spec.data.x)
    print(io, "RamanSpectrum(\"$id\", $n points)")
end

function Base.show(io::IO, ::MIME"text/plain", spec::RamanSpectrum)
    println(io, "RamanSpectrum:")

    id = get(spec.sample, "_id", nothing)
    !isnothing(id) && println(io, "  id: $id")

    for key in ["sample", "laser_nm", "exposure_sec", "accumulations", "objective"]
        val = get(spec.sample, key, nothing)
        !isnothing(val) && println(io, "  $key: $val")
    end

    x = spec.data.x
    println(io, "  range: $(round(minimum(x), digits=1)) - $(round(maximum(x), digits=1)) cm⁻¹")
    println(io, "  points: $(length(x))")
    println(io, "  date: $(spec.data.date)")
end

# =============================================================================
# Loading functions
# =============================================================================

"""
    load_raman(; kwargs...) -> RamanSpectrum

Load a single Raman spectrum by metadata query. Errors if not exactly one match.

# Keyword Arguments
Any field in the registry can be used as a filter:
- `sample` — Sample name
- `laser_nm` — Laser wavelength in nm
- `exposure_sec` — Exposure time in seconds
- `objective` — Objective lens used

# Examples
```julia
spec = load_raman(sample="C1")
spec = load_raman(laser_nm=532.05)
```
"""
function load_raman(; kwargs...)
    matches = query_registry(:raman; kwargs...)

    if isempty(matches)
        _annotated_no_match_error(:raman, kwargs)
    elseif length(matches) > 1
        _annotated_multiple_match_error(:raman, matches, kwargs)
    end

    return _load_annotated_entry(matches[1], RamanSpectrum)
end

"""
    search_raman(; kwargs...) -> Vector{RamanSpectrum}

Search for Raman spectra matching filters. Always returns a vector (possibly empty).

# Examples
```julia
all_spectra = search_raman()              # All Raman entries
laser_532 = search_raman(laser_nm=532.05) # Specific laser
```
"""
function search_raman(; kwargs...)
    matches = query_registry(:raman; kwargs...)
    return [_load_annotated_entry(m, RamanSpectrum) for m in matches]
end

"""
    list_raman(; field::Symbol=:sample) -> Vector

List unique values for a given field in the Raman registry.

# Examples
```julia
list_raman()                    # Default: list samples
list_raman(field=:laser_nm)     # [532.05, 785.0, ...]
list_raman(field=:objective)    # ["100x", "50x", ...]
```
"""
function list_raman(; field::Symbol=:sample)
    return list_registry(:raman; field=field)
end

# =============================================================================
# Plotting (thin wrapper around plot_spectrum)
# =============================================================================

"""
    plot_raman(spec::RamanSpectrum; kwargs...)

Convenience alias for `plot_spectrum(spec; kwargs...)`.

See `plot_spectrum(::AnnotatedSpectrum)` for full documentation.

# Examples
```julia
spec = load_raman(sample="C1")

fig, ax = plot_raman(spec)

peaks = find_peaks(spec)
fig, ax = plot_raman(spec; peaks=peaks)

result = fit_peaks(spec, (1000, 1200))
fig, ax, ax_res = plot_raman(spec; fit=result, residuals=true)
```
"""
plot_raman(spec::RamanSpectrum; kwargs...) = plot_spectrum(spec; kwargs...)

# =============================================================================
# Internal helpers
# =============================================================================

function _raman_title(spec::RamanSpectrum)
    parts = String[]

    sample = get(spec.sample, "sample", nothing)
    laser = get(spec.sample, "laser_nm", nothing)

    if !isnothing(sample)
        push!(parts, sample)
    end
    if !isnothing(laser)
        push!(parts, "$(laser) nm")
    end

    return isempty(parts) ? nothing : join(parts, " - ")
end
