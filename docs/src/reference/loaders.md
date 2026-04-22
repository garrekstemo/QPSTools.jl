# Loaders

QPSTools provides typed file loaders for the instrument formats used in QPS lab. Loading returns spectrum types that carry sample metadata through the rest of the analysis pipeline — into plots, fit reports, and eLabFTW experiment entries.

## Unified Loader

```@docs
load_spectroscopy
```

## Steady-State Spectroscopy

```@docs
load_ftir
load_raman
load_uvvis
load_cavity
```

## Transient Absorption

```@docs
load_ta_trace
load_ta_spectrum
load_ta_matrix
```

## PL / Raman Mapping

```@docs
load_pl_map
load_wavelength_file
```

## Legacy / Low-Level

```@docs
load_lvm
find_peak_time
```

## Sample Registry

Steady-state loaders (`load_ftir`, `load_raman`, `load_uvvis`, `load_cavity`) accept keyword arguments such as `solute=`, `material=`, `concentration=`, `solvent=`, and `substrate=`. Any keyword is stored verbatim on the returned spectrum's `sample::Dict{String,Any}` field and becomes part of the metadata that follows the spectrum through plotting, fitting, and lab-notebook logging.

Beyond annotation, these kwargs also drive the local sample registry: when the loader is called without an explicit path, the metadata keys are matched against the registry to resolve a file path on disk.

```julia
# Registry lookup by metadata
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# Explicit path plus metadata (path wins; metadata still stored)
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv";
    solute="NH4SCN", concentration="1.0M")
```

The stored metadata is consumed downstream:

- `plot_ftir`, `plot_raman`, etc. auto-generate titles from `solute`, `material`, `concentration`, `solvent`.
- The eLabFTW integration uses [`tags_from_sample`](https://garrekstemo.github.io/ElabFTW.jl/stable/) on `spec.sample` to auto-tag experiments when logging.
- Interactive `show` methods display the same metadata keys so spectra are self-documenting in the REPL.
