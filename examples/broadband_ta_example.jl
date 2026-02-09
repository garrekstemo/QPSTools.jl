# Broadband Transient Absorption Example
#
# PB-film (perovskite) pump-probe experiment (251202)
# CCD camera: 151 time points × 2048 wavelengths (~467–733 nm)
#
# Pipeline: load → background subtraction → chirp detection → correction

using Revise
using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(@__DIR__)
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "broadband_ta")
mkpath(FIGDIR)

# ============================================================================
# PART 1: LOAD & BACKGROUND SUBTRACTION
# ============================================================================

DATA_ROOT = joinpath(PROJECT_ROOT, "data", "broadbandTA_experiment")

# CCD time axis: instrument step size 400.2769 fs, constructed from settings
dt_fs = 400.2769
time_fs = collect(-20000:dt_fs:(20400 + dt_fs * 50))
time_ps = time_fs ./ 1000

matrix = load_ta_matrix(DATA_ROOT;
    time=time_ps,
    data_file="CCDABS_251202_163329.lvm",
    wavelength_file="wavelength_reference.txt")

println(matrix)

fig, ax, hm = plot_ta_heatmap(matrix; title="Raw ΔA(t, λ)")
save(joinpath(FIGDIR, "01_raw_heatmap.png"), fig)

matrix_bg = subtract_background(matrix)

fig, ax, hm = plot_ta_heatmap(matrix_bg; title="Background-subtracted ΔA(t, λ)")
save(joinpath(FIGDIR, "02_background_subtracted.png"), fig)

# ============================================================================
# PART 2: CHIRP DETECTION — compare both methods
# ============================================================================
# bin_width=16 recommended for CCD data with many wavelength pixels.
# min_signal excludes bins with weak TA signal (default 0.2).
# See ?detect_chirp for all parameters.

cal_xcorr = detect_chirp(matrix_bg; bin_width=16, min_signal=0.19)
cal_threshold = detect_chirp(matrix_bg; method=:threshold, bin_width=16, min_signal=0.19)

println("\nxcorr:")
report(cal_xcorr)
println("\nthreshold:")
report(cal_threshold)

# ============================================================================
# PART 3: DIAGNOSTIC PLOTS & CORRECTION (using xcorr result)
# ============================================================================

fig, ax = plot_chirp(matrix_bg, cal_xcorr)
save(joinpath(FIGDIR, "03_chirp_detection.png"), fig)

matrix_corrected = correct_chirp(matrix_bg, cal_xcorr)

fig, ax, hm = plot_ta_heatmap(matrix_corrected; title="Chirp-corrected ΔA(t, λ)")
save(joinpath(FIGDIR, "04_chirp_corrected.png"), fig)

# ============================================================================
# PART 4: SAVE CALIBRATION
# ============================================================================

cal_path = joinpath(FIGDIR, "chirp_calibration.json")
save_chirp(cal_path, cal_xcorr)
println("\nSaved: $cal_path")
println("Done!")
