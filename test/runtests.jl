include("testsetup.jl")
using Aqua

@testset "QPSTools.jl" begin

    @testset "Code quality (Aqua.jl)" begin
        # QPSTools is the top-level lab-integration layer (nothing depends on
        # it), so it intentionally extends sibling functions with methods on
        # OpticalSpectroscopy's `Spectrum`: the cavity-fit dispatch and the
        # eLabFTW provenance glue. Aqua flags these as piracy — allowlist them.
        Aqua.test_all(QPSTools;
            deps_compat=(ignore=[
                :Dates, :DelimitedFiles, :LinearAlgebra, :Statistics,
                :ElabFTW, :HamamatsuStreakFiles,
                :JASCOFiles, :QPSScanFormat, :OpticalSpectroscopy,
            ],),
            piracies=(treat_as_own=[
                QPSTools.fit_cavity_spectrum,
                QPSTools.tags_from_sample,
                QPSTools.log_to_elab,
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
