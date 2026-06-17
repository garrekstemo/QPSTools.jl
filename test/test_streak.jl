@isdefined(PROJECT_ROOT) || include("testsetup.jl")

using Dates: DateTime
using Makie: Figure, Axis

# StreakImage parsing (binary layout, scaling tables, metadata sentinels) is
# tested in HamamatsuStreakFiles. This file exercises only the QPSTools-owned
# pieces: the annotated wrapper (`StreakPL` / `load_streak_pl`), the eLabFTW
# glue, and the Makie plotting wrapper.

@testset "load_streak_pl — annotated wrapper" begin
    pl = load_streak_pl(STREAK_FIXTURE; temperature="15K", material="NH4SCN")

    @test pl isa StreakPL
    @test pl.data isa StreakImage
    @test pl.path == abspath(STREAK_FIXTURE)

    # Sample kwargs land in the sample dict (string keys)
    @test pl.sample["temperature"] == "15K"
    @test pl.sample["material"] == "NH4SCN"
    @test QPSTools.sample_metadata(pl) === pl.sample
    @test QPSTools.spectrum_data(pl) === pl.data

    # On-disk descending wavelength order preserved
    @test pl.data.wavelength == [700, 690, 680, 670]
    @test pl.data.time == [0, 2, 4]
    @test size(pl) == (4, 3)
    @test pl.data.xunits == "nm"
    @test pl.data.yunits == "ns"

    # Missing file errors
    @test_throws ErrorException load_streak_pl("nonexistent.img")
end

@testset "StreakPL show methods" begin
    pl = load_streak_pl(STREAK_FIXTURE; temperature="15K")

    buf = IOBuffer()
    show(buf, pl)
    s = String(take!(buf))
    @test occursin("StreakPL", s)
    @test occursin("4×3", s)

    buf2 = IOBuffer()
    show(buf2, MIME("text/plain"), pl)
    s2 = String(take!(buf2))
    @test occursin(basename(STREAK_FIXTURE), s2)
    @test occursin("temperature = 15K", s2)
end

@testset "StreakPL eLabFTW glue" begin
    pl = load_streak_pl(STREAK_FIXTURE; material="NH4SCN", temperature="15K")

    tags = tags_from_sample(pl)
    @test "NH4SCN" in tags
    @test "15K" in tags

    auto = QPSTools._streak_auto_tags(pl)
    @test auto[1] == "pl"
    @test "NH4SCN" in auto

    body = QPSTools._streak_provenance_body(pl)
    @test occursin(basename(STREAK_FIXTURE), body)
    @test occursin("C11440-36U", body)       # camera
    @test occursin("C10910", body)           # streak unit
    @test occursin("50 ns", body)            # time range
    @test occursin("554.969", body)          # center wavelength
    @test occursin("2026-06-02", body)       # acquisition date

    # No kwargs → technique tag only
    bare = load_streak_pl(STREAK_FIXTURE)
    @test QPSTools._streak_auto_tags(bare) == ["pl"]
end

@testset "plot_streak_pl" begin
    pl = load_streak_pl(STREAK_FIXTURE)

    fig, ax, hm = plot_streak_pl(pl)
    @test fig isa Figure
    @test ax isa Axis
    @test ax.xlabel[] == "Wavelength (nm)"
    @test ax.ylabel[] == "Time (ns)"

    # Raw StreakImage works too, and kwargs pass through
    fig2, ax2, hm2 = plot_streak_pl(pl.data; colormap=:viridis, colorrange=(0, 12),
                                    title="Streak PL")
    @test fig2 isa Figure
    @test ax2.title[] == "Streak PL"
end

@testset "TimeResolvedMatrix(::StreakPL) converter" begin
    pl = load_streak_pl(STREAK_FIXTURE; temperature="15K")
    m = TimeResolvedMatrix(pl)

    @test m isa TimeResolvedMatrix
    @test size(m.data) == (3, 4)                       # time × wavelength
    @test m.time == [0.0, 2.0, 4.0]
    @test m.wavelength == [670.0, 680.0, 690.0, 700.0] # ascending
    @test issorted(m.wavelength)

    # data mapping: img.counts[w, t] → m.data[t, ascending-sorted w]
    img = pl.data
    for (wi, w) in enumerate(img.wavelength), (ti, t) in enumerate(img.time)
        col = findfirst(==(w), m.wavelength)
        @test m.data[ti, col] == img.counts[wi, ti]
    end

    # metadata mapping
    @test m.metadata[:yquantity] == :intensity
    @test m.metadata[:xquantity] == :wavelength
    @test m.metadata[:time_unit] == (isempty(img.yunits) ? :ns : normalize_unit(img.yunits))
    @test m.metadata[:source] == pl.path
    @test m.metadata[:sample]["temperature"] == "15K"
    @test haskey(m.metadata, :camera)
    @test haskey(m.metadata, :center_wavelength)

    # labels flow through OpticalSpectroscopy display
    @test occursin("Intensity", zlabel(m))
    @test occursin("Time", ylabel(m))

    # converted matrix feeds the analysis chain
    g = integrate_time(m)
    @test g isa Spectrum
    @test issorted(xdata(g))
end

# Real instrument file (data/ is not in version control — guard with isfile)
real_img = joinpath(PROJECT_ROOT, "data", "PL", "15K.img")
if isfile(real_img)
    @testset "load_streak_pl — real 15K.img" begin
        pl = load_streak_pl(real_img; temperature="15K")
        @test size(pl) == (1408, 1072)
        @test pl.data.wavelength[1] ≈ 662.4 atol=0.1   # descending on disk
        @test pl.data.wavelength[end] ≈ 395.2 atol=0.1
        @test pl.data.time[1] ≈ 0.0 atol=0.01
        @test pl.data.time[end] ≈ 47.24 atol=0.01
        @test pl.data.xunits == "nm"
        @test pl.data.yunits == "ns"

        fig, ax, hm = plot_streak_pl(pl)
        @test fig isa Figure

        m = TimeResolvedMatrix(pl)
        @test size(m.data) == (1072, 1408)
        @test issorted(m.wavelength)
        @test m.wavelength[1] ≈ 395.2 atol=0.1
        @test m.wavelength[end] ≈ 662.4 atol=0.1
        @test m.time[end] ≈ 47.24 atol=0.01
    end
else
    @info "Skipping real streak-file tests (data/PL/15K.img not present)"
end
