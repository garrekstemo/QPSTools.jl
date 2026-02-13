[English](README.en.md) | [日本語](README.ja.md)

# Bootstrap

Adds QPSTools to an existing Julia project. One command installs all
packages, copies analysis templates, and creates the standard directory
structure.

## Install

From your project root:

```bash
julia --project=. bootstrap/install.jl
```

## Verify

```julia
julia --project=.
julia> using Revise, QPSTools
julia> using GLMakie
```

## What gets installed

**Packages** (added to your Project.toml):

| Package | Purpose |
|---------|---------|
| QPSTools | Analysis, fitting, plotting |
| SpectroscopyTools | Base types and spectroscopy functions |
| JASCOFiles | JASCO FTIR/UV-vis file import |
| GLMakie | Interactive plotting |
| Revise | Live code reloading |

**Templates** (copied to `templates/`):

| File | Type | Description |
|------|------|-------------|
| `explore_raman.jl` | Explore | GLMakie + DataInspector |
| `explore_ftir.jl` | Explore | GLMakie + DataInspector |
| `explore_plmap.jl` | Explore | GLMakie + DataInspector |
| `raman_analysis.jl` | Analysis | CairoMakie, saves PNG |
| `ftir_analysis.jl` | Analysis | CairoMakie, saves PNG |
| `plmap_analysis.jl` | Analysis | CairoMakie, saves PNG |

---

## Project structure and workflow

### Recommended folder layout

```
my-project/
├── Project.toml
├── data/                # Raw instrument data (never modify originals)
│   ├── raman/
│   ├── ftir/
│   └── PLmap/
├── explore/             # Ephemeral exploration scripts (yours to create)
├── templates/           # Starting points (copy, don't edit directly)
├── analysis/            # Finished, reproducible analyses
│   └── MoSe2_A1g/
│       ├── analysis.jl
│       └── figures/
└── manuscript/          # Publication-quality composite figures
```

### Workflow

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                         DATA                                    │
  │           Raw files from instruments go in data/                │
  └───────────────────────────┬─────────────────────────────────────┘
                              │
                              v
  ┌─────────────────────────────────────────────────────────────────┐
  │                      EXPLORE                                    │
  │                                                                 │
  │  Copy a template to explore/ and step through it in the REPL.   │
  │  Uses GLMakie -- interactive plots with zoom, pan, hover.       │
  │  These scripts are ephemeral: quick, messy, disposable.         │
  │  Make as many as you want. Delete them when you're done.        │
  │                                                                 │
  │  cp templates/explore_raman.jl explore/look_at_sample_A.jl     │
  └───────────────────────────┬─────────────────────────────────────┘
                              │
                    Found something interesting?
                              │
                              v
  ┌─────────────────────────────────────────────────────────────────┐
  │                      ANALYZE                                    │
  │                                                                 │
  │  Copy an analysis template to analysis/<topic>/.                │
  │  Uses CairoMakie -- saves publication-quality PNG/PDF.          │
  │  These scripts are permanent: clean, documented, reproducible.  │
  │  Anyone in the lab can re-run them and get the same results.    │
  │                                                                 │
  │  mkdir -p analysis/MoSe2_A1g                                    │
  │  cp templates/raman_analysis.jl analysis/MoSe2_A1g/analysis.jl │
  └───────────────────────────┬─────────────────────────────────────┘
                              │
                    Ready to write up?
                              │
                              v
  ┌─────────────────────────────────────────────────────────────────┐
  │                     MANUSCRIPT                                  │
  │                                                                 │
  │  Combine panels from multiple analysis scripts into composite figures.  │
  │  CairoMakie + PDF output for vector graphics in papers.         │
  │  These scripts produce the exact figures in your publication.   │
  └───────────────────────────┬─────────────────────────────────────┘
                              │
                              v
  ┌─────────────────────────────────────────────────────────────────┐
  │                      eLABFTW                           (soon)   │
  │                                                                 │
  │  eLabFTW is our electronic lab notebook. QPSTools can log       │
  │  analysis results, fit parameters, and figures directly to      │
  │  your notebook with one function call. This makes it easy to    │
  │  track what you've done, share results with the team, and       │
  │  keep publication-ready figures organized from the start.       │
  └─────────────────────────────────────────────────────────────────┘
```

### Explore scripts -- quick and disposable

Explore scripts are for **you**, right now. They are not meant to be
permanent or pretty. Their purpose is to look at your data interactively
so you can figure out what's going on.

- Copy a template: `cp templates/explore_raman.jl explore/my_idea.jl`
- Open it in VS Code and step through line by line (Shift+Enter)
- Zoom, pan, and hover over data with DataInspector
- Write as many as you need -- one per sample, one per question
- Delete them when you're done; they've served their purpose

**You are encouraged to write your own explore scripts.** The templates
are just starting points. If you want to compare two spectra, subtract
a baseline, or overlay a fit on the data -- write a quick script in
`explore/` and try it out.

### Analysis scripts -- clean and reproducible

Analysis scripts are for **the lab**. They should be clean enough that
another student can understand and re-run them months later.

- Copy a template: `cp templates/raman_analysis.jl analysis/MoSe2_A1g/analysis.jl`
- Edit the data path and analysis parameters
- Run the whole script: `julia --project=. analysis/MoSe2_A1g/analysis.jl`
- Figures are saved to `analysis/MoSe2_A1g/figures/`
- Commit to git so the analysis is preserved

**You are encouraged to write your own analysis scripts.** Once you've
explored your data and know what story it tells, write a clean analysis
that captures that story. Your future self and your labmates will
thank you.

### A note on QPSTools functions

The functions in QPSTools are meant to be **flexible and easy to use**.
Loading data, fitting peaks, plotting results -- these should each be
one or two lines, not fifty. If something feels clunky, confusing, or
doesn't work the way you expect, that's a bug in the tool, not in you.

**Please tell Garrek** if a function is hard to use or doesn't do what
you need. Even better: try editing the code yourself (I'll show you
how) and we can improve the analysis functions together. Every
improvement you make benefits everyone in the lab.

### Coming soon: eLabFTW integration

[eLabFTW](https://www.elabftw.net/) is an open-source electronic lab
notebook that our lab uses for experiment tracking. QPSTools will
integrate directly with eLabFTW so you can:

- Log fit results and parameters to your notebook automatically
- Attach figures to experiments with one function call
- Tag experiments by sample, technique, and project
- Search across all lab experiments by keyword or tag

This means your analysis results flow straight from Julia into a
searchable, shareable lab record -- no manual copy-paste needed.
