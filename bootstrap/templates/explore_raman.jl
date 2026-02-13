# ラマン探索 / Raman Exploration
# explore/にコピーしてREPLで1行ずつ実行
# Copy to explore/ and step through in the REPL
#
#   julia --project=.
#   julia> include("explore/explore_raman.jl")
#
# Ref: examples/explore_raman.jl

using QPSTools, GLMakie
set_theme!(qps_theme())

# ─────────────────────────────────────────────────────────────────────
# 1. Load
# ─────────────────────────────────────────────────────────────────────

# サンプルデータ同梱 — 自分のファイルに置き換えてください
# Sample data included — replace with your own file
spec = load_raman("data/raman/MoSe2-center.csv"; material="MoSe2", sample="center")

# ─────────────────────────────────────────────────────────────────────
# 2. Fit a region
# ─────────────────────────────────────────────────────────────────────
# DataInspectorでホバーして波数範囲を特定する。
# Use DataInspector to hover and identify the wavenumber range.
# オプションはすべて省略可。変更・削除は自由。
# All options are optional. Change or remove as needed.
#   model:          lorentzian (default), gaussian, pseudo_voigt
#   n_peaks:        ピーク数を固定 / fix number of peaks (auto-detected if omitted)
#   baseline_order: 0=定数, 1=線形(default), 2=二次... / 0=const, 1=linear, 2=quadratic...

region = (225, 260)   # e.g. A₁g
result = fit_peaks(spec, region; model=lorentzian, n_peaks=1, baseline_order=1)
report(result)

# ─────────────────────────────────────────────────────────────────────
# 3. Plot fit with residuals
# ─────────────────────────────────────────────────────────────────────

fig, ax_ctx, ax_fit, ax_res = plot_raman(spec; fit=result, context=true, residuals=true)
display(fig)
DataInspector()
