@isdefined(PROJECT_ROOT) || include("testsetup.jl")

if has_data("MIRpumpprobe")
    @testset "PumpProbeData axis_type" begin
        # Load kinetics file (should be time_axis)
        kinetics = load_lvm(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"))
        @test kinetics.axis_type == time_axis

        # Load spectrum file (should be wavelength_axis)
        spectrum = load_lvm(datapath("MIRpumpprobe/spectra/bare_1M_1ps.lvm"))
        @test spectrum.axis_type == wavelength_axis
    end
else
    @info "Skipping PumpProbeData axis_type tests (MIRpumpprobe not present under $DATA_ROOT)"
end

if has_data("MIRpumpprobe") && has_data("CCD")
    @testset "load_spectroscopy auto-detection" begin
        # Kinetics file -> KineticTrace
        trace = load_spectroscopy(datapath("MIRpumpprobe/pp_kinetics_esa.lvm"))
        @test trace isa KineticTrace
        @test xlabel(trace) == "Time (ps)"

        # Spectrum file -> Spectrum
        spec = load_spectroscopy(datapath("MIRpumpprobe/spectra/bare_1M_1ps.lvm"))
        @test spec isa Spectrum
        @test xlabel(spec) == "Wavenumber (cm⁻¹)"

        # Directory -> TimeResolvedMatrix
        matrix = load_spectroscopy(datapath("CCD"))
        @test matrix isa TimeResolvedMatrix
        @test is_matrix(matrix) == true
    end
else
    @info "Skipping load_spectroscopy auto-detection tests (MIRpumpprobe/CCD not present under $DATA_ROOT)"
end

@testset "load_spectroscopy rejects missing paths" begin
    @test_throws ErrorException load_spectroscopy("/nonexistent/path.lvm")
end
