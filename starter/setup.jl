# 初期セットアップ / One-time setup
# 実行 / Run:  julia --project=. setup.jl

using Pkg

println("パッケージをインストール中... / Installing packages...")
Pkg.instantiate()

println("\nセットアップ完了 / Setup complete")
println("  julia --project=.")
