"""
FTIR spectrum loading and analysis.

Provides `load_ftir()` and `search_ftir()` for registry-based loading,
plus `plot_ftir()` for visualization.
"""

"""
    FTIRSpectrum <: AnnotatedSpectrum

FTIR spectrum with sample metadata from registry.

# Fields
- `data::JASCOSpectrum` — Raw spectrum from JASCOFiles.jl (includes instrument metadata)
- `sample::Dict{String,Any}` — Sample metadata from registry (solute, concentration, etc.)
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
ylabel(::FTIRSpectrum) = "Absorbance"
source_file(s::FTIRSpectrum) = basename(s.path)

# FTIR convention: high wavenumber on left
xreversed(::FTIRSpectrum) = true

function Base.show(io::IO, spec::FTIRSpectrum)
    id = get(spec.sample, "_id", "unknown")
    n = length(spec.data.x)
    print(io, "FTIRSpectrum(\"$id\", $n points)")
end

function Base.show(io::IO, ::MIME"text/plain", spec::FTIRSpectrum)
    println(io, "FTIRSpectrum:")

    id = get(spec.sample, "_id", nothing)
    !isnothing(id) && println(io, "  id: $id")

    for key in ["solute", "solvent", "concentration", "material", "pathlength", "substrate"]
        val = get(spec.sample, key, nothing)
        !isnothing(val) && println(io, "  $key: $val")
    end

    x = spec.data.x
    println(io, "  range: $(round(minimum(x), digits=1)) - $(round(maximum(x), digits=1)) $(spec.data.xunits)")
    println(io, "  points: $(length(x))")
    println(io, "  date: $(spec.data.date)")
end

"""
    load_ftir(; kwargs...) -> FTIRSpectrum

Load a single FTIR spectrum by metadata query. Errors if not exactly one match.

# Keyword Arguments
Any field in the registry can be used as a filter:
- `solute` — Solute name (e.g., "NH4SCN")
- `solvent` — Solvent name (e.g., "DMF")
- `concentration` — Concentration string (e.g., "1.0M")
- `material` — Material name (for references)
- `pathlength` — Cell pathlength in μm
- `substrate` — Window/substrate material

# Examples
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
ref = load_ftir(material="DMF", pathlength=12.0)
```
"""
function load_ftir(; kwargs...)
    matches = query_registry(:ftir; kwargs...)

    if isempty(matches)
        _annotated_no_match_error(:ftir, kwargs)
    elseif length(matches) > 1
        _annotated_multiple_match_error(:ftir, matches, kwargs)
    end

    return _load_annotated_entry(matches[1], FTIRSpectrum)
end

"""
    search_ftir(; kwargs...) -> Vector{FTIRSpectrum}

Search for FTIR spectra matching filters. Always returns a vector (possibly empty).

# Examples
```julia
all_concs = search_ftir(solute="NH4SCN")   # All concentrations
all_refs = search_ftir(material="DMF")      # All DMF references
everything = search_ftir()                  # All FTIR entries
```
"""
function search_ftir(; kwargs...)
    matches = query_registry(:ftir; kwargs...)
    return [_load_annotated_entry(m, FTIRSpectrum) for m in matches]
end

"""
    list_ftir(; field::Symbol=:concentration) -> Vector

List unique values for a given field in the FTIR registry.

# Examples
```julia
list_ftir()                        # Default: list concentrations
list_ftir(field=:solvent)          # ["DMF", "DMSO", ...]
list_ftir(field=:solute)           # ["NH4SCN", "W(CO)6", ...]
```
"""
function list_ftir(; field::Symbol=:concentration)
    return list_registry(:ftir; field=field)
end

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
fig, ax = plot_ftir(spec; labels=true)

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
