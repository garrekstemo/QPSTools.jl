# QPSTools.jl

**Lab-specific integration layer for the QPS spectroscopy ecosystem.**

QPSTools is the glue package for the Quantum Photonic Spectroscopy (QPS) lab. It owns the lab-specific pieces — LabVIEW file loaders, cavity polariton analysis, Makie plotting themes, and eLabFTW provenance — and composes them on top of the registered, general-purpose sibling packages. General-purpose spectroscopy (types, fitting, baseline correction, peak detection) lives in [SpectroscopyTools.jl](https://garrekstemo.github.io/SpectroscopyTools.jl/).

## Installation

QPSTools is not registered. Install via the GitHub URL:

```julia
using Pkg
Pkg.add(url="https://github.com/garrekstemo/QPSTools.jl")
```

## Quick Start

```julia
using QPSTools
using SpectroscopyTools  # types, fitting, baseline, peak detection
using JASCOFiles         # JASCOSpectrum + isftir/israman/isuvvis
using ElabFTW            # eLabFTW CRUD
using CairoMakie         # or GLMakie for interactive exploration
```

`using QPSTools` brings in only the names QPSTools itself defines. No sibling re-exports — method dispatch threads the layers together.

## Ecosystem Layout

```
CurveFitModels.jl ──── zero deps, pure math model functions
       │
CurveFit.jl ────────── fitting backend (NonlinearCurveFitProblem, solve)
       │
SpectroscopyTools.jl ── base types + algorithms (public, registerable)
       │                  TATrace, TASpectrum, TAMatrix, PLMap
       │                  fit_peaks, fit_exp_decay, fit_ta_spectrum
       │                  baseline, smoothing, normalize
       │
       ├── CavitySpectroscopy.jl ── polariton analysis (independent, public)
       │
QPSTools.jl ──────────── lab layer (this package)
                          load_ftir, load_raman, load_ta_*, load_pl_map
                          plot_spectrum, plot_kinetics, Makie themes
                          eLabFTW integration, cavity polariton physics
```

## Package Overview

| Module | What it does |
|--------|-------------|
| **File loaders** | LabVIEW LVM, pump-probe (`.dat`), PL/Raman maps, cavity transmission |
| **Cavity spectroscopy** | `CavitySpectrum`, `fit_cavity_spectrum`, dispersion + Hopfield |
| **Plotting** | Makie themes (`qps_theme`, `print_theme`, `poster_theme`) and layouts |
| **eLabFTW provenance** | `log_to_elab` / `tags_from_sample` dispatches on `AnnotatedSpectrum` |

## Documentation Layout

This documentation follows the [Diátaxis](https://diataxis.fr/) framework:

- **Tutorials** — end-to-end cross-package workflows (loading instrument files → analysis → logging to eLabFTW)
- **How-To Guides** — focused recipes for lab-specific tasks
- **Reference** — complete API documentation grouped by source file
- **Explanation** — architecture and design rationale for the lab layer

## Module

```@docs
QPSTools.QPSTools
```

## Related Packages

- [SpectroscopyTools.jl](https://garrekstemo.github.io/SpectroscopyTools.jl/) — steady-state and ultrafast spectroscopy types and algorithms
- [CurveFitModels.jl](https://garrekstemo.github.io/CurveFitModels.jl/stable/) — lineshape and temporal model functions
- [CurveFit.jl](https://github.com/garrekstemo/CurveFit.jl) — the nonlinear least-squares solver
- [JASCOFiles.jl](https://github.com/garrekstemo/JASCOFiles.jl) — JASCO instrument file reader
- [ElabFTW.jl](https://github.com/garrekstemo/ElabFTW.jl) — eLabFTW REST API client
