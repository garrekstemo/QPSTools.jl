using Statistics: std

@testset "Chirp correction (re-exports + integration)" begin

    @testset "Re-exports available" begin
        @test isdefined(QPSTools, :ChirpCalibration)
        @test isdefined(QPSTools, :detect_chirp)
        @test isdefined(QPSTools, :correct_chirp)
        @test isdefined(QPSTools, :subtract_background)
        @test isdefined(QPSTools, :save_chirp)
        @test isdefined(QPSTools, :load_chirp)
        @test isdefined(QPSTools, :plot_chirp)
        @test isdefined(QPSTools, :plot_chirp!)
    end

    @testset "Smoke test: detect_chirp through QPSTools" begin
        # Synthetic matrix with known chirp
        n_time = 200
        n_wl = 100
        time = collect(range(-5.0, 15.0, length=n_time))
        wavelength = collect(range(500.0, 700.0, length=n_wl))

        ref_λ = 600.0
        chirp_fn(λ) = 0.0001 * (λ - ref_λ)^2 - 0.002 * (λ - ref_λ)

        data = zeros(n_time, n_wl)
        for j in eachindex(wavelength)
            λ = wavelength[j]
            t_onset = chirp_fn(λ)
            for i in eachindex(time)
                t = time[i]
                if t > t_onset
                    data[i, j] = 0.5 * exp(-(t - t_onset) / 3.0)
                end
            end
        end

        metadata = Dict{Symbol,Any}(:source => "synthetic")
        matrix = TAMatrix(time, wavelength, data, metadata)

        # subtract_background
        bg = subtract_background(matrix)
        @test bg isa TAMatrix

        # detect_chirp
        cal = detect_chirp(bg; order=2, reference=ref_λ, smooth_window=7, bin_width=4)
        @test cal isa ChirpCalibration
        @test cal.r_squared > 0.9

        # correct_chirp
        corrected = correct_chirp(bg, cal)
        @test corrected isa TAMatrix
        @test corrected.metadata[:chirp_corrected] == true

        # save/load round-trip
        tmpfile = tempname() * ".json"
        save_chirp(tmpfile, cal)
        cal2 = load_chirp(tmpfile)
        @test cal2.poly_coeffs ≈ cal.poly_coeffs
        rm(tmpfile)
    end

end
