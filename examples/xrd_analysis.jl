# XRD Analysis Example
#
# Demonstrates peak labeling on X-ray diffraction data.
# Run from project root: julia --project=. examples/xrd_analysis.jl

using QPSTools
using CairoMakie

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

samples = [
    ("ZIF-62(Co) powder",           "data/xrd/ZIF62-Co_powder.txt"),
    ("ZIF-62(Co) powder (low XRF)", "data/xrd/ZIF62-Co_powder_lowXRF.txt"),
    ("ZIF-62(Zn) crystal",          "data/xrd/ZIF62-Zn_crystal.txt"),
]

for (name, path) in samples
    twotheta, intensity = load_xrd(path)
    println("$name: $(length(twotheta)) points, 2θ = $(twotheta[1])–$(twotheta[end])°")

    fig, peaks = label_peaks(twotheta, intensity;
        xlabel_text="2θ (°)",
        ylabel_text="Intensity (cps)",
        title=name,
        min_prominence=0.02)

    tag = replace(replace(name, " " => "_"), r"[()]" => "")
    save("figures/EXAMPLES/xrd/xrd_labeled_$(tag).pdf", fig)

    println("  $(length(peaks)) peaks detected")
    println(peak_table(peaks))
    println()
end

println("Figures saved to figures/EXAMPLES/xrd/")
