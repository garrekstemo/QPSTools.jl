# FTIR Analysis Example
#
# Demonstrates the FTIR loading, labeling, fitting, and plotting API.
# Run from project root: julia --project=. examples/ftir_analysis.jl

using QPSTools
using CairoMakie

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
    fig, ax = plot_spectrum(spec_i; peaks=peaks)
    save("figures/EXAMPLES/ftir/ftir_labeled_$(s.label).pdf", fig)
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

fig, ax, ax_res = plot_spectrum(spec; fit=result, residuals=true)
save("figures/EXAMPLES/ftir/ftir_fit.pdf", fig)

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

println("\nFigures saved to figures/EXAMPLES/ftir/")

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
#     attachments = ["figures/EXAMPLES/ftir/ftir_fit.pdf"],
#     tags = ["ftir", "nh4scn", "cn_stretch"]
# )
