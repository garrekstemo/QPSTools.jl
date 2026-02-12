# Agent Swarm Task Plan — QPS Ecosystem

**Date**: 2025-02-12
**Scope**: QPSTools.jl + QPSDrive.jl parallel work items
**Status**: Ready for assignment

---

## How to Use This File

Each task below is **independent** and can be assigned to a separate agent. Tasks include:
- **Scope**: What exactly to do
- **Key files**: Where to look and what to modify
- **Acceptance criteria**: How to know it's done
- **Context**: Background the agent needs to avoid wrong turns

Agents should read the project's `CLAUDE.md` before starting any task. QPSTools conventions (no `[compat]`, CurveFit.jl, Makie theming, etc.) apply to all work.

---

## QPSTools.jl Tasks

### Task A: Implement `plot_ta_heatmap()` for TAMatrix

**Scope**: `plot_ta_heatmap()` is exported from QPSTools but has no implementation. Write it.

**Key files**:
- `src/QPSTools.jl` — check the export list
- `src/types.jl` — `TAMatrix` type definition, interface (`xdata`, `ydata`, `zdata`)
- `src/plotting/plot_kinetics.jl` — existing TA plotting patterns to follow
- `src/plotting/themes.jl` — `qps_theme()` must wrap all plot functions
- `examples/broadband_ta_example.jl` — shows how `TAMatrix` is used

**Acceptance criteria**:
- `plot_ta_heatmap(matrix::TAMatrix)` returns `(Figure, Axis)`
- Uses `with_theme(qps_theme())` internally
- Heatmap orientation correct (see CLAUDE.md "Heatmap Matrix Orientation" section — Makie expects `z` shape `(length(x), length(y))`, may need transpose)
- Colorbar included
- Optional kwargs: `colormap`, `title`
- No inline styling (linewidth, fontsize, etc.)
- Add a smoke test in `test/runtests.jl` that calls it without erroring

**Context**: Makie `heatmap(x, y, z)` expects `z[i,j]` at `(x[i], y[j])`. TAMatrix stores data as `(n_time, n_wavelength)`. This is the #1 student gotcha — get the transpose right.

---

### Task B: Implement `plot_spectra()` Multi-Spectrum View

**Scope**: `plot_spectra()` is exported but not implemented. It should overlay multiple spectra on one axis.

**Key files**:
- `src/QPSTools.jl` — export list
- `src/plotting/plot_spectrum.jl` — existing `plot_comparison()` and `plot_waterfall()` patterns
- `src/plotting/layers.jl` — `_draw_data!()` layer function

**Acceptance criteria**:
- `plot_spectra(spectra::Vector; labels=nothing)` returns `(Figure, Axis)`
- Works with any `AbstractSpectroscopyData` that has `xdata()`/`ydata()`
- Also works with `Vector{<:AnnotatedSpectrum}` (FTIR, Raman, Cavity)
- Auto-cycles colors from theme palette
- Optional `labels` kwarg for legend
- Uses `with_theme(qps_theme())`
- Smoke test in `test/runtests.jl`

**Context**: Check if `plot_comparison()` already does this — it may just need an alias or slight generalization rather than a new function. Don't duplicate existing code.

---

### Task C: Tests for Polariton Physics and Dispersion Fitting

**Scope**: `src/cavity.jl` has substantial physics functions that are untested. Add tests.

**Key files**:
- `src/cavity.jl` — functions to test: `refractive_index()`, `extinction_coeff()`, `polariton_branches()`, `polariton_eigenvalues()`, `hopfield_coefficients()`, `cavity_mode_energy()`, `fit_dispersion()`
- `test/test_cavity.jl` — existing cavity tests to extend
- `examples/cavity_analysis.jl` — usage patterns

**Acceptance criteria**:
- Test `polariton_branches()` with known coupled oscillator parameters (check LP < bare, UP > bare)
- Test `polariton_eigenvalues()` for N=1 matches `polariton_branches()` result
- Test `hopfield_coefficients()` sum to 1.0 at each angle
- Test `cavity_mode_energy()` angle dependence (energy increases with angle)
- Test `fit_dispersion()` recovers known parameters from synthetic data
- All tests pass with `julia --project=. -e 'using Pkg; Pkg.test()'`

**Context**: These are physics validation tests. Use textbook values where possible (e.g., Rabi splitting of 100 cm⁻¹, cavity at 2000 cm⁻¹). The coupled oscillator model eigenvalues should be `E± = (E_c + E_v)/2 ± √((E_c - E_v)² + Ω²)/2`.

---

### Task D: Tests for PLMap Background Subtraction

**Scope**: `PLMap.subtract_background()` has auto and explicit modes that are untested.

**Key files**:
- `src/plmap.jl` — `subtract_background()` implementation
- `test/runtests.jl` — existing PLMap test section to extend
- `testdata/CCD/` — test data files

**Acceptance criteria**:
- Test explicit position background subtraction (provide corner positions, verify subtraction)
- Test auto mode (no positions given, should pick bottom corners)
- Test that background-subtracted spectra have lower baseline than originals
- Test that `normalize()` after `subtract_background()` gives values in [0, 1]
- All tests pass

**Context**: The PLMap test data is in `testdata/CCD/`. Check what files are available there. Background subtraction takes mean of spectra at given spatial positions and subtracts from all pixels.

---

### Task E: Plotting Smoke Tests

**Scope**: No plotting functions are tested at all. Add basic smoke tests that verify they run without error.

**Key files**:
- `src/plotting/` — all plot functions
- `test/runtests.jl` — add a new `@testset "Plotting"` section
- Existing test data loading patterns in the test file

**Acceptance criteria**:
- Smoke test for each public plot function: `plot_spectrum`, `plot_kinetics`, `plot_ftir`, `plot_raman`, `plot_cavity`, `plot_pl_map`, `plot_pl_spectra`, `plot_dispersion`, `plot_hopfield`, `plot_comparison`, `plot_waterfall`, `plot_peak_decomposition!`, `plot_peaks!`
- Each test loads real test data, calls the plot function, and checks it returns the expected tuple type (`Figure`, `Axis`, etc.)
- Tests use `CairoMakie` (add to test dependencies if not already there)
- No visual regression — just "does it run and return the right types"
- All tests pass

**Context**: Makie plotting tests need a backend loaded. Use `CairoMakie` in the test environment. Each test should be wrapped in a `@testset` with the function name. The plot functions apply `qps_theme()` internally via `with_theme()`.

---

### Task F: Documenter.jl Setup

**Scope**: Set up a documentation site skeleton with Documenter.jl. Auto-generate API reference from existing docstrings.

**Key files**:
- `src/` — all files have docstrings on public functions
- Create: `docs/make.jl`, `docs/Project.toml`, `docs/src/index.md`, `docs/src/api.md`

**Acceptance criteria**:
- `docs/make.jl` builds without error (`julia --project=docs docs/make.jl`)
- Landing page (`index.md`) has: package description, installation, quick start (adapt from CLAUDE.md)
- API reference page auto-generates from docstrings using `@autodocs`
- Organized into sections: Types, I/O, Analysis, Plotting, eLabFTW, Registry
- `docs/Project.toml` has Documenter.jl + QPSTools as dependencies
- Do NOT add `[compat]` entries to `docs/Project.toml`
- Build produces `docs/build/` with working HTML

**Context**: This is a standard Documenter.jl setup. The CLAUDE.md Quick Start Guide section has good content to adapt for the landing page. Keep it minimal — the docstrings do the heavy lifting. Do not add CairoMakie or GLMakie to docs dependencies (they're heavy); use `modules=[QPSTools]` in makedocs.

---

## QPSDrive.jl Tasks

### Task G: QPSDrive Mock Instrument Integration Testing

**Scope**: QPSDrive.jl has 4 mock instruments (`MockStage`, `MockDetector`, `MockMonochromator`, `MockSpectralDetector`) and a composite `PeakKineticsScan` workflow. An agent was working on integrating mocks into a control panel — this task is to **review what exists, identify gaps, and add validation tests**.

**Key files (all under `/Users/garrek/Documents/projects/QPSDrive.jl/`)**:
- `src/QPSDrive.jl` — module structure and exports
- `src/mock/` — all 4 mock instrument files
- `src/instruments/interface.jl` — abstract instrument interfaces
- `src/scans/` — `engine.jl`, `kinetic.jl`, `spectral.jl`, `composite.jl`
- `test/runtests.jl` — existing test suite (723 lines, 18 test sets)
- `examples/` — demo scripts
- Check for any uncommitted/in-progress work: `git status`, `git stash list`, `git diff`

**Acceptance criteria**:
- Document what the previous agent session accomplished (check git log, uncommitted changes, stash)
- Verify all existing tests pass: `julia --project=. -e 'using Pkg; Pkg.test()'`
- Identify any new code that lacks tests and add them
- If a control panel / GUI was started, assess its state and document what's done vs remaining
- Test the full composite workflow: mock stage + mock detector → `PeakKineticsScan` → saved CSV → reload and verify
- Validate mock instrument state management (connect/disconnect/abort cycles)
- Report findings as comments in the test file and a brief summary

**Context**: The user said "I left an instance to work on integrating the mock instruments into a control panel" and "it's probably not done yet." There may be uncommitted changes, a git stash, or work on a branch. **Check `git status`, `git stash list`, `git branch -a`, and `git log --oneline -20` first** to understand what state the previous session left things in. The project has no GUI framework in its dependencies — if a control panel was started, it may use QPSView's live plotting or an external package. CairoMakie was added to Project.toml (possibly uncommitted).

---

### Task H: QPSDrive ↔ QPSTools Integration Path

**Scope**: QPSDrive produces `TATrace` objects (via SpectroscopyTools types). QPSTools needs to be able to load QPSDrive's saved CSV scan files. Map the integration points and implement a loader if straightforward.

**Key files**:
- QPSDrive: `src/io.jl` — CSV save format with metadata headers
- QPSTools: `src/io.jl` — existing loaders
- QPSTools: `src/types.jl` — `TATrace`, `TASpectrum` types
- QPSDrive: `test/runtests.jl` — look for saved test output files

**Acceptance criteria**:
- Document the QPSDrive CSV format (header structure, column layout)
- If format is stable enough, implement `load_qpsdrive_scan()` in QPSTools `src/io.jl`
- The loaded data should return a `TATrace` or `TAMatrix` compatible with all QPSTools analysis
- If format is not yet stable, document what's needed and flag as blocked
- Add a test with a sample QPSDrive CSV file copied to `testdata/`

**Context**: QPSDrive saves scan data as CSV with metadata headers. The format was recently changed (commit message: "switch I/O to CSV"). Check the actual format before implementing — it may still be in flux. This task can be skipped if the format isn't stable yet; just document the gap.

---

## Task Dependency Map

```
Independent (all can run in parallel):
  A  plot_ta_heatmap
  B  plot_spectra
  C  polariton physics tests
  D  PLMap background tests
  E  plotting smoke tests      ← depends on A, B being done first (or test what exists)
  F  Documenter.jl setup
  G  QPSDrive mock validation
  H  QPSDrive ↔ QPSTools integration

Suggested ordering if agents are limited:
  Priority 1 (core gaps):  A, B, C, D
  Priority 2 (quality):    E, G
  Priority 3 (infra):      F, H
```

**Note on Task E**: If running in parallel with A and B, Task E should only smoke-test functions that already exist. If A and B finish first, E can also test the new functions.

---

## Agent Instructions (Copy to Each Agent)

> You are working on the QPS lab ecosystem. Read `CLAUDE.md` in the project root before starting.
> Key conventions:
> - Julia 1.10+, no `[compat]` entries in Project.toml
> - CurveFit.jl for fitting (not LsqFit), signature `fn(p, x)`
> - Makie for plotting (never Plots.jl), themes over inline styling
> - No `##` comments, no `@sprintf`, no `const` in scripts
> - `eachindex()` not `1:length()`, `similar(p, N)` not `zeros(N)`
> - Run tests with `julia --project=. -e 'using Pkg; Pkg.test()'`
