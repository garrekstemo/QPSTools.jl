@isdefined(PROJECT_ROOT) || include("testsetup.jl")

# QPSTools defines almost no types of its own. General-purpose spectroscopy
# types (`Spectrum`, `KineticTrace`, `TimeResolvedMatrix`, …) and the
# transmittance↔absorbance conversion semantics live in OpticalSpectroscopy and
# are tested there. This file pins the handful of QPS-specific raw-instrument
# types and the type-boundary contract.

@testset "Type boundary" begin
    # The OpticalSpectroscopy analysis types QPSTools threads through
    @test KineticTrace <: AbstractSpectroscopyData
    @test Spectrum <: AbstractSpectroscopyData
    @test TimeResolvedMatrix <: AbstractSpectroscopyData

    # QPS-specific raw-instrument types
    @test isdefined(QPSTools, :PumpProbeData)
    @test isdefined(QPSTools, :AxisType)

    # The collapsed lab spectrum types are gone — steady-state spectra are
    # plain token-stamped `Spectrum`s loaded by `load_spectrum`.
    @test !isdefined(QPSTools, :AnnotatedSpectrum)
    @test !isdefined(QPSTools, :CavitySpectrum)
end
