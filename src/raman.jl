"""
Raman spectrum loading and analysis.

Provides `load_raman()` for path-based loading and `plot_raman()` for visualization.
"""

"""
    RamanSpectrum <: AnnotatedSpectrum

Raman spectrum with sample metadata.

# Fields
- `data::JASCOSpectrum` — Raw spectrum from JASCOFiles.jl (includes instrument metadata)
- `sample::Dict{String,Any}` — Sample metadata (material, laser, exposure, etc.)
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
    label = get(spec.sample, "_id", basename(spec.path))
    n = length(spec.data.x)
    print(io, "RamanSpectrum(\"$label\", $n points)")
end

function Base.show(io::IO, ::MIME"text/plain", spec::RamanSpectrum)
    println(io, "RamanSpectrum:")

    id = get(spec.sample, "_id", nothing)
    if !isnothing(id)
        println(io, "  id: $id")
    else
        println(io, "  file: $(basename(spec.path))")
    end

    for key in ["sample", "material", "laser_nm", "exposure_sec", "accumulations", "objective"]
        val = get(spec.sample, key, nothing)
        !isnothing(val) && println(io, "  $key: $val")
    end

    x = spec.data.x
    println(io, "  range: $(round(minimum(x), digits=1)) - $(round(maximum(x), digits=1)) cm⁻¹")
    println(io, "  points: $(length(x))")
    !isempty(spec.data.spectrometer) && println(io, "  instrument: $(spec.data.spectrometer)")
    println(io, "  date: $(spec.data.date)")
end

# =============================================================================
# Loading functions
# =============================================================================

"""
    load_raman(path::String; kwargs...) -> RamanSpectrum

Load a Raman spectrum from a JASCO CSV file. Optional kwargs
(e.g., `material="MoSe2"`) are stored as metadata for display and eLabFTW.

# Examples
```julia
spec = load_raman("data/raman/MoSe2_center.csv")
spec = load_raman("data/raman/MoSe2_center.csv"; material="MoSe2", sample="center")
```
"""
load_raman(path::String; kwargs...) = _load_annotated_path(path, RamanSpectrum; kwargs...)

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
