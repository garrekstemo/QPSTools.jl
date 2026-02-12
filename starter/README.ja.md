[English](README.en.md) | [日本語](README.ja.md)

# 解析スターター

QPSTools.jlを使った新しい解析プロジェクトのテンプレートです。

## セットアップ

1. この`starter/`フォルダを自分の場所にコピーしてリネームしてください：
   ```
   cp -r starter/ ~/Documents/projects/my-raman-project/
   ```

2. 初回セットアップを実行してQPSToolsをリンクします（必要に応じて`setup.jl`内のパスを編集）：
   ```
   cd ~/Documents/projects/my-raman-project/
   julia --project=. setup.jl
   ```

3. データファイルを`data/raman/`に追加し、`data/registry.json`に登録してください。

## 使い方

各解析は`analyses/`の下にサンプル名や対象ごとのフォルダとして保存します：

```
analyses/
  MoSe2_A1g/
    analysis.jl
    figures/
  ZIF62_crystal_Co/
    analysis.jl
    figures/
```

新しい解析を始めるには：

```bash
mkdir -p analyses/MoSe2_A1g
cp templates/raman_analysis.jl analyses/MoSe2_A1g/analysis.jl
```

スクリプトを編集して実行します：

```bash
julia --project=../.. analyses/MoSe2_A1g/analysis.jl
```

## フォルダ構成

```
my-project/
├── Project.toml              # Julia環境（手動で編集しないこと）
├── setup.jl                  # 初回セットアップ用（実行後は削除可）
├── data/
│   ├── registry.json         # サンプルのメタデータ — QPSToolsが参照します
│   └── raman/                # JASCOの生データ（.csvファイル）
├── scratch/                  # 探索用 — 自由に使える作業スペース
├── templates/                # テンプレート — コピーして使う（直接編集しない）
│   ├── raman_analysis.jl
│   └── ftir_analysis.jl
└── analyses/                 # 完成した解析はここに保存
    └── MoSe2_A1g/
        ├── analysis.jl
        └── figures/
```

## レジストリ

QPSToolsは`data/registry.json`を通してデータを検索します。
各エントリはサンプルIDをメタデータとファイルパスに対応付けます：

```json
{
  "raman": {
    "my_sample_1": {
      "sample": "spot1",
      "material": "MySample",
      "laser_nm": 532.05,
      "path": "raman/my_sample_spot1.csv"
    }
  }
}
```

メタデータで読み込みます：

```julia
spec = load_raman(sample="spot1", material="MySample")
```

詳しくはQPSToolsのサンプルを参照してください：`QPSTools.jl/examples/raman_analysis.jl`
