# plot_spectrum Views Reference
#
# Demonstrates every layout that plot_spectrum supports,
# from simplest to most complex.

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(dirname(@__DIR__))
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "views")
mkpath(FIGDIR)

# Load data and prepare all ingredients
spec = load_raman(joinpath(PROJECT_ROOT, "data", "raman", "MoSe2", "MoSe2-center.csv");
    material="MoSe2", sample="center")
peaks = find_peaks(spec)
fit = fit_peaks(spec, (225, 260))

# =============================================================================
# 1. Survey — just the spectrum
# =============================================================================
fig, ax = plot_raman(spec)
save(joinpath(FIGDIR, "1_survey.png"), fig)

# =============================================================================
# 2. Peaks — spectrum with peak markers
# =============================================================================
fig, ax = plot_raman(spec; peaks=peaks)
save(joinpath(FIGDIR, "2_peaks.png"), fig)

# =============================================================================
# 3. Fit — zoomed to fit region (scatter + fit + decomposition)
# =============================================================================
fig, ax = plot_raman(spec; fit=fit)
save(joinpath(FIGDIR, "3_fit.png"), fig)

# =============================================================================
# 4. Fit + peaks — full spectrum with fit overlaid in its region
# =============================================================================
fig, ax = plot_raman(spec; fit=fit, peaks=peaks)
save(joinpath(FIGDIR, "4_fit_peaks.png"), fig)

# =============================================================================
# 5. Fit + residuals — stacked (fit region + residuals below)
# =============================================================================
fig, ax, ax_res = plot_raman(spec; fit=fit, residuals=true)
save(joinpath(FIGDIR, "5_fit_residuals.png"), fig)

# =============================================================================
# 6. Fit + peaks + residuals — stacked, peaks filtered to fit region
# =============================================================================
fig, ax, ax_res = plot_raman(spec; fit=fit, peaks=peaks, residuals=true)
save(joinpath(FIGDIR, "6_fit_peaks_residuals.png"), fig)

# =============================================================================
# 7. Fit + context — three-panel (full spectrum, fit, residuals)
# =============================================================================
fig, ax_ctx, ax_fit, ax_res = plot_raman(spec; fit=fit, context=true)
save(joinpath(FIGDIR, "7_context.png"), fig)

# =============================================================================
# 8. Fit + context + peaks — three-panel with peaks on context panel
# =============================================================================
fig, ax_ctx, ax_fit, ax_res = plot_raman(spec; fit=fit, context=true, peaks=peaks)
save(joinpath(FIGDIR, "8_context_peaks.png"), fig)

println("All views saved to $FIGDIR")
