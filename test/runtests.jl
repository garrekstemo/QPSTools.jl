include("testsetup.jl")

@testset "QPSTools.jl" begin
    include("test_types.jl")
    include("test_io.jl")
    include("test_ftir.jl")
    include("test_raman.jl")
    include("test_ta.jl")
    include("test_ta_matrix.jl")
    include("test_cavity.jl")
    include("test_chirp.jl")
    include("test_elabftw.jl")
    include("test_plmap.jl")
    include("test_plotting.jl")
    include("test_format_results.jl")
end
