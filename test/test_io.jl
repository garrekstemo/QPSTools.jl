@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "PumpProbeData axis_type" begin
    # Load kinetics file (should be time_axis)
    kinetics = load_lvm(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"))
    @test kinetics.axis_type == time_axis

    # Load spectrum file (should be wavelength_axis)
    spectrum = load_lvm(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/spectra/bare_1M_1ps.lvm"))
    @test spectrum.axis_type == wavelength_axis
end

@testset "load_spectroscopy auto-detection" begin
    # Kinetics file -> KineticTrace
    trace = load_spectroscopy(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"))
    @test trace isa KineticTrace
    @test xlabel(trace) == "Time (ps)"

    # Spectrum file -> Spectrum
    spec = load_spectroscopy(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/spectra/bare_1M_1ps.lvm"))
    @test spec isa Spectrum
    @test xlabel(spec) == "Wavenumber (cm⁻¹)"

    # Directory -> TimeResolvedMatrix
    matrix = load_spectroscopy(joinpath(PROJECT_ROOT, "data/CCD"))
    @test matrix isa TimeResolvedMatrix
    @test is_matrix(matrix) == true

    # Non-existent path should error
    @test_throws ErrorException load_spectroscopy("/nonexistent/path.lvm")
end
