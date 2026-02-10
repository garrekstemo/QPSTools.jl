# QPSTools.jl TODO

## Active

### TA Phase 4: plot_das()
- [ ] `plot_das(result::GlobalFitResult)` — decay-associated spectra visualization (Makie)

The fitting side (`fit_global(::TAMatrix; n_exp)`, multi-exp `GlobalFitResult`, DAS extraction) is a SpectroscopyTools task — see `SpectroscopyTools.jl/TODO.md` task 3.

### eLabFTW Improvements
Priority 1 bugs all fixed (category, metadata encoding, content_type, file handle).

Remaining (from `notes/elabftw_review.md`):
- [ ] `add_step()` / `list_steps()` — analysis procedure tracking
- [ ] `link_experiments()` — connect related analyses
- [ ] `create_from_template()` — standardized experiment creation
- [ ] `print_experiments()` — clean table view for search results
- [ ] `test_connection()` — verify eLabFTW config
- [ ] Fix stale module docstring (says "read-only" but has full write API)

### Documentation
- [ ] IRF convolution model and FWHM calculations (irf_fwhm, pulse_fwhm)
- [ ] Makie heatmap orientation gotcha (already in CLAUDE.md, could be a standalone doc)

## Planned

- [ ] Fluorescence spectroscopy support
- [ ] Batch processing for multiple files
- [ ] UV-vis module (`load_uvvis()`, `plot_uvvis()`)
- [ ] Bootstrap error estimation (`errors=:bootstrap` for fitting functions)

## Deferred to SpectroscopyTools.jl

These items now live in `SpectroscopyTools.jl/TODO.md`:
- Chirp detection R² tuning on real CCD data
- SVD filter for TA matrix denoising (`svd_filter()`)
- Multi-exponential global analysis (`fit_global(::TAMatrix; n_exp)`, DAS extraction)

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
- [x] UUID regeneration + publication_theme → print_theme rename
- [x] 13 stale exports cleaned
