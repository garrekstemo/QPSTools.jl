module QPSToolsElabFTWExt

# eLabFTW provenance glue: typed `log_to_elab` / `tags_from_sample` dispatches for
# QPSTools' `Spectrum` and `StreakPL` objects. ElabFTW is a *weak* dependency of
# QPSTools, so this extension loads only once the user does `using ElabFTW`.
#
# The join lives here because nothing else can host it: ElabFTW knows nothing of
# spectra, and OpticalSpectroscopy knows nothing of eLabFTW. (Extending ElabFTW's
# generics on OpticalSpectroscopy's `Spectrum` would be type piracy in QPSTools
# proper — the extension is the blessed home for exactly this kind of glue.)

using QPSTools: StreakPL, sample_metadata
using OpticalSpectroscopy: Spectrum, format_results
import ElabFTW: tags_from_sample, log_to_elab

# =============================================================================
# Auto-provenance helpers
# =============================================================================

"""Technique tag from the `:technique` token (`"ftir"`, `"raman"`, …)."""
_technique_tag(spec::Spectrum) = string(get(spec.metadata, :technique, "spectroscopy"))

"""Build a provenance body section from a Spectrum's stamped header metadata."""
function _spectrum_provenance_body(spec::Spectrum)
    lines = ["## Source", "- **File**: $(get(spec.metadata, :source_file, "unknown"))"]
    inst = get(spec.metadata, :instrument, "")
    isempty(inst) || push!(lines, "- **Instrument**: $inst")
    # date can be absent (no JASCO date): omit rather than log a non-date
    d = get(spec.metadata, :date, nothing)
    isnothing(d) || push!(lines, "- **Acquired**: $d")
    prog = Base.PROGRAM_FILE
    (!isempty(prog) && isfile(prog)) && push!(lines, "- **Script**: $(basename(prog))")
    return join(lines, "\n")
end

"""Auto-generate tags from the technique token + sample kwargs."""
function _spectrum_auto_tags(spec::Spectrum)
    tags = [_technique_tag(spec)]
    append!(tags, tags_from_sample(spec))
    return unique(filter(!isempty, tags))
end

# =============================================================================
# Spectrum dispatches
# =============================================================================

"""
    tags_from_sample(spec::Spectrum; kwargs...) -> Vector{String}

Extract tags from a Spectrum's sample metadata (`metadata[:sample]`).

# Example
```julia
spec = load_spectrum("data/ftir/sample.csv"; solute="NH4SCN", concentration="1.0M")
tags = tags_from_sample(spec)
# => ["NH4SCN", "DMF", "1.0M", "CaF2"]
```
"""
tags_from_sample(spec::Spectrum; kwargs...) = tags_from_sample(sample_metadata(spec); kwargs...)

"""
    log_to_elab(spec::Spectrum, result; title, body, attachments, extra_tags, category) -> Int

Log analysis results with auto-provenance from the Spectrum's stamped metadata
and auto-tags from sample kwargs. Inherits idempotency from the keyword-only form.

Tags are auto-generated from: the `:technique` token + sample kwargs.
Body includes: provenance (file, instrument, date, script) + user body + formatted results.

# Example
```julia
spec = load_spectrum("data/ftir/1.0M_NH4SCN_DMF.csv"; solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))

log_to_elab(spec, result;
    title = "FTIR: CN stretch fit",
    attachments = ["figures/fit.pdf"],
    extra_tags = ["peak_fit"]
)
```
"""
function log_to_elab(spec::Spectrum, result;
    title::String,
    body::String = "",
    attachments::Vector{String} = String[],
    extra_tags::Vector{String} = String[],
    category::Union{Int, Nothing} = nothing
)
    auto_tags = _spectrum_auto_tags(spec)
    all_tags = unique(vcat(auto_tags, extra_tags))

    full_body = _spectrum_provenance_body(spec)
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

end # module QPSToolsElabFTWExt
