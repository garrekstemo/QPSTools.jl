"""
Project-local registry system for sample metadata.

The registry maps sample identifiers to file paths and metadata.
Each project maintains its own `data/registry.json`.

Supports multiple backends:
- `:local` — JSON file registry (default)
- `:elabftw` — eLabFTW database
- `:hybrid` — Try eLabFTW first, fall back to local
"""

# Registry cache: path -> (data, mtime)
const _registry_cache = Dict{String, Tuple{Dict, Float64}}()

# Configurable data directory
const _data_dir = Ref{String}("data")

# Registry backend: :local, :elabftw, :hybrid
const _registry_backend = Ref{Symbol}(:local)

"""
    set_registry_backend(backend::Symbol)

Set the registry backend. Options:
- `:local` — Use local JSON registry only (default)
- `:elabftw` — Use eLabFTW only (requires configure_elabftw())
- `:hybrid` — Try eLabFTW first, fall back to local if offline

# Example
```julia
set_registry_backend(:hybrid)
```
"""
function set_registry_backend(backend::Symbol)
    if backend ∉ (:local, :elabftw, :hybrid)
        error("Unknown backend :$backend. Use :local, :elabftw, or :hybrid")
    end
    _registry_backend[] = backend
    @info "Registry backend set to :$backend"
end

"""
    get_registry_backend() -> Symbol

Get the current registry backend.
"""
get_registry_backend() = _registry_backend[]

"""
    set_data_dir(path::String)

Set the data directory for registry lookups. Default is "data".
"""
function set_data_dir(path::String)
    _data_dir[] = path
    # Clear cache when directory changes
    empty!(_registry_cache)
end

"""
    get_data_dir() -> String

Get the current data directory.
"""
get_data_dir() = _data_dir[]

"""
    load_registry(; data_dir=get_data_dir()) -> Dict

Load registry.json from data directory. Results are cached and
automatically reloaded if the file has been modified.
"""
function load_registry(; data_dir::String=get_data_dir())
    path = joinpath(data_dir, "registry.json")
    abspath_key = abspath(path)

    if !isfile(path)
        error("Registry not found: $path\nCreate a registry.json in your data directory.")
    end

    current_mtime = mtime(path)

    # Return cached version if still valid
    if haskey(_registry_cache, abspath_key)
        cached_data, cached_mtime = _registry_cache[abspath_key]
        if current_mtime <= cached_mtime
            return cached_data
        end
    end

    # Load and cache
    data = JSON.parsefile(path)
    _registry_cache[abspath_key] = (data, current_mtime)
    return data
end

"""
    reload_registry!()

Force reload of registry from disk. Use after manually editing registry.json.
"""
function reload_registry!()
    empty!(_registry_cache)
    load_registry()
    println("Registry reloaded from $(joinpath(get_data_dir(), "registry.json"))")
end

"""
    query_registry(category::Symbol; kwargs...) -> Vector{Dict}

Query registry entries matching all provided keyword filters.

Routes to the appropriate backend based on `get_registry_backend()`:
- `:local` — Query local JSON registry
- `:elabftw` — Query eLabFTW database
- `:hybrid` — Try eLabFTW, fall back to local if unavailable

Returns a vector of matching entries, each with an added `_id` field
containing the entry's key in the registry.

# Arguments
- `category`: Registry category (e.g., `:ftir`, `:uvvis`, `:raman`)
- `kwargs...`: Field filters (e.g., `solute="NH4SCN"`, `concentration="1.0M"`)

# Examples
```julia
# All FTIR entries
query_registry(:ftir)

# Filter by solute
query_registry(:ftir, solute="NH4SCN")

# Multiple filters
query_registry(:ftir, solute="NH4SCN", concentration="1.0M")
```
"""
function query_registry(category::Symbol; kwargs...)
    backend = get_registry_backend()

    if backend == :local
        return query_registry_local(category; kwargs...)
    elseif backend == :elabftw
        return query_elabftw(category; kwargs...)
    elseif backend == :hybrid
        return _query_hybrid(category; kwargs...)
    else
        error("Unknown backend: $backend")
    end
end

"""
    query_registry_local(category::Symbol; kwargs...) -> Vector{Dict}

Query the local JSON registry. Used internally by query_registry.
"""
function query_registry_local(category::Symbol; kwargs...)
    reg = load_registry()
    cat_str = string(category)

    if !haskey(reg, cat_str)
        available = join(keys(reg), ", ")
        error("Unknown registry category ':$category'. Available: $available")
    end

    entries = reg[cat_str]

    matches = Dict{String, Any}[]
    for (id, entry) in entries
        # Check if all provided kwargs match
        match = all(kwargs) do (k, v)
            v === nothing || get(entry, string(k), nothing) == v
        end
        if match
            # Add _id field to identify the entry
            push!(matches, merge(entry, Dict("_id" => id)))
        end
    end

    return matches
end

"""
Try eLabFTW first, fall back to local on error.
"""
function _query_hybrid(category::Symbol; kwargs...)
    if elabftw_enabled()
        try
            return query_elabftw(category; kwargs...)
        catch e
            @warn "eLabFTW query failed, falling back to local registry" exception=e
        end
    end
    return query_registry_local(category; kwargs...)
end

"""
    list_registry(category::Symbol; field::Symbol) -> Vector

List unique values for a given field in a registry category.

Uses the current registry backend (local, eLabFTW, or hybrid).

# Examples
```julia
list_registry(:ftir, field=:concentration)  # ["0.45M", "1.0M", ...]
list_registry(:ftir, field=:solvent)        # ["DMF", "DMSO", ...]
```
"""
function list_registry(category::Symbol; field::Symbol)
    matches = query_registry(category)
    field_str = string(field)
    values = [get(m, field_str, nothing) for m in matches]
    return sort(unique(filter(!isnothing, values)))
end

# =============================================================================
# Hybrid backend helpers (eLabFTW + local)
# =============================================================================

# Placeholder - actual implementation in elabftw.jl
# These allow registry.jl to compile before elabftw.jl is loaded
function elabftw_enabled end
function query_elabftw end
