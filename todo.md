# QPSTools.jl TODO

## Active

### TA Phase 4: plot_das()
- [x] `plot_das(result::GlobalFitResult)` — decay-associated spectra visualization (Makie)

The fitting side (`fit_global(::TAMatrix; n_exp)`, multi-exp `GlobalFitResult`, DAS extraction) is a SpectroscopyTools task — see `SpectroscopyTools.jl/TODO.md` task 3.

### Housekeeping
- [x] Fix `fit_global` test: `result.tau` → `result.taus` (field was renamed)

### Documentation
- [x] IRF convolution model and FWHM calculations → `notes/irf_convolution_model.md`
- [x] Makie heatmap orientation gotcha → `notes/heatmap_orientation.md`

## Planned

- [ ] Fluorescence spectroscopy support
- [ ] Batch processing for multiple files
- [ ] UV-vis module (`load_uvvis()`, `plot_uvvis()`)
- [ ] Bootstrap error estimation (`errors=:bootstrap` for fitting functions)


## Completed

- [x] Multi-peak fitting (FTIR + Raman) with auto-detect via find_peaks()
- [x] TA Phases 1-3: TATrace, TAMatrix, multi-exponential, plotting
- [x] TA Phase 5: Chirp correction + background subtraction (moved to SpectroscopyTools)
- [x] Registry system (eLabFTW read + hybrid cache)
- [x] Unitful.jl integration (concentrations, time, spectroscopy conversions)
- [x] Exponential decay fitting with IRF convolution
- [x] Advanced baseline correction (ALS, arPLS, SNIP)
- [x] Automatic peak detection (find_peaks wrapping Peaks.jl)
- [x] Broadband TA loading with CCD/wavelength auto-detection
- [x] plot_chirp / plot_chirp! (Makie visualization for chirp calibration)
- [x] eLabFTW critical bug fixes (category, metadata, content_type, file handle)
- [x] eLabFTW workflow features (steps, links, templates, print_experiments, test_connection, docstring)
- [x] UUID regeneration + publication_theme → print_theme rename
- [x] 13 stale exports cleaned
