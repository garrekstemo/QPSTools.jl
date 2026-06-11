# eLabFTW glue: AnnotatedSpectrum and StreakPL dispatches for ElabFTW.jl
#
# These methods extend ElabFTW.tags_from_sample and ElabFTW.log_to_elab
# with QPSTools-specific types (AnnotatedSpectrum, JASCO metadata, StreakPL).

# =============================================================================
# Auto-provenance helpers
# =============================================================================

"""Build a provenance body section from JASCO header fields."""
function _jasco_provenance_body(spec::AnnotatedSpectrum)
    lines = ["## Source", "- **File**: $(basename(spec.path))"]
    !isempty(spec.data.spectrometer) && push!(lines, "- **Instrument**: $(spec.data.spectrometer)")
    # date can be nothing (JASCOFiles 2.0): omit rather than log a non-date
    spec.data.date === nothing || push!(lines, "- **Acquired**: $(spec.data.date)")
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
spec = load_cavity("data/ftir/sample.csv"; solute="NH4SCN", concentration="1.0M")
tags = tags_from_sample(spec)
# => ["NH4SCN", "DMF", "1.0M", "CaF2"]
```
"""
tags_from_sample(spec::AnnotatedSpectrum; kwargs...) = tags_from_sample(spec.sample; kwargs...)

"""
    log_to_elab(spec::AnnotatedSpectrum, result; title, body, attachments, extra_tags, category) -> Int

Log analysis results with auto-provenance from JASCO header and auto-tags from
sample kwargs. Inherits idempotency from the keyword-only form.

Tags are auto-generated from: JASCO technique type + kwargs passed to the loader.
Body includes: provenance (file, instrument, date, script) + user body + formatted results.

# Example
```julia
spec = load_cavity("data/ftir/1.0M_NH4SCN_DMF.csv"; solute="NH4SCN", concentration="1.0M")
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

# =============================================================================
# StreakPL dispatches
# =============================================================================

"""Build a provenance body section from streak-image header fields."""
function _streak_provenance_body(s::StreakPL)
    img = s.data
    lines = ["## Source", "- **File**: $(basename(s.path))"]
    !isempty(img.camera) && push!(lines, "- **Camera**: $(img.camera)")
    !isempty(img.streak_device) && push!(lines, "- **Streak unit**: $(img.streak_device)")
    !isempty(img.time_range) && push!(lines, "- **Time range**: $(img.time_range)")
    img.center_wavelength > 0 && push!(lines, "- **Center wavelength**: $(img.center_wavelength) nm")
    img.date === nothing || push!(lines, "- **Acquired**: $(img.date)")
    prog = Base.PROGRAM_FILE
    (!isempty(prog) && isfile(prog)) && push!(lines, "- **Script**: $(basename(prog))")
    return join(lines, "\n")
end

"""Auto-generate tags from the streak technique + sample kwargs."""
function _streak_auto_tags(s::StreakPL)
    tags = ["pl"]
    append!(tags, tags_from_sample(s))
    return unique(filter(!isempty, tags))
end

"""
    tags_from_sample(s::StreakPL; kwargs...) -> Vector{String}

Extract tags from a StreakPL's sample metadata.
"""
tags_from_sample(s::StreakPL; kwargs...) = tags_from_sample(s.sample; kwargs...)

"""
    log_to_elab(s::StreakPL, result; title, body, attachments, extra_tags, category) -> Int

Log analysis results with auto-provenance from the streak-image header (camera,
streak unit, time range, acquisition date) and auto-tags from sample kwargs.
Inherits idempotency from the keyword-only form.

# Example
```julia
pl = load_streak_pl("data/PL/15K.img"; temperature="15K", material="NH4SCN")
result = fit_exp_decay(...)

log_to_elab(pl, result;
    title = "Streak PL: 15 K decay",
    attachments = ["figures/streak_15K.png"]
)
```
"""
function log_to_elab(s::StreakPL, result;
    title::String,
    body::String = "",
    attachments::Vector{String} = String[],
    extra_tags::Vector{String} = String[],
    category::Union{Int, Nothing} = nothing
)
    auto_tags = _streak_auto_tags(s)
    all_tags = unique(vcat(auto_tags, extra_tags))

    full_body = _streak_provenance_body(s)
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
