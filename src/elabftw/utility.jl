# Utility endpoints: instance info, favorites, import/export

"""
    instance_info() -> Dict

Get information about the eLabFTW instance (version, etc.).

# Example
```julia
info = instance_info()
println("eLabFTW version: ", info["elabftw_version"])
```
"""
function instance_info()
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/info"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    list_favorite_tags() -> Vector{Dict}

List the current user's favorite tags.
"""
function list_favorite_tags()
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/users/me/favorite_tags"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    add_favorite_tag(tag_id::Int)

Add a tag to the current user's favorites.
"""
function add_favorite_tag(tag_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/users/me/favorite_tags/$tag_id"
    _elabftw_post(url, Dict{String, Any}())
    return nothing
end

"""
    remove_favorite_tag(tag_id::Int)

Remove a tag from the current user's favorites.
"""
function remove_favorite_tag(tag_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/users/me/favorite_tags/$tag_id"
    _elabftw_delete(url)
    return nothing
end

"""
    import_file(filepath::String; entity_type=:experiments, category=nothing) -> Int

Import a file (.eln, .csv, etc.) into eLabFTW. Returns the created entity ID.

# Arguments
- `filepath::String` — Path to file to import
- `entity_type::Symbol` — Target type: `:experiments` or `:items` (default: `:experiments`)
- `category::Union{Int, Nothing}` — Category ID for the imported entity
"""
function import_file(filepath::String;
    entity_type::Symbol=:experiments,
    category::Union{Int, Nothing}=nothing
)
    _check_enabled()
    if !isfile(filepath)
        error("File not found: $filepath")
    end
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/import"
    headers = [
        "Authorization" => _elabftw_config.api_key,
    ]
    io = open(filepath)
    try
        form_data = Dict{String, Any}(
            "file" => io,
            "entity_type" => etype
        )
        if !isnothing(category)
            form_data["category"] = string(category)
        end
        form = HTTP.Form(form_data)
        response = HTTP.post(url, headers, form)
        return _parse_id_from_response(response)
    finally
        close(io)
    end
end

"""
    create_export(entity_type::Symbol, id::Int; format="eln") -> String

Create an export of an entity. Returns the export ID/path.

# Arguments
- `entity_type::Symbol` — `:experiments` or `:items`
- `id::Int` — Entity ID
- `format::String` — Export format: "eln", "pdf", "zip" (default: "eln")
"""
function create_export(entity_type::Symbol, id::Int; format::String="eln")
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$id/exports/$format"
    response = _elabftw_request(url; accept="application/octet-stream")
    # Return the raw binary content — caller should write to file
    return response.body
end

"""
    download_export(entity_type::Symbol, id::Int, filepath::String; format="eln")

Export an entity and save to a local file.

# Arguments
- `entity_type::Symbol` — `:experiments` or `:items`
- `id::Int` — Entity ID
- `filepath::String` — Local path to save the export
- `format::String` — Export format: "eln", "pdf", "zip" (default: "eln")

# Example
```julia
download_export(:experiments, 42, "experiment_42.eln")
```
"""
function download_export(entity_type::Symbol, id::Int, filepath::String; format::String="eln")
    data = create_export(entity_type, id; format=format)
    write(filepath, data)
    @info "Exported" entity_type id filepath
    return filepath
end
