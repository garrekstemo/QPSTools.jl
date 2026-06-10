@isdefined(PROJECT_ROOT) || include("testsetup.jl")

using Logging
using Dates: DateTime
# The AnnotatedSpectrum T↔A dispatches extend OpticalSpectroscopy's generic
# functions (QPSTools imports them from there). JASCOFiles exports the same
# names, so qualify to avoid the using-ambiguity.
import OpticalSpectroscopy: transmittance_to_absorbance, absorbance_to_transmittance

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

@testset "AnnotatedSpectrum transmittance ↔ absorbance" begin
    # Regression pins for the AnnotatedSpectrum conversion path. The numerics
    # are owned by OpticalSpectroscopy (single owner); the dispatch passes
    # percent explicitly with default percent=true because JASCO instruments
    # record percent transmittance (0–100).
    spec = JASCOSpectrum("cavity", DateTime(2026), "test", "INFRARED SPECTRUM",
                         "1/CM", "TRANSMITTANCE",
                         [1000.0, 2000.0, 3000.0], [95.0, 50.0, 10.0],
                         Dict{String,Any}())
    cs = CavitySpectrum(spec, Dict{String,Any}("_id" => "test"), "test.csv")

    # Pinned %T → A: A = -log10(T/100); T = 10% → A = 1 landmark
    a = transmittance_to_absorbance(cs)
    @test a isa CavitySpectrum
    @test a.data.yunits == "ABS"
    @test a.data.x == spec.x
    @test ydata(a) ≈ [-log10(0.95), -log10(0.50), 1.0]

    # Explicit percent=false for already-fractional data
    spec_frac = JASCOSpectrum("cavity", DateTime(2026), "test", "INFRARED SPECTRUM",
                              "1/CM", "TRANSMITTANCE_FRAC",
                              [1000.0], [0.5], Dict{String,Any}())
    cs_frac = CavitySpectrum(spec_frac, Dict{String,Any}(), "test.csv")
    @test ydata(transmittance_to_absorbance(cs_frac; percent=false)) ≈ [-log10(0.5)]

    # Round trip back to %T preserves values, units, and sample metadata
    t = absorbance_to_transmittance(a)
    @test t isa CavitySpectrum
    @test t.data.yunits == "TRANSMITTANCE"
    @test ydata(t) ≈ [95.0, 50.0, 10.0]
    @test t.sample === cs.sample
    tf = absorbance_to_transmittance(a; percent=false)
    @test tf.data.yunits == "TRANSMITTANCE_FRAC"
    @test ydata(tf) ≈ [0.95, 0.50, 0.10]

    # The dispatches must route through OpticalSpectroscopy's numerics, not
    # JASCOFiles': JASCOFiles 1.x emits a deprecation-style warning when its
    # JASCOSpectrum methods are called without an explicit percent, so the
    # AnnotatedSpectrum path must stay silent.
    @test_logs min_level=Logging.Warn transmittance_to_absorbance(cs)
    @test_logs min_level=Logging.Warn absorbance_to_transmittance(a)

    # OpticalSpectroscopy guard semantics: nonpositive transmittance throws
    # (JASCOFiles 1.x silently returned Inf for T = 0)
    spec_zero = JASCOSpectrum("z", DateTime(2026), "test", "INFRARED SPECTRUM",
                              "1/CM", "TRANSMITTANCE",
                              [1000.0], [0.0], Dict{String,Any}())
    cs_zero = CavitySpectrum(spec_zero, Dict{String,Any}(), "z.csv")
    @test_throws ArgumentError transmittance_to_absorbance(cs_zero)
end
