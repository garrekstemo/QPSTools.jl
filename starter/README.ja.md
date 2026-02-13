[English](README.en.md) | [日本語](README.ja.md)

# 解析スターター

QPSTools.jlを使った新しい解析プロジェクトのテンプレートです。

## セットアップ

1. このフォルダを自分の場所にコピーしてリネームしてください：
   ```
   cp -r starter/ ~/Documents/projects/my-raman-project/
   ```

2. 初回セットアップを実行してパッケージをインストールします：
   ```
   cd ~/Documents/projects/my-raman-project/
   julia --project=. setup.jl
   ```

3. データファイルを`data/raman/`（または`data/ftir/`、`data/PLmap/`など）に追加してください。

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

スクリプトを編集（ファイルパスとメタデータを変更）して実行します。

**ターミナルから**（プロジェクトルートで実行）：

```bash
julia --project=. analyses/MoSe2_A1g/analysis.jl
```

**Julia REPLから**（プロジェクトルートでJuliaを起動）：

```bash
julia --project=.
```

```julia
julia> include("analyses/MoSe2_A1g/analysis.jl")
```

## フォルダ構成

```
my-project/
├── Project.toml              # Julia環境（手動で編集しないこと）
├── setup.jl                  # 初回セットアップ用（実行後は削除可能）
├── data/
│   ├── raman/                # JASCOの生データ（.csvファイル）
│   ├── ftir/                 # FTIRの.csvファイル
│   └── PLmap/                # CCDラスタースキャンの.lvmファイル
├── scratch/                  # 探索用 — 自由に使える作業スペース
├── manuscript/               # 論文用の複合図
├── templates/                # テンプレート — コピーして使う（直接編集しない）
│   ├── raman_analysis.jl
│   ├── ftir_analysis.jl
│   └── plmap_analysis.jl
└── analyses/                 # 完成した解析はここに保存
    └── MoSe2_A1g/
        ├── analysis.jl
        ├── .elab_id          # log_to_elabが自動作成（gitignore対象）
        └── figures/
```

## データの読み込み

QPSToolsはファイルパスでデータを読み込みます。オプションのキーワード引数で
表示やeLabFTWタグ付けに使うメタデータを追加できます：

```julia
spec = load_raman("data/raman/MoSe2_center.csv"; material="MoSe2", sample="center")
spec = load_ftir("data/ftir/1.0M_NH4SCN_DMF.csv"; solute="NH4SCN", concentration="1.0M")
m = load_pl_map("data/PLmap/my_scan.lvm"; step_size=2.16)
```

## eLabFTWのセットアップ

結果をラボノートに記録するには、環境変数を設定してください（`~/.zshrc`に追加）：

```bash
export ELABFTW_URL="https://your-instance.elabftw.net"
export ELABFTW_API_KEY="your-api-key"
```

接続を確認：

```julia
using QPSTools
test_connection()
```

詳しくはQPSToolsのサンプルを参照してください：`QPSTools.jl/examples/`
