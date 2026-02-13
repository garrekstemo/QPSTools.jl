# ラマン探索 / Raman Exploration
# explore/にコピーしてREPLで1行ずつ実行
# Copy to explore/ and step through in the REPL
#
#   julia --project=.
#   julia> include("explore/explore_raman.jl")

using QPSTools, GLMakie
set_theme!(qps_theme())

spec = load_raman("data/raman/my_sample.csv"; material="MySample")

fig, ax = plot_raman(spec)
display(fig)
DataInspector()  # マウスホバーで値を読む / hover to read values

peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_raman(spec; peaks=peaks)
display(fig)
