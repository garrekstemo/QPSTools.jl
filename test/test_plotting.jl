@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "DAS and plot_das" begin
    using Makie: Figure, Axis

    data_dir = joinpath(PROJECT_ROOT, "data/CCD")
    matrix = load_ta_matrix(data_dir;
        time_file="time_axis.txt",
        wavelength_file="wavelength_axis.txt",
        data_file="ta_matrix.lvm",
        time_unit=:fs)

    # Global fit on subset of wavelengths (fast)
    result = fit_global(matrix; n_exp=2, λ=[550, 600, 650])

    # das accessor re-exported from SpectroscopyTools
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
