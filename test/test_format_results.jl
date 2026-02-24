@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "format_results" begin
    # Test format_results returns markdown strings for all fit types

    # MultiPeakFitResult
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    result = fit_peaks(spec, (2000, 2100))
    md = format_results(result)
    @test md isa String
    @test occursin("## Peak Fit", md)
    @test occursin("| Parameter |", md)
    @test occursin("R²", md)

    # PeakFitResult (single peak)
    pk = result[1]
    md_pk = format_results(pk)
    @test md_pk isa String
    @test occursin("## Peak Fit", md_pk)

    # ExpDecayFit
    trace = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_esa.lvm"); mode=:OD)
    result_exp = fit_exp_decay(trace)
    md_exp = format_results(result_exp)
    @test md_exp isa String
    @test occursin("## Exponential Decay", md_exp)
    @test occursin("τ", md_exp)

    # MultiexpDecayFit (n_exp=2)
    result_biexp = fit_exp_decay(trace; n_exp=2)
    md_biexp = format_results(result_biexp)
    @test md_biexp isa String
    @test occursin("τ", md_biexp)

    # GlobalFitResult
    trace_gsb = load_ta_trace(joinpath(PROJECT_ROOT, "data/MIRpumpprobe/pp_kinetics_gsb.lvm"); mode=:OD)
    result_global = fit_global([trace, trace_gsb]; labels=["ESA", "GSB"])
    md_global = format_results(result_global)
    @test md_global isa String
    @test occursin("## Global Fit", md_global)
    @test occursin("Shared", md_global)

    # MultiexpDecayFit
    result_multi = fit_exp_decay(trace; n_exp=2)
    md_multi = format_results(result_multi)
    @test md_multi isa String
    @test occursin("Multi-exponential", md_multi) || occursin("## ", md_multi)
end
