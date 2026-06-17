"""
# QPSTools.jl — QPS Laboratory Integration Layer

Lab-specific glue for the QPS spectroscopy ecosystem. QPSTools defines:

- LabVIEW pump-probe loaders (`load_ta_trace`, `load_ta_spectrum`, `load_ta_matrix`, `load_lvm`, `load_pl_map`)
- Streak-camera PL loader (`load_streak_pl` → `StreakPL`)
- Steady-state spectrum loader (`load_spectrum` → token-stamped `Spectrum`) + cavity fitting (`fit_cavity_spectrum`, `fit_dispersion`)
- Makie plotting themes and layouts (`plot_spectrum`, `plot_kinetics`, `plot_dispersion`, …)
- eLabFTW provenance (`log_to_elab`, `tags_from_sample` dispatched on `Spectrum` and `StreakPL`)

`using QPSTools` brings in only names QPSTools itself defines. General-purpose
spectroscopy lives in the sibling packages — load them alongside:

```julia
using QPSTools
using OpticalSpectroscopy    # types, fitting, baseline, peak detection
using JASCOFiles             # JASCOSpectrum + isftir/israman/isuvvis
using HamamatsuStreakFiles   # StreakImage (raw streak .img reader)
using ElabFTW                # eLabFTW CRUD
```

Method dispatch threads the layers together.
"""
module QPSTools

using Statistics
using LinearAlgebra
using Dates
using JASCOFiles
using HamamatsuStreakFiles
using Makie

using OpticalSpectroscopy
using ElabFTW

# QPSScanFormat owns the canonical HDF5 scan-file reader/writer + Loaded*
# types, and returns PLAIN DATA (NamedTuples of vectors/matrices) — the
# format layer carries no analysis types. QPSTools defines its own
# `load_scan` (src/scan_loading.jl) that calls QPSScanFormat.load_scan and
# rebuilds the same Loaded* structs with OpticalSpectroscopy types
# (KineticTrace, Spectrum, TimeResolvedMatrix, SweepData), so the daily analysis entry
# point keeps yielding fit/plot-ready objects. The Loaded* types and the
# update_scan_*! helpers are re-exported as a documented exception to the
# no-sibling-re-export rule; writers + schema constants stay behind the
# `QPSScanFormat.` prefix. Note: `load_scan` is deliberately NOT brought
# into scope from QPSScanFormat — QPSTools owns that binding (don't
# blanket-`using QPSScanFormat` alongside QPSTools, or the two `load_scan`
# exports clash; `import QPSScanFormat` for qualified writer access).
using QPSScanFormat: QPSScanFormat,
    LoadedScanResult, LoadedSpectralResult, LoadedCompositeResult, LoadedNoiseResult,
    update_scan_description!, update_scan_comment!, update_scan_sample_name!

# Cavity physics + fitting live in OpticalSpectroscopy (its src/cavity.jl);
# the blanket `using OpticalSpectroscopy` above brings the polariton
# vocabulary into scope. QPSTools owns only the Spectrum-aware lab dispatch
# in src/cavity.jl (the cavity fit) and the load_spectrum loader (src/io.jl).
import OpticalSpectroscopy: fit_cavity_spectrum, fit_dispersion

# These accessors are exported by BOTH OpticalSpectroscopy and JASCOFiles, so a
# bare `using` leaves them ambiguous — they must be explicitly imported to make
# `xlabel`/`ylabel`/… resolve inside QPSTools (qualified as `QPSTools.xlabel` in
# the plotting layer, and called unqualified elsewhere).
import OpticalSpectroscopy: xdata, ydata, xlabel, ylabel, source_file

# tags_from_sample / log_to_elab gain Spectrum + StreakPL dispatches (src/elabftw_glue.jl).
# Everything QPSTools used to extend on the now-deleted CavitySpectrum/AnnotatedSpectrum
# (peak fitting, T↔A, baseline, spectral math) now lives on Spectrum in
# OpticalSpectroscopy and reaches lab users through `using OpticalSpectroscopy`.
import ElabFTW: tags_from_sample, log_to_elab

# ============================================================================
# Source files
# ============================================================================

include("types.jl")
include("io.jl")
include("scan_loading.jl")
include("streak.jl")
include("elabftw_glue.jl")
include("cavity.jl")
include("plmap.jl")

include("plotting/themes.jl")
include("plotting/layers.jl")
include("plotting/plot_spectrum.jl")
include("plotting/plot_kinetics.jl")
include("plotting/plot_chirp.jl")
include("plotting/plot_das.jl")
include("plotting/plot_cavity.jl")
include("plotting/plot_plmap.jl")
include("plotting/plot_streak.jl")

# ============================================================================
# Exports
# ============================================================================

# Types
export AxisType, time_axis, wavelength_axis
export PumpProbeData
export StreakPL

# Loaders
export load_spectroscopy
export load_ta_trace, load_ta_spectrum, load_ta_matrix
export load_lvm
export load_pl_map, load_wavelength_file, generate_wavelength_axis
export load_streak_pl
export find_peak_time
export load_spectrum

# QPSDrive scan-file reader. `load_scan` is QPSTools' own typed wrapper
# (src/scan_loading.jl) over QPSScanFormat's plain-data reader; the
# Loaded* types and update_scan_*! helpers are re-exported from
# QPSScanFormat (see using block above for the rationale behind this
# documented exception to the no-re-export rule). Writers and schema
# constants stay namespace-prefixed under `QPSScanFormat.`.
export load_scan
export LoadedScanResult, LoadedSpectralResult, LoadedCompositeResult, LoadedNoiseResult
export update_scan_description!, update_scan_comment!, update_scan_sample_name!

# Plotting
export plot_spectrum, plot_kinetics
export plot_ta_heatmap, plot_spectra
export plot_data
export plot_peak_decomposition!, plot_peaks!
export plot_comparison, plot_waterfall
export plot_chirp, plot_chirp!
export plot_das, plot_das!
export plot_dispersion, plot_dispersion!
export plot_hopfield, plot_hopfield!
export plot_pl_map, plot_pl_spectra
export plot_streak_pl

# Themes
export qps_theme, print_theme, poster_theme
export lab_colors, lab_linewidths
export setup_poster_plot

# Accessors
export xreversed

end # module QPSTools
