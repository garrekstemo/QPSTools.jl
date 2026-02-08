# Unified Transient Absorption API Plan

## Overview

Design a unified API for transient absorption spectroscopy that handles both:
- **Single-pixel detection** (single wavelength kinetics)
- **Broadband/white-light detection** (2D time × wavelength matrix)

The goal: same mental model, same function names — dispatch handles the details.

---

## Data Types

### TATrace (1D kinetics)

Single wavelength kinetic trace.

```julia
struct TATrace
    time::Vector{Float64}      # Time axis (ps)
    signal::Vector{Float64}    # ΔA signal
    wavelength::Float64        # Probe wavelength (nm or cm⁻¹), NaN if unknown
    metadata::Dict{Symbol,Any} # Timestamp, filename, mode, etc.
end
```

**Sources:**
- Loaded directly from single-pixel .lvm file
- Extracted from TAMatrix at specific wavelength

### TAMatrix (2D surface)

Broadband TA data.

```julia
struct TAMatrix
    time::Vector{Float64}       # Time axis (ps)
    wavelength::Vector{Float64} # Wavelength axis (nm or cm⁻¹)
    signal::Matrix{Float64}     # ΔA(time, wavelength)
    metadata::Dict{Symbol,Any}
end
```

**Indexing convenience:**
```julia
matrix[t=1.5]           # → spectrum at t ≈ 1.5 ps (returns vector)
matrix[λ=500]           # → kinetic trace at λ ≈ 500 nm (returns TATrace)
matrix[t=1.5, λ=500]    # → single ΔA value
```

---

## Loading Functions

| Function | Input | Output |
|----------|-------|--------|
| `load_ta_trace(file)` | .lvm (single-pixel) | `TATrace` |
| `load_ta_matrix(file)` | .csv, .dat (broadband) | `TAMatrix` |
| `load_ta(file)` | Any supported format | Auto-detect → `TATrace` or `TAMatrix` |

**Options:**
```julia
load_ta_trace(file;
    mode=:OD,           # :OD, :transmission, :diff
    channel=1           # For multi-channel detectors
)

load_ta_matrix(file;
    time_col=1,         # Column index or :auto
    wavelength_row=1,   # Row index or :auto
    transpose=false     # If data is wavelength × time
)
```

---

## Preprocessing Functions

All return new objects (immutable style).

### For TATrace

| Function | Description |
|----------|-------------|
| `subtract_background(trace; t_range)` | Subtract pre-t₀ baseline |
| `normalize(trace; mode=:max)` | Normalize by max, area, or value at t |
| `truncate(trace; t_range)` | Keep only specified time range |

### For TAMatrix

| Function | Description |
|----------|-------------|
| `subtract_background(matrix; t_range)` | Subtract pre-t₀ spectra |
| `correct_chirp(matrix; order=2)` | Polynomial chirp correction |
| `svd_filter(matrix; n_components=3)` | Noise reduction via truncated SVD |
| `truncate(matrix; t_range, λ_range)` | Crop to region of interest |

### Shared (dispatch on type)

```julia
subtract_background(data; t_range=(-1, -0.5))  # Works for both
truncate(data; t_range=(0, 100))               # Works for both
```

---

## Fitting Functions

### Core: `fit_exp_decay`

Fits exponential decay model with optional IRF convolution.

```julia
# Signature
fit_exp_decay(data; n_exp=1, irf=true, irf_width=0.1, t_range=nothing)

# For TATrace
result = fit_exp_decay(trace)
result = fit_exp_decay(trace; n_exp=2)  # Bi-exponential

# For TAMatrix (must specify wavelength)
result = fit_exp_decay(matrix; λ=500)
result = fit_exp_decay(matrix; λ=500, n_exp=2)
```

**Returns:** `ExpDecayFit`

```julia
struct ExpDecayFit
    τ::Vector{Float64}          # Time constants [τ₁, τ₂, ...]
    τ_err::Vector{Float64}      # Uncertainties
    amplitudes::Vector{Float64} # Pre-exponential factors
    offset::Float64
    irf_width::Float64          # σ of Gaussian IRF (NaN if irf=false)
    t0::Float64
    rsquared::Float64
    signal_type::Symbol         # :esa or :gsb
    residuals::Vector{Float64}
    # For reconstruction
    model::Function             # model(t) returns fitted curve
end
```

### Global: `fit_global`

Fits all wavelengths simultaneously with shared time constants.

```julia
# Only for TAMatrix
result = fit_global(matrix; n_exp=2, irf=true)
```

**Returns:** `GlobalFitResult`

```julia
struct GlobalFitResult
    τ::Vector{Float64}          # Shared time constants
    τ_err::Vector{Float64}
    das::Matrix{Float64}        # Decay-associated spectra (n_exp × n_wavelengths)
    wavelength::Vector{Float64} # Wavelength axis for DAS
    irf_width::Float64
    rsquared::Float64
    # For reconstruction
    model::Function             # model(t, λ) returns fitted surface
end
```

### Target: `fit_target` (future)

Fits kinetic model to extract species-associated spectra.

```julia
result = fit_target(matrix; model=:sequential)  # A → B → C
result = fit_target(matrix; model=:parallel)    # A → B, A → C
result = fit_target(matrix; model=custom_model) # User-defined
```

---

## Visualization Functions

### Plotting Kinetics

```julia
# Single trace
plot_kinetics(trace)
plot_kinetics(trace, fit_result)  # With fit overlay

# From matrix (extracts traces)
plot_kinetics(matrix; λ=[450, 500, 550])
plot_kinetics(matrix, global_result; λ=[450, 500, 550])
```

### Plotting Spectra

```julia
# Transient spectra at selected times
plot_spectra(matrix; t=[0.1, 1, 10, 100])

# DAS from global fit
plot_das(global_result)
```

### Plotting 2D Surface

```julia
plot_ta_heatmap(matrix)
plot_ta_heatmap(matrix;
    t_range=(0, 50),
    λ_range=(450, 650),
    colormap=:RdBu
)
```

---

## Convenience / High-Level Functions

For common workflows:

```julia
# One-liner for single trace
result = fit_ta(file; mode=:OD)
# Equivalent to: load_ta_trace(file; mode) |> fit_exp_decay

# One-liner for global analysis
result = fit_ta_global(file; n_exp=2, chirp_correct=true)
# Equivalent to: load_ta_matrix(file) |> correct_chirp |> fit_global
```

---

## File Format Support

| Format | Type | Notes |
|--------|------|-------|
| `.lvm` (stacked) | TATrace | Current MIR pump-probe format |
| `.csv` (2D) | TAMatrix | Common export format |
| `.dat` | TAMatrix | Some spectrometers |
| `.spe` | TAMatrix | Princeton Instruments (future) |

---

## Migration Path

### Current API → New API

| Current | New |
|---------|-----|
| `load_lvm(file)` | `load_ta_trace(file)` |
| `compute_signal(data; mode)` | Built into `load_ta_trace(; mode)` |
| `analyze_kinetics(file)` | `fit_ta(file)` or `fit_exp_decay(trace)` |
| `fit_decay_irf(t, signal)` | `fit_exp_decay(trace)` |

### Deprecation

Since we haven't shipped, no deprecation needed. Just rename and restructure.

---

## Implementation Order

### Phase 1: Core Types and Single-Trace
1. [ ] Define `TATrace` struct
2. [ ] Rename `load_lvm` → `load_ta_trace`, return `TATrace`
3. [ ] Implement `fit_exp_decay(::TATrace)`
4. [ ] Implement `plot_kinetics(::TATrace)`
5. [ ] Update example script

### Phase 2: Multi-Exponential
6. [ ] Add `n_exp` parameter to `fit_exp_decay`
7. [ ] Update `ExpDecayFit` for multiple τ values
8. [ ] Test bi-exponential fitting

### Phase 3: TAMatrix Basics
9. [ ] Define `TAMatrix` struct with indexing
10. [ ] Implement `load_ta_matrix` for CSV
11. [ ] Implement `fit_exp_decay(::TAMatrix; λ=...)` via extraction
12. [ ] Implement `plot_ta_heatmap`, `plot_kinetics(::TAMatrix)`

### Phase 4: Global Analysis
13. [ ] Implement `fit_global`
14. [ ] Implement `GlobalFitResult` and DAS extraction
15. [ ] Implement `plot_das`

### Phase 5: Preprocessing
16. [ ] `correct_chirp` for TAMatrix
17. [ ] `svd_filter` for TAMatrix
18. [ ] `subtract_background` for both types

---

## Design Decisions

| Question | Decision |
|----------|----------|
| Wavelength units | nm for visible, cm⁻¹ for MIR |
| Time units | ps everywhere |
| IRF model | Gaussian (sufficient for most cases) |
| Error estimation | Covariance (default, fast) + bootstrap (optional, rigorous) |
| Chirp correction | Automatic + saved calibration files |

### Chirp Correction Strategy

Chirp is instrument-dependent, not sample-dependent. Calibrate once, reuse:

```julia
# First time: measure chirp with a standard sample
chirp_params = calibrate_chirp(reference_matrix)
save_chirp("mir_setup_chirp.json", chirp_params)

# Every subsequent dataset
chirp = load_chirp("mir_setup_chirp.json")
corrected = correct_chirp(matrix, chirp)
```

### Error Estimation Strategy

```julia
# Default: covariance matrix (fast, from optimizer)
result = fit_exp_decay(trace)
result.τ_err  # ~instant

# Optional: bootstrap (for publication-quality uncertainties)
result = fit_exp_decay(trace; errors=:bootstrap, n_bootstrap=1000)
result.τ_err  # 95% CI from resampling
```
