# SpectroscopyTools.jl Ecosystem Roadmap

A long-term vision for how SpectroscopyTools.jl could grow from a single package into a modular ecosystem for spectroscopy in Julia. Inspired by the SciML approach: start as a monolith, split along natural fracture lines as the codebase and user base grow.

**Guiding principle:** Don't split preemptively. The interface should emerge from real usage patterns, not upfront design. SciML started as DifferentialEquations.jl (one package) and split as it grew. We do the same.

---

## The Three-Layer Architecture

Regardless of how many packages exist, the architecture always has three layers:

```
Models          Pure math functions: fn(params, x) → y
                No data types, no I/O, no opinions
                    │
Analysis        Algorithms that solve spectroscopy problems
                Types, fitting, baseline, decomposition
                    │
Application     Lab-specific: instrument I/O, registries,
                plotting themes, notebook integration
```

**Users interact at the Application layer.** Analysis and Models are invisible infrastructure. A student types `using QPS` and gets everything.

---

## Phase 1: Monolith (Current → Package Registration)

**Trigger:** Get something working and registered.

```
CurveFitModels.jl             model functions (exists, zero deps)
CurveFit.jl                   fitting backend (exists)

SpectroscopyTools.jl           monolith: types + all analysis
  ~4,000 lines
  Types:      AbstractSpectroscopyData, TATrace, TASpectrum, TAMatrix
              PeakInfo, PeakFitResult, MultiPeakFitResult
              TAPeak, TASpectrumFit
              ExpDecayFit, MultiexpDecayFit, GlobalFitResult
  Steady:     find_peaks, fit_peaks, fit_ta_spectrum, baseline correction, smoothing
  Kinetics:   fit_exp_decay (n_exp=1..N), fit_global, IRF convolution
  Chirp:      detect_chirp, correct_chirp, subtract_background
  Utilities:  normalize, subtract, FWHM, unit conversions
  Reporting:  report(), format_results()

QPS.jl                         lab layer (exists)
  I/O:        load_lvm, load_ftir, load_raman
  Registry:   sample metadata lookup
  Plotting:   themes, layers, layouts, all plot_* functions
  eLabFTW:    experiment logging
```

**User experience:**
```julia
using QPS
using CairoMakie

spec = load_ftir(solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))
report(result)
fig, ax = plot_spectrum(spec; fit=result, residuals=true)
```

**What to focus on:** Get the API right. Write tests. Register CurveFitModels and SpectroscopyTools. Everything else follows from a solid foundation.

---

## Phase 2: Extract the Interface (~8,000-10,000 lines)

**Trigger:** Someone wants to depend on your types but not your fitting code. Or you want a Makie extension that doesn't pull in the entire fitting stack.

```
SpectroscopyBase.jl            NEW — types + interface + result structs
  ~1,500 lines
  AbstractSpectroscopyData hierarchy
  All fit result types (PeakFitResult, ExpDecayFit, etc.)
  Interface: xdata(), ydata(), xlabel(), is_matrix()
  Accessors: predict(), residuals(), report(), format_results()
  PeakInfo struct + peak_table()
  Minimal deps: just Statistics

SpectroscopyTools.jl           analysis algorithms + umbrella
  using SpectroscopyBase       (re-exports all types)
  Peak fitting, baseline, smoothing
  Exponential decay, IRF, global fitting
  Unit conversions, spectral math

QPS.jl
  using SpectroscopyTools      (re-exports everything)
  Lab-specific layer (unchanged)
```

This is the SciMLBase pattern: separate "what things are" from "what you do with them." Downstream packages can depend on SpectroscopyBase without pulling in fitting code, Peaks.jl, SavitzkyGolay, etc.

**The split test:** If you can draw a line in `types.jl` where everything above is pure data definitions and everything below is algorithms, that's your SpectroscopyBase.

---

## Phase 3: Technique Splits (~15,000-20,000 lines)

**Trigger:** Fluorescence lifetime analysis arrives. Or 2D-IR processing. The codebase has grown enough that independent versioning matters, and you find yourself avoiding changes to kinetics code because it might break peak fitting.

```
SpectroscopyBase.jl              types + interface (stable, rarely changes)
        │
        ├── SpectralMath.jl      lightweight utilities everyone needs
        │     normalize, subtract, smooth, FWHM
        │     unit conversions (cm⁻¹ ↔ nm ↔ eV)
        │     transmittance ↔ absorbance
        │     ~500 lines
        │
        ├── PeakAnalysis.jl      peak detection + peak fitting + baseline
        │     find_peaks, fit_peaks, peak_table
        │     als_baseline, arpls_baseline, snip_baseline
        │     Uses: SpectralMath, CurveFitModels, CurveFit, Peaks.jl
        │     ~800 lines
        │     Audience: every spectroscopist
        │
        ├── KineticsFitting.jl   time-domain fitting
        │     fit_exp_decay (n_exp=1..N), fit_global
        │     IRF convolution (analytical erfc-based)
        │     Multi-exponential with shared parameters
        │     Uses: SpectralMath, CurveFitModels, CurveFit
        │     ~1,000 lines
        │     Audience: ultrafast TA + fluorescence lifetime
        │
        └── SpectroscopyTools.jl umbrella — re-exports all of the above
```

**The key fracture line: PeakAnalysis vs KineticsFitting.** A Raman chemist never calls `fit_exp_decay`. An ultrafast physicist rarely calls `fit_peaks` on a static spectrum. But both call `normalize` and `subtract_spectrum`.

**User experience is unchanged:**
```julia
using SpectroscopyTools  # gets everything

# OR, for a lightweight Raman pipeline:
using SpectroscopyBase
using PeakAnalysis
```

---

## Phase 4: Advanced Analysis (~25,000+ lines)

**Trigger:** You implement target analysis, SVD, or MCR-ALS. These are substantial algorithmic packages, each potentially paper-worthy.

```
SpectroscopyBase.jl              types + interface
        │
        ├── SpectralMath.jl      utilities (unchanged)
        │
        ├── PeakAnalysis.jl      peaks + baseline (unchanged)
        │
        ├── KineticsFitting.jl   exponential decay + IRF (unchanged)
        │
        ├── GlobalAnalysis.jl    NEW — global + target analysis
        │     Compartment models
        │     Decay-associated spectra (DAS)
        │     Species-associated spectra (SAS)
        │     Spectral constraints
        │     Uses: KineticsFitting, SpectralMath
        │     The Glotaran/pyglotaran competitor
        │
        ├── SpectralDecomposition.jl  NEW — matrix factorization
        │     Singular Value Decomposition (SVD)
        │     Multivariate Curve Resolution (MCR-ALS)
        │     Non-negative Matrix Factorization (NMF)
        │     Evolving Factor Analysis (EFA)
        │     Uses: SpectroscopyBase, LinearAlgebra
        │
        └── SpectroscopyTools.jl umbrella (re-exports everything)
```

At this point, `GlobalAnalysis.jl` is doing what Glotaran does — but in Julia, with composable types, and integrated with the same ecosystem that handles peak fitting and baseline correction. That's the value proposition no Python tool offers.

---

## Phase 5: Ecosystem (~50,000+ lines, multiple contributors)

**Trigger:** External contributors want to build technique-specific packages on top of SpectroscopyBase. You no longer own every package — the ecosystem grows beyond your lab.

```
SpectroscopyBase.jl
        │
        ├── [core analysis packages from Phase 4]
        │
        ├── SpectroscopyMakieExt.jl    plotting recipes (weak dep extension)
        │     Generic plot_spectrum, plot_kinetics, plot_heatmap
        │     No themes — users set their own
        │
        │   Community packages (not yours to maintain):
        │
        ├── RamanTools.jl              Raman-specific processing
        │     Cosmic ray removal
        │     Stokes / anti-Stokes correction
        │     Fluorescence background removal
        │     Raman tensor analysis
        │
        ├── FluorescenceTools.jl       fluorescence-specific
        │     Lifetime fitting (uses KineticsFitting internally)
        │     Quantum yield calculation
        │     FRET analysis
        │     Stern-Volmer
        │
        ├── TwoDIR.jl                  2D infrared spectroscopy
        │     Phasing, zero-padding, apodization
        │     Diagonal / cross-peak analysis
        │     Center-line slope
        │     Spectral diffusion
        │
        ├── CavitySpectroscopy.jl      your lab — polariton analysis
        │     Coupled oscillator models
        │     Rabi splitting extraction
        │     Hopfield coefficients
        │
        └── SpectroscopyTools.jl       umbrella (core packages only)
```

**QPS.jl at this stage:**
```
QPS.jl
  using SpectroscopyTools        (all core analysis)
  using CavitySpectroscopy       (lab research area)
  Lab I/O, registry, eLabFTW, themes, plotting pipeline
```

---

## Dependency Graph at Maturity

```
CurveFitModels.jl ─────────────────────── zero deps, pure math
       │
CurveFit.jl ──────────────────────────── fitting backend
       │
SpectroscopyBase.jl ──────────────────── types + interface (Statistics only)
       │
       ├─ SpectralMath.jl ────────────── utilities (Unitful, SavitzkyGolay)
       │       │
       ├─ PeakAnalysis.jl ───────────── peaks + baseline (Peaks.jl)
       │       │
       ├─ KineticsFitting.jl ────────── decay + IRF
       │       │
       ├─ GlobalAnalysis.jl ─────────── target analysis (uses Kinetics)
       │       │
       ├─ SpectralDecomposition.jl ──── SVD, MCR-ALS, NMF
       │
SpectroscopyTools.jl ─────────────────── umbrella: re-exports everything
       │
       ├─ RamanTools.jl ─────────────── community
       ├─ FluorescenceTools.jl ──────── community
       ├─ TwoDIR.jl ────────────────── community
       ├─ CavitySpectroscopy.jl ─────── your lab
       │
QPS.jl ───────────────────────────────── lab application layer
```

---

## When to Split

Don't split because the architecture diagram looks clean. Split when you feel the pain.

| Signal | Action |
|--------|--------|
| A file exceeds ~1,000 lines with unrelated sections | Consider splitting the file, not the package |
| Someone wants your types but not your algorithms | Extract SpectroscopyBase |
| A new technique shares *some* analysis but not all | Split along the technique boundary |
| You avoid touching kinetics code because it might break peak fitting | Split into separate packages |
| An external contributor wants to own a subpackage | Give them their own repo under an org |
| CI takes too long because unrelated tests run together | Split to get independent test suites |
| You're coordinating breaking changes across >3 files for one feature | The package is too big |

And conversely — signals that you should **not** split yet:

| Signal | Stay monolithic |
|--------|----------------|
| Total source < 10,000 lines | One package is fine |
| Only 1-2 contributors | Coordination overhead isn't worth it |
| All users want all features | No one benefits from partial installs |
| You're still changing the type hierarchy | Stabilize before extracting Base |

---

## What Stays Constant Across All Phases

1. **`using SpectroscopyTools` always works.** The umbrella re-exports everything. Users who want the full toolkit never think about sub-packages.

2. **Types defined once, used everywhere.** Whether it's one package or ten, `TATrace` is `TATrace`. Result types don't change when algorithms move between packages.

3. **CurveFitModels stays independent.** Zero dependencies, pure math functions. This never merges into anything.

4. **QPS stays the lab layer.** It never contains general-purpose spectroscopy code. It's I/O, registry, eLabFTW, and Makie plotting on top.

5. **The API doesn't change when packages split.** If `fit_peaks(x, y)` works in Phase 1, it works in Phase 5. Internal reorganization is invisible to users.

---

## Competitive Landscape

For context on where this ecosystem would sit relative to existing tools:

| Tool | Language | Scope | Gap SpectroscopyTools fills |
|------|----------|-------|-----------------------------|
| Igor Pro | Proprietary | General analysis | Open source, reproducible, free |
| OriginLab | Proprietary | General analysis | Same as above |
| Glotaran / pyglotaran | Java / Python | TA global analysis only | Unified with steady-state analysis |
| TAPAS | Python | TA processing + analysis | Julia performance, composable types |
| skultrafast | Python | TA data analysis | Same as above |
| Spectra.jl | Julia | Geoscience spectroscopy | Different domain, incompatible design |

The unique value: **no existing tool covers both steady-state characterization and time-resolved analysis in one ecosystem.** A sample goes from FTIR → pump-probe → global analysis using the same types, the same fitting engine, and the same result reporting. That workflow doesn't exist anywhere else.
