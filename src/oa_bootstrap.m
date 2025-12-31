function cfg = oa_bootstrap(varargin)
%OA_BOOTSTRAP  Robust bootstrap for OA helper scripts.
%
% Purpose:
%   - Resolve repo root reliably even when Live Script runs from a Temp shadow copy
%   - cd(repoRoot) for deterministic relative paths
%   - addpath(repoRoot/src)
%   - prepare output folders and defaults (e.g., OPENALEX_MAILTO)
%
% Usage:
%   cfg = oa_bootstrap();
%
% Returns:
%   cfg.repoRoot   (string)  Repository root folder
%   cfg.srcDir     (string)  <repoRoot>/src
%   cfg.oaDir      (string)  <repoRoot>/src/+oa (if exists) otherwise <repoRoot>/src
%   cfg.outDir     (string)  Default output folder (default: <repoRoot>/data)
%   cfg.defaults.mailto (string) from env OPENALEX_MAILTO (may be empty)

% ---- Options (keep minimal) ----
p = inputParser;
addParameter(p, "outDirName", "data", @(x) ischar(x) || isstring(x));
addParameter(p, "doCd", true, @(x) islogical(x) && isscalar(x));
addParameter(p, "quiet", false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opt = p.Results;

outDirName = string(opt.outDirName);
doCd       = logical(opt.doCd);
quiet      = logical(opt.quiet);

% ---- Resolve this script path (best-effort) ----
thisFile = string(mfilename("fullpath"));

% Live Script sometimes executes from a Temp shadow copy -> mfilename points into tempdir
if strlength(thisFile) == 0 || startsWith(thisFile, string(tempdir), "IgnoreCase", true)
    % Try active editor file (works when invoked from a .mlx open in editor)
    try
        activeFile = string(matlab.desktop.editor.getActiveFilename);
        if strlength(activeFile) > 0
            thisFile = activeFile;
        end
    catch
        % ignore
    end
end

% If still unusable, fall back to current folder (last resort)
if strlength(thisFile) == 0
    thisFile = string(pwd);
end

% ---- Determine repo root ----
% Expected layout:
%   <repoRoot>/src/oa_bootstrap.m
% So: fileparts(fileparts(thisFile)) == repoRoot when thisFile is in src/
repoRoot = fileparts(fileparts(thisFile));

% Sanity check: ensure <repoRoot>/src exists; otherwise try to find src upwards a bit
srcDir = fullfile(repoRoot, "src");
if ~isfolder(srcDir)
    repoRoot = localFindRepoRootFromPath_(fileparts(thisFile));
    srcDir   = fullfile(repoRoot, "src");
end

if ~isfolder(srcDir)
    error("oa_bootstrap:RepoRootNotFound", ...
        "Could not locate repoRoot/src. Resolved repoRoot='%s'.", repoRoot);
end

% ---- cd(repoRoot) for deterministic paths ----
if doCd
    try
        cd(repoRoot);
    catch
        if ~quiet
            warning("oa_bootstrap:CdFailed", "Could not cd to repoRoot: %s", repoRoot);
        end
    end
end

% ---- addpath(src) (idempotent) ----
if ~contains(string(path), string(srcDir), "IgnoreCase", true)
    addpath(srcDir);
end

% ---- Default output dir ----
outDir = fullfile(repoRoot, outDirName);
if ~isfolder(outDir)
    mkdir(outDir);
end

% ---- Defaults ----
mailto = string(getenv("OPENALEX_MAILTO"));

% ---- Build cfg ----
cfg = struct();
cfg.repoRoot    = string(repoRoot);
cfg.srcDir      = string(srcDir);
cfg.outDir      = string(outDir);

% Prefer package folder if present (optional)
oaPkgDir = string(fullfile(srcDir, "+oa"));
if isfolder(oaPkgDir)
    cfg.oaDir = oaPkgDir;
else
    cfg.oaDir = string(srcDir);
end

cfg.defaults = struct();
cfg.defaults.mailto = mailto;

if ~quiet
    % Minimal, non-noisy confirmation
    fprintf("[oa_bootstrap] repoRoot: %s\n", cfg.repoRoot);
    fprintf("[oa_bootstrap] outDir  : %s\n", cfg.outDir);
end
end

% =========================
% Local helper functions
% =========================
function repoRoot = localFindRepoRootFromPath_(startDir)
% Walk upward (limited) to find a folder that contains "src".
d = string(startDir);
repoRoot = d;

maxHops = 6; % enough for weird temp paths; keeps it bounded
for k = 1:maxHops
    if isfolder(fullfile(repoRoot, "src"))
        return;
    end
    parent = string(fileparts(repoRoot));
    if parent == repoRoot || strlength(parent) == 0
        break;
    end
    repoRoot = parent;
end
% If not found, return startDir (caller will error)
repoRoot = string(startDir);
end
