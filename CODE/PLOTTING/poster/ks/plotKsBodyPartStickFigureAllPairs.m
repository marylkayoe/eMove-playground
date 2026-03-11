function R = plotKsBodyPartStickFigureAllPairs(ksTbl, varargin)
% plotKsBodyPartStickFigureAllPairs - Tiled stick-figure KS maps for all emotion pairs in ksTbl.
%
% Usage:
%   plotKsBodyPartStickFigureAllPairs(ksTbl)
%   plotKsBodyPartStickFigureAllPairs(ksTbl, 'annotateDelta', true)
%
% This is a convenience wrapper around plotKsBodyPartStickFigurePanel that
% auto-detects all unique emotion pairs present in ksTbl and plots them all.
%
% Inputs:
%   ksTbl - table with columns emotionA, emotionB, markerGroup, ksD, ...
%
% Name-value pairs:
%   'excludeEmotions' - emotion labels to exclude from displayed pairs (default {})
%   'includeEmotions' - if non-empty, only use pairs composed of these emotions (default {})
%   Forwarded to plotKsBodyPartStickFigurePanel (except emotionPairs/maxPairs).
%
% Output:
%   R - struct returned by plotKsBodyPartStickFigurePanel

    p = inputParser;
    p.KeepUnmatched = true;
    addRequired(p, 'ksTbl', @istable);
    addParameter(p, 'excludeEmotions', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'includeEmotions', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    parse(p, ksTbl, varargin{:});

    if ~istable(ksTbl)
        error('plotKsBodyPartStickFigureAllPairs:BadInput', 'ksTbl must be a table.');
    end
    needed = {'emotionA','emotionB'};
    for i = 1:numel(needed)
        if ~ismember(needed{i}, ksTbl.Properties.VariableNames)
            error('plotKsBodyPartStickFigureAllPairs:MissingVar', ...
                'ksTbl missing required variable "%s".', needed{i});
        end
    end

    emoA = string(ksTbl.emotionA);
    emoB = string(ksTbl.emotionB);

    includeEmotions = string(cellstr(string(p.Results.includeEmotions)));
    excludeEmotions = string(cellstr(string(p.Results.excludeEmotions)));
    keep = true(size(emoA));
    if ~isempty(includeEmotions)
        keep = keep & ismember(emoA, includeEmotions) & ismember(emoB, includeEmotions);
    end
    if ~isempty(excludeEmotions)
        keep = keep & ~ismember(emoA, excludeEmotions) & ~ismember(emoB, excludeEmotions);
    end
    ksTblFiltered = ksTbl(keep, :);

    panelArgs = localForwardArgs(varargin, {'excludeEmotions','includeEmotions'});

    R = plotKsBodyPartStickFigurePanel(ksTblFiltered, ...
        panelArgs{:});
end

function out = localForwardArgs(args, blockedKeys)
    out = {};
    i = 1;
    while i <= numel(args)
        if ~(ischar(args{i}) || isstring(args{i}))
            i = i + 1;
            continue;
        end
        if i == numel(args)
            break;
        end
        key = char(string(args{i}));
        val = args{i+1};
        if ~any(strcmpi(key, blockedKeys))
            out(end+1:end+2) = {key, val}; %#ok<AGROW>
        end
        i = i + 2;
    end
end
