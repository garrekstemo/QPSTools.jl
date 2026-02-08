# QPS-specific peak fitting dispatches
#
# General-purpose peak fitting (fit_peaks for raw vectors and AbstractSpectroscopyData,
# predict, predict_peak, predict_baseline, residuals, and all helpers)
# is provided by SpectroscopyTools.jl.
#
# This file adds:
# - fit_peaks dispatches for AnnotatedSpectrum (auto-fills sample_id)
#
# Plotting functions (plot_peak_decomposition!, plot_peaks!) are in plotting.jl.

# =============================================================================
# AnnotatedSpectrum dispatches
# =============================================================================

function fit_peaks(spec::AnnotatedSpectrum, region::Tuple{Real,Real}; kwargs...)
    x_full = xdata(spec)
    y_full = ydata(spec)

    mask = region[1] .< x_full .< region[2]
    x = x_full[mask]
    y = y_full[mask]

    if length(x) < 10
        error("Region $(region) contains only $(length(x)) points. Need at least 10.")
    end

    sid = sample_id(spec)
    return fit_peaks(x, y; sample_id=sid, kwargs...)
end

function fit_peaks(spec::AnnotatedSpectrum; kwargs...)
    x = xdata(spec)
    y = ydata(spec)

    sid = sample_id(spec)
    return fit_peaks(x, y; sample_id=sid, kwargs...)
end
