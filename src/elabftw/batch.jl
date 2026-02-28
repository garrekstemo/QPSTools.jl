# Batch operations on experiments and items

"""
    delete_experiments(; query, tags, dry_run=true) -> Vector{Int}

Delete multiple experiments matching a search query and/or tags.

**Safety:** By default, `dry_run=true` — prints what would be deleted without
actually deleting. Set `dry_run=false` to perform the deletion.

# Arguments
- `query::String` — Full-text search term
- `tags::Vector{String}` — Filter by tags (experiments must have ALL tags)
- `dry_run::Bool` — If true (default), only print what would be deleted

# Examples
```julia
# Preview what would be deleted
delete_experiments(tags=["test"])

# Actually delete
delete_experiments(tags=["test"]; dry_run=false)

# Delete by search query
delete_experiments(query="QPS.jl test"; dry_run=false)
```
"""
function delete_experiments(;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[],
    dry_run::Bool = true
)
    if isnothing(query) && isempty(tags)
        error("Must specify at least one of: query, tags")
    end

    all_matches = _find_all_entities("experiments"; query=query, tags=tags)

    if isempty(all_matches)
        println("No experiments match the criteria")
        return Int[]
    end

    ids = [exp["id"] for exp in all_matches]

    if dry_run
        println("Would delete $(length(ids)) experiment(s):")
        for exp in all_matches
            println("  $(exp["id"]): $(exp["title"])")
        end
        println("\nRe-run with dry_run=false to delete")
    else
        println("Deleting $(length(ids)) experiment(s)...")
        for exp in all_matches
            delete_experiment(exp["id"])
        end
        println("Done")
    end

    return ids
end

"""
    tag_experiments(tag::String; query, tags) -> Vector{Int}

Add a tag to multiple experiments matching a search query and/or existing tags.

# Arguments
- `tag::String` — Tag to add to matching experiments
- `query::String` — Full-text search term
- `tags::Vector{String}` — Filter by existing tags

# Example
```julia
# Add "archived" tag to all experiments tagged "2024"
tag_experiments("archived"; tags=["2024"])

# Add tag to experiments matching a query
tag_experiments("reviewed"; query="NH4SCN")
```
"""
function tag_experiments(tag::String;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[]
)
    if isnothing(query) && isempty(tags)
        error("Must specify at least one of: query, tags")
    end

    all_matches = _find_all_entities("experiments"; query=query, tags=tags)

    if isempty(all_matches)
        println("No experiments match the criteria")
        return Int[]
    end

    ids = [exp["id"] for exp in all_matches]
    println("Adding tag '$tag' to $(length(ids)) experiment(s)...")

    for exp in all_matches
        tag_experiment(exp["id"], tag)
    end

    println("Done")
    return ids
end

"""
    update_experiments(; query, tags, new_body, append_body) -> Vector{Int}

Update multiple experiments matching a search query and/or tags.

# Arguments
- `query::String` — Full-text search term
- `tags::Vector{String}` — Filter by tags
- `new_body::String` — Replace body with this content
- `append_body::String` — Append this content to existing body

# Example
```julia
# Append a note to all experiments tagged "draft"
update_experiments(tags=["draft"]; append_body="\\n\\n---\\nReviewed 2025-02-05")
```
"""
function update_experiments(;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[],
    new_body::Union{String, Nothing} = nothing,
    append_body::Union{String, Nothing} = nothing
)
    if isnothing(query) && isempty(tags)
        error("Must specify at least one of: query, tags")
    end
    if isnothing(new_body) && isnothing(append_body)
        error("Must specify at least one of: new_body, append_body")
    end

    all_matches = _find_all_entities("experiments"; query=query, tags=tags)

    if isempty(all_matches)
        println("No experiments match the criteria")
        return Int[]
    end

    ids = [exp["id"] for exp in all_matches]
    println("Updating $(length(ids)) experiment(s)...")

    for exp in all_matches
        if !isnothing(new_body)
            update_experiment(exp["id"]; body=new_body)
        elseif !isnothing(append_body)
            full_exp = get_experiment(exp["id"])
            current_body = get(full_exp, "body", "")
            update_experiment(exp["id"]; body=current_body * append_body)
        end
    end

    println("Done")
    return ids
end

"""
    delete_items(; query, tags, dry_run=true) -> Vector{Int}

Delete multiple items matching a search query and/or tags.

**Safety:** By default, `dry_run=true` — prints what would be deleted without
actually deleting. Set `dry_run=false` to perform the deletion.

# Arguments
- `query::String` — Full-text search term
- `tags::Vector{String}` — Filter by tags
- `dry_run::Bool` — If true (default), only print what would be deleted
"""
function delete_items(;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[],
    dry_run::Bool = true
)
    if isnothing(query) && isempty(tags)
        error("Must specify at least one of: query, tags")
    end

    all_matches = _find_all_entities("items"; query=query, tags=tags)

    if isempty(all_matches)
        println("No items match the criteria")
        return Int[]
    end

    ids = [item["id"] for item in all_matches]

    if dry_run
        println("Would delete $(length(ids)) item(s):")
        for item in all_matches
            println("  $(item["id"]): $(get(item, "title", ""))")
        end
        println("\nRe-run with dry_run=false to delete")
    else
        println("Deleting $(length(ids)) item(s)...")
        for item in all_matches
            delete_item(item["id"])
        end
        println("Done")
    end

    return ids
end

"""
    tag_items(tag::String; query, tags) -> Vector{Int}

Add a tag to multiple items matching a search query and/or existing tags.

# Arguments
- `tag::String` — Tag to add to matching items
- `query::String` — Full-text search term
- `tags::Vector{String}` — Filter by existing tags
"""
function tag_items(tag::String;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[]
)
    if isnothing(query) && isempty(tags)
        error("Must specify at least one of: query, tags")
    end

    all_matches = _find_all_entities("items"; query=query, tags=tags)

    if isempty(all_matches)
        println("No items match the criteria")
        return Int[]
    end

    ids = [item["id"] for item in all_matches]
    println("Adding tag '$tag' to $(length(ids)) item(s)...")

    for item in all_matches
        tag_item(item["id"], tag)
    end

    println("Done")
    return ids
end

"""
    update_items(; query, tags, new_body, append_body) -> Vector{Int}

Update multiple items matching a search query and/or tags.

# Arguments
- `query::String` — Full-text search term
- `tags::Vector{String}` — Filter by tags
- `new_body::String` — Replace body with this content
- `append_body::String` — Append this content to existing body
"""
function update_items(;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[],
    new_body::Union{String, Nothing} = nothing,
    append_body::Union{String, Nothing} = nothing
)
    if isnothing(query) && isempty(tags)
        error("Must specify at least one of: query, tags")
    end
    if isnothing(new_body) && isnothing(append_body)
        error("Must specify at least one of: new_body, append_body")
    end

    all_matches = _find_all_entities("items"; query=query, tags=tags)

    if isempty(all_matches)
        println("No items match the criteria")
        return Int[]
    end

    ids = [item["id"] for item in all_matches]
    println("Updating $(length(ids)) item(s)...")

    for item in all_matches
        if !isnothing(new_body)
            update_item(item["id"]; body=new_body)
        elseif !isnothing(append_body)
            full_item = get_item(item["id"])
            current_body = get(full_item, "body", "")
            update_item(item["id"]; body=current_body * append_body)
        end
    end

    println("Done")
    return ids
end
