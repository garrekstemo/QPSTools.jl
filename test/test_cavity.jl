@testset "Cavity spectroscopy" begin

    @testset "Type hierarchy" begin
        @test CavitySpectrum <: QPSTools.AnnotatedSpectrum
        @test CavitySpectrum <: AbstractSpectroscopyData
    end

    @testset "Physics: refractive_index and extinction_coeff" begin
        # For a non-absorbing medium, k should be zero
        eps1 = 2.0
        eps2 = 0.0
        n = refractive_index(eps1, eps2)
        k = extinction_coeff(eps1, eps2)
        @test n ≈ sqrt(2.0)
        @test k ≈ 0.0 atol=1e-14

        # n^2 - k^2 = eps1, 2nk = eps2
        eps1 = 1.5
        eps2 = 0.3
        n = refractive_index(eps1, eps2)
        k = extinction_coeff(eps1, eps2)
        @test n^2 - k^2 ≈ eps1 atol=1e-10
        @test 2 * n * k ≈ eps2 atol=1e-10
    end

    @testset "Physics: compute_cavity_transmittance" begin
        # Empty cavity (no oscillators): should match bare cavity_transmittance
        nu = collect(1900.0:1.0:2100.0)
        R, L, n_bg, phi = 0.9, 12.0e-4, 1.4, 0.3

        T_full = compute_cavity_transmittance(nu, Float64[], Float64[], Float64[],
                                               R, L, n_bg, phi)
        T_bare = [cavity_transmittance((n_bg, 0.0, L, R, phi), v) for v in nu]
        @test T_full ≈ T_bare atol=1e-10

        # With oscillator: transmittance should show splitting
        T_osc = compute_cavity_transmittance(nu, [2055.0], [23.0], [3000.0],
                                              R, L, n_bg, phi)
        @test all(T_osc .>= 0)
        @test all(T_osc .<= 1)

        # With oscillator, the transmission pattern should differ from bare
        @test !isapprox(T_osc, T_bare, atol=0.01)

        # Scalar dispatch should match array dispatch
        T_scalar = compute_cavity_transmittance(2000.0, [2055.0], [23.0], [3000.0],
                                                 R, L, n_bg, phi)
        @test T_scalar ≈ T_osc[nu .== 2000.0][1]
    end

    @testset "Physics: cavity_mode_energy" begin
        E0 = 2000.0
        n_eff = 1.5

        # At normal incidence, energy equals E0
        E_0deg = cavity_mode_energy([E0, n_eff], [0.0])
        @test E_0deg[1] ≈ E0

        # At non-zero angle, energy increases (blue shift)
        theta = deg2rad(10.0)
        E_10deg = cavity_mode_energy([E0, n_eff], [theta])
        @test E_10deg[1] > E0
    end

    @testset "Physics: polariton_branches" begin
        E_cav = 2050.0
        E_vib = 2050.0  # Zero detuning
        Omega = 20.0

        LP, UP = polariton_branches(E_cav, E_vib, Omega)

        # At zero detuning, splitting equals Omega
        @test UP - LP ≈ Omega atol=0.1

        # Branches are symmetric around the molecular mode at zero detuning
        @test (LP + UP) / 2 ≈ E_vib atol=0.1

        # LP < E_vib < UP
        @test LP < E_vib
        @test UP > E_vib

        # Vector dispatch
        E_cav_vec = collect(2030.0:2.0:2070.0)
        LP_vec, UP_vec = polariton_branches(E_cav_vec, E_vib, Omega)
        @test length(LP_vec) == length(E_cav_vec)
        @test all(LP_vec .< UP_vec)
    end

    @testset "Physics: polariton_eigenvalues" begin
        # 2-mode should reduce to standard 2-level formula
        E_cav = 2050.0
        E_vib = 2050.0
        Omega = 20.0

        eigs = polariton_eigenvalues(E_cav, [E_vib], [Omega])
        LP, UP = polariton_branches(E_cav, E_vib, Omega)

        @test length(eigs) == 2
        @test eigs[1] ≈ LP atol=0.1
        @test eigs[2] ≈ UP atol=0.1

        # N-mode returns N+1 eigenvalues
        eigs3 = polariton_eigenvalues(E_cav, [2030.0, 2060.0, 2090.0], [15.0, 20.0, 10.0])
        @test length(eigs3) == 4
        @test issorted(eigs3)
    end

    @testset "Physics: hopfield_coefficients" begin
        E_vib = 2050.0
        Omega = 20.0

        # At zero detuning, should give 50/50 mixing
        h = hopfield_coefficients(E_vib, E_vib, Omega)
        @test h.photon_LP ≈ 0.5 atol=0.01
        @test h.matter_LP ≈ 0.5 atol=0.01
        @test h.photon_UP ≈ 0.5 atol=0.01
        @test h.matter_UP ≈ 0.5 atol=0.01

        # Fractions sum to 1
        @test h.photon_LP + h.matter_LP ≈ 1.0 atol=1e-10
        @test h.photon_UP + h.matter_UP ≈ 1.0 atol=1e-10

        # Far positive detuning: LP becomes more photon-like
        h_pos = hopfield_coefficients(E_vib + 100, E_vib, Omega)
        @test h_pos.photon_LP > 0.9
        @test h_pos.matter_UP > 0.9

        # Far negative detuning: LP becomes more matter-like
        h_neg = hopfield_coefficients(E_vib - 100, E_vib, Omega)
        @test h_neg.matter_LP > 0.9
        @test h_neg.photon_UP > 0.9

        # Vector dispatch
        E_cav_vec = collect(2000.0:10.0:2100.0)
        h_vec = hopfield_coefficients(E_cav_vec, E_vib, Omega)
        @test length(h_vec.photon_LP) == length(E_cav_vec)
        @test all(h_vec.photon_LP .+ h_vec.matter_LP .≈ 1.0)
    end

    @testset "Fitting: synthetic cavity spectrum round-trip" begin
        # Generate synthetic cavity spectrum with known parameters
        nu = collect(1900.0:0.5:2200.0)
        R_true = 0.92
        L_true = 12.0e-4
        n_bg_true = 1.4
        phi_true = 0.3
        A_true = 3000.0
        nu0_true = 2055.0
        Gamma_true = 23.0

        T_true = compute_cavity_transmittance(nu, [nu0_true], [Gamma_true], [A_true],
                                               R_true, L_true, n_bg_true, phi_true)

        # Add small noise
        T_noisy = clamp.(T_true .+ 0.002 .* randn(length(nu)), 0.0, 1.0)

        result = fit_cavity_spectrum(nu, T_noisy;
            oscillators=[(nu0=nu0_true, Gamma=Gamma_true)],
            L=L_true,
            n_bg=n_bg_true,
            R_init=0.9,
            phi_init=0.2,
            A_init=2500.0)

        @test result isa CavityFitResult
        @test result.rsquared > 0.95
        @test isapprox(result.R, R_true, atol=0.05)
        @test length(result.oscillators) == 1
        @test result.oscillators[1].nu0 ≈ nu0_true
        @test result.oscillators[1].Gamma ≈ Gamma_true

        # predict should work
        y_fit = predict(result)
        @test length(y_fit) == length(nu)
        @test all(isfinite, y_fit)

        y_fit_custom = predict(result, nu[1:10])
        @test length(y_fit_custom) == 10

        # residuals
        res = residuals(result)
        @test length(res) == length(nu)
    end

    @testset "Fitting: region parameter" begin
        nu = collect(1900.0:0.5:2200.0)
        T = compute_cavity_transmittance(nu, [2055.0], [23.0], [3000.0],
                                          0.92, 12.0e-4, 1.4, 0.3)

        result = fit_cavity_spectrum(nu, T;
            oscillators=[(nu0=2055.0, Gamma=23.0)],
            L=12.0e-4, n_bg=1.4,
            region=(1950, 2150))

        @test result.rsquared > 0.99
        @test length(result._nu) < length(nu)
    end

    @testset "Fitting: dispersion round-trip" begin
        # Generate synthetic dispersion data
        E_vib = 2055.0
        Omega_true = 25.0
        E0_true = 2040.0
        n_eff_true = 1.5

        angles = collect(0.0:2.0:30.0) .* (pi / 180)

        E_cav = cavity_mode_energy([E0_true, n_eff_true], angles)
        lp_true, up_true = polariton_branches(E_cav, E_vib, Omega_true)

        # Add small noise
        lp_noisy = lp_true .+ 0.5 .* randn(length(angles))
        up_noisy = up_true .+ 0.5 .* randn(length(angles))

        result = fit_dispersion(angles, lp_noisy, up_noisy;
            molecular_modes=E_vib,
            E0_init=2035.0,
            n_eff_init=1.4,
            Omega_init=20.0)

        @test result isa DispersionFitResult
        @test result.rsquared > 0.95
        @test isapprox(result.rabi_splitting, Omega_true, atol=3.0)
        @test isapprox(result.E0, E0_true, atol=5.0)
        @test isapprox(result.n_eff, n_eff_true, atol=0.2)
        @test length(result.molecular_modes) == 1

        # Hopfield at zero detuning should be ~50/50
        @test result.hopfield_zero.photon_LP ≈ 0.5 atol=0.05
    end

    @testset "Result: report and format_results" begin
        # CavityFitResult
        nu = collect(1900.0:1.0:2200.0)
        T = compute_cavity_transmittance(nu, [2055.0], [23.0], [3000.0],
                                          0.92, 12.0e-4, 1.4, 0.3)
        result = fit_cavity_spectrum(nu, T;
            oscillators=[(nu0=2055.0, Gamma=23.0)],
            L=12.0e-4, n_bg=1.4)

        # report should run without error (uses show)
        buf = IOBuffer()
        show(buf, MIME("text/plain"), result)
        output = String(take!(buf))
        @test occursin("Cavity Spectrum Fit", output)
        @test occursin("R^2", output)

        # format_results returns markdown
        md = format_results(result)
        @test md isa String
        @test occursin("## Cavity Spectrum Fit", md)
        @test occursin("| R |", md)

        # DispersionFitResult
        angles = collect(0.0:5.0:30.0) .* (pi / 180)
        E_cav = cavity_mode_energy([2040.0, 1.5], angles)
        lp, up = polariton_branches(E_cav, 2055.0, 25.0)
        disp = fit_dispersion(angles, lp, up; molecular_modes=2055.0)

        buf = IOBuffer()
        show(buf, MIME("text/plain"), disp)
        output = String(take!(buf))
        @test occursin("Dispersion Fit", output)
        @test occursin("Rabi splitting", output)

        md_d = format_results(disp)
        @test md_d isa String
        @test occursin("## Dispersion Fit", md_d)
    end

    @testset "Registry: cavity category exists" begin
        reg = load_registry()
        @test haskey(reg, "cavity")
    end

    @testset "Registry: search_cavity with empty registry" begin
        results = search_cavity()
        @test results isa Vector{CavitySpectrum}
        @test isempty(results)
    end

    @testset "Plotting: plot_spectrum smoke test" begin
        using Makie: Figure, Axis

        # Generate synthetic data as CavityFitResult for plot_spectrum dispatch
        nu = collect(1900.0:1.0:2200.0)
        T = compute_cavity_transmittance(nu, [2055.0], [23.0], [3000.0],
                                          0.92, 12.0e-4, 1.4, 0.3)
        result = fit_cavity_spectrum(nu, T;
            oscillators=[(nu0=2055.0, Gamma=23.0)],
            L=12.0e-4, n_bg=1.4)

        # plot_spectrum with raw vectors + CavityFitResult
        fig, ax = plot_spectrum(nu, T; fit=result, xlabel="Wavenumber (cm⁻¹)",
                                ylabel="Transmittance")
        @test fig isa Figure
        @test ax isa Axis

        # With residuals
        fig2, ax2, ax_res = plot_spectrum(nu, T; fit=result, residuals=true,
                                          xlabel="Wavenumber (cm⁻¹)", ylabel="Transmittance")
        @test fig2 isa Figure
        @test ax2 isa Axis
        @test ax_res isa Axis
    end

    @testset "Plotting: plot_dispersion smoke test" begin
        using Makie: Figure, Axis

        angles = collect(0.0:5.0:30.0) .* (pi / 180)
        E_cav = cavity_mode_energy([2040.0, 1.5], angles)
        lp, up = polariton_branches(E_cav, 2055.0, 25.0)
        disp = fit_dispersion(angles, lp, up; molecular_modes=2055.0)

        fig, ax = plot_dispersion(disp)
        @test fig isa Figure
        @test ax isa Axis
    end

    @testset "Plotting: plot_hopfield smoke test" begin
        using Makie: Figure, Axis

        angles = collect(0.0:5.0:30.0) .* (pi / 180)
        E_cav = cavity_mode_energy([2040.0, 1.5], angles)
        lp, up = polariton_branches(E_cav, 2055.0, 25.0)
        disp = fit_dispersion(angles, lp, up; molecular_modes=2055.0)

        fig, ax = plot_hopfield(disp)
        @test fig isa Figure
        @test ax isa Axis
    end

end
