# Public experiment API — thin wrappers over generic entity helpers.
# All signatures and docstrings preserved from the original monolithic file.

"""
    create_experiment(; title, body, category, metadata) -> Int

Create a new experiment in eLabFTW. Returns the experiment ID.

# Arguments
- `title::String` — Experiment title
- `body::String` — Experiment body (supports HTML/markdown)
- `category::Union{Int, Nothing}` — Experiment category ID
- `metadata::Union{Dict, Nothing}` — Extra metadata JSON

# Example
```julia
id = create_experiment(title="FTIR measurement", body="CN stretch region")
```
"""
function create_experiment(;
    title::String,
    body::String = "",
    category::Union{Int, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    return _create_entity("experiments"; title=title, body=body, category=category, metadata=metadata)
end

"""
    create_from_template(template_id; title, body, tags) -> Int

Create a new experiment from an eLabFTW experiment template. Returns the experiment ID.

Optionally override the title and body from the template, and add tags.

# Arguments
- `template_id::Int` — Template ID in eLabFTW
- `title::String` — Override template title (optional)
- `body::String` — Override template body (optional)
- `tags::Vector{String}` — Tags to add to the new experiment

# Example
```julia
id = create_from_template(42; title="FTIR: NH4SCN run 3", tags=["ftir", "nh4scn"])
```
"""
function create_from_template(template_id::Int;
    title::Union{String, Nothing} = nothing,
    body::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[]
)
    id = _create_entity("experiments"; template=template_id)

    if !isnothing(title) || !isnothing(body)
        update_experiment(id; title=title, body=body)
    end

    for tag in tags
        tag_experiment(id, tag)
    end

    return id
end

"""
    update_experiment(id::Int; title, body, metadata)

Update an existing experiment in eLabFTW.

# Arguments
- `id::Int` — Experiment ID
- `title::String` — New title (optional)
- `body::String` — New body content (optional)
- `metadata::Union{Dict, Nothing}` — Extra metadata JSON (optional)

# Example
```julia
update_experiment(42; body="Updated analysis results")
```
"""
function update_experiment(id::Int;
    title::Union{String, Nothing} = nothing,
    body::Union{String, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    return _update_entity("experiments", id; title=title, body=body, metadata=metadata)
end

"""
    upload_to_experiment(id::Int, filepath::String; comment) -> Int

Upload a file attachment to an experiment. Returns the upload ID.

# Arguments
- `id::Int` — Experiment ID
- `filepath::String` — Path to file to upload
- `comment::String` — Optional comment for the attachment

# Example
```julia
upload_id = upload_to_experiment(42, "figures/fit.pdf"; comment="Peak fit figure")
```
"""
function upload_to_experiment(id::Int, filepath::String; comment::String="")
    return _upload_to_entity("experiments", id, filepath; comment=comment)
end

"""
    tag_experiment(id::Int, tag::String)

Add a tag to an experiment.

# Example
```julia
tag_experiment(42, "ftir")
tag_experiment(42, "nh4scn")
```
"""
tag_experiment(id::Int, tag::String) = _tag_entity("experiments", id, tag)

"""
    tag_experiment(id::Int, tags::Vector{String})

Add multiple tags to an experiment.

# Example
```julia
tag_experiment(42, ["ftir", "nh4scn", "peak_fit"])
```
"""
tag_experiment(id::Int, tags::Vector{String}) = _tag_entity("experiments", id, tags)

"""
    list_tags(id::Int) -> Vector{Dict}

List all tags on an experiment. Returns an array of tag objects with
`"tag_id"` and `"tag"` keys.

# Example
```julia
tags = list_tags(42)
for t in tags
    println(t["tag_id"], ": ", t["tag"])
end
```
"""
list_tags(id::Int) = _list_entity_tags("experiments", id)

# Explicit alias for consistency with new entity types
const list_experiment_tags = list_tags

"""
    untag_experiment(id::Int, tag_id::Int)

Remove a single tag from an experiment (does not delete the team-level tag).

Use `list_tags(id)` to find the tag ID (the `"tag_id"` field).

# Example
```julia
tags = list_tags(42)
untag_experiment(42, tags[1]["tag_id"])
```
"""
untag_experiment(id::Int, tag_id::Int) = _untag_entity("experiments", id, tag_id)

"""
    clear_tags(id::Int)

Remove all tags from an experiment.

# Example
```julia
clear_tags(42)
```
"""
clear_tags(id::Int) = _clear_entity_tags("experiments", id)

# Explicit alias for consistency with new entity types
const clear_experiment_tags = clear_tags

"""
    get_experiment(id::Int) -> Dict

Retrieve an experiment by ID.

# Example
```julia
exp = get_experiment(42)
exp["title"]
exp["body"]
```
"""
get_experiment(id::Int) = _get_entity("experiments", id)

"""
    delete_experiment(id::Int)

Delete an experiment from eLabFTW.

# Example
```julia
delete_experiment(7377)
```
"""
function delete_experiment(id::Int)
    _delete_entity("experiments", id)
    println("Deleted experiment $id")
    return nothing
end

"""
    duplicate_experiment(id::Int) -> Int

Duplicate an experiment. Returns the new experiment ID.

# Example
```julia
new_id = duplicate_experiment(42)
```
"""
duplicate_experiment(id::Int) = _duplicate_entity("experiments", id)

"""
    list_experiments(; limit, offset, order, sort) -> Vector{Dict}

List experiments from eLabFTW with pagination and sorting.

# Arguments
- `limit::Int` — Maximum number of results (default: 20)
- `offset::Int` — Skip first N results (default: 0)
- `order::Symbol` — Sort field: `:date`, `:title`, `:id` (default: `:date`)
- `sort::Symbol` — Sort direction: `:desc`, `:asc` (default: `:desc`)

# Example
```julia
# Most recent 10 experiments
exps = list_experiments(limit=10)

# Paginate through results
page1 = list_experiments(limit=20, offset=0)
page2 = list_experiments(limit=20, offset=20)
```
"""
function list_experiments(;
    limit::Int = 20,
    offset::Int = 0,
    order::Symbol = :date,
    sort::Symbol = :desc
)
    return _list_entities("experiments"; limit=limit, offset=offset, order=order, sort=sort)
end

"""
    search_experiments(; query, tags, limit, offset, order, sort) -> Vector{Dict}

Search experiments in eLabFTW by text query and/or tags.

# Arguments
- `query::String` — Full-text search term (searches title and body)
- `tags::Vector{String}` — Filter by tags (experiments must have ALL specified tags)
- `limit::Int` — Maximum number of results (default: 20)
- `offset::Int` — Skip first N results (default: 0)
- `order::Symbol` — Sort field: `:date`, `:title`, `:id` (default: `:date`)
- `sort::Symbol` — Sort direction: `:desc`, `:asc` (default: `:desc`)

# Examples
```julia
# Search by text
results = search_experiments(query="CN stretch")

# Filter by tags
results = search_experiments(tags=["ftir", "nh4scn"])

# Combine query and tags
results = search_experiments(query="peak fit", tags=["ftir"])
```
"""
function search_experiments(;
    query::Union{String, Nothing} = nothing,
    tags::Vector{String} = String[],
    limit::Int = 20,
    offset::Int = 0,
    order::Symbol = :date,
    sort::Symbol = :desc
)
    return _list_entities("experiments";
        query=query, tags=tags, limit=limit, offset=offset, order=order, sort=sort)
end

# Experiment sub-resources: uploads, steps

"""
    list_experiment_uploads(id::Int) -> Vector{Dict}

List all file uploads on an experiment.
"""
list_experiment_uploads(id::Int) = _list_entity_uploads("experiments", id)

"""
    delete_experiment_upload(id::Int, upload_id::Int)

Delete a file upload from an experiment.
"""
delete_experiment_upload(id::Int, upload_id::Int) = _delete_entity_upload("experiments", id, upload_id)

"""
    add_step(id, body) -> Int

Add an analysis step to an experiment. Returns the step ID.

Steps track the procedure used in an analysis (e.g., "Load raw data",
"Fit single exponential with IRF"). Use `finish_step` to mark completed.

# Example
```julia
id = create_experiment(title="TA kinetics analysis")
s1 = add_step(id, "Load and inspect raw data")
s2 = add_step(id, "Fit single exponential with IRF")
finish_step(id, s1)
```
"""
add_step(id::Int, body::String) = _add_entity_step("experiments", id, body)

"""
    list_steps(id) -> Vector{Dict}

List all steps for an experiment.

# Example
```julia
steps = list_steps(42)
for step in steps
    status = get(step, "finished", false) ? "done" : "todo"
    println("[", status, "] ", step["body"])
end
```
"""
list_steps(id::Int) = _list_entity_steps("experiments", id)

"""
    finish_step(id, step_id)

Mark a step as finished.

# Example
```julia
finish_step(42, 1)
```
"""
finish_step(id::Int, step_id::Int) = _finish_entity_step("experiments", id, step_id)

"""
    link_experiments(id1, id2)

Create a link between two experiments. The link appears on experiment `id1`
pointing to experiment `id2`.

# Example
```julia
link_experiments(42, 37)  # Link experiment 42 → 37
```
"""
function link_experiments(id1::Int, id2::Int)
    _link_entity("experiments", id1, "experiments", id2)
    println("Linked experiment $id1 → $id2")
    return nothing
end

"""
    list_experiment_links(id::Int) -> Vector{Dict}

List all experiment-to-experiment links on an experiment.
"""
list_experiment_links(id::Int) = _list_entity_links("experiments", id, "experiments")

"""
    unlink_experiments(id1::Int, id2::Int)

Remove a link between two experiments.
"""
function unlink_experiments(id1::Int, id2::Int)
    _unlink_entity("experiments", id1, "experiments", id2)
    return nothing
end
