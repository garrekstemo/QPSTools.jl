# Comments on experiments and items

# =============================================================================
# Generic comment helpers
# =============================================================================

"""
    create_comment(entity_type::Symbol, id::Int, body::String) -> Int

Add a comment to an experiment or item. Returns the comment ID.

`entity_type` is `:experiments` or `:items`.

# Example
```julia
comment_id = create_comment(:experiments, 42, "Looks good, approved for publication.")
```
"""
function create_comment(entity_type::Symbol, id::Int, body::String)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$id/comments"
    response = _elabftw_post(url, Dict("comment" => body))
    return _parse_id_from_response(response)
end

"""
    list_comments(entity_type::Symbol, id::Int) -> Vector{Dict}

List all comments on an experiment or item.

# Example
```julia
comments = list_comments(:experiments, 42)
```
"""
function list_comments(entity_type::Symbol, id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$id/comments"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    get_comment(entity_type::Symbol, id::Int, comment_id::Int) -> Dict

Get a single comment by ID.
"""
function get_comment(entity_type::Symbol, id::Int, comment_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$id/comments/$comment_id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    update_comment(entity_type::Symbol, id::Int, comment_id::Int, body::String)

Update an existing comment.
"""
function update_comment(entity_type::Symbol, id::Int, comment_id::Int, body::String)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$id/comments/$comment_id"
    _elabftw_patch(url, Dict("comment" => body))
    return nothing
end

"""
    delete_comment(entity_type::Symbol, id::Int, comment_id::Int)

Delete a comment.
"""
function delete_comment(entity_type::Symbol, id::Int, comment_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$id/comments/$comment_id"
    _elabftw_delete(url)
    return nothing
end

# =============================================================================
# Convenience wrappers
# =============================================================================

"""
    comment_experiment(id::Int, body::String) -> Int

Add a comment to an experiment. Returns the comment ID.

# Example
```julia
comment_experiment(42, "Re-analyzed with updated calibration.")
```
"""
comment_experiment(id::Int, body::String) = create_comment(:experiments, id, body)

"""
    list_experiment_comments(id::Int) -> Vector{Dict}

List all comments on an experiment.
"""
list_experiment_comments(id::Int) = list_comments(:experiments, id)

"""
    comment_item(id::Int, body::String) -> Int

Add a comment to an item. Returns the comment ID.

# Example
```julia
comment_item(7, "Sample degraded, prepare new batch.")
```
"""
comment_item(id::Int, body::String) = create_comment(:items, id, body)

"""
    list_item_comments(id::Int) -> Vector{Dict}

List all comments on an item.
"""
list_item_comments(id::Int) = list_comments(:items, id)
