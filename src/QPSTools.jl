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
eLabFTW integration, and Makie plotting.

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

# Load FTIR spectrum from file
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv"; solute="NH4SCN", concentration="1.0M")

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
import SpectroscopyTools: subtract_spectrum, correct_baseline
import SpectroscopyTools: xdata, ydata, zdata, xlabel, ylabel, zlabel
import SpectroscopyTools: source_file, npoints, title, is_matrix
import SpectroscopyTools: wavenumber, signal, delay, wavelength

# Resolve name conflict: LinearAlgebra.normalize vs SpectroscopyTools.normalize
import SpectroscopyTools: normalize
import SpectroscopyTools: normalize_intensity

# Import unexported SpectroscopyTools names that QPSTools re-exports
import SpectroscopyTools: n_exp, weights, anharmonicity, format_results

# Dielectric functions from CurveFitModels (via SpectroscopyTools)
import SpectroscopyTools: dielectric_real, dielectric_imag

# Chirp correction (moved to SpectroscopyTools)
import SpectroscopyTools: ChirpCalibration, polynomial,
    detect_chirp, correct_chirp, subtract_background,
    save_chirp, load_chirp

# Decay-associated spectra (from global TAMatrix fitting)
import SpectroscopyTools: das

# PLMap type and analysis (moved to SpectroscopyTools)
import SpectroscopyTools: extract_spectrum, peak_centers, intensity

# Re-export SpectroscopyTools public names
# Types (from SpectroscopyTools)
export AbstractSpectroscopyData
export TATrace, TASpectrum, TAMatrix
export PLMap
export PeakInfo, PeakFitResult, MultiPeakFitResult
export ExpDecayFit, MultiexpDecayFit
export GlobalFitResult, TASpectrumFit
# Types (defined in QPSTools)
export AxisType, time_axis, wavelength_axis
export PumpProbeData
# Fitting
export fit_exp_decay
export fit_decay_irf
export fit_global, das
export fit_peaks, find_peaks, fit_ta_spectrum
export predict, predict_peak, predict_baseline, residuals
export report, format_results, n_exp, anharmonicity
# CurveFit / CurveFitModels re-exports
export NonlinearCurveFitProblem, solve, coef, stderror, confint
export isconverged, mse, rss, nobs, weights
export lorentzian, gaussian, pseudo_voigt, single_exponential
# Baseline
export als_baseline, arpls_baseline, snip_baseline
export correct_baseline
# Spectroscopy utilities
export normalize, normalize_intensity, smooth_data, calc_fwhm
export transmittance_to_absorbance, absorbance_to_transmittance
export subtract_spectrum
export time_index, peak_table
export irf_fwhm, pulse_fwhm
# Data interface
export xdata, ydata, zdata, xlabel, ylabel, zlabel
export is_matrix, source_file, npoints, title
export xaxis, xaxis_label
# Semantic accessors (from SpectroscopyTools)
export delay, signal, wavenumber, wavelength
# Semantic accessors (QPSTools-specific)
export shift
export absorbance, transmittance, reflectance, ykind
# Units
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

# eLabFTW integration
include("elabftw.jl")
export configure_elabftw, elabftw_enabled, disable_elabftw, enable_elabftw
export test_connection
export clear_elabftw_cache, elabftw_cache_info
export create_experiment, create_from_template
export update_experiment, upload_to_experiment
export tag_experiment, get_experiment, delete_experiment
export list_experiments, search_experiments, print_experiments
export delete_experiments, tag_experiments, update_experiments
export add_step, list_steps, finish_step, link_experiments
export log_to_elab, tags_from_sample

# FTIR loading and analysis
include("ftir.jl")
export FTIRSpectrum, FTIRFitResult
export load_ftir, plot_ftir
export xreversed

# Raman loading and analysis
include("raman.jl")
export RamanSpectrum
export load_raman, plot_raman

# Cavity spectroscopy analysis
include("cavity.jl")
export CavitySpectrum, CavityFitResult, DispersionFitResult
export load_cavity, plot_cavity
export fit_cavity_spectrum, fit_dispersion
export compute_cavity_transmittance
export cavity_mode_energy, polariton_branches, polariton_eigenvalues
export hopfield_coefficients
export refractive_index, extinction_coeff

# PL mapping (CCD raster scans — loader only, type lives in SpectroscopyTools)
include("plmap.jl")
export load_pl_map, extract_spectrum, peak_centers, intensity

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

# Chirp correction (re-export from SpectroscopyTools)
export ChirpCalibration
export detect_chirp, correct_chirp, subtract_background
export save_chirp, load_chirp

# Plotting: themes, layers, layouts, and public API
include("plotting/themes.jl")
include("plotting/layers.jl")
include("plotting/plot_spectrum.jl")
include("plotting/plot_kinetics.jl")
include("plotting/plot_chirp.jl")
include("plotting/plot_das.jl")
include("plotting/plot_cavity.jl")
include("plotting/plot_plmap.jl")
export qps_theme
export print_theme, poster_theme
export lab_colors, lab_linewidths
export setup_poster_plot
export plot_spectrum, plot_kinetics
export plot_ta_heatmap, plot_spectra  # TAMatrix plotting
export plot_data  # Generic plotting via interface
export plot_peak_decomposition!, plot_peaks!  # Layer functions for existing axes
export plot_comparison, plot_waterfall  # Multi-spectrum views
export plot_chirp, plot_chirp!  # Chirp diagnostic visualization
export plot_das, plot_das!  # Decay-associated spectra
export plot_dispersion, plot_dispersion!  # Polariton dispersion
export plot_hopfield, plot_hopfield!  # Hopfield coefficients
export plot_pl_map, plot_pl_spectra  # PL spatial mapping

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
