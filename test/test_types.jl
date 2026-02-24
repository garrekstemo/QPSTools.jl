@isdefined(PROJECT_ROOT) || include("testsetup.jl")

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
