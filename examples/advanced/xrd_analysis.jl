# XRD Analysis Example
#
# Demonstrates peak labeling on X-ray diffraction data.

using QPSTools
using CairoMakie

PROJECT_ROOT = dirname(dirname(@__DIR__))
FIGDIR = joinpath(PROJECT_ROOT, "figures", "EXAMPLES", "xrd")
mkpath(FIGDIR)

# =============================================================================
# Helper: load Rigaku SmartLab .txt files
# =============================================================================

function load_xrd(path::String)
    all_lines = readlines(path)
    # Data starts after header lines (* and # prefixed)
    data_start = findfirst(l -> l[1] != '*' && l[1] != '#', all_lines)

    twotheta = Float64[]
    intensity = Float64[]
    for l in all_lines[data_start:end]
        parts = split(l)
        length(parts) >= 2 || continue
        push!(twotheta, parse(Float64, parts[1]))
        push!(intensity, parse(Float64, parts[2]))
    end
    return twotheta, intensity
end

# =============================================================================
# 1. Label peaks for all three samples
# =============================================================================

xrd_dir = joinpath(PROJECT_ROOT, "data", "xrd")
samples = [
    ("ZIF-62(Co) powder",           joinpath(xrd_dir, "ZIF62-Co_powder.txt")),
    ("ZIF-62(Co) powder (low XRF)", joinpath(xrd_dir, "ZIF62-Co_powder_lowXRF.txt")),
    ("ZIF-62(Zn) crystal",          joinpath(xrd_dir, "ZIF62-Zn_crystal.txt")),
]

for (name, path) in samples
    twotheta, intensity = load_xrd(path)
    println("$name: $(length(twotheta)) points, 2θ = $(twotheta[1])–$(twotheta[end])°")

    peaks = find_peaks(twotheta, intensity; min_prominence=0.02)
    fig, ax = plot_spectrum(twotheta, intensity; peaks=peaks,
        xlabel="2θ (°)", ylabel="Intensity (cps)", title=name)

    tag = replace(replace(name, " " => "_"), r"[()]" => "")
    save(joinpath(FIGDIR, "xrd_labeled_$(tag).png"), fig)

    println("  $(length(peaks)) peaks detected")
    println(peak_table(peaks))
    println()
end

println("Figures saved to $FIGDIR")
