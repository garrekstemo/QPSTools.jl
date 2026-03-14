@isdefined(PROJECT_ROOT) || include("testsetup.jl")

@testset "Wavelength sidecar file loading" begin

    # Helper: write a synthetic wavelength sidecar file with LabVIEW line endings
    function write_synthetic_wl(path, wavelengths)
        open(path, "w") do io
            # Header with \r only (LabVIEW quirk)
            write(io, "CCD_test_x\tCCD_test_y\r")
            for (i, wl) in enumerate(wavelengths)
                write(io, "$(wl)\t$(1000.0 + i)\r\n")
            end
        end
    end

    # Helper: write a synthetic PLMap LVM file (row-count header + tab-separated spectra)
    function write_synthetic_lvm(path, nx, ny, n_pixel)
        n_points = nx * ny
        open(path, "w") do io
            println(io, n_points)
            for _ in 1:n_points
                println(io, join(rand(1:5000, n_pixel), "\t"))
            end
        end
    end

    @testset "load_wavelength_file parses correctly" begin
        wl_expected = [500.0, 500.5, 501.0, 501.5, 502.0]

        mktempdir() do dir
            wl_path = joinpath(dir, "spec.txt")
            write_synthetic_wl(wl_path, wl_expected)

            wl = load_wavelength_file(wl_path)

            @test wl isa Vector{Float64}
            @test length(wl) == 5
            @test wl ≈ wl_expected
            @test issorted(wl)
        end
    end

    @testset "load_wavelength_file errors on missing file" begin
        @test_throws Exception load_wavelength_file("/nonexistent/file.txt")
    end

    @testset "load_pl_map with wavelength kwarg" begin
        wl_expected = [500.0, 500.5, 501.0, 501.5, 502.0]

        mktempdir() do dir
            lvm_path = joinpath(dir, "map.lvm")
            wl_path = joinpath(dir, "spec.txt")
            write_synthetic_lvm(lvm_path, 2, 2, 5)
            write_synthetic_wl(wl_path, wl_expected)

            wl = load_wavelength_file(wl_path)
            m = load_pl_map(lvm_path; nx=2, ny=2, wavelength=wl)

            @test m isa PLMap
            @test m.pixel == wl_expected
            @test m.pixel[1] ≈ 500.0
            @test length(m.pixel) == size(m.spectra, 3)
            @test size(m.spectra) == (2, 2, 5)
        end
    end

    @testset "load_pl_map with wavelength length mismatch" begin
        mktempdir() do dir
            lvm_path = joinpath(dir, "map.lvm")
            write_synthetic_lvm(lvm_path, 2, 2, 5)
            bad_wl = [1.0, 2.0, 3.0]  # 3 wavelengths for 5 pixels

            @test_throws ErrorException load_pl_map(lvm_path; nx=2, ny=2, wavelength=bad_wl)
        end
    end
end
