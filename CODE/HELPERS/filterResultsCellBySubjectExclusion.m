function [resultsCellOut, excludedSubjectIDs] = filterResultsCellBySubjectExclusion(resultsCellIn, varargin)
% filterResultsCellBySubjectExclusion - Remove excluded subjects from resultsCell.
%
% Usage:
%   [rcOut, excluded] = filterResultsCellBySubjectExclusion(resultsCellIn)
%
% Optional name-value:
%   'excludedIDs' - explicit cellstr/string list of subject IDs to exclude.

    p = inputParser;
    addParameter(p, 'excludedIDs', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    parse(p, varargin{:});

    excludedIDs = p.Results.excludedIDs;
    if ischar(excludedIDs) || isstring(excludedIDs)
        excludedIDs = cellstr(string(excludedIDs));
    end
    if isempty(excludedIDs)
        excludedIDs = loadSubjectExclusionList();
    end
    excludedIDs = upper(strtrim(string(excludedIDs)));
    excludedIDs = unique(cellstr(excludedIDs(excludedIDs ~= "")), 'stable');

    keep = true(numel(resultsCellIn), 1);
    for i = 1:numel(resultsCellIn)
        sid = "";
        rc = resultsCellIn{i};
        if isstruct(rc) && isfield(rc, 'subjectID') && ~isempty(rc.subjectID)
            sid = upper(strtrim(string(rc.subjectID)));
        end
        if sid ~= "" && ismember(char(sid), excludedIDs)
            keep(i) = false;
        end
    end

    resultsCellOut = resultsCellIn(keep);
    excludedSubjectIDs = excludedIDs;
end

