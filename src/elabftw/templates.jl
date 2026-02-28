# Experiment templates and items types

# =============================================================================
# Experiment templates
# =============================================================================

"""
    list_experiment_templates(; limit=20, offset=0) -> Vector{Dict}

List experiment templates.

# Example
```julia
templates = list_experiment_templates()
for t in templates
    println(t["id"], ": ", t["title"])
end
```
"""
function list_experiment_templates(; limit::Int=20, offset::Int=0)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/experiments_templates?limit=$limit&offset=$offset"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_experiment_template(; title, body) -> Int

Create a new experiment template. Returns the template ID.

# Example
```julia
id = create_experiment_template(title="FTIR analysis template", body="## Protocol\\n...")
```
"""
function create_experiment_template(; title::String, body::String="")
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/experiments_templates"
    payload = Dict{String, Any}("title" => title)
    if !isempty(body)
        payload["body"] = body
        payload["content_type"] = 2
    end
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    get_experiment_template(id::Int) -> Dict

Retrieve an experiment template by ID.
"""
function get_experiment_template(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/experiments_templates/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    update_experiment_template(id::Int; title, body)

Update an experiment template.
"""
function update_experiment_template(id::Int;
    title::Union{String, Nothing}=nothing,
    body::Union{String, Nothing}=nothing
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/experiments_templates/$id"
    payload = Dict{String, Any}()
    !isnothing(title) && (payload["title"] = title)
    if !isnothing(body)
        payload["body"] = body
        payload["content_type"] = 2
    end
    isempty(payload) && return nothing
    _elabftw_patch(url, payload)
    return nothing
end

"""
    delete_experiment_template(id::Int)

Delete an experiment template.
"""
function delete_experiment_template(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/experiments_templates/$id"
    _elabftw_delete(url)
    return nothing
end

"""
    duplicate_experiment_template(id::Int) -> Int

Duplicate an experiment template. Returns the new template ID.
"""
function duplicate_experiment_template(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/experiments_templates/$id"
    response = _elabftw_post(url, Dict("action" => "duplicate"))
    return _parse_id_from_response(response)
end

# =============================================================================
# Items types (resource templates)
# =============================================================================

"""
    list_items_types(; limit=20, offset=0) -> Vector{Dict}

List item types (resource category definitions).

# Example
```julia
types = list_items_types()
for t in types
    println(t["id"], ": ", t["title"])
end
```
"""
function list_items_types(; limit::Int=20, offset::Int=0)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/items_types?limit=$limit&offset=$offset"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_items_type(; title, body) -> Int

Create a new items type. Returns the type ID.

# Example
```julia
id = create_items_type(title="Sample", body="Template for lab samples")
```
"""
function create_items_type(; title::String, body::String="")
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/items_types"
    payload = Dict{String, Any}("title" => title)
    if !isempty(body)
        payload["body"] = body
        payload["content_type"] = 2
    end
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    get_items_type(id::Int) -> Dict

Retrieve an items type by ID.
"""
function get_items_type(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/items_types/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    update_items_type(id::Int; title, body)

Update an items type.
"""
function update_items_type(id::Int;
    title::Union{String, Nothing}=nothing,
    body::Union{String, Nothing}=nothing
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/items_types/$id"
    payload = Dict{String, Any}()
    !isnothing(title) && (payload["title"] = title)
    if !isnothing(body)
        payload["body"] = body
        payload["content_type"] = 2
    end
    isempty(payload) && return nothing
    _elabftw_patch(url, payload)
    return nothing
end

"""
    delete_items_type(id::Int)

Delete an items type.
"""
function delete_items_type(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/items_types/$id"
    _elabftw_delete(url)
    return nothing
end
