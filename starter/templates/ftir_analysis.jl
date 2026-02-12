# FTIR分析 / FTIR Analysis
# 実行 / Run:  julia --project=../.. analyses/NH4SCN_CN_stretch/analysis.jl
# 参考 / Ref:  QPSTools.jl/examples/ftir_analysis.jl

using QPSTools
using CairoMakie

FIGDIR = joinpath(@__DIR__, "figures")
mkpath(FIGDIR)
set_data_dir(joinpath(dirname(dirname(@__DIR__)), "data"))

# 1. 読み込み / Load
list_ftir()
spec = load_ftir(solute="NH4SCN", concentration="1.0M")

# 2. 全体像 / Survey
fig, ax = plot_ftir(spec)
save(joinpath(FIGDIR, "survey.png"), fig)

# 3. ピーク検出 / Peak detection
peaks = find_peaks(spec)
println(peak_table(peaks))

fig, ax = plot_ftir(spec; peaks=peaks)
save(joinpath(FIGDIR, "peaks.png"), fig)

# 4. フィッティング / Peak fitting
# 領域 (lo, hi) を自分のデータに合わせて変更
# Change the region (lo, hi) to match your data
result = fit_peaks(spec, (1950, 2150))
report(result)

fig, ax, ax_res = plot_ftir(spec; fit=result, residuals=true)
save(joinpath(FIGDIR, "fit.png"), fig)

# 三面図（論文用） / Three-panel (publication)
fig, ax_ctx, ax_fit, ax_res = plot_ftir(spec; fit=result, context=true, peaks=peaks)
save(joinpath(FIGDIR, "context.png"), fig)

# 5. eLabFTWに記録 / Log to eLabFTW
log_to_elab(
    title = "FTIR: NH4SCN CN stretch fit",
    body = format_results(result),
    attachments = [joinpath(FIGDIR, "context.png")],
    tags = ["ftir", "nh4scn"]
)
