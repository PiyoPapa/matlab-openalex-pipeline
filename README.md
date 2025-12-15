# matlab-openalex-pipeline
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-pipeline)

A MATLAB-based pipeline for fetching OpenAlex **Works** metadata at scale using cursor-based pagination, with resumable checkpoints and JSONL output.

This repository is designed for **large-scale bibliographic data collection**
(e.g. tens to hundreds of thousands of records) in research and analytics
workflows where MATLAB is the primary environment.

---

## What this repository provides

- Cursor-based pagination for the OpenAlex Works API  
  (avoids the 10,000-record limit of page-based pagination)
- Safe resume mechanism using a lightweight `.mat` checkpoint
- High-throughput output via append-only JSONL
- MATLAB-only implementation (no Python/R dependencies)

This is **not** a wrapper for the full OpenAlex API.
It intentionally focuses on a **robust, reproducible data acquisition core**.

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
│  ├─ openalex_fetch_works.m
│  └─ openalex_read_jsonl.m
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

This will:
 - Add `src/` to the MATLAB path
 - Fetch OpenAlex Works metadata for a sample query
 - Write outputs to `./data/`

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

## What this repository does NOT do
- It does not perform downstream analysis or visualization.
- It does not normalize or deduplicate records.
- It does not aim to replace official OpenAlex SDKs.

This repository focuses strictly on robust data acquisition.

## License
MIT

## A note for contributors
This repository prioritizes:
- clarity over abstraction
- reproducibility over convenience
- explicit configuration over magic defaults

If you plan to extend it, please preserve these principles.
