# Provenance helpers: log_to_elab, tags_from_sample, JASCO integration

# =============================================================================
# .elab_id helpers (idempotent logging)
# =============================================================================

"""Return path for .elab_id file next to the running script, or nothing."""
function _elab_id_path()
    prog = Base.PROGRAM_FILE
    (isempty(prog) || !isfile(prog)) && return nothing
    return joinpath(dirname(abspath(prog)), ".elab_id")
end

"""Read existing .elab_id file. Returns (id=Int, title=String) or nothing."""
function _read_elab_id()
    path = _elab_id_path()
    (isnothing(path) || !isfile(path)) && return nothing
    try
        data = JSON.parsefile(path)
        return (id=data["id"]::Int, title=get(data, "title", "")::String)
    catch
        return nothing
    end
end

"""Write .elab_id file next to the running script."""
function _write_elab_id(id::Int, title::String)
    path = _elab_id_path()
    isnothing(path) && return
    open(path, "w") do io
        JSON.print(io, Dict("id" => id, "title" => title), 2)
    end
end

# =============================================================================
# Attachment replacement (idempotent uploads)
# =============================================================================

"""Replace attachments by filename — delete existing with same name, then upload."""
function _replace_attachments(experiment_id::Int, filepaths::Vector{String})
    isempty(filepaths) && return
    exp = get_experiment(experiment_id)
    existing = get(exp, "uploads", [])
    for filepath in filepaths
        fname = basename(filepath)
        for upload in existing
            if get(upload, "real_name", "") == fname
                _delete_entity_upload("experiments", experiment_id, upload["id"])
                break
            end
        end
        upload_to_experiment(experiment_id, filepath; comment=fname)
    end
end

# =============================================================================
# Auto-provenance helpers
# =============================================================================

"""Build a provenance body section from JASCO header fields."""
function _jasco_provenance_body(spec::AnnotatedSpectrum)
    lines = ["## Source", "- **File**: $(basename(spec.path))"]
    !isempty(spec.data.spectrometer) && push!(lines, "- **Instrument**: $(spec.data.spectrometer)")
    push!(lines, "- **Acquired**: $(spec.data.date)")
    prog = Base.PROGRAM_FILE
    (!isempty(prog) && isfile(prog)) && push!(lines, "- **Script**: $(basename(prog))")
    return join(lines, "\n")
end

"""Auto-generate tags from JASCO header + sample kwargs."""
function _jasco_auto_tags(spec::AnnotatedSpectrum)
    tags = [_jasco_technique_tag(spec)]
    append!(tags, tags_from_sample(spec))
    return unique(filter(!isempty, tags))
end

# =============================================================================
# Idempotent log_to_elab
# =============================================================================

"""
    log_to_elab(; title, body, attachments, tags, category, metadata) -> Int

Log analysis results to eLabFTW. Idempotent: if a `.elab_id` file exists next
to the running script with a matching title, updates the existing experiment
instead of creating a new one.

Returns the experiment ID.

# Examples
```julia
# First run: creates experiment, writes .elab_id
log_to_elab(title="FTIR: CN stretch fit", body=format_results(result))

# Re-run: updates existing experiment
log_to_elab(title="FTIR: CN stretch fit", body=format_results(result))
```
"""
function log_to_elab(;
    title::String,
    body::String = "",
    attachments::Vector{String} = String[],
    tags::Vector{String} = String[],
    category::Union{Int, Nothing} = nothing,
    metadata::Union{Dict, Nothing} = nothing
)
    existing = _read_elab_id()

    if !isnothing(existing) && existing.title == title
        # Update existing experiment
        id = existing.id
        update_experiment(id; title=title, body=body)
        _replace_attachments(id, attachments)
        if !isempty(tags)
            tag_experiment(id, tags)
        end
        exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
        println("eLabFTW: updated experiment #$id")
        println("  $exp_url")
    else
        # Create new experiment
        id = create_experiment(; title=title, body=body, category=category, metadata=metadata)
        for filepath in attachments
            upload_to_experiment(id, filepath; comment=basename(filepath))
        end
        if !isempty(tags)
            tag_experiment(id, tags)
        end
        _write_elab_id(id, title)
        exp_url = "$(_elabftw_config.url)/experiments.php?mode=view&id=$id"
        println("eLabFTW: created experiment #$id")
        println("  $exp_url")
    end

    return id
end

"""
    tags_from_sample(sample::Dict; include=nothing, exclude=["_id", "path", "date"]) -> Vector{String}

Extract tags from sample metadata dictionary.

By default, extracts values from common fields (solute, solvent, material, etc.)
and excludes internal fields (_id, path, date).

# Arguments
- `sample::Dict` — Sample metadata (e.g., from `spec.sample`)
- `include::Vector{Symbol}` — Only include these fields (default: all except excluded)
- `exclude::Vector{String}` — Fields to skip (default: ["_id", "path", "date"])

# Example
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
tags = tags_from_sample(spec.sample)
# => ["NH4SCN", "DMF", "1.0M", "CaF2"]
```
"""
function tags_from_sample(sample::Dict;
    include::Union{Nothing, Vector{Symbol}} = nothing,
    exclude::Vector{String} = ["_id", "path", "date", "pathlength"]
)
    tags = String[]

    for (k, v) in sample
        k in exclude && continue
        if !isnothing(include) && Symbol(k) ∉ include
            continue
        end
        v isa String || continue
        isempty(v) && continue
        push!(tags, v)
    end

    return unique(tags)
end

"""
    tags_from_sample(spec::AnnotatedSpectrum; kwargs...) -> Vector{String}

Extract tags from an AnnotatedSpectrum's sample metadata.

# Example
```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
tags = tags_from_sample(spec)
# => ["NH4SCN", "DMF", "1.0M", "CaF2"]
```
"""
tags_from_sample(spec::AnnotatedSpectrum; kwargs...) = tags_from_sample(spec.sample; kwargs...)

"""
    log_to_elab(spec::AnnotatedSpectrum, result; title, body, attachments, extra_tags, category) -> Int

Log analysis results with auto-provenance from JASCO header and auto-tags from
sample kwargs. Inherits idempotency from the keyword-only form.

Tags are auto-generated from: JASCO technique type + kwargs passed to load_ftir/load_raman.
Body includes: provenance (file, instrument, date, script) + user body + formatted results.

# Example
```julia
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv"; solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))

log_to_elab(spec, result;
    title = "FTIR: CN stretch fit",
    attachments = ["figures/fit.pdf"],
    extra_tags = ["peak_fit"]
)
```
"""
function log_to_elab(spec::AnnotatedSpectrum, result;
    title::String,
    body::String = "",
    attachments::Vector{String} = String[],
    extra_tags::Vector{String} = String[],
    category::Union{Int, Nothing} = nothing
)
    auto_tags = _jasco_auto_tags(spec)
    all_tags = unique(vcat(auto_tags, extra_tags))

    full_body = _jasco_provenance_body(spec)
    if !isempty(body)
        full_body *= "\n\n" * body
    end
    full_body *= "\n\n" * format_results(result)

    return log_to_elab(;
        title = title,
        body = full_body,
        attachments = attachments,
        tags = all_tags,
        category = category
    )
end
