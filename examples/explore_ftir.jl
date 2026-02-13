# FTIR Exploration
#
# Runnable version of starter/templates/explore_ftir.jl with real data.
# Step through in the REPL to interactively explore your spectrum.
#
# Ref: starter/templates/explore_ftir.jl

using QPSTools, GLMakie

PROJECT_ROOT = dirname(@__DIR__)
set_theme!(qps_theme())

# Load
spec = load_ftir(joinpath(PROJECT_ROOT, "data", "ftir", "1.0M_NH4SCN_DMF.csv");
    solute="NH4SCN", concentration="1.0M")

# Survey
fig, ax = plot_ftir(spec)
display(fig)
DataInspector()  # hover to read values

# Peak detection
peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_ftir(spec; peaks=peaks)
display(fig)
