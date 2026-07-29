@isdefined(PROJECT_ROOT) || include("testsetup.jl")

# PLMap algorithm behaviour (extract_spectrum, subtract_background,
# normalize_intensity, peak_centers, etc.) is tested in OpticalSpectroscopy.
# This file exercises only the QPSTools-owned pieces: the `.lvm` loader
# (`load_pl_map`) and the Makie plotting wrappers.

@testset "load_pl_map — explicit grid dimensions" begin
    m = load_pl_map(PLMAP_FIXTURE; nx=11, ny=11, step_size=2.0)

    @test m isa PLMap
    @test PLMap <: AbstractSpectroscopyData

    @test length(m.x) == 11
    @test length(m.y) == 11
    @test size(m.spectra) == (200, 11, 11)
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

@testset "load_pl_map — auto-detect non-square grid (unidirectional)" begin
    field = make_plmap_field(; nx=15, ny=9)          # 135 pts, √135 not integer
    path = write_plmap_lvm(joinpath(mktempdir(), "ns.lvm"), field)

    m = load_pl_map(path)                             # no nx/ny given
    @test length(m.x) == 15
    @test length(m.y) == 9
    @test size(m.spectra) == (50, 15, 9)

    # Auto-detected map matches the explicit-dims load of the same file.
    m_explicit = load_pl_map(path; nx=15, ny=9)
    @test m.intensity ≈ m_explicit.intensity
end

@testset "load_pl_map — serpentine reconstruction (explicit snake)" begin
    field = make_plmap_field(; nx=15, ny=9)
    p_uni  = write_plmap_lvm(joinpath(mktempdir(), "uni.lvm"), field)
    p_serp = write_plmap_lvm(joinpath(mktempdir(), "serp.lvm"), field; serpentine=true)

    m_uni  = load_pl_map(p_uni;  nx=15, ny=9)                 # canonical map
    m_serp = load_pl_map(p_serp; nx=15, ny=9, snake=true)     # un-snaked

    @test m_serp.intensity ≈ m_uni.intensity
    @test m_serp.spectra ≈ m_uni.spectra
end

@testset "load_pl_map — auto-detect serpentine orientation" begin
    field = make_plmap_field(; nx=15, ny=9)
    p_uni  = write_plmap_lvm(joinpath(mktempdir(), "uni.lvm"), field)
    p_serp = write_plmap_lvm(joinpath(mktempdir(), "serp.lvm"), field; serpentine=true)

    m_uni  = load_pl_map(p_uni; nx=15, ny=9)
    m_auto = load_pl_map(p_serp)                             # no dims, no snake flag

    @test length(m_auto.x) == 15
    @test length(m_auto.y) == 9
    @test m_auto.intensity ≈ m_uni.intensity                 # detected serp + rebuilt correctly
end

@testset "load_pl_map — uninferable grid raises a helpful error" begin
    field = make_plmap_field(; nx=17, ny=1)                  # 17 pts: prime, non-square
    path = write_plmap_lvm(joinpath(mktempdir(), "prime.lvm"), field)
    @test_throws "nx and ny" load_pl_map(path)
end

@testset "_infer_raster_grid — refuses to guess unstructured data" begin
    # A perfectly flat signal has zero row-alignment contrast → no confident grid.
    @test QPSTools._infer_raster_grid(fill(5.0, 120)) === nothing
end

@testset "detect_pl_grid — probe grid without building a PLMap" begin
    field  = make_plmap_field(; nx=15, ny=9)
    p_uni  = write_plmap_lvm(joinpath(mktempdir(), "u.lvm"), field)
    p_serp = write_plmap_lvm(joinpath(mktempdir(), "s.lvm"), field; serpentine=true)

    g = detect_pl_grid(p_uni)
    @test (g.nx, g.ny, g.serpentine, g.n_points) == (15, 9, false, 135)

    gs = detect_pl_grid(p_serp)
    @test (gs.nx, gs.ny, gs.serpentine) == (15, 9, true)

    prime = write_plmap_lvm(joinpath(mktempdir(), "p.lvm"), make_plmap_field(; nx=17, ny=1))
    @test detect_pl_grid(prime) === nothing
end

@testset "detect_pl_grid — streaming row-sums match readdlm ground truth" begin
    # The fast detection path integrates each CCD row with a single streaming
    # byte-scan instead of materialising the whole matrix. For integer CCD
    # counts it must reproduce the readdlm-based per-row sums *exactly*, not
    # approximately — that equivalence is what lets it feed _infer_raster_grid.
    field = make_plmap_field(; nx=15, ny=9, npix=64)
    p = write_plmap_lvm(joinpath(mktempdir(), "stream.lvm"), field)

    truth = vec(sum(QPSTools._read_ccd_lvm(p); dims=2))
    fast  = QPSTools._stream_ccd_row_sums(p)
    @test fast == truth
    @test length(fast) == 15 * 9

    # Serpentine ordering changes which row is which, but each row's integrated
    # intensity is still parsed identically.
    ps = write_plmap_lvm(joinpath(mktempdir(), "stream_s.lvm"), field; serpentine=true)
    @test QPSTools._stream_ccd_row_sums(ps) == vec(sum(QPSTools._read_ccd_lvm(ps); dims=2))

    # Grid detection over the streamed sums is unchanged.
    @test detect_pl_grid(p) == (nx=15, ny=9, serpentine=false, n_points=135)
end

@testset "detect_pl_grid — fast path stays low-allocation" begin
    # Streaming reads the file once (~1× its size) plus a tiny per-row vector;
    # the old readdlm path built the full matrix and allocated ~20× the file.
    # Bound well below that so the streaming property is actually enforced.
    field = make_plmap_field(; nx=40, ny=40, npix=400)
    p = write_plmap_lvm(joinpath(mktempdir(), "alloc.lvm"), field)
    detect_pl_grid(p)                                  # compile before measuring
    @test @allocated(detect_pl_grid(p)) < 3 * filesize(p)
end

@testset "detect_pl_grid — real CCD map files (local only)" begin
    # Correctness on the actual LabVIEW CCD raster files. These live outside the
    # repo, so the testset auto-skips wherever they are absent (e.g. CI).
    realcases = [
        (datapath("test/PLmap/20260623/CCDtmp_260623_201749.lvm"),
         (nx=65, ny=55, serpentine=false, n_points=3575)),
        (datapath("test/PLmap/20260308/CCDtmp_260308_141314.lvm"),
         (nx=86, ny=96, serpentine=false, n_points=8256)),
    ]
    present = filter(c -> isfile(first(c)), realcases)
    if isempty(present)
        @test_skip "real CCD map files not present on this machine"
    else
        for (path, expected) in present
            @test detect_pl_grid(path) == expected
            detect_pl_grid(path)                        # compile
            @test (@elapsed detect_pl_grid(path)) < 0.75
        end
    end
end

@testset "PLMap plotting" begin
    using Makie: Figure, Axis, Theme, with_theme, to_color

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

    # Theme transparency: a caller's active theme must reach the Axis
    # (regression for the internal with_theme(qps_theme()) that wiped it),
    # while the lab-convention inside ticks still apply via Axis kwargs.
    with_theme(Theme(Axis=(titlecolor=:red,))) do
        _, axt, _ = plot_pl_map(m_norm)
        @test axt.titlecolor[] == to_color(:red)
        @test axt.xtickalign[] == 1.0
        _, axs = plot_pl_spectra(m, [(m.x[6], m.y[6])])
        @test axs.titlecolor[] == to_color(:red)
        @test axs.xtickalign[] == 1.0
    end
end
