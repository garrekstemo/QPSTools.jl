# eLabFTW glue: AnnotatedSpectrum dispatches for ElabFTW.jl
#
# These methods extend ElabFTW.tags_from_sample and ElabFTW.log_to_elab
# with QPSTools-specific types (AnnotatedSpectrum, JASCO metadata).

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
# AnnotatedSpectrum dispatches
# =============================================================================

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
