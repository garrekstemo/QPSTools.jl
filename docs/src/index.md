# QPS.jl

**Quantum Photo-Science Laboratory Analysis Package**

QPS.jl provides standardized spectroscopy analysis tools for all members of the Quantum Photo-Science Laboratory. The goal is to eliminate "coding from scratch" so students can focus on physics interpretation rather than technical implementation.

## Current Documentation Scope

This documentation covers **peak detection, peak fitting, baseline correction, and spectrum preprocessing**. Additional modules (transient absorption, plotting themes, eLabFTW integration) are documented in docstrings and will be added to these pages over time.

## Getting Started

```julia
julia --project=/path/to/QPS.jl
using Revise
using QPS
using CairoMakie  # or GLMakie for interactive plots
```

### Quick Example: Fit a Peak

```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

result = fit_peaks(spec, (2000, 2100))
report(result)

fig = plot_peaks(result; residuals=true)
save("figures/cn_stretch.pdf", fig)
```

## Documentation Structure

This documentation follows the [Diátaxis](https://diataxis.fr/) framework:

- **[Tutorials](tutorials/raman.md)** — Step-by-step walkthroughs of complete analysis workflows
- **[How-To Guides](howto/peak_detection_sensitivity.md)** — Focused recipes for specific tasks
- **[Reference](reference/peak_detection.md)** — Complete API documentation pulled from docstrings
- **[Explanation](explanation/fitting_statistics.md)** — Background theory and design rationale

## Key Dependencies

| Package | Role |
|---------|------|
| [CurveFit.jl](https://docs.sciml.ai/CurveFit/stable/) | Nonlinear least-squares solver |
| [CurveFitModels.jl](https://github.com/garrekstemo/CurveFitModels.jl) | Spectroscopy model functions (`lorentzian`, `gaussian`, etc.) |
| [Makie.jl](https://docs.makie.org/stable/) | Plotting (CairoMakie for publication, GLMakie for interactive) |
| [SavitzkyGolay.jl](https://github.com/BBN-Q/SavitzkyGolay.jl) | Peak-preserving smoothing |
| [JASCOFiles.jl](https://github.com/garrekstemo/JASCOFiles.jl) | JASCO instrument file loader |
