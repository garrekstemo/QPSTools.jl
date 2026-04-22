@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "Type hierarchy" begin
    # AnnotatedSpectrum is itself an AbstractSpectroscopyData
    @test QPSTools.AnnotatedSpectrum <: AbstractSpectroscopyData

    # CavitySpectrum is the only AnnotatedSpectrum subtype defined here
    @test CavitySpectrum <: QPSTools.AnnotatedSpectrum
    @test CavitySpectrum <: AbstractSpectroscopyData

    # TA types implement AbstractSpectroscopyData (re-checked here so the
    # boundary stays explicit)
    @test TATrace <: AbstractSpectroscopyData
    @test TASpectrum <: AbstractSpectroscopyData
    @test TAMatrix <: AbstractSpectroscopyData
end

@testset "Module symbols defined" begin
    @test isdefined(QPSTools, :PumpProbeData)
    @test isdefined(QPSTools, :AxisType)
    @test isdefined(QPSTools, :AnnotatedSpectrum)
    @test isdefined(QPSTools, :CavitySpectrum)
end
