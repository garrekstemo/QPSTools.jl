using HamamatsuStreakFiles
using GLMakie

# 15K.img は Julia を起動したフォルダに置くか、フルパスで指定する
s = StreakImage("15K.img")

# 1. データオブジェクトのプロパティ
propertynames(s)   # s が持っているフィールド（プロパティ）を全部リストアップ
s.wavelength       # 波長軸 [nm]。装置は赤→青の順で保存するので値は「減少」していく（662 → 395）
s.time             # 時間軸 [ns]。0 → 47
s.counts           # データ本体の行列。counts[波長のインデックス, 時間のインデックス]
size(s)            # (1408, 1072) = (波長ピクセル数, 時間ビン数)

# 装置のメタデータも一緒に読み込まれている
s.camera
s.time_range
s.date
s.metadata["Streak camera"]   # 生のメタデータ全体はセクション名で引ける

# 2. まずはヒートマップ表示（plot はカラーバーを f[1, 2] に置く）
f, ax1, hm = plot(s)
# 弱い発光を見たいときは: plot(s; colormap = :inferno, colorrange = (0, 20))

# 3. スペクトル — 時間方向に足し合わせる（時間積算スペクトル）
#
# counts は「波長 × 時間」の行列。ある波長の行には、その波長の光が各時刻に
# 何カウントあったかが並んでいる。これを時間方向（dims = 2）に全部足すと
# 「その波長で合計何カウントあったか」が波長ごとに 1 個ずつ得られて、
# それがそのまま発光スペクトルになる。
# sum(...; dims = 2) の結果は 1408×1 の行列のままなので、vec() で
# 普通のベクトルに直してからプロットする。
spectrum = vec(sum(s.counts, dims = 2))
ax2 = Axis(f[1, 3], title = "Spectrum", xlabel = "Wavelength (nm)", ylabel = "Counts")
lines!(ax2, s.wavelength, spectrum)   # x = 波長軸、y = 各波長の合計カウント

# 4. 減衰カーブ — 波長方向に足し合わせる（波長積算の減衰カーブ）
#
# 今度は逆向き。ある時刻の列には、その瞬間の全波長のカウントが並んでいる。
# これを波長方向（dims = 1）に全部足すと「その時刻に全波長合計で
# 何カウントあったか」が時刻ごとに 1 個ずつ得られる。
# それを時間軸に沿って並べたものが PL の減衰カーブ。
decay = vec(sum(s.counts, dims = 1))
ax3 = Axis(f[2, 1:3], title = "Decay", xlabel = "Time (ns)", ylabel = "Counts")
lines!(ax3, s.time, decay)   # x = 時間軸、y = 各時刻の合計カウント

f

# 5. 練習
# 行列から 1 行・1 列だけ取り出すと「ある時刻のスペクトル」「ある波長の減衰」
# になる。ただし 1 ビンあたり数フォトンしかないのでかなりノイジー：
#   lines(s.wavelength, s.counts[:, 100])   # 100 番目の時間ビンでのスペクトル
#   lines(s.time, s.counts[700, :])         # 700 番目の波長ピクセルでの減衰
#
# 物理的な値（450 nm、10 ns など）に一番近いインデックスを探す方法。
# 波長軸は値が「減少」していくことに注意！：
#   i = findfirst(<=(450), s.wavelength)    # 450 nm 以下になる最初のピクセル
#   j = findfirst(>=(10), s.time)           # 10 ns 以降の最初の時間ビン
#
# 1 ピクセルだけだとノイズだらけなので、近くのピクセルを束ねて足すときれいになる：
#   band = vec(sum(s.counts[i-20:i+20, :], dims = 1))
#   lines(s.time, band)                     # 450 nm 付近の減衰カーブ

# 6. 発展：減衰カーブのフィッティング
# decay を指数関数 A * exp(-t / τ) でフィットすると PL 寿命 τ が求まる。
# 研究室のフィッティングパッケージ CurveFit.jl を使ってみよう：
#   https://github.com/garrekstemo/CurveFit.jl
# （モデル関数は fn(p, x) の形で書くのがこのパッケージのルール）
# 実際のフィット例は examples/tutorial/ex3_lifetime_decay.jl にある。
