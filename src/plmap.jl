# PL mapping analysis for CCD raster scans (Raman/PL spatial mapping)

using DelimitedFiles: readdlm

# =============================================================================
# PLMap type
# =============================================================================

"""
    PLMap <: AbstractSpectroscopyData

Photoluminescence intensity map from a CCD raster scan.

A 2D spatial grid where each point has a full CCD spectrum. The `intensity`
field holds the integrated PL signal at each position; the full spectra are
stored in `spectra` for extraction at individual positions.

# Fields
- `intensity::Matrix{Float64}` — Integrated PL intensity `(nx, ny)`
- `spectra::Array{Float64,3}` — Raw CCD counts `(nx, ny, n_pixel)`
- `x::Vector{Float64}` — Spatial x positions (μm)
- `y::Vector{Float64}` — Spatial y positions (μm)
- `pixel::Vector{Float64}` — Pixel indices (or wavelength if calibrated)
- `metadata::Dict{String,Any}` — Source file, grid dims, step size, etc.
"""
struct PLMap <: AbstractSpectroscopyData
    intensity::Matrix{Float64}
    spectra::Array{Float64,3}
    x::Vector{Float64}
    y::Vector{Float64}
    pixel::Vector{Float64}
    metadata::Dict{String,Any}
end

# =============================================================================
# AbstractSpectroscopyData interface
# =============================================================================

xdata(m::PLMap) = m.x
ydata(m::PLMap) = m.y
zdata(m::PLMap) = m.intensity
xlabel(::PLMap) = "X (μm)"
ylabel(::PLMap) = "Y (μm)"
zlabel(::PLMap) = "PL Intensity"
is_matrix(::PLMap) = true
npoints(m::PLMap) = (length(m.x), length(m.y))
source_file(m::PLMap) = get(m.metadata, "source_file", "unknown")
title(m::PLMap) = source_file(m)

# Semantic accessor
"""
    intensity(m::PLMap) -> Matrix{Float64}

Return the PL intensity matrix.
"""
intensity(m::PLMap) = m.intensity

function Base.show(io::IO, m::PLMap)
    nx, ny = length(m.x), length(m.y)
    np = length(m.pixel)
    print(io, "PLMap($(nx)×$(ny) grid, $(np) pixels)")
end

function Base.show(io::IO, ::MIME"text/plain", m::PLMap)
    nx, ny = length(m.x), length(m.y)
    np = length(m.pixel)
    println(io, "PLMap")
    println(io, "  Grid:     $(nx) × $(ny) spatial points")
    println(io, "  Pixels:   $(np) per spectrum")
    println(io, "  X range:  $(round(m.x[1], digits=1)) to $(round(m.x[end], digits=1)) μm")
    println(io, "  Y range:  $(round(m.y[1], digits=1)) to $(round(m.y[end], digits=1)) μm")
    print(io, "  Source:   $(source_file(m))")
end

# =============================================================================
# Loader
# =============================================================================

"""
    load_pl_map(filepath; nx=nothing, ny=nothing, step_size=1.0,
                pixel_range=nothing, center=true) -> PLMap

Load a PL/Raman spatial map from a CCD raster scan file.

The file is a LabVIEW `.lvm` containing a row-count header followed by
tab-separated CCD spectra (one row per spatial point, one column per pixel).

# Arguments
- `filepath`: Path to `.lvm` CCD data file
- `nx`, `ny`: Grid dimensions. If not given, assumes a square grid (`√n_points`)
- `step_size`: Spatial step between grid points in μm (default 1.0)
- `pixel_range`: `(start, stop)` pixel range for intensity integration.
  If `nothing` (default), integrates over all pixels.
- `center`: Center spatial axes at zero (default `true`)

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
                     center::Bool=true)

    raw = readdlm(filepath)

    # First line may be a row count (single integer); skip if so
    data_start = 1
    if size(raw, 1) > 1 && size(raw, 2) == 1 || (size(raw, 2) > 1 && all(raw[1, 2:end] .== 0))
        # Check if first row is a single value (row count header)
        if size(raw, 2) == 1 || count(!iszero, raw[1, :]) == 1
            data_start = 2
        end
    end

    # More robust: read file, detect header
    lines = readlines(filepath)
    first_line = strip(lines[1])
    if match(r"^\d+$", first_line) !== nothing
        # Single integer header (row count) — skip it
        data_start = 2
    end

    data = Float64.(raw[data_start:end, :])
    n_points, n_pixel = size(data)

    # Infer grid dimensions
    if isnothing(nx) && isnothing(ny)
        n_side = isqrt(n_points)
        if n_side * n_side != n_points
            error("Cannot infer square grid: $n_points points is not a perfect square. Specify nx and ny.")
        end
        nx = n_side
        ny = n_side
    elseif isnothing(nx)
        nx = div(n_points, ny)
    elseif isnothing(ny)
        ny = div(n_points, nx)
    end

    if nx * ny != n_points
        error("Grid dimensions $(nx)×$(ny) = $(nx*ny) do not match $n_points data points.")
    end

    # Reshape to (nx, ny, n_pixel)
    spectra = reshape(data, nx, ny, n_pixel)

    # Integrate spectra to get intensity map
    if !isnothing(pixel_range)
        p1, p2 = pixel_range
        p1 = max(1, p1)
        p2 = min(n_pixel, p2)
        intensity = dropdims(sum(spectra[:, :, p1:p2]; dims=3); dims=3)
    else
        intensity = dropdims(sum(spectra; dims=3); dims=3)
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

    pixel = collect(1.0:n_pixel)

    metadata = Dict{String,Any}(
        "source_file" => basename(filepath),
        "filepath" => filepath,
        "nx" => nx,
        "ny" => ny,
        "n_pixel" => n_pixel,
        "step_size" => step,
        "pixel_range" => pixel_range,
        "centered" => center,
    )

    return PLMap(intensity, spectra, x, y, pixel, metadata)
end

# =============================================================================
# Spectrum extraction
# =============================================================================

"""
    extract_spectrum(m::PLMap, ix::Int, iy::Int) -> NamedTuple

Extract the CCD spectrum at grid index `(ix, iy)`.

Returns `(pixel=..., signal=..., x=..., y=...)`.
"""
function extract_spectrum(m::PLMap, ix::Int, iy::Int)
    1 <= ix <= length(m.x) || error("ix=$ix out of range 1:$(length(m.x))")
    1 <= iy <= length(m.y) || error("iy=$iy out of range 1:$(length(m.y))")
    return (pixel=m.pixel, signal=vec(m.spectra[ix, iy, :]),
            x=m.x[ix], y=m.y[iy])
end

"""
    extract_spectrum(m::PLMap; x::Real, y::Real) -> NamedTuple

Extract the CCD spectrum at the spatial position nearest to `(x, y)`.

Returns `(pixel=..., signal=..., x=..., y=..., ix=..., iy=...)`.
"""
function extract_spectrum(m::PLMap; x::Real, y::Real)
    ix = argmin(abs.(m.x .- x))
    iy = argmin(abs.(m.y .- y))
    spec = extract_spectrum(m, ix, iy)
    return (pixel=spec.pixel, signal=spec.signal,
            x=spec.x, y=spec.y, ix=ix, iy=iy)
end

# =============================================================================
# Background subtraction
# =============================================================================

"""
    subtract_background(m::PLMap; positions=nothing, margin=5) -> PLMap

Subtract a background spectrum from every grid point.

The background is the average CCD spectrum over the reference positions.
After subtraction, the intensity map is recomputed from the corrected spectra
using the same `pixel_range` as the original load (if any).

# Arguments
- `positions`: Vector of `(x, y)` spatial coordinate tuples (μm) for background
  reference points. These should be off-flake positions with no PL signal.
- `margin`: Number of grid points from each edge used for auto-detection when
  `positions` is not given. Auto mode averages the corners of the bottom half
  of the map (avoids top-row artifacts). Default: 5.

# Example
```julia
m = load_pl_map("data.lvm"; nx=51, ny=51, step_size=2.16, pixel_range=(950, 1100))

# Explicit background positions
m_bg = subtract_background(m; positions=[(-40, -40), (40, -40), (-40, -20)])

# Auto mode (bottom corners)
m_bg = subtract_background(m)
```
"""
function subtract_background(m::PLMap; positions=nothing, margin::Int=5)
    nx, ny = length(m.x), length(m.y)

    if !isnothing(positions)
        # Explicit: average spectra at user-specified (x, y) positions
        bg_spectra = zeros(length(m.pixel))
        for pos in positions
            spec = extract_spectrum(m; x=pos[1], y=pos[2])
            bg_spectra .+= spec.signal
        end
        bg_spectra ./= length(positions)
    else
        # Auto: average corners from the bottom half of the map
        bg_spectra = zeros(length(m.pixel))
        count = 0
        for ix in [1:margin; (nx-margin+1):nx]
            for iy in 1:margin
                bg_spectra .+= vec(m.spectra[ix, iy, :])
                count += 1
            end
        end
        bg_spectra ./= count
    end

    # Subtract background spectrum from every grid point
    corrected = m.spectra .- reshape(bg_spectra, 1, 1, :)

    # Recompute intensity with the same pixel_range as the original
    pixel_range = get(m.metadata, "pixel_range", nothing)
    if !isnothing(pixel_range)
        p1, p2 = pixel_range
        intensity = dropdims(sum(corrected[:, :, p1:p2]; dims=3); dims=3)
    else
        intensity = dropdims(sum(corrected; dims=3); dims=3)
    end

    return PLMap(intensity, corrected, m.x, m.y, m.pixel, m.metadata)
end

# =============================================================================
# Normalization
# =============================================================================

"""
    normalize(m::PLMap) -> PLMap

Return a new PLMap with intensity normalized to [0, 1].
"""
function normalize(m::PLMap)
    imin, imax = extrema(m.intensity)
    if imax == imin
        norm_intensity = zeros(size(m.intensity))
    else
        norm_intensity = (m.intensity .- imin) ./ (imax - imin)
    end
    return PLMap(norm_intensity, m.spectra, m.x, m.y, m.pixel, m.metadata)
end

# =============================================================================
# Peak center (centroid) map
# =============================================================================

"""
    peak_centers(m::PLMap; pixel_range=nothing, threshold=0.05) -> Matrix{Float64}

Compute the centroid (intensity-weighted average pixel) at each grid point.

Returns a `(nx, ny)` matrix of peak center positions in pixel units. Grid points
where the PL intensity (`m.intensity`) is below `threshold` × the map maximum
are set to `NaN` (renders as transparent in heatmaps with `nan_color=:transparent`).

Masking uses the PLMap's intensity field — the integrated PL signal already stored
in the map. This produces clean masks that match the intensity heatmap: off-flake
regions (low PL signal) are transparent, on-flake regions show centroid positions.

# Arguments
- `pixel_range`: `(start, stop)` pixel range to compute the centroid over.
  Falls back to the `pixel_range` stored in metadata, or all pixels if unset.
- `threshold`: Fraction of the maximum PL intensity below which a grid point is
  masked as `NaN`. Default `0.05` (5%). Set to `0` to disable masking.

# Example
```julia
m = load_pl_map("scan.lvm"; nx=51, ny=51, pixel_range=(950, 1100))
m = subtract_background(m)
centers = peak_centers(m)
heatmap(m.x, m.y, centers'; colormap=:viridis, nan_color=:transparent)
```
"""
function peak_centers(m::PLMap; pixel_range::Union{Tuple{Int,Int},Nothing}=nothing,
                      threshold::Real=0.05)
    pr = !isnothing(pixel_range) ? pixel_range : get(m.metadata, "pixel_range", nothing)

    if !isnothing(pr)
        p1 = max(1, pr[1])
        p2 = min(length(m.pixel), pr[2])
        pixels = m.pixel[p1:p2]
        spectra_slice = @view m.spectra[:, :, p1:p2]
    else
        pixels = m.pixel
        spectra_slice = m.spectra
    end

    nx, ny = length(m.x), length(m.y)

    # Mask against the PL intensity map (integrated signal already in m.intensity)
    max_intensity = maximum(m.intensity)
    cutoff = max_intensity > 0 ? max_intensity * threshold : zero(max_intensity)

    centers = Matrix{Float64}(undef, nx, ny)
    for iy in 1:ny
        for ix in 1:nx
            if m.intensity[ix, iy] <= cutoff
                centers[ix, iy] = NaN
            else
                sig = @view spectra_slice[ix, iy, :]
                total = sum(sig)
                centers[ix, iy] = sum(pixels[k] * sig[k] for k in eachindex(sig)) / total
            end
        end
    end
    return centers
end
