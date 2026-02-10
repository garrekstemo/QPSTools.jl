using Test
using QPSTools

# Set data directory to the project's data folder
const PROJECT_ROOT = dirname(@__DIR__)
set_data_dir(joinpath(PROJECT_ROOT, "data"))

@testset "QPSTools.jl" begin

    @testset "Type hierarchy" begin
        # AnnotatedSpectrum subtypes (FTIR, Raman)
        @test FTIRSpectrum <: QPSTools.AnnotatedSpectrum
        @test RamanSpectrum <: QPSTools.AnnotatedSpectrum

        # AnnotatedSpectrum is itself an AbstractSpectroscopyData
        @test QPSTools.AnnotatedSpectrum <: AbstractSpectroscopyData

        # Direct AbstractSpectroscopyData subtypes (TA data, from SpectroscopyTools)
        @test TATrace <: AbstractSpectroscopyData
        @test TASpectrum <: AbstractSpectroscopyData
        @test TAMatrix <: AbstractSpectroscopyData

        # FTIR/Raman also implement AbstractSpectroscopyData (via AnnotatedSpectrum)
        @test FTIRSpectrum <: AbstractSpectroscopyData
        @test RamanSpectrum <: AbstractSpectroscopyData
    end

    @testset "SpectroscopyTools re-exports available" begin
        # Types from SpectroscopyTools should be accessible via QPSTools
        @test isdefined(QPSTools, :TATrace)
        @test isdefined(QPSTools, :TASpectrum)
        @test isdefined(QPSTools, :TAMatrix)
        @test isdefined(QPSTools, :PeakInfo)
        @test isdefined(QPSTools, :MultiPeakFitResult)
        @test isdefined(QPSTools, :ExpDecayFit)
        @test isdefined(QPSTools, :MultiexpDecayFit)
        @test isdefined(QPSTools, :GlobalFitResult)

        # Functions from SpectroscopyTools
        @test isdefined(QPSTools, :fit_peaks)
        @test isdefined(QPSTools, :find_peaks)
        @test isdefined(QPSTools, :als_baseline)
        @test isdefined(QPSTools, :normalize)
        @test isdefined(QPSTools, :fit_exp_decay)

        # Types defined in QPSTools
        @test isdefined(QPSTools, :PumpProbeData)
        @test isdefined(QPSTools, :AxisType)

        # Re-exports from CurveFit/CurveFitModels
        @test isdefined(QPSTools, :solve)
        @test isdefined(QPSTools, :NonlinearCurveFitProblem)
        @test isdefined(QPSTools, :lorentzian)
        @test isdefined(QPSTools, :gaussian)
    end

    @testset "FTIRFitResult alias" begin
        @test FTIRFitResult === MultiPeakFitResult
    end

    @testset "Extended interface - FTIR source_file and npoints" begin
        spec = load_ftir(solute="NH4SCN", concentration="1.0M")
        @test source_file(spec) isa String
        @test !isempty(source_file(spec))
        @test npoints(spec) == length(spec.data.x)
        @test title(spec) == source_file(spec)
    end

    @testset "Extended interface - Raman source_file and npoints" begin
        raman = load_raman(phase="crystal", composition="Zn/Co")
        @test source_file(raman) isa String
        @test !isempty(source_file(raman))
        @test npoints(raman) == length(raman.data.x)
        @test title(raman) == source_file(raman)
    end

    @testset "PumpProbeData axis_type" begin
        # Load kinetics file (should be time_axis)
        kinetics = load_lvm(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"))
        @test kinetics.axis_type == time_axis
        @test xaxis_label(kinetics) == "Time (ps)"
        @test xaxis(kinetics) === kinetics.time

        # Load spectrum file (should be wavelength_axis)
        spectrum = load_lvm(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/spectra/bare_1M_1ps.lvm"))
        @test spectrum.axis_type == wavelength_axis
        @test xaxis_label(spectrum) == "Wavelength (nm)"
        @test xaxis(spectrum) === spectrum.time
    end

    @testset "load_spectroscopy auto-detection" begin
        # Kinetics file → TATrace
        trace = load_spectroscopy(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"))
        @test trace isa TATrace
        @test xlabel(trace) == "Time (ps)"

        # Spectrum file → TASpectrum
        spec = load_spectroscopy(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/spectra/bare_1M_1ps.lvm"))
        @test spec isa TASpectrum
        @test xlabel(spec) == "Wavenumber (cm⁻¹)"

        # Directory → TAMatrix
        matrix = load_spectroscopy(joinpath(PROJECT_ROOT, "data/CCD"))
        @test matrix isa TAMatrix
        @test is_matrix(matrix) == true

        # Non-existent path should error
        @test_throws ErrorException load_spectroscopy("/nonexistent/path.lvm")
    end

    @testset "FTIR loading" begin
        spec = load_ftir(solute="NH4SCN", concentration="1.0M")
        @test spec isa FTIRSpectrum
        @test length(spec.data.x) > 0
        @test QPSTools.sample_id(spec) == "NH4SCN_DMF_1M"
    end

    @testset "FTIR interface" begin
        spec = load_ftir(solute="NH4SCN", concentration="1.0M")
        @test xdata(spec) === spec.data.x
        @test ydata(spec) === spec.data.y
        @test xlabel(spec) == "Wavenumber (cm⁻¹)"
        @test ylabel(spec) == "Absorbance"
        @test is_matrix(spec) == false
        @test zdata(spec) === nothing
    end

    @testset "Raman loading" begin
        raman = load_raman(phase="crystal", composition="Zn/Co")
        @test raman isa RamanSpectrum
        @test length(raman.data.x) > 0
        @test QPSTools.sample_id(raman) == "ZIF62_crystal_1"
    end

    @testset "Raman interface" begin
        raman = load_raman(phase="crystal", composition="Zn/Co")
        @test xdata(raman) === raman.data.x
        @test ydata(raman) === raman.data.y
        @test xlabel(raman) == "Raman Shift (cm⁻¹)"
        @test ylabel(raman) == "Intensity"
        @test is_matrix(raman) == false
        @test zdata(raman) === nothing
    end

    @testset "FTIR peak fitting (fit_peaks)" begin
        spec = load_ftir(solute="NH4SCN", concentration="1.0M")
        result = fit_peaks(spec, (2000, 2100))

        @test result isa MultiPeakFitResult
        @test length(result) >= 1

        # Per-peak access
        pk = result[1]
        @test pk isa PeakFitResult
        @test haskey(pk, :amplitude)
        @test haskey(pk, :center)
        @test haskey(pk, :fwhm)

        # Check parameter access
        @test pk[:center].value > 2000
        @test pk[:center].value < 2100
        @test result.r_squared > 0.9

        # Predict functions
        y_fit = predict(result)
        @test length(y_fit) == result.npoints

        y_peak = predict_peak(result, 1)
        @test length(y_peak) == result.npoints

        y_bl = predict_baseline(result)
        @test length(y_bl) == result.npoints

        res = residuals(result)
        @test length(res) == result.npoints
    end

    @testset "Raman peak fitting (fit_peaks)" begin
        raman = load_raman(phase="crystal", composition="Zn/Co")
        result = fit_peaks(raman, (1250, 1300))

        @test result isa MultiPeakFitResult
        @test length(result) >= 1
        pk = result[1]
        @test haskey(pk, :amplitude)
        @test haskey(pk, :center)
    end

    @testset "Spectrum subtraction" begin
        spec = load_ftir(solute="NH4SCN", concentration="1.0M")
        ref = load_ftir(material="DMF")

        corrected = subtract_spectrum(spec, ref)
        @test corrected isa FTIRSpectrum
        @test length(corrected.data.x) == length(spec.data.x)
    end

    @testset "TA trace loading" begin
        trace = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)

        @test trace isa TATrace
        @test length(trace.time) > 0
        @test length(trace.signal) == length(trace.time)

        # Peak should be shifted to t=0
        peak_idx = argmax(trace.signal)
        @test abs(trace.time[peak_idx]) < 0.1  # Peak within 0.1 ps of zero

        # Time axis should span negative to positive
        @test minimum(trace.time) < 0
        @test maximum(trace.time) > 0

        # Test without time shift - peak should NOT be at t=0
        trace_unshifted = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm");
                                        mode=:OD, shift_t0=false)
        peak_idx_unshifted = argmax(trace_unshifted.signal)
        @test abs(trace_unshifted.time[peak_idx_unshifted]) > 0.1  # Peak NOT at zero
    end

    @testset "find_peak_time" begin
        time = collect(-5.0:0.1:10.0)

        # ESA signal (positive peak)
        signal_esa = exp.(-(time .- 0.5).^2)
        @test find_peak_time(time, signal_esa) ≈ 0.5 atol=0.1

        # GSB signal (negative peak)
        signal_gsb = -exp.(-(time .+ 1.0).^2)
        @test find_peak_time(time, signal_gsb) ≈ -1.0 atol=0.1
    end

    @testset "TA spectrum loading" begin
        spec = load_ta_spectrum(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/spectra/bare_1M_1ps.lvm");
                                mode=:OD, calibration=-19.0, time_delay=1.0)

        @test spec isa TASpectrum
        @test length(spec.wavenumber) > 0
        @test length(spec.signal) == length(spec.wavenumber)
        @test spec.time_delay == 1.0

        # Wavenumber should be in reasonable range for MIR
        @test minimum(spec.wavenumber) > 1800
        @test maximum(spec.wavenumber) < 2300

        # Check metadata
        @test haskey(spec.metadata, :filename)
        @test haskey(spec.metadata, :mode)
        @test spec.metadata[:calibration] == -19.0

        # Test different modes
        spec_diff = load_ta_spectrum(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/spectra/bare_1M_1ps.lvm");
                                     mode=:diff)
        @test spec_diff isa TASpectrum
        @test length(spec_diff.signal) == length(spec_diff.wavenumber)
    end

    @testset "fit_ta_spectrum" begin
        spec = load_ta_spectrum(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/spectra/bare_1M_1ps.lvm");
                                mode=:OD, calibration=-19.0)

        # Fit with region (default: ESA + GSB peaks)
        result = fit_ta_spectrum(spec; region=(2000, 2100))
        @test result isa TASpectrumFit
        @test length(result.peaks) == 2

        # Access peaks by label
        esa = first(p for p in result.peaks if p.label == :esa)
        gsb = first(p for p in result.peaks if p.label == :gsb)

        # Check ESA < GSB (anharmonic shift)
        @test esa.center < gsb.center
        @test anharmonicity(result) > 0

        # Check reasonable parameter ranges
        @test esa.center > 2000 && esa.center < 2100
        @test gsb.center > 2000 && gsb.center < 2100
        @test esa.width > 0
        @test gsb.width > 0
        @test result.rsquared > 0.9

        # Test predict
        y_fit = predict(result, spec)
        @test length(y_fit) == length(spec.wavenumber)
    end

    @testset "fit_exp_decay with IRF" begin
        trace = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)
        result = fit_exp_decay(trace; irf=true)

        @test result isa ExpDecayFit
        @test result.tau > 0
        @test !isnan(result.sigma)  # IRF should be fitted
        @test result.rsquared > 0.9
        @test result.signal_type == :esa
    end

    @testset "fit_exp_decay without IRF" begin
        trace = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)
        result = fit_exp_decay(trace; irf=false)

        @test result isa ExpDecayFit
        @test result.tau > 0
        @test isnan(result.sigma)  # No IRF
        @test result.t0 == 0.0     # Default t_start
        @test result.rsquared > 0.9

        # Test with custom t_start
        result_delayed = fit_exp_decay(trace; irf=false, t_start=1.0)
        @test result_delayed.t0 == 1.0
        @test result_delayed.rsquared > 0.9
    end

    @testset "predict" begin
        trace = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)

        # With IRF
        result_irf = fit_exp_decay(trace)
        curve_irf = predict(result_irf, trace)
        @test length(curve_irf) == length(trace.time)
        @test all(isfinite, curve_irf)

        # Without IRF
        result_simple = fit_exp_decay(trace; irf=false)
        curve_simple = predict(result_simple, trace)
        @test length(curve_simple) == length(trace.time)
        @test all(isfinite, curve_simple)

        # Before t0, simple fit should return offset
        pre_t0_idx = findfirst(t -> t < result_simple.t0, trace.time)
        if !isnothing(pre_t0_idx)
            @test curve_simple[pre_t0_idx] ≈ result_simple.offset
        end
    end

    @testset "fit_global" begin
        trace_esa = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)
        trace_gsb = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_gsb.lvm"); mode=:OD)

        result = fit_global([trace_esa, trace_gsb]; labels=["ESA", "GSB"])

        @test result isa GlobalFitResult
        @test all(result.taus .> 0)
        @test !isnan(result.sigma)
        @test result.rsquared > 0.9
        @test length(result.amplitudes) == 2
        @test length(result.offsets) == 2
        @test result.labels == ["ESA", "GSB"]

        # ESA should have positive amplitude, GSB negative
        @test result.amplitudes[1] > 0
        @test result.amplitudes[2] < 0

        # predict for global fit
        curves = predict(result, [trace_esa, trace_gsb])
        @test length(curves) == 2
        @test length(curves[1]) == length(trace_esa.time)
        @test length(curves[2]) == length(trace_gsb.time)
    end

    @testset "Biexponential fitting (n_exp=2)" begin
        trace = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)

        # With IRF
        result_irf = fit_exp_decay(trace; n_exp=2, irf=true)
        @test result_irf isa MultiexpDecayFit
        @test length(result_irf.taus) == 2
        @test all(result_irf.taus .> 0)
        @test result_irf.taus[1] < result_irf.taus[2]  # Ordered: fast < slow
        @test !isnan(result_irf.sigma)  # IRF fitted
        @test result_irf.rsquared > 0.9

        # Without IRF
        result_simple = fit_exp_decay(trace; n_exp=2, irf=false)
        @test result_simple isa MultiexpDecayFit
        @test isnan(result_simple.sigma)  # No IRF
        @test result_simple.t0 == 0.0     # Default t_start
        @test result_simple.rsquared > 0.9

        # Custom t_start (only for non-IRF)
        result_delayed = fit_exp_decay(trace; n_exp=2, irf=false, t_start=5.0)
        @test result_delayed.t0 >= 5.0

        # predict should work for both
        curve_irf = predict(result_irf, trace)
        curve_simple = predict(result_simple, trace)
        @test length(curve_irf) == length(trace.time)
        @test length(curve_simple) == length(trace.time)
        @test all(isfinite, curve_irf)
        @test all(isfinite, curve_simple)
    end

    @testset "Multi-exponential fitting (n_exp parameter)" begin
        trace = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)

        # n_exp=1 should return ExpDecayFit
        result1 = fit_exp_decay(trace; n_exp=1)
        @test result1 isa ExpDecayFit
        @test result1.tau > 0
        @test result1.rsquared > 0.9

        # n_exp=2 should return MultiexpDecayFit
        result2 = fit_exp_decay(trace; n_exp=2)
        @test result2 isa MultiexpDecayFit
        @test n_exp(result2) == 2
        @test length(result2.taus) == 2
        @test length(result2.amplitudes) == 2
        @test all(result2.taus .> 0)
        @test result2.taus[1] <= result2.taus[2]  # Sorted fast→slow
        @test result2.rsquared > 0.9

        # weights should sum to ~1
        w = weights(result2)
        @test length(w) == 2
        @test sum(w) ≈ 1.0 atol=1e-10

        # n_exp=3 should also work
        result3 = fit_exp_decay(trace; n_exp=3)
        @test result3 isa MultiexpDecayFit
        @test n_exp(result3) == 3
        @test length(result3.taus) == 3
        @test result3.taus[1] <= result3.taus[2] <= result3.taus[3]

        # Without IRF
        result_no_irf = fit_exp_decay(trace; n_exp=2, irf=false)
        @test result_no_irf isa MultiexpDecayFit
        @test isnan(result_no_irf.sigma)
        @test result_no_irf.rsquared > 0.9

        # predict should work
        curve2 = predict(result2, trace)
        @test length(curve2) == length(trace.time)
        @test all(isfinite, curve2)

        curve3 = predict(result3, trace)
        @test length(curve3) == length(trace.time)
        @test all(isfinite, curve3)

        curve_no_irf = predict(result_no_irf, trace)
        @test length(curve_no_irf) == length(trace.time)
        @test all(isfinite, curve_no_irf)
    end

    @testset "TAMatrix loading and indexing" begin
        # Load TAMatrix
        data_dir = joinpath(PROJECT_ROOT, "data/CCD")
        matrix = load_ta_matrix(data_dir;
            time_file="time_axis.txt",
            wavelength_file="wavelength_axis.txt",
            data_file="ta_matrix.lvm",
            time_unit=:fs)

        @test matrix isa TAMatrix
        @test length(matrix.time) > 0
        @test length(matrix.wavelength) > 0
        @test size(matrix.data) == (length(matrix.time), length(matrix.wavelength))

        # Extract TATrace at wavelength
        trace = matrix[λ=600]
        @test trace isa TATrace
        @test length(trace.time) == length(matrix.time)
        @test length(trace.signal) == length(trace.time)
        @test haskey(trace.metadata, :actual_wavelength)
        @test abs(trace.wavelength - 600) < 10  # Within 10 nm of requested

        # Extract TASpectrum at time
        spec = matrix[t=1.0]
        @test spec isa TASpectrum
        @test length(spec.wavenumber) == length(matrix.wavelength)
        @test length(spec.signal) == length(spec.wavenumber)
        @test haskey(spec.metadata, :actual_time)

        # Error cases
        @test_throws ErrorException matrix[]  # No index specified
        @test_throws ErrorException matrix[λ=600, t=1.0]  # Both specified
    end

    @testset "TAMatrix fitting" begin
        data_dir = joinpath(PROJECT_ROOT, "data/CCD")
        matrix = load_ta_matrix(data_dir;
            time_file="time_axis.txt",
            wavelength_file="wavelength_axis.txt",
            data_file="ta_matrix.lvm",
            time_unit=:fs)

        # Extract and fit
        trace = matrix[λ=600]
        result = fit_exp_decay(trace; irf_width=0.15)

        @test result isa ExpDecayFit
        @test result.tau > 0

        # predict should work
        curve = predict(result, trace)
        @test length(curve) == length(trace.time)
        @test all(isfinite, curve)
    end

    @testset "Cavity transmittance physical properties" begin
        # Empty cavity (no absorption): periodic Airy function
        n, α, L, R, ϕ = 1.0, 0.0, 1.0, 0.9, 0.0

        # At resonance, transmittance should be maximum
        # Resonance condition: 4π·n·L·ν = 2π·m for integer m
        # For L=1, n=1: ν_res = m/2
        ν_res = 0.5  # First resonance
        T_res = cavity_transmittance([n, α, L, R, ϕ], [ν_res])[1]

        # Off resonance (halfway between resonances)
        ν_off = 0.25
        T_off = cavity_transmittance([n, α, L, R, ϕ], [ν_off])[1]

        # Peak transmittance > off-resonance transmittance
        @test T_res > T_off

        # Transmittance is bounded: 0 ≤ T ≤ 1
        ν_range = collect(0.0:0.01:2.0)
        T_range = cavity_transmittance([n, α, L, R, ϕ], ν_range)
        @test all(T_range .>= 0)
        @test all(T_range .<= 1)

        # For lossless cavity (α=0), peak transmittance approaches 1
        @test T_res ≈ 1.0 rtol=0.01

        # With absorption, peak transmittance decreases
        α_absorb = 0.5
        T_res_abs = cavity_transmittance([n, α_absorb, L, R, ϕ], [ν_res])[1]
        @test T_res_abs < T_res

        # Higher reflectance → higher finesse → sharper peaks
        R_high = 0.99
        R_low = 0.5
        T_res_high = cavity_transmittance([n, 0.0, L, R_high, ϕ], [ν_res])[1]
        T_off_high = cavity_transmittance([n, 0.0, L, R_high, ϕ], [ν_off])[1]
        T_res_low = cavity_transmittance([n, 0.0, L, R_low, ϕ], [ν_res])[1]
        T_off_low = cavity_transmittance([n, 0.0, L, R_low, ϕ], [ν_off])[1]
        contrast_high = T_res_high / T_off_high
        contrast_low = T_res_low / T_off_low
        @test contrast_high > contrast_low

        # Free spectral range: peaks separated by FSR = 1/(2nL)
        FSR = 1 / (2 * n * L)
        ν_res2 = ν_res + FSR
        T_res2 = cavity_transmittance([n, α, L, R, ϕ], [ν_res2])[1]
        @test T_res2 ≈ T_res rtol=0.01
    end

    @testset "Cavity transmittance fitting" begin
        ν = collect(0.0:0.005:2.0)
        p_true = [1.0, 0.0, 1.0, 0.9, 0.0]
        T_true = cavity_transmittance(p_true, ν)
        noise = 0.005 * randn(length(ν))
        T_data = clamp.(T_true .+ noise, 0.0, 1.0)

        # Fit reflectance (keeping other params fixed for stability)
        model(p, x) = cavity_transmittance([1.0, 0.0, 1.0, p[1], 0.0], x)
        p0 = [0.85]
        prob = NonlinearCurveFitProblem(model, p0, ν, T_data)
        sol = solve(prob)
        R_fit = coef(sol)[1]

        @test isapprox(R_fit, p_true[4], atol=0.05)
    end

    @testset "eLabFTW write API guards" begin
        # Without configuration, all write functions should error
        disable_elabftw()
        @test_throws ErrorException create_experiment(title="test")
        @test_throws ErrorException update_experiment(1; title="test")
        @test_throws ErrorException upload_to_experiment(1, "test.pdf")
        @test_throws ErrorException tag_experiment(1, "test")
        @test_throws ErrorException get_experiment(1)
        @test_throws ErrorException log_to_elab(title="test")
        @test_throws ErrorException list_experiments()
        @test_throws ErrorException search_experiments(query="test")
        @test_throws ErrorException delete_experiment(1)
    end

    @testset "eLabFTW batch operation guards" begin
        disable_elabftw()
        # Batch operations require at least one filter
        @test_throws ErrorException delete_experiments()
        @test_throws ErrorException tag_experiments("tag")
        @test_throws ErrorException update_experiments(new_body="test")
    end

    @testset "eLabFTW steps and links guards" begin
        disable_elabftw()
        @test_throws ErrorException test_connection()
        @test_throws ErrorException add_step(1, "test")
        @test_throws ErrorException list_steps(1)
        @test_throws ErrorException finish_step(1, 1)
        @test_throws ErrorException link_experiments(1, 2)
        @test_throws ErrorException create_from_template(1)
    end

    @testset "print_experiments formatting" begin
        buf = IOBuffer()
        print_experiments(Dict[]; io=buf)
        @test occursin("No experiments", String(take!(buf)))

        experiments = [
            Dict("id" => 42, "title" => "Test experiment",
                 "date" => "2026-02-09T12:00:00",
                 "tags" => [Dict("tag" => "ftir")])
        ]
        buf = IOBuffer()
        print_experiments(experiments; io=buf)
        output = String(take!(buf))
        @test occursin("42", output)
        @test occursin("Test experiment", output)
        @test occursin("ftir", output)
    end

    @testset "tags_from_sample" begin
        # Test with Dict
        sample = Dict(
            "solute" => "NH4SCN",
            "solvent" => "DMF",
            "concentration" => "1.0M",
            "substrate" => "CaF2",
            "_id" => "NH4SCN_DMF_1M",
            "path" => "ftir/test.csv",
            "date" => "2025-06-19",
            "pathlength" => 12.0  # Non-string, should be skipped
        )

        tags = tags_from_sample(sample)
        @test "NH4SCN" in tags
        @test "DMF" in tags
        @test "1.0M" in tags
        @test "CaF2" in tags
        @test !("NH4SCN_DMF_1M" in tags)  # _id excluded
        @test !("ftir/test.csv" in tags)   # path excluded
        @test !("2025-06-19" in tags)      # date excluded
        @test length(tags) == 4

        # Test with include filter
        tags_filtered = tags_from_sample(sample; include=[:solute, :solvent])
        @test "NH4SCN" in tags_filtered
        @test "DMF" in tags_filtered
        @test !("1.0M" in tags_filtered)
        @test !("CaF2" in tags_filtered)
        @test length(tags_filtered) == 2

        # Test with AnnotatedSpectrum
        spec = load_ftir(solute="NH4SCN", concentration="1.0M")
        tags_spec = tags_from_sample(spec)
        @test "NH4SCN" in tags_spec
        @test "DMF" in tags_spec
    end

    @testset "DAS and plot_das" begin
        using Makie: Figure, Axis

        data_dir = joinpath(PROJECT_ROOT, "data/CCD")
        matrix = load_ta_matrix(data_dir;
            time_file="time_axis.txt",
            wavelength_file="wavelength_axis.txt",
            data_file="ta_matrix.lvm",
            time_unit=:fs)

        # Global fit on subset of wavelengths (fast)
        result = fit_global(matrix; n_exp=2, λ=[550, 600, 650])

        # das accessor re-exported from SpectroscopyTools
        d = das(result)
        @test size(d, 1) == 2
        @test size(d, 2) == 3

        # plot_das returns (Figure, Axis)
        fig, ax = plot_das(result)
        @test fig isa Figure
        @test ax isa Axis

        # plot_das! works on existing axis
        fig2 = Figure()
        ax2 = Axis(fig2[1, 1])
        plot_das!(ax2, result)

        # Error without wavelengths (traces-only fit has no wavelength axis)
        no_wl = fit_global([matrix[λ=600], matrix[λ=550]]; n_exp=1)
        @test_throws ErrorException plot_das(no_wl)
    end

    include("test_chirp.jl")

    @testset "format_results" begin
        # Test format_results returns markdown strings for all fit types

        # MultiPeakFitResult
        spec = load_ftir(solute="NH4SCN", concentration="1.0M")
        result = fit_peaks(spec, (2000, 2100))
        md = format_results(result)
        @test md isa String
        @test occursin("## Peak Fit", md)
        @test occursin("| Parameter |", md)
        @test occursin("R²", md)

        # PeakFitResult (single peak)
        pk = result[1]
        md_pk = format_results(pk)
        @test md_pk isa String
        @test occursin("## Peak Fit", md_pk)

        # ExpDecayFit
        trace = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)
        result_exp = fit_exp_decay(trace)
        md_exp = format_results(result_exp)
        @test md_exp isa String
        @test occursin("## Exponential Decay", md_exp)
        @test occursin("τ", md_exp)

        # MultiexpDecayFit (n_exp=2)
        result_biexp = fit_exp_decay(trace; n_exp=2)
        md_biexp = format_results(result_biexp)
        @test md_biexp isa String
        @test occursin("τ", md_biexp)

        # GlobalFitResult
        trace_gsb = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_gsb.lvm"); mode=:OD)
        result_global = fit_global([trace, trace_gsb]; labels=["ESA", "GSB"])
        md_global = format_results(result_global)
        @test md_global isa String
        @test occursin("## Global Fit", md_global)
        @test occursin("Shared", md_global)

        # MultiexpDecayFit
        result_multi = fit_exp_decay(trace; n_exp=2)
        md_multi = format_results(result_multi)
        @test md_multi isa String
        @test occursin("Multi-exponential", md_multi) || occursin("## ", md_multi)
    end

end
