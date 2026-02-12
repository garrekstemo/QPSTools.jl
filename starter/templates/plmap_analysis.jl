# PLマッピング分析 / PL Mapping Analysis
# 実行 / Run:  julia --project=../.. analyses/MoSe2_flake/analysis.jl
# 参考 / Ref:  QPSTools.jl/examples/pl_map_example.jl

using QPSTools
using CairoMakie

FIGDIR = joinpath(@__DIR__, "figures")
mkpath(FIGDIR)
set_data_dir(joinpath(dirname(dirname(@__DIR__)), "data"))

# 1. 読み込み・スペクトル確認 / Load and inspect spectra
filepath = joinpath(data_dir(), "PLmap", "my_scan.lvm")
m_raw = load_pl_map(filepath; nx=51, ny=51, step_size=2.16)
println(m_raw)

# 位置を選んでスペクトルを確認 / Pick positions and check spectra
positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]
fig, ax = plot_pl_spectra(m_raw, positions)
save(joinpath(FIGDIR, "spectra.png"), fig)

# 2. ピクセル範囲を決めて再読み込み / Choose pixel range and reload
# スペクトルを見てPLピークの範囲を決める
# Inspect spectra above to find PL peak pixel range
m = load_pl_map(filepath; nx=51, ny=51, step_size=2.16, pixel_range=(950, 1100))
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

save(joinpath(FIGDIR, "publication.png"), fig)

# 5. eLabFTWに記録 / Log to eLabFTW
log_to_elab(
    title = "PL Map: MySample",
    body = """
## 測定条件 / Measurement
- **Grid**: 51 x 51 (2.16 μm step)
- **PL pixel range**: 950-1100
- **Background**: auto
""",
    attachments = [joinpath(FIGDIR, "publication.png")],
    tags = ["pl-map"]
)
