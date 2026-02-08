# eLabFTW Logging Example
#
# Demonstrates logging analysis results to eLabFTW as experiment entries.
# Run from project root: julia --project=. examples/elabftw_logging.jl
#
# Prerequisites:
#   1. A running eLabFTW instance
#   2. An API key (get from User Panel → API Keys in eLabFTW)
#   3. Set ELABFTW_URL and ELABFTW_API_KEY environment variables

using QPSTools
using CairoMakie

# =============================================================================
# 1. Configure eLabFTW
# =============================================================================

configure_elabftw(
    url = ENV["ELABFTW_URL"],
    api_key = ENV["ELABFTW_API_KEY"]
)

# =============================================================================
# 2. Load FTIR data and fit the CN stretch
# =============================================================================

spec = load_ftir(solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))

report(result)

# =============================================================================
# 3. Generate and save the figure
# =============================================================================

mkpath("figures/EXAMPLES/elabftw")
fig = plot_peaks(result; residuals=true)
save("figures/EXAMPLES/elabftw/cn_stretch_fit.pdf", fig)

# =============================================================================
# 4. Log to eLabFTW with auto-tags from registry
# =============================================================================

# The two-argument form auto-extracts tags from sample metadata:
#   - solute, solvent, concentration, substrate → become tags
#   - format_results(result) is appended to body automatically

id = log_to_elab(spec, result;
    title = "FTIR: NH4SCN CN stretch fit",
    body = "CN stretch region (2000-2100 cm⁻¹).",
    attachments = ["figures/EXAMPLES/elabftw/cn_stretch_fit.pdf"],
    extra_tags = ["ftir", "peak_fit"]  # Added to auto-extracted tags
)

println("\nExperiment ID: $id")

# You can also extract tags manually:
println("\n=== Auto-extracted tags ===")
println("  ", join(tags_from_sample(spec), ", "))

# =============================================================================
# 5. Search and list experiments
# =============================================================================

# List recent experiments
println("\n=== Recent experiments ===")
recent = list_experiments(limit=5)
for exp in recent
    println("  $(exp["id"]): $(exp["title"])")
end

# Search by tag
println("\n=== Experiments tagged 'ftir' ===")
ftir_exps = search_experiments(tags=["ftir"], limit=5)
for exp in ftir_exps
    println("  $(exp["id"]): $(exp["title"])")
end

# Full-text search
println("\n=== Search for 'NH4SCN' ===")
results = search_experiments(query="NH4SCN", limit=5)
for exp in results
    println("  $(exp["id"]): $(exp["title"])")
end

# =============================================================================
# 6. Manual logging (without auto-tags)
# =============================================================================

# If you don't have an AnnotatedSpectrum, use the basic form:
#
# log_to_elab(
#     title = "Manual experiment",
#     body = format_results(result),
#     attachments = ["figure.pdf"],
#     tags = ["tag1", "tag2"]
# )

# =============================================================================
# 7. Low-level API (building blocks)
# =============================================================================

# You can also use the building blocks directly:
#
# id = create_experiment(title="Manual experiment")
# update_experiment(id; body="Updated body text")
# upload_to_experiment(id, "data.csv"; comment="Raw data")
# tag_experiment(id, "manual")
# exp = get_experiment(id)
# delete_experiment(id)
