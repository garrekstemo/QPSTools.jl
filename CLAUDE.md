# QPSTools.jl - Quantum Photo-Science Laboratory Analysis Package

## Ecosystem

| Package | Role | Status |
|---|---|---|
| **QPSTools.jl** | Analysis, fitting, plotting, reporting | Active (this package) |
| **QPSDrive.jl** | Instrument control & scanning | In development |
| **QPSView.jl** | Live data viewer & scan monitor | Active |
| **SpectroscopyTools.jl** | Base types and general spectroscopy | Active |
| **CavitySpectroscopy.jl** | Polariton analysis | Independent (public) |

## Project Mission

**QPSTools.jl is the standardized analysis foundation for all research in the Quantum Photo-Science Laboratory.** This package eliminates the "coding from scratch" bottleneck that slows down every project, enabling students to focus on physics interpretation rather than technical implementation.

## Lab Transformation Context

This package is central to transforming our lab from a linear research model to a high-output pipeline system:

- **Eliminates Knowledge Loss**: Common analysis tools persist when students graduate
- **Enables Team Collaboration**: Standardized tools allow cross-project collaboration
- **Accelerates Publication**: Automated analysis reduces time from data to manuscript
- **Scales Expertise**: Garrek's analysis speed multipliers become available to all students
- **Supports Living Manuscripts**: Fast, reproducible analysis enables continuous manuscript development

See `Lab_Transformation_Assessment.md` and `Lab_Transformation_Roadmap.md` for full context.

---

## Package Dependencies

**Note**: This package uses **loose dependency constraints** (no `[compat]` entries in Project.toml). Since we don't develop many packages or do extensive package development, we keep dependencies flexible to avoid version conflicts. This approach prioritizes usability over strict version compatibility - if issues arise, they can be addressed case-by-case.

**IMPORTANT**: Do NOT add `[compat]` entries to Project.toml. When adding dependencies with `Pkg.add()`, Julia may automatically add compat entries — these should be removed.

The package manager will select compatible versions automatically. Key dependencies:
- **CurveFit.jl**: Lab standard for all curve fitting
- **Makie.jl ecosystem**: CairoMakie (publications), GLMakie (interactive)
- **SavitzkyGolay.jl**: Peak-preserving smoothing for spectroscopy
- **CurveFitModels.jl**: Garrek's spectroscopy-specific model library

### Examples Environment

Examples have their own environment at `examples/Project.toml` with additional dependencies that are **not** part of the main package. Students load the Makie backend (`CairoMakie` or `GLMakie`) themselves — QPSTools only depends on `Makie` (the abstract interface).

**Example-only deps** (do NOT add to root `Project.toml`): `CairoMakie`, `GLMakie`, `FileIO`, `CurveFit`, `CurveFitModels`, `Revise`

Run examples with the examples environment:
```bash
julia --project=examples examples/raman_analysis.jl
```

---

## Development Status

**This package has not shipped yet.** Backward compatibility is not a concern — breaking changes to APIs, struct fields, and function signatures are acceptable during development. Prioritize clean, correct design over maintaining legacy interfaces.

## Communication Preferences

- **Use tables** when presenting options, comparisons, or structured information — they're easier to scan and compare.

---

## Core Capabilities

### Uniform Data Interface
- **`AbstractSpectroscopyData`**: Base type for all spectroscopy data
- **`load_spectroscopy()`**: Auto-detecting loader (returns `TATrace`, `TASpectrum`, or `TAMatrix`)
- **Interface functions**: `xdata()`, `ydata()`, `zdata()`, `xlabel()`, `ylabel()`, `is_matrix()`
- **Metadata accessors**: `source_file()`, `npoints()`, `title()`
- **Axis detection**: `AxisType` enum (`time_axis`, `wavelength_axis`) for raw data

### Transient Absorption (Pump-Probe)
- **Spectra**: `load_ta_spectrum()` — ΔA vs wavenumber at fixed time delay
- **Kinetics**: `load_ta_trace()` — ΔA vs time at fixed wavelength
- **Broadband**: `load_ta_matrix()` — 2D time × wavelength heatmaps
- **Fitting**: Single/biexponential with IRF deconvolution
- **Global fitting**: Shared τ, σ, t₀ across multiple traces
- **Plotting**: `plot_spectrum()`, `plot_kinetics()` with keyword-driven layouts (survey, labeled, fit, residuals, three-panel)

### Steady-State Spectroscopy
- **FTIR**: `load_ftir()`, `fit_peaks()` with registry integration
- **Raman**: `load_raman()`, `fit_peaks()` with registry integration
- **Peak fitting**: Gaussian, Lorentzian, Pseudo-Voigt via CurveFitModels.jl
- **Baseline correction**: ALS, ARPLS, SNIP algorithms

### PL / Raman Mapping (CCD Raster Scans)
- **`PLMap`**: 2D spatial grid with full CCD spectrum at each point
- **`load_pl_map()`**: Load LabVIEW CCD raster scan files
- **`extract_spectrum()`**: Pull individual spectra by grid index or spatial position
- **`subtract_background()`**: Remove per-pixel CCD baseline (explicit positions or auto)
- **`normalize()`**: Min-max normalization to [0, 1]
- **Plotting**: `plot_pl_map()` (spatial heatmap), `plot_pl_spectra()` (spectra at positions)

### Data Import
- **LabVIEW (.lvm)**: Pump-probe spectra and kinetics with wavenumber calibration
- **LabVIEW CCD (.lvm)**: PL/Raman raster scan maps (row-count header + tab-separated spectra)
- **JASCO (.csv)**: FTIR spectra via JASCOFiles.jl
- **Broadband TA**: Separate axis files with auto-detection
- **Registry system**: Sample metadata lookup and organization

### Planned Extensions
- **Fluorescence spectroscopy**: Lifetime and quantum yield
- **Cavity spectroscopy**: Polariton analysis (CavitySpectroscopy.jl integration)
- **QPSDrive.jl integration**: Load QPSDrive scan files, scan metadata → eLabFTW tags

### eLabFTW Integration
- **Experiment logging**: `log_to_elab()` creates experiments with formatted results
- **Auto-tagging**: Extract tags from sample registry metadata
- **File attachments**: Upload figures and data files
- **Search & list**: Query experiments by tags or full-text search

---

## eLabFTW Lab Notebook Integration

QPSTools.jl integrates with [eLabFTW](https://www.elabftw.net/) for logging analysis results to your electronic lab notebook.

### Configuration

Set environment variables (add to `~/.zshrc` or `~/.bashrc`):

```bash
export ELABFTW_URL="https://your-instance.elabftw.net"
export ELABFTW_API_KEY="your-api-key-here"
```

Get your API key from eLabFTW: User Panel → API Keys.

QPSTools auto-configures on load if these variables are set:

```julia
using QPSTools
# => "eLabFTW configured: https://your-instance.elabftw.net"
```

Or configure manually:

```julia
configure_elabftw(
    url = "https://your-instance.elabftw.net",
    api_key = "your-api-key"
)
```

### Logging Results

**Basic logging:**

```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))

log_to_elab(
    title = "FTIR: CN stretch fit",
    body = format_results(result),
    attachments = ["figures/fit.pdf"],
    tags = ["ftir", "nh4scn"]
)
```

**With auto-tags from registry** (recommended):

```julia
# Tags auto-extracted from sample metadata: NH4SCN, DMF, 1.0M, CaF2
log_to_elab(spec, result;
    title = "FTIR: CN stretch fit",
    body = "CN stretch region analysis.",
    attachments = ["figures/fit.pdf"],
    extra_tags = ["peak_fit"]  # Merged with auto-tags
)
```

### Formatting Results

`format_results()` converts any fit result to a markdown table:

```julia
format_results(result)  # Returns markdown string
```

Supported types:
- `MultiPeakFitResult`, `PeakFitResult` — Peak fitting
- `ExpDecayFit` — Single exponential (with or without IRF)
- `MultiexpDecayFit` — Multi-exponential
- `GlobalFitResult` — Global fitting
- `TASpectrumFit` — TA spectrum ESA/GSB fit

### Searching Experiments

```julia
# List recent experiments
list_experiments(limit=10)

# Search by tags
search_experiments(tags=["ftir", "nh4scn"])

# Full-text search
search_experiments(query="CN stretch")

# Combine
search_experiments(query="peak fit", tags=["ftir"], limit=5)
```

### CRUD Operations

```julia
# Create
id = create_experiment(title="New experiment", body="Description")

# Read
exp = get_experiment(id)
exp["title"]
exp["body"]
exp["tags"]

# Update
update_experiment(id; body="Updated content")

# Delete
delete_experiment(id)

# Attachments
upload_to_experiment(id, "figure.pdf"; comment="Peak fit")

# Tags
tag_experiment(id, "new-tag")
```

### Extracting Tags from Samples

```julia
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# Extract all tag-worthy fields
tags_from_sample(spec)
# => ["NH4SCN", "DMF", "1.0M", "CaF2"]

# Filter to specific fields
tags_from_sample(spec; include=[:solute, :solvent])
# => ["NH4SCN", "DMF"]
```

---

## Package Structure & Contribution Guidelines

```
QPSTools.jl/
├── src/
│   ├── QPSTools.jl      # Main module (includes and exports)
│   ├── types.jl         # Data structures for all spectroscopy types
│   ├── io.jl            # File loading (extensible for new formats)
│   ├── plotting.jl      # Makie plotting themes and utilities
│   ├── spectroscopy.jl  # General spectroscopy functions
│   ├── peakdetection.jl # Peak detection dispatches
│   ├── peakfitting.jl   # Peak fitting dispatches
│   ├── registry.jl      # Sample metadata registry
│   ├── elabftw.jl       # eLabFTW lab notebook integration
│   ├── ftir.jl          # FTIR loading and analysis
│   └── raman.jl         # Raman loading and analysis
├── examples/            # Example usage scripts
├── figures/             # All generated figures (see convention below)
│   └── EXAMPLES/        # Output from example scripts (safe to delete)
├── data/                # Raw instrument data (gitignored)
├── test/                # Unit tests for all functions
├── notes/               # Lab transformation docs, planning notes
└── CLAUDE.md            # This file
```

### Figure Output Convention

**All figures must be saved to a subfolder of `figures/`.** This keeps generated output organized and separate from source code.

- `figures/EXAMPLES/` — Output from example scripts (easily deleted)
- `figures/<project>/` — Project-specific figures (e.g., `figures/VSC-paper/`)
- Never save figures to project root or alongside scripts

**Two template types: explore + analysis.**
- `explore_*.jl` — GLMakie + `DataInspector()` for interactive REPL exploration. Copy to `explore/`, step through line-by-line.
- `*_analysis.jl` — CairoMakie for saved output. Copy to `analyses/`, run as a script.

**PNG for saved output, PDF for publication.** Analysis templates use CairoMakie + `.png` — VS Code previews PNG natively. Switch to `.pdf` only for `manuscript/` figures (vector graphics for journals).

### Contributing New Analysis Types

1. **Add new types** in `types.jl` following existing patterns
2. **Extend `io.jl`** for new data formats
3. **Add analysis functions** in appropriate module file
4. **Create analysis example** in `examples/` directory
5. **Write tests** for new functionality
6. **Update this documentation**

All students should contribute back to this package when developing new analysis capabilities.

### Example Script Guidelines

Examples should be **minimal and easy to understand**, simulating a beginning master student's workflow. **Keep each example under 100 lines** (including comments).

1. **Simple data loading** — one or two function calls
2. **Short analysis calls** — fit functions that do the work
3. **Terminal output** — call a report function, never raw `println`
4. **Plot recipe** — automatic data + fit + residuals plotting
5. **Custom figure** — 2-4 panel publication figure at the end
6. **eLabFTW logging** — commented-out `log_to_elab()` block showing how to document results

### Fit Reporting Convention

**Users should never write `println` statements to display fit results.** Fit result types (`MultiPeakFitResult`, etc.) must provide a report function that prints a formatted summary. This keeps analysis scripts clean and ensures consistent output across the lab.

```julia
# Good — report function handles all formatting
result = fit_peaks(spec, (2000, 2100))
report(result)

# Bad — user writes print statements manually
println("Center: $(round(result[1][:center].value, digits=1))")
println("FWHM: $(round(result[1][:fwhm].value, digits=1))")
```

This applies to all spectroscopy fits (FTIR, Raman, pump-probe). When adding a new fit result type, implement `report()` for it.

### Before Writing New Code

**Always check existing functionality first** to avoid duplication:

1. **Search the codebase** for related functions before implementing new ones
2. **Check `spectroscopy.jl`** for general-purpose functions (baseline correction, smoothing, etc.)
3. **Prefer generalization** — extend existing functions rather than creating parallel implementations
4. **Keep functions modular** — small, composable functions over monolithic ones
5. **Technique-agnostic when possible** — a baseline correction should work for FTIR, Raman, UV-vis, etc.

Example: Before writing `correct_raman_baseline()`, check if `linear_baseline_correction()` in `spectroscopy.jl` already exists and can be reused or extended.

---

## Julia Development Standards

### Language Requirements
- **Julia version**: Minimum 1.10 LTS
- **Package activation**: Always use `julia --project=.` and `using Revise`
- **Development workflow**: Use Revise.jl for interactive development

### Preferred Julia Patterns

```julia
# Iteration
for i in eachindex(arr)          # ✓ Not 1:length(arr)

# Nil coalescing  
something(a, default)            # ✓ Not `a === nothing ? default : a`

# Array allocation (ForwardDiff compatible)
similar(p, N)                    # ✓ Not zeros(N) in autodiff contexts

# Number formatting
fmt(x, d=2) = string(round(x, digits=d))  # ✓ Not @sprintf
println(rpad(name, 8), lpad(fmt(value), 12))
```

### What to Avoid

- `##` comments in Julia files (conflicts with VS Code Julia extension)
- `const` declarations in analysis scripts (redefinition errors when re-running)
- `using Printf` / `@sprintf` — use `round()` and string interpolation
- Repeating function definitions across files — define once in `src/`, use everywhere
- Inline plot styling — use themes instead
- **Defining fitting functions inline** — use CurveFitModels.jl instead

### Julia 1.12 World Age Warning

Julia 1.12 introduced stricter world age semantics. When adding new exported functions, **always test with Revise.jl** to catch this warning:

```
WARNING: Detected access to binding `QPSTools.new_function` in a world prior to its definition world.
  Julia 1.12 has introduced more strict world age semantics for global bindings.
  !!! This code may malfunction under Revise.
  !!! This code will error in future versions of Julia.
Hint: Add an appropriate `invokelatest` around the access to this binding.
```

**How to test:** After adding a new function, run `using Revise; using QPSTools` and call the function.

**How to fix:** Do NOT use `invokelatest()` — that's a workaround, not a fix. Instead, restructure the code:
- Move the called function definition **before** the calling function
- Avoid top-level code that calls functions defined later in the module
- Check `include()` order in the main module file — included files must define functions before they're used

### Curve Fitting Conventions

Use **CurveFit.jl** for fitting and **CurveFitModels.jl** for model functions. Never define fitting functions inline — use the standard models from CurveFitModels.jl.

**Documentation**: https://docs.sciml.ai/CurveFit/stable/

**Available models** (all use signature `fn(p, x)`):
- `lorentzian` — Lorentzian with FWHM parameter: `p = [A, x₀, Γ, offset]`
- `gaussian` — Gaussian with FWHM parameter: `p = [A, x₀, Γ, offset]`
- `single_exponential` — Exponential decay: `p = [A, τ, offset]`
- `pseudo_voigt` — Mixed Gaussian/Lorentzian: `p = [A, x₀, σ, α]`

```julia
# Example: FTIR peak fitting
p0 = [amplitude, center, fwhm, offset]
sol = solve(NonlinearCurveFitProblem(lorentzian, p0, x, y))

# Fitted parameters
coef(sol)       # Fitted parameter values
stderror(sol)   # Parameter uncertainties (standard errors)

# Fit quality (via StatsAPI.jl)
residuals(sol)  # y_data - y_fit
rss(sol)        # Residual sum of squares
mse(sol)        # Mean squared error
nobs(sol)       # Number of observations

# Predictions and diagnostics
predict(sol)    # Fitted values (same as model(coef(sol), x))
isconverged(sol) # Check if solver succeeded
confint(sol)    # Confidence intervals for parameters
```

**ForwardDiff compatibility**: Use `similar(p, N)` instead of `zeros(N)` for array allocation.

---

## Makie Plotting Standards

**Always use Makie**, never Plots.jl.

### Backend Selection
| Backend | Use Case |
|---------|----------|
| `GLMakie` | Interactive exploration, development |
| `CairoMakie` | Publication figures (save as PDF/SVG) |
| `WGLMakie` | Web-based interactive plots (if needed) |

### Default Theme: qps_theme()

All QPSTools plot functions (`plot_kinetics`, `plot_spectrum`, etc.) automatically apply `qps_theme()` via `with_theme()`. This ensures consistent styling (ticks inside, etc.) without affecting the user's global theme.

```julia
# QPSTools functions apply qps_theme automatically
fig, ax = plot_kinetics(trace; fit=result)  # Uses qps_theme internally

# Users can still set their own global theme for custom plots
set_theme!(print_theme())
fig = Figure()  # Uses print_theme
```

For custom plots, users should explicitly set a theme or use `with_theme()`:

```julia
with_theme(print_theme()) do
    fig = Figure()
    # ...
end
```

### Unified Plotting API

All spectrum/kinetics plotting goes through two main functions: `plot_spectrum` and `plot_kinetics`. These dispatch on data type and use keyword arguments to select the layout. Convenience aliases `plot_ftir`, `plot_raman`, and `plot_cavity` forward all kwargs to `plot_spectrum`.

**Keywords:** `fit`, `peaks`, `residuals`, `context` (no `labels` kwarg — pass pre-computed peaks explicitly).

**`plot_spectrum` — keyword-driven layouts:**

```julia
plot_spectrum(spec)                                    # survey
plot_spectrum(spec; peaks=peaks)                       # survey + peak markers
plot_spectrum(spec; fit=result)                        # zoomed to fit region
plot_spectrum(spec; fit=result, peaks=peaks)           # full spectrum + fit overlaid
plot_spectrum(spec; fit=result, residuals=true)        # fit region + residuals (stacked)
plot_spectrum(spec; fit=result, peaks=peaks, residuals=true)  # stacked, peaks filtered to fit region
plot_spectrum(spec; fit=result, context=true)          # three-panel publication
plot_spectrum(spec; fit=result, context=true, peaks=peaks)    # three-panel, peaks on context panel
```

**Layout selection priority** (in `_plot_spectrum_impl`):

| Priority | Keywords | Layout | x-range |
|----------|----------|--------|---------|
| 1 | `fit + context` | Three-panel (full, fit, residuals) | Fit region (context panel shows full) |
| 2 | `fit + residuals` | Stacked (fit + residuals) | Fit region |
| 3 | `fit + peaks` | Single panel, fit overlaid | Full spectrum |
| 4 | `fit` only | Single panel, zoomed | Fit region |
| 5 | No `fit` | Survey | Full spectrum |

Peaks are passed through all branches. In zoomed views (stacked, three-panel fit panel), `_filter_peaks()` clips peaks to the data x-range to prevent axis distortion. In the three-panel view, peaks draw on the context panel (a), not the fit panel (b).

**Invalid combinations produce `@warn`:**
- `residuals=true` without `fit` — warns, returns survey
- `context=true` without `fit` — warns, returns survey

**`plot_spectrum` dispatches on:** `AbstractVector` (raw x/y), `AnnotatedSpectrum` (FTIR, Raman, Cavity), `TASpectrum`

**AnnotatedSpectrum dispatch** handles the x-data asymmetry: `MultiPeakFitResult` stores its own `._x` and `._y` (narrow fit region), while the spectrum has full data. The dispatch decides which to send to `_plot_spectrum_impl`:
- `fit + peaks` (no residuals) → sends full `x, y` (overview)
- `fit + residuals` or `fit` alone → sends `fit._x, fit._y` (zoomed)
- `fit + context` → sends `fit._x, fit._y` with `context=(x, y, region)` tuple

**Multi-spectrum views:**

```julia
plot_comparison([spec1, spec2, spec3]; labels=["A","B","C"])
plot_waterfall([spec1, spec2, spec3]; offset=0.1)
```

**Return values:**

| View | Return |
|------|--------|
| Survey, Peaks, Fit, Fit+Peaks (single panel) | `(Figure, Axis)` |
| Fit + Residuals | `(Figure, Axis, Axis)` |
| Context (three-panel) | `(Figure, Axis, Axis, Axis)` |
| Comparison, Waterfall | `(Figure, Axis)` |

**Architecture — layers + layouts:**
- Internal `_draw_*!` layer functions draw on existing axes (data, fit, annotations, residuals, region indicators)
- Internal `_layout_*` functions create Figure + Axes arrangements
- Internal `_filter_peaks()` clips peaks to data x-range for zoomed views
- Public `plot_peak_decomposition!(ax, result)` and `plot_peaks!(ax, peaks)` add to existing axes
- `plot_ftir`, `plot_raman`, `plot_cavity` are convenience aliases for `plot_spectrum`

**No mixing of analysis and plotting:**
- Plot functions do NOT trigger fitting internally
- Users call `find_peaks` and `fit_peaks` separately, then pass results to plot functions

### Theming Over Inline Styling

**Rely on Makie defaults or user-defined themes** — do not hardcode styling attributes in library code.

Inline attributes like `linewidth`, `markersize`, `fontsize`, etc. cause confusion when users set a theme and plots don't match their expectations. Library functions should only specify attributes that convey *semantic meaning* (e.g., `color=:red` to distinguish a fit from data).

```julia
# Good - semantic distinction only, let theme control appearance
lines!(ax, x, y)                         # Uses theme defaults
lines!(ax, x_fit, y_fit, color=:red)     # Color distinguishes fit from data
scatter!(ax, x, y)                       # Markersize from theme

# Bad - hardcoded styling overrides user themes
lines!(ax, x, y, linewidth=2)            # Don't hardcode linewidth
scatter!(ax, x, y, markersize=8)         # Don't hardcode markersize
text!(ax, x, y, text="label", fontsize=10)  # Don't hardcode fontsize
```

**In user analysis scripts**, theming should be set once at the top:

```julia
using QPSTools
set_theme!(print_theme())  # Or user's custom theme
# All subsequent plots inherit theme settings
```

### Figure Organization

Keep analysis logic separate from plotting:

```julia
# Analysis script structure
using QPSTools
using GLMakie  # or CairoMakie for saving

# 1. Load and analyze data
data = load_lvm("my_experiment.lvm")
result = analyze(data)

# 2. Create figure
set_theme!(print_theme())
fig = Figure()
ax = Axis(fig[1,1], xlabel="Time (ps)", ylabel="ΔA")

# 3. Plot data (minimal styling)
scatter!(ax, result.time, result.signal, label="Data")
lines!(ax, result.time, result.fit_curve, color=:red, label="Fit")

# 4. Format and save
axislegend(ax)
save("figure.pdf", fig)
```

### Heatmap Matrix Orientation (Common Gotcha)

Makie's `heatmap(x, y, z)` expects `z` to have shape `(length(x), length(y))`:

```julia
# z[i, j] is plotted at position (x[i], y[j])
# First dimension of z  →  first argument (x-axis)
# Second dimension of z →  second argument (y-axis)
```

**Common mistake with 2D spectroscopy data:**

```julia
# Data stored as (time, wavelength) = (53, 2048)
ta_matrix = load_matrix(...)  # shape: (n_time, n_wavelength)

# WRONG - dimensions don't match
heatmap(wavelength, time, ta_matrix)  # Error! expects (2048, 53)

# CORRECT - transpose the matrix
heatmap(wavelength, time, ta_matrix')  # Works: (2048, 53)
```

This differs from Python/matplotlib convention, which trips up students coming from numpy.

---

## Data Formats & Instrument Integration

### Current: LabVIEW Measurement Files (.lvm)

Pump-probe data stored as tab-separated values:
- **Header**: `CH{n}_{ON|OFF}_{YYMMDD}_{HHMMSS}` format
- **Data**: 4 channels (CH0-CH3), ON/OFF measurements per time point
- **Example**: `sig_250903_154003.lvm` = acquired 2025-09-03 at 15:40:03

### Extensibility for Lab Equipment

**Ti:sapphire/OPA system**: Add export handlers for cavity spectroscopy data
**MIRA 900**: Extend for TMDC-specific pump-probe formats
**FTIR/UV-vis**: Standardize steady-state import functions
**Future instruments**: Follow established patterns in `io.jl`

### File Naming Convention

Use this minimal convention for all spectroscopy data:

```
YYYYMMDD_<sample>_<run>.csv
```

| Component | Description | Example |
|-----------|-------------|---------|
| `YYYYMMDD` | Date (ISO format, sortable) | `20250619` |
| `<sample>` | Human-readable sample ID | `NH4SCN-1M-DMF` |
| `<run>` | Run number (3 digits) | `001` |

**Examples:**
```
20250619_NH4SCN-1M-DMF_001.csv    # 1M ammonium thiocyanate in DMF
20250422_DMF-ref_001.csv          # Pure DMF reference
20250620_MAPbI3-film_002.csv      # Perovskite thin film, second run
```

**Guidelines:**
- Use hyphens within sample IDs, underscores between components
- Technique is encoded by folder (`data/ftir/`, `data/uvvis/`), not filename
- Full metadata lives in the registry; filenames are for humans
- Keep sample IDs short but recognizable

---

## Vertical Team Integration

### Team-Specific Usage Patterns

**VSC Team**: 
- Heavy pump-probe analysis, cavity spectroscopy integration
- Living manuscript approach with automated figure generation
- Theoretical knowledge transfer through documented analysis

**TMDC Team**: 
- Adaptation of pump-probe tools for 2D materials
- Cross-correlation with VSC analysis for comparative studies
- Equipment sharing optimization

**MOF Team**: 
- Steady-state characterization tools
- New data format integration as needed

**Equipment Team**: 
- Maintain and extend instrument-specific import functions
- Support all other teams with standardized analysis

### Knowledge Transfer Protocol

1. **All new analysis capabilities** must be added to QPSTools.jl, not kept in individual projects
2. **Graduating students** must document analysis procedures in package documentation
3. **Team leaders** ensure QPSTools.jl usage in all team publications
4. **Monthly reviews** of package development and feature requests

---

## Quick Start Guide

### Installation
```julia
julia --project=.
using Revise  # Essential for development
using QPSTools
using CairoMakie  # or GLMakie for interactive
```

### Uniform Data Interface (for QPSView and generic tools)

All spectroscopy data types (`TATrace`, `TASpectrum`, `TAMatrix`) implement a common interface:

```julia
# Auto-detect and load any spectroscopy data
data = load_spectroscopy(path)  # Returns TATrace, TASpectrum, or TAMatrix

# Uniform interface functions (work on any type)
xdata(data)      # Primary x-axis values
ydata(data)      # Signal (1D) or secondary axis (2D)
zdata(data)      # Matrix data (2D only, nothing for 1D)
xlabel(data)     # X-axis label string
ylabel(data)     # Y-axis label string
is_matrix(data)  # true for 2D data (TAMatrix)

# Metadata accessors (work on any type)
source_file(data)  # Source filename ("kinetics.lvm", "NH4SCN_DMF_1M.csv")
npoints(data)      # Number of data points (Int for 1D, Tuple for 2D)
title(data)        # Display title (defaults to source_file)

# Generic plotting pattern
if is_matrix(data)
    heatmap(xdata(data), ydata(data), zdata(data)')
else
    lines(xdata(data), ydata(data))
end
```

For raw `PumpProbeData` (low-level access):
```julia
raw = load_lvm(filepath)
raw.axis_type     # time_axis or wavelength_axis
xaxis(raw)        # X-axis data
xaxis_label(raw)  # "Time (ps)" or "Wavelength (nm)"
```

### Transient Absorption Spectra (ΔA vs wavenumber)
```julia
# Load spectrum with wavenumber calibration
spec = load_ta_spectrum("data.lvm"; mode=:OD, calibration=-19.0, time_delay=1.0)

# Access data
spec.wavenumber  # cm⁻¹
spec.signal      # ΔA
spec.time_delay  # ps (if known)
spec.metadata    # Acquisition info

# Plot spectrum
fig, ax = plot_spectrum(spec; title="TA Spectrum at 1 ps")
hlines!(ax, 0; color=:black, linestyle=:dash)
save("figures/spectrum.pdf", fig)

# Plot multiple time delays
fig = Figure()
ax = Axis(fig[1, 1], xlabel="Wavenumber (cm⁻¹)", ylabel="ΔA")
lines!(ax, spec_1ps.wavenumber, spec_1ps.signal, label="1 ps")
lines!(ax, spec_5ps.wavenumber, spec_5ps.signal, label="5 ps")
axislegend(ax)
```

### Kinetic Traces (ΔA vs time)
```julia
# Load kinetic trace (time is automatically shifted so peak is at t=0)
trace = load_ta_trace("kinetics.lvm"; mode=:OD)

# Access data
trace.time      # Time axis (ps)
trace.signal    # ΔA signal
trace.metadata  # Acquisition info
```

### Single Exponential Fit
```julia
# Without IRF (default, for slow dynamics or when τ >> pulse width)
result = fit_exp_decay(trace)

# Access fit parameters
result.tau       # Time constant (ps)
result.amplitude
result.rsquared  # Fit quality

# With IRF deconvolution (best for ultrafast dynamics)
result = fit_exp_decay(trace; irf=true)
result.sigma     # IRF width (Gaussian σ)
result.t0        # Time zero

# Start fit from later time point
result = fit_exp_decay(trace; t_start=1.0)
```

### Multi-exponential Fit
```julia
# Two decay components
result = fit_exp_decay(trace; n_exp=2)

# Access parameters
result.taus       # Vector of time constants [τ_fast, τ_slow]
result.amplitudes # Vector of amplitudes
result.rsquared

# With IRF deconvolution
result = fit_exp_decay(trace; n_exp=2, irf=true)
```

### Global Fit (Shared Parameters)
```julia
# Fit multiple traces with shared τ, σ, and t₀
result = fit_global([trace_esa, trace_gsb]; labels=["ESA", "GSB"])

# Access shared parameters
result.tau       # Shared time constant
result.sigma     # Shared IRF width
result.rsquared  # Overall R²
result.rsquared_individual  # Per-trace R² values
```

### Plotting Kinetics with Residuals
```julia
# Plot with automatic residuals panel (default when fit provided)
fig, ax, ax_res = plot_kinetics(trace; fit=result)
save("figures/kinetics.pdf", fig)

# Plot without residuals panel
fig, ax = plot_kinetics(trace; fit=result, residuals=false)

# Data only (no fit)
fig, ax = plot_kinetics(trace)
```

### Generate Fit Curves
```julia
# Use predict() to get fitted values
y_fit = predict(result, trace)

# Or with custom time axis
y_fit = predict(result, time_array)
```

### Publication Figure Example
```julia
set_theme!(print_theme())
fig = Figure(size=(1000, 400))

# Panel A: Spectra
ax_a = Axis(fig[1, 1], xlabel="Wavenumber (cm⁻¹)", ylabel="ΔA")
lines!(ax_a, spec_1ps.wavenumber, spec_1ps.signal, label="1 ps")
lines!(ax_a, spec_5ps.wavenumber, spec_5ps.signal, label="5 ps")
hlines!(ax_a, 0; color=:black, linestyle=:dash)
axislegend(ax_a)

# Panel B: Kinetics
ax_b = Axis(fig[1, 2], xlabel="Time (ps)", ylabel="ΔA")
scatter!(ax_b, trace.time, trace.signal, label="Data")
lines!(ax_b, trace.time, predict(result, trace), color=:red, label="Fit")
axislegend(ax_b)

save("figures/publication.pdf", fig)
```

---

## Implementation Roadmap

### Phase 1: Foundation (Completed)
- ✅ Basic pump-probe analysis with IRF deconvolution
- ✅ Standard data import pipeline
- ✅ Publication-quality plotting themes

### Phase 2: Lab Integration (Current)
- ✅ Transient absorption spectra (ΔA vs wavenumber)
- ✅ Kinetic trace analysis (ΔA vs time)
- ✅ Multi-exponential fitting (single + biexponential with IRF)
- ✅ Global analysis across multiple datasets
- ✅ Automatic residuals plotting
- ✅ Time-shift to peak convention
- 🔄 Integration with existing projects (VSC team pilot) — process-dependent
- 🔄 Equipment-specific data format support — requires equipment specs

### Phase 3: Advanced Features (Planned)
- ✅ eLabFTW integration (experiment logging, search, attachments)
- ✅ `format_results()` for all fit types (markdown output)
- ✅ Auto-tagging from sample registry metadata
- 📝 Integration with cavity spectroscopy models
- 📝 AI-assisted data quality assessment

### Phase 4: QPSDrive Integration (Future)
QPSDrive.jl handles hardware control and data acquisition. Integration is mostly
already working at the type level — QPSDrive produces `TATrace` (and eventually
`TAMatrix`) objects that QPSTools consumes directly via SpectroscopyTools types.

Remaining work:
- 📝 **QPSDrive TSV loader** — `load_ta_trace()` support for QPSDrive's saved scan files
- 📝 **Scan metadata → eLabFTW** — convenience to auto-tag experiments from scan metadata
- 📝 Automated figure generation for manuscripts

---

## Publication Standards

### Manuscript Integration

All lab publications should:
1. **Use QPSTools.jl** for analysis whenever applicable
2. **Cite the package** in methods sections
3. **Contribute new capabilities** back to the package
4. **Include analysis scripts** as supplementary material

### Figure Quality Standards

- **Use `print_theme()`** for all manuscript figures
- **Save as PDF/SVG** for vector graphics
- **Include error bars** from fitting uncertainties
- **Follow lab color scheme** defined in plotting themes

### Reproducibility Requirements

- **Analysis scripts** must be runnable by other team members
- **Data paths** should be relative to standard lab directory structure
- **Package versions** should be documented in Project.toml

---

## Success Metrics

### Individual Student Impact
- **Time to first analysis**: < 1 hour for standard pump-probe data
- **Analysis consistency**: All students use same fitting procedures
- **Error reduction**: Standardized uncertainty quantification

### Lab-Wide Impact  
- **Code reuse**: > 80% reduction in "coding from scratch"
- **Cross-team collaboration**: Analysis tools shared between projects
- **Publication acceleration**: Faster data-to-manuscript pipeline
- **Knowledge retention**: Analysis capabilities persist after graduation

### Team System Support
- **Manuscript velocity**: Living documents updated with automated analysis
- **Resource efficiency**: Shared tools reduce individual development time
- **Quality consistency**: Standardized analysis across all publications

---

## Contact & Support

**Primary maintainer**: Garrek Stemo
**Development model**: All lab members contribute
**Issue reporting**: Use GitHub issues or lab Slack
**Feature requests**: Discuss with team leaders and assistant professor

---

*QPSTools.jl is more than a software package — it's the technical foundation that enables our lab's transformation from individual projects to collaborative research teams. Every contribution strengthens the entire lab's research capacity.*