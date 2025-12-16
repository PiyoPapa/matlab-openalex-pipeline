function T = openalex_export_csv(jsonlFile, outCsv, varargin)
%OPENALEX_EXPORT_CSV Export Works to a single CSV while preserving ALL fields.
% Strategy:
% - Scalar-ish fields -> columns
% - Nested/arrays/cells/struct arrays -> JSON string columns (lossless)
%
% T = openalex_export_csv("openalex_results.jsonl","works.csv");

p = inputParser;
addRequired(p, 'jsonlFile', @(x) ischar(x) || isstring(x));
addRequired(p, 'outCsv',    @(x) ischar(x) || isstring(x));
addParameter(p, 'maxRecords', inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, jsonlFile, outCsv, varargin{:});
opt = p.Results;

jsonlFile = string(opt.jsonlFile);
outCsv    = string(opt.outCsv);
maxRecords = opt.maxRecords;
verbose = opt.verbose;

% Read using your existing helper (array-per-line -> struct array)
results = openalex_read_jsonl(jsonlFile, 'maxRecords', maxRecords, 'verbose', verbose); % :contentReference[oaicite:2]{index=2}

% Convert each record to a 1-row table with consistent variables
rows = cell(numel(results),1);
for i = 1:numel(results)
    rows{i} = localWorkToRow(results(i));
    if verbose && mod(i, 10000) == 0
        fprintf("[export-csv] flattened %d records...\n", i);
    end
end

T = vertcat(rows{:});
% Write (UTF-8)
writetable(T, outCsv, 'FileType', 'text');

if verbose
    fprintf("[export-csv] wrote %d rows -> %s\n", height(T), outCsv);
end
end

function Tr = localWorkToRow(w)
% Build a flat struct with all top-level fields.
fn = fieldnames(w);
S = struct();
for j = 1:numel(fn)
    key = fn{j};
    val = w.(key);
    S.(key) = localToCsvCell(val);
end

% Make stable column order (alphabetical)
keys = fieldnames(S);
keys = sort(keys);
vals = cell(size(keys));
for k = 1:numel(keys)
    vals{k} = S.(keys{k});
end
Tr = cell2table(vals', 'VariableNames', matlab.lang.makeValidName(keys'));
end

function out = localToCsvCell(val)
% CSV cell must be scalar string/char/double/logical; otherwise use JSON string.
if isempty(val)
    out = "";
    return;
end

if ischar(val) || (isstring(val) && isscalar(val))
    out = string(val);
    return;
end

if isnumeric(val) && isscalar(val)
    out = val;
    return;
end

if islogical(val) && isscalar(val)
    out = val;
    return;
end

% Everything else (struct, struct array, cell, vector, etc.) => JSON string (lossless)
try
    out = string(jsonencode(val));
catch
    % Fallback: stringify class
    out = "<unencodable:" + string(class(val)) + ">";
end
end