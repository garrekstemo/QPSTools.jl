# QPSTools.jl — Quantum Photo-Science Laboratory Integration Layer

[![CI](https://github.com/garrekstemo/QPSTools.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/garrekstemo/QPSTools.jl/actions/workflows/CI.yml)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

**Lab-specific integration layer for the QPS spectroscopy ecosystem.**

QPSTools.jl provides LabVIEW pump-probe loaders, cavity polariton analysis, Makie themes / plot layouts, and eLabFTW provenance dispatches. Everything else — peak fitting, baseline correction, exponential-decay fitting, chirp correction, PL map analysis, the spectroscopy data types themselves — lives in sibling packages and is loaded alongside.

## Ecosystem

| Package | Role |
|---|---|
| **QPSTools.jl** | Lab loaders, cavity polariton, plotting, eLabFTW glue (this package) |
| [SpectroscopyTools.jl](https://github.com/garrekstemo/SpectroscopyTools.jl) | Types, fitting, baseline, peak detection, PLMap, chirp, DAS |
| [JASCOFiles.jl](https://github.com/garrekstemo/JASCOFiles.jl) | `JASCOSpectrum` + FTIR/Raman/UV-Vis CSV parsing |
| [ElabFTW.jl](https://github.com/garrekstemo/ElabFTW.jl) | eLabFTW API client |
| [CurveFitModels.jl](https://github.com/garrekstemo/CurveFitModels.jl) | Pure-math model functions (lineshapes, dielectric, etc.) |

`using QPSTools` brings in only names QPSTools itself defines. Method dispatch threads the layers together.

## Quick Start

```julia
julia --project=.
using Revise
using QPSTools
using SpectroscopyTools  # fit_exp_decay, fit_peaks, find_peaks, baselines, …
using CairoMakie         # or GLMakie for interactive
```

### Pump-probe workflow

```julia
using QPSTools, SpectroscopyTools, CairoMakie

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

### Cavity polariton workflow

```julia
using QPSTools, SpectroscopyTools, CairoMakie

# Load a JASCO FTIR transmission spectrum from a cavity sample
spec = load_cavity("data/cavity/Au_0deg.csv"; mirror="Au", angle=0,
                   cavity_length=12e-4)

# Fit the multi-oscillator Fabry-Perot model
result = fit_cavity_spectrum(spec;
    oscillators=[(nu0=2055.0, Gamma=23.0)],
    n_bg=1.4)

# Plot with residuals
fig, ax, ax_res = plot_spectrum(spec; fit=result, residuals=true)
save("figures/cavity.pdf", fig)
```

### PL map workflow

```julia
using QPSTools, SpectroscopyTools, CairoMakie

m = load_pl_map("data/PLmap/scan.lvm"; nx=51, ny=51, step_size=2.16,
                pixel_range=(950, 1100))
m = subtract_background(m)
m = normalize_intensity(m)

fig, ax, hm = plot_pl_map(m; title="PL Intensity")
save("figures/pl_map.pdf", fig)
```

### Publication figure

```julia
using QPSTools, SpectroscopyTools, CairoMakie

set_theme!(print_theme())
fig = Figure(size=(1000, 400))

# Panel A: Spectra
ax_a = Axis(fig[1, 1], xlabel="Wavenumber (cm⁻¹)", ylabel="ΔA")
lines!(ax_a, spec_1ps.wavenumber, spec_1ps.signal, label="1 ps")
lines!(ax_a, spec_5ps.wavenumber, spec_5ps.signal, label="5 ps")
axislegend(ax_a)

# Panel B: Kinetics
ax_b = Axis(fig[1, 2], xlabel="Time (ps)", ylabel="ΔA")
scatter!(ax_b, trace.time, trace.signal, label="Data")
lines!(ax_b, trace.time, predict(result, trace), color=:red, label="Fit")
axislegend(ax_b)

save("figures/publication.pdf", fig)
```

## What lives here

- **LabVIEW loaders**: `load_ta_trace`, `load_ta_spectrum`, `load_ta_matrix`, `load_lvm`, `load_pl_map`, `load_wavelength_file`, `load_spectroscopy` (auto-detect)
- **Cavity polariton spectroscopy**: `CavitySpectrum`, `load_cavity`, `fit_cavity_spectrum`, `fit_dispersion`, `cavity_mode_energy`, `polariton_branches`, `polariton_eigenvalues`, `hopfield_coefficients`, `compute_cavity_transmittance`
- **Plotting themes and layouts**: `qps_theme`, `print_theme`, `poster_theme`, `lab_colors`, `lab_linewidths`, `plot_spectrum`, `plot_kinetics`, `plot_cavity`, `plot_ta_heatmap`, `plot_dispersion`, `plot_hopfield`, `plot_pl_map`, `plot_pl_spectra`, `plot_chirp`, `plot_das`, `plot_comparison`, `plot_waterfall`
- **eLabFTW provenance** for `AnnotatedSpectrum`: `log_to_elab`, `tags_from_sample`

For peak detection / fitting, baseline correction, exponential decay fitting, chirp correction, PLMap analysis, DAS extraction, normalize / smooth, and unit conversions, load `SpectroscopyTools` alongside QPSTools.

## Data Import

| Format | Loader | Source |
|---|---|---|
| LabVIEW `.lvm` (kinetics) | `load_ta_trace` | Pump-probe single-pixel detector |
| LabVIEW `.lvm` (spectrum) | `load_ta_spectrum` | Pump-probe spectrometer |
| Broadband TA (directory) | `load_ta_matrix` | CCD time × wavelength data |
| LabVIEW `.lvm` (PL map) | `load_pl_map` | CCD raster scan |
| JASCO `.csv` (cavity) | `load_cavity` | JASCO FTIR of cavity samples |
| JASCO `.csv` (any technique) | `JASCOSpectrum(path)` | From `JASCOFiles.jl` |
| Auto-detect | `load_spectroscopy` | LVM file → trace / spectrum / matrix |

## Installation

```bash
cd /path/to/projects/
git clone <repository-url> QPSTools.jl
cd QPSTools.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Requirements

- **Julia 1.11+**
- **Makie.jl**: load CairoMakie (publications) or GLMakie (interactive) yourself
- **SpectroscopyTools.jl**, **JASCOFiles.jl**, **ElabFTW.jl**: sibling packages, declared in `Project.toml`

## Contributing

1. New lab loader → extend `src/io.jl` or add a new file under `src/`
2. New cavity / polariton physics → `src/cavity.jl`
3. New plot layout → new file under `src/plotting/`
4. Export the new symbol from `src/QPSTools.jl`
5. Add tests in `test/` and an example in `examples/`

If a capability is general-purpose (peak fitting, baseline, transforms, model functions, eLabFTW CRUD), land it in the appropriate sibling package instead — QPSTools only carries lab-specific glue.

See `CLAUDE.md` for full development conventions.

## Support

- **Questions**: Ask team members or Garrek
- **Documentation**: `?function_name` in the REPL
- **Examples**: See `examples/` directory
