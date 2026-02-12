"""
FTIR spectrum loading and analysis.

Provides `load_ftir()` for path-based loading and `plot_ftir()` for visualization.
"""

"""
    FTIRSpectrum <: AnnotatedSpectrum

FTIR spectrum with sample metadata.

# Fields
- `data::JASCOSpectrum` — Raw spectrum from JASCOFiles.jl (includes instrument metadata)
- `sample::Dict{String,Any}` — Sample metadata (solute, concentration, etc.)
- `path::String` — File path

# Accessing data
- Wavenumber: `spec.data.x`
- Absorbance: `spec.data.y`
- Sample info: `spec.sample["concentration"]`
- Instrument info: `spec.data.date`, `spec.data.spectrometer`
"""
struct FTIRSpectrum <: AnnotatedSpectrum
    data::JASCOSpectrum
    sample::Dict{String, Any}
    path::String
end

# AbstractSpectroscopyData interface
xdata(s::FTIRSpectrum) = s.data.x
ydata(s::FTIRSpectrum) = s.data.y
xlabel(::FTIRSpectrum) = "Wavenumber (cm⁻¹)"
source_file(s::FTIRSpectrum) = basename(s.path)

# Dynamic ylabel from JASCO YUNITS field
const _FTIR_YLABEL = Dict(
    "ABSORBANCE" => "Absorbance",
    "TRANSMITTANCE" => "Transmittance (%)",
    "REFLECTANCE" => "Reflectance (%)",
    "SB" => "Single Beam (arb. u.)",
    "INTENSITY" => "Intensity (arb. u.)",
    "Int." => "Interferogram",
)

ylabel(spec::FTIRSpectrum) = get(_FTIR_YLABEL, spec.data.yunits, "Signal")

# FTIR convention: high wavenumber on left
xreversed(::FTIRSpectrum) = true

# Semantic accessors
"""
    wavenumber(s::FTIRSpectrum) -> Vector{Float64}

Return the wavenumber axis (cm⁻¹).
"""
wavenumber(s::FTIRSpectrum) = xdata(s)

"""
    signal(s::FTIRSpectrum) -> Vector{Float64}

Return the y-data regardless of measurement mode (absorbance, transmittance, etc.).
"""
signal(s::FTIRSpectrum) = ydata(s)

"""
    ykind(s::FTIRSpectrum) -> Symbol

Return the kind of y-data as a Symbol (`:absorbance`, `:transmittance`,
`:reflectance`, `:single_beam`, `:intensity`, `:interferogram`, or `:unknown`).
"""
const _FTIR_YKIND = Dict(
    "ABSORBANCE" => :absorbance,
    "TRANSMITTANCE" => :transmittance,
    "REFLECTANCE" => :reflectance,
    "SB" => :single_beam,
    "INTENSITY" => :intensity,
    "Int." => :interferogram,
)

ykind(spec::FTIRSpectrum) = get(_FTIR_YKIND, spec.data.yunits, :unknown)

"""
    absorbance(s::FTIRSpectrum) -> Vector{Float64}

Return y-data, validating that the spectrum contains absorbance data.
Errors if the JASCO YUNITS field indicates a different measurement mode.
"""
function absorbance(spec::FTIRSpectrum)
    ykind(spec) === :absorbance || error(
        "Spectrum contains $(spec.data.yunits) data, not absorbance. " *
        "Use signal(spec) for generic access or transmittance_to_absorbance() to convert."
    )
    return ydata(spec)
end

"""
    transmittance(s::FTIRSpectrum) -> Vector{Float64}

Return y-data, validating that the spectrum contains transmittance data.
Errors if the JASCO YUNITS field indicates a different measurement mode.
"""
function transmittance(spec::FTIRSpectrum)
    ykind(spec) === :transmittance || error(
        "Spectrum contains $(spec.data.yunits) data, not transmittance. " *
        "Use signal(spec) for generic access or absorbance_to_transmittance() to convert."
    )
    return ydata(spec)
end

"""
    reflectance(s::FTIRSpectrum) -> Vector{Float64}

Return y-data, validating that the spectrum contains reflectance data.
Errors if the JASCO YUNITS field indicates a different measurement mode.
"""
function reflectance(spec::FTIRSpectrum)
    ykind(spec) === :reflectance || error(
        "Spectrum contains $(spec.data.yunits) data, not reflectance. " *
        "Use signal(spec) for generic access."
    )
    return ydata(spec)
end

function Base.show(io::IO, spec::FTIRSpectrum)
    label = get(spec.sample, "_id", basename(spec.path))
    n = length(spec.data.x)
    print(io, "FTIRSpectrum(\"$label\", $n points)")
end

function Base.show(io::IO, ::MIME"text/plain", spec::FTIRSpectrum)
    println(io, "FTIRSpectrum:")

    id = get(spec.sample, "_id", nothing)
    if !isnothing(id)
        println(io, "  id: $id")
    else
        println(io, "  file: $(basename(spec.path))")
    end

    for key in ["solute", "solvent", "concentration", "material", "pathlength", "substrate"]
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
    load_ftir(path::String; kwargs...) -> FTIRSpectrum

Load an FTIR spectrum from a JASCO CSV file. Optional kwargs
(e.g., `solute="NH4SCN"`) are stored as metadata for display and eLabFTW.

# Examples
```julia
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv")
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv"; solute="NH4SCN", concentration="1.0M")
```
"""
load_ftir(path::String; kwargs...) = _load_annotated_path(path, FTIRSpectrum; kwargs...)

# =============================================================================
# Plotting (thin wrapper around plot_spectrum)
# =============================================================================

"""
    plot_ftir(spec::FTIRSpectrum; kwargs...)

Convenience alias for `plot_spectrum(spec; kwargs...)`.

See `plot_spectrum(::AnnotatedSpectrum)` for full documentation.

# Examples
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

fig, ax = plot_ftir(spec)

peaks = find_peaks(spec)
fig, ax = plot_ftir(spec; peaks=peaks)

result = fit_peaks(spec, (1950, 2150))
fig, ax, ax_res = plot_ftir(spec; fit=result, residuals=true)
```
"""
plot_ftir(spec::FTIRSpectrum; kwargs...) = plot_spectrum(spec; kwargs...)

plot_ftir(spec::JASCOSpectrum; kwargs...) =
    plot_spectrum(FTIRSpectrum(spec, Dict{String,Any}(), ""); kwargs...)

# =============================================================================
# Internal helpers
# =============================================================================

function _ftir_title(spec::FTIRSpectrum)
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
