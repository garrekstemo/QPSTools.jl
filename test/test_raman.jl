@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "Extended interface - Raman source_file and npoints" begin
    raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
    @test source_file(raman) isa String
    @test !isempty(source_file(raman))
    @test npoints(raman) == length(raman.data.x)
    @test title(raman) == source_file(raman)
end

@testset "Raman loading" begin
    raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
    @test raman isa RamanSpectrum
    @test length(raman.data.x) > 0
end

@testset "Raman loading with kwargs" begin
    raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv");
                       material="ZIF-62", phase="crystal")
    @test raman isa RamanSpectrum
    @test raman.sample["material"] == "ZIF-62"
    @test raman.sample["phase"] == "crystal"
end

@testset "Raman bad path" begin
    @test_throws ErrorException load_raman("/nonexistent/file.csv")
end

@testset "Raman interface" begin
    raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
    @test xdata(raman) === raman.data.x
    @test ydata(raman) === raman.data.y
    @test xlabel(raman) == "Raman Shift (cm⁻¹)"
    @test ylabel(raman) == "Intensity"
    @test is_matrix(raman) == false
    @test zdata(raman) === nothing
end

@testset "Semantic accessors - Raman" begin
    raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
    @test shift(raman) === xdata(raman)
    @test intensity(raman) === ydata(raman)
end

@testset "Raman peak fitting (fit_peaks)" begin
    raman = load_raman(joinpath(PROJECT_ROOT, "data/raman/ZIF62_crystal_1.csv"))
    result = fit_peaks(raman, (1250, 1300))

    @test result isa MultiPeakFitResult
    @test length(result) >= 1
    pk = result[1]
    @test haskey(pk, :amplitude)
    @test haskey(pk, :center)
end
