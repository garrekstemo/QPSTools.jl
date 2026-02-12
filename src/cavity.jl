"""
Cavity spectroscopy analysis: types, physics, fitting, and registry loading.

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

Cavity FTIR transmission spectrum with sample metadata from registry.

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
    id = get(spec.sample, "_id", "unknown")
    n = length(spec.data.x)
    print(io, "CavitySpectrum(\"$id\", $n points)")
end

function Base.show(io::IO, ::MIME"text/plain", spec::CavitySpectrum)
    println(io, "CavitySpectrum:")

    id = get(spec.sample, "_id", nothing)
    !isnothing(id) && println(io, "  id: $id")

    for key in ["sample", "mirror", "cavity_length", "angle", "solute", "concentration", "solvent"]
        val = get(spec.sample, key, nothing)
        !isnothing(val) && println(io, "  $key: $val")
    end

    x = spec.data.x
    println(io, "  range: $(round(minimum(x), digits=1)) - $(round(maximum(x), digits=1)) $(spec.data.xunits)")
    println(io, "  points: $(length(x))")
    println(io, "  date: $(spec.data.date)")
end

# =============================================================================
# Physics functions
# =============================================================================

"""
    refractive_index(eps1, eps2)

Compute refractive index n from real (eps1) and imaginary (eps2) parts of
the dielectric function.

n = sqrt((sqrt(eps1^2 + eps2^2) + eps1) / 2)
"""
function refractive_index(eps1, eps2)
    @. sqrt(0.5 * (eps1 + sqrt(eps1^2 + eps2^2)))
end

"""
    extinction_coeff(eps1, eps2)

Compute extinction coefficient k from real (eps1) and imaginary (eps2) parts of
the dielectric function.

k = sqrt((sqrt(eps1^2 + eps2^2) - eps1) / 2)
"""
function extinction_coeff(eps1, eps2)
    @. sqrt(0.5 * (-eps1 + sqrt(eps1^2 + eps2^2)))
end

"""
    compute_cavity_transmittance(nu::Number, nu0s, Gammas, As, R, L, n_bg, phi)

Compute cavity transmittance at a single frequency for multiple Lorentzian oscillators.

Builds the full physics chain:
1. Sum Lorentz oscillator dielectric contributions
2. Compute complex refractive index (n, k) from dielectric function
3. Compute absorption coefficient alpha = 4pi * k * nu
4. Feed into Fabry-Perot Airy function

# Arguments
- `nu`: Frequency (cm^-1)
- `nu0s`: Vector of oscillator center frequencies (cm^-1)
- `Gammas`: Vector of oscillator linewidths (cm^-1)
- `As`: Vector of oscillator amplitudes/strengths (cm^-2)
- `R`: Mirror reflectivity
- `L`: Cavity length (cm)
- `n_bg`: Background refractive index
- `phi`: Phase shift upon reflection

ForwardDiff-compatible.
"""
function compute_cavity_transmittance(nu::Number, nu0s, Gammas, As, R, L, n_bg, phi)
    # Build dielectric function from all oscillators
    eps1 = n_bg^2
    eps2 = 0.0

    for i in eachindex(nu0s, Gammas, As)
        eps1 += dielectric_real((As[i], nu0s[i], Gammas[i]), nu)
        eps2 += dielectric_imag((As[i], nu0s[i], Gammas[i]), nu)
    end

    # Complex refractive index
    n = sqrt((sqrt(eps1^2 + eps2^2) + eps1) / 2)
    k = sqrt((sqrt(eps1^2 + eps2^2) - eps1) / 2)

    # Absorption coefficient
    alpha = 4pi * k * nu

    # Fabry-Perot transmittance
    return cavity_transmittance((n, alpha, L, R, phi), nu)
end

"""
    compute_cavity_transmittance(nus::AbstractArray, nu0s, Gammas, As, R, L, n_bg, phi)

Array dispatch: compute cavity transmittance for multiple frequencies.
"""
function compute_cavity_transmittance(nus::AbstractArray, nu0s, Gammas, As, R, L, n_bg, phi)
    return [compute_cavity_transmittance(nu, nu0s, Gammas, As, R, L, n_bg, phi) for nu in nus]
end

"""
    cavity_mode_energy(p, thetas)

Compute cavity photon energy as a function of incidence angle.

E_cav(theta) = E0 / sqrt(1 - (sin(theta) / n_eff)^2)

# Arguments
- `p`: Parameters [E0, n_eff] where E0 is normal-incidence cavity energy
  and n_eff is effective refractive index
- `thetas`: Incidence angles (radians)
"""
function cavity_mode_energy(p, thetas)
    E0, n_eff = p
    @. E0 / sqrt(1 - (sin(thetas) / n_eff)^2)
end

"""
    polariton_branches(E_cav, E_vib, Omega)

Compute upper and lower polariton energies from the 2-level coupled oscillator model.

E_pm = (E_cav + E_vib) / 2 +/- sqrt(Omega^2 + (E_cav - E_vib)^2) / 2

# Arguments
- `E_cav`: Cavity photon energy (scalar or vector)
- `E_vib`: Vibrational mode energy (scalar)
- `Omega`: Rabi splitting (scalar)

# Returns
`(E_LP, E_UP)` — lower and upper polariton energies, same shape as `E_cav`.
"""
function polariton_branches(E_cav, E_vib, Omega)
    delta = @. sqrt(Omega^2 + (E_cav - E_vib)^2)
    E_LP = @. 0.5 * (E_vib + E_cav - delta)
    E_UP = @. 0.5 * (E_vib + E_cav + delta)
    return E_LP, E_UP
end

"""
    polariton_eigenvalues(E_cav, E_vibs, Omegas)

Compute polariton energies for N vibrational modes coupled to one cavity mode.

Builds the (N+1) x (N+1) Hamiltonian and returns sorted eigenvalues.
For a single vibrational mode, this reduces to `polariton_branches`.

# Arguments
- `E_cav`: Cavity photon energy (scalar)
- `E_vibs`: Vector of vibrational mode energies
- `Omegas`: Vector of Rabi splittings (one per mode)

# Returns
Sorted vector of N+1 eigenvalues (polariton energies).
"""
function polariton_eigenvalues(E_cav, E_vibs, Omegas)
    N = length(E_vibs)
    @assert length(Omegas) == N "Need one Rabi splitting per vibrational mode"

    H = zeros(N + 1, N + 1)
    H[1, 1] = E_cav
    for i in eachindex(E_vibs)
        H[i + 1, i + 1] = E_vibs[i]
        H[1, i + 1] = Omegas[i] / 2
        H[i + 1, 1] = Omegas[i] / 2
    end

    return sort(eigvals(H))
end

"""
    hopfield_coefficients(E_cav, E_vib, Omega)

Compute Hopfield coefficients (light-matter mixing fractions) for the
2-level coupled oscillator model.

At a given detuning (E_cav - E_vib), returns the photonic and matter
fractions for the lower and upper polariton branches.

# Arguments
- `E_cav`: Cavity photon energy (scalar or vector)
- `E_vib`: Vibrational mode energy (scalar)
- `Omega`: Rabi splitting (scalar)

# Returns
Named tuple `(photon_LP, matter_LP, photon_UP, matter_UP)`.
Each element has the same shape as `E_cav`.
Values satisfy: photon + matter = 1 for each branch.
"""
function hopfield_coefficients(E_cav, E_vib, Omega)
    delta = @. E_cav - E_vib
    theta = @. 0.5 * atan(Omega, delta)

    # |C|^2 = cos^2(theta) is photon fraction of LP
    photon_LP = @. cos(theta)^2
    matter_LP = @. sin(theta)^2
    photon_UP = matter_LP
    matter_UP = photon_LP

    return (photon_LP=photon_LP, matter_LP=matter_LP,
            photon_UP=photon_UP, matter_UP=matter_UP)
end

# =============================================================================
# Result types
# =============================================================================

"""
    CavityFitResult

Result from fitting a single cavity transmission spectrum.

# Fields
- `R`: Mirror reflectivity
- `L`: Cavity length (cm)
- `n_bg`: Background refractive index
- `phi`: Phase shift
- `scale`: Scale factor applied to transmittance
- `offset`: Baseline offset
- `oscillators`: Vector of NamedTuples `(nu0, Gamma, A)` for each oscillator
- `polariton_peaks`: Vector of peak positions (cm^-1) extracted from fit
- `rsquared`: R^2 goodness of fit
- `_nu`: Wavenumber array used in fit (internal)
- `_T_data`: Transmittance data used in fit (internal)
- `_sol`: CurveFit solution object (internal)
"""
struct CavityFitResult
    R::Float64
    L::Float64
    n_bg::Float64
    phi::Float64
    scale::Float64
    offset::Float64
    oscillators::Vector{NamedTuple{(:nu0, :Gamma, :A), Tuple{Float64, Float64, Float64}}}
    polariton_peaks::Vector{Float64}
    rsquared::Float64
    _nu::Vector{Float64}
    _T_data::Vector{Float64}
    _sol::Any
end

xdata(r::CavityFitResult) = r._nu
ydata(r::CavityFitResult) = r._T_data

"""
    wavenumber(r::CavityFitResult) -> Vector{Float64}

Return the wavenumber array used in the fit.
"""
wavenumber(r::CavityFitResult) = r._nu

"""
    transmittance(r::CavityFitResult) -> Vector{Float64}

Return the transmittance data used in the fit.
"""
transmittance(r::CavityFitResult) = r._T_data

"""
    predict(result::CavityFitResult)

Return fitted transmittance on the original wavenumber grid.
"""
function SpectroscopyTools.predict(result::CavityFitResult)
    return predict(result, result._nu)
end

"""
    predict(result::CavityFitResult, nu)

Return fitted transmittance on a custom wavenumber array.
"""
function SpectroscopyTools.predict(result::CavityFitResult, nu::AbstractVector)
    nu0s = [osc.nu0 for osc in result.oscillators]
    Gammas = [osc.Gamma for osc in result.oscillators]
    As = [osc.A for osc in result.oscillators]
    T = compute_cavity_transmittance(nu, nu0s, Gammas, As, result.R, result.L, result.n_bg, result.phi)
    return T .* result.scale .+ result.offset
end

"""
    residuals(result::CavityFitResult)

Return residuals (data - fit) on the original wavenumber grid.
"""
function SpectroscopyTools.residuals(result::CavityFitResult)
    return result._T_data .- predict(result)
end

function Base.show(io::IO, r::CavityFitResult)
    n_osc = length(r.oscillators)
    n_peaks = length(r.polariton_peaks)
    print(io, "CavityFitResult($n_osc oscillator$(n_osc == 1 ? "" : "s"), $n_peaks polariton peak$(n_peaks == 1 ? "" : "s"), R^2=$(round(r.rsquared, digits=4)))")
end

function Base.show(io::IO, ::MIME"text/plain", r::CavityFitResult)
    println(io, "Cavity Spectrum Fit")
    println(io, "=" ^ 50)

    println(io, "\nCavity parameters:")
    println(io, "  R       = $(round(r.R, digits=4))")
    println(io, "  L       = $(r.L) cm")
    println(io, "  n_bg    = $(round(r.n_bg, digits=3))")
    println(io, "  phi     = $(round(r.phi, digits=4))")
    println(io, "  scale   = $(round(r.scale, digits=4))")
    println(io, "  offset  = $(round(r.offset, digits=4))")

    if !isempty(r.oscillators)
        println(io, "\nOscillators:")
        for (i, osc) in enumerate(r.oscillators)
            println(io, "  [$i] nu0 = $(round(osc.nu0, digits=1)) cm^-1, Gamma = $(round(osc.Gamma, digits=1)) cm^-1, A = $(round(osc.A, digits=1))")
        end
    end

    if !isempty(r.polariton_peaks)
        println(io, "\nPolariton peaks:")
        for (i, pk) in enumerate(r.polariton_peaks)
            println(io, "  [$i] $(round(pk, digits=1)) cm^-1")
        end
    end

    println(io, "\nR^2 = $(round(r.rsquared, digits=6))")
end

"""
    format_results(r::CavityFitResult) -> String

Format cavity fit results as a markdown table.
"""
function SpectroscopyTools.format_results(r::CavityFitResult)
    lines = String[]
    push!(lines, "## Cavity Spectrum Fit\n")

    push!(lines, "| Parameter | Value |")
    push!(lines, "|-----------|-------|")
    push!(lines, "| R | $(round(r.R, digits=4)) |")
    push!(lines, "| L | $(r.L) cm |")
    push!(lines, "| n_bg | $(round(r.n_bg, digits=3)) |")
    push!(lines, "| phi | $(round(r.phi, digits=4)) |")
    push!(lines, "| scale | $(round(r.scale, digits=4)) |")
    push!(lines, "| offset | $(round(r.offset, digits=4)) |")
    push!(lines, "| R^2 | $(round(r.rsquared, digits=6)) |")

    if !isempty(r.oscillators)
        push!(lines, "\n### Oscillators\n")
        push!(lines, "| # | nu0 (cm^-1) | Gamma (cm^-1) | A |")
        push!(lines, "|---|-------------|---------------|---|")
        for (i, osc) in enumerate(r.oscillators)
            push!(lines, "| $i | $(round(osc.nu0, digits=1)) | $(round(osc.Gamma, digits=1)) | $(round(osc.A, digits=1)) |")
        end
    end

    if !isempty(r.polariton_peaks)
        push!(lines, "\n### Polariton Peaks\n")
        push!(lines, "| # | Position (cm^-1) |")
        push!(lines, "|---|-----------------|")
        for (i, pk) in enumerate(r.polariton_peaks)
            push!(lines, "| $i | $(round(pk, digits=1)) |")
        end
    end

    return join(lines, "\n")
end

"""
    DispersionFitResult

Result from fitting the coupled oscillator model to polariton dispersion data.

# Fields
- `rabi_splitting`: Rabi splitting Omega (cm^-1)
- `molecular_modes`: Vector of molecular mode energies (cm^-1)
- `n_eff`: Effective refractive index
- `E0`: Normal-incidence cavity energy (cm^-1)
- `rabi_err`: Uncertainty in Rabi splitting
- `n_eff_err`: Uncertainty in n_eff
- `E0_err`: Uncertainty in E0
- `lp_angles`: Incidence angles for LP data (radians)
- `lp_positions`: Lower polariton positions at each LP angle
- `up_angles`: Incidence angles for UP data (radians)
- `up_positions`: Upper polariton positions at each UP angle
- `hopfield_zero`: Hopfield coefficients at zero detuning
- `rsquared`: R^2 goodness of fit
- `_sol`: CurveFit solution object (internal)
"""
struct DispersionFitResult
    rabi_splitting::Float64
    molecular_modes::Vector{Float64}
    n_eff::Float64
    E0::Float64
    rabi_err::Float64
    n_eff_err::Float64
    E0_err::Float64
    lp_angles::Vector{Float64}
    lp_positions::Vector{Float64}
    up_angles::Vector{Float64}
    up_positions::Vector{Float64}
    hopfield_zero::NamedTuple{(:photon_LP, :matter_LP, :photon_UP, :matter_UP),
                              NTuple{4, Float64}}
    rsquared::Float64
    _sol::Any
end

function Base.show(io::IO, r::DispersionFitResult)
    print(io, "DispersionFitResult(Omega=$(round(r.rabi_splitting, digits=1)) cm^-1, R^2=$(round(r.rsquared, digits=4)))")
end

function Base.show(io::IO, ::MIME"text/plain", r::DispersionFitResult)
    println(io, "Dispersion Fit (Coupled Oscillator Model)")
    println(io, "=" ^ 50)

    println(io, "\nFitted parameters:")
    println(io, "  Rabi splitting = $(round(r.rabi_splitting, digits=1)) +/- $(round(r.rabi_err, digits=1)) cm^-1")
    println(io, "  E0 (normal)    = $(round(r.E0, digits=1)) +/- $(round(r.E0_err, digits=1)) cm^-1")
    println(io, "  n_eff          = $(round(r.n_eff, digits=3)) +/- $(round(r.n_eff_err, digits=3))")

    println(io, "\nMolecular modes:")
    for (i, m) in enumerate(r.molecular_modes)
        println(io, "  [$i] $(round(m, digits=1)) cm^-1")
    end

    h = r.hopfield_zero
    println(io, "\nHopfield coefficients (zero detuning):")
    println(io, "  LP: photon = $(round(h.photon_LP, digits=3)), matter = $(round(h.matter_LP, digits=3))")
    println(io, "  UP: photon = $(round(h.photon_UP, digits=3)), matter = $(round(h.matter_UP, digits=3))")

    println(io, "\nR^2 = $(round(r.rsquared, digits=6))")
    println(io, "Data points: $(length(r.lp_angles)) LP, $(length(r.up_angles)) UP")
end

function SpectroscopyTools.format_results(r::DispersionFitResult)
    lines = String[]
    push!(lines, "## Dispersion Fit (Coupled Oscillator)\n")

    push!(lines, "| Parameter | Value | Uncertainty |")
    push!(lines, "|-----------|-------|-------------|")
    push!(lines, "| Rabi splitting | $(round(r.rabi_splitting, digits=1)) cm^-1 | $(round(r.rabi_err, digits=1)) |")
    push!(lines, "| E0 | $(round(r.E0, digits=1)) cm^-1 | $(round(r.E0_err, digits=1)) |")
    push!(lines, "| n_eff | $(round(r.n_eff, digits=3)) | $(round(r.n_eff_err, digits=3)) |")
    push!(lines, "| R^2 | $(round(r.rsquared, digits=6)) | |")

    push!(lines, "\n### Molecular Modes\n")
    for (i, m) in enumerate(r.molecular_modes)
        push!(lines, "- Mode $i: $(round(m, digits=1)) cm^-1")
    end

    h = r.hopfield_zero
    push!(lines, "\n### Hopfield Coefficients (zero detuning)\n")
    push!(lines, "| Branch | Photon | Matter |")
    push!(lines, "|--------|--------|--------|")
    push!(lines, "| LP | $(round(h.photon_LP, digits=3)) | $(round(h.matter_LP, digits=3)) |")
    push!(lines, "| UP | $(round(h.photon_UP, digits=3)) | $(round(h.matter_UP, digits=3)) |")

    return join(lines, "\n")
end

# =============================================================================
# Fitting functions
# =============================================================================

"""
    _find_local_maxima(x, y; min_prominence=0.0)

Find local maxima in y(x). Returns vector of x positions sorted by prominence.
"""
function _find_local_maxima(x, y; min_prominence::Real=0.0)
    peaks = Float64[]
    prominences = Float64[]
    for i in 2:(length(y) - 1)
        if y[i] > y[i-1] && y[i] > y[i+1]
            # Estimate prominence as height above lower neighbor
            prom = y[i] - min(y[i-1], y[i+1])
            if prom > min_prominence
                push!(peaks, x[i])
                push!(prominences, prom)
            end
        end
    end
    # Sort by prominence (highest first)
    order = sortperm(prominences, rev=true)
    return peaks[order]
end

"""
    fit_cavity_spectrum(nu, T_data; oscillators, L, n_bg,
                        R_init=0.92, phi_init=0.3, A_init=3000.0,
                        scale_init=1.0, offset_init=0.0,
                        region=nothing, fit_nu0=false, fit_Gamma=false)

Fit a cavity transmission spectrum with a multi-oscillator Fabry-Perot model.

# Arguments
- `nu`: Wavenumber array (cm^-1)
- `T_data`: Transmittance data (fractional, 0-1)
- `oscillators`: Vector of named tuples `(nu0=..., Gamma=...)` defining oscillator
  center frequencies and linewidths. These are fixed by default.
- `L`: Cavity length (cm)
- `n_bg`: Background refractive index
- `R_init`: Initial guess for mirror reflectivity (default: 0.92)
- `phi_init`: Initial guess for phase shift (default: 0.3)
- `A_init`: Initial guess for oscillator amplitude (default: 3000.0)
- `scale_init`: Initial guess for scale factor (default: 1.0)
- `offset_init`: Initial guess for baseline offset (default: 0.0)
- `region`: Optional `(lo, hi)` tuple to restrict fitting range
- `fit_nu0`: If true, also fit oscillator center frequencies (default: false)
- `fit_Gamma`: If true, also fit oscillator linewidths (default: false)

# Returns
`CavityFitResult` with fitted parameters and auto-extracted polariton peaks.
"""
function fit_cavity_spectrum(nu::AbstractVector, T_data::AbstractVector;
    oscillators,
    L::Real,
    n_bg::Real,
    R_init::Real=0.92,
    phi_init::Real=0.3,
    A_init::Real=3000.0,
    scale_init::Real=1.0,
    offset_init::Real=0.0,
    region=nothing,
    fit_nu0::Bool=false,
    fit_Gamma::Bool=false)

    # Apply region mask
    if !isnothing(region)
        mask = region[1] .<= nu .<= region[2]
        nu = Float64.(nu[mask])
        T_data = Float64.(T_data[mask])
    else
        nu = Float64.(nu)
        T_data = Float64.(T_data)
    end

    n_osc = length(oscillators)

    # Build parameter vector: [R, phi, scale, offset, A1, A2, ..., (nu0_1, ...), (Gamma_1, ...)]
    p0 = Float64[R_init, phi_init, scale_init, offset_init]
    for _ in 1:n_osc
        push!(p0, A_init)
    end
    if fit_nu0
        for osc in oscillators
            push!(p0, Float64(osc.nu0))
        end
    end
    if fit_Gamma
        for osc in oscillators
            push!(p0, Float64(osc.Gamma))
        end
    end

    # Fixed values for nu0 and Gamma when not fitting
    fixed_nu0s = Float64[osc.nu0 for osc in oscillators]
    fixed_Gammas = Float64[osc.Gamma for osc in oscillators]

    function model(p, x)
        R_val = p[1]
        phi_val = p[2]
        scale_val = p[3]
        offset_val = p[4]

        As = p[5:5 + n_osc - 1]

        idx = 5 + n_osc
        if fit_nu0
            nu0s = p[idx:idx + n_osc - 1]
            idx += n_osc
        else
            nu0s = fixed_nu0s
        end

        if fit_Gamma
            Gammas = p[idx:idx + n_osc - 1]
        else
            Gammas = fixed_Gammas
        end

        T = compute_cavity_transmittance(x, nu0s, Gammas, As, R_val, L, n_bg, phi_val)
        return T .* scale_val .+ offset_val
    end

    prob = NonlinearCurveFitProblem(model, p0, nu, T_data)
    sol = solve(prob)
    c = coef(sol)

    # Extract fitted parameters
    R_fit = c[1]
    phi_fit = c[2]
    scale_fit = c[3]
    offset_fit = c[4]
    A_fits = c[5:5 + n_osc - 1]

    idx = 5 + n_osc
    if fit_nu0
        nu0_fits = c[idx:idx + n_osc - 1]
        idx += n_osc
    else
        nu0_fits = fixed_nu0s
    end

    if fit_Gamma
        Gamma_fits = c[idx:idx + n_osc - 1]
    else
        Gamma_fits = fixed_Gammas
    end

    # Build oscillator results
    osc_results = [(nu0=nu0_fits[i], Gamma=Gamma_fits[i], A=A_fits[i]) for i in 1:n_osc]

    # Compute R^2
    y_fit = model(c, nu)
    ss_res = sum((T_data .- y_fit).^2)
    ss_tot = sum((T_data .- mean(T_data)).^2)
    rsq = 1 - ss_res / ss_tot

    # Auto-extract polariton peaks from fitted curve
    polariton_peaks = _find_local_maxima(nu, y_fit; min_prominence=0.005 * maximum(y_fit))

    return CavityFitResult(R_fit, L, n_bg, phi_fit, scale_fit, offset_fit,
                           osc_results, polariton_peaks, rsq, nu, T_data, sol)
end

"""
    fit_cavity_spectrum(spec::CavitySpectrum; kwargs...)

Fit a `CavitySpectrum` from registry. Extracts wavenumber/transmittance and
cavity length from metadata.

Transmittance is normalized from percent (0-100) to fractional (0-1) automatically
if the maximum value exceeds 1.5.
"""
function fit_cavity_spectrum(spec::CavitySpectrum; kwargs...)
    nu = xdata(spec)
    T = ydata(spec)

    # Auto-normalize percent transmittance to fractional
    if maximum(T) > 1.5
        T = T ./ 100.0
    end

    # Pull defaults from metadata if not provided in kwargs
    kw = Dict{Symbol, Any}(kwargs)
    if !haskey(kw, :L) && haskey(spec.sample, "cavity_length")
        kw[:L] = spec.sample["cavity_length"]
    end

    return fit_cavity_spectrum(nu, T; kw...)
end

"""
    fit_dispersion(lp_angles, lp_positions, up_angles, up_positions;
                   molecular_modes, E0_init=nothing, n_eff_init=1.5, Omega_init=20.0)

Fit the coupled oscillator model to polariton dispersion data.

LP and UP data can be measured at different angles (common in experiments where
only the photon-like branch is visible at large detuning).

For a single molecular mode, fits the analytic 2-level model:
E_LP, E_UP = (E_cav + E_vib)/2 +/- sqrt(Omega^2 + (E_cav - E_vib)^2)/2

where E_cav(theta) = E0 / sqrt(1 - (sin(theta)/n_eff)^2).

# Arguments
- `lp_angles`: Incidence angles for LP data (radians)
- `lp_positions`: Lower polariton energies (cm^-1)
- `up_angles`: Incidence angles for UP data (radians)
- `up_positions`: Upper polariton energies (cm^-1)
- `molecular_modes`: Scalar or vector of molecular mode energies (cm^-1), fixed
- `E0_init`: Initial guess for normal-incidence cavity energy (default: min of LP - 10)
- `n_eff_init`: Initial guess for effective refractive index (default: 1.5)
- `Omega_init`: Initial guess for Rabi splitting (default: 20.0)

# Returns
`DispersionFitResult`
"""
function fit_dispersion(lp_angles::AbstractVector, lp_positions::AbstractVector,
                        up_angles::AbstractVector, up_positions::AbstractVector;
                        molecular_modes,
                        E0_init=nothing,
                        n_eff_init::Real=1.5,
                        Omega_init::Real=20.0)

    mol_modes = molecular_modes isa Number ? [Float64(molecular_modes)] : Float64.(molecular_modes)

    # Default E0 guess: slightly below the lowest LP position
    if isnothing(E0_init)
        E0_init = minimum(lp_positions) - 10.0
    end

    n_lp = length(lp_angles)
    n_up = length(up_angles)

    # Stack LP and UP data: fit both branches simultaneously
    y_data = Float64.([lp_positions; up_positions])

    # p = [E0, n_eff, Omega]
    p0 = Float64[E0_init, n_eff_init, Omega_init]

    # x-axis: LP angles then UP angles
    x = Float64.([lp_angles; up_angles])

    function model(p, x)
        E0, n_eff, Omega = p[1], p[2], p[3]
        a_lp = x[1:n_lp]
        a_up = x[n_lp+1:end]

        E_cav_lp = cavity_mode_energy([E0, n_eff], a_lp)
        E_cav_up = cavity_mode_energy([E0, n_eff], a_up)

        if length(mol_modes) == 1
            lp, _ = polariton_branches(E_cav_lp, mol_modes[1], Omega)
            _, up = polariton_branches(E_cav_up, mol_modes[1], Omega)
        else
            lp = similar(a_lp)
            up = similar(a_up)
            for i in eachindex(a_lp)
                eigs = polariton_eigenvalues(E_cav_lp[i], mol_modes, [Omega for _ in mol_modes])
                lp[i] = eigs[1]
            end
            for i in eachindex(a_up)
                eigs = polariton_eigenvalues(E_cav_up[i], mol_modes, [Omega for _ in mol_modes])
                up[i] = eigs[end]
            end
        end

        return [lp; up]
    end

    prob = NonlinearCurveFitProblem(model, p0, x, y_data)
    sol = solve(prob)
    c = coef(sol)
    errs = stderror(sol)

    E0_fit, n_eff_fit, Omega_fit = c[1], c[2], c[3]
    E0_err, n_eff_err, Omega_err = errs[1], errs[2], errs[3]

    # Compute R^2
    y_pred = model(c, x)
    ss_res = sum((y_data .- y_pred).^2)
    ss_tot = sum((y_data .- mean(y_data)).^2)
    rsq = 1 - ss_res / ss_tot

    # Hopfield coefficients at zero detuning (E_cav = E_vib)
    if length(mol_modes) == 1
        h = hopfield_coefficients(mol_modes[1], mol_modes[1], Omega_fit)
        hopfield_zero = (photon_LP=h.photon_LP, matter_LP=h.matter_LP,
                         photon_UP=h.photon_UP, matter_UP=h.matter_UP)
    else
        # For multi-mode, compute at E_cav = mean of molecular modes
        E_avg = mean(mol_modes)
        h = hopfield_coefficients(E_avg, E_avg, Omega_fit)
        hopfield_zero = (photon_LP=h.photon_LP, matter_LP=h.matter_LP,
                         photon_UP=h.photon_UP, matter_UP=h.matter_UP)
    end

    return DispersionFitResult(Omega_fit, mol_modes, n_eff_fit, E0_fit,
                               Omega_err, n_eff_err, E0_err,
                               Float64.(lp_angles), Float64.(lp_positions),
                               Float64.(up_angles), Float64.(up_positions),
                               hopfield_zero, rsq, sol)
end

"""
    fit_dispersion(angles, lp_positions, up_positions; kwargs...)

Convenience method when LP and UP are measured at the same angles.
"""
function fit_dispersion(angles::AbstractVector, lp_positions::AbstractVector,
                        up_positions::AbstractVector; kwargs...)
    return fit_dispersion(angles, lp_positions, angles, up_positions; kwargs...)
end

"""
    fit_dispersion(results::Vector{CavityFitResult}; molecular_modes, angles)

Extract LP/UP peak positions from a vector of `CavityFitResult`s and fit
the coupled oscillator model.

# Arguments
- `results`: Vector of cavity fit results (one per detuning/angle)
- `molecular_modes`: Molecular mode energy or vector of energies (cm^-1)
- `angles`: Vector of incidence angles (radians). Must match length of `results`.
"""
function fit_dispersion(results::Vector{CavityFitResult};
                        molecular_modes,
                        angles::AbstractVector)
    @assert length(angles) == length(results) "Need one angle per CavityFitResult"

    mol = molecular_modes isa Number ? Float64(molecular_modes) : Float64.(molecular_modes)
    mol_center = mol isa Number ? mol : mean(mol)

    lp = Float64[]
    up = Float64[]
    valid_angles = Float64[]

    for (i, r) in enumerate(results)
        if length(r.polariton_peaks) >= 2
            sorted_peaks = sort(r.polariton_peaks)
            # LP = peak below molecular mode, UP = peak above
            below = filter(p -> p < mol_center, sorted_peaks)
            above = filter(p -> p >= mol_center, sorted_peaks)

            if !isempty(below) && !isempty(above)
                push!(lp, last(below))    # Highest peak below molecular mode
                push!(up, first(above))   # Lowest peak above molecular mode
                push!(valid_angles, angles[i])
            end
        end
    end

    if length(lp) < 3
        error("Need at least 3 valid LP/UP pairs for dispersion fitting, got $(length(lp))")
    end

    return fit_dispersion(valid_angles, lp, up; molecular_modes=molecular_modes)
end

# =============================================================================
# Registry loading
# =============================================================================

"""
    load_cavity(; kwargs...) -> CavitySpectrum

Load a single cavity spectrum by metadata query. Errors if not exactly one match.

# Keyword Arguments
Any field in the registry can be used as a filter:
- `sample` - Sample description
- `mirror` - Mirror type (e.g., "Au", "DBR")
- `angle` - Incidence angle
- `cavity_length` - Cavity length in cm
- `solute`, `concentration`, `solvent` - Solution properties

# Examples
```julia
spec = load_cavity(sample="NH4SCN 1.0M in DMF", angle=0)
```
"""
function load_cavity(; kwargs...)
    matches = query_registry(:cavity; kwargs...)

    if isempty(matches)
        _annotated_no_match_error(:cavity, kwargs)
    elseif length(matches) > 1
        _annotated_multiple_match_error(:cavity, matches, kwargs)
    end

    return _load_annotated_entry(matches[1], CavitySpectrum)
end

"""
    search_cavity(; kwargs...) -> Vector{CavitySpectrum}

Search for cavity spectra matching filters. Always returns a vector (possibly empty).

# Examples
```julia
all_au = search_cavity(mirror="Au")
angle_scan = search_cavity(sample="NH4SCN 1.0M in DMF")
everything = search_cavity()
```
"""
function search_cavity(; kwargs...)
    matches = query_registry(:cavity; kwargs...)
    return [_load_annotated_entry(m, CavitySpectrum) for m in matches]
end

"""
    list_cavity(; field::Symbol=:angle) -> Vector

List unique values for a given field in the cavity registry.

# Examples
```julia
list_cavity()                   # Default: list angles
list_cavity(field=:mirror)      # ["Au", "DBR", ...]
list_cavity(field=:sample)      # Available samples
```
"""
function list_cavity(; field::Symbol=:angle)
    return list_registry(:cavity; field=field)
end

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
