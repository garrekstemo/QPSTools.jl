@isdefined(PROJECT_ROOT) || include("testsetup.jl")

using Dates: DateTime
using Makie: Figure

# QPSTools' student-facing `load_scan` contract: results carry
# OpticalSpectroscopy analysis types ready for fitting and plotting.
#
# This pins the behavior students have always seen. QPSScanFormat itself
# returns plain data (NamedTuples of vectors/matrices); QPSTools wraps
# those into TATrace / TASpectrum / TAMatrix / SweepData. The assertions
# below were recorded against the pre-decoupling QPSScanFormat (which
# returned the typed objects directly) and must keep passing verbatim
# against the plain-data QPSScanFormat + QPSTools wrapper.

@testset "load_scan returns OpticalSpectroscopy-typed results" begin

    # ─── Fixtures written through QPSScanFormat's canonical writers ───
    t = collect(range(-1.0, 8.0; length=60))
    decay = @. exp(-max(t, 0.0) / 2.0) * (t >= 0.0)
    sweeps_k = SweepData(repeat(decay, 1, 3), zeros(60, 3), ones(60, 3))

    wl = collect(range(2000.0, 2200.0; length=24))
    wn = 1e7 ./ wl
    sspec = @. exp(-((wn - 4760.0) / 30.0)^2)

    ts = DateTime(2026, 6, 10, 12, 0, 0)

    mktempdir() do dir
        kinetic_path = joinpath(dir, "kinetic.h5")
        QPSScanFormat.save_kinetic_scan(TATrace(t, decay), kinetic_path;
            sweeps = sweeps_k,
            scan_params = Dict{String,Any}(
                "averages" => 100,
                "metadata" => Dict{String,Any}("sample_name" => "W(CO)6"),
            ),
            instrument_state = Dict{String,Any}(
                "stage" => Dict{String,Any}("position_ps" => 0.5),
            ),
            description = "kinetic for wrapper test",
            comment = "typed contract",
            timestamp = ts,
            duration_seconds = 42.5,
        )

        spectral_path = joinpath(dir, "spectral.h5")
        QPSScanFormat.save_spectral_scan(TASpectrum(wn, sspec), wl, spectral_path;
            scan_params = Dict{String,Any}("delay_ps" => 1.5),
            description = "spectrum for wrapper test",
            timestamp = ts,
            duration_seconds = 12.0,
        )

        composite_path = joinpath(dir, "composite.h5")
        QPSScanFormat.save_composite_scan(composite_path;
            spectra = [
                (spectrum = TASpectrum(wn, sspec), wavelengths = wl, sweeps = nothing,
                 description = "early", comment = "", timestamp = ts,
                 duration_seconds = 10.0, delay_ps = 0.5),
            ],
            kinetics = [
                (trace = TATrace(t, decay), sweeps = sweeps_k,
                 description = "@2050nm", comment = "", timestamp = ts,
                 duration_seconds = 15.0, wavelength_nm = 2050.0),
            ],
            description = "composite for wrapper test",
            timestamp = ts,
            duration_seconds = 100.0,
        )

        broadband_path = joinpath(dir, "broadband.h5")
        mat_data = decay * sspec'   # 60 × 24, rank-1 TA matrix
        QPSScanFormat.save_broadband_scan(TAMatrix(t, wl, mat_data), broadband_path;
            description = "broadband for wrapper test",
            timestamp = ts,
            duration_seconds = 2.0,
        )

        noise_path = joinpath(dir, "noise.h5")
        QPSScanFormat.save_noise_scan(noise_path;
            time_constants = [1e-3, 1e-2],
            noise_rms = [1e-6, 1e-7],
            noise_mean = [1e-3, 1e-3],
            samples = [100.0, 100.0],
            allan_taus = [0.01, 0.1],
            allan_devs = [2e-7, 5e-8],
            description = "noise for wrapper test",
            timestamp = ts,
            duration_seconds = 30.0,
        )

        # ─── Kinetic: trace is a TATrace, sweeps a SweepData ─────────
        @testset "kinetic" begin
            r = load_scan(kinetic_path)
            @test r isa LoadedScanResult
            @test r.trace isa TATrace
            @test isnan(r.trace.wavelength)
            @test r.trace.time ≈ t
            @test r.trace.signal ≈ decay
            @test r.sweeps isa SweepData
            @test size(r.sweeps.X) == (60, 3)
            @test r.description == "kinetic for wrapper test"
            @test r.comment == "typed contract"
            @test r.duration_seconds ≈ 42.5
            @test r.scan_params["averages"] == 100
            @test r.scan_params["metadata"]["sample_name"] == "W(CO)6"
            @test r.instrument_state["stage"]["position_ps"] ≈ 0.5

            # Fits exactly as before: the trace feeds OS fitting directly.
            fit = fit_exp_decay(r.trace)
            @test fit isa ExpDecayFit
            @test isapprox(fit.tau, 2.0; rtol = 0.05)

            # Plots exactly as before.
            fig, _ = plot_kinetics(r.trace)
            @test fig isa Figure
        end

        # ─── Spectral: spectrum is a TASpectrum ──────────────────────
        @testset "spectral" begin
            r = load_scan(spectral_path)
            @test r isa LoadedSpectralResult
            @test r.spectrum isa TASpectrum
            @test isnan(r.spectrum.time_delay)
            @test r.spectrum.wavenumber ≈ wn
            @test r.spectrum.signal ≈ sspec
            @test r.wavelengths ≈ wl
            @test r.scan_params["delay_ps"] ≈ 1.5

            fig, _ = plot_spectrum(r.spectrum)
            @test fig isa Figure
        end

        # ─── Composite: typed sub-results, sub_path bookkeeping ──────
        @testset "composite" begin
            r = load_scan(composite_path)
            @test r isa LoadedCompositeResult
            @test length(r.spectra) == 1
            @test length(r.traces) == 1
            @test r.spectra[1] isa LoadedSpectralResult
            @test r.spectra[1].spectrum isa TASpectrum
            @test r.spectra[1].sweeps === nothing
            @test r.spectra[1].scan_params["delay_ps"] ≈ 0.5
            @test r.spectra[1].scan_params["sub_path"] == "data/spectra/spectrum_001"
            @test r.traces[1] isa LoadedScanResult
            @test r.traces[1].trace isa TATrace
            @test r.traces[1].sweeps isa SweepData
            @test r.traces[1].scan_params["wavelength_nm"] ≈ 2050.0
            @test r.traces[1].scan_params["sub_path"] == "data/kinetics/trace_001"
            @test r.description == "composite for wrapper test"
        end

        # ─── Broadband: a TAMatrix, as always ────────────────────────
        @testset "broadband" begin
            r = load_scan(broadband_path)
            @test r isa TAMatrix
            @test r.time ≈ t
            @test r.wavelength ≈ wl
            @test r.data ≈ mat_data
        end

        # ─── Noise: plain-data result passes through unchanged ───────
        @testset "noise" begin
            r = load_scan(noise_path)
            @test r isa LoadedNoiseResult
            @test r.time_constants ≈ [1e-3, 1e-2]
            @test r.allan_devs ≈ [2e-7, 5e-8]
        end

        # ─── Rewrite helpers reachable through QPSTools ──────────────
        @testset "update_scan_*! re-exports" begin
            update_scan_description!(kinetic_path, "renamed")
            r = load_scan(kinetic_path)
            @test r.description == "renamed"
            @test r.trace isa TATrace
        end
    end
end
