"""
Cavity spectroscopy analysis: types, physics, and fitting.

Provides tools for fitting Fabry-Perot cavity transmission spectra with
Lorentz oscillator models, extracting polariton peak positions, building
dispersion curves, and fitting the coupled oscillator model to extract
Rabi splitting and Hopfield coefficients.

Physics chain:
1. Multi-oscillator dielectric function (CurveFitModels: `dielectric_real`, `dielectric_imag`)
2. Complex refractive index from dielectric function (`refractive_index`, `extinction_coeff`)
3. Absorption coefficient from extinction coefficient
4. Fabry-Perot Airy function (`cavity_transmittance` from spectroscopy.jl)
"""

# =============================================================================
# Type: CavitySpectrum
# =============================================================================

"""
    CavitySpectrum <: AnnotatedSpectrum

Cavity FTIR transmission spectrum with sample metadata.

# Fields
- `data::JASCOSpectrum` - Raw spectrum from JASCOFiles.jl
- `sample::Dict{String,Any}` - Sample metadata (mirror, cavity_length, angle, etc.)
- `path::String` - File path

# Accessing data
- Wavenumber: `spec.data.x`
- Transmittance: `spec.data.y`
- Sample info: `spec.sample["mirror"]`, `spec.sample["angle"]`
"""
struct CavitySpectrum <: AnnotatedSpectrum
    data::JASCOSpectrum
    sample::Dict{String, Any}
    path::String
end

# AbstractSpectroscopyData interface
xdata(s::CavitySpectrum) = s.data.x
ydata(s::CavitySpectrum) = s.data.y
xlabel(::CavitySpectrum) = "Wavenumber (cm⁻¹)"
ylabel(::CavitySpectrum) = "Transmittance (%)"
source_file(s::CavitySpectrum) = basename(s.path)

# FTIR convention: high wavenumber on left
xreversed(::CavitySpectrum) = true

# Semantic accessors
"""
    wavenumber(s::CavitySpectrum) -> Vector{Float64}

Return the wavenumber axis (cm⁻¹).
"""
wavenumber(s::CavitySpectrum) = xdata(s)

"""
    transmittance(s::CavitySpectrum) -> Vector{Float64}

Return the transmittance signal (%).
"""
transmittance(s::CavitySpectrum) = ydata(s)

function Base.show(io::IO, spec::CavitySpectrum)
    label = get(spec.sample, "_id", basename(spec.path))
    n = length(spec.data.x)
    print(io, "CavitySpectrum(\"$label\", $n points)")
end

function Base.show(io::IO, ::MIME"text/plain", spec::CavitySpectrum)
    println(io, "CavitySpectrum:")

    id = get(spec.sample, "_id", nothing)
    if !isnothing(id)
        println(io, "  id: $id")
    else
        println(io, "  file: $(basename(spec.path))")
    end

    for key in ["sample", "mirror", "cavity_length", "angle", "solute", "concentration", "solvent"]
        val = get(spec.sample, key, nothing)
        !isnothing(val) && println(io, "  $key: $val")
    end

    x = spec.data.x
    println(io, "  range: $(round(minimum(x), digits=1)) - $(round(maximum(x), digits=1)) $(spec.data.xunits)")
    println(io, "  points: $(length(x))")
    !isempty(spec.data.spectrometer) && println(io, "  instrument: $(spec.data.spectrometer)")
    println(io, "  date: $(something(spec.data.date, "unknown"))")
end
# =============================================================================
# Physics + fitting: CavitySpectroscopy.jl
# =============================================================================
# The cavity physics (cavity_transmittance, polariton branches/eigenvalues,
# Hopfield coefficients, dispersion model) and the fitting layer
# (fit_cavity_spectrum, fit_dispersion, CavityFitResult, DispersionFitResult)
# live in the public CavitySpectroscopy.jl package. QPSTools re-exports those
# names (see QPSTools.jl) and adds the JASCO-aware dispatches below.

"""
    fit_cavity_spectrum(spec::CavitySpectrum; kwargs...)

Fit a JASCO-backed `CavitySpectrum`. Extracts wavenumber/transmittance,
auto-normalizes percent transmittance (0–100) to fractional, and pulls the
cavity length from sample metadata (`"cavity_length"`) when `L` is not
given. Numerics from `CavitySpectroscopy`.
"""
function fit_cavity_spectrum(spec::CavitySpectrum; kwargs...)
    nu = xdata(spec)
    T = ydata(spec)
    if maximum(T) > 1.5
        T = T ./ 100.0
    end
    kw = Dict{Symbol, Any}(kwargs)
    if !haskey(kw, :L) && haskey(spec.sample, "cavity_length")
        kw[:L] = spec.sample["cavity_length"]
    end
    return fit_cavity_spectrum(nu, T; kw...)
end

# Markdown reporting: route OpticalSpectroscopy's format_results generic
# (the one QPSTools users have loaded) to CavitySpectroscopy's methods.
OpticalSpectroscopy.format_results(r::CavityFitResult) =
    CavitySpectroscopy.format_results(r)
OpticalSpectroscopy.format_results(r::DispersionFitResult) =
    CavitySpectroscopy.format_results(r)


# =============================================================================
# Loading
# =============================================================================

"""
    load_cavity(path::String; kwargs...) -> CavitySpectrum

Load a cavity spectrum from a JASCO CSV file. Optional kwargs
(e.g., `mirror="Au"`, `angle=10`) are stored as metadata for display and eLabFTW.

# Examples
```julia
spec = load_cavity("data/cavity/Au_0deg.csv")
spec = load_cavity("data/cavity/Au_0deg.csv"; mirror="Au", angle=0, cavity_length=12e-4)
```
"""
load_cavity(path::String; kwargs...) = _load_annotated_path(path, CavitySpectrum; kwargs...)

# =============================================================================
# Plotting alias
# =============================================================================

"""
    plot_cavity(spec::CavitySpectrum; kwargs...)

Convenience alias for `plot_spectrum(spec; kwargs...)`.

See `plot_spectrum(::AnnotatedSpectrum)` for full documentation.
"""
plot_cavity(spec::CavitySpectrum; kwargs...) = plot_spectrum(spec; kwargs...)

# =============================================================================
# Internal helpers
# =============================================================================

function _cavity_title(spec::CavitySpectrum)
    parts = String[]

    sample = get(spec.sample, "sample", nothing)
    mirror = get(spec.sample, "mirror", nothing)
    angle = get(spec.sample, "angle", nothing)

    if !isnothing(sample)
        push!(parts, sample)
    end
    if !isnothing(mirror)
        push!(parts, "$mirror mirror")
    end
    if !isnothing(angle)
        push!(parts, "$(angle) deg")
    end

    return isempty(parts) ? nothing : join(parts, " - ")
end
