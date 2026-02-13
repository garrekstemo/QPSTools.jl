# Cavity Spectroscopy Analysis Example
#
# Demonstrates the full cavity analysis workflow using synthetic data:
# 1. Generate synthetic cavity transmission spectra at varying detuning
# 2. Fit each spectrum with the multi-oscillator Fabry-Perot model
# 3. Extract polariton peak positions (LP, UP) — tracks the bright peak
# 4. Fit the coupled oscillator model to get Rabi splitting
# 5. Compute and plot Hopfield coefficients
#
# Physics note: at large detuning, only the photon-like (bright) polariton
# branch is visible in transmission. The matter-like (dark) branch absorbs
# too strongly to appear as a resolved peak. This is normal and matches
# what students observe in the lab.
#
# Output: figures/EXAMPLES/cavity/

using QPSTools
using CairoMakie

# Output directory
outdir = joinpath(@__DIR__, "..", "..", "figures", "EXAMPLES", "cavity")
mkpath(outdir)

# =============================================================================
# 1. Generate synthetic cavity transmission spectra
# =============================================================================
# Simulate detuning by varying the phase (equivalent to changing cavity length
# or incidence angle). The cavity mode sweeps through the molecular resonance.

nu = collect(1900.0:0.5:2200.0)  # Wavenumber grid

# Fixed cavity/molecular parameters
L = 12.0e-4        # Cavity length (cm)
n_bg = 1.4         # Background refractive index
nu0 = 2055.0       # CN stretch frequency (cm^-1)
Gamma = 23.0       # Oscillator linewidth (cm^-1)
A = 3000.0         # Oscillator strength
R = 0.92           # Mirror reflectivity

# Angle-tuning simulation
angles = collect(0.0:3.0:30.0)  # degrees
E0 = 2035.0                     # Normal-incidence bare cavity energy (cm^-1)
n_eff = 1.5                     # Effective refractive index

println("Generating $(length(angles)) synthetic cavity spectra...")
println("  Bare molecular mode: $nu0 cm^-1")
println("  Normal-incidence cavity mode: $E0 cm^-1")

spectra_data = []
for theta_deg in angles
    theta = deg2rad(theta_deg)
    E_cav = cavity_mode_energy([E0, n_eff], [theta])[1]

    # Phase that places the bare cavity mode at E_cav
    # Resonance: 4pi*n*L*nu_res + 2phi = 2pi*m  =>  phi = pi*m - 2pi*n*L*nu_res
    m = round(Int, 2 * n_bg * L * E_cav)
    phi = pi * m - 2pi * n_bg * L * E_cav

    T = compute_cavity_transmittance(nu, [nu0], [Gamma], [A], R, L, n_bg, phi)

    # Add realistic noise
    T_noisy = clamp.(T .+ 0.003 .* randn(length(nu)), 0.0, 1.0)
    push!(spectra_data, (nu=nu, T=T_noisy, angle=theta_deg, phi=phi, E_cav=E_cav))
    println("  $(theta_deg) deg: E_cav = $(round(E_cav, digits=1)) cm^-1")
end

# =============================================================================
# 2. Fit each spectrum
# =============================================================================

println("\nFitting spectra...")

results = CavityFitResult[]
for (i, s) in enumerate(spectra_data)
    result = fit_cavity_spectrum(s.nu, s.T;
        oscillators=[(nu0=nu0, Gamma=Gamma)],
        L=L,
        n_bg=n_bg,
        R_init=0.90,
        phi_init=s.phi,
        A_init=2500.0,
        region=(1920, 2180))

    push!(results, result)
    peaks_str = join([string(round(p, digits=1)) for p in sort(result.polariton_peaks)], ", ")
    println("  $(s.angle) deg: R^2 = $(round(result.rsquared, digits=4)), peaks = [$peaks_str]")
end

# Report the first result in detail
println("\nDetailed fit result for 0 deg:")
report(results[1])

# =============================================================================
# 3. Plot a single spectrum with fit
# =============================================================================

println("\nPlotting single spectrum fit...")
set_theme!(print_theme())

fig, ax, ax_res = plot_spectrum(
    spectra_data[1].nu, spectra_data[1].T;
    fit=results[1],
    residuals=true,
    xlabel="Wavenumber (cm⁻¹)",
    ylabel="Transmittance",
    title="Cavity Spectrum (0 deg)")
ax.xreversed = true
ax_res.xreversed = true
save(joinpath(outdir, "single_fit.png"), fig)
println("  Saved single_fit.png")

# =============================================================================
# 4. Build dispersion from peak positions
# =============================================================================
# At large detuning, only the photon-like (bright) polariton peak is visible.
# We assign each peak to LP or UP based on its position relative to the
# molecular mode frequency:
#   peak < nu0  =>  LP (lower polariton)
#   peak >= nu0 =>  UP (upper polariton)
# Near zero detuning, both peaks may be visible.

println("\nBuilding dispersion from tracked polariton peaks...")
println("  (Peaks below $nu0 cm^-1 -> LP, above -> UP)")

lp_angles = Float64[]
lp_pos = Float64[]
up_angles = Float64[]
up_pos = Float64[]

for (i, r) in enumerate(results)
    theta = deg2rad(angles[i])
    for pk in r.polariton_peaks
        if pk < nu0
            push!(lp_angles, theta)
            push!(lp_pos, pk)
            println("  $(angles[i]) deg: LP = $(round(pk, digits=1)) cm^-1")
        else
            push!(up_angles, theta)
            push!(up_pos, pk)
            println("  $(angles[i]) deg: UP = $(round(pk, digits=1)) cm^-1")
        end
    end
end

println("\n  LP points: $(length(lp_pos)), UP points: $(length(up_pos))")

# For dispersion fitting, we need at least 3 LP and 3 UP points.
# LP and UP can be measured at different angles — the fitter handles this.

if length(lp_pos) >= 3 && length(up_pos) >= 3
    println("\nFitting polariton dispersion...")
    println("  LP: $(length(lp_pos)) points, UP: $(length(up_pos)) points")

    disp = fit_dispersion(lp_angles, lp_pos, up_angles, up_pos;
        molecular_modes=nu0,
        E0_init=E0,
        n_eff_init=n_eff,
        Omega_init=20.0)

    if true  # always enter this block

        println("\nDispersion fit result:")
        report(disp)

        # =============================================================================
        # 5. Plot dispersion
        # =============================================================================

        fig_disp, ax_disp = plot_dispersion(disp; title="Polariton Dispersion")
        save(joinpath(outdir, "dispersion.png"), fig_disp)
        println("\nSaved dispersion.png")

        # =============================================================================
        # 6. Plot Hopfield coefficients
        # =============================================================================

        fig_hop, ax_hop = plot_hopfield(disp; title="Hopfield Coefficients")
        save(joinpath(outdir, "hopfield.png"), fig_hop)
        println("Saved hopfield.png")

        # =============================================================================
        # 7. Publication figure (3-panel)
        # =============================================================================

        println("\nCreating publication figure...")

        fig = Figure(size=(7 * 72, 3.5 * 72))

        # (a) Single spectrum fit near zero detuning
        zd_idx = argmin(abs.([s.E_cav for s in spectra_data] .- nu0))
        ax_a = Axis(fig[1, 1],
            xlabel="Wavenumber (cm⁻¹)", ylabel="Transmittance",
            title="(a) Cavity spectrum",
            xreversed=true)
        lines!(ax_a, spectra_data[zd_idx].nu, spectra_data[zd_idx].T, label="Data")
        lines!(ax_a, results[zd_idx]._nu, predict(results[zd_idx]), color=:red, label="Fit")
        axislegend(ax_a, position=:rt)

        # (b) Dispersion
        ax_b = Axis(fig[1, 2],
            xlabel="Angle (deg)", ylabel="Energy (cm⁻¹)",
            title="(b) Dispersion")
        plot_dispersion!(ax_b, disp)

        # (c) Hopfield
        ax_c = Axis(fig[1, 3],
            xlabel="Detuning (cm⁻¹)", ylabel="|C|², |X|²",
            title="(c) Hopfield")
        plot_hopfield!(ax_c, disp)

        save(joinpath(outdir, "cavity_publication.png"), fig)
        println("Saved cavity_publication.png")
    end  # if true
else
    println("\nNot enough LP or UP points for dispersion fitting.")
    println("Need >= 3 of each, got LP=$(length(lp_pos)), UP=$(length(up_pos)).")
end

println("\nDone! All figures saved to $outdir")
