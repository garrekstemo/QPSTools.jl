# 初期セットアップ / One-time setup
# 実行 / Run:  julia --project=. setup.jl

using Pkg

# 自分の環境に合わせて変更 / Adjust for your machine
qpstools_path = expanduser("~/Documents/projects/QPSTools.jl")

if !isdir(qpstools_path)
    @error "QPSTools not found: $qpstools_path"
else
    Pkg.develop(path=qpstools_path)
    Pkg.instantiate()
    println("\nセットアップ完了 / Setup complete")
    println("  julia --project=.")
end
