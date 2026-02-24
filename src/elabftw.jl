"""
eLabFTW integration for QPSTools.jl.

Provides full read/write access to eLabFTW for experiment logging,
batch operations, analysis steps, and experiment linking.

# Configuration

Set up eLabFTW connection (typically in startup.jl or environment):

```julia
using QPSTools
configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
test_connection()  # Verify credentials
```

# Usage

```julia
# Log analysis results
spec = load_raman(material="MoS2")
log_to_elab(title="FTIR fit", body=format_results(result))

# Track analysis steps
id = create_experiment(title="TA kinetics analysis")
s1 = add_step(id, "Load and inspect raw data")
s2 = add_step(id, "Fit single exponential with IRF")
finish_step(id, s1)

# Link related experiments
link_experiments(id, previous_id)

# Browse experiments
exps = search_experiments(tags=["ftir"])
print_experiments(exps)

# Create from template
id = create_from_template(42; title="New FTIR run", tags=["ftir"])
```

# Caching

Downloaded files are cached in `data/.cache/elabftw/`. The cache is checked
before making API requests. Clear with `clear_elabftw_cache()`.
"""

# HTTP, JSON, Dates are loaded at module level in QPSTools.jl

# =============================================================================
# Configuration
# =============================================================================

"""eLabFTW configuration state"""
mutable struct ElabFTWConfig
    url::Union{String, Nothing}
    api_key::Union{String, Nothing}
    enabled::Bool
    cache_dir::String
    category_ids::Dict{Symbol, Int}  # :raman => 14, :ftir => 15, etc.
end

const _elabftw_config = ElabFTWConfig(nothing, nothing, false, "", Dict())

"""
    configure_elabftw(; url, api_key, cache_dir, category_ids)

Configure eLabFTW connection.

# Arguments
- `url::String` — eLabFTW instance URL (e.g., "https://lab.elabftw.net")
- `api_key::String` — API key (get from User Panel → API Keys in eLabFTW)
- `cache_dir::String` — Local cache directory (default: "data/.cache/elabftw")
- `category_ids::Dict{Symbol,Int}` — Map of spectrum types to eLabFTW category IDs

# Example
```julia
configure_elabftw(
    url = "https://lab.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"],
    category_ids = Dict(:raman => 14, :ftir => 15)
)
```
"""
function configure_elabftw(;
    url::String,
    api_key::String,
    cache_dir::String = joinpath(homedir(), ".cache", "qpstools", "elabftw"),
    category_ids::Dict{Symbol, Int} = Dict{Symbol, Int}()
)
    _elabftw_config.url = rstrip(url, '/')
    _elabftw_config.api_key = api_key
    _elabftw_config.cache_dir = cache_dir
    _elabftw_config.category_ids = category_ids
    _elabftw_config.enabled = true

    # Create cache directory
    mkpath(cache_dir)

    @info "eLabFTW configured" url=url cache_dir=cache_dir
end

"""
    elabftw_enabled() -> Bool

Check if eLabFTW is configured and enabled.
"""
elabftw_enabled() = _elabftw_config.enabled

"""
    disable_elabftw()

Disable eLabFTW integration.
"""
function disable_elabftw()
    _elabftw_config.enabled = false
    @info "eLabFTW disabled"
end

"""
    enable_elabftw()

Re-enable eLabFTW queries after disabling.
"""
function enable_elabftw()
    if isnothing(_elabftw_config.url)
        error("eLabFTW not configured. Call configure_elabftw() first.")
    end
    _elabftw_config.enabled = true
    @info "eLabFTW enabled"
end

"""
    test_connection()

Verify the eLabFTW connection by fetching the current user's profile.
Prints the user's name and email on success.

# Example
```julia
configure_elabftw(url="https://lab.elabftw.net", api_key=ENV["ELABFTW_API_KEY"])
test_connection()
# => "Connected to eLabFTW as Jane Doe (jane@lab.edu)"
```
"""
function test_connection()
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/users/me"
    response = _elabftw_request(url)
    user = JSON.parse(String(response.body))
    fullname = get(user, "fullname", "Unknown")
    email = get(user, "email", "")
    println("Connected to eLabFTW as $fullname ($email)")
end

# =============================================================================
# API Queries
# =============================================================================

"""
    download_elabftw_file(item_id::Int, upload_id::Int) -> String

Download a file attachment from eLabFTW and cache locally.
Returns the local file path.
"""
function download_elabftw_file(item_id::Int, upload_id::Int; filename::String="")
    cache_path = _get_cache_path(item_id, upload_id, filename)

    # Return cached file if exists
    if isfile(cache_path)
        return cache_path
    end

    # Download from eLabFTW
    url = "$(_elabftw_config.url)/api/v2/items/$item_id/uploads/$upload_id"
    response = _elabftw_request(url; accept="application/octet-stream")

    # Ensure directory exists
    mkpath(dirname(cache_path))

    # Write to cache
    write(cache_path, response.body)
    @info "Downloaded and cached" path=cache_path

    return cache_path
end

# =============================================================================
# Cache Management
# =============================================================================

"""
    clear_elabftw_cache()

Clear the local eLabFTW file cache.
"""
function clear_elabftw_cache()
    cache_dir = _elabftw_config.cache_dir
    if isdir(cache_dir)
        rm(cache_dir; recursive=true)
        mkpath(cache_dir)
        @info "eLabFTW cache cleared" path=cache_dir
    end
end

"""
    elabftw_cache_info() -> NamedTuple

Get information about the eLabFTW cache.
"""
function elabftw_cache_info()
    cache_dir = _elabftw_config.cache_dir
    if !isdir(cache_dir)
        return (files=0, size_mb=0.0, path=cache_dir)
    end

    files = String[]
    total_size = 0
    for (root, dirs, filenames) in walkdir(cache_dir)
        for f in filenames
            path = joinpath(root, f)
            push!(files, path)
            total_size += filesize(path)
        end
    end

    return (
        files = length(files),
        size_mb = round(total_size / 1024^2, digits=2),
        path = cache_dir
    )
end

# =============================================================================
# Experiment Write API
# =============================================================================

"""
    create_experiment(; title, body, category, metadata) -> Int

Create a new experiment in eLabFTW. Returns the experiment ID.

# Arguments
- `title::String` — Experiment title
- `body::String` — Experiment body (supports HTML/markdown)
- `category::Union{Int, Nothing}` — Experiment category ID
- `metadata::Union{Dict, Nothing}` — Extra metadata JSON

# Example
```julia
id = create_experiment(title="FTIR measurement", body="CN stretch region")
```
"""
function create_experiment(;
    title::String,
    body::String = "",
    category::Union{Int, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments"
    payload = Dict{String, Any}("title" => title)
    if !isempty(body)
        payload["body"] = body
        payload["content_type"] = 2  # Markdown rendering
    end
    if !isnothing(category)
        payload["category"] = category
    end
    if !isnothing(metadata)
        payload["metadata"] = metadata
    end

    response = _elabftw_post(url, payload)

    # Parse experiment ID from Location header
    location = HTTP.header(response, "Location", "")
    if isempty(location)
        error("eLabFTW create_experiment: no Location header in response")
    end
    # Location is like "/api/v2/experiments/123" or just the ID
    id_str = last(split(location, "/"))
    return parse(Int, id_str)
end

"""
    create_from_template(template_id; title, body, tags) -> Int

Create a new experiment from an eLabFTW experiment template. Returns the experiment ID.

Optionally override the title and body from the template, and add tags.

# Arguments
- `template_id::Int` — Template ID in eLabFTW
- `title::String` — Override template title (optional)
- `body::String` — Override template body (optional)
- `tags::Vector{String}` — Tags to add to the new experiment

# Example
```julia
id = create_from_template(42; title="FTIR: NH4SCN run 3", tags=["ftir", "nh4scn"])
```
"""
function create_from_template(template_id::Int;
    title::Union{String, Nothing} = nothing,
    body::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[]
)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments"
    payload = Dict{String, Any}("template" => template_id)
    response = _elabftw_post(url, payload)

    # Parse experiment ID from Location header
    location = HTTP.header(response, "Location", "")
    if isempty(location)
        error("eLabFTW create_from_template: no Location header in response")
    end
    id_str = last(split(location, "/"))
    id = parse(Int, id_str)

    # Override title/body if provided
    if !isnothing(title) || !isnothing(body)
        update_experiment(id; title=title, body=body)
    end

    # Add tags
    for tag in tags
        tag_experiment(id, tag)
    end

    return id
end

"""
    update_experiment(id::Int; title, body, metadata)

Update an existing experiment in eLabFTW.

# Arguments
- `id::Int` — Experiment ID
- `title::String` — New title (optional)
- `body::String` — New body content (optional)
- `metadata::Union{Dict, Nothing}` — Extra metadata JSON (optional)

# Example
```julia
update_experiment(42; body="Updated analysis results")
```
"""
function update_experiment(id::Int;
    title::Union{String, Nothing} = nothing,
    body::Union{String, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id"
    payload = Dict{String, Any}()
    if !isnothing(title)
        payload["title"] = title
    end
    if !isnothing(body)
        payload["body"] = body
        payload["content_type"] = 2  # Markdown rendering
    end
    if !isnothing(metadata)
        payload["metadata"] = metadata
    end

    if isempty(payload)
        @warn "update_experiment called with no fields to update"
        return
    end

    _elabftw_patch(url, payload)
    return nothing
end

"""
    upload_to_experiment(id::Int, filepath::String; comment) -> Int

Upload a file attachment to an experiment. Returns the upload ID.

# Arguments
- `id::Int` — Experiment ID
- `filepath::String` — Path to file to upload
- `comment::String` — Optional comment for the attachment

# Example
```julia
upload_id = upload_to_experiment(42, "figures/fit.pdf"; comment="Peak fit figure")
```
"""
function upload_to_experiment(id::Int, filepath::String; comment::String="")
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id/uploads"
    response = _elabftw_upload(url, filepath; comment=comment)

    # Parse upload ID from Location header
    location = HTTP.header(response, "Location", "")
    if isempty(location)
        # Fallback: try to get from response body
        body = JSON.parse(String(response.body))
        return get(body, "id", -1)
    end
    id_str = last(split(location, "/"))
    return parse(Int, id_str)
end

"""
    tag_experiment(id::Int, tag::String)

Add a tag to an experiment.

# Example
```julia
tag_experiment(42, "ftir")
tag_experiment(42, "nh4scn")
```
"""
function tag_experiment(id::Int, tag::String)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id/tags"
    _elabftw_post(url, Dict("tag" => tag))
    return nothing
end

"""
    tag_experiment(id::Int, tags::Vector{String})

Add multiple tags to an experiment.

# Example
```julia
tag_experiment(42, ["ftir", "nh4scn", "peak_fit"])
```
"""
function tag_experiment(id::Int, tags::Vector{String})
    for tag in tags
        tag_experiment(id, tag)
    end
    return nothing
end

"""
    list_tags(id::Int) -> Vector{Dict}

List all tags on an experiment. Returns an array of tag objects with
`"tag_id"` and `"tag"` keys.

# Example
```julia
tags = list_tags(42)
for t in tags
    println(t["tag_id"], ": ", t["tag"])
end
```
"""
function list_tags(id::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id/tags"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    untag_experiment(id::Int, tag_id::Int)

Remove a single tag from an experiment (does not delete the team-level tag).

Use `list_tags(id)` to find the tag ID (the `"tag_id"` field).

# Example
```julia
tags = list_tags(42)
untag_experiment(42, tags[1]["tag_id"])
```
"""
function untag_experiment(id::Int, tag_id::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id/tags/$tag_id"
    _elabftw_patch(url, Dict("action" => "unreference"))
    return nothing
end

"""
    clear_tags(id::Int)

Remove all tags from an experiment.

# Example
```julia
clear_tags(42)
```
"""
function clear_tags(id::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id/tags"
    _elabftw_delete(url)
    return nothing
end

# =============================================================================
# Team-level Tag Management
# =============================================================================

"""
    list_team_tags() -> Vector{Dict}

List all tags in the team registry.

# Example
```julia
tags = list_team_tags()
for t in tags
    println(t["id"], ": ", t["tag"])
end
```
"""
function list_team_tags()
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/teams/current/tags"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    rename_team_tag(tag_id::Int, new_name::String)

Rename a tag in the team registry. Admin-only operation.

# Example
```julia
rename_team_tag(7, "ftir-analysis")
```
"""
function rename_team_tag(tag_id::Int, new_name::String)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/teams/current/tags/$tag_id"
    _elabftw_patch(url, Dict("action" => "updatetag", "tag" => new_name))
    return nothing
end

"""
    delete_team_tag(tag_id::Int)

Delete a tag from the team registry. Removes the tag from all entity references.
Admin-only operation.

# Example
```julia
delete_team_tag(7)
```
"""
function delete_team_tag(tag_id::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/teams/current/tags/$tag_id"
    _elabftw_delete(url)
    return nothing
end

"""
    print_tags(tags::Vector; io::IO=stdout)

Pretty-print tag lists from `list_tags` (entity tags) or `list_team_tags` (team tags).

# Examples
```julia
print_tags(list_tags(experiment_id))
print_tags(list_team_tags())
```
"""
function print_tags(tags::Vector; io::IO=stdout)
    if isempty(tags)
        println(io, "No tags found.")
        return
    end

    # Detect entity vs team tags by key presence
    is_team = haskey(first(tags), "item_count")

    if is_team
        println(io, rpad("ID", 8), rpad("Tag", 32), "Experiments")
        println(io, repeat("-", 52))
        for t in tags
            id = string(get(t, "id", ""))
            tag = string(get(t, "tag", ""))
            count = string(get(t, "item_count", ""))
            println(io, rpad(id, 8), rpad(tag, 32), count)
        end
    else
        println(io, rpad("ID", 8), "Tag")
        println(io, repeat("-", 32))
        for t in tags
            id = string(get(t, "tag_id", ""))
            tag = string(get(t, "tag", ""))
            println(io, rpad(id, 8), tag)
        end
    end
end

"""
    get_experiment(id::Int) -> Dict

Retrieve an experiment by ID.

# Example
```julia
exp = get_experiment(42)
exp["title"]
exp["body"]
```
"""
function get_experiment(id::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    delete_experiment(id::Int)

Delete an experiment from eLabFTW.

# Example
```julia
delete_experiment(7377)
```
"""
function delete_experiment(id::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id"
    _elabftw_delete(url)
    println("Deleted experiment $id")
    return nothing
end

"""
    list_experiments(; limit, offset, order, sort) -> Vector{Dict}

List experiments from eLabFTW with pagination and sorting.

# Arguments
- `limit::Int` — Maximum number of results (default: 20)
- `offset::Int` — Skip first N results (default: 0)
- `order::Symbol` — Sort field: `:date`, `:title`, `:id` (default: `:date`)
- `sort::Symbol` — Sort direction: `:desc`, `:asc` (default: `:desc`)

# Example
```julia
# Most recent 10 experiments
exps = list_experiments(limit=10)

# Paginate through results
page1 = list_experiments(limit=20, offset=0)
page2 = list_experiments(limit=20, offset=20)
```
"""
function list_experiments(;
    limit::Int = 20,
    offset::Int = 0,
    order::Symbol = :date,
    sort::Symbol = :desc
)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    params = [
        "limit=$limit",
        "offset=$offset",
        "order=$(order)",
        "sort=$(sort)"
    ]

    url = "$(_elabftw_config.url)/api/v2/experiments?" * join(params, "&")
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    search_experiments(; query, tags, limit, offset, order, sort) -> Vector{Dict}

Search experiments in eLabFTW by text query and/or tags.

# Arguments
- `query::String` — Full-text search term (searches title and body)
- `tags::Vector{String}` — Filter by tags (experiments must have ALL specified tags)
- `limit::Int` — Maximum number of results (default: 20)
- `offset::Int` — Skip first N results (default: 0)
- `order::Symbol` — Sort field: `:date`, `:title`, `:id` (default: `:date`)
- `sort::Symbol` — Sort direction: `:desc`, `:asc` (default: `:desc`)

# Examples
```julia
# Search by text
results = search_experiments(query="CN stretch")

# Filter by tags
results = search_experiments(tags=["ftir", "nh4scn"])

# Combine query and tags
results = search_experiments(query="peak fit", tags=["ftir"])
```
"""
function search_experiments(;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[],
    limit::Int = 20,
    offset::Int = 0,
    order::Symbol = :date,
    sort::Symbol = :desc
)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    params = [
        "limit=$limit",
        "offset=$offset",
        "order=$(order)",
        "sort=$(sort)"
    ]

    # Add search query
    if !isnothing(query) && !isempty(query)
        push!(params, "q=$(HTTP.escapeuri(query))")
    end

    # Add tag filters
    for tag in tags
        push!(params, "tags[]=$(HTTP.escapeuri(tag))")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments?" * join(params, "&")
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    print_experiments(experiments; io=stdout)

Print a formatted table of experiments. Pure formatting function — no API calls.

# Arguments
- `experiments::Vector` — Vector of experiment dicts (from `list_experiments` or `search_experiments`)
- `io::IO` — Output stream (default: stdout)

# Example
```julia
exps = search_experiments(tags=["ftir"])
print_experiments(exps)
```
"""
function print_experiments(experiments::Vector; io::IO=stdout)
    if isempty(experiments)
        println(io, "No experiments found.")
        return
    end

    # Header
    println(io, rpad("ID", 8), rpad("Date", 12), rpad("Title", 52), "Tags")
    println(io, repeat("-", 80))

    for exp in experiments
        id = string(get(exp, "id", ""))
        raw_date = string(get(exp, "date", ""))
        date = length(raw_date) >= 10 ? raw_date[1:10] : raw_date
        raw_title = string(get(exp, "title", ""))
        t = length(raw_title) > 50 ? raw_title[1:47] * "..." : raw_title
        tags_list = get(exp, "tags", [])
        tag_strs = [string(get(tag, "tag", tag)) for tag in tags_list]
        tags_str = join(tag_strs, ", ")
        println(io, rpad(id, 8), rpad(date, 12), rpad(t, 52), tags_str)
    end
end

# =============================================================================
# Batch Operations
# =============================================================================

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

    # Find matching experiments (get all, not just first 20)
    all_matches = Dict[]
    offset = 0
    while true
        batch = search_experiments(; query=query, tags=tags, limit=100, offset=offset)
        isempty(batch) && break
        append!(all_matches, batch)
        offset += 100
        length(batch) < 100 && break
    end

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

    # Find matching experiments
    all_matches = Dict[]
    offset = 0
    while true
        batch = search_experiments(; query=query, tags=tags, limit=100, offset=offset)
        isempty(batch) && break
        append!(all_matches, batch)
        offset += 100
        length(batch) < 100 && break
    end

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

    # Find matching experiments
    all_matches = Dict[]
    offset = 0
    while true
        batch = search_experiments(; query=query, tags=tags, limit=100, offset=offset)
        isempty(batch) && break
        append!(all_matches, batch)
        offset += 100
        length(batch) < 100 && break
    end

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
            # Need to fetch current body first
            full_exp = get_experiment(exp["id"])
            current_body = get(full_exp, "body", "")
            update_experiment(exp["id"]; body=current_body * append_body)
        end
    end

    println("Done")
    return ids
end

# =============================================================================
# Steps & Links
# =============================================================================

"""
    add_step(id, body) -> Int

Add an analysis step to an experiment. Returns the step ID.

Steps track the procedure used in an analysis (e.g., "Load raw data",
"Fit single exponential with IRF"). Use `finish_step` to mark completed.

# Example
```julia
id = create_experiment(title="TA kinetics analysis")
s1 = add_step(id, "Load and inspect raw data")
s2 = add_step(id, "Fit single exponential with IRF")
finish_step(id, s1)
```
"""
function add_step(id::Int, body::String)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id/steps"
    response = _elabftw_post(url, Dict("body" => body))

    # Parse step ID from Location header
    location = HTTP.header(response, "Location", "")
    if !isempty(location)
        id_str = last(split(location, "/"))
        return parse(Int, id_str)
    end

    # Fallback: try response body
    resp_body = JSON.parse(String(response.body))
    return get(resp_body, "id", -1)
end

"""
    list_steps(id) -> Vector{Dict}

List all steps for an experiment.

# Example
```julia
steps = list_steps(42)
for step in steps
    status = get(step, "finished", false) ? "done" : "todo"
    println("[", status, "] ", step["body"])
end
```
"""
function list_steps(id::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id/steps"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    finish_step(id, step_id)

Mark a step as finished.

# Example
```julia
finish_step(42, 1)
```
"""
function finish_step(id::Int, step_id::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id/steps/$step_id"
    _elabftw_patch(url, Dict("finished" => true))
    return nothing
end

"""
    link_experiments(id1, id2)

Create a link between two experiments. The link appears on experiment `id1`
pointing to experiment `id2`.

# Example
```julia
link_experiments(42, 37)  # Link experiment 42 → 37
```
"""
function link_experiments(id1::Int, id2::Int)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$id1/experiments_links/$id2"
    _elabftw_post(url, Dict{String, Any}())
    println("Linked experiment $id1 → $id2")
    return nothing
end

# =============================================================================
# .elab_id helpers (idempotent logging)
# =============================================================================

"""Return path for .elab_id file next to the running script, or nothing."""
function _elab_id_path()
    prog = Base.PROGRAM_FILE
    (isempty(prog) || !isfile(prog)) && return nothing
    return joinpath(dirname(abspath(prog)), ".elab_id")
end

"""Read existing .elab_id file. Returns (id=Int, title=String) or nothing."""
function _read_elab_id()
    path = _elab_id_path()
    (isnothing(path) || !isfile(path)) && return nothing
    try
        data = JSON.parsefile(path)
        return (id=data["id"]::Int, title=get(data, "title", "")::String)
    catch
        return nothing
    end
end

"""Write .elab_id file next to the running script."""
function _write_elab_id(id::Int, title::String)
    path = _elab_id_path()
    isnothing(path) && return
    open(path, "w") do io
        JSON.print(io, Dict("id" => id, "title" => title), 2)
    end
end

# =============================================================================
# Attachment replacement (idempotent uploads)
# =============================================================================

"""Delete a single upload from an experiment."""
function _delete_upload(experiment_id::Int, upload_id::Int)
    url = "$(_elabftw_config.url)/api/v2/experiments/$experiment_id/uploads/$upload_id"
    _elabftw_delete(url)
end

"""Replace attachments by filename — delete existing with same name, then upload."""
function _replace_attachments(experiment_id::Int, filepaths::Vector{String})
    isempty(filepaths) && return
    exp = get_experiment(experiment_id)
    existing = get(exp, "uploads", [])
    for filepath in filepaths
        fname = basename(filepath)
        for upload in existing
            if get(upload, "real_name", "") == fname
                _delete_upload(experiment_id, upload["id"])
                break
            end
        end
        upload_to_experiment(experiment_id, filepath; comment=fname)
    end
end

# =============================================================================
# Auto-provenance helpers
# =============================================================================

"""Build a provenance body section from JASCO header fields."""
function _jasco_provenance_body(spec::AnnotatedSpectrum)
    lines = ["## Source", "- **File**: $(basename(spec.path))"]
    !isempty(spec.data.spectrometer) && push!(lines, "- **Instrument**: $(spec.data.spectrometer)")
    push!(lines, "- **Acquired**: $(spec.data.date)")
    prog = Base.PROGRAM_FILE
    (!isempty(prog) && isfile(prog)) && push!(lines, "- **Script**: $(basename(prog))")
    return join(lines, "\n")
end

"""Auto-generate tags from JASCO header + sample kwargs."""
function _jasco_auto_tags(spec::AnnotatedSpectrum)
    tags = [_jasco_technique_tag(spec)]
    append!(tags, tags_from_sample(spec))
    return unique(filter(!isempty, tags))
end

# =============================================================================
# Idempotent log_to_elab
# =============================================================================

"""
    log_to_elab(; title, body, attachments, tags, category, metadata) -> Int

Log analysis results to eLabFTW. Idempotent: if a `.elab_id` file exists next
to the running script with a matching title, updates the existing experiment
instead of creating a new one.

Returns the experiment ID.

# Examples
```julia
# First run: creates experiment, writes .elab_id
log_to_elab(title="FTIR: CN stretch fit", body=format_results(result))

# Re-run: updates existing experiment
log_to_elab(title="FTIR: CN stretch fit", body=format_results(result))
```
"""
function log_to_elab(;
    title::String,
    body::String = "",
    attachments::Vector{String} = String[],
    tags::Vector{String} = String[],
    category::Union{Int, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    existing = _read_elab_id()

    if !isnothing(existing) && existing.title == title
        # Update existing experiment
        id = existing.id
        update_experiment(id; title=title, body=body)
        _replace_attachments(id, attachments)
        if !isempty(tags)
            tag_experiment(id, tags)
        end
        exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
        println("eLabFTW: updated experiment #$id")
        println("  $exp_url")
    else
        # Create new experiment
        id = create_experiment(; title=title, body=body, category=category, metadata=metadata)
        for filepath in attachments
            upload_to_experiment(id, filepath; comment=basename(filepath))
        end
        if !isempty(tags)
            tag_experiment(id, tags)
        end
        _write_elab_id(id, title)
        exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
        println("eLabFTW: created experiment #$id")
        println("  $exp_url")
    end

    return id
end

"""
    tags_from_sample(sample::Dict; include=nothing, exclude=["_id", "path", "date"]) -> Vector{String}

Extract tags from sample metadata dictionary.

By default, extracts values from common fields (solute, solvent, material, etc.)
and excludes internal fields (_id, path, date).

# Arguments
- `sample::Dict` — Sample metadata (e.g., from `spec.sample`)
- `include::Vector{Symbol}` — Only include these fields (default: all except excluded)
- `exclude::Vector{String}` — Fields to skip (default: ["_id", "path", "date"])

# Example
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
tags = tags_from_sample(spec.sample)
# => ["NH4SCN", "DMF", "1.0M", "CaF2"]
```
"""
function tags_from_sample(sample::Dict;
    include::Union{Nothing, Vector{Symbol}} = nothing,
    exclude::Vector{String} = ["_id", "path", "date", "pathlength"]
)
    tags = String[]

    for (k, v) in sample
        # Skip excluded fields
        k in exclude && continue

        # Skip if include list specified and field not in it
        if !isnothing(include) && Symbol(k) ∉ include
            continue
        end

        # Skip non-string values
        v isa String || continue

        # Skip empty values
        isempty(v) && continue

        push!(tags, v)
    end

    return unique(tags)
end

"""
    tags_from_sample(spec::AnnotatedSpectrum; kwargs...) -> Vector{String}

Extract tags from an AnnotatedSpectrum's sample metadata.

# Example
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
tags = tags_from_sample(spec)
# => ["NH4SCN", "DMF", "1.0M", "CaF2"]
```
"""
tags_from_sample(spec::AnnotatedSpectrum; kwargs...) = tags_from_sample(spec.sample; kwargs...)

"""
    log_to_elab(spec::AnnotatedSpectrum, result; title, body, attachments, extra_tags, category) -> Int

Log analysis results with auto-provenance from JASCO header and auto-tags from
sample kwargs. Inherits idempotency from the keyword-only form.

Tags are auto-generated from: JASCO technique type + kwargs passed to load_ftir/load_raman.
Body includes: provenance (file, instrument, date, script) + user body + formatted results.

# Example
```julia
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv"; solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))

log_to_elab(spec, result;
    title = "FTIR: CN stretch fit",
    attachments = ["figures/fit.pdf"],
    extra_tags = ["peak_fit"]
)
```
"""
function log_to_elab(spec::AnnotatedSpectrum, result;
    title::String,
    body::String = "",
    attachments::Vector{String} = String[],
    extra_tags::Vector{String} = String[],
    category::Union{Int, Nothing} = nothing
)
    # Auto-tags from JASCO header + sample kwargs
    auto_tags = _jasco_auto_tags(spec)
    all_tags = unique(vcat(auto_tags, extra_tags))

    # Build body: provenance + user body + formatted results
    full_body = _jasco_provenance_body(spec)
    if !isempty(body)
        full_body *= "\n\n" * body
    end
    full_body *= "\n\n" * format_results(result)

    return log_to_elab(;
        title = title,
        body = full_body,
        attachments = attachments,
        tags = all_tags,
        category = category
    )
end

# =============================================================================
# Internal Helpers
# =============================================================================

function _elabftw_request(url::String; accept::String="application/json")
    headers = [
        "Authorization" => _elabftw_config.api_key,
        "Accept" => accept
    ]

    try
        response = HTTP.get(url, headers)
        return response
    catch e
        if e isa HTTP.ExceptionRequest.StatusError
            status = e.status
            if status == 401
                error("eLabFTW authentication failed. Check your API key.")
            elseif status == 404
                error("eLabFTW resource not found: $url")
            else
                error("eLabFTW request failed with status $status")
            end
        end
        rethrow(e)
    end
end

function _elabftw_post(url::String, body_dict::Dict)
    headers = [
        "Authorization" => _elabftw_config.api_key,
        "Content-Type" => "application/json"
    ]
    try
        response = HTTP.post(url, headers, JSON.json(body_dict))
        return response
    catch e
        if e isa HTTP.ExceptionRequest.StatusError
            status = e.status
            if status == 401
                error("eLabFTW authentication failed. Check your API key.")
            elseif status == 403
                error("eLabFTW permission denied. Check API key permissions.")
            else
                error("eLabFTW POST failed with status $status")
            end
        end
        rethrow(e)
    end
end

function _elabftw_patch(url::String, body_dict::Dict)
    headers = [
        "Authorization" => _elabftw_config.api_key,
        "Content-Type" => "application/json"
    ]
    try
        response = HTTP.patch(url, headers, JSON.json(body_dict))
        return response
    catch e
        if e isa HTTP.ExceptionRequest.StatusError
            status = e.status
            if status == 401
                error("eLabFTW authentication failed. Check your API key.")
            elseif status == 403
                error("eLabFTW permission denied. Check API key permissions.")
            elseif status == 404
                error("eLabFTW experiment not found: $url")
            else
                error("eLabFTW PATCH failed with status $status")
            end
        end
        rethrow(e)
    end
end

function _elabftw_delete(url::String)
    headers = [
        "Authorization" => _elabftw_config.api_key
    ]
    try
        response = HTTP.delete(url, headers)
        return response
    catch e
        if e isa HTTP.ExceptionRequest.StatusError
            status = e.status
            if status == 401
                error("eLabFTW authentication failed. Check your API key.")
            elseif status == 403
                error("eLabFTW permission denied. Check API key permissions.")
            elseif status == 404
                error("eLabFTW experiment not found: $url")
            else
                error("eLabFTW DELETE failed with status $status")
            end
        end
        rethrow(e)
    end
end

function _elabftw_upload(url::String, filepath::String; comment::String="")
    if !isfile(filepath)
        error("File not found: $filepath")
    end
    headers = [
        "Authorization" => _elabftw_config.api_key,
    ]
    io = open(filepath)
    try
        form = HTTP.Form(Dict(
            "file" => io,
            "comment" => comment
        ))
        response = HTTP.post(url, headers, form)
        return response
    catch e
        if e isa HTTP.ExceptionRequest.StatusError
            status = e.status
            if status == 401
                error("eLabFTW authentication failed. Check your API key.")
            elseif status == 404
                error("eLabFTW experiment not found: $url")
            else
                error("eLabFTW upload failed with status $status")
            end
        end
        rethrow(e)
    finally
        close(io)
    end
end

function _get_cache_path(item_id::Int, upload_id::Int, filename::String)
    cache_dir = _elabftw_config.cache_dir
    if isempty(filename)
        filename = "upload_$upload_id.csv"
    end
    return joinpath(cache_dir, string(item_id), filename)
end

