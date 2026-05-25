# Smoke tests for the QPSScanFormat ⇄ QPSTools integration.
#
# Student workflow this should make work:
#
#     using QPSTools
#     result = load_scan("foo.h5")   # reader re-exported from QPSScanFormat
#     QPSScanFormat.save_kinetic_scan(...)   # writers stay namespace-prefixed
#
# Read-side names are explicitly re-exported as a documented exception to the
# no-sibling-re-export rule (see QPSTools/CLAUDE.md). Writers and schema
# constants are NOT re-exported.

@testset "QPSScanFormat coexistence + re-exports" begin
    @testset "both packages load alongside QPSTools" begin
        @test isdefined(@__MODULE__, :QPSScanFormat)
        @test isdefined(@__MODULE__, :QPSTools)
        @test isdefined(@__MODULE__, :OpticalSpectroscopy)
    end

    @testset "read-side API re-exported, writers and schema NOT re-exported" begin
        qpstools_names = names(QPSTools)

        # Read-side API: re-exported.
        @test :load_scan ∈ qpstools_names
        @test :LoadedScanResult ∈ qpstools_names
        @test :LoadedSpectralResult ∈ qpstools_names
        @test :LoadedCompositeResult ∈ qpstools_names
        @test :LoadedNoiseResult ∈ qpstools_names
        @test :update_scan_description! ∈ qpstools_names
        @test :update_scan_comment! ∈ qpstools_names
        @test :update_scan_sample_name! ∈ qpstools_names

        # Writers + schema constants: NOT re-exported, reachable only via
        # QPSScanFormat.* (intentional — students don't write files, QPSDrive does).
        @test :save_kinetic_scan ∉ qpstools_names
        @test :save_spectral_scan ∉ qpstools_names
        @test :save_composite_scan ∉ qpstools_names
        @test :save_broadband_scan ∉ qpstools_names
        @test :save_noise_scan ∉ qpstools_names
        @test :FORMAT_VERSION ∉ qpstools_names
        @test :FORMAT_TAG ∉ qpstools_names
        @test :is_hdf5_path ∉ qpstools_names
    end

    @testset "round-trip: write via QPSScanFormat, read via QPSTools.load_scan" begin
        trace = TATrace(collect(0.0:0.5:5.0), randn(11))
        sweeps = SweepData(randn(11, 3), randn(11, 3), zeros(11, 3))

        mktempdir() do dir
            path = joinpath(dir, "smoke.h5")
            QPSScanFormat.save_kinetic_scan(trace, path;
                sweeps = sweeps,
                description = "QPSTools coexistence smoke",
                duration_seconds = 1.0,
            )
            # Reader called without the QPSScanFormat. prefix — this is the
            # ergonomic win of the re-export.
            r = load_scan(path)
            @test r isa LoadedScanResult
            @test r.description == "QPSTools coexistence smoke"
            @test r.trace.time ≈ trace.time
            @test r.sweeps.X ≈ sweeps.X
        end
    end
end
