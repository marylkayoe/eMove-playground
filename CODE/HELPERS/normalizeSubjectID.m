function [subjectID, isValid] = normalizeSubjectID(rawID, varargin)
% normalizeSubjectID - Normalize subject IDs to uppercase and validate format.
%
% Usage:
%   [subjectID, isValid] = normalizeSubjectID(rawID)
%   [subjectID, isValid] = normalizeSubjectID(rawID, 'idPattern', '^[A-Z]{2}\\d{4}$')
%
% Inputs:
%   rawID - char/string value from file names, folder names, or tables.
%
% Name-value pairs:
%   'idPattern' - regex for validity check (default: two letters + four digits)
%
% Outputs:
%   subjectID - normalized uppercase ID (non-alphanumeric removed from edges)
%   isValid   - true if subjectID matches idPattern

    p = inputParser;
    addRequired(p, 'rawID', @(x) ischar(x) || isstring(x));
    addParameter(p, 'idPattern', '^[A-Z]{2}\\d{4}$', @(x) ischar(x) || isstring(x));
    parse(p, rawID, varargin{:});

    subjectID = char(string(p.Results.rawID));
    subjectID = strtrim(subjectID);
    subjectID = regexprep(subjectID, '^"|"$', '');
    subjectID = upper(subjectID);

    % Keep core token characters; this helps with accidental spaces/punctuation.
    subjectID = regexprep(subjectID, '[^A-Z0-9]', '');

    if isempty(subjectID)
        isValid = false;
        return;
    end

    isValid = ~isempty(regexp(subjectID, char(string(p.Results.idPattern)), 'once'));
end
