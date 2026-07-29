# QPSTools.jl — QPS Lab Integration Layer

Private lab-specific glue layer of the spectroscopy ecosystem (see global CLAUDE.md for the models→analysis→lab map). General-purpose spectroscopy lives in the sibling packages; QPSTools owns only lab-side loaders, Makie themes/plots, and eLabFTW provenance glue.

## Status

Pre-ship (unregistered). Breaking changes to APIs, struct fields, and signatures are fine — prioritize clean design over legacy compatibility.

## Scope

- **Pump-probe loaders** (LabVIEW LVM) — TA traces/spectra/matrices, PL maps, wavelength files
- **Steady-state loader**: `load_spectrum` → token-stamped OpticalSpectroscopy `Spectrum` (FTIR/Raman/UV-Vis/cavity transmission). This replaced the old `load_cavity`/`CavitySpectrum` pair, which no longer exist. (`load_spectroscopy` is a separate auto-detect entry point.)
- **Streak PL**: `load_streak_pl` → `StreakPL` (wraps HamamatsuStreakFiles' `StreakImage`); `TimeResolvedMatrix(::StreakPL)` transposes to time × wavelength, sorts λ ascending, maps display metadata for downstream slicing/binning/cosmic-ray/decay-fitting.
- **Makie plots/themes** — `plot_*` recipes and lab themes (see `src/plotting/`)

`using QPSTools` brings in only names QPSTools defines. Students load siblings alongside (`OpticalSpectroscopy`, `JASCOFiles`, `HamamatsuStreakFiles`, `ElabFTW`).

## Cavity / polariton

QPSTools' `src/cavity.jl` holds **only lab accessors** over the generic `Spectrum` (`sample_metadata`, `xreversed`, `_sample_title`). All cavity/polariton numerics — `fit_cavity_spectrum(::Spectrum)` (reads `:cavity_length` and `:yunit` tokens), `fit_dispersion`, `polariton_branches`, `hopfield_coefficients` — live in **OpticalSpectroscopy.jl** (its `src/cavity.jl`) and reach lab users via `using OpticalSpectroscopy` (not re-exported). `load_spectrum`'s `cavity_length` kwarg is promoted to the `:cavity_length` token so that dispatch can find it.

## eLabFTW glue (weakdep extension)

`ElabFTW` is a **weak dependency**. The typed `log_to_elab` / `tags_from_sample` dispatches for `Spectrum` and `StreakPL` live in `ext/QPSToolsElabFTWExt.jl` and load only under `using ElabFTW`. The extension is the blessed home for this join (ElabFTW knows nothing of spectra; OpticalSpectroscopy knows nothing of eLabFTW) — keeps it out of type-piracy territory.

## The `load_scan` exception

`load_scan` is **QPSTools' own** function (`src/scan_loading.jl`): a typed wrapper over `QPSScanFormat.load_scan`. The format layer returns `Loaded*` results carrying plain NamedTuple data (no analysis deps); QPSTools rebuilds them with OpticalSpectroscopy types (`KineticTrace`, `Spectrum`, `TimeResolvedMatrix`, `SweepData`) so results feed `fit_*`/`plot_*` directly.

- **`import QPSScanFormat`, NOT `using`** — both export `load_scan` and the bindings clash. QPSTools owns that binding; use the `QPSScanFormat.` prefix for qualified writer/schema access.
- The `Loaded*` types (`LoadedScanResult`, `LoadedSpectralResult`, `LoadedCompositeResult`, `LoadedNoiseResult`) and `update_scan_description!` / `update_scan_comment!` / `update_scan_sample_name!` are re-exported from QPSScanFormat — the documented exception to the no-sibling-re-export rule.

## Examples environment

`examples/` has its own env (`examples/Project.toml`) with deps NOT in root: `CairoMakie`, `GLMakie`, `FileIO`, `CurveFit`, `CurveFitModels`, `Revise`. Root QPSTools depends only on abstract `Makie`; students load the backend themselves. Do NOT add these to root `Project.toml`.

## Figure output

Figures save to `figures/` subfolders (`figures/EXAMPLES/` for example-script output). Never save to project root or alongside scripts. PNG for saved output, PDF for publication.

## Measurement data

Data lives outside the repo, under `~/Data`, one folder per technique (`CCD`, `MIRpumpprobe`, `ftir`, `raman`, `uvvis`, `xrd`). Nothing measured belongs in version control.

Tests that read real files go through `datapath(...)` from `test/testsetup.jl`, which resolves against `$QPSTOOLS_DATA` (default `~/Data`), and guard themselves with `has_data(...)` so they run wherever the data is present and skip everywhere else. CI therefore exercises only the synthetic fixtures — a loader regression against a real instrument file shows up when you run the suite locally, not on GitHub.

## Layout

Entry point: `src/QPSTools.jl` (imports, includes, exports). Loaders in `src/io.jl` / `scan_loading.jl` / `streak.jl` / `plmap.jl`; lab accessors in `cavity.jl`; raw types (`AxisType`, `PumpProbeData`) in `types.jl`; plots under `src/plotting/`. Browse `src/` for the rest.
