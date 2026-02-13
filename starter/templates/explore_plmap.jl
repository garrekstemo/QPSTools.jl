# PLマッピング探索 / PL Map Exploration
# scratch/にコピーしてREPLで1行ずつ実行
# Copy to scratch/ and step through in the REPL
#
#   julia --project=.
#   julia> include("scratch/explore_plmap.jl")
#
# スペクトルを見てPLピークのピクセル範囲を特定する
# Inspect spectra to find the PL peak pixel range

using QPSTools, GLMakie

m = load_pl_map("data/PLmap/my_scan.lvm"; step_size=2.16)
println(m)

# 代表的な位置でスペクトルを確認 / Check spectra at representative positions
positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]
fig, ax = plot_pl_spectra(m, positions)
DataInspector()  # マウスホバーでピクセル番号と強度を読む / hover to read pixel numbers
