# FTIR探索 / FTIR Exploration
# scratch/にコピーしてREPLで1行ずつ実行
# Copy to scratch/ and step through in the REPL
#
#   julia --project=.
#   julia> include("scratch/explore_ftir.jl")

using QPSTools, GLMakie
set_theme!(qps_theme())

spec = load_ftir("data/ftir/my_solution.csv"; solute="NH4SCN", concentration="1.0M")

fig, ax = plot_ftir(spec)
display(fig)
DataInspector()  # マウスホバーで値を読む / hover to read values

peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_ftir(spec; peaks=peaks)
display(fig)
