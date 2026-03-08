function [edaTable, meta] = loadShimmerEDACSV(filePath, varargin)
% loadShimmerEDACSV Parse one Shimmer EDA CSV into a clean MATLAB table.
%
% Purpose:
%   Convert one raw Shimmer CSV into a standard table for downstream
%   visualization/analysis without changing signal values.
%
% Usage:
%   [edaTable, meta] = loadShimmerEDACSV('/path/DefaultTrial_...csv')
%
% Output columns (when available):
%   timestamp        - parsed datetime from first column
%   gsrRange         - range code from Shimmer
%   edaMicroSiemens  - skin conductance (uS)
%   resistanceKOhms  - skin resistance (kOhms)

    p = inputParser;
    addRequired(p, 'filePath', @(x) ischar(x) || isstring(x));
    parse(p, filePath, varargin{:});

    filePath = char(string(filePath));
    if ~isfile(filePath)
        error('loadShimmerEDACSV:FileMissing', 'File not found: %s', filePath);
    end

    meta = struct();
    meta.filePath = filePath;
    [~, f, e] = fileparts(filePath);
    meta.fileName = [f, e];
    meta.headerRaw = readSingleCSVRow(filePath, 2);
    meta.unitsRaw = readSingleCSVRow(filePath, 3);

    opts = detectImportOptions(filePath, 'FileType', 'text', 'NumHeaderLines', 3);
    opts.VariableNamingRule = 'preserve';
    rawT = readtable(filePath, opts);
    rawT = localDropEmptyColumns(rawT);

    varNames = localHeaderToVarNames(meta.headerRaw, width(rawT));
    rawT.Properties.VariableNames = varNames;

    tsVar = varNames{1};
    ts = localParseShimmerDatetime(rawT.(tsVar));

    edaTable = table();
    edaTable.timestamp = ts;

    if any(contains(varNames, "GSR_Range", 'IgnoreCase', true))
        vn = varNames{find(contains(varNames, "GSR_Range", 'IgnoreCase', true), 1, 'first')};
        edaTable.gsrRange = localToDouble(rawT.(vn));
    else
        edaTable.gsrRange = NaN(height(rawT), 1);
    end

    if any(contains(varNames, "Skin_Conductance", 'IgnoreCase', true))
        vn = varNames{find(contains(varNames, "Skin_Conductance", 'IgnoreCase', true), 1, 'first')};
        edaTable.edaMicroSiemens = localToDouble(rawT.(vn));
    else
        edaTable.edaMicroSiemens = NaN(height(rawT), 1);
    end

    if any(contains(varNames, "Skin_Resistance", 'IgnoreCase', true))
        vn = varNames{find(contains(varNames, "Skin_Resistance", 'IgnoreCase', true), 1, 'first')};
        edaTable.resistanceKOhms = localToDouble(rawT.(vn));
    else
        edaTable.resistanceKOhms = NaN(height(rawT), 1);
    end
end

function T = localDropEmptyColumns(T)
    keep = true(1, width(T));
    for c = 1:width(T)
        v = T{:, c};
        if isnumeric(v)
            keep(c) = ~all(isnan(v));
        else
            s = strtrim(string(v));
            keep(c) = ~all(s == "" | ismissing(s));
        end
    end
    T = T(:, keep);
end

function names = localHeaderToVarNames(headerRaw, nCols)
    h = string(headerRaw);
    h = strrep(h, '"', '');
    h = strtrim(h);
    h = h(h ~= "");
    if isempty(h)
        names = arrayfun(@(k) sprintf('col%d', k), 1:nCols, 'UniformOutput', false);
        return;
    end
    n = min(numel(h), nCols);
    names = cell(1, nCols);
    for i = 1:n
        names{i} = matlab.lang.makeValidName(char(h(i)));
    end
    for i = (n+1):nCols
        names{i} = sprintf('col%d', i);
    end
end

function dt = localParseShimmerDatetime(v)
    s = strtrim(string(v));
    dt = NaT(size(s));
    fmts = { ...
        'yyyy/MM/dd HH:mm:ss.SSS', ...
        'yyyy/MM/dd HH:mm:ss', ...
        'MM/dd/yyyy HH:mm:ss.SSS', ...
        'yyyy-MM-dd HH:mm:ss.SSS' ...
        };
    for i = 1:numel(s)
        if s(i) == "" || ismissing(s(i))
            continue;
        end
        for f = 1:numel(fmts)
            try
                dt(i) = datetime(s(i), 'InputFormat', fmts{f});
                if ~isnat(dt(i))
                    break;
                end
            catch
                % try next format
            end
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
