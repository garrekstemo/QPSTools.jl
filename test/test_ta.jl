@isdefined(PROJECT_ROOT) || include("testsetup.jl")

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
    @test result2.taus[1] <= result2.taus[2]  # Sorted fast->slow
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
