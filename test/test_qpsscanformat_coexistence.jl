# Smoke tests for the recommended student workflow:
#
#     using QPSTools
#     using QPSScanFormat
#     result = load_scan("foo.h5")
#
# QPSTools does not re-export load_scan or Loaded* (per the no-sibling-re-export
# rule in QPSTools' CLAUDE.md); these tests just verify the two packages
# coexist and that a file produced by QPSScanFormat is readable in a session
# that has both packages loaded.

@testset "QPSScanFormat coexistence" begin
    @testset "both packages load alongside QPSTools" begin
        @test isdefined(@__MODULE__, :QPSScanFormat)
        @test isdefined(@__MODULE__, :QPSTools)
        @test isdefined(@__MODULE__, :SpectroscopyTools)
    end

    @testset "QPSTools does not re-export load_scan or Loaded* types" begin
        # Per QPSTools CLAUDE.md: "using QPSTools brings in only names QPSTools
        # itself defines. No sibling re-exports." Confirm the public names of
        # QPSScanFormat are reachable via the QPSScanFormat module, not the
        # QPSTools module.
        @test :load_scan ∉ names(QPSTools)
        @test :LoadedScanResult ∉ names(QPSTools)
        @test :load_scan ∈ names(QPSScanFormat)
        @test :LoadedScanResult ∈ names(QPSScanFormat)
    end

    @testset "round-trip a QPSScanFormat file in a QPSTools session" begin
        trace = TATrace(collect(0.0:0.5:5.0), randn(11))
        sweeps = SweepData(randn(11, 3), randn(11, 3), zeros(11, 3))

        mktempdir() do dir
            path = joinpath(dir, "smoke.h5")
            QPSScanFormat.save_kinetic_scan(trace, path;
                sweeps = sweeps,
                description = "QPSTools coexistence smoke",
                duration_seconds = 1.0,
            )
            r = QPSScanFormat.load_scan(path)
            @test r isa QPSScanFormat.LoadedScanResult
            @test r.description == "QPSTools coexistence smoke"
            @test r.trace.time ≈ trace.time
            @test r.sweeps.X ≈ sweeps.X
        end
    end
end
