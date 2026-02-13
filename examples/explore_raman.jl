# Raman Exploration
#
# Runnable version of starter/templates/explore_raman.jl with real data.
# Step through in the REPL to interactively explore your spectrum.
#
# Ref: starter/templates/explore_raman.jl

using QPSTools, GLMakie

PROJECT_ROOT = dirname(@__DIR__)
set_theme!(qps_theme())

# Load
spec = load_raman(joinpath(PROJECT_ROOT, "data", "raman", "MoSe2", "MoSe2-center.csv");
    material="MoSe2", sample="center")

# Survey
fig, ax = plot_raman(spec)
display(fig)
DataInspector()  # hover to read values

# Peak detection
peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_raman(spec; peaks=peaks)
display(fig)
