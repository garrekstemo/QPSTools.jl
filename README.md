# QPS.jl - Quantum Photo-Science Laboratory Analysis Package

**The standardized analysis package for all lab members.**

This package provides common tools for spectroscopic data analysis, pump-probe measurements, and publication-quality plotting. **All students should use QPS.jl** to ensure consistency and enable collaboration across research projects.

## Quick Start

### Installation

```julia
# In Julia REPL, navigate to project directory
julia --project=.

# Install dependencies (first time only)
using Pkg; Pkg.instantiate()

# Load the package
using QPS
```

### Basic Usage

```julia
using QPS, CairoMakie

# Set up publication-quality plots
setup_publication_plot()

# Load experimental data
data = load_lvm("your_data.lvm")

# Calculate change in absorbance  
ΔA = calc_ΔA(data)

# Fit exponential decay
result = fit_decay_trace(data.time, ΔA; 
    truncate_time=0.5,    # Start fitting 0.5 ps after t0
    initial_tau=2.0       # Initial guess for time constant
)

# Extract fitted parameters
τ, στ = extract_tau(result.fit)
println("Time constant: $τ ± $στ ps")

# Create publication figure
fig, ax = plot_kinetics(data.time, ΔA)
lines!(ax, data.time, model_prediction, 
    color=lab_colors()[:fit], linestyle=:dash, 
    label="Fit (τ = $τ ps)")
save("kinetics.pdf", fig)
```

## Core Features

### 🔬 Spectroscopic Analysis
- **calc_ΔA**: Calculate absorbance changes from transient data
- **fit_decay_trace**: Exponential decay fitting with configurable models
- **fit_global_decay**: Global kinetics analysis across multiple wavelengths
- **subtract_spectrum**: Baseline subtraction and solvent correction
- **calc_fwhm**: Peak width analysis with automated smoothing

### 📊 Standardized Plotting
- **publication_theme()**: High-quality figures for papers
- **poster_theme()**: Large fonts for conference posters  
- **compact_theme()**: Space-efficient multi-panel layouts
- **lab_colors()**: Consistent color schemes across all lab publications
- **plot_spectrum()**, **plot_kinetics()**: Common plot types with sensible defaults

### ⚡ Pump-Probe Analysis
- **PumpProbeData**: Structured data handling
- **fit_decay_irf()**: Instrument response function deconvolution
- **process_pumpprobe()**: End-to-end analysis pipeline

### 🧹 Data Processing
- **linear_baseline_correction**: Automated baseline removal
- **savitzky_golay**: Peak-preserving smoothing
- **smooth_data**: Moving average filtering

## Research Squad Integration

This package supports our lab's transformation to vertical research squads:

- **VSC Squad**: Use cavity spectrum fitting and polariton analysis tools
- **TMDC Squad**: Apply standard pump-probe analysis to 2D materials
- **MOF Squad**: Utilize FTIR processing and kinetics analysis
- **Equipment Squad**: Develop new analysis modules for emerging techniques

## Examples

### Basic Spectrum Analysis
```julia
using QPS, CairoMakie
setup_publication_plot()

# Load and process FTIR data
sample = load_spectrum("sample.lvm") 
solvent = load_spectrum("solvent.lvm")

# Subtract solvent background
corrected = subtract_spectrum(sample, solvent)

# Apply baseline correction
final = linear_baseline_correction(
    corrected.x, corrected.y, (1950, 2150)
)

# Plot result
fig, ax = plot_spectrum(final.x, final.y, 
    ylabel="Corrected Absorbance")
save("corrected_spectrum.pdf", fig)
```

### Kinetics Analysis
```julia
# Load time-resolved data
data = load_lvm("kinetics.lvm")
ΔA = calc_ΔA(data, mode=:transmission)

# Fit single exponential
result = fit_decay_trace(data.time, ΔA; 
    truncate_time=0.3, initial_tau=1.8)
    
# Extract and report results
τ, στ = extract_tau(result.fit)
println("Lifetime: $τ ± $στ ps")

# Global analysis across multiple traces
signals = [ΔA_probe1, ΔA_probe2, ΔA_probe3]
global_result = fit_global_decay(data.time, signals; 
    start_idx=result.start_idx, initial_tau=τ)
```

### Multi-Panel Publication Figure
```julia
using CairoMakie
set_theme!(publication_theme())

fig = Figure(size=(800, 600))

# Panel A: Spectrum
ax1 = Axis(fig[1, 1], xlabel="Wavenumber (cm⁻¹)", 
    ylabel="ΔA", title="(a)")
lines!(ax1, wavenumber, spectrum, color=lab_colors()[:primary])

# Panel B: Kinetics  
ax2 = Axis(fig[1, 2], xlabel="Time (ps)", 
    ylabel="ΔA", title="(b)")
lines!(ax2, time, kinetics, color=lab_colors()[:kinetics])
lines!(ax2, time, fit, color=lab_colors()[:fit], linestyle=:dash)

save("figure2.pdf", fig)
```

## Installation & Setup

### First Time Setup
```bash
# Clone or download to your local machine
cd /Users/your-username/Documents/projects/
git clone <repository-url> QPS.jl
cd QPS.jl

# Start Julia in project mode
julia --project=.

# Install all dependencies
julia> using Pkg; Pkg.instantiate()
```

### Daily Usage
```julia
# Start Julia with the package
julia --project=/path/to/QPS.jl

# Load for analysis
using QPS, CairoMakie
setup_publication_plot()

# Your analysis here...
```

## Package Philosophy

1. **Standardization over customization**: Use provided functions rather than writing from scratch
2. **Theme-based plotting**: Let themes handle styling, focus on data
3. **Semantic naming**: Use `lab_colors()[:primary]` not `"#1f77b4"`
4. **Reproducible analysis**: Save scripts alongside figures
5. **Documentation**: Comment your analysis for future lab members

## Contributing

All lab members are expected to contribute improvements:

1. **Report bugs**: Use GitHub issues for problems
2. **Suggest features**: Propose new analysis functions needed for your research
3. **Contribute code**: Add project-specific functions that could benefit others
4. **Improve documentation**: Update examples and docstrings

### Adding New Functions
```julia
# Add to appropriate file (spectroscopy.jl, plotting.jl, etc.)
# Follow existing documentation patterns
# Export in main QPS.jl module
# Add tests if possible
```

## Requirements

- **Julia 1.10+** (LTS version)
- **CurveFit.jl**: For all curve fitting (lab standard)
- **Makie.jl ecosystem**: CairoMakie (publications), GLMakie (interactive)

## Support

- **Questions**: Ask squad members or Garrek
- **Documentation**: Check function docstrings with `?function_name`
- **Examples**: See analysis/ directory for real-world usage
- **Issues**: Report problems via GitHub issues

---

**This package is the technical foundation of our lab transformation to high-output research squads. Using QPS.jl consistently is essential for lab-wide collaboration and knowledge retention.**