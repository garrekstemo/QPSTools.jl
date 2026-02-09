# QPSTools.jl - Quantum Photo-Science Laboratory Analysis Package

**The standardized analysis package for all lab members.**

QPSTools.jl provides common tools for spectroscopic data analysis, pump-probe measurements, and publication-quality plotting. All students should use QPSTools.jl to ensure consistency and enable collaboration across research projects.

## Ecosystem

| Package | Role |
|---|---|
| **QPSTools.jl** | Analysis, fitting, plotting, reporting (this package) |
| **QPSDrive.jl** | Instrument control & scanning |
| **QPSView.jl** | Live data viewer & scan monitor |

## Quick Start

```julia
julia --project=.
using Revise
using QPSTools
using CairoMakie  # or GLMakie for interactive
```

### FTIR Workflow

```julia
using QPSTools, CairoMakie

# Load from registry
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# Fit peaks in the CN stretch region
result = fit_peaks(spec, (2000, 2100))
report(result)

# Plot with fit and residuals
fig, ax, ax_res = plot_spectrum(spec; fit=result, residuals=true)
save("figures/cn_stretch.pdf", fig)
```

### Pump-Probe Workflow

```julia
using QPSTools, CairoMakie

# Load kinetic trace (peak auto-shifted to t=0)
trace = load_ta_trace("data/kinetics.lvm"; mode=:OD)

# Fit with IRF deconvolution
result = fit_exp_decay(trace)
report(result)

# Plot with automatic residuals panel
fig, ax, ax_res = plot_kinetics(trace; fit=result)
save("figures/kinetics.pdf", fig)

# Global fit across ESA and GSB traces
trace_gsb = load_ta_trace("data/kinetics_gsb.lvm"; mode=:OD)
global_result = fit_global([trace, trace_gsb]; labels=["ESA", "GSB"])
report(global_result)
```

### Publication Figure

```julia
set_theme!(print_theme())
fig = Figure(size=(1000, 400))

# Panel A: Spectra
ax_a = Axis(fig[1, 1], xlabel="Wavenumber (cm-1)", ylabel="DA")
lines!(ax_a, spec_1ps.wavenumber, spec_1ps.signal, label="1 ps")
lines!(ax_a, spec_5ps.wavenumber, spec_5ps.signal, label="5 ps")
axislegend(ax_a)

# Panel B: Kinetics
ax_b = Axis(fig[1, 2], xlabel="Time (ps)", ylabel="DA")
scatter!(ax_b, trace.time, trace.signal, label="Data")
lines!(ax_b, trace.time, predict(result, trace), color=:red, label="Fit")
axislegend(ax_b)

save("figures/publication.pdf", fig)
```

## Core Features

### Transient Absorption
- Single/biexponential fitting with IRF deconvolution
- Global analysis with shared parameters across traces
- Broadband TA matrix loading and indexing (`matrix[t=1.0]`, `matrix[l=800]`)
- TA spectrum fitting (ESA/GSB decomposition)

### Steady-State Spectroscopy
- FTIR and Raman loading via sample registry
- Peak detection (`find_peaks`) and fitting (`fit_peaks`)
- Gaussian, Lorentzian, Pseudo-Voigt models via CurveFitModels.jl
- Baseline correction (ALS, ARPLS, SNIP)

### Plotting
- `plot_spectrum`, `plot_kinetics` with keyword-driven layouts
- `plot_comparison`, `plot_waterfall` for multi-spectrum views
- `print_theme()`, `poster_theme()`, `compact_theme()`
- Layer functions: `plot_peak_decomposition!`, `plot_peaks!`

### eLabFTW Integration
- Log results to electronic lab notebook with `log_to_elab()`
- Auto-tagging from sample registry metadata
- Search, create, update experiments

### Fit Reporting
- `report(result)` for formatted terminal output
- `format_results(result)` for markdown tables
- Works for all fit types (peaks, exponential, global, TA spectrum)

## Data Import

| Format | Loader | Source |
|---|---|---|
| LabVIEW `.lvm` | `load_ta_trace`, `load_ta_spectrum` | Pump-probe setup |
| JASCO `.csv` | `load_ftir`, `load_raman` | FTIR/Raman via registry |
| Broadband TA | `load_ta_matrix` | Time x wavelength matrices |
| Auto-detect | `load_spectroscopy` | Any of the above |

## Installation

```bash
cd /path/to/projects/
git clone <repository-url> QPSTools.jl
cd QPSTools.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Requirements

- **Julia 1.10+** (LTS)
- **CurveFit.jl** / **CurveFitModels.jl**: Lab standard for curve fitting
- **Makie.jl**: CairoMakie (publications), GLMakie (interactive)
- **SpectroscopyTools.jl**: Base types and general spectroscopy functions

## Contributing

All lab members are expected to contribute improvements:

1. Add new types in `types.jl`, loaders in `io.jl`/`ftir.jl`/`raman.jl`
2. Implement `report()` for any new fit result type
3. Add examples in `examples/` and tests in `test/`
4. Export new functions in `src/QPSTools.jl`

See `CLAUDE.md` for full development conventions.

## Support

- **Questions**: Ask team members or Garrek
- **Documentation**: `?function_name` in the REPL
- **Examples**: See `examples/` directory
