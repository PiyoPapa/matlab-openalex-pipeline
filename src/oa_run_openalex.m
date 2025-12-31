function out = oa_run_openalex(cfg, ...
    query, language, dateMode, fromDate, toDate, type, sort, select, mailto, ...
    maxRecords, perPage, pauseSec, varargin)
%OA_RUN_OPENALEX  One-shot runner: build filter/tag/paths and fetch OpenAlex Works.
%
% out = oa_run_openalex(cfg, query, language, dateMode, fromDate, toDate, type, sort, select, mailto, ...
%                             maxRecords, perPage, pauseSec)
%
% Inputs (front-friendly):
%   cfg        : from oa_bootstrap()
%   query      : e.g. "MATLAB"
%   language   : e.g. "en" ("" to skip)
%   dateMode   : "publication" | "created" | "updated"
%   fromDate   : "YYYY-MM-DD" ("" to skip)
%   toDate     : "YYYY-MM-DD" ("" to skip)
%   type       : e.g. "journal-article" ("" to skip)
%   sort       : e.g. "publication_date:desc" ("" to use default inside fetcher)
%   select     : string array of fields or "" (empty to skip)
%   mailto     : "" to use cfg.defaults.mailto
%   maxRecords : integer
%   perPage    : integer (OpenAlex max is typically 200)
%   pauseSec   : seconds between requests
%
% Name-Value options:
%   "verbose" (true/false) default true
%   "saveEvery" default 25
%   "saveEveryRecords" default 10000
%   "progressEveryRecords" default 5000
%   "keepInMemory" default false
%   "tagPrefix" default ""   (optional prefix for filenames)

p = inputParser;
addParameter(p, "verbose", true, @(x) islogical(x) && isscalar(x));
addParameter(p, "saveEvery", 25, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, "saveEveryRecords", 10000, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, "progressEveryRecords", 5000, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, "keepInMemory", false, @(x) islogical(x) && isscalar(x));
addParameter(p, "tagPrefix", "", @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opt = p.Results;

% ---- Normalize inputs ----
query    = string(query);
language = string(language);
dateMode = lower(string(dateMode));
fromDate = string(fromDate);
toDate   = string(toDate);
type     = string(type);
sort     = string(sort);

% select can be string array OR "" OR empty
if nargin < 9 || isempty(select)
    select = strings(0,1);
end
select = string(select);

mailto = string(mailto);
if strlength(mailto) == 0
    if isfield(cfg,"defaults") && isfield(cfg.defaults,"mailto")
        mailto = string(cfg.defaults.mailto);
    end
end

maxRecords = localToScalarNumber_(maxRecords, "maxRecords");
perPage    = localToScalarNumber_(perPage,    "perPage");
pauseSec   = localToScalarNumber_(pauseSec,   "pauseSec");

% Manual validation (avoid validateattributes compatibility issues)
if ~(isnumeric(maxRecords) && isscalar(maxRecords) && isfinite(maxRecords) && maxRecords > 0 && maxRecords == floor(maxRecords))
    error("oa_run_openalex:InvalidMaxRecords", ...
        "maxRecords must be a positive integer (got: %s).", string(maxRecords));
end
if ~(isnumeric(perPage) && isscalar(perPage) && isfinite(perPage) && perPage > 0 && perPage == floor(perPage))
    error("oa_run_openalex:InvalidPerPage", ...
        "perPage must be a positive integer (got: %s).", string(perPage));
end
if ~(isnumeric(pauseSec) && isscalar(pauseSec) && isfinite(pauseSec) && pauseSec >= 0)
    error("oa_run_openalex:InvalidPauseSec", ...
        "pauseSec must be a nonnegative number (got: %s).", string(pauseSec));
end

% Validate dateMode
validModes = ["publication","created","updated"];
if ~any(dateMode == validModes)
    error("oa_run_openalex:InvalidDateMode", ...
        "dateMode must be one of: %s", strjoin(validModes,", "));
end

% Validate date formats if provided
localValidateDate_(fromDate, "fromDate");
localValidateDate_(toDate,   "toDate");

% ---- Build filter string ----
filterParts = strings(0,1);

if strlength(language) > 0
    % accept "en" or "language:en"
    if contains(language, ":")
        filterParts(end+1) = language;
    else
        filterParts(end+1) = "language:" + language;
    end
end

if strlength(type) > 0
    % accept "journal-article" or "type:journal-article"
    if contains(type, ":")
        filterParts(end+1) = type;
    else
        filterParts(end+1) = "type:" + type;
    end
end

% Date filter keys by mode
[fromKey, toKey] = localDateKeys_(dateMode);
if strlength(fromDate) > 0
    filterParts(end+1) = fromKey + ":" + fromDate;
end
if strlength(toDate) > 0
    filterParts(end+1) = toKey + ":" + toDate;
end

filterStr = strjoin(filterParts, ",");

% ---- Build tag + paths (avoid collisions; reflect conditions) ----
tagPrefix = string(opt.tagPrefix);
runStamp  = string(datetime("now","Format","yyyyMMdd_HHmmss"));
hash8     = localHash8_(query, filterStr, sort, select, maxRecords, perPage, pauseSec);
tag       = localBuildShortTag_(tagPrefix, runStamp, hash8);

outDir = string(cfg.outDir);
if ~isfolder(outDir)
    mkdir(outDir);
end

cursorMat = fullfile(outDir, "openalex_cursor_" + tag + ".mat");
jsonlRaw  = fullfile(outDir, "openalex_cursor_" + tag + ".jsonl");
jsonlStd  = fullfile(outDir, "openalex_cursor_" + tag + ".standard.jsonl");

% ---- Call fetcher ----
if opt.verbose
    fprintf("[oa_run_openalex] query   : %s\n", query);
    fprintf("[oa_run_openalex] filter  : %s\n", filterStr);
    fprintf("[oa_run_openalex] sort    : %s\n", sort);
    fprintf("[oa_run_openalex] select  : %s\n", localPrettySelect_(select));
    fprintf("[oa_run_openalex] max/per : %d / %d\n", maxRecords, perPage);
    fprintf("[oa_run_openalex] outDir  : %s\n", outDir);
end

% NOTE:
% - openalex_fetch_works must support these Name-Value pairs.
% - If your openalex_fetch_works does NOT yet support 'select' or date keys,
%   you must patch it accordingly (we can do a diff next).
openalex_fetch_works(query, ...
    "perPage", perPage, ...
    "maxRecords", maxRecords, ...
    "filter", filterStr, ...
    "sort", sort, ...
    "select", select, ...
    "mailto", mailto, ...
    "outFile", cursorMat, ...
    "jsonlFile", jsonlRaw, ...
    "keepInMemory", opt.keepInMemory, ...
    "saveEvery", opt.saveEvery, ...
    "saveEveryRecords", opt.saveEveryRecords, ...
    "progressEveryRecords", opt.progressEveryRecords, ...
    "pauseSec", pauseSec, ...
    "verbose", opt.verbose);

% ---- Convert to standard JSONL ----
openalex_write_jsonl(jsonlRaw, jsonlStd, "verbose", opt.verbose);

% ---- Output summary ----
out = struct();
out.tag = tag;
out.filter = filterStr;
out.runStamp = runStamp;
out.cursorMat = string(cursorMat);
out.jsonlRaw = string(jsonlRaw);
out.jsonlStandard = string(jsonlStd);
out.query = query;
out.language = language;
out.dateMode = dateMode;
out.fromDate = fromDate;
out.toDate = toDate;
out.type = type;
out.sort = sort;
out.select = select;
out.mailto = mailto;
end

% =========================
% Local helper functions
% =========================
function localValidateDate_(s, name)
s = string(s);
if strlength(s) == 0
    return;
end
try
    datetime(s, "InputFormat","yyyy-MM-dd");
catch
    error("oa_run_openalex:InvalidDate", ...
        "%s must be 'YYYY-MM-DD' (got: %s)", name, s);
end
end

function x = localToScalarNumber_(x, name)
% Accept numeric, string, char; convert to double scalar.
if isnumeric(x)
    if ~isscalar(x)
        error("oa_run_openalex:InvalidNumeric", "%s must be a scalar.", name);
    end
    x = double(x);
    return;
end
if isstring(x) || ischar(x)
    sx = strtrim(string(x));
    v = str2double(sx);
    if isnan(v) || ~isfinite(v)
        error("oa_run_openalex:InvalidNumeric", "%s must be numeric (got: %s).", name, sx);
    end
    x = double(v);
    return;
end
error("oa_run_openalex:InvalidNumeric", "%s has unsupported type: %s", name, class(x));
end

function [fromKey, toKey] = localDateKeys_(mode)
switch string(mode)
    case "publication"
        fromKey = "from_publication_date";
        toKey   = "to_publication_date";
    case "created"
        fromKey = "from_created_date";
        toKey   = "to_created_date";
    case "updated"
        fromKey = "from_updated_date";
        toKey   = "to_updated_date";
    otherwise
        error("Unreachable");
end
end

function tag = localBuildTag_(prefix, query, language, dateMode, fromDate, toDate, type, maxRecords)
% Keep filenames safe and stable (avoid spaces/slashes/long garbage).
q = localSlug_(query, 24);
lang = localSlug_(language, 10);
typ  = localSlug_(type, 18);

dm = localSlug_(dateMode, 12);
fd = localSlug_(fromDate, 10);
td = localSlug_(toDate, 10);

parts = strings(0,1);
if strlength(prefix) > 0, parts(end+1) = localSlug_(prefix, 24); end
parts(end+1) = q;

if strlength(lang) > 0, parts(end+1) = "lang-" + lang; end
parts(end+1) = "dm-" + dm;

if strlength(fd) > 0, parts(end+1) = "from-" + fd; end
if strlength(td) > 0, parts(end+1) = "to-" + td; end

if strlength(typ) > 0, parts(end+1) = "type-" + typ; end
parts(end+1) = "n-" + string(maxRecords);

tag = strjoin(parts, "_");
end

function s = localSlug_(s, maxLen)
s = string(s);
s = lower(s);
s = regexprep(s, "\s+", "-");
s = regexprep(s, "[^a-z0-9\-_:.]+", "");  % keep safe chars
s = regexprep(s, "[:.]+", "-");          % avoid weird Windows file chars
s = regexprep(s, "-{2,}", "-");
% strip(s,"-_") is not supported on some MATLAB versions.
% Remove leading/trailing '-' and '_' via regex for compatibility.
s = regexprep(s, "^[\-_]+", "");
s = regexprep(s, "[\-_]+$", "");
if strlength(s) > maxLen
    s = extractBetween(s, 1, maxLen);
end
end

function t = localPrettySelect_(select)
select = string(select);
if isempty(select) || all(strlength(select)==0)
    t = "(none)";
else
    t = strjoin(select, ",");
end
end

function tag = localBuildShortTag_(prefix, runStamp, hash8)
parts = strings(0,1);
if strlength(prefix) > 0
    parts(end+1) = localSlug_(prefix, 24);
end
parts(end+1) = runStamp;
parts(end+1) = hash8;
tag = strjoin(parts, "_");
end

function h8 = localHash8_(query, filterStr, sortStr, select, maxRecords, perPage, pauseSec)
% Short hash for collision avoidance; details still stored in checkpoint .mat.
select = string(select);
if isempty(select), select = ""; end
key = strjoin([
    "q=" + string(query)
    "filter=" + string(filterStr)
    "sort=" + string(sortStr)
    "select=" + strjoin(select, ",")
    "max=" + string(maxRecords)
    "per=" + string(perPage)
    "pause=" + string(pauseSec)
], "|");

% Robust MD5 (works across MATLAB versions) using Java MessageDigest
bytes = uint8(char(key));
md = java.security.MessageDigest.getInstance("MD5");
md.update(bytes);
dig = typecast(md.digest(), "uint8");  % 16 bytes
hex = lower(string(reshape(dec2hex(dig,2).',1,[]))); % 32 hex chars
h8  = extractBetween(hex, 1, 8);
end