# PLマッピング分析 / PL Mapping Analysis
# 参考 / Ref:  QPSTools.jl/examples/pl_map_example.jl
#
# 実行方法 / How to run (from project root):
#   ターミナル / Terminal:  julia --project=. analyses/MoSe2_flake/analysis.jl
#   REPL:                  include("analyses/MoSe2_flake/analysis.jl")
#
# 使い方 / How to use:
#   1回目: そのまま実行 → spectra.png が保存される
#          Run as-is → saves spectra.png
#   2回目: spectra.pngを見てPIXEL_RANGEを設定 → 再実行でマップ完成
#          Set PIXEL_RANGE from spectra.png → rerun for final map

using QPSTools
using CairoMakie

FIGDIR = joinpath(@__DIR__, "figures")
mkpath(FIGDIR)

# パスとstep_sizeを自分のデータに合わせて変更
# Change the path and step_size to match your scan
filepath = "data/PLmap/my_scan.lvm"
STEP_SIZE = 2.16

# spectra.pngを見てからPLピークのピクセル範囲を設定
# After looking at spectra.png, set the pixel range that contains your PL peak
PIXEL_RANGE = nothing  # → (950, 1100)

# =========================================================================
# Step 1: スペクトル確認 / Inspect spectra
# =========================================================================

m_raw = load_pl_map(filepath; step_size=STEP_SIZE)
println(m_raw)

positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]
fig, ax = plot_pl_spectra(m_raw, positions)
save(joinpath(FIGDIR, "spectra.png"), fig)

if isnothing(PIXEL_RANGE)
    println("\n--> spectra.png を確認して PIXEL_RANGE を設定してください")
    println("--> Check spectra.png, then set PIXEL_RANGE above and rerun")
    return
end

# =========================================================================
# Step 2: マップ作成 / Build the map
# =========================================================================

m = load_pl_map(filepath; step_size=STEP_SIZE, pixel_range=PIXEL_RANGE)
m = subtract_background(m)
m = normalize(m)

fig, ax = plot_pl_map(m)
save(joinpath(FIGDIR, "pl_map.png"), fig)

# =========================================================================
# Step 3: 論文用図 / Publication figure
# =========================================================================

set_theme!(print_theme())
fig = Figure(size=(1000, 400))

ax1 = Axis(fig[1, 1], xlabel="CCD Pixel", ylabel="Counts", title="(a)")
for (i, pos) in enumerate(positions)
    spec = extract_spectrum(m_raw; x=pos[1], y=pos[2])
    lines!(ax1, spec.pixel, spec.signal, label="($(pos[1]), $(pos[2])) μm")
end
vspan!(ax1, PIXEL_RANGE..., color=(:blue, 0.1))
axislegend(ax1, position=:rt)

ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
    title="(b)", aspect=DataAspect())
hm = heatmap!(ax2, xdata(m), ydata(m), intensity(m); colormap=:hot)
Colorbar(fig[1, 3], hm, label="Normalized PL")

save(joinpath(FIGDIR, "publication.pdf"), fig)

# =========================================================================
# Step 4: eLabFTWに記録 / Log to eLabFTW
# =========================================================================
# 環境変数の設定が必要 / Requires environment variables:
#   export ELABFTW_URL="https://your-instance.elabftw.net"
#   export ELABFTW_API_KEY="your-api-key"
#= Uncomment when ready:
log_to_elab(
    title = "PL Map: MySample",
    body = """
## 測定条件 / Measurement
- **Grid**: $(m_raw.metadata["nx"]) x $(m_raw.metadata["ny"]) ($(STEP_SIZE) μm step)
- **PL pixel range**: $(PIXEL_RANGE[1])-$(PIXEL_RANGE[2])
- **Background**: auto
""",
    attachments = [joinpath(FIGDIR, "publication.pdf")],
    tags = ["pl-map"]
)
=#
