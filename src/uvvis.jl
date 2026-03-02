"""
UV-Vis spectrum loading and analysis.

Provides `load_uvvis()` for path-based loading and `plot_uvvis()` for visualization.
"""

"""
    UVVisSpectrum <: AnnotatedSpectrum

UV-Vis spectrum with sample metadata.

# Fields
- `data::JASCOSpectrum` — Raw spectrum from JASCOFiles.jl (includes instrument metadata)
- `sample::Dict{String,Any}` — Sample metadata (solute, concentration, etc.)
- `path::String` — File path

# Accessing data
- Wavelength: `spec.data.x`
- Absorbance/Transmittance: `spec.data.y`
- Sample info: `spec.sample["concentration"]`
- Instrument info: `spec.data.date`, `spec.data.spectrometer`
"""
struct UVVisSpectrum <: AnnotatedSpectrum
    data::JASCOSpectrum
    sample::Dict{String, Any}
    path::String
end

# AbstractSpectroscopyData interface
xdata(s::UVVisSpectrum) = s.data.x
ydata(s::UVVisSpectrum) = s.data.y
xlabel(::UVVisSpectrum) = "Wavelength (nm)"
source_file(s::UVVisSpectrum) = basename(s.path)

# Dynamic ylabel from JASCO YUNITS field
const _UVVIS_YLABEL = Dict(
    "ABSORBANCE" => "Absorbance",
    "ABS" => "Absorbance",
    "TRANSMITTANCE" => "Transmittance (%)",
    "REFLECTANCE" => "Reflectance (%)",
    "INTENSITY" => "Intensity (arb. u.)",
)

ylabel(spec::UVVisSpectrum) = get(_UVVIS_YLABEL, spec.data.yunits, "Signal")

# Semantic accessors
"""
    wavelength(s::UVVisSpectrum) -> Vector{Float64}

Return the wavelength axis (nm).
"""
wavelength(s::UVVisSpectrum) = xdata(s)

"""
    signal(s::UVVisSpectrum) -> Vector{Float64}

Return the y-data regardless of measurement mode (absorbance, transmittance, etc.).
"""
signal(s::UVVisSpectrum) = ydata(s)

"""
    ykind(s::UVVisSpectrum) -> Symbol

Return the kind of y-data as a Symbol (`:absorbance`, `:transmittance`,
`:reflectance`, `:intensity`, or `:unknown`).
"""
const _UVVIS_YKIND = Dict(
    "ABSORBANCE" => :absorbance,
    "ABS" => :absorbance,
    "TRANSMITTANCE" => :transmittance,
    "REFLECTANCE" => :reflectance,
    "INTENSITY" => :intensity,
)

ykind(spec::UVVisSpectrum) = get(_UVVIS_YKIND, spec.data.yunits, :unknown)

"""
    absorbance(s::UVVisSpectrum) -> Vector{Float64}

Return y-data, validating that the spectrum contains absorbance data.
Errors if the JASCO YUNITS field indicates a different measurement mode.
"""
function absorbance(spec::UVVisSpectrum)
    ykind(spec) === :absorbance || error(
        "Spectrum contains $(spec.data.yunits) data, not absorbance. " *
        "Use signal(spec) for generic access or transmittance_to_absorbance() to convert."
    )
    return ydata(spec)
end

"""
    transmittance(s::UVVisSpectrum) -> Vector{Float64}

Return y-data, validating that the spectrum contains transmittance data.
Errors if the JASCO YUNITS field indicates a different measurement mode.
"""
function transmittance(spec::UVVisSpectrum)
    ykind(spec) === :transmittance || error(
        "Spectrum contains $(spec.data.yunits) data, not transmittance. " *
        "Use signal(spec) for generic access or absorbance_to_transmittance() to convert."
    )
    return ydata(spec)
end

"""
    reflectance(s::UVVisSpectrum) -> Vector{Float64}

Return y-data, validating that the spectrum contains reflectance data.
Errors if the JASCO YUNITS field indicates a different measurement mode.
"""
function reflectance(spec::UVVisSpectrum)
    ykind(spec) === :reflectance || error(
        "Spectrum contains $(spec.data.yunits) data, not reflectance. " *
        "Use signal(spec) for generic access."
    )
    return ydata(spec)
end

function Base.show(io::IO, spec::UVVisSpectrum)
    label = get(spec.sample, "_id", basename(spec.path))
    n = length(spec.data.x)
    print(io, "UVVisSpectrum(\"$label\", $n points)")
end

function Base.show(io::IO, ::MIME"text/plain", spec::UVVisSpectrum)
    println(io, "UVVisSpectrum:")

    id = get(spec.sample, "_id", nothing)
    if !isnothing(id)
        println(io, "  id: $id")
    else
        println(io, "  file: $(basename(spec.path))")
    end

    for key in ["solute", "solvent", "concentration", "material", "pathlength"]
        val = get(spec.sample, key, nothing)
        !isnothing(val) && println(io, "  $key: $val")
    end

    x = spec.data.x
    println(io, "  range: $(round(minimum(x), digits=1)) - $(round(maximum(x), digits=1)) $(spec.data.xunits)")
    println(io, "  points: $(length(x))")
    !isempty(spec.data.spectrometer) && println(io, "  instrument: $(spec.data.spectrometer)")
    println(io, "  date: $(spec.data.date)")
end

"""
    load_uvvis(path::String; kwargs...) -> UVVisSpectrum

Load a UV-Vis spectrum from a JASCO CSV file. Optional kwargs
(e.g., `solute="Rhodamine 6G"`) are stored as metadata for display and eLabFTW.

# Examples
```julia
spec = load_uvvis("data/uvvis/rhodamine_6g.csv")
spec = load_uvvis("data/uvvis/rhodamine_6g.csv"; solute="Rhodamine 6G", concentration="10 uM")
```
"""
load_uvvis(path::String; kwargs...) = _load_annotated_path(path, UVVisSpectrum; kwargs...)

# =============================================================================
# Plotting (thin wrapper around plot_spectrum)
# =============================================================================

"""
    plot_uvvis(spec::UVVisSpectrum; kwargs...)

Convenience alias for `plot_spectrum(spec; kwargs...)`.

See `plot_spectrum(::AnnotatedSpectrum)` for full documentation.

# Examples
```julia
spec = load_uvvis("data/uvvis/rhodamine_6g.csv")

fig, ax = plot_uvvis(spec)

peaks = find_peaks(spec)
fig, ax = plot_uvvis(spec; peaks=peaks)

result = fit_peaks(spec, (400, 600))
fig, ax, ax_res = plot_uvvis(spec; fit=result, residuals=true)
```
"""
plot_uvvis(spec::UVVisSpectrum; kwargs...) = plot_spectrum(spec; kwargs...)

plot_uvvis(spec::JASCOSpectrum; kwargs...) =
    plot_spectrum(UVVisSpectrum(spec, Dict{String,Any}(), ""); kwargs...)

# =============================================================================
# Internal helpers
# =============================================================================

function _uvvis_title(spec::UVVisSpectrum)
    parts = String[]

    solute = get(spec.sample, "solute", nothing)
    material = get(spec.sample, "material", nothing)
    conc = get(spec.sample, "concentration", nothing)
    solvent = get(spec.sample, "solvent", nothing)

    if !isnothing(solute)
        push!(parts, solute)
        !isnothing(conc) && push!(parts, conc)
        !isnothing(solvent) && push!(parts, "in $solvent")
    elseif !isnothing(material)
        push!(parts, material)
    end

    return isempty(parts) ? nothing : join(parts, " ")
end
