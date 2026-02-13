# QPSTools Install
#
# Adds QPSTools and its dependencies to your project, copies analysis
# templates, and creates the standard directory scaffold.
#
# Run from your project root:
#   julia --project=. bootstrap/install.jl

using Pkg
using TOML

BOOTSTRAP_DIR = @__DIR__
PROJECT_ROOT = dirname(BOOTSTRAP_DIR)

# ─────────────────────────────────────────────────────────────────────
# 1. Package installation
# ─────────────────────────────────────────────────────────────────────

println("=== QPSTools Install ===")
println()
println("1/3  Installing packages...")

project_file = Base.active_project()
project = TOML.parsefile(project_file)

if !haskey(project, "deps")
    project["deps"] = Dict{String,Any}()
end
if !haskey(project, "sources")
    project["sources"] = Dict{String,Any}()
end

# Unregistered packages need [deps] + [sources] entries
unregistered = Dict(
    "QPSTools"          => ("91240044-bfa4-4bca-8577-4d123ebe80d7",
                            "https://github.com/garrekstemo/QPSTools.jl.git"),
    "SpectroscopyTools" => ("f1436f7a-66ba-4269-a153-8996db8f0853",
                            "https://github.com/garrekstemo/SpectroscopyTools.jl.git"),
    "JASCOFiles"        => ("8f461479-960a-4355-a802-16cf8971498c",
                            "https://github.com/garrekstemo/JASCOFiles.jl.git"),
)

for (name, (uuid, url)) in unregistered
    project["deps"][name] = uuid
    project["sources"][name] = Dict("url" => url)
    println("  + $name")
end

open(project_file, "w") do io
    TOML.print(io, project)
end

Pkg.resolve()

println()
println("  Installing GLMakie and Revise...")
Pkg.add("GLMakie")
Pkg.add("Revise")

# ─────────────────────────────────────────────────────────────────────
# 2. Copy templates
# ─────────────────────────────────────────────────────────────────────

println()
println("2/4  Copying templates...")

src_templates = joinpath(BOOTSTRAP_DIR, "templates")
dst_templates = joinpath(PROJECT_ROOT, "templates")
mkpath(dst_templates)

for f in readdir(src_templates)
    src = joinpath(src_templates, f)
    dst = joinpath(dst_templates, f)
    if isfile(dst)
        println("  skip $f (already exists)")
    else
        cp(src, dst)
        println("  + $f")
    end
end

# ─────────────────────────────────────────────────────────────────────
# 3. Copy sample data
# ─────────────────────────────────────────────────────────────────────

println()
println("3/4  Copying sample data...")

src_data = joinpath(BOOTSTRAP_DIR, "data")
if isdir(src_data)
    for subdir in readdir(src_data)
        src_sub = joinpath(src_data, subdir)
        isdir(src_sub) || continue
        dst_sub = joinpath(PROJECT_ROOT, "data", subdir)
        mkpath(dst_sub)
        for f in readdir(src_sub)
            src = joinpath(src_sub, f)
            dst = joinpath(dst_sub, f)
            if isfile(dst)
                println("  skip data/$subdir/$f (already exists)")
            else
                cp(src, dst)
                println("  + data/$subdir/$f")
            end
        end
    end
end

# ─────────────────────────────────────────────────────────────────────
# 4. Create directory scaffold + .gitignore
# ─────────────────────────────────────────────────────────────────────

println()
println("4/4  Creating directories...")

for d in ["explore", "analysis", "manuscript", "data"]
    path = joinpath(PROJECT_ROOT, d)
    mkpath(path)
    println("  + $d/")
end

gitignore_src = joinpath(BOOTSTRAP_DIR, ".gitignore")
gitignore_dst = joinpath(PROJECT_ROOT, ".gitignore")

if !isfile(gitignore_dst)
    cp(gitignore_src, gitignore_dst)
    println("  + .gitignore (copied)")
else
    # Append missing entries from template
    existing = Set(strip.(readlines(gitignore_dst)))
    template_lines = strip.(readlines(gitignore_src))
    new_lines = filter(l -> l != "" && !(l in existing), template_lines)
    if !isempty(new_lines)
        open(gitignore_dst, "a") do io
            println(io)
            for l in new_lines
                println(io, l)
            end
        end
        println("  + .gitignore (appended $(length(new_lines)) entries)")
    else
        println("  skip .gitignore (already up to date)")
    end
end

# ─────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────

println()
println("=" ^ 50)
println("Install complete!")
println("=" ^ 50)
println()
println("Verify:")
println("  julia --project=.")
println("  julia> using Revise, QPSTools")
println("  julia> using GLMakie")
println()
println("Templates are in templates/ — copy to explore/ or analysis/ to use.")
