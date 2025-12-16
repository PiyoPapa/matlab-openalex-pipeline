function nWritten = openalex_write_jsonl(inJsonl, outJsonl, varargin)
%OPENALEX_WRITE_JSONL Convert "array-per-line" JSONL to standard JSONL
% Input:  1 line = JSON array of Works (your current format)
% Output: 1 line = JSON object (1 Work per line)
%
% nWritten = openalex_write_jsonl("in.jsonl","out_standard.jsonl");

p = inputParser;
addRequired(p, 'inJsonl',  @(x) ischar(x) || isstring(x));
addRequired(p, 'outJsonl', @(x) ischar(x) || isstring(x));
addParameter(p, 'maxRecords', inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, inJsonl, outJsonl, varargin{:});
opt = p.Results;

inJsonl  = string(opt.inJsonl);
outJsonl = string(opt.outJsonl);
maxRecords = opt.maxRecords;
verbose = opt.verbose;

fin = fopen(inJsonl, 'r');
if fin < 0, error("Cannot open file: %s", inJsonl); end
cleanIn = onCleanup(@() fclose(fin));

fout = fopen(outJsonl, 'w');
if fout < 0, error("Cannot open file for write: %s", outJsonl); end
cleanOut = onCleanup(@() fclose(fout));

nWritten = 0;
t0 = tic;
while true
    line = fgetl(fin);
    if ~ischar(line); break; end
    line = strtrim(line);
    if line == ""; continue; end

    arr = jsondecode(line);  % struct array
    for k = 1:numel(arr)
        fprintf(fout, '%s\n', jsonencode(arr(k)));
        nWritten = nWritten + 1;
        if nWritten >= maxRecords
            break;
        end
    end

    if verbose && mod(nWritten, 10000) == 0 && nWritten > 0
        fprintf("[write-jsonl] wrote %d records (%.1fs)\n", nWritten, toc(t0));
    end

    if nWritten >= maxRecords
        break;
    end
end
end