function [groupedMarkerNames, groupedBodypartNames, markerTbl, groupTbl] = loadBodypartGroupingCSV(csvPath)
% loadBodypartGroupingCSV Load marker grouping CSV and return classic cell arrays.
%
% CSV must contain at least:
%   markerName, groupName, include

    if ~(ischar(csvPath) || isstring(csvPath))
        error('loadBodypartGroupingCSV:BadInput', 'csvPath must be char or string.');
    end
    csvPath = char(string(csvPath));
    if ~isfile(csvPath)
        error('loadBodypartGroupingCSV:MissingFile', 'File not found: %s', csvPath);
    end

    opts = detectImportOptions(csvPath, 'VariableNamingRule', 'preserve');
    wantStr = {'markerName','groupName','suggestedGroup','suggestedSide','notes'};
    present = intersect(wantStr, opts.VariableNames, 'stable');
    if ~isempty(present)
        opts = setvartype(opts, present, 'string');
    end
    markerTbl = readtable(csvPath, opts);

    if ~ismember('include', markerTbl.Properties.VariableNames)
        markerTbl.include = true(height(markerTbl), 1);
    end
    markerTbl.include = localToLogical(markerTbl.include);

    [groupedMarkerNames, groupedBodypartNames, groupTbl] = ...
        buildMarkerGroupsFromAssignmentTable(markerTbl);
end

function out = localToLogical(v)
    if islogical(v)
        out = v;
        return;
    end
    if isnumeric(v)
        out = v ~= 0;
        return;
    end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end
