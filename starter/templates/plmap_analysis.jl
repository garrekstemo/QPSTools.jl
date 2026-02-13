# PLマッピング分析 / PL Mapping Analysis
# 参考 / Ref:  QPSTools.jl/examples/pl_map_example.jl
#
# 実行方法 / How to run (from project root):
#   ターミナル / Terminal:  julia --project=. analyses/MoSe2_flake/analysis.jl
#   REPL:                  include("analyses/MoSe2_flake/analysis.jl")
#
# --- 概要 / What this does ---
#
# CCDラスタースキャンは各空間点でフルスペクトル（カウント vs ピクセル）を記録する。
# スペクトルにはレーザー散乱、PL発光、ラマンピーク、検出器ノイズが全て含まれる。
# PLマップを作るには、PLピークだけを取り出す必要がある：
#
# A CCD raster scan records a full spectrum (counts vs pixel) at every spatial
# point. That spectrum contains everything: laser scatter, PL emission, Raman
# peaks, and detector noise. To build a PL map, we isolate just the PL peak:
#
#   Step 1: スペクトルを見てPLピークの位置（ピクセル範囲）を特定する
#           Inspect spectra to find which pixels contain the PL peak
#   Step 2: フレーク外のスペクトルを差し引いてレーザーとノイズを除去する
#           Subtract an off-flake spectrum to remove laser scatter and noise
#   Step 3: PLピクセルのみを合計 → グリッド点ごとに1つの強度値 → マップ
#           Sum only the PL pixels → one intensity value per grid point → map
#
using QPSTools
using CairoMakie

FIGDIR = joinpath(@__DIR__, "figures")
mkpath(FIGDIR)

# パスとstep_sizeを自分のデータに合わせて変更
# Change the path and step_size to match your scan
filepath = "data/PLmap/CCDtmp_260129_111138.lvm"
STEP_SIZE = 2.16

# spectra.pngを見てからPLピークのピクセル範囲を設定
# After looking at spectra.png, set the pixel range that brackets your PL peak
PIXEL_RANGE = (950, 1100)

# =========================================================================
# Step 1: スペクトル確認 / Inspect raw spectra
# =========================================================================
# 代表的な位置でスペクトルをプロット。PLピークを探す。
# レーザー散乱（鋭い）やラマンピーク（狭い）も見えるが、
# PL発光は通常最も広いピーク。PLピークを囲むピクセル範囲をメモする。
#
# Plot spectra at a few positions across the scan. Look for the PL peak.
# You'll also see laser scatter (sharp) and Raman peaks (narrow).
# PL emission is usually the broadest feature. Note which pixel range
# brackets the PL peak — that's what you'll set as PIXEL_RANGE.

m_raw = load_pl_map(filepath; step_size=STEP_SIZE)
println(m_raw)

positions = [(0.0, 0.0), (10.0, 10.0), (-10.0, -10.0)]
fig, ax = plot_pl_spectra(m_raw, positions)
save(joinpath(FIGDIR, "spectra.png"), fig)

# =========================================================================
# Step 2: バックグラウンド除去 / Background subtraction
# =========================================================================
# フレーク外の領域（PLなし）から平均スペクトルを取り、全グリッド点から
# 差し引く。これでレーザー散乱と検出器ノイズが除去され、PLピークだけが残る。
#
# Average the spectrum from off-flake regions (where there's no PL) and
# subtract it from every grid point. This removes laser scatter and
# detector noise, leaving only the PL contribution.

m = load_pl_map(filepath; step_size=STEP_SIZE, pixel_range=PIXEL_RANGE)
m = subtract_background(m)

# 確認: 補正後のスペクトルでPLピークがフラットなベースライン上にあるか確認
# Verify: the PL peak should now sit on a flat baseline
fig_check, ax_check = plot_pl_spectra(m, positions)
vspan!(ax_check, PIXEL_RANGE..., color=(:blue, 0.1))
save(joinpath(FIGDIR, "spectra_corrected.png"), fig_check)

# =========================================================================
# Step 3: マップ作成 / Build the intensity map
# =========================================================================
# PIXEL_RANGE内のカウントを合計して各グリッド点のPL強度を計算する。
# これは「スペクトル窓掛け」— PLピークだけを含む窓で積分している。
# 他のピーク（レーザー、ラマン）は窓の外なので無視される。
#
# Sum the counts within PIXEL_RANGE at each grid point to get PL intensity.
# This is "spectral windowing" — integrating only the window that contains
# the PL peak. Anything outside the window (laser, Raman) is ignored.

m = normalize(m)

set_theme!(print_theme())
fig = Figure(size=(1000, 400))

# (a) 生スペクトル + 積分窓（青帯）
# (a) Raw spectra with integration window (blue band)
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

save(joinpath(FIGDIR, "pl_map.png"), fig)

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
- **Background**: auto (off-flake corners)
""",
    attachments = [joinpath(FIGDIR, "pl_map.png")],
    tags = ["pl-map"]
)
=#
