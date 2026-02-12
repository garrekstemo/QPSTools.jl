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

3. Add your data files to `data/raman/` and register them in `data/registry.json`.

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

Then edit the script and run it:

```bash
julia --project=../.. analyses/MoSe2_A1g/analysis.jl
```

## Folder Structure

```
my-project/
├── Project.toml              # Julia environment (don't edit manually)
├── setup.jl                  # One-time setup (can delete after running)
├── data/
│   ├── registry.json         # Sample metadata — QPSTools looks here
│   └── raman/                # Raw .csv files from JASCO
├── scratch/                  # Exploration — try things here freely
├── templates/                # Starting points — copy, don't edit
│   ├── raman_analysis.jl
│   ├── ftir_analysis.jl
│   └── plmap_analysis.jl
└── analyses/                 # Finished analyses go here
    └── MoSe2_A1g/
        ├── analysis.jl
        └── figures/
```

## Registry

QPSTools finds your data through `data/registry.json`. Each entry maps a sample ID
to its metadata and file path:

```json
{
  "raman": {
    "my_sample_1": {
      "sample": "spot1",
      "material": "MySample",
      "laser_nm": 532.05,
      "path": "raman/my_sample_spot1.csv"
    }
  }
}
```

Then load by metadata:

```julia
spec = load_raman(sample="spot1", material="MySample")
```

See the QPSTools examples for more: `QPSTools.jl/examples/raman_analysis.jl`
