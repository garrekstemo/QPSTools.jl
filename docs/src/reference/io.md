# File Loaders

Loaders for LabVIEW-produced instrument files and auto-dispatching wrappers for JASCO files. See [`src/io.jl`](https://github.com/garrekstemo/QPSTools.jl/blob/main/src/io.jl).

## Auto-Detect Loader

```@docs
load_spectroscopy
```

## LabVIEW and Pump-Probe Loaders

```@docs
load_lvm
load_ta_trace
load_ta_spectrum
load_ta_matrix
find_peak_time
```

## Steady-State Spectra (JASCO)

```@docs
load_spectrum
```

## Streak-Camera PL

```@docs
StreakPL
load_streak_pl
```

Convert a `StreakPL` to an analysis matrix with `TimeResolvedMatrix(pl)` (from
OpticalSpectroscopy) for slicing, binning, cosmic-ray removal, and decay fitting.

## HDF5 Scan Files

```@docs
load_scan
```

`load_scan` wraps `QPSScanFormat.load_scan` and rebuilds its plain-data results
with OpticalSpectroscopy analysis types (`KineticTrace`, `Spectrum`,
`TimeResolvedMatrix`, `SweepData`). The `Loaded*` result types
(`LoadedScanResult`, `LoadedSpectralResult`, `LoadedCompositeResult`,
`LoadedNoiseResult`) and the in-place editors (`update_scan_description!`,
`update_scan_comment!`, `update_scan_sample_name!`) are re-exported from
[QPSScanFormat.jl](https://github.com/garrekstemo/QPSScanFormat.jl) — see its
documentation for their fields.

## Raw Instrument Types

```@docs
AxisType
PumpProbeData
```

`AxisType` is an `@enum` with instances `time_axis` and `wavelength_axis`.
