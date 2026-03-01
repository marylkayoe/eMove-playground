function R = plotKsBodyPartStickFigurePanel(ksTbl, varargin)
% plotKsBodyPartStickFigurePanel - Panel of body-part stick-figure KS maps for multiple emotion pairs.
%
% Usage:
%   plotKsBodyPartStickFigurePanel(ksTbl)
%   plotKsBodyPartStickFigurePanel(ksTbl, 'emotionPairs', {'FEAR','JOY'; 'DISGUST','FEAR'})
%
% Name-value pairs:
%   'emotionPairs'     - Nx2 cell array of emotion labels (default all pairs found in ksTbl)
%   'maxPairs'         - maximum number of pairs to plot if auto-selected (default 6)
%   'sortByMeanKs'     - sort auto pairs by mean ksD descending (default true)
%   'useSharedCLim'    - use one color scale across all tiles (default true)
%   'sharedCLim'       - shared color limits across panels (default auto)
%   'valueField'       - field to color by (default 'ksD')
%   'aggFcn'           - 'median' (default) or 'mean'
%   'minSubjects'      - minimum subjects per marker group (default 1)
%   'annotateDelta'    - annotate deltaMedian_sorted (default false)
%   'annotateField'    - annotation field (default 'deltaMedian_sorted')
%   'showValues'       - show D values on body-part labels (default true)
%   'titleText'        - panel title
%   'colormapName'     - colormap for all panels (default 'turbo')
%
% Output:
%   R struct with figure, tiledlayout, pairsUsed, panelOutputs

    p = inputParser;
    addRequired(p, 'ksTbl', @istable);
    addParameter(p, 'emotionPairs', {}, @(x) iscell(x) || isstring(x));
    addParameter(p, 'maxPairs', 6, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'sortByMeanKs', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'useSharedCLim', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'sharedCLim', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    addParameter(p, 'valueField', 'ksD', @(x) ischar(x) || isstring(x));
    addParameter(p, 'aggFcn', 'median', @(x) ischar(x) || isstring(x));
    addParameter(p, 'minSubjects', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'annotateDelta', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'annotateField', 'deltaMedian_sorted', @(x) ischar(x) || isstring(x));
    addParameter(p, 'showValues', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'titleText', 'Body-part discriminability across emotion pairs', @(x) ischar(x) || isstring(x));
    addParameter(p, 'colormapName', 'turbo');
    parse(p, ksTbl, varargin{:});

    pairs = localResolvePairs(ksTbl, p.Results.emotionPairs, p.Results.sortByMeanKs, p.Results.maxPairs);
    nPairs = size(pairs, 1);
    nCols = min(3, nPairs);
    nRows = ceil(nPairs / nCols);

    sharedCLim = p.Results.sharedCLim;
    if p.Results.useSharedCLim
        if isempty(sharedCLim)
            sharedCLim = localSharedCLim(ksTbl, pairs, ...
                char(string(p.Results.valueField)), ...
                char(string(p.Results.aggFcn)), ...
                p.Results.minSubjects);
        end
    else
        sharedCLim = [];
    end

    fig = figure('Color', 'w');
    tl = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
    tl.Units = 'normalized';
    tl.Position = [0.03 0.03 0.84 0.94]; % leave room on the right for colorbar
    title(tl, char(string(p.Results.titleText)), 'FontWeight', 'bold', 'FontSize', 14);

    panelOutputs = cell(nPairs, 1);
    for i = 1:nPairs
        ax = nexttile(tl, i);
        pair = pairs(i, :);
        thisCLim = sharedCLim;
        if ~p.Results.useSharedCLim
            thisCLim = [];
        end
        panelOutputs{i} = plotKsBodyPartStickFigure(ksTbl, pair, ...
            'plotWhere', ax, ...
            'aggFcn', p.Results.aggFcn, ...
            'minSubjects', p.Results.minSubjects, ...
            'valueField', p.Results.valueField, ...
            'annotateDelta', p.Results.annotateDelta, ...
            'annotateField', p.Results.annotateField, ...
            'showValues', p.Results.showValues, ...
            'showColorbar', false, ...
            'cLim', thisCLim, ...
            'colormapName', p.Results.colormapName, ...
            'titleText', sprintf('%s-%s', pair{1}, pair{2}));
    end

    % Colorbar / legend
    if p.Results.useSharedCLim
        colormap(fig, localPanelColormap(p.Results.colormapName));
        cax = axes(fig, 'Visible', 'off', 'Units', 'normalized', 'Position', [0.89 0.12 0.001 0.76]); %#ok<LAXES>
        colormap(cax, localPanelColormap(p.Results.colormapName));
        caxis(cax, sharedCLim);
        cb = colorbar(cax, 'Location', 'eastoutside');
        cb.Label.String = char(string(p.Results.valueField));
        cb.FontSize = 10;
    else
        % Per-tile scaling: show a normalized legend so the palette is visible.
        cax = axes(fig, 'Visible', 'off', 'Units', 'normalized', 'Position', [0.89 0.12 0.001 0.76]); %#ok<LAXES>
        colormap(cax, localPanelColormap(p.Results.colormapName));
        caxis(cax, [0 1]);
        cb = colorbar(cax, 'Location', 'eastoutside');
        cb.Label.String = sprintf('%s (per-tile scale)', char(string(p.Results.valueField)));
        cb.FontSize = 10;
    end

    R = struct();
    R.figure = fig;
    R.tiledlayout = tl;
    R.pairsUsed = pairs;
    R.panelOutputs = panelOutputs;
    R.sharedCLim = sharedCLim;
    R.colorbar = cb;
end

function pairs = localResolvePairs(ksTbl, emotionPairsIn, sortByMeanKs, maxPairs)
    if ~isempty(emotionPairsIn)
        pairs = localNormalizePairsInput(emotionPairsIn);
        return;
    end

    emoA = string(ksTbl.emotionA);
    emoB = string(ksTbl.emotionB);
    pr = sort([emoA emoB], 2);
    pairLabels = pr(:,1) + "-" + pr(:,2);
    uPairs = unique(pairLabels, 'stable');

    if sortByMeanKs && ismember('ksD', ksTbl.Properties.VariableNames)
        score = nan(numel(uPairs),1);
        for i = 1:numel(uPairs)
            score(i) = mean(ksTbl.ksD(pairLabels == uPairs(i)), 'omitnan');
        end
        [~, ord] = sort(score, 'descend', 'MissingPlacement', 'last');
        uPairs = uPairs(ord);
    end

    uPairs = uPairs(1:min(maxPairs, numel(uPairs)));
    pairs = cell(numel(uPairs), 2);
    for i = 1:numel(uPairs)
        sp = split(uPairs(i), "-");
        pairs{i,1} = char(sp(1));
        pairs{i,2} = char(sp(2));
    end
end

function pairs = localNormalizePairsInput(x)
    if isstring(x)
        x = cellstr(x);
    end
    if iscell(x) && numel(x) == 2 && (ischar(x{1}) || isstring(x{1}))
        x = reshape(x, 1, 2);
    end
    if ~iscell(x) || size(x,2) ~= 2
        error('plotKsBodyPartStickFigurePanel:BadPairs', 'emotionPairs must be Nx2 cell array.');
    end
    pairs = cell(size(x,1), 2);
    for i = 1:size(x,1)
        p = sort(string(x(i, :)));
        pairs{i,1} = char(p(1));
        pairs{i,2} = char(p(2));
    end
end

function cLim = localSharedCLim(ksTbl, pairs, valueField, aggFcnName, minSubjects)
    if ~ismember(valueField, ksTbl.Properties.VariableNames)
        cLim = [0 1];
        return;
    end

    switch lower(aggFcnName)
        case 'median'
            agg = @(x) median(x, 'omitnan');
        case 'mean'
            agg = @(x) mean(x, 'omitnan');
        otherwise
            agg = @(x) median(x, 'omitnan');
    end

    emoA = string(ksTbl.emotionA);
    emoB = string(ksTbl.emotionB);
    pr = sort([emoA emoB], 2);
    labels = pr(:,1) + "-" + pr(:,2);

    vals = [];
    for i = 1:size(pairs,1)
        lbl = string(pairs{i,1}) + "-" + string(pairs{i,2});
        Tpair = ksTbl(labels == lbl, :);
        if isempty(Tpair), continue; end

        grpNames = unique(Tpair.markerGroup, 'stable');
        for g = 1:numel(grpNames)
            Tg = Tpair(strcmp(Tpair.markerGroup, grpNames{g}), :);
            if isempty(Tg), continue; end
            subj = unique(Tg.subjectID, 'stable');
            subjVals = nan(numel(subj),1);
            for s = 1:numel(subj)
                m = strcmp(Tg.subjectID, subj{s});
                subjVals(s) = agg(Tg.(valueField)(m));
            end
            if sum(~isnan(subjVals)) >= minSubjects
                vals(end+1,1) = agg(subjVals); %#ok<AGROW>
            end
        end
    end

    vals = vals(isfinite(vals));
    if isempty(vals)
        cLim = [0 1];
    elseif numel(unique(vals)) == 1
        cLim = [max(0, vals(1)-0.05), vals(1)+0.05];
    else
        cLim = [min(vals), max(vals)];
    end
end

function cmap = localPanelColormap(cmapIn)
    if ischar(cmapIn) || isstring(cmapIn)
        switch lower(char(string(cmapIn)))
            case 'turbo'
                cmap = turbo(256);
            case 'parula'
                cmap = parula(256);
            otherwise
                cmap = parula(256);
        end
    elseif isnumeric(cmapIn) && size(cmapIn,2) == 3
        cmap = cmapIn;
    else
        cmap = parula(256);
    end
end
