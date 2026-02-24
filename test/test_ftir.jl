@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "Extended interface - FTIR source_file and npoints" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    @test source_file(spec) isa String
    @test !isempty(source_file(spec))
    @test npoints(spec) == length(spec.data.x)
    @test title(spec) == source_file(spec)
end

@testset "FTIR loading" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    @test spec isa FTIRSpectrum
    @test length(spec.data.x) > 0
end

@testset "FTIR loading with kwargs" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv");
                     solute="NH4SCN", concentration="1.0M")
    @test spec isa FTIRSpectrum
    @test spec.sample["solute"] == "NH4SCN"
    @test spec.sample["concentration"] == "1.0M"
end

@testset "FTIR bad path" begin
    @test_throws ErrorException load_ftir("/nonexistent/file.csv")
end

@testset "FTIR interface" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    @test xdata(spec) === spec.data.x
    @test ydata(spec) === spec.data.y
    @test xlabel(spec) == "Wavenumber (cm⁻¹)"
    @test ylabel(spec) == get(QPSTools._FTIR_YLABEL, spec.data.yunits, "Signal")
    @test is_matrix(spec) == false
    @test zdata(spec) === nothing
end

@testset "Semantic accessors - FTIR" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    @test wavenumber(spec) === xdata(spec)
    @test signal(spec) === ydata(spec)
    @test ykind(spec) isa Symbol
    # NH4SCN data is absorbance
    @test ykind(spec) === :absorbance
    @test absorbance(spec) === ydata(spec)
end

@testset "FTIR peak fitting (fit_peaks)" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    result = fit_peaks(spec, (2000, 2100))

    @test result isa MultiPeakFitResult
    @test length(result) >= 1

    # Per-peak access
    pk = result[1]
    @test pk isa PeakFitResult
    @test haskey(pk, :amplitude)
    @test haskey(pk, :center)
    @test haskey(pk, :fwhm)

    # Check parameter access
    @test pk[:center].value > 2000
    @test pk[:center].value < 2100
    @test result.r_squared > 0.9

    # Predict functions
    y_fit = predict(result)
    @test length(y_fit) == result.npoints

    y_peak = predict_peak(result, 1)
    @test length(y_peak) == result.npoints

    y_bl = predict_baseline(result)
    @test length(y_bl) == result.npoints

    res = residuals(result)
    @test length(res) == result.npoints
end

@testset "Spectrum subtraction" begin
    spec = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/1.0M_NH4SCN_DMF.csv"))
    ref = load_ftir(joinpath(PROJECT_ROOT, "data/ftir/DMF.csv"))

    corrected = subtract_spectrum(spec, ref)
    @test corrected isa FTIRSpectrum
    @test length(corrected.data.x) == length(spec.data.x)
end
