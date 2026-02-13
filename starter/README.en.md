[English](README.en.md) | [日本語](README.ja.md)

# Analysis Starter

Template for new analysis projects using QPSTools.jl.

## Setup

1. Copy this folder to your own location and rename it:
   ```
   cp -r starter/ ~/Documents/projects/my-raman-project/
   ```

2. Run the one-time setup to install packages:
   ```
   cd ~/Documents/projects/my-raman-project/
   julia --project=. setup.jl
   ```

3. Add your data files to `data/raman/` (or `data/ftir/`, `data/PLmap/`, etc.).

## Usage

Each analysis lives in its own folder under `analyses/`, named by sample or topic:

```
analyses/
  MoSe2_A1g/
    analysis.jl
    figures/
  ZIF62_crystal_Co/
    analysis.jl
    figures/
```

To start a new analysis:

```bash
mkdir -p analyses/MoSe2_A1g
cp templates/raman_analysis.jl analyses/MoSe2_A1g/analysis.jl
```

Then edit the script (change the file path and metadata) and run it.

**From the terminal** (run from the project root):

```bash
julia --project=. analyses/MoSe2_A1g/analysis.jl
```

**From the Julia REPL** (start Julia at the project root):

```bash
julia --project=.
```

```julia
julia> include("analyses/MoSe2_A1g/analysis.jl")
```

## Folder Structure

```
my-project/
├── Project.toml              # Julia environment (don't edit manually)
├── setup.jl                  # One-time setup (can delete after running)
├── data/
│   ├── raman/                # Raw .csv files from JASCO
│   ├── ftir/                 # FTIR .csv files
│   └── PLmap/                # CCD raster scan .lvm files
├── scratch/                  # Exploration — try things here freely
├── templates/                # Starting points — copy, don't edit
│   ├── raman_analysis.jl
│   ├── ftir_analysis.jl
│   └── plmap_analysis.jl
└── analyses/                 # Finished analyses go here
    └── MoSe2_A1g/
        ├── analysis.jl
        ├── .elab_id          # Auto-created by log_to_elab (gitignored)
        └── figures/
```

## Loading Data

QPSTools loads data by file path. Optional keyword arguments add metadata
for display and eLabFTW tagging:

```julia
spec = load_raman("data/raman/MoSe2_center.csv"; material="MoSe2", sample="center")
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv"; solute="NH4SCN", concentration="1.0M")
m = load_pl_map("data/PLmap/my_scan.lvm"; step_size=2.16)
```

## eLabFTW Setup

To log results to your lab notebook, set environment variables (add to `~/.zshrc`):

```bash
export ELABFTW_URL="https://your-instance.elabftw.net"
export ELABFTW_API_KEY="your-api-key"
```

Then verify the connection:

```julia
using QPSTools
test_connection()
```

See the QPSTools examples for more: `QPSTools.jl/examples/`
