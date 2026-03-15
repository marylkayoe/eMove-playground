function excludedIDs = loadSubjectExclusionList(varargin)
% loadSubjectExclusionList - Load excluded subject IDs from project CSV.
%
% Usage:
%   excludedIDs = loadSubjectExclusionList()
%   excludedIDs = loadSubjectExclusionList('csvPath', '/path/subject_exclusions.csv')
%
% Output:
%   excludedIDs - cellstr of uppercase subject IDs with exclude=true.

    p = inputParser;
    addParameter(p, 'csvPath', '', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});

    csvPath = char(string(p.Results.csvPath));
    if isempty(csvPath)
        csvPath = localDefaultExclusionCsvPath();
    end

    % Fallback defaults if CSV is missing/unreadable.
    fallback = {'JANNE', 'AS2302', 'XC1301', 'AB1502'};

    if ~isfile(csvPath)
        excludedIDs = fallback;
        return;
    end

    try
        opts = detectImportOptions(csvPath, 'VariableNamingRule', 'preserve');
        opts = setvartype(opts, intersect({'subjectID','exclude'}, opts.VariableNames, 'stable'), 'string');
        T = readtable(csvPath, opts);

        if ~ismember('subjectID', T.Properties.VariableNames)
            excludedIDs = fallback;
            return;
        end

        if ismember('exclude', T.Properties.VariableNames)
            keep = localToLogical(T.exclude);
        else
            keep = true(height(T), 1);
        end

        ids = upper(strtrim(string(T.subjectID)));
        ids = ids(keep & ids ~= "");
        excludedIDs = unique(cellstr(ids), 'stable');
        if isempty(excludedIDs)
            excludedIDs = fallback;
        end
    catch
        excludedIDs = fallback;
    end
end

function out = localToLogical(v)
    if islogical(v), out = v; return; end
    if isnumeric(v), out = v ~= 0; return; end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end

function csvPath = localDefaultExclusionCsvPath()
    thisFile = mfilename('fullpath');
    helpersDir = fileparts(thisFile);
    codeDir = fileparts(helpersDir);
    repoRoot = fileparts(codeDir);
    csvPath = fullfile(repoRoot, 'resources', 'project', 'subject_exclusions.csv');
end

