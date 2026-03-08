function [ecgTable, meta] = loadMovesenseECGCSV(filePath, varargin)
% loadMovesenseECGCSV Parse one Movesense ECG CSV into a clean MATLAB table.
%
% Purpose:
%   Convert one raw Movesense file into a standard, readable table without
%   running any signal-processing computations.
%
% Usage:
%   [ecgTable, meta] = loadMovesenseECGCSV('/path/MovesenseECG-....csv')
%
% Output columns:
%   elapsedSec    - elapsed time in seconds from file start
%   ecgMv         - ECG amplitude in mV
%   timestampUTC  - absolute UTC timestamp if "# created ..." header exists

    p = inputParser;
    addRequired(p, 'filePath', @(x) ischar(x) || isstring(x));
    parse(p, filePath, varargin{:});

    filePath = char(string(filePath));
    if ~isfile(filePath)
        error('loadMovesenseECGCSV:FileMissing', 'File not found: %s', filePath);
    end

    meta = struct();
    meta.filePath = filePath;
    [~, f, e] = fileparts(filePath);
    meta.fileName = [f, e];
    meta.createdUTC = NaT;
    meta.header = struct();

    meta.header = localParseHeader(filePath);
    if isfield(meta.header, 'created')
        meta.createdUTC = localParseCreatedUTC(meta.header.created);
    end

    opts = detectImportOptions(filePath, 'FileType', 'text', 'CommentStyle', '#');
    opts.VariableNamingRule = 'preserve';
    rawT = readtable(filePath, opts);
    if width(rawT) < 2
        error('loadMovesenseECGCSV:UnexpectedFormat', ...
            'Expected at least 2 columns (elapsed and ECG) in %s', filePath);
    end

    elapsedSec = localToDouble(rawT{:, 1});
    ecgMv = localToDouble(rawT{:, 2});

    timestampUTC = NaT(size(elapsedSec));
    if ~isnat(meta.createdUTC)
        timestampUTC = meta.createdUTC + seconds(elapsedSec);
    end

    ecgTable = table(elapsedSec, ecgMv, timestampUTC, ...
        'VariableNames', {'elapsedSec', 'ecgMv', 'timestampUTC'});
end

function header = localParseHeader(filePath)
    header = struct();
    fid = fopen(filePath, 'r');
    if fid < 0
        return;
    end
    cleaner = onCleanup(@() fclose(fid));

    while true
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end
        line = strtrim(line);
        if ~startsWith(line, '#')
            break;
        end
        line = strtrim(regexprep(line, '^#\s*', ''));
        tok = regexp(line, '^([A-Za-z_]+)\s+(.*)$', 'tokens', 'once');
        if isempty(tok)
            continue;
        end
        key = matlab.lang.makeValidName(lower(tok{1}));
        val = strtrim(tok{2});
        header.(key) = val;
    end
end

function dt = localParseCreatedUTC(s)
    dt = NaT;
    s = strtrim(char(string(s)));
    fmts = { ...
        'yyyy-MM-dd''T''HH:mm:ss.SSSSSS''Z''', ...
        'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', ...
        'yyyy-MM-dd''T''HH:mm:ss''Z''' ...
        };
    for i = 1:numel(fmts)
        try
            dt = datetime(s, 'InputFormat', fmts{i}, 'TimeZone', 'UTC');
            if ~isnat(dt)
                return;
            end
        catch
            % try next format
        end
    end
end

function x = localToDouble(v)
    if isnumeric(v)
        x = double(v);
        return;
    end
    s = string(v);
    s = strrep(s, ',', '.');
    x = str2double(s);
end
