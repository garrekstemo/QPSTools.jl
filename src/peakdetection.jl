# QPS-specific peak detection dispatches
#
# General-purpose peak detection (PeakInfo, find_peaks for vectors, peak_table)
# is provided by SpectroscopyTools.jl.
#
# This file adds:
# - find_peaks dispatch for AnnotatedSpectrum
#
# Plotting functions (plot_peaks!) are in plotting.jl.

# =============================================================================
# AnnotatedSpectrum dispatch
# =============================================================================

"""
    find_peaks(spec::AnnotatedSpectrum; kwargs...) -> Vector{PeakInfo}

Detect peaks in a spectrum. Returns a vector of `PeakInfo` with position,
height, prominence, and width for each detected peak.

# Keywords
- `min_prominence=0.05`: Minimum prominence as fraction of data range (0–1)
- `min_width=0`: Minimum peak width (in x-axis units)
- `max_width=Inf`: Maximum peak width
- `min_height=-Inf`: Minimum peak height
- `window=1`: Half-width of comparison window (in index units)
- `baseline=nothing`: Apply baseline correction before detection (`:als`, `:arpls`, `:snip`)
- `baseline_kw=NamedTuple()`: Keyword arguments for baseline correction

# Example
```julia
spec = load_raman(sample="center", material="MoSe2")
peaks = find_peaks(spec)
peaks = find_peaks(spec; min_prominence=0.1, min_width=5.0)
```
"""
function find_peaks(spec::AnnotatedSpectrum; kwargs...)
    return find_peaks(spec.data.x, spec.data.y; kwargs...)
end
