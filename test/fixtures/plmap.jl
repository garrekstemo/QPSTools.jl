using Random: MersenneTwister

"""
    make_plmap_fixture(path::String; nx=11, ny=11, npix=200, seed=42)

Write a small deterministic synthetic PL-map `.lvm` file at `path` suitable
for exercising the `load_pl_map` parser. The file format matches the
LabVIEW raster-scan output: a row-count header line followed by
tab-separated integer rows (one row per spatial point, one column per
CCD pixel).

The synthetic map has a Gaussian spatial blob centered on the grid and a
Gaussian spectral peak near `npix ÷ 2`, with background noise everywhere.
Dimensions are kept small so the fixture stays under ~150 KB and tests
run in well under a second. The default seed makes the file byte-stable
across runs.
"""
function make_plmap_fixture(path::String; nx::Int=11, ny::Int=11,
                             npix::Int=200, seed::Int=42)
    mkpath(dirname(path))
    rng = MersenneTwister(seed)
    n_points = nx * ny
    center_x, center_y = (nx + 1) / 2, (ny + 1) / 2
    peak_pixel = npix ÷ 2

    spectra = Matrix{Int}(undef, n_points, npix)
    for iy in 1:ny, ix in 1:nx
        row = (iy - 1) * nx + ix
        spatial = exp(-((ix - center_x)^2 + (iy - center_y)^2) / (2 * 3^2))
        for p in 1:npix
            bg = 1000 + round(Int, 20 * randn(rng))
            peak = 5000 * spatial * exp(-(p - peak_pixel)^2 / (2 * 15^2))
            spectra[row, p] = bg + round(Int, peak + 30 * randn(rng))
        end
    end

    open(path, "w") do io
        println(io, n_points)
        for row in 1:n_points
            println(io, join(view(spectra, row, :), '\t'))
        end
    end
    return path
end

"""
    make_plmap_field(; nx, ny, npix=50, seed=7) -> Array{Int,3}

Build a deterministic `(nx, ny, npix)` synthetic PL-map cube: a smooth Gaussian
spatial blob times a Gaussian spectral peak, plus mild noise. Value generation is
keyed on `(ix, iy)` so the same field can be written to disk in different raster
orders (see [`write_plmap_lvm`](@ref)) and still describe the same physical map.
"""
function make_plmap_field(; nx::Int, ny::Int, npix::Int=50, seed::Int=7)
    rng = MersenneTwister(seed)
    cx, cy = (nx + 1) / 2, (ny + 1) / 2
    pk = npix ÷ 2
    field = Array{Int}(undef, nx, ny, npix)
    for iy in 1:ny, ix in 1:nx
        spatial = exp(-((ix - cx)^2 + (iy - cy)^2) / (2 * 3^2))
        ramp = 60 * ix   # break fast-axis symmetry so scan direction is detectable
        for p in 1:npix
            peak = 5000 * spatial * exp(-(p - pk)^2 / (2 * 15^2))
            field[ix, iy, p] = 1000 + ramp + round(Int, peak + 20 * randn(rng))
        end
    end
    return field
end

"""
    write_plmap_lvm(path, field; serpentine=false) -> path

Write a `(nx, ny, npix)` cube to a LabVIEW `.lvm` (row-count header + one
tab-separated spectrum per spatial point). Points are streamed in raster order
(`ix` fast, `iy` slow); with `serpentine=true` even `iy` rows are written in
reverse `ix` order (boustrophedon), matching a bidirectional stage scan.
"""
function write_plmap_lvm(path::String, field::Array{Int,3}; serpentine::Bool=false)
    nx, ny, _ = size(field)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, nx * ny)
        for iy in 1:ny
            xs = (serpentine && iseven(iy)) ? (nx:-1:1) : (1:nx)
            for ix in xs
                println(io, join(view(field, ix, iy, :), '\t'))
            end
        end
    end
    return path
end
