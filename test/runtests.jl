include("testsetup.jl")
using Aqua

@testset "QPSTools.jl" begin

    @testset "Code quality (Aqua.jl)" begin
        # QPSTools proper extends no sibling functions, so it pirates nothing and
        # needs no piracy allowlist. The eLabFTW glue (ElabFTW generics dispatched
        # on OpticalSpectroscopy's `Spectrum`/`StreakPL`) lives in the weak-dep
        # extension ext/QPSToolsElabFTWExt.jl, which Aqua.test_all(QPSTools) does
        # not scan; the cavity fit moved into OpticalSpectroscopy.
        # ElabFTW (the eLabFTW weak dep) is pinned by a [sources] URL, so per
        # project policy it carries no [compat] entry — but Aqua's extras/weakdeps
        # compat sub-checks would demand one. Disable those two sub-checks; the
        # main deps check still runs, ignoring the other [sources]-pinned deps.
        Aqua.test_all(QPSTools;
            deps_compat=(check_extras=false, check_weakdeps=false, ignore=[
                :Dates, :DelimitedFiles, :LinearAlgebra, :Statistics,
                :ElabFTW, :HamamatsuStreakFiles,
                :JASCOFiles, :QPSScanFormat, :OpticalSpectroscopy,
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
