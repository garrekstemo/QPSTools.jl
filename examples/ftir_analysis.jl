# FTIR Analysis
#
# Runnable version of starter/templates/ftir_analysis.jl with real data.
# Produces publication-quality figures saved to figures/EXAMPLES/ftir/.
#
# Ref: starter/templates/ftir_analysis.jl

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(@__DIR__)
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "ftir")
mkpath(FIGDIR)

# =============================================================================
# 1. Load
# =============================================================================

spec = load_ftir(joinpath(PROJECT_ROOT, "data", "ftir", "1.0M_NH4SCN_DMF.csv");
    solute="NH4SCN", concentration="1.0M")

# =============================================================================
# 2. Survey
# =============================================================================

fig, ax = plot_ftir(spec)
save(joinpath(FIGDIR, "survey.png"), fig)

# =============================================================================
# 3. Peak detection
# =============================================================================

peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_ftir(spec; peaks=peaks)
save(joinpath(FIGDIR, "peaks.png"), fig)

# =============================================================================
# 4. Fit the CN stretch
# =============================================================================

result = fit_peaks(spec, (1950, 2150))
report(result)

# =============================================================================
# 5. Fit + residuals
# =============================================================================

fig, ax, ax_res = plot_ftir(spec; fit=result, residuals=true)
save(joinpath(FIGDIR, "fit.png"), fig)

# =============================================================================
# 6. Three-panel context view
# =============================================================================

fig, ax_ctx, ax_fit, ax_res = plot_ftir(spec; fit=result, context=true, peaks=peaks)
save(joinpath(FIGDIR, "context.png"), fig)

println("\nFigures saved to $FIGDIR")

# =============================================================================
# 7. Log to eLabFTW (optional)
# =============================================================================
# Uncomment to log results to your lab notebook.
# Requires ELABFTW_URL and ELABFTW_API_KEY environment variables.

#=
log_to_elab(spec, result;
    title = "FTIR: NH4SCN CN stretch fit",
    attachments = [joinpath(FIGDIR, "context.png")],
    extra_tags = ["peak_fit"]
)
=#
