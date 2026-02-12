# FTIR Analysis Example
#
# Demonstrates the FTIR loading, labeling, fitting, and plotting API.

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(@__DIR__)
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "ftir")
mkpath(FIGDIR)
set_data_dir(joinpath(PROJECT_ROOT, "data"))

# =============================================================================
# 1. Label all peaks for each molecule
# =============================================================================

samples = [
    (label="NH4SCN",  kw=(solute="NH4SCN", concentration="1.0M")),
    (label="DMF",     kw=(material="DMF",)),
    (label="DPPA",    kw=(solute="DPPA",)),
]

for s in samples
    spec_i = load_ftir(; s.kw...)
    peaks = find_peaks(spec_i)
    fig, ax = plot_ftir(spec_i; peaks=peaks)
    save(joinpath(FIGDIR, "ftir_labeled_$(s.label).png"), fig)
    println("$(s.label): $(length(peaks)) peaks detected")
end
println()

# Use NH4SCN for the rest of the analysis
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# =============================================================================
# 2. Fit the CN stretch
# =============================================================================

result = fit_peaks(spec, (1950, 2150))
pk = result[1]

println()
report(result)

fig, ax, ax_res = plot_ftir(spec; fit=result, residuals=true)
save(joinpath(FIGDIR, "ftir_fit.png"), fig)

peaks = find_peaks(spec)
fig, ax_ctx, ax_fit, ax_res = plot_ftir(spec; fit=result, context=true, peaks=peaks)
save(joinpath(FIGDIR, "ftir_context.png"), fig)

# =============================================================================
# 3. Background subtraction
# =============================================================================

ref = load_ftir(material="DMF")
corrected = subtract_spectrum(spec, ref)

result_sub = fit_peaks(corrected, (1950, 2150))
pk_sub = result_sub[1]

println()
report(result_sub)

# =============================================================================
# 4. Model comparison (Lorentzian vs Gaussian)
# =============================================================================

result_g = fit_peaks(spec, (1950, 2150); model=gaussian)
pk_g = result_g[1]

println("\n=== Model Comparison ===")
report(result)
report(result_g)

println("\nFigures saved to $FIGDIR")

# =============================================================================
# 5. Log to eLabFTW (optional)
# =============================================================================

# Uncomment to log results to your lab notebook:
#
# log_to_elab(
#     title = "FTIR: NH4SCN CN stretch analysis",
#     body = """
# ## Sample
# 1M NH₄SCN in DMF
#
# ## Analysis
# - Peak detection and labeling
# - Lorentzian fit to CN stretch (1950-2150 cm⁻¹)
# - Background subtraction using pure DMF reference
#
# $(format_results(result))
# """,
#     attachments = [joinpath(FIGDIR, "ftir_fit.png")],
#     tags = ["ftir", "nh4scn", "cn_stretch"]
# )
