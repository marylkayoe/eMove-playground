function modalityData = loadModalitySignalsFromInventory(fileInventory, varargin)
% loadModalitySignalsFromInventory Load Unity/EDA/HR files from inventory.
%
% Purpose:
%   Given `trialData.metaData.modalityFileInventory` (or equivalent table),
%   load modality files into parsed tables with one consistent API.
%
% Inputs:
%   fileInventory - table with columns: modality, filePath
%
% Name-value:
%   'modalities' - subset to load (default: {'unity','eda','hr'})
%
% Output:
%   modalityData struct with fields:
%       unity, eda, hr
%   Each field is a struct array with:
%       filePath, table, meta, loadError

    p = inputParser;
    addRequired(p, 'fileInventory', @istable);
    addParameter(p, 'modalities', {'unity','eda','hr'}, @(x) iscell(x) || isstring(x));
    parse(p, fileInventory, varargin{:});

    inv = fileInventory;
    needed = {'modality', 'filePath'};
    if ~all(ismember(needed, inv.Properties.VariableNames))
        error('loadModalitySignalsFromInventory:MissingColumns', ...
            'fileInventory must contain columns: modality, filePath');
    end

    wanted = lower(string(p.Results.modalities));
    allMod = lower(string(inv.modality));

    modalityData = struct();
    modalityData.unity = struct('filePath', {}, 'table', {}, 'meta', {}, 'loadError', {});
    modalityData.eda = struct('filePath', {}, 'table', {}, 'meta', {}, 'loadError', {});
    modalityData.hr = struct('filePath', {}, 'table', {}, 'meta', {}, 'loadError', {});

    if any(wanted == "unity")
        m = allMod == "unity" | allMod == "unitylogs";
        modalityData.unity = localLoadRows(inv(m, :), @loadUnityEyeLogCSV);
    end
    if any(wanted == "eda")
        m = allMod == "eda";
        modalityData.eda = localLoadRows(inv(m, :), @loadShimmerEDACSV);
    end
    if any(wanted == "hr")
        m = allMod == "hr";
        modalityData.hr = localLoadRows(inv(m, :), @loadMovesenseECGCSV);
    end
end

function out = localLoadRows(T, loaderFn)
    out = struct('filePath', {}, 'table', {}, 'meta', {}, 'loadError', {});
    for i = 1:height(T)
        fp = char(string(T.filePath(i)));
        row = struct();
        row.filePath = fp;
        row.table = table();
        row.meta = struct();
        row.loadError = '';

        try
            [tbl, meta] = loaderFn(fp);
            row.table = tbl;
            row.meta = meta;
        catch ME
            row.loadError = sprintf('%s: %s', ME.identifier, ME.message);
        end
        out(end+1,1) = row; %#ok<AGROW>
    end
end
