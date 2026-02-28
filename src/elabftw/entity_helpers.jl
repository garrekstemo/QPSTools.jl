# Generic entity CRUD helpers for eLabFTW API v2
#
# These private helpers accept an `entity_type` string ("experiments" or "items")
# and implement the common REST patterns shared across entity types.

"""
    _create_entity(entity_type; title, body, category, metadata, template) -> Int

Create a new entity. Returns the entity ID.
"""
function _create_entity(entity_type::String;
    title::Union{String, Nothing} = nothing,
    body::Union{String, Nothing} = nothing,
    category::Union{Int, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing,
    template::Union{Int, Nothing} = nothing
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type"

    payload = Dict{String, Any}()
    if !isnothing(template)
        payload["template"] = template
    end
    if !isnothing(title)
        payload["title"] = title
    end
    if !isnothing(body) && !isempty(body)
        payload["body"] = body
        payload["content_type"] = 2  # Markdown
    end
    if !isnothing(category)
        payload["category"] = category
    end
    if !isnothing(metadata)
        payload["metadata"] = metadata
    end

    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    _get_entity(entity_type, id) -> Dict

Retrieve an entity by ID.
"""
function _get_entity(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    _update_entity(entity_type, id; title, body, metadata)

Update an existing entity.
"""
function _update_entity(entity_type::String, id::Int;
    title::Union{String, Nothing} = nothing,
    body::Union{String, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id"

    payload = Dict{String, Any}()
    if !isnothing(title)
        payload["title"] = title
    end
    if !isnothing(body)
        payload["body"] = body
        payload["content_type"] = 2  # Markdown
    end
    if !isnothing(metadata)
        payload["metadata"] = metadata
    end

    if isempty(payload)
        @warn "_update_entity called with no fields to update" entity_type id
        return
    end

    _elabftw_patch(url, payload)
    return nothing
end

"""
    _delete_entity(entity_type, id)

Delete an entity.
"""
function _delete_entity(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id"
    _elabftw_delete(url)
    return nothing
end

"""
    _list_entities(entity_type; limit, offset, order, sort, query, tags, cat, owner) -> Vector{Dict}

List entities with pagination, sorting, and optional filtering.
"""
function _list_entities(entity_type::String;
    limit::Int = 20,
    offset::Int = 0,
    order::Symbol = :date,
    sort::Symbol = :desc,
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[],
    cat::Union{Int, Nothing} = nothing,
    owner::Union{Int, Nothing} = nothing
)
    _check_enabled()

    params = [
        "limit=$limit",
        "offset=$offset",
        "order=$(order)",
        "sort=$(sort)"
    ]

    if !isnothing(query) && !isempty(query)
        push!(params, "q=$(HTTP.escapeuri(query))")
    end
    for tag in tags
        push!(params, "tags[]=$(HTTP.escapeuri(tag))")
    end
    if !isnothing(cat)
        push!(params, "cat=$cat")
    end
    if !isnothing(owner)
        push!(params, "owner=$owner")
    end

    url = "$(_elabftw_config.url)/api/v2/$entity_type?" * join(params, "&")
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    _duplicate_entity(entity_type, id) -> Int

Duplicate an entity. Returns the new entity ID.
"""
function _duplicate_entity(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id"
    response = _elabftw_post(url, Dict("action" => "duplicate"))
    return _parse_id_from_response(response)
end

"""
    _find_all_entities(entity_type; query, tags) -> Vector{Dict}

Paginate through all matching entities. Used by batch operations.
"""
function _find_all_entities(entity_type::String;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[]
)
    all_matches = Dict[]
    offset = 0
    while true
        batch = _list_entities(entity_type; query=query, tags=tags, limit=100, offset=offset)
        isempty(batch) && break
        append!(all_matches, batch)
        offset += 100
        length(batch) < 100 && break
    end
    return all_matches
end
