"""
# QPSTools.jl — QPS Laboratory Integration Layer

Lab-specific glue for the QPS spectroscopy ecosystem. QPSTools defines:

- LabVIEW pump-probe loaders (`load_ta_trace`, `load_ta_spectrum`, `load_ta_matrix`, `load_lvm`, `load_pl_map`)
- Cavity polariton spectroscopy (`CavitySpectrum`, `fit_cavity_spectrum`, `fit_dispersion`)
- Makie plotting themes and layouts (`plot_spectrum`, `plot_kinetics`, `plot_cavity`, …)
- eLabFTW provenance (`log_to_elab`, `tags_from_sample` dispatched on `AnnotatedSpectrum`)

`using QPSTools` brings in only names QPSTools itself defines. General-purpose
spectroscopy lives in the sibling packages — load them alongside:

```julia
using QPSTools
using SpectroscopyTools  # types, fitting, baseline, peak detection
using JASCOFiles         # JASCOSpectrum + isftir/israman/isuvvis
using ElabFTW            # eLabFTW CRUD
```

Method dispatch threads the layers together.
"""
module QPSTools

using Statistics
using LinearAlgebra
using Dates
using JASCOFiles
using Makie

using SpectroscopyTools
using ElabFTW

# Functions extended with new method dispatches in this package
import SpectroscopyTools: find_peaks, fit_peaks
import SpectroscopyTools: transmittance_to_absorbance, absorbance_to_transmittance
import SpectroscopyTools: subtract_spectrum, correct_baseline
import SpectroscopyTools: xdata, ydata, xlabel, ylabel, source_file, wavenumber
import SpectroscopyTools: savitzky_golay_smooth, derivative
import SpectroscopyTools: band_area, normalize_area, normalize_to_peak, estimate_snr
import SpectroscopyTools: average_spectra
import SpectroscopyTools: dielectric_real, dielectric_imag
import ElabFTW: tags_from_sample, log_to_elab

# ============================================================================
# Source files
# ============================================================================

include("types.jl")
include("io.jl")
include("elabftw_glue.jl")
include("cavity.jl")
include("plmap.jl")
include("spectroscopy.jl")
include("peakdetection.jl")
include("peakfitting.jl")

include("plotting/themes.jl")
include("plotting/layers.jl")
include("plotting/plot_spectrum.jl")
include("plotting/plot_kinetics.jl")
include("plotting/plot_chirp.jl")
include("plotting/plot_das.jl")
include("plotting/plot_cavity.jl")
include("plotting/plot_plmap.jl")

# ============================================================================
# Exports
# ============================================================================

# Types
export AnnotatedSpectrum
export AxisType, time_axis, wavelength_axis
export PumpProbeData

# Loaders
export load_spectroscopy
export load_ta_trace, load_ta_spectrum, load_ta_matrix
export load_lvm
export load_pl_map, load_wavelength_file
export find_peak_time
export load_cavity

# Cavity types and analysis
export CavitySpectrum, CavityFitResult, DispersionFitResult
export fit_cavity_spectrum, fit_dispersion
export compute_cavity_transmittance, cavity_transmittance
export cavity_mode_energy, polariton_branches, polariton_eigenvalues
export hopfield_coefficients
export refractive_index, extinction_coeff

# Plotting
export plot_spectrum, plot_kinetics
export plot_cavity
export plot_ta_heatmap, plot_spectra
export plot_data
export plot_peak_decomposition!, plot_peaks!
export plot_comparison, plot_waterfall
export plot_chirp, plot_chirp!
export plot_das, plot_das!
export plot_dispersion, plot_dispersion!
export plot_hopfield, plot_hopfield!
export plot_pl_map, plot_pl_spectra

# Themes
export qps_theme, print_theme, poster_theme
export lab_colors, lab_linewidths
export setup_poster_plot

# Accessors
export xreversed, xaxis, xaxis_label

end # module QPSTools
