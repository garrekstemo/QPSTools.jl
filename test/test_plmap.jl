@isdefined(PROJECT_ROOT) || include("testsetup.jl")

# PLMap algorithm behaviour (extract_spectrum, subtract_background,
# normalize_intensity, peak_centers, etc.) is tested in SpectroscopyTools.
# This file exercises only the QPSTools-owned pieces: the `.lvm` loader
# (`load_pl_map`) and the Makie plotting wrappers.

@testset "load_pl_map — explicit grid dimensions" begin
    m = load_pl_map(PLMAP_FIXTURE; nx=11, ny=11, step_size=2.0)

    @test m isa PLMap
    @test PLMap <: AbstractSpectroscopyData

    @test length(m.x) == 11
    @test length(m.y) == 11
    @test size(m.spectra) == (11, 11, 200)
    @test size(m.intensity) == (11, 11)

    # Centered spatial axes
    @test m.x[1] < 0
    @test m.x[end] > 0
    @test abs(m.x[1] + m.x[end]) < 0.01
    @test m.x[end] - m.x[1] ≈ 10 * 2.0  # (nx-1) * step_size

    # Loader populates metadata + source_file
    @test source_file(m) == basename(PLMAP_FIXTURE)

    # Show methods wire up
    buf = IOBuffer()
    show(buf, m)
    @test occursin("11×11", String(take!(buf)))

    buf2 = IOBuffer()
    show(buf2, MIME("text/plain"), m)
    @test occursin("Grid", String(take!(buf2)))
end

@testset "load_pl_map — auto grid inference" begin
    # Square grid: √121 = 11
    m = load_pl_map(PLMAP_FIXTURE; step_size=2.0)
    @test length(m.x) == 11
    @test length(m.y) == 11
end

@testset "load_pl_map — pixel_range shrinks integration window" begin
    m_full = load_pl_map(PLMAP_FIXTURE; nx=11, ny=11)
    m_range = load_pl_map(PLMAP_FIXTURE; nx=11, ny=11, pixel_range=(80, 120))

    # Partial integration gives smaller totals; shapes unchanged
    @test sum(m_range.intensity) < sum(m_full.intensity)
    @test size(m_range.intensity) == size(m_full.intensity)
end

@testset "load_pl_map — non-centered axes" begin
    m = load_pl_map(PLMAP_FIXTURE; nx=11, ny=11, step_size=1.0, center=false)
    @test m.x[1] ≈ 0.0
    @test m.y[1] ≈ 0.0
    @test m.x[end] ≈ 10.0
end

@testset "PLMap plotting" begin
    using Makie: Figure, Axis

    m = load_pl_map(PLMAP_FIXTURE; nx=11, ny=11)
    m_norm = normalize_intensity(m)

    # plot_pl_map returns (Figure, Axis, Heatmap)
    fig, ax, hm = plot_pl_map(m_norm)
    @test fig isa Figure
    @test ax isa Axis

    # plot_pl_spectra returns (Figure, Axis) for a small list of positions
    fig2, ax2 = plot_pl_spectra(m, [(m.x[6], m.y[6]), (m.x[1], m.y[1])])
    @test fig2 isa Figure
    @test ax2 isa Axis
end
