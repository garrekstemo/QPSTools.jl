# QPS.jl TODO

## In Progress

### Multi-Peak Fitting (FTIR + Raman) ✓
- [x] Multi-peak fitting for overlapping peaks (both FTIR and Raman)
- [x] Auto-detect peaks via `find_peaks()` → initial guesses for multi-peak fit
- [x] `fit_peaks(spec, region; model, n_peaks)` — generic multi-peak fitting
- [x] Plotting: overlay individual peak components on composite fit
- See `notes/raman_automation_proposal.md` for original Raman proposal

### Unified TA API (Single-Pixel + White-Light)

Unified API for transient absorption — same functions work for both detector types.
See `notes/unified_ta_api_plan.md` for full design.

**Phase 1: Core types + single-trace** ✓
- [x] Define `TATrace` struct
- [x] Implement `load_ta_trace`, return `TATrace` (kept `load_lvm` for raw access)
- [x] Implement `fit_exp_decay(::TATrace)` with IRF
- [x] Implement `plot_kinetics(::TATrace)`
- [x] Update example script

**Phase 2: Multi-exponential** ✓
- [x] Add `n_exp` parameter to `fit_exp_decay`
- [x] `MultiexpDecayFit` result type for n>1 exponentials
- [x] Derived properties: `n_exp(fit)`, `weights(fit)`
- [x] `predict()` for `MultiexpDecayFit``
- [x] Plotting support via `TAFitResult` union

**Phase 3: TAMatrix basics** ✓
- [x] Define `TAMatrix` struct with indexing (`matrix[λ=800]`, `matrix[t=1.0]`)
- [x] Implement `load_ta_matrix` for LVM/TXT/CSV formats
- [x] Extraction: `matrix[λ=...]` → `TATrace`, `matrix[t=...]` → `TASpectrum`
- [x] Implement `plot_ta_heatmap`, `plot_kinetics(::TAMatrix; λ=[...])`, `plot_spectra(::TAMatrix; t=[...])`

**Phase 4: Global analysis**
- [ ] Implement `fit_global(::TAMatrix; n_exp)`
- [ ] `GlobalFitResult` with DAS extraction
- [ ] `plot_das()`

**Phase 5: Preprocessing**
- [ ] `correct_chirp()` — automatic + saved calibration
- [ ] `svd_filter()` — noise reduction
- [ ] `subtract_background()` — works for both types

**Error estimation:**
- [ ] Covariance matrix (default, fast)
- [ ] Bootstrap (optional, `errors=:bootstrap`)

### Registry System
- [x] eLabFTW read-only integration (query by metadata) — `src/elabftw.jl`
- [x] Hybrid mode with local cache — `set_registry_backend(:hybrid)`
- [ ] eLabFTW write integration (upload results)
- [ ] eLabFTW item templates for Raman/FTIR

### Unitful.jl Integration
- [x] `parse_concentration("1.0M")` → `1.0u"mol/L"`
- [x] `parse_time("500fs")` → `500.0u"fs"` (for pump-probe)
- [x] Spectroscopy conversions: `wavenumber_to_wavelength`, `wavelength_to_wavenumber`
- [x] Energy conversions: `wavenumber_to_energy`, `wavelength_to_energy`, `energy_to_wavelength`
- [x] Test cases: M, mM, μM, nM, pM, mol/L conversions
- [x] Test edge cases: invalid strings, whitespace handling, Unicode μ/u

## Testing

- [ ] Test `subtract_spectrum` grid mismatch detection
  - [ ] Mismatched lengths → clear error with `interpolate=true` hint
  - [ ] Misaligned x-values (>0.01 cm⁻¹) → clear error with hint
  - [ ] Matching grids → no error, direct subtraction
  - [ ] `interpolate=true` with mismatched grids → works correctly

## Planned

- [ ] Documentation for IRF convolution model and FWHM calculations (irf_fwhm, pulse_fwhm)
- [ ] Document Makie heatmap matrix orientation gotcha
  - `heatmap(x, y, z)` expects `z` to be `(length(x), length(y))`
  - First dimension of matrix → first axis argument
  - Common mistake: data stored as `(time, wavelength)` but plotting `heatmap(wavelength, time, data)` requires transpose
  - Add to CLAUDE.md Makie section and/or create a "Common Pitfalls" doc
- [ ] Add support for fluorescence spectroscopy
- [ ] Batch processing for multiple files
- [ ] UV-vis spectroscopy module (`load_uvvis()`, `plot_uvvis()`)

## Wishlist

- [ ] Monte Carlo error estimation for fitting parameters
  - Add noise to data, refit many times, get error distribution
  - Useful for error propagation in derived quantities
  - Could apply to: peak fitting, decay fitting, global analysis

---

## Completed

- [x] Exponential decay fitting
- [x] IRF-convolved fitting
- [x] Pump-probe analysis pipeline
- [x] LVM file loading
- [x] FTIR loading via JASCOFiles.jl
- [x] `load_ftir()`, `search_ftir()`, `list_ftir()` — registry-based loading
- [x] `plot_ftir()` — full spectrum, peak fit, three-panel modes
- [x] `fit_ftir_peak()` — generic peak fitting with custom models
- [x] `PeakFitResult` — generic result type with parameter access
- [x] Raman module: `load_raman()`, `search_raman()`, `plot_raman()`, `fit_raman_peak()`
- [x] `AnnotatedSpectrum` abstract type for FTIR/Raman/UV-vis
- [x] `subtract_spectrum` with grid mismatch detection
- [x] `linear_baseline_correction()` — works for FTIR and Raman
- [x] Local JSON registry system
- [x] Advanced baseline correction (ALS, arPLS, SNIP) — `src/baseline.jl`
- [x] Automatic peak detection with `find_peaks()` — wraps Peaks.jl
- [x] `plot_peaks!()` with rotated frequency labels and smart positioning
- [x] `TAMatrix` type for 2D broadband TA data (time × wavelength)
- [x] `load_ta_matrix()` with auto-detection of axis and data files
- [x] `plot_ta_heatmap()`, `plot_spectra()` for TAMatrix visualization
