@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "Publication themes carry figure defaults" begin
    using Makie: to_value

    # size/backgroundcolor must be TOP-LEVEL keys — a Figure=(...) sub-block
    # is not read by Makie's Figure constructor and silently does nothing.
    pt = print_theme()
    @test to_value(pt.size) == (7 * 72, 4 * 72)
    @test !haskey(pt, :Figure)

    po = poster_theme()
    @test to_value(po.size) == (1200, 900)
    @test to_value(po.backgroundcolor) == :white
    @test !haskey(po, :Figure)
end

@testset "DAS and plot_das" begin
    using Makie: Figure, Axis, Theme, with_theme, to_color

    data_dir = joinpath(PROJECT_ROOT, "data/CCD")
    matrix = load_ta_matrix(data_dir;
        time_file="time_axis.txt",
        wavelength_file="wavelength_axis.txt",
        data_file="ta_matrix.lvm",
        time_unit=:fs)

    # Global fit on subset of wavelengths (fast)
    result = fit_global(matrix; n_exp=2, λ=[550, 600, 650])

    # das accessor re-exported from OpticalSpectroscopy
    d = das(result)
    @test size(d, 1) == 2
    @test size(d, 2) == 3

    # plot_das returns (Figure, Axis)
    fig, ax = plot_das(result)
    @test fig isa Figure
    @test ax isa Axis

    # plot_das! works on existing axis
    fig2 = Figure()
    ax2 = Axis(fig2[1, 1])
    plot_das!(ax2, result)

    # Error without wavelengths (traces-only fit has no wavelength axis)
    no_wl = fit_global([matrix[λ=600], matrix[λ=550]]; n_exp=1)
    @test_throws ErrorException plot_das(no_wl)

    # Theme transparency: a caller's active theme must reach the Axis
    # (regression for the internal with_theme(qps_theme()) that wiped it),
    # while the lab-convention inside ticks still apply via Axis kwargs.
    with_theme(Theme(Axis=(titlecolor=:red,))) do
        _, axt = plot_das(result)
        @test axt.titlecolor[] == to_color(:red)
        @test axt.xtickalign[] == 1.0
    end
end

@testset "plot_ta_heatmap" begin
    using Makie: Figure, Axis

    data_dir = joinpath(PROJECT_ROOT, "data/CCD")
    matrix = load_ta_matrix(data_dir;
        time_file="time_axis.txt",
        wavelength_file="wavelength_axis.txt",
        data_file="ta_matrix.lvm",
        time_unit=:fs)

    # Default call returns (Figure, Axis, Heatmap)
    fig, ax, hm = plot_ta_heatmap(matrix)
    @test fig isa Figure
    @test ax isa Axis

    # With optional kwargs
    fig2, ax2, hm2 = plot_ta_heatmap(matrix;
        colormap=:viridis, colorrange=(-0.01, 0.01), title="Test Heatmap")
    @test fig2 isa Figure
    @test ax2 isa Axis
end

@testset "Theme transparency across plot functions" begin
    using Makie: Figure, Axis, Theme, with_theme, to_color

    data_dir = joinpath(PROJECT_ROOT, "data/CCD")
    matrix = load_ta_matrix(data_dir;
        time_file="time_axis.txt",
        wavelength_file="wavelength_axis.txt",
        data_file="ta_matrix.lvm",
        time_unit=:fs)
    trace = matrix[λ=600]
    spec = matrix[t=matrix.time[end]]

    # A caller's active theme must reach every Axis these functions build
    # (regression for the internal with_theme(qps_theme()) that wiped it),
    # while the lab-convention inside ticks still apply via Axis kwargs.
    red = to_color(:red)
    themed(ax) = ax.titlecolor[] == red && ax.xtickalign[] == 1.0 && ax.ytickalign[] == 1.0

    with_theme(Theme(Axis=(titlecolor=:red,))) do
        _, ax = plot_kinetics(trace.time, trace.signal)
        @test themed(ax)

        _, ax = plot_kinetics(trace)
        @test themed(ax)

        _, ax = plot_kinetics(matrix; λ=[550, 600])
        @test themed(ax)

        _, ax, _ = plot_ta_heatmap(matrix)
        @test themed(ax)

        _, ax = plot_spectra(matrix; t=[matrix.time[2], matrix.time[end]])
        @test themed(ax)

        _, ax = plot_spectrum(xdata(spec), ydata(spec))
        @test themed(ax)

        x = collect(1.0:50.0)
        specs = [(x, sin.(x ./ 5)), (x, cos.(x ./ 5))]
        _, ax = plot_comparison(specs; labels=["a", "b"])
        @test themed(ax)

        _, ax = plot_waterfall(specs; offset=0.5)
        @test themed(ax)

        _, ax, _ = plot_data(matrix)   # 2D heatmap branch
        @test themed(ax)

        _, ax = plot_data(spec)        # 1D line branch
        @test themed(ax)
    end
end
