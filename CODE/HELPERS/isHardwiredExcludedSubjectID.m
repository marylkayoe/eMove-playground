function [isExcluded, subjectID] = isHardwiredExcludedSubjectID(rawSubjectID)
% isHardwiredExcludedSubjectID - File-backed subject exclusion rule.
%
% Purpose:
%   Legacy-compatible helper name kept for callers.
%   Exclusion IDs are loaded from resources/project/subject_exclusions.csv.
%
% Inputs:
%   rawSubjectID - char/string subject identifier from folder or file names.
%
% Outputs:
%   isExcluded - true if subject is in hardwired exclusion list.
%   subjectID  - normalized uppercase subject token used for matching.

    [subjectID, ~] = normalizeSubjectID(rawSubjectID);
    excludedIDs = loadSubjectExclusionList();
    isExcluded = ismember(subjectID, excludedIDs);
end
