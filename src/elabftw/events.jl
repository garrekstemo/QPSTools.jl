# Booking/scheduler events

"""
    list_events(; limit=20, offset=0) -> Vector{Dict}

List scheduler events (bookings).

# Example
```julia
events = list_events()
for e in events
    println(e["id"], ": ", e["title"], " (", e["start"], ")")
end
```
"""
function list_events(; limit::Int=20, offset::Int=0)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/events?limit=$limit&offset=$offset"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_event(; title, start, end_, item) -> Int

Create a scheduler event (booking). Returns the event ID.

# Arguments
- `title::String` — Event title
- `start::String` — Start datetime (ISO 8601, e.g. "2026-03-01T09:00:00")
- `end_::String` — End datetime (ISO 8601)
- `item::Union{Int, Nothing}` — Item ID to book (optional)

# Example
```julia
id = create_event(title="FTIR session", start="2026-03-01T09:00:00", end_="2026-03-01T12:00:00", item=7)
```
"""
function create_event(;
    title::String,
    start::String,
    end_::String,
    item::Union{Int, Nothing} = nothing
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/events"
    payload = Dict{String, Any}(
        "title" => title,
        "start" => start,
        "end" => end_
    )
    if !isnothing(item)
        payload["item"] = item
    end
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    get_event(id::Int) -> Dict

Retrieve a scheduler event by ID.
"""
function get_event(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/events/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    update_event(id::Int; title, start, end_)

Update a scheduler event.
"""
function update_event(id::Int;
    title::Union{String, Nothing}=nothing,
    start::Union{String, Nothing}=nothing,
    end_::Union{String, Nothing}=nothing
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/events/$id"
    payload = Dict{String, Any}()
    !isnothing(title) && (payload["title"] = title)
    !isnothing(start) && (payload["start"] = start)
    !isnothing(end_) && (payload["end"] = end_)
    isempty(payload) && return nothing
    _elabftw_patch(url, payload)
    return nothing
end

"""
    delete_event(id::Int)

Delete a scheduler event.
"""
function delete_event(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/events/$id"
    _elabftw_delete(url)
    return nothing
end
