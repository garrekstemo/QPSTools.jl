[English](GUIDE.en.md) | [日本語](GUIDE.ja.md)

# 解析の整理ガイド

QPS研究室における分光解析の整理に関するベストプラクティスです。

## 基本方針

1. **フォルダ名は内容で付ける。日付は付けない。**
   日付はラボノート（eLabFTW）に記録します。フォルダ名には含めません。
   わかりやすい名前を使いましょう：`MoSe2_A1g/`、`ZIF62_glass_baseline/`、`NH4SCN_CN_stretch/`

2. **解析対象ごとに1フォルダ。**
   MoSe2のA1gピークをフィットするなら、それが1つのフォルダです。
   後でE2gピークもフィットするなら、別のフォルダを作ります。
   関係のない解析を同じフォルダに入れないでください。

3. **図は解析と一緒に保存する。**
   各解析フォルダに`figures/`ディレクトリがあります。
   これにより、どのスクリプトがどの図を作ったか常に追跡できます。

4. **コピーせず、その場で編集する。**
   パラメータを変えて再解析するときは、既存のスクリプトを編集してください。
   `MoSe2_A1g_v2/`や`MoSe2_A1g_final/`を作らないでください。
   変更履歴を追跡したい場合はgitを使いましょう。

5. **生データは読み取り専用。**
   `data/`内のファイルは絶対に変更しないでください。
   解析スクリプトは`data/`から読み込み、`figures/`に書き出します。
   前処理（ベースライン補正、バックグラウンド除去など）が必要な場合は、
   再現性のためにスクリプト内で行ってください。

6. **eLabFTWはラボノートです。**
   `log_to_elab()`で解析結果を記録します。タグはJASCOファイルヘッダと
   `load_raman`/`load_ftir`に渡したメタデータから自動生成されます。
   eLabFTWのエントリが正式な記録です。解析フォルダは作業スペースです。

## フォルダの命名規則

単語間はアンダースコアで区切ります。短くても他の解析と区別できる名前にしてください。

良い例：
```
MoSe2_A1g/
ZIF62_crystal_Co/
NH4SCN_CN_stretch/
DMF_reference/
```

悪い例：
```
analysis1/
test/
new_analysis/
20260212_MoSe2/
MoSe2_A1g_v2_final_FINAL/
```

## ワークフロー

解析には探索と仕上げの2つのフェーズがあります。

### 探索（`scratch/`）

新しいデータを見るときは、`scratch/`で使い捨てのスクリプトを書きましょう。
ルールも構成もなし — データを読み込んで中身を確認するだけです。

```julia
# scratch/look_at_new_sample.jl
using QPSTools, GLMakie

spec = load_raman("data/raman/MoSe2_center.csv"; material="MoSe2")
fig, ax = plot_raman(spec)
DataInspector()  # プロット上にマウスを置くと値が表示される

peaks = find_peaks(spec)
println(peak_table(peaks))
```

REPLで対話的に実行（`include("scratch/look_at_new_sample.jl")`）するか、
VS Codeで1行ずつ実行します。`GLMakie`を使えばズーム、パン、そして
`DataInspector()`でマウスホバーによる値の読み取り（ピーク位置、強度、
ピクセル番号など）ができます。

`scratch/`内のファイルはいつでも削除して構いません。

### 仕上げ（`analyses/`）

何を解析するか決まったら、解析フォルダを作ります：

```
1. フォルダ作成       mkdir -p analyses/MoSe2_A1g
2. テンプレートコピー  cp templates/raman_analysis.jl analyses/MoSe2_A1g/analysis.jl
3. スクリプト編集     （ファイルパス、メタデータ、フィット領域などを変更）
4. 実行              julia --project=. analyses/MoSe2_A1g/analysis.jl
5. 図の確認          （figures/を開いて出力を確認）
6. 繰り返し          （パラメータ調整、再実行）
7. eLabFTWに記録     （満足したらlog_to_elabブロックのコメントを外す）
```

またはREPLから（GLMakieで対話的に確認したいとき）：

```julia
julia --project=.
julia> include("analyses/MoSe2_A1g/analysis.jl")
```

### 論文用図（`manuscript/`）

論文の図を組み立てるときは`manuscript/`を使います。個々の解析出力を
複合マルチパネル図にまとめる場所です。

```julia
# manuscript/figure1.jl
using QPSTools, CairoMakie

set_theme!(print_theme())
fig = Figure(size=(1200, 400))

# (a) PLマップ — 解析の結果を読み込む
# (b) ラマンスペクトル — 別の解析から読み込む
# (c) 別のパネル

save("manuscript/figure1.pdf", fig)
```

各解析フォルダがそれぞれ論文品質の図を出力します。`manuscript/`は
それらを論文用の複合レイアウトにまとめるためだけのフォルダです。

## 新しいフォルダを作るか、その場で編集するか

**その場で編集する場合**（同じ解析の改善）：
- フィット領域の境界を変更する
- ピークモデルを変える（ガウシアン vs ローレンツィアン）
- プロットの書式を調整する

**新しいフォルダを作る場合**（解析対象が変わる）：
- 同じスペクトルの別のピークをフィットする
- 2つの異なるサンプルを比較する
- 根本的に異なる解析アプローチ（例：ベースライン補正の検討）

## 過去の結果の検索

eLabFTWは過去の解析を検索するためのクエリレイヤーです。
タグはJASCOの種類と`load_raman`/`load_ftir`に渡したkwargsから自動生成されます：

```julia
# 全てのラマン解析を検索
search_experiments(tags=["raman"])

# MoSe2の全ての研究を検索
search_experiments(tags=["MoSe2"])

# タイトルと本文の全文検索
search_experiments(query="A1g peak fit")

# 最近の実験
list_experiments(limit=10)
```

## eLabFTWへの記録

解析が完了したら、結果をeLabFTWに記録します。
自動プロベナンス形式がJASCOヘッダからタグとソース情報を自動抽出します：

```julia
log_to_elab(spec, result;
    title = "Raman: MoSe2 A1g peak fit",
    attachments = [joinpath(FIGDIR, "context.png")],
    extra_tags = ["a1g"]
)
```

スクリプトを再実行すると同じ実験が更新されます（`.elab_id`ファイルによる冪等性）。

## 実用的なヒント

### フィット領域の選び方（ラマン / FTIR）

まず`find_peaks`と`peak_table`を実行します。テーブルにピーク中心位置が表示されるので、
フィットしたいピークを囲む範囲`(lo, hi)`を選びます。

```julia
peaks = find_peaks(spec)
println(peak_table(peaks))
# ピーク中心が表示される（例: 2054.3 cm⁻¹）
# → そのピークを囲む (1950, 2150) を選ぶ
result = fit_peaks(spec, (1950, 2150))
```

### PLマッピング: ピクセル範囲の選び方

CCDラスタースキャンは各空間点でフルスペクトルを記録します。スペクトルには
レーザー散乱、PL発光、ラマンピーク、検出器ノイズが全て含まれています。
意味のあるPLマップを作るには、**スペクトル窓掛け**でPLピークだけを取り出す
必要があります：PLシグナルを含むピクセルのみを積分します。

テンプレート（`templates/plmap_analysis.jl`）は以下の流れです：

1. **スペクトル確認** — 数箇所の位置で生CCDスペクトルをプロット
   （`spectra.pdf`）。PL発光を探します — 通常最も広いピークです。
   レーザー散乱は鋭く、ラマンピークは狭い。

2. **`PIXEL_RANGE`を設定** — PLピークを囲むピクセル範囲をメモし、
   スクリプト上部の変数を更新：
   ```julia
   PIXEL_RANGE = (950, 1100)  # PLピークを含むピクセル範囲
   ```

3. **バックグラウンド差し引き** — フレーク外（PLなし）の角のスペクトルを
   平均して全グリッド点から差し引き、レーザー散乱とノイズを除去。
   確認用プロット（`spectra_corrected.pdf`）で補正後のスペクトルを表示
   — PLピークがフラットなベースライン上にあるはず。

4. **スペクトル窓掛け** — 各グリッド点で`PIXEL_RANGE`内のカウントを合計し、
   PL強度を1つの値として取得。窓の外にあるもの（レーザー、ラマン）は無視。

出力図には積分窓をハイライトしたスペクトルとPLマップが並んで表示されます。

### `format_results`の出力

`format_results(result)`はMarkdown文字列を返します：

```
Peak Fit Results
| Parameter | Peak 1   |
|-----------|----------|
| center    | 2054.3   |
| fwhm      | 22.1     |
| amplitude | 0.83     |
| R²        | 0.9987   |
```

この文字列が`log_to_elab`でeLabFTWに記録されます。

### 常にプロジェクトルートから実行する

全てのコマンドはプロジェクトルート（`Project.toml`がある場所）にいることを前提としています。
`--project=.`でJuliaがインストール済みパッケージを見つけます：

```bash
julia --project=. analyses/MoSe2_A1g/analysis.jl    # ターミナル
julia --project=. scratch/quick_look.jl              # scratchスクリプトも同様
```

またはREPLを起動して`include()`でスクリプトを読み込みます：

```julia
julia --project=.
julia> include("analyses/MoSe2_A1g/analysis.jl")
julia> include("scratch/quick_look.jl")
```

### プロット関数の戻り値

プロット関数はレイアウトに応じて異なるタプルを返します：

```julia
fig, ax                          = plot_ftir(spec)                              # 全体像
fig, ax, ax_res                  = plot_ftir(spec; fit=r, residuals=true)       # 二段
fig, ax_ctx, ax_fit, ax_res      = plot_ftir(spec; fit=r, context=true)         # 三面図
```

分割代入で必要なものだけ受け取れます。図だけ欲しい場合は
`fig, _ = plot_ftir(spec)`のように軸を無視できます。

### PNGとPDF

試行錯誤中はPNG（`.png`）を使います — 高速でプレビューしやすいです。
論文用の図にはPDF（`.pdf`）に切り替えます — ベクター画像なので
拡大してもピクセルが見えません。
