# Internal HTTP helpers for eLabFTW API v2

function _check_enabled()
    if !elabftw_enabled()
        error("eLabFTW not enabled. Call configure_elabftw() first.")
    end
end

function _parse_id_from_response(response)::Int
    location = HTTP.header(response, "Location", "")
    if isempty(location)
        body = JSON.parse(String(response.body))
        id = get(body, "id", nothing)
        isnothing(id) && error("eLabFTW: no ID in response (no Location header or body id)")
        return Int(id)
    end
    id_str = last(split(location, "/"))
    return parse(Int, id_str)
end

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
                error("eLabFTW resource not found: $url")
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
                error("eLabFTW resource not found: $url")
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
                error("eLabFTW resource not found: $url")
            else
                error("eLabFTW upload failed with status $status")
            end
        end
        rethrow(e)
    finally
        close(io)
    end
end
