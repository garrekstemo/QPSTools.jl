@isdefined(PROJECT_ROOT) || include("testsetup.jl")

# Guard and formatting tests are now in ElabFTW.jl/test/runtests.jl.
# Only QPSTools-specific glue tests remain here.

@testset "eLabFTW extension is loaded" begin
    # The provenance helpers live in the weak-dep extension, which `using ElabFTW`
    # (testsetup.jl) loads. Reaching it confirms the extension is wired up.
    ext = Base.get_extension(QPSTools, :QPSToolsElabFTWExt)
    @test ext !== nothing
end

if has_data("ftir") && has_data("raman")
    @testset "tags_from_sample (Spectrum)" begin
        spec = load_spectrum(datapath("ftir/1.0M_NH4SCN_DMF.csv");
                             solute="NH4SCN", solvent="DMF", concentration="1.0M")
        tags_spec = tags_from_sample(spec)
        @test "NH4SCN" in tags_spec
        @test "DMF" in tags_spec
        @test "1.0M" in tags_spec

        # Empty sample dict returns empty tags
        spec_bare = load_spectrum(datapath("ftir/1.0M_NH4SCN_DMF.csv"))
        @test isempty(tags_from_sample(spec_bare))
    end

    @testset "technique tag from token" begin
        ext = Base.get_extension(QPSTools, :QPSToolsElabFTWExt)

        spec = load_spectrum(datapath("ftir/1.0M_NH4SCN_DMF.csv"))
        @test ext._technique_tag(spec) == "ftir"

        raman = load_spectrum(datapath("raman/ZIF62_crystal_1.csv"))
        @test ext._technique_tag(raman) == "raman"
    end
else
    @info "Skipping eLabFTW glue tests on real spectra (ftir/raman not present under $DATA_ROOT)"
end
