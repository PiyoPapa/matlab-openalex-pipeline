%% Step 1. Define query parameters
% This example demonstrates *data acquisition only*.
% No normalization, aggregation, or analysis is performed here.
%
% If you already know the exact number of records you want,
% you may skip the peek_count step below.
cfg = oa_bootstrap();
query      = "matlab";
language   = "en";

fromDate = "2024-01-01";
toDate   = "2024-01-31";
type   = "article";
sort   = "publication_date:desc";

% NOTE on `select`:
% - Uncomment and set `select` to limit returned fields (smaller payload).
% - Leave it empty / commented to request the API default response
%   (i.e., fetch full Work objects, if provided by OpenAlex).
% - Do NOT use `select` with oa_peek_count (count-only).

%select = ["id","title","publication_date","type"];

mailto = ""; % RECOMMEND: Add your email.

% NOTE:
% oa_peek_count is *count-only* and makes a single lightweight request.
% Do NOT pass 'select' here; some APIs may omit meta.count when select is used.
% The returned count helps you decide maxRecords for the actual fetch step.
info = oa_peek_count(cfg, query, language, "publication", fromDate, toDate, type, sort, mailto);
disp(info.count)

%% Step 2. Run acquisition (fetch)
% This step performs the actual bulk fetch and writes JSONL outputs to ./data/.
% The process is resumable via cursor checkpoints (.mat).
maxRecords = 8500;
perPage    = 200;
pauseSec   = 0.2;

out = oa_run_openalex(cfg, ...
  query, language, "publication", fromDate, toDate, type, ...
  sort, select, mailto, maxRecords, perPage, pauseSec);

%% Step 3. Quick sanity check (first 3 Works, full fields)
% NOTE:
% This prints the full decoded Work objects for a quick visual verification.
% It reads only the first N lines of the *standard* JSONL (1 Work per line).
N = 3;
fprintf("Standard JSONL: %s\n", out.jsonlStandard);

try
    fid = fopen(out.jsonlStandard, "r");
    if fid < 0
        error("demo_fetch_example:FileOpenFailed", "Could not open: %s", out.jsonlStandard);
    end
    c = onCleanup(@() fclose(fid));

    fprintf("\n--- First %d Works (full fields) ---\n", N);
    for k = 1:N
        line = fgetl(fid);
        if ~ischar(line); break; end
        w = jsondecode(line);
        fprintf("\n[%d]\n", k);
        disp(w); % full fields (may be verbose)
    end
    fprintf("\n--- end ---\n\n");
catch ME
    warning("demo_fetch_example:SanityCheckFailed", ...
        "Could not preview first lines of standard JSONL. Reason: %s", ME.message);
end