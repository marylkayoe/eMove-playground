function [M, markerGroups, pairLabels] = plotKsHeatmap(ksTbl, varargin)
% plotKsHeatmap - Plot a heatmap of KS distances aggregated across subjects.
%
% Usage:
%   plotKsHeatmap(ksTbl)
%   plotKsHeatmap(ksTbl, 'excludeMarkerGroups', {'L-leg','R-leg'}, 'excludeEmotions', {'FEAR'})
%
% Inputs:
%   ksTbl - table with columns:
%       subjectID, markerGroup, emotionA, emotionB, ksD
%
% Name-value pairs:
%   'excludeMarkerGroups'  - cellstr of markerGroup names to remove (default {})
%   'includeMarkerGroups'  - cellstr; if non-empty, keeps only these (default {})
%   'excludeEmotions'      - cellstr of emotions to remove if in either A or B (default {})
%   'includeEmotions'      - cellstr; if non-empty, keeps only pairs using these emotions (default {})
%   'excludePairs'         - cell array Nx2 of emotion labels to exclude (order-insensitive) (default {})
%   'includePairs'         - cell array Nx2 of emotion labels to include (order-insensitive) (default {})
%   'aggFcn'               - 'median' (default) or 'mean'
%   'minSubjects'          - require at least this many subjects per cell (default 1)
%   'sortPairsByMean'      - logical; sort pair columns by overall mean KS (default true)
%   'sortMarkersByMean'    - logical; sort marker rows by overall mean KS (default false)
%   'titleText'            - char/string for plot title (default 'Median KS distance across subjects')
%
% Outputs:
%   M            - nMarkers x nPairs matrix of aggregated KS distances
%   markerGroups - cellstr row labels
%   pairLabels   - cellstr column labels

    p = inputParser;
    addRequired(p, 'ksTbl', @(x) istable(x));
    addParameter(p, 'excludeMarkerGroups', {}, @(x) iscell(x) || isstring(x));
    addParameter(p, 'includeMarkerGroups', {}, @(x) iscell(x) || isstring(x));
    addParameter(p, 'excludeEmotions', {}, @(x) iscell(x) || isstring(x));
    addParameter(p, 'includeEmotions', {}, @(x) iscell(x) || isstring(x));
    addParameter(p, 'excludePairs', {}, @(x) iscell(x));
    addParameter(p, 'includePairs', {}, @(x) iscell(x));
    addParameter(p, 'aggFcn', 'median', @(x) ischar(x) || isstring(x));
    addParameter(p, 'minSubjects', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'sortPairsByMean', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'sortMarkersByMean', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'titleText', 'Median KS distance across subjects', @(x) ischar(x) || isstring(x));
    addParameter(p, 'annotate', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'annotateField', 'deltaMedian_sorted', @(x) ischar(x) || isstring(x));
addParameter(p, 'annotateFormat', '%+.2f', @(x) ischar(x) || isstring(x));
addParameter(p, 'annotateKs', true, @(x) islogical(x) && isscalar(x)); % if you want ksD printed too

    parse(p, ksTbl, varargin{:});

    excludeMarkerGroups = cellstr(string(p.Results.excludeMarkerGroups));
    includeMarkerGroups = cellstr(string(p.Results.includeMarkerGroups));
    excludeEmotions = cellstr(string(p.Results.excludeEmotions));
    includeEmotions = cellstr(string(p.Results.includeEmotions));
    excludePairs = p.Results.excludePairs;
    includePairs = p.Results.includePairs;
    aggFcnName = char(string(p.Results.aggFcn));
    minSubjects = p.Results.minSubjects;

    % --- basic column checks ---
    neededVars = {'subjectID','markerGroup','emotionA','emotionB','ksD'};
    for k = 1:numel(neededVars)
        if ~ismember(neededVars{k}, ksTbl.Properties.VariableNames)
            error('plotKsHeatmap:MissingVar', 'ksTbl missing required variable "%s".', neededVars{k});
        end
    end

    % --- filter marker groups ---
    if ~isempty(includeMarkerGroups)
        ksTbl = ksTbl(ismember(ksTbl.markerGroup, includeMarkerGroups), :);
    end
    if ~isempty(excludeMarkerGroups)
        ksTbl = ksTbl(~ismember(ksTbl.markerGroup, excludeMarkerGroups), :);
    end

    % --- filter emotions ---
    if ~isempty(includeEmotions)
        keepEmo = ismember(ksTbl.emotionA, includeEmotions) & ismember(ksTbl.emotionB, includeEmotions);
        ksTbl = ksTbl(keepEmo, :);
    end
    if ~isempty(excludeEmotions)
        dropEmo = ismember(ksTbl.emotionA, excludeEmotions) | ismember(ksTbl.emotionB, excludeEmotions);
        ksTbl = ksTbl(~dropEmo, :);
    end

    % --- build order-insensitive pair labels using sort() ---
    emoA = string(ksTbl.emotionA);
    emoB = string(ksTbl.emotionB);
    emoPairsSorted = sort([emoA emoB], 2);
    pairLabelStr = emoPairsSorted(:,1) + "-" + emoPairsSorted(:,2);  % use '-' for simple x-tick readability
    ksTbl.pairLabel = cellstr(pairLabelStr);

    % --- include/exclude specific pairs (order-insensitive) ---
    if ~isempty(includePairs)
        includePairLabels = localPairsToLabels(includePairs);
        ksTbl = ksTbl(ismember(ksTbl.pairLabel, includePairLabels), :);
    end
    if ~isempty(excludePairs)
        excludePairLabels = localPairsToLabels(excludePairs);
        ksTbl = ksTbl(~ismember(ksTbl.pairLabel, excludePairLabels), :);
    end

    if isempty(ksTbl)
        warning('plotKsHeatmap:EmptyAfterFilter', 'No rows left after filtering.');
        M = [];
        markerGroups = {};
        pairLabels = {};
        return;
    end

    % --- choose aggregation function ---
    switch lower(aggFcnName)
        case 'median'
            aggFcn = @(x) median(x, 'omitnan');
        case 'mean'
            aggFcn = @(x) mean(x, 'omitnan');
        otherwise
            error('plotKsHeatmap:BadAggFcn', 'aggFcn must be "median" or "mean".');
    end

    markerGroups = unique(ksTbl.markerGroup, 'stable');
    pairLabels = unique(ksTbl.pairLabel, 'stable');

    % --- compute matrix with subject-level aggregation first, then across subjects ---
    % We want: for each markerGroup x pairLabel, aggregate ksD across subjects.
    % If you have multiple ksD rows per subject for same cell (shouldn't, but just in case),
    % we aggregate within-subject first.
    M = nan(numel(markerGroups), numel(pairLabels));
    nSubj = zeros(size(M));

    for i = 1:numel(markerGroups)
        for j = 1:numel(pairLabels)
            cellMask = strcmp(ksTbl.markerGroup, markerGroups{i}) & strcmp(ksTbl.pairLabel, pairLabels{j});
            if ~any(cellMask)
                continue;
            end

            Tcell = ksTbl(cellMask, :);

            % within-subject collapse (defensive)
            subjList = unique(Tcell.subjectID, 'stable');
            subjVals = nan(numel(subjList), 1);
            for s = 1:numel(subjList)
                sMask = strcmp(Tcell.subjectID, subjList{s});
                subjVals(s) = aggFcn(Tcell.ksD(sMask));
            end

            nSubj(i,j) = sum(~isnan(subjVals));
            if nSubj(i,j) < minSubjects
                continue;
            end
            M(i,j) = aggFcn(subjVals);
        end
    end

    annotateField = char(string(p.Results.annotateField));
doAnnotate = p.Results.annotate;

A = nan(size(M));
if doAnnotate
    if ~ismember(annotateField, ksTbl.Properties.VariableNames)
        warning('plotKsHeatmap:AnnotateMissingField', ...
            'annotateField "%s" not in ksTbl; skipping annotations.', annotateField);
        doAnnotate = false;
    end
end

if doAnnotate
    for i = 1:numel(markerGroups)
        for j = 1:numel(pairLabels)
            cellMask = strcmp(ksTbl.markerGroup, markerGroups{i}) & strcmp(ksTbl.pairLabel, pairLabels{j});
            if ~any(cellMask), continue; end

            Tcell = ksTbl(cellMask, :);

            subjList = unique(Tcell.subjectID, 'stable');
            subjVals = nan(numel(subjList), 1);
            for s = 1:numel(subjList)
                sMask = strcmp(Tcell.subjectID, subjList{s});
                subjVals(s) = aggFcn(Tcell.(annotateField)(sMask));
            end

            if sum(~isnan(subjVals)) < minSubjects
                continue;
            end
            A(i,j) = aggFcn(subjVals);
        end
    end
end



    % --- optional sorting by overall mean effect size ---
    if p.Results.sortPairsByMean
        colScore = mean(M, 1, 'omitnan');
        [~, order] = sort(colScore, 'descend', 'MissingPlacement','last');
        M = M(:, order);
        pairLabels = pairLabels(order);
        nSubj = nSubj(:, order);
    end
    if p.Results.sortMarkersByMean
        rowScore = mean(M, 2, 'omitnan');
        [~, order] = sort(rowScore, 'descend', 'MissingPlacement','last');
        M = M(order, :);
        markerGroups = markerGroups(order);
        nSubj = nSubj(order, :);
    end

    % --- plot ---
ksMin = 0.1;   % choose this explicitly (see note below)

figure;
ax = axes;
imagesc(M, 'Parent', ax);
colormap(ax, parula);
colorbar;
axis(ax, 'equal');
axis(ax, 'tight');

% --- Black background
set(ax, 'Color', 'k');

% --- Alpha mask: hide low-KS cells
alphaMask = ones(size(M));
alphaMask(M < ksMin | isnan(M)) = 0;
set(findobj(ax,'Type','Image'), 'AlphaData', alphaMask);


    if doAnnotate
        fmt = char(string(p.Results.annotateFormat));
        annotateKs = p.Results.annotateKs;

        for i = 1:size(M,1)
            for j = 1:size(M,2)

                if isnan(M(i,j))
                    continue;
                end

                % --- decide text + color depending on relevance ---
                isSmall = M(i,j) < ksMin;

                if annotateKs
                    if isnan(A(i,j))
                        tStr = sprintf('D=%.2f', M(i,j));
                    else
                        tStr = sprintf('D=%.2f\n' + string(fmt), M(i,j), A(i,j));
                    end
                else
                    if isnan(A(i,j))
                        continue;
                    end
                    tStr = sprintf(fmt, A(i,j));
                end

                if isSmall
                    txtColor = 'w';   % white on black
                else
                    txtColor = 'k';   % black on colormap
                end

                text(j, i, tStr, ...
                    'HorizontalAlignment','center', ...
                    'VerticalAlignment','middle', ...
                    'FontSize', 9, ...
                    'Color', txtColor);
            end
        end
    end

    title(char(string(p.Results.titleText)));

    set(gca, 'YTick', 1:numel(markerGroups), 'YTickLabel', markerGroups);
    set(gca, 'XTick', 1:numel(pairLabels), 'XTickLabel', pairLabels);
    xtickangle(45);

    ylabel('markerGroup');
    xlabel('emotion pair (sorted; annotation sign = emo2 - emo1)');

    % Optional: show missing cells as NaN (imagesc will render them as lowest color)
    % If you want a clearer missing-data look, we can apply an alpha mask.

end

function pairLabels = localPairsToLabels(pairs)
    % pairs: cell array Nx2, order-insensitive
    if isempty(pairs)
        pairLabels = {};
        return;
    end
    if isstring(pairs)
        pairs = cellstr(pairs);
    end
    if size(pairs,2) ~= 2
        error('Pairs must be Nx2 cell array.');
    end
    pairLabels = cell(size(pairs,1),1);
    for i = 1:size(pairs,1)
        p = sort(string(pairs(i,:)));
        pairLabels{i} = char(p(1) + "-" + p(2));
    end
end
