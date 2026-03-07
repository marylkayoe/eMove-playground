function [isExcluded, subjectID] = isHardwiredExcludedSubjectID(rawSubjectID)
% isHardwiredExcludedSubjectID - Hardwired exclusion rule for current dataset.
%
% Purpose:
%   This project currently uses one dataset snapshot. For this stage, some
%   subjects are intentionally excluded without configuration indirection.
%
% Inputs:
%   rawSubjectID - char/string subject identifier from folder or file names.
%
% Outputs:
%   isExcluded - true if subject is in hardwired exclusion list.
%   subjectID  - normalized uppercase subject token used for matching.

    [subjectID, ~] = normalizeSubjectID(rawSubjectID);
    excludedIDs = {'JANNE', 'AS2302', 'XC1301'};
    isExcluded = ismember(subjectID, excludedIDs);
end

