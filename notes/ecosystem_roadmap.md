# QPS Spectroscopy Ecosystem

A unified ecosystem for spectroscopy analysis, instrument control, and lab management — from raw data to publication figures to electronic lab notebook.

---

## Full Ecosystem Map

The ecosystem spans three domains: **public libraries** (general spectroscopy), **lab libraries** (QPS-specific), and **lab applications** (GUIs and instrument control).

```
                        PUBLIC LIBRARIES
                    (general, registered/registerable)

CurveFitModels.jl ──────────────────── zero deps, pure math
       │
CurveFit.jl ────────────────────────── fitting backend
       │
SpectroscopyTools.jl ───────────────── base types + algorithms
       │                                 (TATrace, TASpectrum,
       │                                  TAMatrix, PLMap,
       │                                  fit_peaks, fit_exp_decay, ...)
       │
       │               CavitySpectroscopy.jl ──── polariton analysis
       │                       │                  (independent, public)
       │                       │
       ├───────────────────────┘
       │
                         LAB LIBRARIES
                      (QPS-specific, private)

QPSTools.jl ────────────────────────── analysis + plotting + eLabFTW
       │                                 load_ftir, load_raman, load_ta_*,
       │                                 load_pl_map, plot_spectrum,
       │                                 plot_kinetics, registry, themes
       │
       │
       │             SHARED SWIFT INFRASTRUCTURE
       │
       │     QPSKit (Swift Package) ─── shared macOS app components
       │       │                          ServerProcess (launch Julia)
       │       │                          StatusBar, ConnectionBadge
       │       │                          AppearanceMode, StatusLevel
       │       │                          JuliaConnection protocol
       │       │
       │       │
       │       │          LAB APPLICATIONS
       │       │        (GUIs + instruments)
       │       │
       ├───────┼──── QPSLab ─────────── GUI analysis app
       │       │       │                  Electron/Svelte (Windows)
       │       │       │                  SwiftUI/QPSKit (macOS)
       │       │       │                  Julia HTTP server calls QPSTools
       │       │       │
       │       │       │                  see: notes/gui_app_design.md
       │       │       │
       ├───────│──── Student scripts ── Julia REPL / analysis scripts
       │       │
       │       │
QPSDrive.jl ───│──────────────────────── instrument control + scan engine
       │       │                           WebSocket server (JSON protocol)
       │       │                           uses SpectroscopyTools types
       │       │
       └───────┼──── QPSConsole ──────── native macOS scan controller
               │                           SwiftUI/QPSKit, WebSocket to QPSDrive
               │                           Monitor / Scan / Results tabs
               │                           replaces QPSView.jl (deprecated)
               │
               └──── Future TA Viewer ── broadband TA live viewer
                                           SwiftUI/QPSKit, WebSocket
                                           heatmap + slice + DAS views
```

### Communication protocols

HTTP is request/response (app asks, server answers, connection closes). WebSocket is a persistent open connection where either side can send at any time. Analysis is request/response; instrument streaming needs real-time push.

| Connection | Protocol | Why |
|-----------|----------|-----|
| QPSLab frontends ↔ Julia server | HTTP/JSON (localhost) | Analysis is request/response — student clicks "Fit", server replies with results |
| QPSConsole ↔ QPSDrive | WebSocket/JSON (`ws://host:8765`) | Instruments stream live: signal readings, scan progress, stage positions |
| Future TA Viewer ↔ QPSDrive | WebSocket/JSON | Same — live CCD frames during acquisition |

### Package status

| Package | Role | Status | Platform |
|---------|------|--------|----------|
| CurveFitModels.jl | Fitting model functions | Stable | Julia (public) |
| SpectroscopyTools.jl | Base types + algorithms | Active | Julia (public) |
| CavitySpectroscopy.jl | Polariton analysis | Independent | Julia (public) |
| QPSTools.jl | Lab analysis library | Active | Julia (lab) |
| QPSDrive.jl | Instrument control | In dev | Julia (lab) |
| QPSKit | Shared Swift infrastructure | Planned | Swift/macOS |
| QPSConsole | Scan controller GUI | Active | SwiftUI/macOS |
| QPSLab | Analysis GUI | Design phase | Electron + SwiftUI |
| QPSView.jl | Live scan viewer | **Deprecated** → QPSConsole | Julia/GLMakie |

### Competitive landscape

| Tool | Language | Scope | Gap this ecosystem fills |
|------|----------|-------|-----------------------------|
| Igor Pro | Proprietary | General analysis | Open source, reproducible, free |
| OriginLab | Proprietary | General analysis | Same as above |
| Glotaran / pyglotaran | Java / Python | TA global analysis only | Unified with steady-state analysis |
| TAPAS | Python | TA processing + analysis | Julia performance, composable types |
| skultrafast | Python | TA data analysis | Same as above |
| Spectra.jl | Julia | Geoscience spectroscopy | Different domain, incompatible design |
| JASCO software | Proprietary | FTIR instrument | QPSLab replaces for analysis |

**Unique value:** No existing tool covers both steady-state characterization and time-resolved analysis in one ecosystem. A sample goes from FTIR → pump-probe → global analysis using the same types, the same fitting engine, and the same result reporting. That workflow doesn't exist anywhere else. QPSLab puts a GUI on top of it.

---

## Architecture Layers

Regardless of how many packages exist, the architecture always has three layers:

```
Models          Pure math functions: fn(params, x) → y
                No data types, no I/O, no opinions
                    │
Analysis        Algorithms that solve spectroscopy problems
                Types, fitting, baseline, decomposition
                    │
Application     Lab-specific: instrument I/O, registries,
                plotting themes, notebook integration, GUIs
```

**Users interact at the Application layer.** Analysis and Models are invisible infrastructure. A student types `using QPSTools` (scripting) or opens QPSLab (GUI) and gets everything.

---

## SpectroscopyTools.jl Growth Roadmap

A long-term vision for how SpectroscopyTools.jl could grow from a single package into a modular ecosystem. Inspired by the SciML approach: start as a monolith, split along natural fracture lines as the codebase and user base grow.

**Guiding principle:** Don't split preemptively. The interface should emerge from real usage patterns, not upfront design.

### Phase 1: Monolith (Current → Package Registration)

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

QPSTools.jl                    lab layer (exists)
  I/O:        load_lvm, load_ftir, load_raman
  Registry:   sample metadata lookup
  Plotting:   themes, layers, layouts, all plot_* functions
  eLabFTW:    experiment logging
```

**User experience:**
```julia
using QPSTools
using CairoMakie

spec = load_ftir(solute="NH4SCN", concentration="1.0M")
result = fit_peaks(spec, (2000, 2100))
report(result)
fig, ax = plot_spectrum(spec; fit=result, residuals=true)
```

**What to focus on:** Get the API right. Write tests. Register CurveFitModels and SpectroscopyTools. Everything else follows from a solid foundation.

### Phase 2: Extract the Interface (~8,000-10,000 lines)

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

QPSTools.jl
  using SpectroscopyTools      (re-exports everything)
  Lab-specific layer (unchanged)
```

This is the SciMLBase pattern: separate "what things are" from "what you do with them." Downstream packages can depend on SpectroscopyBase without pulling in fitting code, Peaks.jl, SavitzkyGolay, etc.

**The split test:** If you can draw a line in `types.jl` where everything above is pure data definitions and everything below is algorithms, that's your SpectroscopyBase.

### Phase 3: Technique Splits (~15,000-20,000 lines)

**Trigger:** Fluorescence lifetime analysis arrives. Or 2D-IR processing. The codebase has grown enough that independent versioning matters.

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

### Phase 4: Advanced Analysis (~25,000+ lines)

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

### Phase 5: Community Ecosystem (~50,000+ lines, multiple contributors)

**Trigger:** External contributors want to build technique-specific packages on top of SpectroscopyBase.

```
SpectroscopyBase.jl
        │
        ├── [core analysis packages from Phase 4]
        │
        ├── SpectroscopyMakieExt.jl    plotting recipes (weak dep extension)
        │
        │   Community packages (not yours to maintain):
        │
        ├── RamanTools.jl              Raman-specific processing
        ├── FluorescenceTools.jl       fluorescence-specific
        ├── TwoDIR.jl                  2D infrared spectroscopy
        ├── CavitySpectroscopy.jl      your lab — polariton analysis
        │
        └── SpectroscopyTools.jl       umbrella (core packages only)
```

### Dependency graph at maturity

```
                    JULIA                              SWIFT

CurveFitModels.jl ──── zero deps, pure math
       │
CurveFit.jl ────────── fitting backend
       │
SpectroscopyBase.jl ── types + interface               QPSKit ──────── shared macOS infra
       │                                                  │   (ServerProcess, StatusBar,
       ├─ SpectralMath.jl                                 │    ConnectionBadge, protocols)
       ├─ PeakAnalysis.jl                                 │
       ├─ KineticsFitting.jl                              │
       ├─ GlobalAnalysis.jl                               │
       ├─ SpectralDecomposition.jl                        │
       │                                                  │
SpectroscopyTools.jl ── umbrella                          │
       │                                                  │
       ├─ Community packages...                           │
       │                                                  │
QPSTools.jl ──────────── lab layer ──────── QPSLab ───────┤ (macOS: SwiftUI + QPSKit)
       │                                   (Julia HTTP    │ (Windows: Electron/Svelte)
       ├─ Student scripts                    server)      │
       │                                                  │
QPSDrive.jl ──────────── instruments ────── QPSConsole ───┤ (SwiftUI + QPSKit)
                                                          │
                                            TA Viewer ────┘ (SwiftUI + QPSKit, future)
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

4. **QPSTools stays the lab layer.** It never contains general-purpose spectroscopy code. It's I/O, registry, eLabFTW, and Makie plotting on top.

5. **The API doesn't change when packages split.** If `fit_peaks(x, y)` works in Phase 1, it works in Phase 5. Internal reorganization is invisible to users.

6. **QPSLab is a consumer, not a replacement.** Every analysis capability in the GUI must exist as a QPSTools function first. The GUI is a thin layer. New features always land in QPSTools/SpectroscopyTools, never in the GUI.

---

## Licensing and Commercial Strategy

The ecosystem splits into open and commercial along a natural boundary:

### Open Source (MIT)

- **CurveFitModels.jl** — pure math, zero deps
- **CurveFit.jl** — fitting backend
- **SpectroscopyTools.jl** (and future sub-packages) — general spectroscopy algorithms

These are commodity operations every spectroscopist needs.
MIT license builds community, attracts contributors, and establishes SpectroscopyTools as a standard Julia spectroscopy package.
Scientists can inspect the algorithms their analysis depends on — builds trust.

### Commercial

- **QPSTools.jl** — instrument connectors (LVM, JASCO, etc.), eLabFTW integration, lab-specific workflows.
  The proprietary value is domain knowledge about specific instruments and lab data formats.
  Expanding to other labs requires handling vendor-specific formats (WITec, Horiba, Renishaw, etc.) — either via a plugin/adapter model or by standardizing on the HDF5 interchange schema.

- **QPSLab** — the GUI application.
  Multi-technique analysis workspaces (PL maps now, single-spectrum and TA analysis planned).
  Each workspace type maps to a SpectroscopyTools data type and analysis flow.
  The GUI is where all the pieces come together for end users who don't write code.

### Why this split works

| Layer | License | Rationale |
|-------|---------|-----------|
| Algorithms | MIT | Commodity — everyone needs them, community contributions improve quality |
| Instrument I/O + lab integration | Commercial | Domain knowledge — encodes specific instrument formats and lab workflows |
| GUI | Commercial | User experience — ties algorithms + I/O into a polished analytical tool |

Open algorithms make the commercial products more trustworthy.
Commercial products fund continued development of the open libraries.
The HDF5 project schema is a vendor-neutral interchange format that could become a community standard.
