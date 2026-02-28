"""
eLabFTW integration for QPSTools.jl.

Provides full read/write access to eLabFTW for experiment logging,
item/resource management, batch operations, analysis steps, cross-entity
linking, comments, templates, scheduler events, and compounds.

# Configuration

Set up eLabFTW connection (typically in startup.jl or environment):

```julia
using QPSTools
configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = ENV["ELABFTW_API_KEY"]
)
test_connection()  # Verify credentials
```

# Usage

```julia
# Log analysis results
log_to_elab(title="FTIR fit", body=format_results(result))

# Track analysis steps
id = create_experiment(title="TA kinetics analysis")
s1 = add_step(id, "Load and inspect raw data")
s2 = add_step(id, "Fit single exponential with IRF")
finish_step(id, s1)

# Link related experiments
link_experiments(id, previous_id)

# Manage lab resources
sample_id = create_item(title="MoS2 sample A", category=5)
link_experiment_to_item(id, sample_id)

# Browse experiments and items
exps = search_experiments(tags=["ftir"])
print_experiments(exps)
items = search_items(tags=["sample"])
print_items(items)

# Create from template
id = create_from_template(42; title="New FTIR run", tags=["ftir"])

# Add comments
comment_experiment(id, "Approved for publication.")
```

# Caching

Downloaded files are cached in `~/.cache/qpstools/elabftw/`. The cache is checked
before making API requests. Clear with `clear_elabftw_cache()`.
"""

# HTTP, JSON, Dates are loaded at module level in QPSTools.jl

# Infrastructure (must be loaded first)
include("config.jl")
include("http.jl")
include("cache.jl")

# Generic helpers (used by entity-specific wrappers)
include("entity_helpers.jl")
include("subresource_helpers.jl")

# Entity-specific public APIs
include("experiments.jl")
include("items.jl")

# Cross-cutting features
include("links.jl")
include("comments.jl")
include("templates.jl")
include("team.jl")

# Batch operations
include("batch.jl")

# Additional API coverage
include("events.jl")
include("compounds.jl")
include("utility.jl")

# High-level provenance and printing
include("provenance.jl")
include("printing.jl")
