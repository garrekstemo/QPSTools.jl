# PLマッピング分析 / PL Mapping Analysis
# 参考 / Ref:  QPSTools.jl/examples/plmap_analysis.jl
#
# 実行方法 / How to run (from project root):
#   ターミナル / Terminal:  julia --project=. analysis/MoSe2_flake/analysis.jl
#   REPL:                  include("analysis/MoSe2_flake/analysis.jl")
#
# 探索テンプレートでPIXEL_RANGEを決めてからこのスクリプトに記入する。
# Use explore_plmap.jl to find PIXEL_RANGE first, then fill it in here.

using QPSTools
using CairoMakie

FIGDIR = joinpath(@__DIR__, "figures")
mkpath(FIGDIR)

# --- 設定 / Config (fill in from exploration) ---
filepath = "data/PLmap/my_scan.lvm"
STEP_SIZE = 2.16
PIXEL_RANGE = (950, 1100)
positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]

# =========================================================================
# 1. データ処理 / Process data
# =========================================================================

m_raw = load_pl_map(filepath; step_size=STEP_SIZE)
m = load_pl_map(filepath; step_size=STEP_SIZE, pixel_range=PIXEL_RANGE)
m = subtract_background(m)
centers = peak_centers(m)
m = normalize_intensity(m)
println(m)

# =========================================================================
# 2. 図の作成 / Build figure
# =========================================================================

# set_theme! is needed here because we build a custom figure below.
# QPSTools plot functions (plot_pl_map, plot_raman, etc.) apply it automatically.
set_theme!(qps_theme())
fig = Figure(size=(1400, 400))

# (a) スペクトル + 積分窓 / Spectra with integration window
ax1 = Axis(fig[1, 1], xlabel="CCD Pixel", ylabel="Counts",
    title="(a) PL Spectra")
for (i, pos) in enumerate(positions)
    spec = extract_spectrum(m_raw; x=pos[1], y=pos[2])
    lines!(ax1, spec.pixel, spec.signal, label="($(pos[1]), $(pos[2])) μm")
end
vspan!(ax1, PIXEL_RANGE..., color=(:blue, 0.1))
axislegend(ax1, position=:rt)

# (b) 正規化PLマップ / Normalized PL intensity map
ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
    title="(b) PL Intensity", aspect=DataAspect())
hm = heatmap!(ax2, xdata(m), ydata(m), intensity(m); colormap=:hot)
Colorbar(fig[1, 3], hm, label="Normalized PL")
colsize!(fig.layout, 2, Aspect(1, 1.0))

# (c) ピーク中心マップ / PL peak center map
ax3 = Axis(fig[1, 4], xlabel="X (μm)", ylabel="Y (μm)",
    title="(c) Peak Center", aspect=DataAspect())
hm2 = heatmap!(ax3, xdata(m), ydata(m), centers; colormap=:viridis,
    nan_color=:transparent)
Colorbar(fig[1, 5], hm2, label="Peak Center (pixel)")
colsize!(fig.layout, 4, Aspect(1, 1.0))

save(joinpath(FIGDIR, "pl_map.png"), fig)

# =========================================================================
# 3. eLabFTWに記録 / Log to eLabFTW
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
- **Background**: auto (off-flake corners)
""",
    attachments = [joinpath(FIGDIR, "pl_map.png")],
    tags = ["pl-map"]
)
=#
