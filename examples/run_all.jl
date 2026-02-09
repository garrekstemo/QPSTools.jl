# Run All Examples
#
# Runs each example script in a separate process to avoid state leakage.
# Skips elabftw_logging.jl (requires a live server).
#
# Usage:
#   julia --project=examples examples/run_all.jl

EXAMPLES_DIR = @__DIR__

scripts = [
    "ftir_analysis.jl",
    "baseline_correction.jl",
    "raman_analysis.jl",
    "xrd_analysis.jl",
    "mir_workflow_example.jl",
    "single_beam_example.jl",
    "broadband_ta_example.jl",
    # "elabftw_logging.jl",  # requires live eLabFTW server
]

passed = String[]
failed = String[]

for script in scripts
    path = joinpath(EXAMPLES_DIR, script)
    println("\n", "=" ^ 60)
    println("Running: $script")
    println("=" ^ 60)

    t = @elapsed success = run(`julia --project=$EXAMPLES_DIR $path`; wait=true).exitcode == 0

    if success
        push!(passed, script)
        println("  PASSED ($script) in $(round(t, digits=1))s")
    else
        push!(failed, script)
        println("  FAILED ($script)")
    end
end

println("\n", "=" ^ 60)
println("Results: $(length(passed)) passed, $(length(failed)) failed out of $(length(scripts))")
println("=" ^ 60)

if !isempty(failed)
    println("\nFailed:")
    for s in failed
        println("  - $s")
    end
end
