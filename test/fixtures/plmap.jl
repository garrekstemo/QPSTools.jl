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
