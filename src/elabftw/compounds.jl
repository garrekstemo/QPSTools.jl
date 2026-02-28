# Compound CRUD and linking

"""
    list_compounds(; limit=20, offset=0) -> Vector{Dict}

List compounds in eLabFTW.

# Example
```julia
compounds = list_compounds()
```
"""
function list_compounds(; limit::Int=20, offset::Int=0)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds?limit=$limit&offset=$offset"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    create_compound(; name, cas_number, smiles, molecular_formula) -> Int

Create a new compound. Returns the compound ID.

# Arguments
- `name::String` — Compound name
- `cas_number::String` — CAS registry number (optional)
- `smiles::String` — SMILES notation (optional)
- `molecular_formula::String` — Molecular formula (optional)

# Example
```julia
id = create_compound(name="NH4SCN", cas_number="1762-95-4")
```
"""
function create_compound(;
    name::String,
    cas_number::String="",
    smiles::String="",
    molecular_formula::String=""
)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds"
    payload = Dict{String, Any}("name" => name)
    !isempty(cas_number) && (payload["cas_number"] = cas_number)
    !isempty(smiles) && (payload["smiles"] = smiles)
    !isempty(molecular_formula) && (payload["molecular_formula"] = molecular_formula)
    response = _elabftw_post(url, payload)
    return _parse_id_from_response(response)
end

"""
    get_compound(id::Int) -> Dict

Retrieve a compound by ID.
"""
function get_compound(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds/$id"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end

"""
    delete_compound(id::Int)

Delete a compound.
"""
function delete_compound(id::Int)
    _check_enabled()
    url = "$(_elabftw_config.url)/api/v2/compounds/$id"
    _elabftw_delete(url)
    return nothing
end

"""
    link_compound(entity_type::Symbol, entity_id::Int, compound_id::Int)

Link a compound to an experiment or item.

`entity_type` is `:experiments` or `:items`.

# Example
```julia
link_compound(:experiments, 42, 7)
```
"""
function link_compound(entity_type::Symbol, entity_id::Int, compound_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/compounds/$compound_id"
    _elabftw_post(url, Dict{String, Any}())
    return nothing
end

"""
    list_compound_links(entity_type::Symbol, entity_id::Int) -> Vector{Dict}

List compounds linked to an experiment or item.

# Example
```julia
compounds = list_compound_links(:experiments, 42)
```
"""
function list_compound_links(entity_type::Symbol, entity_id::Int)
    _check_enabled()
    etype = String(entity_type)
    url = "$(_elabftw_config.url)/api/v2/$etype/$entity_id/compounds"
    response = _elabftw_request(url)
    return JSON.parse(String(response.body))
end
