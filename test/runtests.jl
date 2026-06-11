include("testsetup.jl")
using Aqua

@testset "QPSTools.jl" begin

    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(QPSTools;
            deps_compat=(ignore=[
                :Dates, :DelimitedFiles, :LinearAlgebra, :Statistics,
                :CavitySpectroscopy, :ElabFTW, :HamamatsuStreakFiles,
                :JASCOFiles, :QPSScanFormat, :OpticalSpectroscopy,
            ],),
            # Deliberate glue: cavity.jl routes OpticalSpectroscopy's
            # format_results generic to CavitySpectroscopy's result types so
            # one reporting vocabulary covers the whole stack. QPSTools is
            # the integration layer; these types are treated as its own.
            piracies=(treat_as_own=[
                CavitySpectroscopy.CavityFitResult,
                CavitySpectroscopy.DispersionFitResult,
            ],),
        )
    end
    include("test_types.jl")
    include("test_io.jl")
    include("test_ta.jl")
    include("test_ta_matrix.jl")
    include("test_cavity.jl")
    include("test_chirp.jl")
    include("test_elabftw.jl")
    include("test_wavelength.jl")
    include("test_plmap.jl")
    include("test_streak.jl")
    include("test_plotting.jl")
    include("test_format_results.jl")
    include("test_qpsscanformat_coexistence.jl")
    include("test_scan_loading.jl")
end
