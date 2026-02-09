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

find_peak_time(trace::TATrace) = find_peak_time(trace.time, trace.signal)

# =============================================================================
# Transient Absorption loading (unified API)
# =============================================================================

"""
    load_ta_trace(filepath; mode=:OD, channel=1, wavelength=NaN, shift_t0=true) -> TATrace

Load a transient absorption kinetic trace from a single-pixel detector file.

The time axis is automatically shifted so that the signal peak (pump-probe overlap)
is at t = 0. This is the standard convention for ultrafast spectroscopy.

# Arguments
- `filepath`: Path to .lvm file
- `mode`: How to compute ΔA signal
  - `:OD` — ΔOD = -log₁₀(ON/OFF) (default, for bare molecules)
  - `:transmission` — -ΔT/T = -(ON - OFF)/OFF
  - `:diff` — Raw lock-in difference signal
- `channel`: Detector channel (1-4, default 1 = CH0)
- `wavelength`: Probe wavelength in nm or cm⁻¹ (default NaN = unknown)
- `shift_t0`: Shift time axis so peak is at t=0 (default true)

# Returns
`TATrace` ready for fitting with `fit_exp_decay`.

# Example
```julia
trace = load_ta_trace("data.lvm"; mode=:OD)
trace.time[1]  # Negative (before pump-probe overlap)
# Peak signal is at t ≈ 0
```
"""
function load_ta_trace(filepath::String; mode::Symbol=:OD, channel::Int=1,
                       wavelength::Float64=NaN, shift_t0::Bool=true)
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

    return TATrace(time, signal, wavelength, metadata)
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
    load_ta_spectrum(filepath; mode=:OD, channel=1, calibration=0.0, time_delay=NaN) -> TASpectrum

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
`TASpectrum` with wavenumber and ΔA signal.

# Example
```julia
spec = load_ta_spectrum("bare_1M_1ps.lvm"; mode=:OD, calibration=-19.0)
spec.wavenumber  # cm⁻¹ (calibrated)
spec.signal      # ΔA values
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
        :calibration => calibration
    )

    return TASpectrum(wavenumber, signal, time_delay, metadata)
end

# =============================================================================
# TAMatrix loading (2D broadband TA data)
# =============================================================================

"""
    load_ta_matrix(dir; time_file=nothing, wavelength_file=nothing, data_file=nothing,
                   time=nothing, time_unit=:fs, wavelength_unit=:nm) -> TAMatrix

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
- `time_unit`: Unit of time axis file, `:fs` (default) or `:ps`. Ignored when `time` vector is provided.
- `wavelength_unit`: Unit of wavelength axis, `:nm` (default) or `:cm⁻¹`

# Auto-detection
If files are not specified, looks for common naming patterns:
- Time: `time*.txt`, `delay*.txt`, `*time*.txt`
- Wavelength: `wavelength*.txt`, `lambda*.txt`, `wl_axis*.txt`, `波長*.txt`
- Data: `CCDABS*.lvm`, `ta_matrix*.txt`, `*matrix*.txt`, `*data*.lvm`

# File Formats
- Time/wavelength axis files: Single or multi-column numeric values (first column used)
- Data matrix: Tab or comma-separated, rows = time points, cols = wavelengths.
  A single-integer first line (row count) is automatically skipped.

# Returns
`TAMatrix` ready for extraction and fitting.

# Example
```julia
# Auto-detect files in directory
matrix = load_ta_matrix("data/broadband-TA/")

# Explicit file paths
matrix = load_ta_matrix("data/",
    time_file="time_axis.txt",
    wavelength_file="wavelength.txt",
    data_file="ta_matrix.lvm")

# CCD data with instrument-defined time axis (no time file)
time_fs = collect(-20000:400.28:180000)  # instrument step size
matrix = load_ta_matrix("data/ccd/",
    time=time_fs ./ 1000,  # convert to ps
    data_file="CCDABS_251202.lvm")

# Extract kinetics and fit
trace = matrix[λ=800]
result = fit_exp_decay(trace)
```
"""
function load_ta_matrix(dir::String; time_file::Union{String,Nothing}=nothing,
                        wavelength_file::Union{String,Nothing}=nothing,
                        data_file::Union{String,Nothing}=nothing,
                        time::Union{AbstractVector,Nothing}=nothing,
                        time_unit::Symbol=:fs,
                        wavelength_unit::Symbol=:nm)

    # Auto-detect data file if not specified
    if isnothing(data_file)
        data_file = _find_file(dir, ["CCDABS", "matrix", "ta_", "data"];
                               extensions=[".lvm", ".txt", ".csv"])
    end

    # Auto-detect wavelength file if not specified
    if isnothing(wavelength_file)
        wavelength_file = _find_file(dir, ["wavelength", "lambda", "wl_axis", "波長", "nm"])
    end

    # Build full paths
    wavelength_path = joinpath(dir, wavelength_file)
    data_path = joinpath(dir, data_file)

    # Load time axis (from vector, file, or row indices)
    if !isnothing(time)
        time_vec = collect(Float64, time)
    elseif !isnothing(time_file)
        time_raw = _load_axis_file(joinpath(dir, time_file))
        time_vec = time_unit == :fs ? time_raw ./ 1000 : Float64.(time_raw)
    else
        # Try auto-detecting a time file
        time_file_found = _find_file_or_nothing(dir, ["time", "delay", "t_axis"])
        if !isnothing(time_file_found)
            time_raw = _load_axis_file(joinpath(dir, time_file_found))
            time_vec = time_unit == :fs ? time_raw ./ 1000 : Float64.(time_raw)
            time_file = time_file_found
        else
            time_vec = nothing  # Will be set after loading matrix
        end
    end

    # Load wavelength axis
    wavelength = _load_axis_file(wavelength_path)

    # Load data matrix
    data = _load_matrix_file(data_path)

    # If no time axis was found, use row indices
    if isnothing(time_vec)
        time_vec = collect(1.0:size(data, 1))
        @warn "No time axis found. Using row indices (1:$(size(data, 1)))."
    end

    # Validate dimensions
    n_time, n_wl = size(data)
    if length(time_vec) != n_time
        # Try transpose
        if length(time_vec) == n_wl && length(wavelength) == n_time
            data = collect(data')
            n_time, n_wl = size(data)
        else
            @warn "Time axis length ($(length(time_vec))) does not match matrix rows ($n_time). Truncating."
            n = min(length(time_vec), n_time)
            time_vec = time_vec[1:n]
            data = data[1:n, :]
        end
    end
    if length(wavelength) != n_wl
        @warn "Wavelength axis length ($(length(wavelength))) does not match matrix columns ($n_wl). Truncating to shorter."
        n = min(length(wavelength), n_wl)
        wavelength = wavelength[1:n]
        data = data[:, 1:n]
    end

    metadata = Dict{Symbol,Any}(
        :source => dir,
        :time_file => something(time_file, "direct"),
        :wavelength_file => wavelength_file,
        :data_file => data_file,
        :time_unit => time_unit,
        :wavelength_unit => wavelength_unit
    )

    return TAMatrix(time_vec, wavelength, data, metadata)
end

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
    load_spectroscopy(path; kwargs...) -> Union{TATrace, TASpectrum, TAMatrix}

Auto-detect measurement type and return the appropriate high-level type.

This is the recommended entry point for data viewers and general-purpose tools
that need to handle any spectroscopy data type uniformly.

# Auto-detection logic
1. **Directory path** → `TAMatrix` (broadband TA with separate axis files)
2. **LVM file with time axis** → `TATrace` (kinetics measurement)
3. **LVM file with wavelength axis** → `TASpectrum` (spectral measurement)

# Keyword arguments
Passed through to the appropriate loader:
- `mode::Symbol` — Signal computation mode (:OD, :transmission, :diff)
- `channel::Int` — Detector channel (1-4)
- `calibration::Float64` — Wavenumber calibration offset (for spectra)
- `shift_t0::Bool` — Shift time axis so peak is at t=0 (for traces)

# Returns
- `TATrace` — For kinetics (time vs ΔA)
- `TASpectrum` — For spectra (wavenumber vs ΔA)
- `TAMatrix` — For broadband data (time × wavelength)

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
    # Case 1: Directory → TAMatrix
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
