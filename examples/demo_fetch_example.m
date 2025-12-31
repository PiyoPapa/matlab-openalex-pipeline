%% Step 1. Setting up parameter
cfg = oa_bootstrap();
query      = "matlab";
language   = "en";

fromDate = "2024-01-01";
toDate   = "2024-01-31";

type   = "article";
sort   = "publication_date:desc";
select = ["id","title","publication_date","type"];
mailto = "";

% NOTE: peek_count is count-only; 'select' is applied only in fetch.
info = oa_peek_count(cfg, query, language, "publication", fromDate, toDate, type, sort, mailto);
disp(info.count)
%% Step 2. Run
maxRecords = 8500;
perPage    = 200;
pauseSec   = 0.2;

out = oa_run_openalex(cfg, ...
  query, language, "publication", fromDate, toDate, type, ...
  sort, select, mailto, maxRecords, perPage, pauseSec);