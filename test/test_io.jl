@isdefined(PROJECT_ROOT) || include("testsetup.jl")

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
    # Kinetics file -> TATrace
    trace = load_spectroscopy(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"))
    @test trace isa TATrace
    @test xlabel(trace) == "Time (ps)"

    # Spectrum file -> TASpectrum
    spec = load_spectroscopy(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/spectra/bare_1M_1ps.lvm"))
    @test spec isa TASpectrum
    @test xlabel(spec) == "Wavenumber (cm⁻¹)"

    # Directory -> TAMatrix
    matrix = load_spectroscopy(joinpath(PROJECT_ROOT, "data/CCD"))
    @test matrix isa TAMatrix
    @test is_matrix(matrix) == true

    # Non-existent path should error
    @test_throws ErrorException load_spectroscopy("/nonexistent/path.lvm")
end
