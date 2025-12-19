# matlab-openalex-pipeline
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-pipeline)

This repository provides a MATLAB-based pipeline for the OpenAlex API (Works endpoint).
It enables cursor-based bulk data harvesting, JSONL storage, and reproducible runs without Python.

Use this when you want **reproducible bulk collection in MATLAB**.
If you want analysis/visualization, build it **on top of the exported files**.

If you want **versioned, analysis-ready CSVs**, use
[`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize).

## What this repository provides (and what it doesn't)

- Cursor-based pagination for the OpenAlex Works API  
  (avoids the 10,000-record limit of page-based pagination)
- Safe resume mechanism using a lightweight `.mat` checkpoint
- High-throughput output via append-only JSONL
- MATLAB-only implementation (no Python/R dependencies)

**Non-goals (intentional):**
- No downstream analysis/visualization
- No record normalization/deduplication
- Not a full OpenAlex SDK replacement

This repository is intentionally narrow: **fetch Works reliably, resume safely, write fast**.
Anything else belongs in a separate repo or your own project layer.
---

## Design principles (important)

This repository intentionally follows these rules:

1. **No implicit project structure assumptions**
   - Library functions do not assume where the repository is located.
   - Output locations must be specified by the caller.

2. **Separation of concerns**
   - `src/` contains reusable library functions.
   - `examples/` contains runnable demo scripts.
   - Generated data is written to `data/` and never committed.

3. **I/O efficiency over convenience**
   - Results are written as JSONL with one line per API request
     (each line is a JSON array, not a single record).
   - In-memory accumulation is optional and disabled by default.

These choices are deliberate and may differ from typical "quick scripts".

---

## Requirements

- MATLAB (recent versions recommended)
- Internet access

No additional toolbox is required under typical conditions
(`webread` is used for HTTP requests).

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

## Quick start
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

* * *
## FAQ

### Is this an OpenAlex API client / SDK?
No. This repo is a narrow, streaming-first **OpenAlex API** fetch layer focused on bulk acquisition of **Works**.
It intentionally does not aim to cover every OpenAlex endpoint or provide a high-level SDK experience.

### Which OpenAlex endpoints are supported?
v0.x targets the **Works** endpoint for scalable metadata harvesting.
If you need normalized tables (works/authorships/concepts/sources...), fetch Works first and use the separate normalization layer:
`matlab-openalex-normalize`.

### Do I need Python or R?
No. The core fetch/resume/JSONL output is MATLAB-only (uses `webread`).

### Why is the JSONL format “array-per-line”?
For I/O efficiency: one API response (typically ~200 Works) is written as one JSON array per line.
This reduces write overhead and makes request-level bookkeeping easier.
If you need interoperability, convert to standard JSONL (1 Work per line) before downstream tooling.

### How do I convert to standard JSONL (1 Work per line)?
Use the provided helper:

    inJsonl  = "data/openalex_....jsonl";
    outJsonl = "data/openalex_....standard.jsonl";
    n = openalex_write_jsonl(inJsonl, outJsonl);

### How does resume work?
If the checkpoint `.mat` exists, the fetcher resumes from the last saved cursor.
To prevent accidental corruption, it performs basic compatibility checks (query/perPage/filters).
If those inputs differ, it stops with an error.

### How should I handle rate limits / polite pool (mailto)?
You are responsible for pacing requests according to OpenAlex policies.
For large-scale requests, provide a contact email via `mailto` (polite pool). This repo supports an optional `mailto`
parameter and the example reads `OPENALEX_MAILTO` from the environment.

### Can I fetch authors/sources/institutions directly?
Not in the core scope right now. The intended flow is:
fetch Works reliably → export/convert → normalize/analyze in a separate layer or your own project.

## Output files
### Checkpoint file (`.mat`)

Example:
```text
data/openalex_MATLAB_cursor_en_100000.mat
```

This file contains:
- Cursor state
- Request counters
- Minimal metadata required for resuming

It is intentionally small and frequently overwritten.

### Results file (.jsonl)
Example:
```text
data/openalex_MATLAB_cursor_en_100000.jsonl
```
This file is append-only and can grow large.

### JSONL format (read carefully)
This repository uses a non-standard but intentional JSONL format:
- 1 line = JSON array of OpenAlex Works objects
- Typically ~200 records per line (per API request)

This is done for:
- Faster writes
- Lower file I/O overhead
- Easier correlation with request-level metadata

This differs from the common "1 record per line" JSONL convention.
If your goal is to normalize Works into **fixed-schema CSVs** (e.g., works/authorships/concepts),
convert to **standard JSONL (1 Work per line)** and then run
[`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize).

## Reading JSONL results back into MATLAB
Use the provided helper:
```matlab
results = openalex_read_jsonl("data/openalex_....jsonl");
```

Options:
```matlab
results = openalex_read_jsonl( ...
    "data/openalex_....jsonl", ...
    "maxRecords", 50000, ...
    "verbose", true);
```

## Exports (Priority A)
This repository writes a high-throughput JSONL format where 1 line = an array of Works
(one API response per line). This is intentional for I/O efficiency.

If you need more interoperable formats:

### Standard JSONL (1 record per line)
Convert the repository JSONL to a standard "1 Work per line" JSONL:
```matlab
inJsonl  = "data/openalex_....jsonl";
outJsonl = "data/openalex_....standard.jsonl";
n = openalex_write_jsonl(inJsonl, outJsonl);
```

### CSV (lossless: nested fields preserved as JSON strings)
Export Works to a single CSV while preserving all top-level fields.
Nested/array fields are stored as JSON strings (lossless, but not normalized):
```matlab
inJsonl = "data/openalex_....jsonl";
outCsv  = "data/openalex_....works.csv";
T = openalex_export_csv(inJsonl, outCsv);
```
> Note
> This CSV export is intended as an interchange format, not an analysis-ready table.
> Variable-length and nested fields are preserved as JSON strings by design.
> If you need normalized or analysis-specific tables, perform that transformation
> in a downstream project.

## Resume behavior
If the checkpoint .mat file exists:
- The fetcher resumes from the last saved cursor.
- Basic compatibility checks are performed:
  - query string
  - perPage
  - filter conditions

If these do not match, execution stops with an error
to prevent accidental data corruption.

## Rate limiting and responsibility
OpenAlex imposes rate limits.
The example script includes a small pause between requests.
You are responsible for adjusting request frequency
according to OpenAlex policies and your own usage.

### Polite pool (recommended)
If you are doing large-scale requests, OpenAlex recommends providing a contact email
so your traffic can be associated with the "polite pool".

This repository supports this via the optional `mailto` parameter.
The example reads it from an environment variable:

**Windows (PowerShell)**
```powershell
$env:OPENALEX_MAILTO="you@example.com"
```

**macOS/Linux (bash/zsh)**
```bash
export OPENALEX_MAILTO="you@example.com"
```

Then run:
```matlab
run("examples/demo_fetch_example.m")
```

## What this repository does NOT do
- It does not perform downstream analysis or visualization.
- It does not normalize or deduplicate records.
- It does not aim to replace official OpenAlex SDKs.

This repository focuses strictly on robust data acquisition.

## License
MIT License. See the LICENSE file for details.

## A note for contributors
This repository prioritizes:
- clarity over abstraction
- reproducibility over convenience
- explicit configuration over magic defaults

If you plan to extend it, please preserve these principles.
