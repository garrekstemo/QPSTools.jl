"""
# QPSTools.jl - Quantum Photo-Science Laboratory Analysis Package

Standardized analysis tools for all lab members. This package provides:

- **Spectroscopic Analysis**: Common functions for UV-vis, FTIR, pump-probe data
- **Standardized Plotting**: Publication-quality themes and color schemes
- **Pump-Probe Analysis**: Time-resolved spectroscopy with IRF deconvolution
- **Baseline Correction**: Automated spectral processing
- **Kinetics Fitting**: Single/biexponential decay with global fitting

General-purpose spectroscopy functionality (types, fitting, baseline, units)
is provided by SpectroscopyTools.jl. QPSTools.jl adds lab-specific loaders,
registry, eLabFTW integration, and Makie plotting.

## Transient Absorption Workflow
```julia
using QPSTools
using CairoMakie  # or GLMakie for interactive use

# Load kinetic trace (time is shifted so peak is at t=0)
trace = load_ta_trace("data/kinetics.lvm"; mode=:OD)

# Fit with IRF deconvolution (default)
result = fit_exp_decay(trace)
println("τ = ", round(result.tau, digits=2), " ps")

# Plot with automatic residuals panel
fig, ax, ax_res = plot_kinetics(trace; fit=result)
save("figures/kinetics.pdf", fig)
```

## FTIR Workflow
```julia
using QPSTools

# Load FTIR spectrum from registry
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# Fit a peak
result = fit_peaks(spec, (2000, 2100))
result[1][:center].value
```

This is the **lab-wide standard analysis package**. All students should use these
functions for consistency and reproducibility.
"""
module QPSTools

# ============================================================================
# Dependencies
# ============================================================================

# General-purpose spectroscopy (types, fitting, baseline, units, peak detection/fitting)
using SpectroscopyTools

# Functions that QPS extends with new method dispatches
import SpectroscopyTools: find_peaks, fit_peaks
import SpectroscopyTools: transmittance_to_absorbance, absorbance_to_transmittance
import SpectroscopyTools: subtract_spectrum
import SpectroscopyTools: xdata, ydata, xlabel, ylabel, source_file

# Resolve name conflict: LinearAlgebra.normalize vs SpectroscopyTools.normalize
import SpectroscopyTools: normalize

# Re-export all SpectroscopyTools public names
# Types
export AbstractSpectroscopyData, AxisType
export TATrace, TASpectrum, TAMatrix, PumpProbeData
export PeakInfo, PeakFitResult, MultiPeakFitResult
export ExpDecayFit, ExpDecayIRFFit, BiexpDecayFit, MultiexpDecayFit
export GlobalFitResult, PumpProbeResult, TASpectrumFit
# Fitting
export fit_exp_decay, fit_biexp_decay, fit_decay, fit_decay_irf
export fit_decay_trace, fit_global, fit_global_decay
export fit_peaks, find_peaks, fit_ta_spectrum
export predict, predict_peak, predict_baseline, residuals
export report, format_results
# CurveFit / CurveFitModels re-exports
export NonlinearCurveFitProblem, solve, coef, stderror, confint
export isconverged, mse, rss, nobs, weights
export lorentzian, gaussian, pseudo_voigt, single_exponential
# Baseline
export als_baseline, arpls_baseline, snip_baseline
export correct_baseline, linear_baseline_correction
# Spectroscopy utilities
export normalize, smooth_data, savitzky_golay, calc_fwhm
export transmittance_to_absorbance, absorbance_to_transmittance
export subtract_spectrum, calc_ΔA
export time_index, peak_table
export extract_tau, irf_fwhm, pulse_fwhm
# Data interface
export xdata, ydata, zdata, xlabel, ylabel, zlabel
export is_matrix, source_file, npoints, title
export xaxis, xaxis_label, time_axis, wavelength_axis
# Units
export parse_concentration, parse_time
export wavelength_to_wavenumber, wavenumber_to_wavelength
export wavelength_to_energy, energy_to_wavelength, wavenumber_to_energy
export decay_time_to_linewidth, linewidth_to_decay_time

using Statistics
using LinearAlgebra
using Dates
using JSON
using HTTP
using JASCOFiles
using Makie

# ============================================================================
# Core modules
# ============================================================================

# QPS-specific types (AnnotatedSpectrum, FTIRFitResult alias)
include("types.jl")

# I/O
include("io.jl")
export load_spectroscopy                # Auto-detecting unified loader
export load_ta_trace, load_ta_spectrum  # Unified TA API
export load_ta_matrix                   # 2D TA data loading
export load_lvm                         # Legacy (raw channel access)
export find_peak_time                   # Time axis utility

# Re-export JASCOFiles for raw spectrum data
export JASCOSpectrum

# Registry system
include("registry.jl")
export load_registry, query_registry, list_registry
export set_data_dir, get_data_dir, reload_registry!
export set_registry_backend, get_registry_backend

# eLabFTW integration (optional backend)
include("elabftw.jl")
export configure_elabftw, elabftw_enabled, disable_elabftw, enable_elabftw
export clear_elabftw_cache, elabftw_cache_info
export create_experiment, update_experiment, upload_to_experiment
export tag_experiment, get_experiment, delete_experiment
export list_experiments, search_experiments
export delete_experiments, tag_experiments, update_experiments
export log_to_elab, tags_from_sample

# FTIR loading and analysis
include("ftir.jl")
export FTIRSpectrum, FTIRFitResult
export load_ftir, search_ftir, list_ftir, plot_ftir
export xreversed

# Raman loading and analysis
include("raman.jl")
export RamanSpectrum
export load_raman, search_raman, list_raman, plot_raman


# ============================================================================
# Lab-specific spectroscopy dispatches
# ============================================================================

# QPS-specific dispatches (JASCOSpectrum, FTIRSpectrum, RamanSpectrum methods)
include("spectroscopy.jl")
export cavity_transmittance

# QPS-specific peak detection dispatches (AnnotatedSpectrum)
include("peakdetection.jl")

# QPS-specific peak fitting dispatches (AnnotatedSpectrum)
include("peakfitting.jl")

# Plotting: themes, layers, layouts, and public API
include("plotting.jl")
export qps_theme
export publication_theme, compact_theme, poster_theme
export lab_colors, lab_linewidths
export setup_publication_plot, setup_poster_plot
export plot_spectrum, plot_kinetics
export plot_ta_heatmap, plot_spectra  # TAMatrix plotting
export plot_data  # Generic plotting via interface
export plot_peak_decomposition!, plot_peaks!  # Layer functions for existing axes
export plot_comparison, plot_waterfall  # Multi-spectrum views

# ============================================================================
# Auto-configure eLabFTW from environment variables
# ============================================================================
function __init__()
    url = get(ENV, "ELABFTW_URL", nothing)
    key = get(ENV, "ELABFTW_API_KEY", nothing)
    if !isnothing(url) && !isnothing(key) && !isempty(url) && !isempty(key)
        configure_elabftw(url=url, api_key=key)
    end
end

end # module QPSTools
