"""
eLabFTW integration for QPSTools.jl registry system.

Provides read-only access to eLabFTW as a sample registry with local file caching.
The local JSON registry remains the fallback for offline use.

# Configuration

Set up eLabFTW connection (typically in startup.jl or environment):

```julia
using QPSTools
configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
```

# Usage

Once configured, the same loading API works:

```julia
spec = load_raman(material="MoS2")           # Queries eLabFTW
specs = search_raman(material="ZIF-62")      # Multiple results
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
    cache_dir::String = joinpath(get_data_dir(), ".cache", "elabftw"),
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

Disable eLabFTW queries (use local registry only).
"""
function disable_elabftw()
    _elabftw_config.enabled = false
    @info "eLabFTW disabled, using local registry"
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

# =============================================================================
# API Queries
# =============================================================================

"""
    query_elabftw(category::Symbol; kwargs...) -> Vector{Dict}

Query eLabFTW for items matching metadata filters.

Returns a vector of item metadata dicts, each containing:
- `_id`: eLabFTW item ID
- `title`: Item title
- `uploads`: List of file attachments
- All custom metadata fields

# Example
```julia
items = query_elabftw(:raman, material="MoS2")
```
"""
function query_elabftw(category::Symbol; kwargs...)
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end

    # Build query URL
    base_url = "$(_elabftw_config.url)/api/v2/items"
    params = String[]

    # Add category filter if we have a mapping
    if haskey(_elabftw_config.category_ids, category)
        cat_id = _elabftw_config.category_ids[category]
        push!(params, "cat=$cat_id")
    end

    # Add metadata filters
    for (key, value) in kwargs
        value === nothing && continue
        # eLabFTW uses metakey[]/metavalue[] for extra_fields queries
        key_str = _normalize_field_name(key)
        push!(params, "metakey[]=$key_str")
        push!(params, "metavalue[]=$value")
    end

    query_string = isempty(params) ? "" : "?" * join(params, "&")
    url = base_url * query_string

    # Make request
    response = _elabftw_request(url)
    items = JSON.parse(String(response.body))

    # Transform to our format
    results = Dict{String, Any}[]
    for item in items
        entry = _parse_elabftw_item(item)
        push!(results, entry)
    end

    return results
end

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
    end
    if !isnothing(category)
        payload["category_id"] = category
    end
    if !isnothing(metadata)
        payload["metadata"] = JSON.json(metadata)
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
    end
    if !isnothing(metadata)
        payload["metadata"] = JSON.json(metadata)
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

"""
    log_to_elab(; title, body, attachments, tags, category, metadata) -> Int

Log analysis results to eLabFTW as a new experiment entry.

Creates an experiment, uploads file attachments, and adds tags. Prints a
confirmation with the experiment URL. Returns the experiment ID.

# Arguments
- `title::String` — Experiment title (required)
- `body::String` — Experiment body text (supports markdown/HTML)
- `attachments::Vector{String}` — File paths to attach
- `tags::Vector{String}` — Tags to add
- `category::Union{Int, Nothing}` — Experiment category ID
- `metadata::Union{Dict, Nothing}` — Extra metadata JSON

# Examples
```julia
# Simple log
log_to_elab(title="FTIR: NH4SCN in DMF", body="Measured CN stretch region")

# With fit results and figure
result = fit_peaks(spec, (2000, 2100))
log_to_elab(
    title = "CN stretch peak fit",
    body = format_results(result),
    attachments = ["figures/fit.pdf"],
    tags = ["ftir", "nh4scn"]
)
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
    # Create the experiment
    id = create_experiment(; title=title, body=body, category=category, metadata=metadata)

    # Upload attachments
    for filepath in attachments
        upload_to_experiment(id, filepath; comment=basename(filepath))
    end

    # Add tags
    for tag in tags
        tag_experiment(id, tag)
    end

    # Print confirmation
    exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
    println("Logged to eLabFTW: $exp_url")
    if !isempty(attachments)
        println("  Attachments: $(length(attachments))")
    end
    if !isempty(tags)
        println("  Tags: $(join(tags, ", "))")
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

Log analysis results with auto-populated tags from sample metadata.

Convenience method that extracts tags from the spectrum's sample metadata
and merges them with any additional tags you specify.

# Arguments
- `spec::AnnotatedSpectrum` — Spectrum with sample metadata
- `result` — Fit result (any type supporting `format_results`)
- `title::String` — Experiment title (required)
- `body::String` — Additional body text (prepended to formatted results)
- `attachments::Vector{String}` — File paths to attach
- `extra_tags::Vector{String}` — Additional tags beyond auto-extracted ones
- `category::Union{Int, Nothing}` — Experiment category ID

# Example
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))
fig = plot_peaks(result)
save("figures/fit.pdf", fig)

# Tags auto-populated: NH4SCN, DMF, 1.0M, CaF2
log_to_elab(spec, result;
    title = "FTIR: CN stretch fit",
    attachments = ["figures/fit.pdf"],
    extra_tags = ["peak_fit"]  # Added to auto-tags
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
    # Auto-extract tags from sample metadata
    auto_tags = tags_from_sample(spec)
    all_tags = unique(vcat(auto_tags, extra_tags))

    # Build body with sample info and results
    sample_id = get(spec.sample, "_id", "")
    full_body = ""
    if !isempty(sample_id)
        full_body *= "**Sample:** $sample_id\n\n"
    end
    if !isempty(body)
        full_body *= body * "\n\n"
    end
    full_body *= format_results(result)

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
    form = HTTP.Form(Dict(
        "file" => open(filepath),
        "comment" => comment
    ))
    try
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
    end
end

function _parse_elabftw_item(item::Dict)
    result = Dict{String, Any}()

    # Core fields
    result["_id"] = string(item["id"])
    result["_elabftw_id"] = item["id"]
    result["title"] = get(item, "title", "")

    # Parse extra_fields (custom metadata)
    if haskey(item, "metadata") && !isnothing(item["metadata"])
        metadata = item["metadata"]
        if haskey(metadata, "extra_fields")
            for (field_name, field_data) in metadata["extra_fields"]
                # Normalize field name to lowercase for consistency
                key = lowercase(replace(field_name, " " => "_"))
                result[key] = get(field_data, "value", nothing)
            end
        end
    end

    # File attachments
    if haskey(item, "uploads") && !isempty(item["uploads"])
        uploads = item["uploads"]
        # Store first CSV/data file path info
        for upload in uploads
            filename = get(upload, "real_name", "")
            if endswith(lowercase(filename), ".csv")
                result["_upload_id"] = upload["id"]
                result["_filename"] = filename
                break
            end
        end
    end

    return result
end

function _get_cache_path(item_id::Int, upload_id::Int, filename::String)
    # Use item_id/upload_id structure for uniqueness
    cache_dir = _elabftw_config.cache_dir
    if isempty(filename)
        filename = "upload_$upload_id.csv"
    end
    return joinpath(cache_dir, string(item_id), filename)
end

function _normalize_field_name(key::Symbol)
    # Convert Julia symbol to eLabFTW field name
    # :material -> "Material", :laser_nm -> "Laser nm"
    s = string(key)
    s = replace(s, "_" => " ")
    return titlecase(s)
end

# =============================================================================
# Registry Integration
# =============================================================================

"""
    load_from_elabftw(category::Symbol, ::Type{T}; kwargs...) where T

Load a spectrum from eLabFTW. Used internally by load_raman, load_ftir, etc.

Returns a spectrum with:
- Sample ID extracted from JASCO file TITLE header
- Date extracted from JASCO file
- All eLabFTW metadata merged into sample dict
"""
function load_from_elabftw(category::Symbol, ::Type{T}; kwargs...) where T
    items = query_elabftw(category; kwargs...)

    if isempty(items)
        _elabftw_no_match_error(category, kwargs)
    elseif length(items) > 1
        _elabftw_multiple_match_error(category, items, kwargs)
    end

    return _load_elabftw_item(items[1], T)
end

"""
    search_from_elabftw(category::Symbol, ::Type{T}; kwargs...) where T

Search eLabFTW for spectra matching filters. Returns vector.
"""
function search_from_elabftw(category::Symbol, ::Type{T}; kwargs...) where T
    items = query_elabftw(category; kwargs...)
    return [_load_elabftw_item(item, T) for item in items]
end

function _load_elabftw_item(item::Dict, ::Type{T}) where T
    # Download the file
    if !haskey(item, "_upload_id")
        error("eLabFTW item $(item["_id"]) has no CSV attachment")
    end

    item_id = item["_elabftw_id"]
    upload_id = item["_upload_id"]
    filename = get(item, "_filename", "")

    local_path = download_elabftw_file(item_id, upload_id; filename=filename)

    # Load the JASCO spectrum
    spectrum = JASCOSpectrum(local_path)

    # Build sample metadata
    # - Sample ID comes from JASCO TITLE header (user-entered on instrument)
    # - Date comes from JASCO file
    # - Everything else from eLabFTW
    sample = copy(item)
    sample["sample"] = spectrum.title  # Auto-extracted from file!

    # Remove internal fields from sample display
    for key in ["_upload_id", "_filename", "_elabftw_id"]
        delete!(sample, key)
    end

    return T(spectrum, sample, local_path)
end

function _elabftw_no_match_error(category, kwargs)
    println("\nNo eLabFTW entries match query in category :$category")
    for (k, v) in kwargs
        println("  $k = $v")
    end
    error("No matching data found in eLabFTW")
end

function _elabftw_multiple_match_error(category, items, kwargs)
    println("\nMultiple eLabFTW entries match query in category :$category")
    for (k, v) in kwargs
        println("  $k = $v")
    end
    println("\nMatches:")
    for item in items
        id = item["_id"]
        title = get(item, "title", "")
        println("  $id: $title")
    end
    error("Multiple matches found ($(length(items))). Add more filters.")
end
