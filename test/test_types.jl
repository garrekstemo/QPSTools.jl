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
    @test KineticTrace <: AbstractSpectroscopyData
    @test TASpectrum <: AbstractSpectroscopyData
    @test TimeResolvedMatrix <: AbstractSpectroscopyData
end

@testset "Module symbols defined" begin
    @test isdefined(QPSTools, :PumpProbeData)
    @test isdefined(QPSTools, :AxisType)
    @test isdefined(QPSTools, :AnnotatedSpectrum)
    @test isdefined(QPSTools, :CavitySpectrum)
end

@testset "AnnotatedSpectrum transmittance ↔ absorbance" begin
    # Regression pins for the AnnotatedSpectrum conversion path. Semantics
    # are owned by JASCOFiles 2.0: scale inferred from yunits, explicit
    # percent overrides, canonical ABSORBANCE output, NaN-with-warning for
    # nonpositive transmittance.
    spec = JASCOSpectrum("cavity", DateTime(2026), "test", "INFRARED SPECTRUM",
                         "1/CM", "TRANSMITTANCE",
                         [1000.0, 2000.0, 3000.0], [95.0, 50.0, 10.0],
                         Dict{String,Any}())
    cs = CavitySpectrum(spec, Dict{String,Any}("_id" => "test"), "test.csv")

    # Pinned %T → A with the scale inferred from yunits: T = 10% → A = 1
    a = transmittance_to_absorbance(cs)
    @test a isa CavitySpectrum
    @test a.data.yunits == "ABSORBANCE"
    @test a.data.x == spec.x
    @test ydata(a) ≈ [-log10(0.95), -log10(0.50), 1.0]

    # TRANSMITTANCE_FRAC is inferred as fractional; explicit percent agrees
    spec_frac = JASCOSpectrum("cavity", DateTime(2026), "test", "INFRARED SPECTRUM",
                              "1/CM", "TRANSMITTANCE_FRAC",
                              [1000.0], [0.5], Dict{String,Any}())
    cs_frac = CavitySpectrum(spec_frac, Dict{String,Any}(), "test.csv")
    @test ydata(transmittance_to_absorbance(cs_frac)) ≈ [-log10(0.5)]
    @test ydata(transmittance_to_absorbance(cs_frac; percent=false)) ≈ [-log10(0.5)]

    # Round trip back to %T: output scale is an explicit, required choice
    t = absorbance_to_transmittance(a; percent=true)
    @test t isa CavitySpectrum
    @test t.data.yunits == "TRANSMITTANCE"
    @test ydata(t) ≈ [95.0, 50.0, 10.0]
    @test t.sample === cs.sample
    tf = absorbance_to_transmittance(a; percent=false)
    @test tf.data.yunits == "TRANSMITTANCE_FRAC"
    @test ydata(tf) ≈ [0.95, 0.50, 0.10]

    # a→t without an explicit output scale is a hard error (2.0 semantics)
    @test_throws UndefKeywordError absorbance_to_transmittance(a)

    # t→a on a non-transmittance spectrum is rejected (no silent guessing)
    @test_throws ArgumentError transmittance_to_absorbance(a)

    # Nonpositive transmittance maps to NaN with a warning (saturated bands
    # are routine in real FTIR data; the conversion must not crash)
    spec_zero = JASCOSpectrum("z", DateTime(2026), "test", "INFRARED SPECTRUM",
                              "1/CM", "TRANSMITTANCE",
                              [1000.0], [0.0], Dict{String,Any}())
    cs_zero = CavitySpectrum(spec_zero, Dict{String,Any}(), "z.csv")
    a_zero = @test_logs (:warn, r"nonpositive") transmittance_to_absorbance(cs_zero)
    @test isnan(only(ydata(a_zero)))
end
