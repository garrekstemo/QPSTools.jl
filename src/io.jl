"""
File I/O functions for loading spectroscopy data.

Supported formats:
- LabVIEW Measurement (.lvm) - pump-probe data
- JASCO CSV (.csv) - FTIR spectra (via JASCOFiles.jl)
- Broadband TA (.lvm, .txt, .csv) - 2D time×wavelength data
"""

using DelimitedFiles

# =============================================================================
# Time axis utilities
# =============================================================================

"""
    find_peak_time(time, signal) -> Float64

Find the time at which the signal reaches its peak (maximum absolute value).
Works for both ESA (positive) and GSB (negative) signals.
"""
function find_peak_time(time::AbstractVector, signal::AbstractVector)
    if abs(maximum(signal)) >= abs(minimum(signal))
        return time[argmax(signal)]
    else
        return time[argmin(signal)]
    end
end

find_peak_time(trace::KineticTrace) = find_peak_time(trace.time, trace.signal)

# =============================================================================
# Transient Absorption loading (unified API)
# =============================================================================

"""
    load_ta_trace(filepath; mode=:OD, channel=1, wavelength=NaN, shift_t0=true) -> KineticTrace

Load a transient absorption kinetic trace from a single-pixel detector file.

The time axis is automatically shifted so that the signal peak (pump-probe overlap)
is at t = 0. This is the standard convention for ultrafast spectroscopy.

Two file layouts are supported:
1. **Raw lock-in .lvm** (MIR pump-probe setup): ON/OFF/diff channel sections;
   the ΔA signal is computed according to `mode` and `channel`.
2. **Plain two-column text** (pre-processed exports, e.g. from the vis-pump /
   white-light-probe setup): time and ΔA columns, no headers. `mode` and
   `channel` are ignored (the signal is already computed; metadata records
   `:mode => :precomputed`). A time axis whose magnitude exceeds 10⁴ is
   assumed to be in fs and is converted to ps.

# Arguments
- `filepath`: Path to .lvm or two-column text file
- `mode`: How to compute ΔA signal (raw .lvm only)
  - `:OD` — ΔOD = -log₁₀(ON/OFF) (default, for bare molecules)
  - `:transmission` — -ΔT/T = -(ON - OFF)/OFF
  - `:diff` — Raw lock-in difference signal
- `channel`: Detector channel (1-4, default 1 = CH0; raw .lvm only)
- `wavelength`: Probe wavelength in nm or cm⁻¹ (default NaN = unknown)
- `shift_t0`: Shift time axis so peak is at t=0 (default true)

# Returns
`KineticTrace` ready for fitting with `fit_exp_decay`.

# Example
```julia
trace = load_ta_trace("data.lvm"; mode=:OD)
trace.time[1]  # Negative (before pump-probe overlap)
# Peak signal is at t ≈ 0
```
"""
function load_ta_trace(filepath::String; mode::Symbol=:OD, channel::Int=1,
                       wavelength::Float64=NaN, shift_t0::Bool=true)
    if _is_plain_xy_file(filepath)
        return _load_plain_trace(filepath; wavelength=wavelength, shift_t0=shift_t0)
    end
    raw = load_lvm(filepath)
    signal = _compute_signal(raw, channel, mode)
    time = raw.time

    # Shift time axis so peak is at t=0
    if shift_t0
        t_peak = find_peak_time(time, signal)
        time = time .- t_peak
    end

    metadata = Dict{Symbol,Any}(
        :filename => basename(filepath),
        :filepath => filepath,
        :timestamp => raw.timestamp,
        :mode => mode,
        :channel => channel
    )

    return KineticTrace(time, signal, wavelength, metadata)
end

"""
Check whether a file is a plain two-column numeric (x, y) text file with no
header lines or LVM section markers. Tab, comma, or whitespace separated;
tolerates CRLF line endings. Inspects up to the first 20 data lines.
"""
function _is_plain_xy_file(path::String)
    n_checked = 0
    for line in eachline(path)
        stripped = strip(replace(line, '\r' => ' '))
        isempty(stripped) && continue
        occursin(r"[a-df-zA-DF-Z_]", stripped) && return false  # allow e/E exponents
        parts = split(stripped, r"[\t, ]+"; keepempty=false)
        length(parts) == 2 || return false
        all(p -> tryparse(Float64, p) !== nothing, parts) || return false
        n_checked += 1
        n_checked >= 20 && break
    end
    return n_checked > 0
end

"""
Parse a plain two-column numeric file into (x, y) vectors.
"""
function _read_xy(path::String)
    x = Float64[]
    y = Float64[]
    for line in eachline(path)
        stripped = strip(replace(line, '\r' => ' '))
        isempty(stripped) && continue
        parts = split(stripped, r"[\t, ]+"; keepempty=false)
        length(parts) == 2 || continue
        xv = tryparse(Float64, parts[1])
        yv = tryparse(Float64, parts[2])
        (isnothing(xv) || isnothing(yv)) && continue
        push!(x, xv)
        push!(y, yv)
    end
    return x, y
end

"""
Load a pre-processed two-column (time, ΔA) trace file. Time axes with
magnitude above 10⁴ are assumed to be in fs and converted to ps.
"""
function _load_plain_trace(filepath::String; wavelength::Float64=NaN, shift_t0::Bool=true)
    time, signal = _read_xy(filepath)
    isempty(time) && error("No numeric data found in $filepath")

    if maximum(abs, time) > 1e4
        time = time ./ 1000
    end

    if shift_t0
        t_peak = find_peak_time(time, signal)
        time = time .- t_peak
    end

    metadata = Dict{Symbol,Any}(
        :filename => basename(filepath),
        :filepath => filepath,
        :timestamp => "",
        :mode => :precomputed,
        :channel => 0
    )

    return KineticTrace(time, signal, wavelength, metadata)
end

"""
Compute ΔA signal from raw pump-probe data.
"""
function _compute_signal(data::PumpProbeData, channel::Int, mode::Symbol)
    if mode == :diff
        return data.diff[:, channel]
    elseif mode == :OD
        return -log10.(data.on[:, channel] ./ data.off[:, channel])
    elseif mode == :transmission
        return -(data.on[:, channel] .- data.off[:, channel]) ./ data.off[:, channel]
    else
        error("Unknown mode: $mode. Use :OD, :transmission, or :diff")
    end
end

# =============================================================================
# Low-level LVM loading (raw channel access)
# =============================================================================

"""
    load_lvm(filepath::String) -> PumpProbeData

Load a LabVIEW .lvm file from the MIR pump-probe setup.

Handles two formats:
1. **Chopper ON** (pump-probe with modulation):
   - ON/OFF channels (8 cols: CH0_ON, CH0_OFF, CH1_ON, CH1_OFF, ...)
   - Diff channels (4 cols: CH0_diff, ...)
   - Time axis (1 col, in fs)

2. **Chopper OFF** (raw channels, no modulation):
   - Raw channels only (CH0, CH1, ..., CH7)
   - No diff or time sections
   - Time axis generated as row indices

# Example
```julia
data = load_lvm("sig_250903_154003.lvm")
data.time           # Time axis in ps
data.on[:, 1]       # Channel 0 pump-on (or raw signal if no chopper)
data.diff[:, 1]     # Channel 0 difference (zeros if no chopper)
```
"""
function load_lvm(filepath::String)
    lines = readlines(filepath)
    first_header = split(lines[1], '\t')[1]

    # Detect format: chopper ON has "_ON_" or "_OFF_" in headers
    is_chopper_on = occursin("_ON_", first_header) || occursin("_OFF_", first_header)

    if is_chopper_on
        return _load_lvm_chopper_on(lines, filepath)
    else
        return _load_lvm_raw_channels(lines, filepath)
    end
end

"""
Load LVM with chopper ON format (ON/OFF/diff sections + time or wavelength axis).
"""
function _load_lvm_chopper_on(lines, filepath)
    # Find section boundaries
    diff_start = findfirst(l -> startswith(l, "CH") && occursin("diff", l), lines)
    time_start = findfirst(l -> startswith(l, "Time"), lines)
    wavelength_start = findfirst(l -> occursin("wavelength", l), lines)

    isnothing(diff_start) && error("Could not find diff section in $filepath")

    # Determine x-axis section (time or wavelength)
    axis_start = something(time_start, wavelength_start, nothing)
    isnothing(axis_start) && error("Could not find time or wavelength section in $filepath")

    # Parse ON/OFF section (lines 1 to diff_start-1)
    on_off_data = _parse_section(lines, 1, diff_start - 1, 8)
    on = on_off_data[:, 1:2:end]   # Columns 1,3,5,7 = ON
    off = on_off_data[:, 2:2:end]  # Columns 2,4,6,8 = OFF

    # Parse diff section
    diff = _parse_section(lines, diff_start, axis_start - 1, 4)

    # Parse x-axis section and determine axis type
    if !isnothing(time_start)
        # Time axis (convert fs → ps)
        time_data = _parse_section(lines, time_start, length(lines), 1)
        time = vec(time_data) ./ 1000  # fs → ps
        axis_type = time_axis
    else
        # Wavelength axis (use directly in nm)
        wl_data = _parse_section(lines, wavelength_start, length(lines), 2)
        time = wl_data[:, 1]  # wavelength in nm
        axis_type = wavelength_axis
    end

    # Extract timestamp from header
    header = split(lines[1], '\t')[1]
    timestamp = match(r"(\d{6}_\d{6})", header)
    timestamp = isnothing(timestamp) ? basename(filepath) : timestamp.captures[1]

    return PumpProbeData(time, on, off, diff, timestamp, axis_type)
end

"""
Load LVM with raw channels (no chopper modulation).
Handles wavelength scans with optional wavelength/wavenumber axis section.
"""
function _load_lvm_raw_channels(lines, filepath)
    # Find section boundaries - look for wavelength/wavenumber section
    wavelength_start = findfirst(l -> startswith(l, "wavelength"), lines)

    # Determine data section end
    data_end = isnothing(wavelength_start) ? length(lines) : wavelength_start - 1

    # Count columns from first line (header + data on same line)
    first_line = lines[1]
    parts = split(replace(first_line, '\r' => '\t'), '\t')
    parts = filter(!isempty, parts)

    # Find how many are headers vs data by checking if parseable
    n_headers = 0
    for p in parts
        if tryparse(Float64, p) === nothing
            n_headers += 1
        else
            break
        end
    end
    n_cols = length(parts) - n_headers

    # Parse channel data section
    data = _parse_section(lines, 1, data_end, n_cols)
    n_rows = size(data, 1)

    # Parse wavelength section if present and determine axis type
    if !isnothing(wavelength_start)
        wl_data = _parse_section(lines, wavelength_start, length(lines), 2)
        time = wl_data[:, 1]  # Use wavelength as x-axis (stored in `time` field)
        axis_type = wavelength_axis
    else
        time = collect(1.0:n_rows)  # Fallback to row indices
        axis_type = time_axis  # Assume time if no wavelength section
    end

    # For raw channels: put data in `on`, zeros for `off`
    # Use first channel as `diff` for default plotting
    n_channels = min(n_cols, 4)  # Limit to 4 channels for compatibility
    on = data[:, 1:n_channels]
    off = zeros(n_rows, n_channels)
    diff = data[:, 1:n_channels]  # Raw data for plotting

    # Extract timestamp from header
    header = split(lines[1], '\t')[1]
    timestamp = match(r"(\d{6}_\d{6})", header)
    timestamp = isnothing(timestamp) ? basename(filepath) : timestamp.captures[1]

    return PumpProbeData(time, on, off, diff, timestamp, axis_type)
end

"""
Parse a section of the LVM file, extracting n_cols numeric columns.
Returns Matrix{Float64} with n_cols columns.

Handles two LabVIEW conventions:
1. Header + first data row on the same line (separated by \\r) — MIR format
2. Header on its own line, data on subsequent lines — broadband format

Also handles tab-separated and carriage-return-separated values.
"""
function _parse_section(lines, start_idx, end_idx, n_cols)
    # Check if the first line contains enough parseable numeric values.
    # If not, it's a header-only line and data starts on the next line.
    first_line = lines[start_idx]
    parts = split(replace(first_line, '\r' => '\t'), '\t')
    parts = filter(p -> !isempty(strip(p)), parts)

    # Count how many trailing values parse as Float64
    n_numeric = 0
    for j in length(parts):-1:1
        if tryparse(Float64, strip(parts[j])) !== nothing
            n_numeric += 1
        else
            break
        end
    end

    # If the first line has enough numeric values, it contains data (MIR format)
    # Otherwise it's a header-only line (broadband format)
    data_start = n_numeric >= n_cols ? start_idx : start_idx + 1

    n_rows = end_idx - data_start + 1
    data = Matrix{Float64}(undef, n_rows, n_cols)

    for (i, line_idx) in enumerate(data_start:end_idx)
        line = lines[line_idx]
        parts = split(replace(line, '\r' => '\t'), '\t')
        parts = filter(p -> !isempty(strip(p)), parts)
        # Data values are the last n_cols elements (header names come first on mixed lines)
        values = parts[end-n_cols+1:end]
        data[i, :] = parse.(Float64, values)
    end

    return data
end

# =============================================================================
# Transient Absorption Spectrum loading
# =============================================================================

"""
    load_ta_spectrum(filepath; mode=:OD, channel=1, calibration=0.0, time_delay=NaN) -> Spectrum

Load a transient absorption spectrum from a MIR pump-probe spectrometer file.

# Arguments
- `filepath`: Path to .lvm file
- `mode`: How to compute ΔA signal
  - `:OD` — ΔOD = -log₁₀(ON/OFF) (default)
  - `:transmission` — -ΔT/T = -(ON - OFF)/OFF
  - `:diff` — Raw lock-in difference signal
- `channel`: Detector channel (1-4, default 1 = CH0)
- `calibration`: Wavenumber calibration offset in cm⁻¹ (default 0.0)
- `time_delay`: Time delay in ps (default NaN = unknown)

# Returns
`Spectrum` on a wavenumber axis (`:xquantity=:wavenumber`, `:xunit=:per_cm`).
The signal token follows `mode`: `:OD` → `:delta_absorbance` ("ΔA"),
`:transmission` → `:delta_transmittance` ("−ΔT/T"), `:diff` → no signal token
(label falls back to the generic "Signal").

# Example
```julia
spec = load_ta_spectrum("bare_1M_1ps.lvm"; mode=:OD, calibration=-19.0)
xdata(spec)  # wavenumber, cm⁻¹ (calibrated)
ydata(spec)  # ΔA values
```
"""
function load_ta_spectrum(filepath::String; mode::Symbol=:OD, channel::Int=1,
                          calibration::Float64=0.0, time_delay::Float64=NaN)
    lines = readlines(filepath)

    # Find section boundaries
    diff_start = findfirst(l -> startswith(l, "CH") && occursin("diff", l), lines)
    wavelength_start = findfirst(l -> occursin("wavelength", l) || occursin("wavenum", l), lines)

    isnothing(diff_start) && error("Could not find diff section in $filepath")
    isnothing(wavelength_start) && error("Could not find wavenumber section in $filepath")

    # Parse ON/OFF section (lines 1 to diff_start-1)
    on_off_data = _parse_section(lines, 1, diff_start - 1, 8)
    on = on_off_data[:, 2*channel - 1]   # ON columns: 1, 3, 5, 7
    off = on_off_data[:, 2*channel]       # OFF columns: 2, 4, 6, 8

    # Compute signal based on mode
    if mode == :OD
        signal = -log10.(on ./ off)
    elseif mode == :transmission
        signal = -(on .- off) ./ off
    elseif mode == :diff
        # Use pre-computed diff section
        diff_data = _parse_section(lines, diff_start, wavelength_start - 1, 4)
        signal = diff_data[:, channel]
    else
        error("Unknown mode: $mode. Use :OD, :transmission, or :diff")
    end

    # Parse wavenumber calibration section (2 columns: pixel, wavenumber)
    wn_data = _parse_section(lines, wavelength_start, length(lines), 2)
    wavenumber = wn_data[:, 2] .+ calibration  # Apply calibration offset

    # Ensure dimensions match (sometimes there's a mismatch)
    n_signal = length(signal)
    n_wn = length(wavenumber)
    if n_signal != n_wn
        # Use the shorter length
        n = min(n_signal, n_wn)
        signal = signal[1:n]
        wavenumber = wavenumber[1:n]
    end

    # Extract timestamp from header
    header = split(lines[1], '\t')[1]
    timestamp_match = match(r"(\d{6}_\d{6})", header)
    timestamp = isnothing(timestamp_match) ? basename(filepath) : timestamp_match.captures[1]

    metadata = Dict{Symbol,Any}(
        :filename => basename(filepath),
        :filepath => filepath,
        :timestamp => timestamp,
        :mode => mode,
        :channel => channel,
        :calibration => calibration,
        :technique => :ta,
        :xquantity => :wavenumber,
        :xunit => :per_cm,
    )
    # Signal quantity depends on mode: :OD gives ΔA, :transmission gives -ΔT/T,
    # :diff is the raw lock-in difference (no honest signal token → "Signal").
    if mode == :OD
        metadata[:yquantity] = :delta_absorbance
    elseif mode == :transmission
        metadata[:yquantity] = :delta_transmittance
    end
    if !isnan(time_delay)
        metadata[:time_delay] = time_delay
        metadata[:time_delay_unit] = :ps
    end

    return Spectrum(wavenumber, signal, metadata)
end

# =============================================================================
# JASCO steady-state spectra (FTIR, Raman, UV-Vis, cavity)
# =============================================================================

# JASCO datatype → (technique, xquantity, xreversed) for token stamping.
const _JASCO_DATATYPE = Dict{String,Tuple{Symbol,Symbol,Bool}}(
    "INFRARED SPECTRUM"   => (:ftir,  :wavenumber,  true),
    "RAMAN SPECTRUM"      => (:raman, :raman_shift, false),
    "UV/VISIBLE SPECTRUM" => (:uvvis, :wavelength,  false),
)

# JASCO yunits string → (yquantity, yunit) tokens. The "%T = TRANSMITTANCE,
# fractional = TRANSMITTANCE_FRAC" convention is JASCO's; everything else falls
# back to the generic OpticalSpectroscopy normalizers.
function _jasco_signal_tokens(yunits::AbstractString)
    u = uppercase(strip(yunits))
    u == "TRANSMITTANCE"      && return (:transmittance, :percent)
    u == "TRANSMITTANCE_FRAC" && return (:transmittance, :fraction)
    u == "ABSORBANCE"         && return (:absorbance, :OD)
    return (normalize_quantity(yunits), normalize_unit(yunits))
end

"""
    load_spectrum(path::String; kwargs...) -> Spectrum

Load a steady-state spectrum from a JASCO file (FTIR, Raman, or UV-Vis) into a
token-stamped [`Spectrum`](@ref). Technique and axis tokens are derived from the
JASCO header (`:technique`, `:xquantity`/`:xunit`, `:yquantity`/`:yunit`,
`:xreversed`); provenance (`:source_file`, `:instrument`, `:date`) is stamped for
eLabFTW logging; any keyword arguments are stored as sample metadata under
`metadata[:sample]` for display and tagging.

`cavity_length`, if given, is promoted to the top-level `:cavity_length` token
(not buried in `:sample`) so OpticalSpectroscopy's `fit_cavity_spectrum(::Spectrum)`
can pick it up as the cavity length `L`.

This replaces the former `load_cavity`/`CavitySpectrum` pair — a cavity
transmission spectrum is just an FTIR `Spectrum` carrying cavity sample metadata.

# Examples
```julia
spec = load_spectrum("data/ftir/sample.csv")
spec = load_spectrum("data/ftir/cavity.csv"; mirror="Au", angle=0, cavity_length=12e-4)
```
"""
function load_spectrum(path::String; cavity_length=nothing, kwargs...)
    full_path = abspath(path)
    isfile(full_path) || error("File not found: $full_path")
    j = JASCOSpectrum(full_path)

    technique, xquantity, xrev = get(_JASCO_DATATYPE, uppercase(strip(j.datatype)),
                                     (:spectroscopy, normalize_quantity(j.xunits), false))
    yquantity, yunit = _jasco_signal_tokens(j.yunits)

    metadata = Dict{Symbol,Any}(
        :source_file => basename(full_path),
        :filepath    => full_path,
        :technique   => technique,
        :xquantity   => xquantity,
        :xunit       => normalize_unit(j.xunits),
        :yquantity   => yquantity,
        :yunit       => yunit,
        :xreversed   => xrev,
        :datatype    => j.datatype,
        :sample      => Dict{String,Any}(string(k) => v for (k, v) in kwargs),
    )
    isnothing(cavity_length) || (metadata[:cavity_length] = cavity_length)
    isempty(j.spectrometer) || (metadata[:instrument] = j.spectrometer)
    isnothing(j.date) || (metadata[:date] = j.date)
    isempty(j.title) || (metadata[:title] = j.title)

    return Spectrum(j.x, j.y, metadata)
end

# =============================================================================
# TimeResolvedMatrix loading (2D broadband TA data)
# =============================================================================

"""
    load_ta_matrix(dir; time_file=nothing, wavelength_file=nothing, data_file=nothing,
                   time=nothing, wavelength=nothing, time_unit=:fs, wavelength_unit=:nm) -> TimeResolvedMatrix

Load 2D transient absorption data (time × wavelength) from separate files.

This function loads broadband/white-light probe TA data stored as separate files
for the time axis, wavelength axis, and data matrix.

# Arguments
- `dir`: Directory containing the data files
- `time_file`: Time axis file (auto-detected if not specified)
- `wavelength_file`: Wavelength axis file (auto-detected if not specified)
- `data_file`: TA matrix file (auto-detected if not specified)
- `time`: Time axis as a `Vector{Float64}` (in ps). Overrides `time_file` when provided.
  Use this when the time axis is not stored in a file (e.g., CCD data with instrument-defined delays).
- `wavelength`: Wavelength (or wavenumber) axis as a vector. Overrides `wavelength_file`
  when provided, parallel to `time`. Use this when the wavelength axis is not stored in a
  file (e.g., supplied by an import dialog or computed from a spectrograph calibration).
- `time_unit`: Unit of time axis file, `:fs` (default) or `:ps`. Ignored when `time` vector is provided.
- `wavelength_unit`: Unit of wavelength axis, `:nm` (default) or `:cm⁻¹`

# Auto-detection
If files are not specified, looks for common naming patterns:
- Time: `time*.txt`, `delay*.txt`, `*time*.txt`
- Wavelength: `wavelength*.txt`, `lambda*.txt`, `wl_axis*.txt`, `波長*.txt`
- Data: `CCDABS*.lvm`, `ta_matrix*.txt`, `*matrix*.txt`, `*data*.lvm`

If neither a `wavelength` vector nor a wavelength file (given or auto-detected) resolves,
the axis falls back to pixel indices `1:n_wl`, `metadata[:xquantity]` is set to `:pixel`,
and a warning is emitted — this no longer errors (unlike a missing data file, which still
raises via the auto-detect failure).

# File Formats
- Time/wavelength axis files: Single or multi-column numeric values (first column used)
- Data matrix: Tab or comma-separated, rows = time points, cols = wavelengths.
  A single-integer first line (row count) is automatically skipped.

# Returns
`TimeResolvedMatrix` ready for extraction and fitting.

# Example
```julia
# Auto-detect files in directory
matrix = load_ta_matrix("data/CCD/")

# Explicit file paths
matrix = load_ta_matrix("data/",
    time_file="time_axis.txt",
    wavelength_file="wavelength.txt",
    data_file="ta_matrix.lvm")

# CCD data with instrument-defined time axis (no time file)
time_fs = collect(-20000:400.28:180000)  # instrument step size
matrix = load_ta_matrix("data/ccd/",
    time=time_fs ./ 1000,  # convert to ps
    data_file="ta_matrix.lvm")

# CCD data with instrument-defined wavelength axis (no wavelength file)
matrix = load_ta_matrix("data/ccd/",
    wavelength=collect(400.0:0.5:800.0),
    data_file="ta_matrix.lvm")

# Extract kinetics and fit
trace = matrix[λ=800]
result = fit_exp_decay(trace)
```
"""
function load_ta_matrix(dir::String; time_file::Union{String,Nothing}=nothing,
                        wavelength_file::Union{String,Nothing}=nothing,
                        data_file::Union{String,Nothing}=nothing,
                        time::Union{AbstractVector,Nothing}=nothing,
                        wavelength::Union{AbstractVector,Nothing}=nothing,
                        time_unit::Symbol=:fs,
                        wavelength_unit::Symbol=:nm)

    # Auto-detect data file if not specified
    if isnothing(data_file)
        data_file = _find_file(dir, ["CCDABS", "matrix", "ta_", "data"];
                               extensions=[".lvm", ".txt", ".csv"])
    end

    # Build full path for the data file
    data_path = joinpath(dir, data_file)

    # Wavelength axis: explicit vector > file (given or auto-detected) > pixel indices
    local wavelength_vec
    if !isnothing(wavelength)
        wavelength_vec = collect(Float64, wavelength)
        wavelength_file = something(wavelength_file, "direct")
    else
        if isnothing(wavelength_file)
            wavelength_file = _find_file_or_nothing(dir, ["wavelength", "lambda", "wl_axis", "波長", "nm"])
        end
        wavelength_vec = isnothing(wavelength_file) ? nothing :
                         _load_axis_file(joinpath(dir, wavelength_file))
    end

    # Load time axis (from vector, file, or row indices). When a file axis is in
    # fs it is converted to ps, so the *stored* time unit becomes :ps — the token
    # must describe the axis as stored, not the source-file unit.
    stored_time_unit = time_unit
    if !isnothing(time)
        time_vec = collect(Float64, time)
    elseif !isnothing(time_file)
        time_raw = _load_axis_file(joinpath(dir, time_file))
        time_vec = time_unit == :fs ? time_raw ./ 1000 : Float64.(time_raw)
        time_unit == :fs && (stored_time_unit = :ps)
    else
        # Try auto-detecting a time file
        time_file_found = _find_file_or_nothing(dir, ["time", "delay", "t_axis"])
        if !isnothing(time_file_found)
            time_raw = _load_axis_file(joinpath(dir, time_file_found))
            time_vec = time_unit == :fs ? time_raw ./ 1000 : Float64.(time_raw)
            time_unit == :fs && (stored_time_unit = :ps)
            time_file = time_file_found
        else
            time_vec = nothing  # Will be set after loading matrix
        end
    end

    # Load data matrix
    data = _load_matrix_file(data_path)

    # If no time axis was found, use row indices
    if isnothing(time_vec)
        time_vec = collect(1.0:size(data, 1))
        @warn "No time axis found. Using row indices (1:$(size(data, 1)))."
    end

    # If no wavelength axis was found (no vector, no file), use pixel indices
    if isnothing(wavelength_vec)
        wavelength_vec = collect(1.0:size(data, 2))
        @warn "No wavelength axis found. Using pixel indices (1:$(size(data, 2)))."
    end

    # Validate dimensions
    n_time, n_wl = size(data)
    if length(time_vec) != n_time
        # Try transpose
        if length(time_vec) == n_wl && length(wavelength_vec) == n_time
            data = collect(data')
            n_time, n_wl = size(data)
        else
            @warn "Time axis length ($(length(time_vec))) does not match matrix rows ($n_time). Truncating."
            n = min(length(time_vec), n_time)
            time_vec = time_vec[1:n]
            data = data[1:n, :]
        end
    end
    if length(wavelength_vec) != n_wl
        @warn "Wavelength axis length ($(length(wavelength_vec))) does not match matrix columns ($n_wl). Truncating to shorter."
        n = min(length(wavelength_vec), n_wl)
        wavelength_vec = wavelength_vec[1:n]
        data = data[:, 1:n]
    end

    xunit = normalize_unit(string(wavelength_unit))
    is_pixel = isnothing(wavelength) && (wavelength_file === nothing)
    metadata = Dict{Symbol,Any}(
        :source => dir,
        :time_file => something(time_file, "direct"),
        :wavelength_file => something(wavelength_file, "none"),
        :data_file => data_file,
        :technique => :ta,
        :time_unit => stored_time_unit,
        :source_time_unit => time_unit,
        :xquantity => is_pixel ? :pixel : (xunit === :per_cm ? :wavenumber : :wavelength),
        :xunit => xunit,
        :yquantity => :delta_absorbance,
    )

    return TimeResolvedMatrix(time_vec, wavelength_vec, data, metadata)
end

"""
    read_axis_file(path; column=1) -> Vector{Float64}

Parse a single- or multi-column numeric axis file (text headers and a bare
row-count first line are skipped; first numeric column by default). Public
wrapper over the parser `load_ta_matrix` uses, for callers that need to
preview an axis before loading (e.g. QPSLab's import dialog).
"""
read_axis_file(path::String; column::Int=1) = _load_axis_file(path; column=column)

"""
Find a file in directory matching any of the patterns.
"""
function _find_file(dir::String, patterns::Vector{String}; extensions=[".txt", ".csv", ".lvm"])
    result = _find_file_or_nothing(dir, patterns; extensions=extensions)
    if isnothing(result)
        files = readdir(dir)
        error("Could not find file matching patterns $patterns in $dir. Found: $files")
    end
    return result
end

"""
Find a file in directory matching any of the patterns. Returns `nothing` if no match.
"""
function _find_file_or_nothing(dir::String, patterns::Vector{String}; extensions=[".txt", ".csv", ".lvm"])
    files = readdir(dir)
    for ext in extensions
        for pattern in patterns
            for f in files
                if occursin(lowercase(pattern), lowercase(f)) && endswith(lowercase(f), ext)
                    return f
                end
            end
        end
    end
    return nothing
end

"""
Load a single-column axis file (time or wavelength).
Handles common formats: plain values, with header, multi-column with header.

For multi-column files (e.g., wavelength reference with extra CCD data),
takes the **first** numeric column by default. Use `column` keyword to override.
"""
function _load_axis_file(path::String; column::Int=1)
    lines = readlines(path)

    # Skip header lines that are non-numeric or contain text
    start_idx = 1
    for (i, line) in enumerate(lines)
        # Handle \r in line (LabVIEW quirk: header\rdata on same line)
        stripped = strip(replace(line, '\r' => '\t'))
        isempty(stripped) && continue
        # Check if line contains letters (header text)
        if occursin(r"[a-zA-Z_]", stripped)
            start_idx = i + 1
            continue
        end
        # Check if it's a single integer on line 1 (likely a count header)
        if match(r"^\d+$", stripped) !== nothing && i == 1
            start_idx = i + 1
            continue
        end
        # This line looks like data
        start_idx = i
        break
    end

    # Parse values from the specified column
    values = Float64[]
    for i in start_idx:length(lines)
        line = lines[i]
        stripped = strip(replace(line, '\r' => '\t'))
        isempty(stripped) && continue
        parts = split(stripped)
        if length(parts) >= column
            val = tryparse(Float64, parts[column])
            if !isnothing(val)
                push!(values, val)
            end
        end
    end

    return values
end

"""
Load a matrix file (tab or comma separated).
Handles LVM and CSV formats with optional header rows.
"""
function _load_matrix_file(path::String)
    lines = readlines(path)

    # Find first data line (line with multiple numeric values separated by delimiter)
    data_start = 1
    for (i, line) in enumerate(lines)
        stripped = strip(line)
        isempty(stripped) && continue

        # Detect delimiter for this line
        delimiter = occursin('\t', stripped) ? '\t' : ','

        parts = split(stripped, delimiter)
        parts = filter(!isempty, parts)

        # Check if we have multiple numeric values (data row)
        if length(parts) > 1 && all(p -> tryparse(Float64, strip(p)) !== nothing, parts)
            data_start = i
            break
        end

        # Skip header-like lines (single values, text, etc.)
    end

    # Determine delimiter from first data line
    delimiter = occursin('\t', lines[data_start]) ? '\t' : ','

    # Parse data rows
    n_rows = length(lines) - data_start + 1
    first_parts = filter(!isempty, split(lines[data_start], delimiter))
    n_cols = length(first_parts)

    data = Matrix{Float64}(undef, n_rows, n_cols)
    for (j, line_idx) in enumerate(data_start:length(lines))
        parts = split(lines[line_idx], delimiter)
        parts = filter(!isempty, parts)
        for (k, val) in enumerate(parts)
            if k <= n_cols
                data[j, k] = parse(Float64, strip(val))
            end
        end
    end

    return data
end

# =============================================================================
# Unified loading interface
# =============================================================================

"""
    load_spectroscopy(path; kwargs...) -> Union{KineticTrace, Spectrum, TimeResolvedMatrix}

Auto-detect measurement type and return the appropriate high-level type.

This is the recommended entry point for data viewers and general-purpose tools
that need to handle any spectroscopy data type uniformly.

# Auto-detection logic
1. **Directory path** → `TimeResolvedMatrix` (broadband TA with separate axis files)
2. **LVM file with time axis** → `KineticTrace` (kinetics measurement)
3. **LVM file with wavelength axis** → `Spectrum` (spectral measurement)
4. **Plain two-column text file with a time-like first column** (negative values
   or fs-scale magnitudes) → `KineticTrace` (pre-processed trace export)

# Keyword arguments
Passed through to the appropriate loader:
- `mode::Symbol` — Signal computation mode (:OD, :transmission, :diff)
- `channel::Int` — Detector channel (1-4)
- `calibration::Float64` — Wavenumber calibration offset (for spectra)
- `shift_t0::Bool` — Shift time axis so peak is at t=0 (for traces)

# Returns
- `KineticTrace` — For kinetics (time vs ΔA)
- `Spectrum` — For spectra (wavenumber vs ΔA)
- `TimeResolvedMatrix` — For broadband data (time × wavelength)

# Example
```julia
# Auto-detect and load
data = load_spectroscopy("measurement.lvm")

# Use the uniform interface
plot(xdata(data), ydata(data))
ax.xlabel = xlabel(data)
ax.ylabel = ylabel(data)

# Type-specific handling if needed
if is_matrix(data)
    heatmap(xdata(data), ydata(data), zdata(data)')
else
    lines(xdata(data), ydata(data))
end
```
"""
function load_spectroscopy(path::String; kwargs...)
    # Case 1: Directory → TimeResolvedMatrix
    if isdir(path)
        return load_ta_matrix(path; kwargs...)
    end

    # Case 2: File → detect type from content
    if !isfile(path)
        error("Path does not exist: $path")
    end

    # For LVM files, peek at the content to determine type
    ext = lowercase(splitext(path)[2])
    if ext == ".lvm"
        axis_type = _detect_lvm_axis_type(path)
        if axis_type == time_axis
            return load_ta_trace(path; kwargs...)
        else
            return load_ta_spectrum(path; kwargs...)
        end
    end

    # Plain two-column text: a first column with negative values (pre-t0
    # points) or fs-scale magnitudes is a time axis → kinetic trace. An
    # all-positive, small-magnitude first column is ambiguous (could be a
    # wavelength axis), so fall through to the error below.
    if _is_plain_xy_file(path)
        x, _ = _read_xy(path)
        if !isempty(x) && (minimum(x) < 0 || maximum(abs, x) > 1e4)
            return load_ta_trace(path; kwargs...)
        end
    end

    # For other file types, try to infer from content or name
    error("Cannot auto-detect type for file: $path. Use load_ta_trace, load_ta_spectrum, or load_ta_matrix directly.")
end

"""
    _detect_lvm_axis_type(filepath) -> AxisType

Peek at an LVM file to determine if it contains time or wavelength data.
"""
function _detect_lvm_axis_type(filepath::String)
    lines = readlines(filepath)

    # Look for "Time" or "wavelength" section headers
    time_start = findfirst(l -> startswith(l, "Time"), lines)
    wavelength_start = findfirst(l -> occursin("wavelength", lowercase(l)), lines)

    if !isnothing(time_start)
        return time_axis
    elseif !isnothing(wavelength_start)
        return wavelength_axis
    else
        # Fallback: assume time if no clear indicator
        return time_axis
    end
end
