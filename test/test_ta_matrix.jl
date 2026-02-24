@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "TAMatrix loading and indexing" begin
    # Load TAMatrix
    data_dir = joinpath(PROJECT_ROOT, "data/CCD")
    matrix = load_ta_matrix(data_dir;
        time_file="time_axis.txt",
        wavelength_file="wavelength_axis.txt",
        data_file="ta_matrix.lvm",
        time_unit=:fs)

    @test matrix isa TAMatrix
    @test length(matrix.time) > 0
    @test length(matrix.wavelength) > 0
    @test size(matrix.data) == (length(matrix.time), length(matrix.wavelength))

    # Extract TATrace at wavelength
    trace = matrix[λ=600]
    @test trace isa TATrace
    @test length(trace.time) == length(matrix.time)
    @test length(trace.signal) == length(trace.time)
    @test haskey(trace.metadata, :actual_wavelength)
    @test abs(trace.wavelength - 600) < 10  # Within 10 nm of requested

    # Extract TASpectrum at time
    spec = matrix[t=1.0]
    @test spec isa TASpectrum
    @test length(spec.wavenumber) == length(matrix.wavelength)
    @test length(spec.signal) == length(spec.wavenumber)
    @test haskey(spec.metadata, :actual_time)

    # Error cases
    @test_throws ErrorException matrix[]  # No index specified
    @test_throws ErrorException matrix[λ=600, t=1.0]  # Both specified
end

@testset "TAMatrix fitting" begin
    data_dir = joinpath(PROJECT_ROOT, "data/CCD")
    matrix = load_ta_matrix(data_dir;
        time_file="time_axis.txt",
        wavelength_file="wavelength_axis.txt",
        data_file="ta_matrix.lvm",
        time_unit=:fs)

    # Extract and fit
    trace = matrix[λ=600]
    result = fit_exp_decay(trace; irf_width=0.15)

    @test result isa ExpDecayFit
    @test result.tau > 0

    # predict should work
    curve = predict(result, trace)
    @test length(curve) == length(trace.time)
    @test all(isfinite, curve)
end
