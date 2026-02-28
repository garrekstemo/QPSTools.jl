@isdefined(PROJECT_ROOT) || include("testsetup.jl")

# Guard and formatting tests are now in ElabFTW.jl/test/runtests.jl.
# Only QPSTools-specific glue tests remain here.

@testset "tags_from_sample (AnnotatedSpectrum)" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv");
                     solute="NH4SCN", solvent="DMF", concentration="1.0M")
    tags_spec = tags_from_sample(spec)
    @test "NH4SCN" in tags_spec
    @test "DMF" in tags_spec
    @test "1.0M" in tags_spec

    # Empty sample dict returns empty tags
    spec_bare = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    @test isempty(tags_from_sample(spec_bare))
end

@testset "JASCO technique tag" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    @test QPSTools._jasco_technique_tag(spec) == "ftir"

    raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
    @test QPSTools._jasco_technique_tag(raman) == "raman"
end
