using Test
using QPSTools

const PROJECT_ROOT = dirname(@__DIR__)

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
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        @test source_file(spec) isa String
        @test !isempty(source_file(spec))
        @test npoints(spec) == length(spec.data.x)
        @test title(spec) == source_file(spec)
    end

    @testset "Extended interface - Raman source_file and npoints" begin
        raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
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
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        @test spec isa FTIRSpectrum
        @test length(spec.data.x) > 0
    end

    @testset "FTIR loading with kwargs" begin
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv");
                         solute="NH4SCN", concentration="1.0M")
        @test spec isa FTIRSpectrum
        @test spec.sample["solute"] == "NH4SCN"
        @test spec.sample["concentration"] == "1.0M"
    end

    @testset "FTIR bad path" begin
        @test_throws ErrorException load_ftir("/nonexistent/file.csv")
    end

    @testset "FTIR interface" begin
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        @test xdata(spec) === spec.data.x
        @test ydata(spec) === spec.data.y
        @test xlabel(spec) == "Wavenumber (cm⁻¹)"
        @test ylabel(spec) == get(QPSTools._FTIR_YLABEL, spec.data.yunits, "Signal")
        @test is_matrix(spec) == false
        @test zdata(spec) === nothing
    end

    @testset "Raman loading" begin
        raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
        @test raman isa RamanSpectrum
        @test length(raman.data.x) > 0
    end

    @testset "Raman loading with kwargs" begin
        raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv");
                           material="ZIF-62", phase="crystal")
        @test raman isa RamanSpectrum
        @test raman.sample["material"] == "ZIF-62"
        @test raman.sample["phase"] == "crystal"
    end

    @testset "Raman bad path" begin
        @test_throws ErrorException load_raman("/nonexistent/file.csv")
    end

    @testset "Raman interface" begin
        raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
        @test xdata(raman) === raman.data.x
        @test ydata(raman) === raman.data.y
        @test xlabel(raman) == "Raman Shift (cm⁻¹)"
        @test ylabel(raman) == "Intensity"
        @test is_matrix(raman) == false
        @test zdata(raman) === nothing
    end

    @testset "Semantic accessors - FTIR" begin
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        @test wavenumber(spec) === xdata(spec)
        @test signal(spec) === ydata(spec)
        @test ykind(spec) isa Symbol
        # NH4SCN data is absorbance
        @test ykind(spec) === :absorbance
        @test absorbance(spec) === ydata(spec)
    end

    @testset "Semantic accessors - Raman" begin
        raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
        @test shift(raman) === xdata(raman)
        @test intensity(raman) === ydata(raman)
    end

    @testset "FTIR peak fitting (fit_peaks)" begin
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
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
        raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
        result = fit_peaks(raman, (1250, 1300))

        @test result isa MultiPeakFitResult
        @test length(result) >= 1
        pk = result[1]
        @test haskey(pk, :amplitude)
        @test haskey(pk, :center)
    end

    @testset "Spectrum subtraction" begin
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        ref = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/DMF.csv"))

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
        @test_throws ErrorException tag_experiment(1, ["a", "b"])
        @test_throws ErrorException get_experiment(1)
        @test_throws ErrorException log_to_elab(title="test")
        @test_throws ErrorException list_experiments()
        @test_throws ErrorException search_experiments(query="test")
        @test_throws ErrorException delete_experiment(1)
    end

    @testset "eLabFTW tag API guards" begin
        disable_elabftw()
        @test_throws ErrorException list_tags(1)
        @test_throws ErrorException untag_experiment(1, 1)
        @test_throws ErrorException clear_tags(1)
        @test_throws ErrorException list_team_tags()
        @test_throws ErrorException rename_team_tag(1, "new")
        @test_throws ErrorException delete_team_tag(1)
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

    @testset "print_tags formatting" begin
        buf = IOBuffer()
        print_tags(Any[]; io=buf)
        @test occursin("No tags", String(take!(buf)))

        # Entity tags (tag_id key)
        entity_tags = [
            Dict("tag" => "ftir", "tag_id" => 7, "is_favorite" => 0),
            Dict("tag" => "nh4scn", "tag_id" => 12, "is_favorite" => 0),
        ]
        buf = IOBuffer()
        print_tags(entity_tags; io=buf)
        output = String(take!(buf))
        @test occursin("7", output)
        @test occursin("ftir", output)
        @test occursin("nh4scn", output)

        # Team tags (id + item_count keys)
        team_tags = [
            Dict("id" => 3, "tag" => "raman", "item_count" => 5, "is_favorite" => 0, "team" => 1),
        ]
        buf = IOBuffer()
        print_tags(team_tags; io=buf)
        output = String(take!(buf))
        @test occursin("raman", output)
        @test occursin("5", output)
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
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv");
                         solute="NH4SCN", solvent="DMF", concentration="1.0M")
        tags_spec = tags_from_sample(spec)
        @test "NH4SCN" in tags_spec
        @test "DMF" in tags_spec
        @test "1.0M" in tags_spec

        # Empty sample dict returns empty tags
        spec_bare = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        @test isempty(tags_from_sample(spec_bare))
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

    @testset "plot_ta_heatmap" begin
        using Makie: Figure, Axis

        data_dir = joinpath(PROJECT_ROOT, "data/CCD")
        matrix = load_ta_matrix(data_dir;
            time_file="time_axis.txt",
            wavelength_file="wavelength_axis.txt",
            data_file="ta_matrix.lvm",
            time_unit=:fs)

        # Default call returns (Figure, Axis, Heatmap)
        fig, ax, hm = plot_ta_heatmap(matrix)
        @test fig isa Figure
        @test ax isa Axis

        # With optional kwargs
        fig2, ax2, hm2 = plot_ta_heatmap(matrix;
            colormap=:viridis, colorrange=(-0.01, 0.01), title="Test Heatmap")
        @test fig2 isa Figure
        @test ax2 isa Axis
    end

    include("test_chirp.jl")
    include("test_cavity.jl")

    @testset "PLMap loading and interface" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)

        @test m isa PLMap
        @test PLMap <: AbstractSpectroscopyData

        # Grid dimensions
        @test length(m.x) == 51
        @test length(m.y) == 51
        @test size(m.spectra) == (51, 51, 2000)
        @test size(m.intensity) == (51, 51)

        # Spatial axes centered
        @test m.x[1] < 0
        @test m.x[end] > 0
        @test abs(m.x[1] + m.x[end]) < 0.01  # Symmetric

        # Interface
        @test xdata(m) === m.x
        @test ydata(m) === m.y
        @test zdata(m) === m.intensity
        @test xlabel(m) == "X (μm)"
        @test ylabel(m) == "Y (μm)"
        @test is_matrix(m) == true
        @test npoints(m) == (51, 51)
        @test source_file(m) == "CCDtmp_260129_111138.lvm"

        # Show methods
        buf = IOBuffer()
        show(buf, m)
        @test occursin("51×51", String(take!(buf)))

        buf = IOBuffer()
        show(buf, MIME("text/plain"), m)
        @test occursin("Grid", String(take!(buf)))
    end

    @testset "Semantic accessors - PLMap" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)
        @test intensity(m) === m.intensity
    end

    @testset "PLMap auto grid inference" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; step_size=2.16)
        @test length(m.x) == 51
        @test length(m.y) == 51
    end

    @testset "PLMap extract_spectrum" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51)

        # Extract by index
        spec = extract_spectrum(m, 26, 26)
        @test length(spec.pixel) == 2000
        @test length(spec.signal) == 2000
        @test spec.x ≈ m.x[26]
        @test spec.y ≈ m.y[26]

        # Extract by position (nearest neighbor)
        spec_pos = extract_spectrum(m; x=0.0, y=0.0)
        @test length(spec_pos.signal) == 2000
        @test haskey(spec_pos, :ix)
        @test haskey(spec_pos, :iy)

        # Out of bounds
        @test_throws ErrorException extract_spectrum(m, 0, 1)
        @test_throws ErrorException extract_spectrum(m, 1, 52)
    end

    @testset "PLMap normalize_intensity" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51)

        m_norm = normalize_intensity(m)
        @test m_norm isa PLMap
        @test minimum(m_norm.intensity) ≈ 0.0
        @test maximum(m_norm.intensity) ≈ 1.0

        # Spectra should be unchanged
        @test m_norm.spectra === m.spectra
    end

    @testset "PLMap subtract_background (explicit positions)" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)

        # Pick corners as background positions (off-flake)
        bg_positions = [
            (m.x[1], m.y[1]),
            (m.x[end], m.y[1]),
            (m.x[1], m.y[end]),
        ]
        m_bg = subtract_background(m; positions=bg_positions)

        @test m_bg isa PLMap
        @test size(m_bg.spectra) == size(m.spectra)
        @test size(m_bg.intensity) == size(m.intensity)

        # Spatial axes and pixel axis unchanged
        @test m_bg.x === m.x
        @test m_bg.y === m.y
        @test m_bg.pixel === m.pixel

        # Background-subtracted spectra should differ from originals
        @test m_bg.spectra != m.spectra

        # Mean signal at a background position should be closer to zero after subtraction
        bg_before = extract_spectrum(m; x=bg_positions[1][1], y=bg_positions[1][2])
        bg_after = extract_spectrum(m_bg; x=bg_positions[1][1], y=bg_positions[1][2])
        @test abs(sum(bg_after.signal)) < abs(sum(bg_before.signal))
    end

    @testset "PLMap subtract_background (auto mode)" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)

        # Auto mode uses bottom corners with default margin=5
        m_auto = subtract_background(m)

        @test m_auto isa PLMap
        @test size(m_auto.spectra) == size(m.spectra)
        @test size(m_auto.intensity) == size(m.intensity)

        # Spectra should be modified
        @test m_auto.spectra != m.spectra

        # Auto with custom margin
        m_auto2 = subtract_background(m; margin=3)
        @test m_auto2 isa PLMap
        @test m_auto2.spectra != m.spectra
        # Different margins should give slightly different results
        @test m_auto2.spectra != m_auto.spectra
    end

    @testset "PLMap subtract_background preserves pixel_range" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51, pixel_range=(500, 700))

        m_bg = subtract_background(m)
        @test m_bg isa PLMap

        # Intensity should be recomputed from the same pixel_range
        expected_intensity = dropdims(sum(m_bg.spectra[:, :, 500:700]; dims=3); dims=3)
        @test m_bg.intensity ≈ expected_intensity
    end

    @testset "PLMap normalize_intensity after subtract_background" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)

        m_bg = subtract_background(m)
        m_norm = normalize_intensity(m_bg)

        @test m_norm isa PLMap
        @test minimum(m_norm.intensity) ≈ 0.0
        @test maximum(m_norm.intensity) ≈ 1.0

        # All values should be in [0, 1]
        @test all(m_norm.intensity .>= 0.0)
        @test all(m_norm.intensity .<= 1.0)

        # Spectra should be the background-subtracted ones (not re-normalized)
        @test m_norm.spectra === m_bg.spectra
    end

    @testset "PLMap pixel_range integration" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m_full = load_pl_map(plmap_file; nx=51, ny=51)
        m_range = load_pl_map(plmap_file; nx=51, ny=51, pixel_range=(500, 700))

        # Partial integration should give different (smaller) intensity values
        @test sum(m_range.intensity) < sum(m_full.intensity)
        @test size(m_range.intensity) == size(m_full.intensity)
    end

    @testset "PLMap plotting" begin
        using Makie: Figure, Axis

        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51)
        m_norm = normalize_intensity(m)

        # plot_pl_map returns (Figure, Axis, Heatmap)
        fig, ax, hm = plot_pl_map(m_norm)
        @test fig isa Figure
        @test ax isa Axis

        # plot_pl_spectra returns (Figure, Axis)
        fig2, ax2 = plot_pl_spectra(m, [(0.0, 0.0), (10.0, 10.0)])
        @test fig2 isa Figure
        @test ax2 isa Axis
    end

    @testset "PLMap peak_centers" begin
        plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
        m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16, pixel_range=(950, 1100))

        centers = peak_centers(m)
        @test size(centers) == (51, 51)
        @test eltype(centers) == Float64

        # All valid centroids within pixel_range
        valid = filter(!isnan, centers)
        @test !isempty(valid)
        @test all(c -> 950 <= c <= 1100, valid)

        # After background subtraction — masking uses m.intensity,
        # so off-flake regions (low PL) become NaN
        m_bg = subtract_background(m)
        centers_bg = peak_centers(m_bg)
        @test size(centers_bg) == (51, 51)
        @test count(isnan, centers_bg) > count(isnan, centers)

        # Without pixel_range: uses all pixels
        m_full = load_pl_map(plmap_file; nx=51, ny=51)
        centers_full = peak_centers(m_full)
        @test size(centers_full) == (51, 51)

        # Explicit pixel_range kwarg overrides metadata
        centers_custom = peak_centers(m; pixel_range=(960, 1050))
        valid_custom = filter(!isnan, centers_custom)
        @test all(c -> 960 <= c <= 1050, valid_custom)

        # threshold=0 disables masking (intensity cutoff = 0)
        centers_no_mask = peak_centers(m_bg; threshold=0)
        @test count(isnan, centers_no_mask) <= count(isnan, centers_bg)
    end

    @testset "JASCO technique tag" begin
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
        @test QPSTools._jasco_technique_tag(spec) == "ftir"

        raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
        @test QPSTools._jasco_technique_tag(raman) == "raman"
    end

    @testset "format_results" begin
        # Test format_results returns markdown strings for all fit types

        # MultiPeakFitResult
        spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
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
