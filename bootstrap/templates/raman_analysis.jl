# ラマン分析 / Raman Analysis
# 参考 / Ref:  QPSTools.jl/examples/raman_analysis.jl
#
# 実行方法 / How to run (from project root):
#   ターミナル / Terminal:  julia --project=. analysis/MoSe2_A1g/analysis.jl
#   REPL:                  include("analysis/MoSe2_A1g/analysis.jl")

using QPSTools
using CairoMakie

FIGDIR = joinpath(@__DIR__, "figures")
mkpath(FIGDIR)

# 1. 読み込み / Load
# パスとメタデータを自分のデータに合わせて変更
# Change the path and metadata to match your data
spec = load_raman("data/raman/my_sample.csv"; material="MySample")

# 2. 全体像 / Survey
fig, ax = plot_raman(spec)
save(joinpath(FIGDIR, "survey.png"), fig)

# 3. ピーク検出 / Peak detection
peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_raman(spec; peaks=peaks)
save(joinpath(FIGDIR, "peaks.png"), fig)

# 4. フィッティング / Peak fitting
# peak_tableの出力からフィットしたいピークの範囲を読み取る
# Read the peak_table output above to choose a region around your peak
# 領域 (lo, hi) を自分のデータに合わせて変更
# Change the region (lo, hi) to match your data
result = fit_peaks(spec, (200, 260))
report(result)

fig, ax, ax_res = plot_raman(spec; fit=result, residuals=true)
save(joinpath(FIGDIR, "fit.png"), fig)

# 三面図 / Three-panel (full spectrum + fit + residuals)
fig, ax_ctx, ax_fit, ax_res = plot_raman(spec; fit=result, context=true, peaks=peaks)
save(joinpath(FIGDIR, "context.png"), fig)

# 5. eLabFTWに記録 / Log to eLabFTW
# 環境変数の設定が必要 / Requires environment variables:
#   export ELABFTW_URL="https://your-instance.elabftw.net"
#   export ELABFTW_API_KEY="your-api-key"
#= Uncomment when ready:
log_to_elab(spec, result;
    title = "Raman: MySample peak fit",
    attachments = [joinpath(FIGDIR, "context.png")],
    extra_tags = ["peak_fit"]
)
=#
