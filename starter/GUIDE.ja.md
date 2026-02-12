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

6. **レジストリはデータカタログ。**
   すべてのデータファイルを`data/registry.json`に登録してください。
   これにより、ファイルパスではなくメタデータでデータを読み込めます
   （`load_raman(material="MoSe2")`）。スクリプトの可搬性と可読性が向上します。

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

## レジストリの書き方

各サンプルにユニークなIDとメタデータを設定します。
`path`フィールドは`data/`からの相対パスです。

```json
{
  "raman": {
    "MoSe2_center": {
      "sample": "center",
      "material": "MoSe2",
      "laser_nm": 532.05,
      "objective": "100x",
      "path": "raman/MoSe2_center.csv",
      "date": "2026-01-20"
    }
  }
}
```

ポイント：
- エントリ間でフィールド名を統一する（`laser`と`laser_nm`を混在させない）
- スペクトルに影響する測定パラメータを含める（レーザー出力、露光時間、グレーティングなど）
- `date`フィールドはデータの取得日を記録する（解析日ではない）

## ワークフロー

解析には探索と仕上げの2つのフェーズがあります。

### 探索（`scratch/`）

新しいデータを見るときは、`scratch/`で使い捨てのスクリプトを書きましょう。
ルールも構成もなし — データを読み込んで中身を確認するだけです。

```julia
# scratch/look_at_new_sample.jl
using QPSTools, GLMakie
set_data_dir(joinpath(dirname(@__DIR__), "data"))

spec = load_raman(sample="spot1", material="MySample")
fig, ax = plot_raman(spec)

peaks = find_peaks(spec)
println(peak_table(peaks))
```

REPLで対話的に実行（`include("scratch/look_at_new_sample.jl")`）するか、
VS Codeで1行ずつ実行します。`GLMakie`を使えばズームやパンができます。

`scratch/`内のファイルはいつでも削除して構いません。

### 仕上げ（`analyses/`）

何を解析するか決まったら、解析フォルダを作ります：

```
1. フォルダ作成       mkdir -p analyses/MoSe2_A1g
2. テンプレートコピー  cp templates/raman_analysis.jl analyses/MoSe2_A1g/analysis.jl
3. スクリプト編集     （サンプル名、フィット領域などを変更）
4. 実行              julia --project=../.. analyses/MoSe2_A1g/analysis.jl
5. 図の確認          （figures/を開いて出力を確認）
6. 繰り返し          （パラメータ調整、再実行）
7. eLabFTWに記録     （満足したらlog_to_elabブロックのコメントを外す）
```

## 新しいフォルダを作るか、その場で編集するか

**その場で編集する場合**（同じ解析の改善）：
- フィット領域の境界を変更する
- ピークモデルを変える（ガウシアン vs ローレンツィアン）
- プロットの書式を調整する

**新しいフォルダを作る場合**（解析対象が変わる）：
- 同じスペクトルの別のピークをフィットする
- 2つの異なるサンプルを比較する
- 根本的に異なる解析アプローチ（例：ベースライン補正の検討）

## eLabFTWへの記録

解析が完了したら、結果をeLabFTWに記録します。
図が添付された検索可能な記録が作成されます。
スクリプトの末尾に`log_to_elab`ブロックを追加してください：

```julia
log_to_elab(
    title = "Raman: MoSe2 A1g peak fit",
    body = format_results(result),
    attachments = [joinpath(FIGDIR, "context.png")],
    tags = ["raman", "mose2", "a1g"]
)
```

eLabFTWのエントリが正式な記録になります。解析フォルダは作業スペースです。
論文で引用したり共同研究者と共有するのはノートのエントリです。
