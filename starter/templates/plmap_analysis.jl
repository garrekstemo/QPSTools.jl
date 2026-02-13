# PLマッピング分析 / PL Mapping Analysis
# 参考 / Ref:  QPSTools.jl/examples/pl_map_example.jl
#
# 実行方法 / How to run (from project root):
#   ターミナル / Terminal:  julia --project=. analyses/MoSe2_flake/analysis.jl
#   REPL:                  include("analyses/MoSe2_flake/analysis.jl")

using QPSTools
using CairoMakie

FIGDIR = joinpath(@__DIR__, "figures")
mkpath(FIGDIR)

# 1. 読み込み・スペクトル確認 / Load and inspect spectra
# パスとstep_sizeを自分のデータに合わせて変更
# Change the path and step_size to match your scan
filepath = "data/PLmap/my_scan.lvm"
m_raw = load_pl_map(filepath; step_size=2.16)
println(m_raw)

# 位置を選んでスペクトルを確認 / Pick positions and check spectra
positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]
fig, ax = plot_pl_spectra(m_raw, positions)
save(joinpath(FIGDIR, "spectra.png"), fig)

# 2. ピクセル範囲を決めて再読み込み / Choose pixel range and reload
# spectra.pngを見てPLピークの範囲を決める
# Look at spectra.png to find which pixels contain the PL peak
m = load_pl_map(filepath; step_size=2.16, pixel_range=(950, 1100))
m = subtract_background(m)
m = normalize(m)

# 3. PLマップ / PL intensity map
fig, ax = plot_pl_map(m)
save(joinpath(FIGDIR, "pl_map.png"), fig)

# 4. 論文用図 / Publication figure
set_theme!(print_theme())
fig = Figure(size=(1000, 400))

ax1 = Axis(fig[1, 1], xlabel="CCD Pixel", ylabel="Counts", title="(a)")
for (i, pos) in enumerate(positions)
    spec = extract_spectrum(m_raw; x=pos[1], y=pos[2])
    lines!(ax1, spec.pixel, spec.signal, label="($(pos[1]), $(pos[2])) μm")
end
vspan!(ax1, 950, 1100, color=(:blue, 0.1))
axislegend(ax1, position=:rt)

ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
    title="(b)", aspect=DataAspect())
hm = heatmap!(ax2, xdata(m), ydata(m), intensity(m); colormap=:hot)
Colorbar(fig[1, 3], hm, label="Normalized PL")

save(joinpath(FIGDIR, "publication.pdf"), fig)

# 5. eLabFTWに記録 / Log to eLabFTW
# 環境変数の設定が必要 / Requires environment variables:
#   export ELABFTW_URL="https://your-instance.elabftw.net"
#   export ELABFTW_API_KEY="your-api-key"
#= Uncomment when ready:
log_to_elab(
    title = "PL Map: MySample",
    body = """
## 測定条件 / Measurement
- **Grid**: $(m_raw.metadata["nx"]) x $(m_raw.metadata["ny"]) ($(m_raw.metadata["step_size"]) μm step)
- **PL pixel range**: 950-1100
- **Background**: auto
""",
    attachments = [joinpath(FIGDIR, "publication.pdf")],
    tags = ["pl-map"]
)
=#
