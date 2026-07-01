# PL map loader for LabVIEW CCD raster scan files

using DelimitedFiles: readdlm

"""
    load_wavelength_file(path::String) -> Vector{Float64}

Read a CCD wavelength calibration sidecar file. The file is two-column
tab-separated (wavelength nm, intensity counts) with a one-line header.
Only the wavelength column is returned.

Line endings may be mixed `\\r` and `\\r\\n` (LabVIEW quirk).
"""
function load_wavelength_file(path::String)
    text = read(path, String)
    # Normalize line endings: split on \r\n or standalone \r or \n
    lines = split(replace(text, "\r\n" => "\n"), r"[\r\n]"; keepempty=false)

    # Skip header line (contains column names)
    data_lines = lines[2:end]

    wavelengths = Vector{Float64}(undef, length(data_lines))
    for (i, line) in enumerate(data_lines)
        parts = split(strip(line), '\t')
        wavelengths[i] = parse(Float64, parts[1])
    end

    return wavelengths
end

"""
    generate_wavelength_axis(n_pixel; start, stop=nothing, dispersion=nothing) -> Vector{Float64}

Build a length-`n_pixel` linear wavelength axis (nm) without a calibration
file, for the common constant-dispersion spectrometer case. The result is a
drop-in replacement for [`load_wavelength_file`](@ref) — assign it to a
`PLMap`'s pixel axis.

Provide exactly one of `stop` or `dispersion` alongside `start`:
- `stop`: even ramp from `start` to `stop` inclusive (`range(start, stop, length=n_pixel)`).
- `dispersion`: `start .+ (0:n_pixel-1) .* dispersion`, where `dispersion` is nm/pixel.

Throws an `ArgumentError` if `n_pixel < 2`, if neither or both of `stop`/`dispersion`
are given, if `stop == start`, or if `dispersion == 0` (all degenerate axes).

# Examples
```julia
generate_wavelength_axis(512; start=500.0, stop=700.0)
generate_wavelength_axis(512; start=500.0, dispersion=0.39)
```
"""
function generate_wavelength_axis(n_pixel::Integer; start::Real,
                                  stop::Union{Real,Nothing}=nothing,
                                  dispersion::Union{Real,Nothing}=nothing)
    n_pixel >= 2 || throw(ArgumentError("n_pixel must be at least 2 (got $n_pixel)."))

    has_stop = !isnothing(stop)
    has_disp = !isnothing(dispersion)
    if has_stop == has_disp
        throw(ArgumentError("Provide exactly one of `stop` or `dispersion`."))
    end

    if has_stop
        stop == start && throw(ArgumentError("`stop` ($stop) must differ from `start` ($start)."))
        return collect(range(Float64(start), Float64(stop), length=n_pixel))
    else
        dispersion == 0 && throw(ArgumentError("`dispersion` must be nonzero."))
        return Float64(start) .+ (0:n_pixel-1) .* Float64(dispersion)
    end
end

# =============================================================================
# Raster grid inference
# =============================================================================

# Read a CCD raster `.lvm` into a Float64 matrix (one row per spatial point,
# one column per CCD pixel), skipping the optional single-integer row-count
# header line.
function _read_ccd_lvm(filepath::String)
    raw = readdlm(filepath)
    data_start = 1
    if size(raw, 1) > 1 && size(raw, 2) == 1 || (size(raw, 2) > 1 && all(raw[1, 2:end] .== 0))
        # First row is a single value (row-count header).
        if size(raw, 2) == 1 || count(!iszero, raw[1, :]) == 1
            data_start = 2
        end
    end
    # Robust check: a lone-integer first line is a row count. Only the first line
    # is needed, so read just that rather than the whole file again.
    if match(r"^\d+$", strip(readline(filepath))) !== nothing
        data_start = 2
    end
    return Float64.(raw[data_start:end, :])
end

# Nontrivial divisor pairs (a, n÷a) with a ≤ √n, smallest factor first.
_divisor_pairs(n::Integer) = [(d, n ÷ d) for d in 1:isqrt(n) if n % d == 0]

"""
    _alignment_cost(signal, nx, serpentine) -> Float64

Mean `|Δ|` between same-column, adjacent-row points when a length-`n` scan
`signal` is folded column-major into an `nx`-by-`n÷nx` image (`nx` = fast axis).
`serpentine=true` reverses the fast-axis order on even rows (boustrophedon scan).
The true grid makes consecutive rows line up, minimising this cost.
"""
function _alignment_cost(signal::AbstractVector, nx::Integer, serpentine::Bool)
    ny = length(signal) ÷ nx
    img = reshape(view(signal, 1:nx*ny), nx, ny)
    total = 0.0
    count = 0
    for j in 1:(ny - 1)
        flipj  = serpentine && iseven(j)
        flipj1 = serpentine && iseven(j + 1)
        for p in 1:nx
            a = img[flipj  ? nx - p + 1 : p, j]
            b = img[flipj1 ? nx - p + 1 : p, j + 1]
            total += abs(b - a)
            count += 1
        end
    end
    return count == 0 ? Inf : total / count
end

"""
    _infer_raster_grid(signal; min_side=8, aspect_max=20, confidence=0.9)

Infer `(nx, ny, serpentine)` for a raster scan from a per-point summary `signal`
(e.g. integrated intensity), or `nothing` when no folding is clearly best.

A 2-D raster is spatially continuous, so the true fast-axis width `nx` folds the
1-D stream into an image whose adjacent rows line up column-for-column — the
minimum [`_alignment_cost`](@ref). Every divisor of `length(signal)` with a
plausible aspect ratio is scored in both scan directions; the lowest-cost
candidate is returned only if it beats the runner-up by the `confidence` margin
(otherwise the fold is ambiguous and the caller should fall back).
"""
function _infer_raster_grid(signal::AbstractVector; min_side::Integer=8,
                            aspect_max::Real=20.0, confidence::Real=0.9)
    n = length(signal)
    # Best (cost, serpentine) achievable at each candidate fast-axis width. The
    # scan *direction* is a per-width choice — a map symmetric about the fast axis
    # scores the same both ways — so it must not count against grid confidence.
    per_nx = Tuple{Float64,Int,Bool}[]        # (best_cost, nx, serpentine)
    for (a, b) in _divisor_pairs(n)
        for nx in unique((a, b))
            ny = n ÷ nx
            (min(nx, ny) >= min_side) || continue
            (max(nx, ny) / min(nx, ny) <= aspect_max) || continue
            cu = _alignment_cost(signal, nx, false)
            cs = _alignment_cost(signal, nx, true)
            push!(per_nx, cs < cu ? (cs, nx, true) : (cu, nx, false))
        end
    end
    isempty(per_nx) && return nothing
    sort!(per_nx; by = first)
    best = per_nx[1]
    runner = length(per_nx) >= 2 ? per_nx[2][1] : Inf   # next distinct width
    (best[1] < confidence * runner) || return nothing   # grid ambiguous → give up
    return (nx = best[2], ny = n ÷ best[2], serpentine = best[3])
end

"""
    detect_pl_grid(filepath) -> NamedTuple or nothing

Infer a CCD raster map's grid straight from the `.lvm` on disk, without building
a [`PLMap`](@ref). Returns `(; nx, ny, serpentine, n_points)` when the fold is
unambiguous (see [`_infer_raster_grid`](@ref)), or `nothing` when it can't be
inferred and the caller should ask for explicit dimensions. Intended for
pre-filling a load dialog with the right dimensions and scan direction.
"""
function detect_pl_grid(filepath::String)
    data = _read_ccd_lvm(filepath)
    n_points = size(data, 1)
    inferred = _infer_raster_grid(vec(sum(data; dims=2)))
    inferred === nothing && return nothing
    return (; inferred.nx, inferred.ny, inferred.serpentine, n_points)
end

"""
    load_pl_map(filepath; nx=nothing, ny=nothing, step_size=1.0,
                pixel_range=nothing, center=true, snake=nothing,
                wavelength=nothing) -> PLMap

Load a PL/Raman spatial map from a CCD raster scan file.

The file is a LabVIEW `.lvm` containing a row-count header followed by
tab-separated CCD spectra (one row per spatial point, one column per pixel).

# Arguments
- `filepath`: Path to `.lvm` CCD data file
- `nx`, `ny`: Grid dimensions. If neither is given they are inferred from the
  map's spatial continuity (see [`_infer_raster_grid`](@ref)), falling back to a
  square grid and then to an error that lists the candidate factor pairs. Give
  one to fix it and derive the other.
- `step_size`: Spatial step between grid points in μm (default 1.0)
- `pixel_range`: `(start, stop)` pixel range for intensity integration.
  If `nothing` (default), integrates over all pixels.
- `center`: Center spatial axes at zero (default `true`)
- `snake`: Boustrophedon (serpentine) scan — reverse every other row before
  folding. `nothing` (default) auto-detects direction when the grid is inferred;
  pass `true`/`false` to force it.
- `wavelength`: Optional wavelength calibration vector (nm). If provided,
  replaces the default pixel index axis. Must have length equal to `n_pixel`.

# Returns
`PLMap` with integrated intensity and full spectral data.

# Example
```julia
m = load_pl_map("data/PLmap/CCDtmp_260129_111138.lvm"; nx=51, ny=51, step_size=2.16)
println(m)
```
"""
function load_pl_map(filepath::String; nx::Union{Int,Nothing}=nothing,
                     ny::Union{Int,Nothing}=nothing, step_size::Real=1.0,
                     pixel_range::Union{Tuple{Int,Int},Nothing}=nothing,
                     center::Bool=true,
                     snake::Union{Bool,Nothing}=nothing,
                     wavelength::Union{Vector{Float64},Nothing}=nothing)

    data = _read_ccd_lvm(filepath)
    n_points, n_pixel = size(data)

    # Infer grid dimensions. With neither side given, recover the raster shape
    # (and scan direction) from the spatial continuity of the map; fall back to a
    # square grid, then to an error that lists the candidate factorisations.
    auto = isnothing(nx) && isnothing(ny)
    detected_serpentine = false
    if auto
        inferred = _infer_raster_grid(vec(sum(data; dims=2)))
        if inferred !== nothing
            nx, ny = inferred.nx, inferred.ny
            detected_serpentine = inferred.serpentine
        else
            n_side = isqrt(n_points)
            if n_side * n_side == n_points
                nx = ny = n_side
            else
                error("Cannot infer a grid for $n_points points: no confident " *
                      "rectangular fold and not a perfect square. Candidate " *
                      "factor pairs: $(_divisor_pairs(n_points)[2:end]). " *
                      "Specify nx and ny.")
            end
        end
    elseif isnothing(nx)
        nx = div(n_points, ny)
    elseif isnothing(ny)
        ny = div(n_points, nx)
    end

    if nx * ny != n_points
        error("Grid dimensions $(nx)×$(ny) = $(nx*ny) do not match $n_points data points.")
    end

    # Serpentine (boustrophedon) scans store even rows in reverse fast-axis order.
    # Undo that before folding so the map isn't zig-zag scrambled. An explicit
    # `snake` overrides detection; otherwise honour what inference found.
    serpentine = isnothing(snake) ? detected_serpentine : snake
    if serpentine
        order = collect(1:n_points)
        for iy in 2:2:ny
            block = ((iy - 1) * nx + 1):(iy * nx)
            order[block] = reverse(block)
        end
        data = data[order, :]
    end

    # Channel-major (n_pixel, nx, ny): one pixel's spectrum is the contiguous
    # first axis. data is (n_points, n_pixel) = (nx*ny, n_pixel); transpose then
    # reshape so the spectral axis leads.
    spectra = reshape(permutedims(data), n_pixel, nx, ny)

    # Integrate spectra to get intensity map (channel axis is dim 1)
    if !isnothing(pixel_range)
        p1, p2 = pixel_range
        p1 = max(1, p1)
        p2 = min(n_pixel, p2)
        int_matrix = dropdims(sum((@view spectra[p1:p2, :, :]); dims=1); dims=1)
    else
        int_matrix = dropdims(sum(spectra; dims=1); dims=1)
    end

    # Build spatial axes
    step = Float64(step_size)
    if center
        x = range(-(nx-1)/2 * step, (nx-1)/2 * step, length=nx) |> collect
        y = range(-(ny-1)/2 * step, (ny-1)/2 * step, length=ny) |> collect
    else
        x = range(0, (nx-1) * step, length=nx) |> collect
        y = range(0, (ny-1) * step, length=ny) |> collect
    end

    if !isnothing(wavelength)
        if length(wavelength) != n_pixel
            error("Wavelength vector length ($(length(wavelength))) does not match pixel count ($n_pixel).")
        end
        pixel = wavelength
    else
        pixel = collect(1.0:n_pixel)
    end

    metadata = Dict{Symbol,Any}(
        :source_file => basename(filepath),
        :filepath => filepath,
        :nx => nx,
        :ny => ny,
        :n_pixel => n_pixel,
        :step_size => step,
        :pixel_range => pixel_range,
        :centered => center,
        :serpentine => serpentine,
        :grid_inferred => auto,
        # Axis tokens (spatial step is in µm; integrated CCD signal is counts)
        :technique => :pl,
        :position_unit => :um,
        :yquantity => :intensity,
        :yunit => :counts,
    )

    return PLMap(int_matrix, spectra, x, y, pixel, metadata)
end
