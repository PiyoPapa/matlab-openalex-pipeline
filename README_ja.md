# matlab-openalex-pipeline
**Language:** [English](README.md) | 日本語

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-pipeline)

本リポジトリは、OpenAlex Works API のための **MATLAB 専用データ取得レイヤー**です。
**再現性があり、時間的に区切られた一括データ取得**を目的として設計されており、
解析や可視化を目的としたものではありません。

**OpenAlex Works メタデータを取得・保存すること**が目的であれば、ここで止めてください。
**正規化されたテーブルや探索的解析が必要な場合のみ**、次の段階へ進んでください。

> **互換性に関する注意**
>
> 本リポジトリは、高スループットな JSONL 形式
>（**array-per-line JSONL**: 1 行 = 1 API レスポンス配列）を書き出します。
> `matlab-openalex-normalize` を実行したい場合は、
> 本リポジトリに含まれる `openalex_write_jsonl` を使用して、
> **標準 JSONL**（1 行 = 1 Work）へ事前に変換してください。

下流／関連プロジェクト:
- **正規化（固定スキーマ・バージョン管理 CSV）**:
  [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)
- **解析／診断（探索的トピックマッピング、セマンティック確認）**:
  [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)

## Overview

本リポジトリは、OpenAlex Works メタデータを
**再現性があり、時間的に区切られた形**で収集するための
**MATLAB 専用データ取得レイヤー**を提供します。

**本リポジトリが提供するもの**
- OpenAlex Works API に対するカーソルベースのページネーション
- 再開可能なチェックポイントを備えた、追記専用 JSONL 出力
- クエリ、カーソル、出力ファイルに対する明示的な制御

**本リポジトリが提供しないもの**
- 正規化、重複除去、解析
- 可視化やレポーティング
- 汎用的な OpenAlex SDK

## Repository position in the OpenAlex–MATLAB workflow
本リポジトリは、3 段階からなるワークフローの一部です。

1. **Acquisition** — OpenAlex Works を確実に取得（**本リポジトリ**）
2. **Normalization** — 固定スキーマ・バージョン管理 CSV  
   → [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)
3. **Analysis / diagnostics** — 探索的確認およびトピックマッピング  
   → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)

## Who this repository is for / not for

本リポジトリは、以下のユーザーを対象としています。
- MATLAB で OpenAlex Works メタデータを **明示的かつ再現可能に取得**したいユーザー
- Python や R を使わずに、**クエリ・カーソル・出力ファイルを完全に制御**したいユーザー

本リポジトリは、以下の用途を想定していません。
- 解析や可視化ツールを探しているユーザー
- 完全に抽象化された OpenAlex SDK を期待するユーザー

## Scope and non-goals

本リポジトリは、**データ取得のみにスコープを限定**しています。
高度な解析、最適化、可視化、プロダクション配備は、明示的に対象外です。

設計は、利便性や抽象化よりも
**透明性と再現性**を優先しています。

---

## Repository layout

```text
  matlab-openalex-pipeline/
  ├─ src/                # Library functions
  │  ├─ oa_bootstrap.m
  │  ├─ oa_peek_count.m
  │  ├─ oa_run_openalex.m
  │  ├─ openalex_export_csv.m
  │  ├─ openalex_fetch_works.m
  │  ├─ openalex_read_jsonl.m
  │  └─ openalex_write_jsonl.m
  ├─ examples/           # Runnable demos
  │  └─ demo_fetch_example.m
  ├─ data/               # Local outputs (gitignored)
  ├─ docs/               # Optional documentation
  └─ README.md
```

## Input / Output
- Input: OpenAlex Works API クエリおよび任意の再開用チェックポイント
- Output: 追記専用 JSONL ファイルおよび軽量な .mat カーソルチェックポイント

## Optional: クエリ制御（そのまま渡す）
フロントの `oa_run_openalex` は、OpenAlex 形式の文字列を受け取り、fetcher にそのまま渡します。

- `type`: `"article"` または `"type:article"`（どちらも可）
- `sort`: OpenAlex の sort 文字列（例：`"publication_date:desc"`）
- `select`（fetch のみ）: 返却フィールドを絞るための指定。`[]` または `""` で `select` を省略し、
  API のデフォルトレスポンスを取得します。`oa_peek_count` は **count-only** のため `select` は渡さないでください。

## Demos / Examples
> **MATLAB Online ユーザー向け**
>  
> 上記ボタンを使用して、本リポジトリを MATLAB Online で直接開くことができます。  
> 出力ファイルは MATLAB Online セッション内に保存され、手動でダウンロード可能です。

1. 本リポジトリをクローンします。
2. MATLAB を起動します。
3. サンプルスクリプトを実行します。
```matlab
run("examples/demo_fetch_example.m")
```

これにより（**データ取得のみ**）以下が行われます。
 - `src/` を MATLAB パスに追加
 - サンプルクエリに対する OpenAlex Works メタデータの取得
 - 出力を `./data/` に書き込み

## When to stop here / when to move on

以下の場合は、ここで止めてください。
- 目的が OpenAlex Works データの **取得およびアーカイブ**である場合
- 必要な JSONL 出力をすでに取得している場合

以下が必要な場合のみ、次へ進んでください。
- 固定スキーマ・バージョン管理 CSV が必要な場合  
  → [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)
- 探索的トピックマッピングやセマンティック確認を行いたい場合  
  → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)

## Disclaimer
著者は MathWorks Japan の従業員です。
本リポジトリは、個人的かつ独立した実験プロジェクトとして開発されたものであり、
MathWorks の製品、サービス、公式コンテンツの一部ではありません。

MathWorks は、本リポジトリをレビュー、保証、サポート、保守することはありません。
すべての見解および実装は、著者個人のものです。

## License
MIT License。詳細は LICENSE ファイルを参照してください。

## Notes
本プロジェクトはベストエフォートで維持されており、公式なサポートは提供されません。
バグ報告については、GitHub Issues を使用してください。
