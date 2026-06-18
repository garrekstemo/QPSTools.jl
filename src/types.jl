"""
QPS-specific data types.

General-purpose types (`AbstractSpectroscopyData`, `KineticTrace`, `Spectrum`,
`TimeResolvedMatrix`, fit result types, etc.) are provided by OpticalSpectroscopy.jl.
Steady-state spectra (FTIR, Raman, UV-Vis, cavity) are loaded as token-stamped
`Spectrum`s by `load_spectrum` — QPSTools no longer defines a spectrum type.

This file defines QPS-specific raw-instrument types:
- `AxisType` — enum for raw LVM axis detection (time vs wavelength)
- `PumpProbeData` — raw LabVIEW LVM pump-probe container
"""

# =============================================================================
# Raw pump-probe instrument data (LabVIEW LVM files)
# =============================================================================

"""Axis type for raw LVM data: `time_axis` or `wavelength_axis`."""
@enum AxisType time_axis wavelength_axis

"""
    PumpProbeData

Raw pump-probe data from the LabVIEW spectrometer (LVM files).

This is an intermediate container used by `load_lvm`. Users typically don't
interact with this directly — use `load_ta_trace` or `load_ta_spectrum` instead,
which return `KineticTrace` / `Spectrum`.

# Fields
- `time::Vector{Float64}` — Time axis (ps) or wavelength axis (nm)
- `on::Matrix{Float64}` — Pump-ON signals (n_points × n_channels)
- `off::Matrix{Float64}` — Pump-OFF signals (n_points × n_channels)
- `diff::Matrix{Float64}` — Lock-in difference (n_points × n_channels)
- `timestamp::String` — Acquisition timestamp from file header
- `axis_type::AxisType` — Whether x-axis is time or wavelength
"""
struct PumpProbeData
    time::Vector{Float64}
    on::Matrix{Float64}
    off::Matrix{Float64}
    diff::Matrix{Float64}
    timestamp::String
    axis_type::AxisType
end
