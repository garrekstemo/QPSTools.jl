# eLabFTW Integration

A guide to using eLabFTW from Julia via QPSTools.

QPSTools provides full read/write access to the eLabFTW API v2: experiment logging, item/resource management, cross-entity linking, comments, templates, scheduler events, and compounds. The web UI then becomes a browsable, searchable record of every analysis and lab resource.

## Setup

### 1. Get an eLabFTW API Key

1. Log in to your eLabFTW instance in a web browser.
2. Go to **Settings** (gear icon, top right).
3. Scroll to **API Keys**.
4. Click **Create a new key**.
5. Give it a name (e.g., `qps-julia`) and set the access level to **Read/Write**.
6. Copy the key. It looks like `3-cb2314b00d2845a...`.

**Treat this key like a password.** Anyone with it has full access to your account.

### 2. Add Environment Variables

Add these two lines to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export ELABFTW_URL="https://your-instance.elabftw.net"
export ELABFTW_API_KEY="3-cb2314b00d2845a..."
```

Then restart your terminal or run `source ~/.zshrc`.

That's it. QPS.jl auto-configures from these environment variables when you `using QPS`. No Julia configuration needed.

### 3. Verify

```julia
julia> elabftw_enabled()
true
```

If you need to temporarily disable logging (e.g., offline work):

```julia
disable_elabftw()   # Switch to local-only mode
enable_elabftw()    # Re-enable
```

## Quick Start

```julia
using QPS
using CairoMakie

# Load and fit
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))

# Save figure
fig = plot_peaks(result; residuals=true)
save("figures/cn_stretch.pdf", fig)

# Log to eLabFTW
log_to_elab(
    title = "FTIR: CN stretch fit",
    body = format_results(result),
    attachments = ["figures/cn_stretch.pdf"],
    tags = ["ftir", "nh4scn", "peak_fit"]
)
```

This creates an experiment entry in eLabFTW with:
- A formatted markdown table of fit parameters
- The figure attached
- Searchable tags

## `log_to_elab`

```julia
log_to_elab(;
    title::String,                              # Required
    body::String = "",                          # Markdown/HTML content
    attachments::Vector{String} = String[],     # File paths to attach
    tags::Vector{String} = String[],            # Searchable tags
    category::Union{Int, Nothing} = nothing,    # eLabFTW category ID
    metadata::Union{Dict, Nothing} = nothing    # Extra JSON metadata
) -> Int  # Returns experiment ID
```

The function:
1. Creates a new experiment entry
2. Uploads each attachment file
3. Adds each tag
4. Prints the experiment URL
5. Returns the experiment ID

### Attach raw data + figures

```julia
log_to_elab(
    title = "VSC cavity kinetics",
    body = format_results(result),
    attachments = [
        "figures/kinetics.pdf",       # Publication figure
        "data/raw/sig_250903.lvm",    # Raw data for reproducibility
    ],
    tags = ["pump_probe", "vsc"]
)
```

### Mix manual notes with auto-formatted results

```julia
body = """
## Notes
Sample prepared fresh today. Used 12 um CaF2 spacer.
Cavity mode at 2050 cm-1 (checked with FTIR).

$(format_results(result))

## Next Steps
- Repeat at higher concentration
- Compare with bare molecule lifetime
"""

log_to_elab(title="VSC: CN stretch kinetics", body=body)
```

## `format_results`

Converts any QPS fit result into a markdown string with parameter tables and fit statistics. Designed to be composed with `log_to_elab`.

```julia
format_results(result) -> String
```

### Supported result types

| Type | What it formats |
|------|----------------|
| `MultiPeakFitResult` | Peak parameters (center, FWHM, amplitude) per peak |
| `ExpDecayIRFFit` | Single exponential with IRF (tau, sigma, t0) |
| `ExpDecayFit` | Single exponential without IRF |
| `BiexpDecayFit` | Two-component decay with weights |
| `MultiexpDecayFit` | N-component decay with weights |
| `GlobalFitResult` | Shared parameters + per-trace table |

### Example output (MultiPeakFitResult)

```markdown
## Peak Fit Results

| Parameter | Value | Uncertainty |
|-----------|-------|-------------|
| amplitude | 0.452 | +/- 0.002 |
| center | 2062.3 | +/- 0.12 |
| fwhm | 24.7 | +/- 0.31 |

**Baseline:** constant = 0.01
**Model:** lorentzian | **R2:** 0.99850 | **Region:** 2000-2100
```

### Example output (BiexpDecayFit)

```markdown
## Biexponential Decay Fit (ESA)

| Component | tau (ps) | Amplitude | Weight |
|-----------|----------|-----------|--------|
| Fast | 1.5 | 0.3 | 60.0% |
| Slow | 15.0 | 0.2 | 40.0% |

**sigma_IRF:** 0.25 ps | **t0:** 0.1 ps | **Offset:** 0.01
**R2:** 0.99670
```

## Low-Level API

For more control, use the building-block functions directly.

### `create_experiment`

```julia
id = create_experiment(title="My experiment", body="Some notes")
```

### `update_experiment`

```julia
update_experiment(id; body="Updated analysis with new calibration")
```

### `upload_to_experiment`

```julia
upload_to_experiment(id, "figures/fit.pdf"; comment="Peak fit figure")
```

### `tag_experiment`

```julia
tag_experiment(id, "ftir")
tag_experiment(id, "nh4scn")
```

### `get_experiment`

```julia
exp = get_experiment(id)
exp["title"]
exp["body"]
```

### Example: iterative workflow

```julia
# Create the experiment first
id = create_experiment(title="FTIR: NH4SCN kinetics series")

# Run multiple analysis scripts, appending results
for (i, trace) in enumerate(traces)
    result = fit_exp_decay(trace)
    fig = plot_kinetics(trace; fit=result)
    figpath = "figures/trace_$i.pdf"
    save(figpath, fig)

    upload_to_experiment(id, figpath; comment="Trace $i fit")
    tag_experiment(id, "trace_$i")
end

# Update the body with a summary
update_experiment(id; body=summary_text)
```

## Items (Resources)

Items represent lab resources: samples, instruments, reagents, substrates, etc.
They complement experiments — experiments describe *what you did*, items describe *what you used*.

### When to use items vs experiments

| Entity | Use for |
|--------|---------|
| Experiment | Analysis runs, measurements, protocols |
| Item | Samples, instruments, reagents, substrates |

### Create and manage items

```julia
# Create a sample entry
sample_id = create_item(title="MoS2 sample A", category=5)

# Add details
update_item(sample_id; body="Exfoliated 2024-12-15, stored in N2 glovebox")
tag_item(sample_id, ["mos2", "tmdc", "2d_materials"])

# Upload characterization data
upload_to_item(sample_id, "data/raman/mos2_a.csv"; comment="Raman spectrum")

# Track preparation steps
s1 = add_item_step(sample_id, "Exfoliation")
s2 = add_item_step(sample_id, "Transfer to substrate")
finish_item_step(sample_id, s1)
```

### Search and browse items

```julia
items = search_items(tags=["mos2"])
print_items(items)

# Get a specific item
item = get_item(42)
```

## Linking Experiments to Items

Cross-entity links connect experiments to the resources they used.
Links are visible in the eLabFTW web UI on both entities.

```julia
# Link experiment to the sample and instrument used
link_experiment_to_item(experiment_id, sample_id)
link_experiment_to_item(experiment_id, instrument_id)

# See what items an experiment references
links = list_experiment_item_links(experiment_id)

# Reverse: see which experiments used an item
exp_links = list_item_experiment_links(sample_id)

# Remove a link
unlink_experiment_from_item(experiment_id, sample_id)

# Link items to each other (e.g., sample ↔ substrate)
link_items(sample_id, substrate_id)
```

## Templates

Templates pre-populate new experiments with a standard body and structure.
Create them once, then use them for every new analysis of a given type.

### Experiment templates

```julia
# List available templates
templates = list_experiment_templates()
for t in templates
    println(t["id"], ": ", t["title"])
end

# Create a new experiment from a template
id = create_from_template(42; title="FTIR: NH4SCN run 3", tags=["ftir", "nh4scn"])

# Manage templates programmatically
tid = create_experiment_template(title="FTIR analysis", body="## Protocol\n...")
update_experiment_template(tid; body="## Updated Protocol\n...")
delete_experiment_template(tid)
```

### Items types

Items types define categories for resources (Sample, Instrument, Reagent, etc.).

```julia
types = list_items_types()
for t in types
    println(t["id"], ": ", t["title"])
end
```

## Comments

Add review comments to experiments or items. Useful for peer review,
supervisor feedback, or tracking decisions.

```julia
# Comment on an experiment
cid = comment_experiment(42, "Looks good, approved for publication.")

# List comments
comments = list_experiment_comments(42)
for c in comments
    println(c["comment"])
end

# Comment on an item
comment_item(7, "Sample degraded — prepare new batch.")

# Edit or delete comments
update_comment(:experiments, 42, cid, "Updated: approved with minor edits.")
delete_comment(:experiments, 42, cid)
```

## Events / Booking

Schedule instrument time using the eLabFTW scheduler.

```julia
# Create a booking
event_id = create_event(
    title = "FTIR session",
    start = "2026-03-01T09:00:00",
    end_  = "2026-03-01T12:00:00",
    item  = instrument_id  # Link to an instrument item
)

# List upcoming events
events = list_events()

# Update or cancel
update_event(event_id; title="FTIR session — rescheduled")
delete_event(event_id)
```

## Tagging Convention

Consistent tags make experiments findable. Use lowercase, underscores for spaces.

| Tag type | Examples |
|----------|---------|
| Technique | `ftir`, `pump_probe`, `raman`, `uv_vis` |
| Sample | `nh4scn`, `mapbi3`, `mos2` |
| Team | `vsc`, `tmdc`, `mof` |
| Status | `preliminary`, `publication_ready` |
| Project | `cavity_lifetime`, `2d_materials` |

## Troubleshooting

### "eLabFTW not enabled"

The `ELABFTW_URL` and `ELABFTW_API_KEY` environment variables are missing or empty. Check that they're set in your shell:

```bash
echo $ELABFTW_URL
echo $ELABFTW_API_KEY
```

If they're set but QPS was loaded before they were exported, configure manually:

```julia
configure_elabftw(url=ENV["ELABFTW_URL"], api_key=ENV["ELABFTW_API_KEY"])
```

### "eLabFTW authentication failed"

Your API key is invalid or expired. Generate a new one from Settings in the eLabFTW web UI.

### "eLabFTW permission denied"

Your API key doesn't have write permissions. Create a new key with **Read/Write** access level.

### "File not found" on upload

The file path passed to `attachments` doesn't exist. Use absolute paths or paths relative to your current working directory.

### Working offline

Disable eLabFTW to avoid connection errors:

```julia
disable_elabftw()
# ... do offline work ...
enable_elabftw()  # when back online
```
