@isdefined(PROJECT_ROOT) || include("testsetup.jl")

using Dates: DateTime

# The cavity physics and fitting numerics are tested in OpticalSpectroscopy's
# suite. This file covers only the QPSTools layer: the JASCO-backed
# CavitySpectrum, load_cavity, the JASCO-aware fit_cavity_spectrum dispatch,
# format_results on cavity result types, and plotting.

@testset "Cavity spectroscopy" begin

    @testset "Type hierarchy" begin
        @test CavitySpectrum <: QPSTools.AnnotatedSpectrum
        @test CavitySpectrum <: AbstractSpectroscopyData
    end

    @testset "Interface accessors" begin
        spec = load_cavity(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        @test xreversed(spec) == true

        # The semantic accessor must extend OpticalSpectroscopy's generic
        # (the single wavenumber generic, shared with the cavity fit results)
        @test OpticalSpectroscopy.wavenumber(spec) == xdata(spec)
    end

    @testset "fit_cavity_spectrum JASCO dispatch" begin
        # The CavitySpectrum method extracts wavenumber/transmittance,
        # normalizes percent transmittance to fractional, and pulls L from
        # sample metadata; the numerics run in OpticalSpectroscopy.
        nu = collect(1900.0:0.5:2200.0)
        L = 12.0e-4
        T = compute_cavity_transmittance(nu, [2055.0], [23.0], [3000.0],
                                          0.92, L, 1.4, 0.3)
        jasco = JASCOSpectrum("synthetic cavity", DateTime(2026), "test",
                              "INFRARED SPECTRUM", "1/CM", "TRANSMITTANCE",
                              nu, 100 .* T, Dict{String,Any}())
        spec = CavitySpectrum(jasco, Dict{String,Any}("cavity_length" => L),
                              "synthetic.csv")

        # No L kwarg: comes from sample metadata. %T: auto-normalized.
        result = fit_cavity_spectrum(spec;
            oscillators=[(nu0=2055.0, Gamma=23.0)],
            n_bg=1.4)

        @test result isa CavityFitResult
        @test result.rsquared > 0.99
        @test isapprox(result.R, 0.92, atol=0.05)

        # Without metadata and without L the required kwarg is missing
        spec_bare = CavitySpectrum(jasco, Dict{String,Any}(), "synthetic.csv")
        @test_throws UndefKeywordError fit_cavity_spectrum(spec_bare;
            oscillators=[(nu0=2055.0, Gamma=23.0)], n_bg=1.4)
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
