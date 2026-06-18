@isdefined(PROJECT_ROOT) || include("testsetup.jl")

using Dates: DateTime

# The cavity physics and fitting numerics are tested in OpticalSpectroscopy's
# suite. This file covers only the QPSTools layer: load_spectrum stamping FTIR
# tokens, the Spectrum-aware fit_cavity_spectrum dispatch, format_results on
# cavity result types, and plotting.

@testset "Cavity spectroscopy" begin

    @testset "load_spectrum stamps FTIR tokens" begin
        spec = load_spectrum(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        @test spec isa Spectrum
        @test spec.metadata[:technique] == :ftir
        @test spec.metadata[:xquantity] == :wavenumber
        # FTIR convention: high wavenumber on the left
        @test xreversed(spec) == true

        # cavity_length is promoted to the top-level :cavity_length token (where
        # OpticalSpectroscopy's fit_cavity_spectrum(::Spectrum) reads L), not
        # buried in :sample alongside descriptive kwargs.
        cav = load_spectrum(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv");
            mirror="Au", cavity_length=12.0e-4)
        @test cav.metadata[:cavity_length] == 12.0e-4
        @test !haskey(cav.metadata[:sample], "cavity_length")
        @test cav.metadata[:sample]["mirror"] == "Au"
    end

    @testset "fit_cavity_spectrum reachable from a token-stamped Spectrum" begin
        # The Spectrum dispatch lives in OpticalSpectroscopy (tested there); this
        # is an integration smoke that a Spectrum carrying the tokens load_spectrum
        # stamps (percent :yunit, :cavity_length) threads through to a fit.
        nu = collect(1900.0:0.5:2200.0)
        L = 12.0e-4
        T = compute_cavity_transmittance(nu, [2055.0], [23.0], [3000.0],
                                          0.92, L, 1.4, 0.3)
        spec = Spectrum(nu, 100 .* T;
            technique=:ftir, xquantity=:wavenumber, xunit=:per_cm,
            yquantity=:transmittance, yunit=:percent, cavity_length=L)

        result = fit_cavity_spectrum(spec;
            oscillators=[(nu0=2055.0, Gamma=23.0)], n_bg=1.4)

        @test result isa CavityFitResult
        @test result.rsquared > 0.99
        @test isapprox(result.R, 0.92, atol=0.05)
    end

    @testset "format_results on cavity results" begin
        # format_results is one generic in OpticalSpectroscopy; the cavity
        # result methods moved there with the merge.
        nu = collect(1900.0:1.0:2200.0)
        T = compute_cavity_transmittance(nu, [2055.0], [23.0], [3000.0],
                                          0.92, 12.0e-4, 1.4, 0.3)
        result = fit_cavity_spectrum(nu, T;
            oscillators=[(nu0=2055.0, Gamma=23.0)],
            L=12.0e-4, n_bg=1.4)

        md = format_results(result)
        @test md isa String
        @test occursin("## Cavity Spectrum Fit", md)

        angles = collect(0.0:5.0:30.0) .* (pi / 180)
        E_cav = cavity_mode_energy([2040.0, 1.5], angles)
        lp, up = polariton_branches(E_cav, 2055.0, 25.0)
        disp = fit_dispersion(angles, lp, up; molecular_modes=2055.0)

        md_d = format_results(disp)
        @test md_d isa String
        @test occursin("## Dispersion Fit", md_d)
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
