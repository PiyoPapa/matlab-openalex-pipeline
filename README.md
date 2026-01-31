# matlab-openalex-pipeline
**Language:** English | [日本語](README_ja.md)

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-pipeline)

This repository is a **MATLAB-only acquisition layer** for the OpenAlex Works API.
It is designed for **reproducible, time-bounded bulk data collection** — not for analysis or visualization.

**You should stop here if** your goal is to fetch and archive OpenAlex Works metadata.
**You should move on** only if you need normalized tables or exploratory analysis.

> **Compatibility note**
>
> This repo writes a high-throughput JSONL format (**array-per-line JSONL**: 1 line = 1 API response array).
> If you want to run `matlab-openalex-normalize`, convert to **standard JSONL** (1 Work per line) first using
> `openalex_write_jsonl` (provided in this repository).

Downstream / related projects:
- **Normalization (fixed-schema, versioned CSVs):**
  [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)
- **Analysis / diagnostics (exploratory topic mapping, semantic inspection):**
  [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)
 
## Overview

This repository provides a **MATLAB-only acquisition layer** for collecting
OpenAlex Works metadata in a **reproducible, time-bounded manner**.

**What this repository provides**
- Cursor-based pagination for the OpenAlex Works API
- Append-only JSONL output with resumable checkpoints
- Explicit control over queries, cursors, and output files

**What this repository does NOT provide**
- Normalization, deduplication, or analysis
- Visualization or reporting
- A general-purpose OpenAlex SDK

## Repository position in the OpenAlex–MATLAB workflow
This repository is part of a three-stage workflow:

1. **Acquisition** — fetch OpenAlex Works reliably (**this repository**)
2. **Normalization** — fixed-schema, versioned CSVs  
   → [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)
3. **Analysis / diagnostics** — exploratory inspection and topic mapping  
   → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)

## Who this repository is for / not for

This repository is for:
- Users who need **explicit, reproducible acquisition** of OpenAlex Works metadata in MATLAB
- Users who want **full control over queries, cursors, and output files** without Python/R

This repository is NOT for:
- Users looking for an analysis or visualization tool
- Users expecting a fully abstracted OpenAlex SDK

## Scope and non-goals

This repository intentionally limits its scope to **data acquisition only**.
Advanced analytics, optimization, visualization, and production deployment are explicitly out of scope.

The design favors **transparency and reproducibility** over convenience or abstraction. 

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
- Input: OpenAlex Works API queries and optional resume checkpoints
- Output: Append-only JSONL files and lightweight .mat cursor checkpoints

## Optional query controls (passed through)
The front runner `oa_run_openalex` accepts OpenAlex-style strings and passes them through to the fetcher.

- `type`: either `"article"` or `"type:article"` (both are accepted)
- `sort`: OpenAlex sort string (e.g., `"publication_date:desc"`)
- `select` (fetch-only): list of fields to return. Use `[]` or `""` to skip `select`
  (i.e., request the API default response). `oa_peek_count` is **count-only**; do **not** pass `select` to it.

### Optional: filter by institution
You can filter Works by **author affiliation** using an OpenAlex Institution ID.

- `institutionId`: OpenAlex Institution ID (e.g., `"I123456789"`)
- Internally translated to `authorships.institutions.id:<ID>` and passed to the Works API filter.

## Demos / Examples
> **MATLAB Online users**  
> This repository can be opened directly in MATLAB Online using the button above.  
> Output files will be saved within the MATLAB Online session and can be downloaded manually.

1. Clone this repository. 
2. Open MATLAB. 
3. Run the example script:
```matlab
run("examples/demo_fetch_example.m")
```

This will (data acquisition only):
 - Add `src/` to the MATLAB path
 - Fetch OpenAlex Works metadata for a sample query
 - Write outputs to `./data/`

## When to stop here / when to move on

Stop here if:
- Your goal is **acquisition and archival** of OpenAlex Works data
- You already have the JSONL output you need

Move on only if:
- You need fixed-schema, versioned CSVs  
  → [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)
- You want exploratory topic mapping or semantic inspection  
  → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)

## Disclaimer
The author is an employee of MathWorks Japan.
This repository is a personal experimental project developed independently
and is not part of any MathWorks product, service, or official content.

MathWorks does not review, endorse, support, or maintain this repository.
All opinions and implementations are solely those of the author.

## License
MIT License. See the LICENSE file for details.

## Notes
This project is maintained on a best-effort basis and does not provide official support.
For bug reports, please use GitHub Issues.