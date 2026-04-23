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

## Cavity Transmission

```@docs
load_cavity
```

## Annotated Spectrum Types

```@docs
AnnotatedSpectrum
AxisType
PumpProbeData
```

`AxisType` is an `@enum` with instances `time_axis` and `wavelength_axis`.
