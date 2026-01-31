function info = oa_peek_count(cfg, query, language, dateMode, fromDate, toDate, type, sort, mailto, varargin)
%OA_PEEK_COUNT  One-shot "count only" query for OpenAlex Works.
%
% info = oa_peek_count(cfg, query, language, dateMode, fromDate, toDate, type, sort, mailto)
%
% Purpose:
%   - Before running oa_run_openalex(), estimate total hits for the same conditions.
%   - Returns meta.count (total number of Works matching the query+filter).
%
% Notes:
%   - This function makes a single HTTP request (per-page = 1).
%   - Do NOT pass 'select' here; some APIs may omit meta when select is used.
%
% Inputs:
%   cfg      : from oa_bootstrap()
%   query    : e.g. "matlab"
%   language : e.g. "en" or "language:en" ("" to skip)
%   dateMode : "publication" | "created" | "updated"
%   fromDate : "YYYY-MM-DD" ("" to skip)
%   toDate   : "YYYY-MM-DD" ("" to skip)
%   type     : e.g. "article" or "type:article" ("" to skip)
%   sort     : e.g. "publication_date:desc" ("" to skip)
%   mailto   : "" to use cfg.defaults.mailto (recommended)
%
% Name-Value options:
%   "timeout" (seconds) default 30
%   "verbose" (true/false) default true
%   "institutionId" default ""  (OpenAlex Institution ID "I...", or full filter string)
%
% Output:
%   info.count      : total hits (meta.count)
%   info.query      : query string used
%   info.filter     : filter string used
%   info.sort       : sort string used
%   info.dateMode   : dateMode used
%   info.fromDate   : fromDate used
%   info.toDate     : toDate used
%   info.type       : type used
%   info.mailto     : mailto used
%   info.sampleId   : id of the first returned work (if available)
%   info.requestUrl : request URL (best-effort)
%

p = inputParser;
addParameter(p, "timeout", 30, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, "verbose", true, @(x) islogical(x) && isscalar(x));
addParameter(p, "institutionId", "", @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opt = p.Results;

% ---- Normalize inputs  ----
query    = string(query);
language = string(language);
dateMode = lower(string(dateMode));
fromDate = string(fromDate);
toDate   = string(toDate);
type     = string(type);
sort     = string(sort);
mailto   = string(mailto);

institutionId = string(opt.institutionId);

if strlength(mailto) == 0
    if isfield(cfg,"defaults") && isfield(cfg.defaults,"mailto")
        mailto = string(cfg.defaults.mailto);
    end
end

% Validate dateMode
validModes = ["publication","created","updated"];
if ~any(dateMode == validModes)
    error("oa_peek_count:InvalidDateMode", ...
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
    % accept "article" or "type:article"
    if contains(type, ":")
        filterParts(end+1) = type;
    else
        filterParts(end+1) = "type:" + type;
    end
end

[fromKey, toKey] = localDateKeys_(dateMode);
if strlength(fromDate) > 0
    filterParts(end+1) = fromKey + ":" + fromDate;
end
if strlength(toDate) > 0
    filterParts(end+1) = toKey + ":" + toDate;
end

if strlength(institutionId) > 0
    % accept "I123..." or full filter like "authorships.institutions.id:I123..."
    if contains(institutionId, ":")
        filterParts(end+1) = institutionId;
    else
        filterParts(end+1) = "authorships.institutions.id:" + institutionId;
    end
end

filterStr = strjoin(filterParts, ",");

% ---- Base URL (default to Works endpoint; allow cfg override) ----
baseUrl = "https://api.openalex.org/works";
if isfield(cfg,"defaults") && isfield(cfg.defaults,"baseUrl") && strlength(string(cfg.defaults.baseUrl)) > 0
    baseUrl = string(cfg.defaults.baseUrl);
end

% ---- One request: per-page=1, cursor="*" ----
% Use Name-Value pairs for broad MATLAB compatibility (some versions do not accept struct params).
nv = {};
nv(end+1:end+2) = {'search',   char(query)};
nv(end+1:end+2) = {'per-page', 1};
nv(end+1:end+2) = {'cursor',   '*'};

if strlength(filterStr) > 0
    nv(end+1:end+2) = {'filter', char(filterStr)};
end
if strlength(sort) > 0
    nv(end+1:end+2) = {'sort', char(sort)};
end
if strlength(mailto) > 0
    nv(end+1:end+2) = {'mailto', char(mailto)};
end

% weboptions
wo = weboptions("Timeout", opt.timeout);
% requestUrl is best-effort (MATLAB does not expose the final URL reliably across versions)
requestUrl = char(baseUrl);

if opt.verbose
    fprintf("[oa_peek_count] query   : %s\n", query);
    fprintf("[oa_peek_count] filter  : %s\n", filterStr);
    fprintf("[oa_peek_count] sort    : %s\n", sort);
    fprintf("[oa_peek_count] mailto  : %s\n", mailto);
end

try
    r = webread(char(baseUrl), nv{:}, wo);
catch ME
    % Provide a more actionable message while preserving original error id/message.
    msg = sprintf("OpenAlex request failed (count-only). baseUrl=%s, query=%s, filter=%s, sort=%s", ...
        string(baseUrl), query, filterStr, sort);
    cause = MException("oa_peek_count:HttpError", "%s", msg);
    cause = addCause(cause, ME);
    throw(cause);
end

% ---- Extract meta.count ----
count = NaN;
sampleId = "";
try
    if isfield(r,"meta") && isfield(r.meta,"count")
        count = double(r.meta.count);
    end
    if isfield(r,"results") && ~isempty(r.results)
        if isstruct(r.results) && isfield(r.results(1),"id")
            sampleId = string(r.results(1).id);
        end
    end
catch
    % keep NaN if unexpected shape
end

if ~(isfinite(count) && count >= 0)
    % Fail loudly: count-only must return a number, otherwise something is off.
    error("oa_peek_count:MissingCount", ...
        "Response did not contain meta.count. This may indicate an API change or an unexpected response shape.");
end

% ---- Output ----
info = struct();
info.count      = count;
info.query      = query;
info.filter     = filterStr;
info.sort       = sort;
info.dateMode   = dateMode;
info.fromDate   = fromDate;
info.toDate     = toDate;
info.type       = type;
info.mailto     = mailto;
info.sampleId   = sampleId;
info.requestUrl = string(requestUrl);

if opt.verbose
    fprintf("[oa_peek_count] count   : %g\n", info.count);
    if strlength(sampleId) > 0
        fprintf("[oa_peek_count] sample : %s\n", sampleId);
    end
end
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
    error("oa_peek_count:InvalidDate", ...
        "%s must be 'YYYY-MM-DD' (got: %s)", name, s);
end
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
