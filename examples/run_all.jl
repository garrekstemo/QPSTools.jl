# Run All Examples
#
# Runs each example script in a separate process to avoid state leakage.
#
# Usage:
#   julia --project=examples examples/run_all.jl

EXAMPLES_DIR = @__DIR__

scripts = [
    "plmap_analysis.jl",
    "advanced/broadband_ta.jl",
    "advanced/mir_workflow.jl",
    "advanced/cavity_analysis.jl",
    "advanced/single_beam.jl",
    "advanced/xrd_analysis.jl",
    "advanced/cosmic_ray_removal.jl",
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
