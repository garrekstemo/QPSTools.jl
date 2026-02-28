# eLabFTW configuration

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
- `cache_dir::String` — Local cache directory (default: "~/.cache/qpstools/elabftw")
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
    cache_dir::String = joinpath(homedir(), ".cache", "qpstools", "elabftw"),
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

Disable eLabFTW integration.
"""
function disable_elabftw()
    _elabftw_config.enabled = false
    @info "eLabFTW disabled"
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

"""
    test_connection()

Verify the eLabFTW connection by fetching the current user's profile.
Prints the user's name and email on success.

# Example
```julia
configure_elabftw(url="https://lab.elabftw.net", api_key=ENV["ELABFTW_API_KEY"])
test_connection()
# => "Connected to eLabFTW as Jane Doe (jane@lab.edu)"
```
"""
function test_connection()
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/users/me"
    response = _elabftw_request(url)
    user = JSON.parse(String(response.body))
    fullname = get(user, "fullname", "Unknown")
    email = get(user, "email", "")
    println("Connected to eLabFTW as $fullname ($email)")
end
