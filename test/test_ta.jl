@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "find_peak_time" begin
    time = collect(-5.0:0.1:10.0)

    # ESA signal (positive peak)
    signal_esa = exp.(-(time .- 0.5).^2)
    @test find_peak_time(time, signal_esa) ≈ 0.5 atol=0.1

    # GSB signal (negative peak)
    signal_gsb = -exp.(-(time .+ 1.0).^2)
    @test find_peak_time(time, signal_gsb) ≈ -1.0 atol=0.1
end

if !has_data("MIRpumpprobe")
    @info "Skipping MIR pump-probe real-file tests (MIRpumpprobe not present under $DATA_ROOT)"
else

@testset "TA trace loading" begin
    trace = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)

    @test trace isa KineticTrace
    @test length(trace.time) > 0
    @test length(trace.signal) == length(trace.time)

    # Peak should be shifted to t=0
    peak_idx = argmax(trace.signal)
    @test abs(trace.time[peak_idx]) < 0.1  # Peak within 0.1 ps of zero

    # Time axis should span negative to positive
    @test minimum(trace.time) < 0
    @test maximum(trace.time) > 0

    # Test without time shift - peak should NOT be at t=0
    trace_unshifted = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_esa.lvm");
                                    mode=:OD, shift_t0=false)
    peak_idx_unshifted = argmax(trace_unshifted.signal)
    @test abs(trace_unshifted.time[peak_idx_unshifted]) > 0.1  # Peak NOT at zero
end

@testset "TA spectrum loading" begin
    spec = load_ta_spectrum(datapath("MIRpumpprobe/spectra/bare_1M_1ps.lvm");
                            mode=:OD, calibration=-19.0, time_delay=1.0)

    @test spec isa Spectrum
    @test length(xdata(spec)) > 0
    @test length(ydata(spec)) == length(xdata(spec))
    @test spec.metadata[:time_delay] == 1.0

    # Wavenumber should be in reasonable range for MIR
    @test minimum(xdata(spec)) > 1800
    @test maximum(xdata(spec)) < 2300

    # Check metadata
    @test haskey(spec.metadata, :filename)
    @test haskey(spec.metadata, :mode)
    @test spec.metadata[:calibration] == -19.0

    # Test different modes
    spec_diff = load_ta_spectrum(datapath("MIRpumpprobe/spectra/bare_1M_1ps.lvm");
                                 mode=:diff)
    @test spec_diff isa Spectrum
    @test length(ydata(spec_diff)) == length(xdata(spec_diff))
end

@testset "fit_ta_spectrum" begin
    spec = load_ta_spectrum(datapath("MIRpumpprobe/spectra/bare_1M_1ps.lvm");
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
    @test length(y_fit) == length(xdata(spec))
end

@testset "fit_exp_decay with IRF" begin
    trace = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)
    result = fit_exp_decay(trace; irf=true)

    @test result isa ExpDecayFit
    @test result.tau > 0
    @test !isnan(result.sigma)  # IRF should be fitted
    @test result.rsquared > 0.9
    @test result.signal_type == :esa
end

@testset "fit_exp_decay without IRF" begin
    trace = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)
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
    trace = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)

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
    trace_esa = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)
    trace_gsb = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_gsb.lvm"); mode=:OD)

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
    trace = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)

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
    trace = load_ta_trace(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)

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

end  # has_data("MIRpumpprobe")

@testset "load_ta_matrix wavelength fallback + explicit vector" begin
    dir = mktempdir()
    # 3 time rows × 4 pixels, count header, CRLF like the instrument
    open(joinpath(dir, "ta_matrix_test.lvm"), "w") do io
        write(io, "3\r\n")
        for i in 1:3
            write(io, join(0.01i .* (1:4), '\t') * "\r\n")
        end
    end
    open(joinpath(dir, "time_axis.txt"), "w") do io
        write(io, join([0.0, 1000.0, 2000.0], '\n'))
    end

    # (a) no wavelength file anywhere → pixel-index fallback, no throw
    m = @test_logs (:warn, r"pixel indices") load_ta_matrix(dir; data_file="ta_matrix_test.lvm")
    @test m.wavelength == [1.0, 2.0, 3.0, 4.0]
    @test m.metadata[:xquantity] == :pixel

    # (b) explicit wavelength vector wins
    m2 = load_ta_matrix(dir; data_file="ta_matrix_test.lvm", wavelength=[500.0, 510.0, 520.0, 530.0])
    @test m2.wavelength == [500.0, 510.0, 520.0, 530.0]
    @test m2.metadata[:xquantity] == :wavelength
end

@testset "read_axis_file public wrapper" begin
    p = joinpath(mktempdir(), "axis.txt")
    open(p, "w") do io; write(io, "2\n1.5\n2.5\n"); end   # bare-int line-1 = count header
    @test read_axis_file(p) == [1.5, 2.5]
end

@testset "Plain two-column trace loading" begin
    # Pre-processed (time, ΔA) export from the vis-pump/WL-probe setup:
    # tab-separated, CRLF line endings, time already in ps, no headers.
    mktempdir() do dir
        ps_file = joinpath(dir, "sample 0-1000000 630.txt")
        time_ps = -4.0 .+ (0:99) .* 1.1675
        signal = -0.02 .* exp.(-max.(time_ps, 0.0) ./ 100.0) .- 0.005
        open(ps_file, "w") do io
            for (t, s) in zip(time_ps, signal)
                print(io, t, '\t', s, "\r\n")
            end
        end

        trace = load_ta_trace(ps_file; shift_t0=false)
        @test trace isa KineticTrace
        @test length(trace.time) == 100
        @test trace.time[1] ≈ -4.0
        @test trace.time[end] ≈ -4.0 + 99 * 1.1675
        @test trace.signal[1] ≈ signal[1]
        @test isnan(trace.wavelength)
        @test trace.metadata[:mode] == :precomputed

        # wavelength passthrough
        trace_wl = load_ta_trace(ps_file; wavelength=630.0, shift_t0=false)
        @test trace_wl.wavelength == 630.0

        # shift_t0 moves the |signal| peak to t = 0
        shifted = load_ta_trace(ps_file)
        peak_idx = argmin(shifted.signal)
        @test shifted.time[peak_idx] == 0.0

        # fs axis is auto-converted to ps
        fs_file = joinpath(dir, "trace_fs.txt")
        open(fs_file, "w") do io
            for (t, s) in zip(time_ps .* 1000, signal)
                print(io, t, '\t', s, '\n')
            end
        end
        trace_fs = load_ta_trace(fs_file; shift_t0=false)
        @test trace_fs.time ≈ collect(time_ps)

        # load_spectroscopy auto-detects a negative-start axis as kinetics
        auto = load_spectroscopy(ps_file)
        @test auto isa KineticTrace

        # all-positive two-column .txt stays ambiguous → error
        amb_file = joinpath(dir, "ambiguous.txt")
        open(amb_file, "w") do io
            for (t, s) in zip(400.0:700.0, rand(301))
                print(io, t, '\t', s, '\n')
            end
        end
        @test_throws ErrorException load_spectroscopy(amb_file)
    end
end
