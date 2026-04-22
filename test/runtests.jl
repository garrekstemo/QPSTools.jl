include("testsetup.jl")
using Aqua

@testset "QPSTools.jl" begin

    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(QPSTools)
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
    include("test_plotting.jl")
    include("test_format_results.jl")
end
