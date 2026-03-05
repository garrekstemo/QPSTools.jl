@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "Wave 1 — CurveFitModels re-exports" begin
    @test fano isa Function
    @test voigt isa Function
    @test log_normal isa Function
end

@testset "Wave 1 — SpectroscopyTools re-exports" begin
    @test add_spectra isa Function
    @test divide_spectra isa Function
    @test multiply_spectrum isa Function
    @test average_spectra isa Function
    @test interpolate_spectrum isa Function
    @test kramers_kronig isa Function
    @test kubelka_munk isa Function
    @test tauc_plot isa Function
    @test reflectance_to_absorbance isa Function
    @test snv isa Function
    @test beer_lambert isa Function
    @test urbach_tail isa Function
    @test thickness_from_fringes isa Function
    @test rubberband_baseline isa Function
end

@testset "Wave 1 — AnnotatedSpectrum dispatches" begin
    raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
    raman2 = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))

    @testset "Arithmetic (inherited from AbstractSpectroscopyData)" begin
        result = add_spectra(raman, raman2)
        @test haskey(result, :x)
        @test haskey(result, :y)
        @test length(result.y) == length(xdata(raman))

        result = divide_spectra(raman, raman2)
        @test haskey(result, :x)

        result = multiply_spectrum(raman, 2.0)
        @test result.y ≈ ydata(raman) .* 2.0
    end

    @testset "SNV" begin
        result = snv(raman)
        @test haskey(result, :x)
        @test haskey(result, :y)
        @test length(result.y) == length(xdata(raman))
        @test abs(sum(result.y) / length(result.y)) < 1e-10
    end

    @testset "Kubelka-Munk" begin
        # kubelka_munk needs positive reflectance values (0-1 range)
        # Use abs and clamp to ensure valid input
        y_abs = abs.(ydata(raman))
        y_max = maximum(y_abs)
        y_frac = clamp.(y_abs ./ y_max, 0.001, 1.0)

        # Test the scalar function directly
        @test kubelka_munk(0.5) ≈ (1 - 0.5)^2 / (2 * 0.5)
    end

    @testset "Kramers-Kronig" begin
        result = kramers_kronig(raman)
        @test length(result) == length(xdata(raman))
    end

    @testset "Rubberband baseline" begin
        result = rubberband_baseline(raman)
        @test length(result) == length(xdata(raman))
    end

    @testset "Average spectra" begin
        result = average_spectra(raman, raman2)
        @test haskey(result, :x)
        @test haskey(result, :y)
        @test result.y ≈ ydata(raman)
    end
end
