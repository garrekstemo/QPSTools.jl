# QPSTools セットアップ / QPSTools Setup
#
# 既存のJuliaプロジェクトにQPSToolsを追加する。
# Adds QPSTools to an existing Julia project.
#
# 実行方法 / Run from your project root:
#   julia --project=. setup_qpstools.jl

using Pkg

println("QPSToolsと依存パッケージをインストール中...")
println("Installing QPSTools and dependencies...")

Pkg.add(url="https://github.com/garrekstemo/QPSTools.jl.git")
Pkg.add("GLMakie")
Pkg.add("Revise")

println()
println("セットアップ完了 / Setup complete!")
println()
println("テスト / Test:")
println("  julia --project=.")
println("  julia> using Revise, QPSTools")
println("  julia> using GLMakie")
