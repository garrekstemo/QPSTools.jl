# Raman Analysis
#
# Runnable version of starter/templates/raman_analysis.jl with real data.
# Produces publication-quality figures saved to figures/EXAMPLES/raman/.
#
# Ref: starter/templates/raman_analysis.jl
# See also: advanced/raman_comparison.jl for multi-position comparison.

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(@__DIR__)
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "raman")
mkpath(FIGDIR)

# =============================================================================
# 1. Load
# =============================================================================

spec = load_raman(joinpath(PROJECT_ROOT, "data", "raman", "MoSe2", "MoSe2-center.csv");
    material="MoSe2", sample="center")

# =============================================================================
# 2. Survey
# =============================================================================

fig, ax = plot_raman(spec)
save(joinpath(FIGDIR, "survey.png"), fig)

# =============================================================================
# 3. Peak detection
# =============================================================================

peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_raman(spec; peaks=peaks)
save(joinpath(FIGDIR, "peaks.png"), fig)

# =============================================================================
# 4. Fit the A₁g peak
# =============================================================================

result = fit_peaks(spec, (225, 260))
report(result)

# =============================================================================
# 5. Fit + residuals
# =============================================================================

fig, ax, ax_res = plot_raman(spec; fit=result, residuals=true)
save(joinpath(FIGDIR, "fit.png"), fig)

# =============================================================================
# 6. Three-panel context view
# =============================================================================

fig, ax_ctx, ax_fit, ax_res = plot_raman(spec; fit=result, context=true, peaks=peaks)
save(joinpath(FIGDIR, "context.png"), fig)

println("\nFigures saved to $FIGDIR")

# =============================================================================
# 7. Log to eLabFTW (optional)
# =============================================================================
# Uncomment to log results to your lab notebook.
# Requires ELABFTW_URL and ELABFTW_API_KEY environment variables.

#=
log_to_elab(spec, result;
    title = "Raman: MoSe2 A₁g peak fit",
    attachments = [joinpath(FIGDIR, "context.png")],
    extra_tags = ["peak_fit"]
)
=#
