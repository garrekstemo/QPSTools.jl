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

function find_peaks(spec::AnnotatedSpectrum; kwargs...)
    return find_peaks(spec.data.x, spec.data.y; kwargs...)
end
