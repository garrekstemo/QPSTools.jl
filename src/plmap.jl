# PL map loader for LabVIEW CCD raster scan files

using DelimitedFiles: readdlm

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
        int_matrix = dropdims(sum(spectra[:, :, p1:p2]; dims=3); dims=3)
    else
        int_matrix = dropdims(sum(spectra; dims=3); dims=3)
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

    return PLMap(int_matrix, spectra, x, y, pixel, metadata)
end
