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
set_theme!(qps_theme())

m = load_pl_map("data/PLmap/my_scan.lvm"; step_size=2.16)
println(m)

# スペクトル + 生マップを並べて表示
# Show spectra alongside the raw intensity map
positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]

fig = Figure(size=(1000, 400))

# (a) スペクトル / Spectra — ピクセル番号をホバーで読む / hover to read pixel numbers
ax1 = Axis(fig[1, 1], xlabel="CCD Pixel", ylabel="Counts", title="Spectra")
for (i, pos) in enumerate(positions)
    spec = extract_spectrum(m; x=pos[1], y=pos[2])
    lines!(ax1, spec.pixel, spec.signal, label="($(pos[1]), $(pos[2])) μm")
end
axislegend(ax1, position=:rt)

# (b) 生マップ + スペクトル位置 / Raw intensity map with spectrum positions marked
ax2 = Axis(fig[1, 2], xlabel="X (μm)", ylabel="Y (μm)",
    title="Raw PL Map", aspect=DataAspect())
hm = heatmap!(ax2, xdata(m), ydata(m), intensity(m); colormap=:hot)
colors = Makie.wong_colors()
for (i, pos) in enumerate(positions)
    scatter!(ax2, [pos[1]], [pos[2]], color=colors[i], markersize=10,
        strokecolor=:white, strokewidth=1)
end
Colorbar(fig[1, 3], hm, label="Counts")
colgap!(fig.layout, 2, 5)

display(fig)
DataInspector()  # マウスホバーで値を読む / hover to read values

# --- ピクセル範囲を選んでマップを更新 / Set pixel range and update the map ---
# スペクトルをホバーしてPLピークのピクセル範囲を読み取り、下の値を変更して実行
# Hover over the spectra to read the PL peak pixel range, update the value below, and run

PIXEL_RANGE = (950, 1100)

m2 = load_pl_map("data/PLmap/my_scan.lvm"; step_size=2.16, pixel_range=PIXEL_RANGE)
m2 = subtract_background(m2)
m2 = normalize(m2)

# スペクトルに積分窓を表示、マップを更新
# Show integration window on spectra, update the map
vspan!(ax1, PIXEL_RANGE..., color=(:blue, 0.1))
hm[3] = intensity(m2)
display(fig)
