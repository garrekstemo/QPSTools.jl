# Generic sub-resource helpers for eLabFTW API v2
#
# Tags, uploads, steps, and links follow the same REST patterns
# across experiments and items. These helpers accept entity_type.

# =============================================================================
# Tags
# =============================================================================

function _tag_entity(entity_type::String, id::Int, tag::String)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/tags"
    _elabftw_post(url, Dict("tag" => tag))
    return nothing
end

function _tag_entity(entity_type::String, id::Int, tags::Vector{String})
    for tag in tags
        _tag_entity(entity_type, id, tag)
    end
    return nothing
end

function _untag_entity(entity_type::String, id::Int, tag_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/tags/$tag_id"
    _elabftw_patch(url, Dict("action" => "unreference"))
    return nothing
end

function _list_entity_tags(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/tags"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _clear_entity_tags(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/tags"
    _elabftw_delete(url)
    return nothing
end

# =============================================================================
# Uploads
# =============================================================================

function _upload_to_entity(entity_type::String, id::Int, filepath::String; comment::String="")
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads"
    response = _elabftw_upload(url, filepath; comment=comment)
    return _parse_id_from_response(response)
end

function _list_entity_uploads(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _get_entity_upload(entity_type::String, id::Int, upload_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads/$upload_id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _delete_entity_upload(entity_type::String, id::Int, upload_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/uploads/$upload_id"
    _elabftw_delete(url)
    return nothing
end

# =============================================================================
# Steps
# =============================================================================

function _add_entity_step(entity_type::String, id::Int, body::String)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/steps"
    response = _elabftw_post(url, Dict("body" => body))
    return _parse_id_from_response(response)
end

function _list_entity_steps(entity_type::String, id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/steps"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _finish_entity_step(entity_type::String, id::Int, step_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/steps/$step_id"
    _elabftw_patch(url, Dict("finished" => true))
    return nothing
end

# =============================================================================
# Links
# =============================================================================

function _link_entity(entity_type::String, id::Int, target_type::String, target_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/$(target_type)_links/$target_id"
    _elabftw_post(url, Dict{String, Any}())
    return nothing
end

function _list_entity_links(entity_type::String, id::Int, target_type::String)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/$(target_type)_links"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

function _unlink_entity(entity_type::String, id::Int, target_type::String, target_id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/$entity_type/$id/$(target_type)_links/$target_id"
    _elabftw_delete(url)
    return nothing
end
