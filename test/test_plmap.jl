@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "PLMap loading and interface" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)

    @test m isa PLMap
    @test PLMap <: AbstractSpectroscopyData

    # Grid dimensions
    @test length(m.x) == 51
    @test length(m.y) == 51
    @test size(m.spectra) == (51, 51, 2000)
    @test size(m.intensity) == (51, 51)

    # Spatial axes centered
    @test m.x[1] < 0
    @test m.x[end] > 0
    @test abs(m.x[1] + m.x[end]) < 0.01  # Symmetric

    # Interface
    @test xdata(m) === m.x
    @test ydata(m) === m.y
    @test zdata(m) === m.intensity
    @test xlabel(m) == "X (μm)"
    @test ylabel(m) == "Y (μm)"
    @test is_matrix(m) == true
    @test npoints(m) == (51, 51)
    @test source_file(m) == "CCDtmp_260129_111138.lvm"

    # Show methods
    buf = IOBuffer()
    show(buf, m)
    @test occursin("51×51", String(take!(buf)))

    buf = IOBuffer()
    show(buf, MIME("text/plain"), m)
    @test occursin("Grid", String(take!(buf)))
end

@testset "Semantic accessors - PLMap" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)
    @test intensity(m) === m.intensity
end

@testset "PLMap auto grid inference" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; step_size=2.16)
    @test length(m.x) == 51
    @test length(m.y) == 51
end

@testset "PLMap extract_spectrum" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51)

    # Extract by index
    spec = extract_spectrum(m, 26, 26)
    @test length(spec.pixel) == 2000
    @test length(spec.signal) == 2000
    @test spec.x ≈ m.x[26]
    @test spec.y ≈ m.y[26]

    # Extract by position (nearest neighbor)
    spec_pos = extract_spectrum(m; x=0.0, y=0.0)
    @test length(spec_pos.signal) == 2000
    @test haskey(spec_pos, :ix)
    @test haskey(spec_pos, :iy)

    # Out of bounds
    @test_throws ErrorException extract_spectrum(m, 0, 1)
    @test_throws ErrorException extract_spectrum(m, 1, 52)
end

@testset "PLMap normalize_intensity" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51)

    m_norm = normalize_intensity(m)
    @test m_norm isa PLMap
    @test minimum(m_norm.intensity) ≈ 0.0
    @test maximum(m_norm.intensity) ≈ 1.0

    # Spectra should be unchanged
    @test m_norm.spectra === m.spectra
end

@testset "PLMap subtract_background (explicit positions)" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)

    # Pick corners as background positions (off-flake)
    bg_positions = [
        (m.x[1], m.y[1]),
        (m.x[end], m.y[1]),
        (m.x[1], m.y[end]),
    ]
    m_bg = subtract_background(m; positions=bg_positions)

    @test m_bg isa PLMap
    @test size(m_bg.spectra) == size(m.spectra)
    @test size(m_bg.intensity) == size(m.intensity)

    # Spatial axes and pixel axis unchanged
    @test m_bg.x === m.x
    @test m_bg.y === m.y
    @test m_bg.pixel === m.pixel

    # Background-subtracted spectra should differ from originals
    @test m_bg.spectra != m.spectra

    # Mean signal at a background position should be closer to zero after subtraction
    bg_before = extract_spectrum(m; x=bg_positions[1][1], y=bg_positions[1][2])
    bg_after = extract_spectrum(m_bg; x=bg_positions[1][1], y=bg_positions[1][2])
    @test abs(sum(bg_after.signal)) < abs(sum(bg_before.signal))
end

@testset "PLMap subtract_background (auto mode)" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)

    # Auto mode uses bottom corners with default margin=5
    m_auto = subtract_background(m)

    @test m_auto isa PLMap
    @test size(m_auto.spectra) == size(m.spectra)
    @test size(m_auto.intensity) == size(m.intensity)

    # Spectra should be modified
    @test m_auto.spectra != m.spectra

    # Auto with custom margin
    m_auto2 = subtract_background(m; margin=3)
    @test m_auto2 isa PLMap
    @test m_auto2.spectra != m.spectra
    # Different margins should give slightly different results
    @test m_auto2.spectra != m_auto.spectra
end

@testset "PLMap subtract_background preserves pixel_range" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51, pixel_range=(500, 700))

    m_bg = subtract_background(m)
    @test m_bg isa PLMap

    # Intensity should be recomputed from the same pixel_range
    expected_intensity = dropdims(sum(m_bg.spectra[:, :, 500:700]; dims=3); dims=3)
    @test m_bg.intensity ≈ expected_intensity
end

@testset "PLMap normalize_intensity after subtract_background" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16)

    m_bg = subtract_background(m)
    m_norm = normalize_intensity(m_bg)

    @test m_norm isa PLMap
    @test minimum(m_norm.intensity) ≈ 0.0
    @test maximum(m_norm.intensity) ≈ 1.0

    # All values should be in [0, 1]
    @test all(m_norm.intensity .>= 0.0)
    @test all(m_norm.intensity .<= 1.0)

    # Spectra should be the background-subtracted ones (not re-normalized)
    @test m_norm.spectra === m_bg.spectra
end

@testset "PLMap pixel_range integration" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m_full = load_pl_map(plmap_file; nx=51, ny=51)
    m_range = load_pl_map(plmap_file; nx=51, ny=51, pixel_range=(500, 700))

    # Partial integration should give different (smaller) intensity values
    @test sum(m_range.intensity) < sum(m_full.intensity)
    @test size(m_range.intensity) == size(m_full.intensity)
end

@testset "PLMap plotting" begin
    using Makie: Figure, Axis

    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51)
    m_norm = normalize_intensity(m)

    # plot_pl_map returns (Figure, Axis, Heatmap)
    fig, ax, hm = plot_pl_map(m_norm)
    @test fig isa Figure
    @test ax isa Axis

    # plot_pl_spectra returns (Figure, Axis)
    fig2, ax2 = plot_pl_spectra(m, [(0.0, 0.0), (10.0, 10.0)])
    @test fig2 isa Figure
    @test ax2 isa Axis
end

@testset "PLMap peak_centers" begin
    plmap_file = joinpath(PROJECT_ROOT, "data/PLmap/CCDtmp_260129_111138.lvm")
    m = load_pl_map(plmap_file; nx=51, ny=51, step_size=2.16, pixel_range=(950, 1100))

    centers = peak_centers(m)
    @test size(centers) == (51, 51)
    @test eltype(centers) == Float64

    # All valid centroids within pixel_range
    valid = filter(!isnan, centers)
    @test !isempty(valid)
    @test all(c -> 950 <= c <= 1100, valid)

    # After background subtraction -- masking uses m.intensity,
    # so off-flake regions (low PL) become NaN
    m_bg = subtract_background(m)
    centers_bg = peak_centers(m_bg)
    @test size(centers_bg) == (51, 51)
    @test count(isnan, centers_bg) > count(isnan, centers)

    # Without pixel_range: uses all pixels
    m_full = load_pl_map(plmap_file; nx=51, ny=51)
    centers_full = peak_centers(m_full)
    @test size(centers_full) == (51, 51)

    # Explicit pixel_range kwarg overrides metadata
    centers_custom = peak_centers(m; pixel_range=(960, 1050))
    valid_custom = filter(!isnan, centers_custom)
    @test all(c -> 960 <= c <= 1050, valid_custom)

    # threshold=0 disables masking (intensity cutoff = 0)
    centers_no_mask = peak_centers(m_bg; threshold=0)
    @test count(isnan, centers_no_mask) <= count(isnan, centers_bg)
end
