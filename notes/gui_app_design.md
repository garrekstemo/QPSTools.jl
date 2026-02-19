# QPSLab — GUI Application Design Document

**Date**: 2026-02-17
**Status**: Design phase — pre-implementation

## Vision

A desktop application for routine spectroscopy analysis that replaces vendor software (JASCO, etc.) with a modern, unified tool built on the QPSTools.jl analysis engine. Students open their data files, the app recognizes the data type, and presents the appropriate workspace — no coding required for standard workflows.

The app is **not** a replacement for Julia scripting. Power users and custom analysis still use QPSTools.jl directly. The GUI covers the 80% of routine work that doesn't need scripting.

---

## Architecture

### Three-layer stack

```
┌──────────────────────────────────────────────┐
│           Frontend (UI layer)                │
│                                              │
│   ┌─────────────┐     ┌──────────────────┐   │
│   │   SwiftUI   │     │  Electron/Svelte │   │
│   │   (macOS)   │     │  (Windows/Linux) │   │
│   └──────┬──────┘     └────────┬─────────┘   │
│          │    HTTP/JSON        │              │
│          └─────────┬───────────┘              │
│                    │                          │
│   ┌────────────────┴─────────────────────┐   │
│   │        Julia HTTP Server             │   │
│   │        (HTTP.jl + JSON3.jl)          │   │
│   │                                      │   │
│   │   QPSTools.jl / SpectroscopyTools.jl │   │
│   │   CairoMakie (publication export)    │   │
│   └──────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

### Why two frontends?

- **SwiftUI** for macOS: native feel, excellent window management, the team lead (Garrek) knows SwiftUI.
- **Electron/Svelte** for Windows: lab PCs run Windows, students need cross-platform access.
- **Same API**: both frontends are thin clients calling the same Julia HTTP server on localhost.

### Prior art: QPSConsole

QPSConsole (`/Users/garrek/Documents/projects/QPSConsole/`) is an existing SwiftUI app that controls lab instruments via QPSDrive.jl. It proves out the architecture and provides reusable patterns.

QPSConsole uses **WebSocket** because instrument control is bidirectional and real-time — the server pushes signal readings and scan progress without being asked. QPSLab uses **HTTP** because analysis is request/response — the student clicks "Fit", the server replies with results. Simpler protocol, same launch and state patterns.

### QPSKit — shared Swift infrastructure

Shared components extracted from QPSConsole into a Swift Package, used by all QPS macOS apps (QPSConsole, QPSLab macOS, future broadband TA viewer).

```
QPSKit/
├── Package.swift
└── Sources/QPSKit/
    ├── ServerProcess.swift        ← launch/monitor/terminate Julia
    ├── StatusBar.swift            ← status message + level + icon
    ├── ConnectionBadge.swift      ← colored dot + label + value
    ├── AppearanceMode.swift       ← light/dark/system enum
    ├── StatusLevel.swift          ← info/warning/error enum
    ├── ConnectionStatus.swift     ← connected/disconnected/busy enum
    └── JuliaConnection.swift      ← protocol for HTTP + WebSocket backends
```

| Component | What it provides | Used by |
|-----------|-----------------|---------|
| `ServerProcess` | Launch Julia with project path, monitor stdout for `READY`, timeout, graceful shutdown (`SIGINT` → wait → `SIGTERM`) | All apps that start a Julia server |
| `StatusBar` | Status message with level-based icon and color (info/warning/error) | All apps |
| `ConnectionBadge` | Colored status dot + label + value, hover highlight | All apps (instrument badges, correction indicators, connection status) |
| `JuliaConnection` protocol | `isConnected`, `statusMessage`, `statusLevel` — shared interface for both HTTP and WebSocket connection types | StatusBar and ConnectionBadge work against this protocol |
| `AppearanceMode` | Light/dark/system toggle enum | All apps |

Each app provides its own conforming connection type:
- QPSConsole: `LabConnection` (WebSocket, bidirectional streaming)
- QPSLab macOS: `AnalysisConnection` (HTTP, request/response)
- Future TA Viewer: `TAConnection` (WebSocket, live CCD frames)

### Why not Tauri?

Tauri was considered (lighter than Electron, Rust backend). Electron was chosen for ecosystem maturity — larger community, more available components, better documentation, and AI tools generate Electron/Svelte code very effectively due to massive training data. The bundle size tradeoff (150+ MB for Chromium) is acceptable for a lab desktop tool.

### Julia server model

- **Stateful**: the server holds loaded datasets in memory. One student, one session, localhost only.
- **Session-based**: a session tracks loaded datasets, their correction pipelines, and fit results.
- **Local process**: the Julia server starts when the app launches and stops when it closes. Not a web service.

Future option: PackageCompiler.jl sysimage for fast startup.

---

## Fundamental Design Principles

### 1. Raw data first

Upon load, ALL data is shown raw and unprocessed. Background subtraction, normalization, and any other corrections are explicit user actions, never automatic. The user must always be able to see their original data.

### 2. Non-destructive corrections

Raw data is never modified in memory. Corrections (background subtraction, normalization, baseline correction, smoothing) are applied as a pipeline of reversible layers — like adjustment layers in Photoshop or Lightroom. Each correction can be toggled off or removed. The processing chain is visible to the user:

```
Raw Data → [BG Subtracted ✕] → [Baseline Corrected ✕]
```

### 3. Data chooses the UI

The app auto-detects the data type on load and configures the workspace to match. Students don't select a "mode" — they open a file and the appropriate tools appear. This mirrors how scientists think: "I have this data" not "I want to use the PL Map module."

### 4. Hybrid rendering

- **Frontend renders** interactive plots for exploration (hover, zoom, click-to-select, pan). Uses a JavaScript charting library in Electron, Swift Charts in SwiftUI.
- **Julia renders** publication-quality figures for export via CairoMakie. These are the polished, themed figures that go into papers.

### 5. Analysis and display are separate

The GUI never triggers analysis implicitly. Loading a file doesn't fit anything. Clicking a pixel shows the raw spectrum, not an auto-fit. The student explicitly requests fits, corrections, and exports. The app responds to what the user asks for.

---

## Window and Navigation Model

### Tabbed documents

Each loaded dataset is a tab at the top of the window. Click a tab to switch workspaces. This is the primary navigation model and works identically on both platforms.

### Future: split view

Drag a tab to the side to split the window — two datasets side by side. This enables comparison (e.g., two PL maps from different conditions). Deferred to v2.

### macOS bonus: pop-out windows

On SwiftUI, dragging a tab out of the window creates a native macOS window. This is free behavior from the SwiftUI window model.

---

## Workspace Layout

All workspaces share a four-zone layout:

```
┌─────────────────────────────────────────────────────┐
│  Toolbar: [Open] [Save ▼] [eLabFTW ▼] [Corrections]│
├─────────────┬───────────────────────┬───────────────┤
│             │                       │               │
│  Navigator  │    Primary View       │   Inspector   │
│             │                       │               │
│  (varies)   │    (varies)           │   (varies)    │
│             │                       │               │
├─────────────┴───────────────────────┴───────────────┤
│  Detail Panel                                       │
└─────────────────────────────────────────────────────┘
```

What fills each zone depends on the data type:

| Zone | PL / Raman Map | FTIR / Raman Spectrum | TA Kinetics | TA Matrix (Broadband) |
|------|----------------|----------------------|-------------|----------------------|
| **Navigator** | Pixel grid / thumbnail | *(collapsed or file list)* | Trace selector (wavelengths) | *(collapsed or time list)* |
| **Primary View** | Spatial heatmap | Spectrum plot | Kinetics plot (overlaid traces) | Time x wavelength heatmap |
| **Inspector** | Pixel info, correction stack, fit params | Fit parameters, peak table, correction stack | Fit parameters, time constants | Slice info, correction stack |
| **Detail Panel** | Spectrum at clicked pixel + fit | *(merged with Primary — spectrum IS the main view)* | *(merged with Primary)* | Extracted spectrum or kinetics + fit |

For single-spectrum types (FTIR, Raman, TA kinetics), the Primary View and Detail Panel merge — the spectrum/trace is the main view and fit controls live in the Inspector.

### Heatmap modes

For 2D data types (PL Map, TA Matrix), the heatmap in Primary View can switch between:

- **Raw**: integrated intensity (default on load — raw data first)
- **Fit results** (after fit-all): peak center, FWHM, intensity, R-squared
- Failed pixels shown as grey/missing with option to click and manually adjust

---

## Data Types and Auto-Detection

The Julia server's `/load` endpoint returns a `type` field that drives workspace selection:

| File input | Detected type | Workspace |
|-----------|---------------|-----------|
| CCD .lvm raster scan | `pl_map` | Map workspace |
| JASCO .csv | `spectrum` | Spectrum workspace |
| LabVIEW pump-probe .lvm (wavenumber) | `ta_spectrum` | Spectrum workspace |
| LabVIEW pump-probe .lvm (time) | `ta_trace` | Kinetics workspace |
| Broadband TA (axis files) | `ta_matrix` | Matrix workspace |

This maps directly to existing QPSTools types: `PLMap`, `AnnotatedSpectrum` / `TASpectrum`, `TATrace`, `TAMatrix`.

---

## API Surface

### Session Management

```
POST   /session
       → { session_id }

DELETE /session/{session_id}
```

### Data Loading

```
POST   /load
       { session_id, path }
       → { dataset_id, type: "pl_map" | "spectrum" | "ta_trace" | "ta_matrix",
           metadata: { ... type-specific info ... } }

       For pl_map:    { grid_size, wavelength_range, spatial_extent }
       For spectrum:  { x_unit, x_range, n_points, source_file }
       For ta_trace:  { time_range, wavelength, n_points }
       For ta_matrix: { time_range, wavelength_range, shape }
```

### Data Retrieval (frontend rendering)

```
GET    /dataset/{id}/view
       ?mode=integrated              (pl_map: integrated, peak_center, fwhm, ...)
       → { type-appropriate data for frontend to render }

       For pl_map heatmap: { x_positions, y_positions, z_values, x_label, y_label, z_label }
       For spectrum:       { x, y, x_label, y_label }
       For ta_trace:       { time, signal, x_label, y_label }
       For ta_matrix:      { wavelength, time, data, x_label, y_label }
```

### PL Map — Pixel Spectrum Extraction

```
GET    /dataset/{id}/spectrum
       ?row=3&col=5
       → { wavelength, intensity }
```

### Non-Destructive Correction Pipeline

```
POST   /dataset/{id}/corrections
       { type: "background" | "baseline" | "normalize" | "smooth",
         params: { ... method-specific ... } }
       → { correction_id, preview: { ... corrected view data ... } }

       Background params: { method: "auto" | "manual" | "range",
                            positions: [[r,c], ...],
                            wavelength_range: [a, b] }
       Baseline params:   { method: "als" | "arpls" | "snip", ... }
       Normalize params:  { method: "minmax" | "area" }

GET    /dataset/{id}/corrections
       → [{ correction_id, type, params, active: true }]

DELETE /dataset/{id}/corrections/{correction_id}

PATCH  /dataset/{id}/corrections/{correction_id}
       { active: true | false }         ← toggle without removing
```

All data retrieval endpoints (`/view`, `/spectrum`) automatically apply active corrections. The frontend doesn't need to manage corrected data — it always gets the result of the current pipeline.

### Fitting — Peaks (spectra)

```
POST   /dataset/{id}/fit
       { type: "peaks",
         region: [x_min, x_max],
         model: "gaussian" | "lorentzian" | "pseudo_voigt",
         n_peaks: 1,
         baseline_order: 0 }
       → { fit_id,
           peaks: [{ center, intensity, fwhm, ... }],
           r_squared,
           fit_curve: { x, y },
           components: [{ x, y }, ...],
           residuals: { x, y } }
```

### Fitting — Exponential Decay (kinetics)

```
POST   /dataset/{id}/fit
       { type: "decay",
         n_exp: 1 | 2,
         irf: true | false,
         t_start: null | float }
       → { fit_id,
           taus: [float, ...],
           amplitudes: [float, ...],
           sigma: float | null,
           t0: float | null,
           r_squared,
           fit_curve: { x, y },
           residuals: { x, y } }
```

### Fitting — All Pixels (PL Map batch)

```
POST   /dataset/{id}/fit_all
       { model: "gaussian", n_peaks: 1,
         region: [wavelength_min, wavelength_max] }
       → { job_id }

GET    /job/{job_id}
       → { status: "running" | "completed" | "failed",
           progress: 0.0-1.0,
           result: {
             pixel_results: [[row, col, center, fwhm, intensity, r_squared], ...],
             n_converged, n_failed, median_r_squared
           } }
```

Fit-all may be fast enough to return synchronously, but the async pattern with job_id is safer and allows a progress indicator in the frontend.

### Export — Figures (CairoMakie rendered)

```
POST   /export/figure
       { dataset_id,
         view: "heatmap" | "spectrum" | "fit" | "fit_context",
         pixel: [row, col],            ← for spectrum/fit views from maps
         format: "png" | "pdf" | "svg",
         theme: "print" | "qps" }
       → { image_base64, suggested_filename }
```

### Export — Data

```
POST   /export/data
       { dataset_id,
         what: "corrected" | "fit_results" | "raw",
         format: "csv" | "json" }
       → { data, suggested_filename }
```

### Export — eLabFTW

```
POST   /export/elab
       { dataset_id,
         title: "PL Map: MoSe2 flake A",
         body: "optional notes",
         include: ["figure", "fit_results", "corrected_data"],
         figure_options: { view, format, ... },
         tags: ["pl", "mose2"],
         extra_tags: [] }
       → { experiment_id, url }
```

---

## MVP Scope: PL Map Workflow

### User story

A student has a PL map `.lvm` file from a CCD raster scan. They want to:

1. Open the file in the app
2. See the spatial heatmap (integrated intensity)
3. Click a pixel to see its spectrum
4. Subtract background (explicit action)
5. Fit a single Gaussian peak at one pixel to check parameters
6. Fit all pixels
7. View heatmap of peak positions / FWHM
8. Identify and manually adjust failed pixels (grey on heatmap)
9. Save a figure of the heatmap
10. Save a figure of a representative spectrum + fit
11. Export fit results as CSV
12. Log to eLabFTW

### Implementation phases

| Phase | Scope | Depends on |
|-------|-------|-----------|
| **1. Julia HTTP API** | HTTP.jl server skeleton, session management, PL Map endpoints: load, heatmap data, spectrum extraction, background subtraction, single-pixel fit, fit-all, export (CairoMakie figure + CSV) | QPSTools.jl (existing) |
| **2. Electron/Svelte shell** | App skeleton, file open dialog, tab management, 4-zone layout scaffold, app launch starts Julia server | Phase 1 (API to call) |
| **3. PL Map workspace** | Heatmap rendering (JS charting lib), click-to-spectrum, fit controls panel, results display, correction pipeline UI | Phase 2 (shell to build in) |
| **4. Export integration** | Save menu (figure format selection, data export), eLabFTW menu (title, tags, what to include) | Phase 3 (results to export) |
| **5. Spectrum workspace** | FTIR/Raman — reuse spectrum viewer + fit panel from PL Map detail panel, promote to Primary View. Add multi-peak fit controls. | Phase 3 (components exist) |
| **6. Kinetics workspace** | TA traces — reuse plot component, add exponential fit controls (n_exp, irf toggle, t_start). | Phase 5 (pattern established) |
| **7. SwiftUI app** | macOS native frontend consuming the same API. Can start in parallel with Phase 3+ once API is stable. | Phase 1 (stable API) |

### Technology choices (Electron frontend)

| Concern | Choice | Rationale |
|---------|--------|-----------|
| Framework | Svelte 5 | Lightweight, reactive, excellent DX |
| Charting | TBD — evaluate uPlot, Chart.js, Plotly.js, or D3 | Must support: heatmaps, line plots, click events, zoom/pan |
| Component library | shadcn-svelte | Accessible, composable, good defaults |
| Build tool | Vite | Standard for Svelte + Electron |
| Styling | Tailwind CSS | Pairs with shadcn-svelte |

Charting library is the most consequential frontend choice. Needs evaluation — key requirements are heatmap rendering performance (2D maps can be large), click-to-select interaction, and region selection (drag to define fit range).

---

## Open Design Questions

These don't need answers before starting Phase 1 (API), but must be resolved before Phase 3 (workspace UI).

### Interaction design
- **Region selection for fitting**: click-drag on the plot? Numeric input fields? Both?
- **Peak initial guesses**: auto-detected? User clicks to place peaks? Draggable markers?
- **Failed pixel handling**: click grey pixel to open a manual fit dialog? What adjustments are available?

### Visual design
- Light/dark theme support?
- Heatmap colormap selection? (viridis default, user-selectable)
- Keyboard shortcuts for power users

### Data management
- Recent files list?
- Remember last-used directory?
- Auto-save session state (so closing and reopening restores where you were)?

### Packaging and distribution
- How is Julia bundled? Sidecar binary (PackageCompiler) vs. require Julia installation?
- Auto-update mechanism for the Electron app?
- How do students install it? (single installer vs. separate Julia + app install)

---

## Relationship to Existing Packages

```
        JULIA                                    SWIFT

        CurveFitModels.jl
               │
        SpectroscopyTools.jl                     QPSKit (shared infra)
               │                                    │
        QPSTools.jl ──────→ QPSLab server ──────→ QPSLab macOS (SwiftUI + QPSKit)
               │              (HTTP/JSON)           │
               ↓                                    │ (same Julia HTTP API)
        Student scripts       QPSLab desktop ───────┘
                              (Electron/Svelte, Windows)

        QPSDrive.jl ────────────────────────→ QPSConsole (SwiftUI + QPSKit)
           (WebSocket/JSON)                      │
                                              Future TA Viewer (SwiftUI + QPSKit)
```

QPSLab is a **consumer** of QPSTools.jl, not a replacement. Every analysis capability in the GUI must exist as a QPSTools function first. The GUI is a thin layer that calls existing functions and presents results visually.

New analysis features are always added to QPSTools.jl (or SpectroscopyTools.jl), never implemented in the GUI layer. The GUI benefits automatically.

For the full ecosystem map with all packages, status, and communication protocols, see `notes/ecosystem_roadmap.md`.

---

## Success Criteria

### MVP (PL Map)
- Student can go from `.lvm` file to exported heatmap figure in under 5 minutes
- No Julia knowledge required
- Fit results match QPSTools.jl scripting output exactly (same engine)
- Works on lab Windows PCs

### Full app
- Covers FTIR, Raman, pump-probe, and PL map workflows
- Students prefer it over vendor software for routine analysis
- Publication-quality figures exported directly (no post-processing in other tools)
- eLabFTW logging integrated into the workflow
- Both macOS (SwiftUI) and Windows (Electron) versions available
