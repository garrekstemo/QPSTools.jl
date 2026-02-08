# QPS.jl Code Review — Pre-Testing Cleanup

Thorough review before writing tests. Working through each issue one at a time.

## Bugs

| # | File | Status | Summary |
|---|------|--------|---------|
| 1 | pumpprobe.jl:69 | DONE | `_exp_decay_irf_conv` undefined in QPS scope — deleted file |
| 2 | raman.jl:155-163 | DONE | `subtract` passes NamedTuple where JASCOSpectrum expected — fixed via shared `subtract` on `AnnotatedSpectrum` in types.jl |
| 3 | spectroscopy.jl:95-106 | DONE | `_is_percent_transmittance` dead logic — deleted function, hardcoded `percent=true` default since JASCO always records percent transmittance |

## Double work

| # | File | Status | Summary |
|---|------|--------|---------|
| 4 | ftir.jl:293-318, raman.jl:295-321 | DONE | `plot_ftir`/`plot_raman` fit data twice when `return_fit=true` — fixed via shared `_plot_annotated_spectrum` that computes fit once |

## Dead code / bloat

| # | File | Status | Summary |
|---|------|--------|---------|
| 5 | Project.toml:10-11 | DONE | Removed `FileIO` and `GLMakie`; replaced `CairoMakie` dep with abstract `Makie` so users choose their own backend |
| 6 | pumpprobe.jl:17-25 | DONE | `compute_signal` duplicates `_compute_signal` — deleted file |
| 7 | pumpprobe.jl:86-104 | DONE | `print_results` is pre-migration dead code — deleted file |
| 8 | pumpprobe.jl:33-39 | DONE | `process_pumpprobe` uses legacy API — deleted file |
| 9 | types.jl:40 | DONE | `FTIRFitResult` alias was missing definition — added `const FTIRFitResult = MultiPeakFitResult` |

## Code duplication

| # | Files | Status | Summary |
|---|-------|--------|---------|
| 10 | ftir.jl / raman.jl | DONE | ~200 lines of near-identical plotting, error, and loading helpers — deduplicated into shared `AnnotatedSpectrum` methods in types.jl and plotting.jl |
| 11 | peakfitting.jl:106-178 | DONE | Annotation block duplicated between simple and residuals plot — eliminated by unified plotting pipeline; `plot_peaks`/`_plot_peaks_simple`/`_plot_peaks_with_residuals` deleted, replaced by `_draw_peak_annotation!` layer |

## Style / convention violations

| # | File | Status | Summary |
|---|------|--------|---------|
| 12 | ftir.jl, raman.jl, peakfitting.jl | DONE | Hardcoded inline styling overrides themes — all plotting consolidated in plotting.jl via layer functions; no hardcoded fontsize/markersize/linewidth |
| 13 | plotting.jl:248-290 | DONE | `lab_colors()` / `lab_linewidths()` allocate Dict on every call — replaced with `const` module-level Dicts, functions now return the cached reference |
| 14 | pumpprobe.jl:33-39 | DONE | `process_pumpprobe` returns bare Tuple — deleted file |
| 15 | elabftw.jl:34-36 | DONE | Redundant `using` statements — removed `using HTTP, JSON, Dates` (already loaded at module level in QPS.jl) |
| 16 | peakfitting.jl:109,138,164 | DONE | Generic "X"/"Y" axis labels in `plot_peaks` — `plot_peaks` deleted; `plot_spectrum` now uses proper axis labels from dispatch (AnnotatedSpectrum, TASpectrum, or user-provided) |

## API concerns

| # | File | Status | Summary |
|---|------|--------|---------|
| 17 | QPS.jl:148 | DONE | `subtract` renamed to `subtract_spectrum` (extends SpectroscopyTools function) — no longer exports generic name |
| 18 | QPS.jl:82 | DEFERRED | `n_exp` vs `n_exponentials` confusion — removed `n_exponentials` re-export from QPS for now, but root fix requires reworking CurveFitModels/SpectroscopyTools boundary (models define functions, tools do analysis, QPS is lab-specific) |
| 19 | pumpprobe.jl (whole file) | DONE | Deleted entire file — all functions superseded by modern API |

## Future work

- **Rework CurveFitModels / SpectroscopyTools boundary**: Clean separation — CurveFitModels owns model functions (`n_exponentials`, `lorentzian`, etc.), SpectroscopyTools does analysis (`fit_exp_decay`, `fit_peaks`, etc.), QPS is lab-specific. Resolve `n_exp`/`n_exponentials` naming confusion as part of this.

- **Generalize AnnotatedSpectrum beyond JASCOSpectrum**: Currently `AnnotatedSpectrum` assumes `data::JASCOSpectrum`. To support XRD (Rigaku .txt files) and other instrument formats, make the contract more generic (keyed on having x/y data). The XRD example (`examples/xrd_analysis.jl`) currently uses a local `load_xrd` helper returning raw vectors — it could use the registry + AnnotatedSpectrum pattern instead.
