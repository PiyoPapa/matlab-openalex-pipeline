# matlab-openalex-pipeline
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-pipeline)

This repository provides a MATLAB-based acquisition layer for the OpenAlex Works API.
It focuses on reproducible, cursor-based bulk data collection and explicit file output.
Downstream normalization and analysis are intentionally handled in separate repositories.
 
> **Version note**
>
> The behavior described below reflects the implementation as of the current `v0.x` line.
> Minor releases may extend examples or options without changing the core design intent.

> **Compatibility note**
>
> This repo writes a high-throughput JSONL format (**array-per-line JSONL**: 1 line = 1 API response array).
> If you want to run `matlab-openalex-normalize`, convert to **standard JSONL** (1 Work per line) first using
> `openalex_write_jsonl` (provided in this repository).

Downstream / related projects:
- **Normalization (fixed-schema CSVs):**
  [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)
- **Topic mapping / semantic exploration (Text Analytics / DL):**
  [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)
- **Citation graphs / reference edges (advanced users):**
  `matlab-openalex-edges` (separate repository; advanced / not part of this repo)

## Overview
- **Who this is for:**  
  Professionals whose primary responsibilities lie outside text analytics, yet who need
  reproducible, time-bounded exploratory access to research metadata for decision-making.
- **What problem this addresses:**  
  Reliable bulk acquisition of OpenAlex Works data in environments where Python/R tooling
  is undesirable or unavailable.
- **What layer this repository represents:**  
  The acquisition layer in a multi-stage OpenAlex–MATLAB workflow.

## What this repository provides (and what it doesn't)

- **Provides:**
  - Cursor-based pagination for the OpenAlex Works API  
    (avoids the 10,000-record limit of page-based pagination)
  - Safe resume mechanism using a lightweight `.mat` checkpoint
  - Append-only JSONL output for reproducible runs
  - MATLAB-only implementation (no Python/R dependencies)
- **Does NOT provide:**
  - Downstream analysis or visualization
  - Record normalization or deduplication
  - A general-purpose OpenAlex SDK
---

## Repository position in the OpenAlex–MATLAB workflow
This repository is part of a three-stage workflow for analyzing OpenAlex data in MATLAB.
 
1. **Acquisition** — fetch OpenAlex Works reliably (**this repository**)
2. **Normalization** — fixed-schema, versioned CSVs  
   → [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)
3. **Analysis / topic mapping** — clustering, diagnostics, semantic maps  
   → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)
4. **Advanced analysis** — citation graphs, large-scale networks (separate repositories)

## Scope and design principles
This repository is intentionally narrow in scope.
It prioritizes explicit data handling, reproducibility, and diagnostic clarity over
automation or convenience. Advanced analytics, optimization, and production deployment
are explicitly out of scope.
These choices are deliberate and may differ from typical "quick scripts".

---

## Repository layout

```text
 matlab-openalex-pipeline/
 ├─ src/                # Library functions
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

## Intended use
This repository is intended for short-lived, reproducible acquisition runs
where explicit control over queries, cursors, and outputs is required.
It is designed to support exploratory or decision-oriented analysis workflows
that build on exported files in downstream projects, rather than to function
as a persistent data platform or general-purpose API client.

## Relationship to other repositories
This repository deliberately handles only the acquisition of OpenAlex Works data.
Schema stabilization, transformation into analysis-ready tables, and any form of
semantic analysis or visualization are expected to occur in separate repositories
or project layers, according to the OpenAlex–MATLAB workflow described above.

## Disclaimer
The author is an employee of MathWorks Japan.
This repository is a personal experimental project developed independently
and is not part of any MathWorks product, service, or official content.

MathWorks does not review, endorse, support, or maintain this repository.
All opinions and implementations are solely those of the author.

## License
MIT License. See the LICENSE file for details.

## A note for contributors
This repository prioritizes:
- clarity over abstraction
- reproducibility over convenience
- explicit configuration over magic defaults

## Contact
This project is maintained on a best-effort basis and does not provide official support.

For bug reports or feature requests, please use GitHub Issues.
If you plan to extend it, please preserve the principles stated above.
