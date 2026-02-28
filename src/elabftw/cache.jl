# eLabFTW file cache management

"""
    download_elabftw_file(item_id::Int, upload_id::Int; filename) -> String

Download a file attachment from an eLabFTW item and cache locally.
Returns the local file path.

!!! note "Deprecated"
    Use `download_item_upload` instead. This function is kept for backward compatibility.
"""
function download_elabftw_file(item_id::Int, upload_id::Int; filename::String="")
    return download_item_upload(item_id, upload_id; filename=filename)
end

"""
    download_item_upload(item_id::Int, upload_id::Int; filename) -> String

Download a file attachment from an eLabFTW item and cache locally.
Returns the local file path.
"""
function download_item_upload(item_id::Int, upload_id::Int; filename::String="")
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

"""
    download_experiment_upload(experiment_id::Int, upload_id::Int; filename) -> String

Download a file attachment from an eLabFTW experiment and cache locally.
Returns the local file path.
"""
function download_experiment_upload(experiment_id::Int, upload_id::Int; filename::String="")
    cache_path = _get_cache_path(experiment_id, upload_id, filename)

    if isfile(cache_path)
        return cache_path
    end

    url = "$(_elabftw_config.url)/api/v2/experiments/$experiment_id/uploads/$upload_id"
    response = _elabftw_request(url; accept="application/octet-stream")

    mkpath(dirname(cache_path))
    write(cache_path, response.body)
    @info "Downloaded and cached" path=cache_path

    return cache_path
end

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

function _get_cache_path(item_id::Int, upload_id::Int, filename::String)
    cache_dir = _elabftw_config.cache_dir
    if isempty(filename)
        filename = "upload_$upload_id.csv"
    end
    return joinpath(cache_dir, string(item_id), filename)
end
