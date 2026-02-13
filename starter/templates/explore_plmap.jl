# PLマッピング探索 / PL Map Exploration
# explore/にコピーしてREPLで1行ずつ実行
# Copy to explore/ and step through in the REPL
#
#   julia --project=.
#   julia> include("explore/explore_plmap.jl")
#
# スペクトルをホバーしてPLピークのピクセル範囲を特定 → PIXEL_RANGEを変更して再実行
# Hover over spectra to find the PL peak pixel range → change PIXEL_RANGE and rerun

using QPSTools, GLMakie
set_theme!(qps_theme())

# --- 設定 / Config (edit these) ---
filepath = "data/PLmap/my_scan.lvm"
STEP_SIZE = 2.16
PIXEL_RANGE = (950, 1100)
positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]

# --- 読み込み + 処理 / Load + process ---
m_raw = load_pl_map(filepath; step_size=STEP_SIZE)
m = load_pl_map(filepath; step_size=STEP_SIZE, pixel_range=PIXEL_RANGE)
m = subtract_background(m)
centers = peak_centers(m)
m = normalize(m)

# --- 表示 / Display ---
fig = Figure(size=(1400, 400))

# (a) スペクトル + 積分窓 / Spectra with integration window
ax1 = Axis(fig[1, 1], xlabel="CCD Pixel", ylabel="Counts", title="Spectra")
for (i, pos) in enumerate(positions)
    spec = extract_spectrum(m_raw; x=pos[1], y=pos[2])
    lines!(ax1, spec.pixel, spec.signal, label="($(pos[1]), $(pos[2])) μm")
end
vspan!(ax1, PIXEL_RANGE..., color=(:blue, 0.1))
axislegend(ax1, position=:rt)

# (b) PLマップ + スペクトル位置 / PL map with spectrum positions marked
ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
    title="PL Map", aspect=DataAspect())
hm = heatmap!(ax2, xdata(m), ydata(m), intensity(m); colormap=:hot)
colors = Makie.wong_colors()
for (i, pos) in enumerate(positions)
    scatter!(ax2, [pos[1]], [pos[2]], color=colors[i], markersize=10,
        strokecolor=:white, strokewidth=1)
end
Colorbar(fig[1, 3], hm, label="Normalized PL")
colsize!(fig.layout, 2, Aspect(1, 1.0))

# (c) ピーク中心マップ / PL peak center map
ax3 = Axis(fig[1, 4], xlabel="X (μm)", ylabel="Y (μm)",
    title="Peak Center", aspect=DataAspect())
hm2 = heatmap!(ax3, xdata(m), ydata(m), centers; colormap=:viridis,
    nan_color=:transparent)
Colorbar(fig[1, 5], hm2, label="Peak Center (pixel)")
colsize!(fig.layout, 4, Aspect(1, 1.0))

display(fig)
DataInspector()
