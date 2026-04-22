# QPSTools.jl — QPS Lab Integration Layer

## Status

**This package has not shipped yet.** Breaking changes to APIs, struct fields, and function signatures are acceptable. Prioritize clean, correct design over maintaining legacy interfaces.

## Scope

QPSTools is the lab-specific integration layer for the QPS spectroscopy ecosystem. It owns:

- LabVIEW pump-probe loaders (`load_ta_trace`, `load_ta_spectrum`, `load_ta_matrix`, `load_lvm`, `load_pl_map`, `load_wavelength_file`)
- Cavity polariton spectroscopy (`CavitySpectrum`, `fit_cavity_spectrum`, `fit_dispersion`, polariton/Hopfield helpers)
- Makie themes and plot layouts (`plot_spectrum`, `plot_kinetics`, `plot_cavity`, `plot_ta_heatmap`, `plot_dispersion`, `plot_hopfield`, `plot_pl_map`, `print_theme`, `poster_theme`)
- eLabFTW provenance dispatches (`log_to_elab(::AnnotatedSpectrum, …)`, `tags_from_sample(::AnnotatedSpectrum)`)

General-purpose spectroscopy lives in sibling packages — load them alongside:

```julia
using QPSTools
using SpectroscopyTools  # types, fitting, baseline, peak detection
using JASCOFiles         # JASCOSpectrum + isftir/israman/isuvvis
using ElabFTW            # eLabFTW CRUD
```

`using QPSTools` brings in only names QPSTools itself defines. No sibling re-exports — method dispatch threads the layers together.

## Package Dependencies

Compat policy follows global CLAUDE.md: let `Pkg.add()` auto-add lower bounds, don't remove them.

### Examples Environment

Examples have their own environment at `examples/Project.toml` with additional deps NOT in the main package. Students load the Makie backend themselves — QPSTools only depends on `Makie` (the abstract interface).

**Example-only deps** (do NOT add to root `Project.toml`): `CairoMakie`, `GLMakie`, `FileIO`, `CurveFit`, `CurveFitModels`, `Revise`

## Figure Output Convention

All figures saved to `figures/` subfolders. `figures/EXAMPLES/` for example script output. Never save to project root or alongside scripts. PNG for saved output, PDF for publication (`manuscript/` figures only).

## Package Structure

```
src/
  QPSTools.jl         # Module: imports, includes, exports
  types.jl            # AnnotatedSpectrum, AxisType, PumpProbeData
  io.jl               # LVM/TA loaders, load_spectroscopy auto-detect
  spectroscopy.jl     # JASCOSpectrum/AnnotatedSpectrum dispatches, cavity_transmittance
  peakdetection.jl    # find_peaks(::AnnotatedSpectrum)
  peakfitting.jl      # fit_peaks(::AnnotatedSpectrum, …)
  cavity.jl           # CavitySpectrum, fit_cavity_spectrum, fit_dispersion, polariton physics
  plmap.jl            # load_pl_map, load_wavelength_file
  elabftw_glue.jl     # log_to_elab/tags_from_sample dispatches on AnnotatedSpectrum
  plotting/
    themes.jl         # qps_theme, print_theme, poster_theme, lab_colors, lab_linewidths
    layers.jl         # _draw_*! helpers, plot_peaks!, plot_peak_decomposition!
    plot_spectrum.jl  # plot_spectrum, plot_data, plot_comparison, plot_waterfall
    plot_kinetics.jl  # plot_kinetics, plot_ta_heatmap, plot_spectra
    plot_chirp.jl     # plot_chirp, plot_chirp!
    plot_das.jl       # plot_das, plot_das!
    plot_cavity.jl    # plot_dispersion, plot_hopfield (+ !-variants)
    plot_plmap.jl     # plot_pl_map, plot_pl_spectra
examples/             # Example scripts (own environment)
bootstrap/            # Student onboarding script + analysis templates
figures/              # Generated figures
data/                 # Raw instrument data (gitignored)
notes/                # Internal notes
```
