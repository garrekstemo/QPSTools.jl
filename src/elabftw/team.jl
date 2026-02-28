# Team-level tag and category management

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
    _check_enabled()
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
    _check_enabled()
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
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/teams/current/tags/$tag_id"
    _elabftw_delete(url)
    return nothing
end

"""
    list_experiments_categories() -> Vector{Dict}

List all experiment categories for the current team.

# Example
```julia
cats = list_experiments_categories()
for c in cats
    println(c["id"], ": ", c["title"])
end
```
"""
function list_experiments_categories()
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/teams/current/experiments_categories"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    list_items_categories() -> Vector{Dict}

List all item types (resource categories) for the current team.

# Example
```julia
types = list_items_categories()
for t in types
    println(t["id"], ": ", t["title"])
end
```
"""
function list_items_categories()
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/teams/current/items_types"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end
