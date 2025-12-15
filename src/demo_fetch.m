function allResults = demo_fetch(query, varargin)
%DEMO_FETCH  Fetch OpenAlex Works metadata using cursor-based pagination
%
% allResults = demo_fetch(query, ...
%   'perPage', 200, ...
%   'maxRecords', 50000, ...
%   'baseUrl', "https://api.openalex.org/works", ...
%   'sort', "publication_date:desc", ...
%   'filter', "language:en", ...
%   'outFile', "openalex_cursor.mat", ...
%   'saveEvery', 5, ...
%   'saveEveryRecords', 5000, ...
%   'jsonlFile', "openalex_results.jsonl", ...
%   'keepInMemory', false, ...
%   'timeout', 30, ...
%   'pauseSec', 0.2, ...
%   'verbose', true);

% -------------------------------
% Parse input arguments
% -------------------------------
p = inputParser;
addRequired(p, 'query', @(x) ischar(x) || isstring(x));
addParameter(p, 'outDir', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'perPage', 200, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'maxRecords', inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'baseUrl', "https://api.openalex.org/works", @(x) ischar(x) || isstring(x));
addParameter(p, 'sort', "publication_date:desc", @(x) ischar(x) || isstring(x));
addParameter(p, 'filter', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'outFile', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'timeout', 30, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'pauseSec', 0.2, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'verbose', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'saveEvery', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'saveEveryRecords', 5000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'jsonlFile', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'keepInMemory', false, @(x) islogical(x) && isscalar(x));
parse(p, query, varargin{:});
opt = p.Results;

queryStr   = string(opt.query);
outDir     = string(opt.outDir);
perPage    = min(opt.perPage, 200);  % OpenAlex per-page hard limit
maxRecords = opt.maxRecords;
baseUrl    = string(opt.baseUrl);
sortStr    = string(opt.sort);
filterStr  = string(opt.filter);
outFile    = string(opt.outFile);
timeout    = opt.timeout;
pauseSec   = opt.pauseSec;
verbose    = opt.verbose;
saveEvery  = opt.saveEvery;
saveEveryRecords = opt.saveEveryRecords;
jsonlFile  = string(opt.jsonlFile);
keepInMemory = opt.keepInMemory;

% -------------------------------
% Output handling (no repository structure assumptions)
% -------------------------------
% Rules:
% - Use explicitly specified outFile / jsonlFile
% - If outDir is specified, auto-fill missing file paths
% - If nothing is specified, throw an error
if strlength(outDir) > 0
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    if strlength(outFile) == 0
        outFile = fullfile(outDir, "openalex_cursor.mat");
    end
    if strlength(jsonlFile) == 0
        jsonlFile = fullfile(outDir, "openalex_results.jsonl");
    end
end

if strlength(outFile) == 0 && strlength(jsonlFile) == 0
    error("Specify 'outFile' and/or 'jsonlFile' (or specify 'outDir' to auto-fill defaults).");
end
options = weboptions("ContentType","json","Timeout", timeout);

% -------------------------------
% Initialization
% -------------------------------
allResults = [];
metaLast   = [];
nextCursor = "*";      
nRequests  = 0;
lastSavedRecords = 0;
nRecords = 0;               
fidJsonl = -1;              

% -------------------------------
% Resume from checkpoint if available
% -------------------------------
if strlength(outFile) > 0 && isfile(outFile)
    S = load(outFile);

    if isfield(S, "queryStr") && queryStr ~= S.queryStr
        error('Saved file query (%s) and current query (%s) do not match.', S.queryStr, queryStr);
    end
    if isfield(S, "perPage") && perPage ~= S.perPage
        error('Saved file perPage (%d) and current perPage (%d) do not match.', S.perPage, perPage);
    end
    if isfield(S, "filterStr") && filterStr ~= S.filterStr
        error('Saved file filter (%s) and current filter (%s) do not match.', S.filterStr, filterStr);
    end

    if keepInMemory && isfield(S, "allResults"), allResults = S.allResults; end
    if isfield(S, "metaLast"),   metaLast   = S.metaLast;   end
    if isfield(S, "nextCursor"), nextCursor = string(S.nextCursor); end
    if isfield(S, "nRequests"),  nRequests  = S.nRequests; end
    if isfield(S, "lastSavedRecords"), lastSavedRecords = S.lastSavedRecords; end
    if isfield(S, "nRecords"), nRecords = S.nRecords; end

    if verbose
        logtag('resume', 'Loaded %s (records=%d, nextCursor=%s)', outFile, nRecords, shorten(nextCursor));
    end
end

% -------------------------------
% Prepare JSONL append file
% -------------------------------
if strlength(jsonlFile) > 0
    jf = fileparts(jsonlFile);
    if strlength(jf) > 0 && ~isfolder(jf)
        mkdir(jf);
    end
    fidJsonl = fopen(jsonlFile, 'a');
    if fidJsonl < 0
        error('Cannot open jsonlFile for append: %s', jsonlFile);
    end
end
cleaner = onCleanup(@() localClose(fidJsonl));

% -------------------------------
% Cursor loop
% -------------------------------
while true
    if nRecords >= maxRecords
        break;
    end
    if strlength(nextCursor) == 0 || nextCursor == "null"
        break; 
    end

    apiUrl = baseUrl + "?" + ...
        "search="   + urlencode(queryStr) + ...
        "&per-page=" + perPage + ...
        "&cursor="  + urlencode(nextCursor) + ...
        "&sort="    + sortStr;

    if strlength(filterStr) > 0
        apiUrl = apiUrl + "&filter=" + urlencode(filterStr);
    end

    try
        data = webread(apiUrl, options);
    catch ME
        if verbose
            logtag('warn', 'webread failed: %s', ME.message);
            logtag('Done', 'total records=%d', numel(allResults));
        end
        break;
    end

    nRequests = nRequests + 1;

    if isfield(data, "meta")
        metaLast = data.meta;
        if isfield(data.meta, "next_cursor")
            nextCursor = string(data.meta.next_cursor);
        else
            nextCursor = "";
        end
    else
        nextCursor = "";
    end

    if ~isfield(data, "results") || isempty(data.results)
        break;
    end
    %  ---- Count retrieved records ----
    got = numel(data.results);
    nRecords = nRecords + got;

    % ---- Optional in-memory accumulation ----
    if keepInMemory
        allResults = [allResults; data.results(:)];
    end

    % ---- Append results to JSONL ----
    % One line per request (JSON array) for I/O efficiency
    if fidJsonl > 0
        fprintf(fidJsonl, '%s\n', jsonencode(data.results));
    end

    doSave = false;
    if mod(nRequests, saveEvery) == 0
        doSave = true;
    end
    if (nRecords - lastSavedRecords) >= saveEveryRecords
        doSave = true;
    end

    if strlength(outFile) > 0 && doSave
        timestamp = datetime('now');
        lastSavedRecords = nRecords;
        if keepInMemory
            save(outFile, "allResults","metaLast","nextCursor","nRequests","nRecords","lastSavedRecords", ...
                "queryStr","perPage","sortStr","filterStr","timestamp","maxRecords","keepInMemory","-v7.3");
        else
            save(outFile, "metaLast","nextCursor","nRequests","nRecords","lastSavedRecords", ...
                "queryStr","perPage","sortStr","filterStr","timestamp","maxRecords","keepInMemory","-v7");
        end
        if verbose
            logtag('save', 'records=%d -> %s', nRecords, outFile);
        end
    end

    if pauseSec > 0
        pause(pauseSec);
    end
end

if strlength(outFile) > 0
    timestamp = datetime('now');
    lastSavedRecords = nRecords;
    if keepInMemory
        save(outFile, "allResults","metaLast","nextCursor","nRequests","nRecords","lastSavedRecords", ...
            "queryStr","perPage","sortStr","filterStr","timestamp","maxRecords","keepInMemory","-v7.3");
    else
        save(outFile, "metaLast","nextCursor","nRequests","nRecords","lastSavedRecords", ...
            "queryStr","perPage","sortStr","filterStr","timestamp","maxRecords","keepInMemory","-v7");
    end
    if verbose
        logtag('save', 'final records=%d -> %s', nRecords, outFile);
        logtag('Done', 'total records=%d', nRecords);
    end
end

end

function localClose(fid)
if fid > 0
    fclose(fid);
end
end

% -------------------------------
% Utility functions
% -------------------------------
function logtag(tag, fmt, varargin)
t = datetime('now','Format','HH:mm:ss:SS');
msg = sprintf(fmt, varargin{:});
fprintf('%s [%s] %s\n', char(t), tag, msg);
end

function s = shorten(x)
x = string(x);
if strlength(x) > 24
    s = extractBefore(x, 12) + "..." + extractAfter(x, strlength(x)-11);
else
    s = x;
end
end