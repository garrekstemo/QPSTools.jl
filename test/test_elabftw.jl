@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "eLabFTW write API guards" begin
    # Without configuration, all write functions should error
    disable_elabftw()
    @test_throws ErrorException create_experiment(title="test")
    @test_throws ErrorException update_experiment(1; title="test")
    @test_throws ErrorException upload_to_experiment(1, "test.pdf")
    @test_throws ErrorException tag_experiment(1, "test")
    @test_throws ErrorException tag_experiment(1, ["a", "b"])
    @test_throws ErrorException get_experiment(1)
    @test_throws ErrorException log_to_elab(title="test")
    @test_throws ErrorException list_experiments()
    @test_throws ErrorException search_experiments(query="test")
    @test_throws ErrorException delete_experiment(1)
end

@testset "eLabFTW tag API guards" begin
    disable_elabftw()
    @test_throws ErrorException list_tags(1)
    @test_throws ErrorException untag_experiment(1, 1)
    @test_throws ErrorException clear_tags(1)
    @test_throws ErrorException list_team_tags()
    @test_throws ErrorException rename_team_tag(1, "new")
    @test_throws ErrorException delete_team_tag(1)
end

@testset "eLabFTW batch operation guards" begin
    disable_elabftw()
    # Batch operations require at least one filter
    @test_throws ErrorException delete_experiments()
    @test_throws ErrorException tag_experiments("tag")
    @test_throws ErrorException update_experiments(new_body="test")
end

@testset "eLabFTW steps and links guards" begin
    disable_elabftw()
    @test_throws ErrorException test_connection()
    @test_throws ErrorException add_step(1, "test")
    @test_throws ErrorException list_steps(1)
    @test_throws ErrorException finish_step(1, 1)
    @test_throws ErrorException link_experiments(1, 2)
    @test_throws ErrorException create_from_template(1)
end

@testset "print_experiments formatting" begin
    buf = IOBuffer()
    print_experiments(Dict[]; io=buf)
    @test occursin("No experiments", String(take!(buf)))

    experiments = [
        Dict("id" => 42, "title" => "Test experiment",
             "date" => "2026-02-09T12:00:00",
             "tags" => [Dict("tag" => "ftir")])
    ]
    buf = IOBuffer()
    print_experiments(experiments; io=buf)
    output = String(take!(buf))
    @test occursin("42", output)
    @test occursin("Test experiment", output)
    @test occursin("ftir", output)
end

@testset "print_tags formatting" begin
    buf = IOBuffer()
    print_tags(Any[]; io=buf)
    @test occursin("No tags", String(take!(buf)))

    # Entity tags (tag_id key)
    entity_tags = [
        Dict("tag" => "ftir", "tag_id" => 7, "is_favorite" => 0),
        Dict("tag" => "nh4scn", "tag_id" => 12, "is_favorite" => 0),
    ]
    buf = IOBuffer()
    print_tags(entity_tags; io=buf)
    output = String(take!(buf))
    @test occursin("7", output)
    @test occursin("ftir", output)
    @test occursin("nh4scn", output)

    # Team tags (id + item_count keys)
    team_tags = [
        Dict("id" => 3, "tag" => "raman", "item_count" => 5, "is_favorite" => 0, "team" => 1),
    ]
    buf = IOBuffer()
    print_tags(team_tags; io=buf)
    output = String(take!(buf))
    @test occursin("raman", output)
    @test occursin("5", output)
end

@testset "tags_from_sample" begin
    # Test with Dict
    sample = Dict(
        "solute" => "NH4SCN",
        "solvent" => "DMF",
        "concentration" => "1.0M",
        "substrate" => "CaF2",
        "_id" => "NH4SCN_DMF_1M",
        "path" => "ftir/test.csv",
        "date" => "2025-06-19",
        "pathlength" => 12.0  # Non-string, should be skipped
    )

    tags = tags_from_sample(sample)
    @test "NH4SCN" in tags
    @test "DMF" in tags
    @test "1.0M" in tags
    @test "CaF2" in tags
    @test !("NH4SCN_DMF_1M" in tags)  # _id excluded
    @test !("ftir/test.csv" in tags)   # path excluded
    @test !("2025-06-19" in tags)      # date excluded
    @test length(tags) == 4

    # Test with include filter
    tags_filtered = tags_from_sample(sample; include=[:solute, :solvent])
    @test "NH4SCN" in tags_filtered
    @test "DMF" in tags_filtered
    @test !("1.0M" in tags_filtered)
    @test !("CaF2" in tags_filtered)
    @test length(tags_filtered) == 2

    # Test with AnnotatedSpectrum
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
