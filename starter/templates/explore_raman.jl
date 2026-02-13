# ラマン探索 / Raman Exploration
# scratch/にコピーしてREPLで1行ずつ実行
# Copy to scratch/ and step through in the REPL
#
#   julia --project=.
#   julia> include("scratch/explore_raman.jl")

using QPSTools, GLMakie

spec = load_raman("data/raman/my_sample.csv"; material="MySample")

fig, ax = plot_raman(spec)
DataInspector()  # マウスホバーで値を読む / hover to read values

peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_raman(spec; peaks=peaks)
