# Broadband Transient Absorption Analysis
#
# Step-by-step workflow for CCD-based broadband TA data:
#   1. Load the raw 2D matrix (time × wavelength)
#   2. Inspect the raw data (heatmap + spectra at key time delays)
#   3. Subtract pre-pump background
#   4. Detect and correct chirp (GVD)
#   5. Extract single-wavelength kinetics and fit
#   6. Global multi-exponential fit → decay-associated spectra (DAS)
#
# This example uses the CCD test data shipped with QPSTools.

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(dirname(@__DIR__))
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "broadband_ta")
mkpath(FIGDIR)

# ============================================================================
# STEP 1: LOAD RAW DATA
# ============================================================================
# Broadband TA data from a CCD detector comes as three files:
#   - time_axis.txt       (delay stage positions → time in fs or ps)
#   - wavelength_axis.txt (CCD pixel positions → wavelength in nm)
#   - ta_matrix.lvm       (2D ΔA signal, rows = time, columns = wavelength)

data_dir = joinpath(PROJECT_ROOT, "data", "CCD")
raw = load_ta_matrix(data_dir;
    time_file="time_axis.txt",
    wavelength_file="wavelength_axis.txt",
    data_file="ta_matrix.lvm",
    time_unit=:fs)

println("=== Raw Data ===")
println(raw)

# ============================================================================
# STEP 2: INSPECT RAW DATA
# ============================================================================
# Always look at raw data before processing.

# 2a. Heatmap overview
fig_raw, ax_raw, hm_raw = plot_ta_heatmap(raw; title="Raw ΔA")
save(joinpath(FIGDIR, "01_raw_heatmap.png"), fig_raw)

# 2b. Spectra at selected time delays
fig_spec, ax_spec = plot_spectra(raw; t=[-0.5, 0.0, 0.5, 1.0, 3.0],
    title="Raw Spectra")
save(joinpath(FIGDIR, "02_raw_spectra.png"), fig_spec)

# 2c. Kinetics at a few wavelengths
fig_kin, ax_kin = plot_kinetics(raw; λ=[550, 600, 650],
    title="Raw Kinetics")
save(joinpath(FIGDIR, "03_raw_kinetics.png"), fig_kin)

# ============================================================================
# STEP 3: SUBTRACT PRE-PUMP BACKGROUND
# ============================================================================
# Removes the average signal before pump arrival (baseline drift, scatter).
# Auto-detects the baseline region if t_range is not specified.

matrix_bg = subtract_background(raw)

fig_bg, ax_bg, hm_bg = plot_ta_heatmap(matrix_bg; title="Background-Subtracted")
save(joinpath(FIGDIR, "04_bg_subtracted.png"), fig_bg)

# ============================================================================
# STEP 4: CHIRP CORRECTION
# ============================================================================
# Group velocity dispersion (GVD) causes time-zero to vary with wavelength.
# detect_chirp fits a polynomial to the wavelength-dependent onset.
# correct_chirp shifts each wavelength column to align time-zero.

# 4a. Detect chirp
cal = detect_chirp(matrix_bg; order=3)

println("\n=== Chirp Calibration ===")
report(cal)

# 4b. Diagnostic plot: heatmap with chirp curve overlaid
fig_chirp, ax_chirp = plot_chirp(matrix_bg, cal)
save(joinpath(FIGDIR, "05_chirp_detection.png"), fig_chirp)

# 4c. Apply correction
corrected = correct_chirp(matrix_bg, cal)

fig_corr, ax_corr, hm_corr = plot_ta_heatmap(corrected; title="Chirp-Corrected")
save(joinpath(FIGDIR, "06_chirp_corrected.png"), fig_corr)

# 4d. Save calibration for reuse (optional)
save_chirp(joinpath(FIGDIR, "chirp_calibration.json"), cal)

# To reload later:
#   cal = load_chirp("chirp_calibration.json")
#   corrected = correct_chirp(matrix_bg, cal)

# ============================================================================
# STEP 5: SINGLE-WAVELENGTH KINETICS
# ============================================================================
# Extract a kinetic trace at a specific wavelength and fit an exponential decay.

trace = corrected[λ=600]
result = fit_exp_decay(trace; irf_width=0.15)

println("\n=== Kinetics at 600 nm ===")
report(result)

fig_fit, ax_fit, ax_res = plot_kinetics(trace; fit=result, residuals=true,
    title="λ = $(round(trace.wavelength, digits=0)) nm")
save(joinpath(FIGDIR, "07_kinetics_600nm.png"), fig_fit)

# ============================================================================
# STEP 6: GLOBAL FIT + DECAY-ASSOCIATED SPECTRA
# ============================================================================
# Fit all wavelengths simultaneously with shared time constants.
# DAS reveals which spectral regions are associated with each decay component.
#
# Tip: fitting every CCD pixel (2048) is slow and noisy pixels hurt the fit.
# Select a wavelength range covering the signal region.

λ_select = collect(520:5:700)
result_global = fit_global(corrected; n_exp=2, λ=λ_select)

println("\n=== Global Fit (2-component) ===")
report(result_global)

# Decay-associated spectra
fig_das, ax_das = plot_das(result_global)
save(joinpath(FIGDIR, "08_das.png"), fig_das)

# ============================================================================
# SUMMARY
# ============================================================================

println("\nFigures saved to $FIGDIR")
println("  01_raw_heatmap.png      — raw ΔA heatmap")
println("  02_raw_spectra.png      — spectra at selected time delays")
println("  03_raw_kinetics.png     — kinetics at selected wavelengths")
println("  04_bg_subtracted.png    — after background subtraction")
println("  05_chirp_detection.png  — chirp polynomial overlaid on heatmap")
println("  06_chirp_corrected.png  — after chirp correction")
println("  07_kinetics_600nm.png   — single-wavelength fit + residuals")
println("  08_das.png              — decay-associated spectra")
