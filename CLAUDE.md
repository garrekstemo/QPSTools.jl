# QPSTools.jl — QPS Lab Integration Layer

## Status

**This package has not shipped yet.** Breaking changes to APIs, struct fields, and function signatures are acceptable. Prioritize clean, correct design over maintaining legacy interfaces.

## Scope

QPSTools is the lab-specific integration layer for the QPS spectroscopy ecosystem. It owns:

- LabVIEW pump-probe loaders (`load_ta_trace`, `load_ta_spectrum`, `load_ta_matrix`, `load_lvm`, `load_pl_map`, `load_wavelength_file`)
- Streak-camera PL wrapper (`load_streak_pl` → `StreakPL`, wrapping HamamatsuStreakFiles' `StreakImage`); converter `TimeResolvedMatrix(::StreakPL)` transposes to time × wavelength, sorts wavelength ascending, and maps display metadata for downstream slicing, binning, cosmic-ray removal, and decay fitting
- Lab-side cavity polariton layer: JASCO-backed `CavitySpectrum`, `load_cavity`, JASCO-aware `fit_cavity_spectrum` dispatch. The physics + fitting numerics live in [OpticalSpectroscopy.jl](https://github.com/garrekstemo/OpticalSpectroscopy.jl)'s cavity layer (no re-export — students load OpticalSpectroscopy alongside)
- Makie themes and plot layouts (`plot_spectrum`, `plot_kinetics`, `plot_ta_heatmap`, `plot_dispersion`, `plot_hopfield`, `plot_pl_map`, `plot_streak_pl`, `print_theme`, `poster_theme`)
- eLabFTW provenance dispatches (`log_to_elab(::AnnotatedSpectrum, …)`, `tags_from_sample(::AnnotatedSpectrum)`, ditto for `StreakPL`)

General-purpose spectroscopy lives in sibling packages — load them alongside:

```julia
using QPSTools
using OpticalSpectroscopy    # types, fitting, baseline, peak detection
using JASCOFiles             # JASCOSpectrum + isftir/israman/isuvvis
using HamamatsuStreakFiles   # StreakImage (raw streak-camera .img reader)
using ElabFTW                # eLabFTW CRUD
import QPSScanFormat         # writers (save_*_scan) + schema constants, qualified
```

`using QPSTools` brings in only names QPSTools itself defines, with one documented exception around scan files:

- **`load_scan` is QPSTools' own function** (`src/scan_loading.jl`): a typed wrapper over `QPSScanFormat.load_scan`. The format layer returns `Loaded*` results carrying plain NamedTuple data (it has no analysis dependencies); QPSTools rebuilds them with OpticalSpectroscopy types (`KineticTrace`, `TASpectrum`, `TimeResolvedMatrix`, `SweepData`) so results feed `fit_exp_decay`/`fit_peaks`/`plot_kinetics` directly.
- The `Loaded*` result types and `update_scan_description!`/`update_scan_comment!`/`update_scan_sample_name!` are re-exported from QPSScanFormat as a documented exception to the no-sibling-re-export rule.
- Do NOT blanket-`using QPSScanFormat` alongside QPSTools — both export a `load_scan` and the bindings clash. `import QPSScanFormat` for qualified writer/schema access.

Sibling re-export remains the exception, not the rule. Method dispatch threads the rest of the layers together.

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
  scan_loading.jl     # load_scan: typed wrapper over QPSScanFormat's plain-data reader
  spectroscopy.jl     # JASCOSpectrum/AnnotatedSpectrum dispatches
  peakdetection.jl    # find_peaks(::AnnotatedSpectrum)
  peakfitting.jl      # fit_peaks(::AnnotatedSpectrum, …)
  cavity.jl           # JASCO-backed CavitySpectrum + dispatches into OpticalSpectroscopy's cavity layer
  plmap.jl            # load_pl_map, load_wavelength_file
  streak.jl           # StreakPL, load_streak_pl (wraps HamamatsuStreakFiles)
  elabftw_glue.jl     # log_to_elab/tags_from_sample dispatches on AnnotatedSpectrum + StreakPL
  plotting/
    themes.jl         # qps_theme, print_theme, poster_theme, lab_colors, lab_linewidths
    layers.jl         # _draw_*! helpers, plot_peaks!, plot_peak_decomposition!
    plot_spectrum.jl  # plot_spectrum, plot_data, plot_comparison, plot_waterfall
    plot_kinetics.jl  # plot_kinetics, plot_ta_heatmap, plot_spectra
    plot_chirp.jl     # plot_chirp, plot_chirp!
    plot_das.jl       # plot_das, plot_das!
    plot_cavity.jl    # plot_dispersion, plot_hopfield (+ !-variants)
    plot_plmap.jl     # plot_pl_map, plot_pl_spectra
    plot_streak.jl    # plot_streak_pl
examples/             # Example scripts (own environment)
bootstrap/            # Student onboarding script + analysis templates
figures/              # Generated figures
data/                 # Raw instrument data (gitignored)
notes/                # Internal notes
```
