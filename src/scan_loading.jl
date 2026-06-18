# Typed wrapper over QPSScanFormat's plain-data read API.
#
# QPSScanFormat (the format layer) returns Loaded* results whose payloads
# are plain NamedTuples: trace = (time, signal), spectrum = (wavenumber,
# signal), sweeps = (X, Y, DC), and broadband as a bare (time, wavelength,
# data) NamedTuple. The Loaded* structs are parametric over those payload
# fields precisely so this wrapper can rebuild them with
# OpticalSpectroscopy analysis types while `r isa LoadedScanResult` etc.
# stay true for downstream dispatch (QPSLab server, student scripts).

"""
    load_scan(path) -> Loaded* result with OpticalSpectroscopy types

Load a QPSDrive HDF5 scan file (written by QPSScanFormat / QPSDrive) and
return analysis-ready results:

- `kinetic` → `LoadedScanResult` with `trace::KineticTrace`, `sweeps::SweepData`
- `spectrum` → `LoadedSpectralResult` with `spectrum::Spectrum`
- `composite` → `LoadedCompositeResult` with typed sub-results
- `broadband` → `TimeResolvedMatrix`
- `noise` → `LoadedNoiseResult` (plain vectors; no analysis type exists)

The traces/spectra feed `fit_exp_decay`, `fit_peaks`, `plot_kinetics`,
`plot_spectrum`, … directly. This is QPSTools' own function wrapping
`QPSScanFormat.load_scan`, which returns the same structures carrying
plain NamedTuple data instead.
"""
load_scan(path::AbstractString) = _with_analysis_types(QPSScanFormat.load_scan(path))

# nothing stays nothing (legacy files without per-sweep data)
_sweep_data(::Nothing) = nothing
_sweep_data(s) = SweepData(s.X, s.Y, s.DC)

function _with_analysis_types(r::LoadedScanResult)
    LoadedScanResult(
        KineticTrace(r.trace.time, r.trace.signal),
        _sweep_data(r.sweeps),
        r.timestamp, r.duration_seconds,
        r.instrument_state, r.scan_params,
        r.description, r.comment,
    )
end

function _with_analysis_types(r::LoadedSpectralResult)
    LoadedSpectralResult(
        Spectrum(r.spectrum.wavenumber, r.spectrum.signal;
                 axis=:wavenumber, yquantity=:delta_absorbance, technique=:ta),
        _sweep_data(r.sweeps),
        r.wavelengths,
        r.timestamp, r.duration_seconds,
        r.instrument_state, r.scan_params,
        r.description, r.comment,
    )
end

function _with_analysis_types(r::LoadedCompositeResult)
    LoadedCompositeResult(
        LoadedSpectralResult[_with_analysis_types(sp) for sp in r.spectra],
        LoadedScanResult[_with_analysis_types(tr) for tr in r.traces],
        r.timestamp, r.duration_seconds,
        r.instrument_state, r.scan_params,
        r.description, r.comment,
    )
end

# Noise results are already plain data end to end.
_with_analysis_types(r::LoadedNoiseResult) = r

# Broadband: QPSScanFormat returns a bare (time, wavelength, data)
# NamedTuple; analysis users get the TimeResolvedMatrix they always had.
_with_analysis_types(r::NamedTuple{(:time, :wavelength, :data)}) =
    TimeResolvedMatrix(r.time, r.wavelength, r.data)

# Transitional: a pre-decoupling QPSScanFormat returns broadband as a
# TimeResolvedMatrix already — pass it through so QPSTools works against both.
_with_analysis_types(r::TimeResolvedMatrix) = r
