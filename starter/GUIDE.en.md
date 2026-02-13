[English](GUIDE.en.md) | [日本語](GUIDE.ja.md)

# Analysis Organization Guide

Best practices for organizing spectroscopy analysis in the QPS Lab.

## Principles

1. **Name folders by what they contain, not when you made them.**
   Dates belong in the lab notebook (eLabFTW), not in folder names.
   Use descriptive names: `MoSe2_A1g/`, `ZIF62_glass_baseline/`, `NH4SCN_CN_stretch/`.

2. **One folder per analysis target.**
   If you're fitting the A1g peak of MoSe2, that's one folder.
   If you later fit the E2g peak, that's a separate folder.
   Don't put unrelated analyses in the same folder.

3. **Figures stay with their analysis.**
   Every analysis folder has its own `figures/` directory.
   This keeps outputs traceable — you can always find the script that made a figure.

4. **Edit in place, don't duplicate.**
   When you re-run an analysis with different parameters, update the existing script.
   Don't create `MoSe2_A1g_v2/` or `MoSe2_A1g_final/`.
   If you need to track the history of changes, use git.

5. **Raw data is read-only.**
   Never modify files in `data/`. Analysis scripts read from `data/` and write to `figures/`.
   If you need to preprocess data (baseline correction, background subtraction),
   do it in the script so the steps are reproducible.

6. **eLabFTW is your lab notebook.**
   Use `log_to_elab()` to record analysis results. Tags are auto-generated from
   the JASCO file header and any metadata you pass to `load_raman`/`load_ftir`.
   The eLabFTW entry is the permanent record — the analysis folder is your working space.

## Folder Naming

Use underscores between words. Keep names short but specific enough to distinguish
from other analyses.

Good:
```
MoSe2_A1g/
ZIF62_crystal_Co/
NH4SCN_CN_stretch/
DMF_reference/
```

Avoid:
```
analysis1/
test/
new_analysis/
20260212_MoSe2/
MoSe2_A1g_v2_final_FINAL/
```

## Workflow

Analysis has two phases: exploration and finalization.

### Exploration (`scratch/`)

When you first look at new data, use `scratch/` for quick throwaway scripts.
No rules, no structure — just load data and see what's there.

```julia
# scratch/look_at_new_sample.jl
using QPSTools, GLMakie

spec = load_raman("data/raman/MoSe2_center.csv"; material="MoSe2")
fig, ax = plot_raman(spec)

peaks = find_peaks(spec)
println(peak_table(peaks))
```

Run interactively in the REPL (`include("scratch/look_at_new_sample.jl")`) or
line-by-line in VS Code. Use `GLMakie` for interactive plots you can zoom and pan.

Files in `scratch/` are disposable. Delete them whenever you want.

### Finalization (`analyses/`)

Once you know what you want to analyze, create a proper analysis folder:

```
1. Create folder       mkdir -p analyses/MoSe2_A1g
2. Copy template       cp templates/raman_analysis.jl analyses/MoSe2_A1g/analysis.jl
3. Edit the script     (change file path, metadata, fit region, etc.)
4. Run it              julia --project=. analyses/MoSe2_A1g/analysis.jl
5. Check figures       (open figures/ and inspect the output)
6. Iterate             (adjust parameters, re-run)
7. Log to eLabFTW      (uncomment the log_to_elab block when satisfied)
```

Or from the REPL (useful for interactive exploration with GLMakie):

```julia
julia --project=.
julia> include("analyses/MoSe2_A1g/analysis.jl")
```

### Manuscript figures (`manuscript/`)

When it's time to assemble figures for a paper, use `manuscript/`. This is where
you combine individual analysis outputs into composite multi-panel figures.

```julia
# manuscript/figure1.jl
using QPSTools, CairoMakie

set_theme!(print_theme())
fig = Figure(size=(1200, 400))

# (a) PL map — load the saved result
# (b) Raman spectrum — load from a different analysis
# (c) Some other panel

save("manuscript/figure1.pdf", fig)
```

Each analysis folder produces its own publication-ready figures. The `manuscript/`
folder is only for stitching those together into composite layouts for the paper.

## When to Make a New Folder vs. Edit in Place

**Edit in place** when you're refining the same analysis:
- Changing fit region boundaries
- Trying a different peak model (Gaussian vs. Lorentzian)
- Adjusting plot formatting

**Make a new folder** when the analysis target changes:
- Fitting a different peak in the same spectrum
- Comparing two different samples
- A fundamentally different analysis approach (e.g., baseline correction study)

## Retrieving Past Results

eLabFTW is the query layer for finding past analyses. Tags are auto-generated from
the JASCO technique type and any kwargs you pass to `load_raman`/`load_ftir`:

```julia
# Find all Raman analyses
search_experiments(tags=["raman"])

# Find all MoSe2 work
search_experiments(tags=["MoSe2"])

# Full-text search across titles and bodies
search_experiments(query="A1g peak fit")

# Recent experiments
list_experiments(limit=10)
```

## Logging to eLabFTW

After completing an analysis, log the results to eLabFTW. The auto-provenance form
extracts tags and source info from the JASCO header automatically:

```julia
log_to_elab(spec, result;
    title = "Raman: MoSe2 A1g peak fit",
    attachments = [joinpath(FIGDIR, "context.png")],
    extra_tags = ["a1g"]
)
```

Re-running the script updates the same experiment (idempotent via `.elab_id` file).

## Tips

### Choosing a fit region (Raman / FTIR)

Run `find_peaks` and `peak_table` first. The table prints center positions —
pick a range `(lo, hi)` that brackets the peak you want to fit.

```julia
peaks = find_peaks(spec)
println(peak_table(peaks))
# Output shows peak centers, e.g. 2054.3 cm⁻¹
# → choose (1950, 2150) to bracket that peak
result = fit_peaks(spec, (1950, 2150))
```

### PL Mapping: choosing a pixel range

A CCD raster scan records a full spectrum at every spatial point. That spectrum
contains everything — laser scatter, PL emission, Raman peaks, and detector
noise. To build a meaningful PL map, you need to isolate the PL peak using
**spectral windowing**: integrating only the pixels that contain the PL signal.

The template (`templates/plmap_analysis.jl`) works like this:

1. **Inspect spectra** — the script plots raw CCD spectra at a few positions
   (`spectra.pdf`). Look for the PL emission — it's usually the broadest peak.
   Laser scatter is sharp, Raman peaks are narrow.

2. **Set `PIXEL_RANGE`** — note which pixels bracket the PL peak and update
   the variable at the top of the script:
   ```julia
   PIXEL_RANGE = (950, 1100)  # pixels that contain your PL peak
   ```

3. **Background subtraction** — the script averages spectra from off-flake
   corners (no PL) and subtracts from every grid point, removing laser scatter
   and detector noise. A verification plot (`spectra_corrected.pdf`) shows the
   corrected spectra — the PL peak should sit on a flat baseline.

4. **Spectral windowing** — sums counts within `PIXEL_RANGE` at each grid
   point, giving one PL intensity value per point. Anything outside the window
   (laser lines, Raman peaks) is ignored.

The output figure shows the spectra with the integration window highlighted
alongside the spatial PL map.

### What `format_results` returns

`format_results(result)` returns a markdown string like:

```
Peak Fit Results
| Parameter | Peak 1   |
|-----------|----------|
| center    | 2054.3   |
| fwhm      | 22.1     |
| amplitude | 0.83     |
| R²        | 0.9987   |
```

This is the string logged to eLabFTW by `log_to_elab`.

### Always run from the project root

All commands assume you are in the project root (where `Project.toml` lives).
Use `--project=.` so Julia finds the installed packages:

```bash
julia --project=. analyses/MoSe2_A1g/analysis.jl    # terminal
julia --project=. scratch/quick_look.jl              # scratch scripts too
```

Or start a REPL and `include()` scripts:

```julia
julia --project=.
julia> include("analyses/MoSe2_A1g/analysis.jl")
julia> include("scratch/quick_look.jl")
```

### Plot return values

Plot functions return different tuples depending on the layout:

```julia
fig, ax                          = plot_ftir(spec)                              # survey
fig, ax, ax_res                  = plot_ftir(spec; fit=r, residuals=true)       # stacked
fig, ax_ctx, ax_fit, ax_res      = plot_ftir(spec; fit=r, context=true)         # three-panel
```

Use destructuring to capture only what you need. If you only want the figure
(e.g., for saving), you can ignore the axes: `fig, _ = plot_ftir(spec)`.

### PNG vs PDF

Use PNG (`.png`) while iterating — it's fast and easy to preview.
Switch to PDF (`.pdf`) for publication figures — it's vector graphics
that scales without pixelation.
