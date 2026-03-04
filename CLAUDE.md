# QPSTools.jl — QPS Laboratory Analysis Package

## Status

**This package has not shipped yet.** Breaking changes to APIs, struct fields, and function signatures are acceptable. Prioritize clean, correct design over maintaining legacy interfaces.

## Package Dependencies

Compat policy follows global CLAUDE.md: let `Pkg.add()` auto-add lower bounds, don't remove them.

### Examples Environment

Examples have their own environment at `examples/Project.toml` with additional deps NOT in the main package. Students load the Makie backend themselves — QPSTools only depends on `Makie` (the abstract interface).

**Example-only deps** (do NOT add to root `Project.toml`): `CairoMakie`, `GLMakie`, `FileIO`, `CurveFit`, `CurveFitModels`, `Revise`

## Core Capabilities

### Transient Absorption
- `load_ta_spectrum()`, `load_ta_trace()`, `load_ta_matrix()` — load LabVIEW .lvm files
- `fit_exp_decay()` — single/biexponential with IRF deconvolution
- `fit_global()` — shared τ, σ, t₀ across traces

### Steady-State Spectroscopy
- `load_ftir()`, `load_raman()` — load JASCO CSV and LabVIEW files
- `fit_peaks()` — Gaussian, Lorentzian, Pseudo-Voigt via CurveFitModels.jl

### PL / Raman Mapping
- `PLMap`, `load_pl_map()` — 2D spatial grid with full CCD spectrum at each point
- `extract_spectrum()`, `subtract_background()`, `normalize_intensity()`

### eLabFTW Integration
- `log_to_elab()` — create experiments with formatted results and attachments
- `tags_from_sample()` — auto-extract tags from sample registry metadata
- `format_results()` — converts any fit result type to markdown table

### Plotting
- `plot_spectrum()`, `plot_kinetics()` — keyword-driven layouts (survey, fit, residuals, three-panel)
- `plot_ftir`, `plot_raman`, `plot_cavity` — convenience aliases for `plot_spectrum`
- `plot_comparison()`, `plot_waterfall()` — multi-spectrum views

## Figure Output Convention

All figures saved to `figures/` subfolders. `figures/EXAMPLES/` for example script output. Never save to project root or alongside scripts. PNG for saved output, PDF for publication (`manuscript/` figures only).

## Package Structure

```
src/
  QPSTools.jl      # Main module (includes and exports)
  types.jl         # Data structures for all spectroscopy types
  io.jl            # File loading (extensible for new formats)
  plotting.jl      # Makie plotting themes and utilities
  spectroscopy.jl  # General spectroscopy functions
  peakdetection.jl # Peak detection dispatches
  peakfitting.jl   # Peak fitting dispatches
  registry.jl      # Sample metadata registry
  elabftw.jl       # eLabFTW lab notebook integration
  ftir.jl          # FTIR loading and analysis
  raman.jl         # Raman loading and analysis
examples/          # Example scripts (own environment)
figures/           # Generated figures
data/              # Raw instrument data (gitignored)
notes/             # Lab transformation docs, planning notes
```
