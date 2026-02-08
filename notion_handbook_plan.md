# QPS.jl Lab Handbook — Notion Setup Plan

## Context

With spectroscopy-specific functions moving to SpectroscopyTools.jl (public, Documenter.jl docs), QPS.jl documentation becomes a **lab handbook**: onboarding, workflows, conventions, and eLabFTW integration. Notion is the platform. Content must be fully bilingual (English and Japanese) since the lab has ~3–4 English speakers and ~10 Japanese speakers.

## Workspace Setup

Use the existing Notion workspace. Create a top-level **Lab Handbook** page shared with all lab members. No need for a separate workspace.

- Share with lab members via email
- **Can edit** for students who contribute content
- **Can view** for everyone else

## Page Structure

Two parallel trees — one English, one Japanese — with identical structure and content. Pin both to the sidebar.

```
Lab Handbook
├── 🇬🇧 English
│   ├── Getting Started
│   │   ├── Julia Environment Setup
│   │   ├── QPS.jl Installation
│   │   └── eLabFTW Account Setup
│   ├── Data Conventions
│   │   ├── File Naming
│   │   ├── Folder Structure
│   │   └── Registry System
│   ├── Workflows
│   │   ├── FTIR Analysis
│   │   ├── Raman Analysis
│   │   ├── Pump-Probe Analysis
│   │   └── Logging Results to eLabFTW
│   ├── For New Students
│   │   └── First Week Checklist
│   └── SpectroscopyTools.jl Docs → (external link)
│
├── 🇯🇵 日本語
│   ├── はじめに
│   │   ├── Julia環境構築
│   │   ├── QPS.jlのインストール
│   │   └── eLabFTWアカウント設定
│   ├── データ規則
│   │   ├── ファイル命名規則
│   │   ├── フォルダ構成
│   │   └── レジストリシステム
│   ├── ワークフロー
│   │   ├── FTIR解析
│   │   ├── ラマン解析
│   │   ├── ポンプ-プローブ解析
│   │   └── eLabFTWへの結果記録
│   ├── 新入生向け
│   │   └── 初週チェックリスト
│   └── SpectroscopyTools.jlドキュメント → (外部リンク)
```

## Bilingual Maintenance

- Write in your stronger language first, then translate.
- Keep pages short and focused — a 5-paragraph page stays in sync easily; a 20-paragraph page drifts.
- Add a **Last updated** date at the top of each page. When one language is updated, the other shows a stale date.
- Code blocks (Julia snippets) are identical in both trees — copy-paste verbatim.

## Notion Features to Use

| Feature | Use for |
|---------|---------|
| `/code` blocks | Julia snippets (select "Julia" for syntax highlighting) |
| `/callout` blocks | Warnings, tips, important notes |
| `/table` databases | Instrument registry, sample registry, data format reference |
| Inline links | Link to SpectroscopyTools.jl public docs for API details |
| Page icons | Distinguish section types visually |

## What to Do First

1. Create the **Lab Handbook** top-level page
2. Create the 🇬🇧 / 🇯🇵 sub-pages
3. Write **Getting Started / はじめに** first (Julia setup, QPS.jl install, eLabFTW account)
4. Share with one student, get feedback on format
5. Add remaining pages incrementally

## Relationship to SpectroscopyTools.jl

| Content | Where it lives |
|---------|---------------|
| Spectroscopy API reference (fit_peaks, find_peaks, baseline, etc.) | SpectroscopyTools.jl public docs (Documenter.jl) |
| Lab workflows (how to go from raw data to publication) | Notion handbook |
| eLabFTW integration, data conventions, onboarding | Notion handbook |
| Theory and background (fitting statistics, baseline algorithms) | SpectroscopyTools.jl public docs |
