"""
Live integration test for eLabFTW API surface.

Run manually against a configured eLabFTW instance:

    julia --project=. test/test_elabftw_live.jl

Requires ELABFTW_URL and ELABFTW_API_KEY environment variables.
Creates temporary experiments and items, exercises the API, then cleans up.
"""

using QPSTools
using Test

# Verify configuration
if !haskey(ENV, "ELABFTW_URL") || !haskey(ENV, "ELABFTW_API_KEY")
    error("Set ELABFTW_URL and ELABFTW_API_KEY environment variables before running")
end

configure_elabftw(
    url = ENV["ELABFTW_URL"],
    api_key = ENV["ELABFTW_API_KEY"]
)
test_connection()

experiment_id = nothing
item_id = nothing

try
    @testset "eLabFTW Live API Tests" begin

        # =================================================================
        # Experiment tag API (existing tests)
        # =================================================================

        @testset "Experiment Tag API" begin

            @testset "Setup: create test experiment" begin
                global experiment_id
                experiment_id = create_experiment(
                    title = "QPSTools.jl API test — safe to delete"
                )
                @test experiment_id isa Int
                println("Created test experiment #$experiment_id")
            end

            @testset "Single tag" begin
                tag_experiment(experiment_id, "test-single")
                tags = list_tags(experiment_id)
                @test any(t -> t["tag"] == "test-single", tags)
            end

            @testset "Batch tags" begin
                tag_experiment(experiment_id, ["test-batch-a", "test-batch-b"])
                tags = list_tags(experiment_id)
                names = [t["tag"] for t in tags]
                @test "test-batch-a" in names
                @test "test-batch-b" in names
            end

            @testset "List tags" begin
                tags = list_tags(experiment_id)
                @test length(tags) >= 3
                @test all(t -> haskey(t, "tag_id") && haskey(t, "tag"), tags)
            end

            @testset "Untag (unreference) single tag" begin
                tags_before = list_tags(experiment_id)
                target = first(t for t in tags_before if t["tag"] == "test-single")
                untag_experiment(experiment_id, target["tag_id"])

                tags_after = list_tags(experiment_id)
                @test !any(t -> t["tag"] == "test-single", tags_after)
                @test length(tags_after) == length(tags_before) - 1
            end

            @testset "Clear all tags" begin
                @test length(list_tags(experiment_id)) >= 2

                clear_tags(experiment_id)
                tags = list_tags(experiment_id)
                @test isempty(tags)
            end

            @testset "Team tag listing" begin
                team_tags = list_team_tags()
                @test team_tags isa Vector
                if !isempty(team_tags)
                    @test haskey(team_tags[1], "id")
                    @test haskey(team_tags[1], "tag")
                end
                println("Team has $(length(team_tags)) tags")
            end
        end

        # =================================================================
        # Items (Resources) API
        # =================================================================

        @testset "Items API" begin

            @testset "Create item" begin
                global item_id
                item_id = create_item(
                    title = "QPSTools.jl test item — safe to delete"
                )
                @test item_id isa Int
                println("Created test item #$item_id")
            end

            @testset "Get item" begin
                item = get_item(item_id)
                @test item["id"] == item_id
                @test occursin("test item", item["title"])
            end

            @testset "Update item" begin
                update_item(item_id; body="Updated description")
                item = get_item(item_id)
                @test occursin("Updated", item["body"])
            end

            @testset "Item tags" begin
                tag_item(item_id, "test-item-tag")
                tags = list_item_tags(item_id)
                @test any(t -> t["tag"] == "test-item-tag", tags)

                tag_item(item_id, ["batch-a", "batch-b"])
                tags = list_item_tags(item_id)
                @test length(tags) >= 3

                clear_item_tags(item_id)
                @test isempty(list_item_tags(item_id))
            end

            @testset "Item steps" begin
                s1 = add_item_step(item_id, "First step")
                @test s1 isa Int

                steps = list_item_steps(item_id)
                @test length(steps) >= 1

                finish_item_step(item_id, s1)
                steps = list_item_steps(item_id)
                @test any(s -> get(s, "finished", false), steps)
            end

            @testset "List and search items" begin
                items = list_items(limit=5)
                @test items isa Vector
                @test length(items) <= 5
            end
        end

        # =================================================================
        # Cross-entity links
        # =================================================================

        @testset "Cross-Entity Links" begin

            @testset "Link experiment to item" begin
                link_experiment_to_item(experiment_id, item_id)
                links = list_experiment_item_links(experiment_id)
                @test any(l -> get(l, "itemid", get(l, "id", -1)) == item_id, links)
            end

            @testset "Unlink experiment from item" begin
                unlink_experiment_from_item(experiment_id, item_id)
                links = list_experiment_item_links(experiment_id)
                @test !any(l -> get(l, "itemid", get(l, "id", -1)) == item_id, links)
            end

            @testset "Experiment-to-experiment links" begin
                links_before = list_experiment_links(experiment_id)
                # Just verify the endpoint works — no second experiment to link to
                @test links_before isa Vector
            end
        end

        # =================================================================
        # Comments
        # =================================================================

        @testset "Comments" begin

            @testset "Experiment comments" begin
                cid = comment_experiment(experiment_id, "Test comment from QPSTools.jl")
                @test cid isa Int

                comments = list_experiment_comments(experiment_id)
                @test length(comments) >= 1
                @test any(c -> occursin("Test comment", get(c, "comment", "")), comments)

                # Update
                update_comment(:experiments, experiment_id, cid, "Updated comment")
                c = get_comment(:experiments, experiment_id, cid)
                @test occursin("Updated", c["comment"])

                # Delete
                delete_comment(:experiments, experiment_id, cid)
                comments = list_experiment_comments(experiment_id)
                @test !any(c -> get(c, "id", -1) == cid, comments)
            end
        end

    end

finally
    # Clean up: delete test entities
    if !isnothing(item_id)
        try
            delete_item(item_id)
        catch e
            @warn "Failed to clean up test item #$item_id" exception=e
        end
    end
    if !isnothing(experiment_id)
        try
            delete_experiment(experiment_id)
        catch e
            @warn "Failed to clean up test experiment #$experiment_id" exception=e
        end
    end
end

println("\nAll live API tests passed.")
