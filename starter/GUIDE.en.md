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

6. **The registry is your data catalog.**
   Every data file should have an entry in `data/registry.json`.
   This lets you load data by metadata (`load_raman(material="MoSe2")`) instead of
   by file path, which makes scripts portable and self-documenting.

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

## Registry Entries

Each sample gets a unique ID and a set of metadata fields. The `path` field
is relative to `data/`.

```json
{
  "raman": {
    "MoSe2_center": {
      "sample": "center",
      "material": "MoSe2",
      "laser_nm": 532.05,
      "objective": "100x",
      "path": "raman/MoSe2_center.csv",
      "date": "2026-01-20"
    }
  }
}
```

Tips:
- Use consistent field names across entries (don't mix `laser` and `laser_nm`)
- Include measurement parameters that might affect the spectrum (laser power, exposure, grating)
- The `date` field records when the data was acquired, not when you analyzed it

## Workflow

Analysis has two phases: exploration and finalization.

### Exploration (`scratch/`)

When you first look at new data, use `scratch/` for quick throwaway scripts.
No rules, no structure — just load data and see what's there.

```julia
# scratch/look_at_new_sample.jl
using QPSTools, GLMakie
set_data_dir(joinpath(dirname(@__DIR__), "data"))

spec = load_raman(sample="spot1", material="MySample")
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
3. Edit the script     (change sample name, fit region, etc.)
4. Run it              julia --project=../.. analyses/MoSe2_A1g/analysis.jl
5. Check figures       (open figures/ and inspect the output)
6. Iterate             (adjust parameters, re-run)
7. Log to eLabFTW      (uncomment the log_to_elab block when satisfied)
```

## When to Make a New Folder vs. Edit in Place

**Edit in place** when you're refining the same analysis:
- Changing fit region boundaries
- Trying a different peak model (Gaussian vs. Lorentzian)
- Adjusting plot formatting

**Make a new folder** when the analysis target changes:
- Fitting a different peak in the same spectrum
- Comparing two different samples
- A fundamentally different analysis approach (e.g., baseline correction study)

## Logging to eLabFTW

After completing an analysis, log the results to eLabFTW. This creates a searchable
record with figures attached. Add a `log_to_elab` block at the end of your script:

```julia
log_to_elab(
    title = "Raman: MoSe2 A1g peak fit",
    body = format_results(result),
    attachments = [joinpath(FIGDIR, "context.png")],
    tags = ["raman", "mose2", "a1g"]
)
```

The eLabFTW entry becomes the permanent record. The analysis folder is your working
space — the notebook entry is what you cite in papers and share with collaborators.
