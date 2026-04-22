# QPSTools.jl

The lab-specific integration layer for the QPS spectroscopy ecosystem.

QPSTools adds three things to the general-purpose stack: **file loaders** for the instrument formats used in QPS lab, **Makie-based plotting** with lab themes, and **eLabFTW glue** that auto-extracts sample metadata into lab-notebook entries. General spectroscopy analysis — peak fitting, baseline correction, exponential decay fitting, PL/Raman map analysis — lives in [SpectroscopyTools.jl](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/). The eLabFTW API client lives in [ElabFTW.jl](https://garrekstemo.github.io/ElabFTW.jl/stable/).

## Ecosystem

| Package | Role | Docs |
|---------|------|------|
| [QPSTools.jl](https://github.com/garrekstemo/QPSTools.jl) | **This package.** Lab loaders, plotting themes, eLabFTW provenance glue | you're here |
| [SpectroscopyTools.jl](https://github.com/garrekstemo/SpectroscopyTools.jl) | Peak fitting, baselines, decay fitting, PL/Raman maps, unit conversions | [docs](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/) |
| [ElabFTW.jl](https://github.com/garrekstemo/ElabFTW.jl) | eLabFTW API client (experiments, items, uploads, tags, links) | [docs](https://garrekstemo.github.io/ElabFTW.jl/stable/) |
| [CurveFitModels.jl](https://github.com/garrekstemo/CurveFitModels.jl) | Lineshape and temporal model functions (`lorentzian`, `gaussian`, …) | [docs](https://garrekstemo.github.io/CurveFitModels.jl/stable/) |
| [JASCOFiles.jl](https://github.com/garrekstemo/JASCOFiles.jl) | JASCO CSV file parser (used by `load_ftir` / `load_raman`) | [docs](https://garrekstemo.github.io/JASCOFiles.jl/stable/) |

## Installation

```julia
using Pkg
Pkg.develop(url="https://github.com/garrekstemo/QPSTools.jl")
using QPSTools
using CairoMakie  # or GLMakie for interactive exploration
```

## Quick Start

```julia
using QPSTools, CairoMakie

# Registry-based load
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# Fit peaks (dispatches to SpectroscopyTools)
result = fit_peaks(spec, (2000, 2100))
report(result)

# Plot with lab theme
set_theme!(print_theme())
fig = plot_ftir(spec; fit=result, residuals=true)
save("figures/cn_stretch.pdf", fig)

# Log to eLabFTW (auto-tags from spec.sample metadata)
log_to_elab(spec, result; title="FTIR: CN stretch fit",
    attachments=["figures/cn_stretch.pdf"])
```

See the [Lab Workflow tutorial](tutorials/lab_workflow.md) for a full walkthrough.

## Documentation Layout

- **Tutorials** — [Lab Workflow](tutorials/lab_workflow.md) (end-to-end), [Spectrum Plotting Views](tutorials/plot_spectrum_views.md) (all `plot_spectrum` layouts)
- **Reference** — [Loaders](reference/loaders.md), [Plotting](reference/plotting.md), [eLabFTW Integration](reference/elabftw_integration.md)

## Where Else to Look

- **Peak fitting, baselines, decay fitting, PL map analysis** — [SpectroscopyTools.jl docs](https://garrekstemo.github.io/SpectroscopyTools.jl/stable/)
- **eLabFTW API (experiments, items, uploads, tags, links, templates)** — [ElabFTW.jl docs](https://garrekstemo.github.io/ElabFTW.jl/stable/)
- **Model functions** (`lorentzian`, `gaussian`, `pseudo_voigt`, …) — [CurveFitModels.jl docs](https://garrekstemo.github.io/CurveFitModels.jl/stable/)
