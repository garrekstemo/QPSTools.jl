# Raman Exploration
#
# Runnable version of bootstrap/templates/explore_raman.jl with real data.
# Step through in the REPL to interactively explore your spectrum.
#
# Ref: bootstrap/templates/explore_raman.jl

using QPSTools, GLMakie

PROJECT_ROOT = dirname(@__DIR__)
set_theme!(qps_theme())

# ─────────────────────────────────────────────────────────────────────
# 1. Load
# ─────────────────────────────────────────────────────────────────────

spec = load_raman(joinpath(PROJECT_ROOT, "data", "raman", "MoSe2", "MoSe2-center.csv");
    material="MoSe2", sample="center")

# ─────────────────────────────────────────────────────────────────────
# 2. Fit a region
# ─────────────────────────────────────────────────────────────────────

region = (225, 260)   # A₁g
result = fit_peaks(spec, region; model=lorentzian, n_peaks=1, baseline_order=1)
report(result)

# ─────────────────────────────────────────────────────────────────────
# 3. Plot fit with residuals
# ─────────────────────────────────────────────────────────────────────

fig, ax_ctx, ax_fit, ax_res = plot_raman(spec; fit=result, context=true, residuals=true)
display(fig)
DataInspector()
