function plotMetricsByStimGroup(outArr, codingTable, varargin)
% plotMetricsByStimGroup - Pool metrics by stimulus group and plot violins per marker group.
%
%   plotMetricsByStimGroup(outArr, codingTable, ...)
%
% Inputs:
%   outArr      - output struct array from buildNormalizedMetricsBuckets
%   codingTable - table or cell array {videoID, groupCode}; used to map videos to stim groups
%
% Optional name-value:
%   'metric'           - which metric to plot: 'speed'|'mad'|'sal' (default 'speed')
%   'outlierQuantile'  - upper quantile cutoff to drop outliers (default 0.99; [] to disable)
%
% Behavior:
%   For each marker group, pools the chosen metric across all videos belonging
%   to the same stim group (per codingTable). Baseline group '0' is skipped.
%   Creates a figure with one subplot per marker group; each subplot shows
%   violins for stim groups, colored by group code (baseline color scheme).

    p = inputParser;
    addParameter(p, 'metric', 'speed', @(x) ischar(x) || isstring(x));
    addParameter(p, 'outlierQuantile', 0.99, @(x) isempty(x) || (isscalar(x) && x>0 && x<1));
    parse(p, varargin{:});
    metric = lower(string(p.Results.metric));
    outlierQuantile = p.Results.outlierQuantile;

    switch metric
        case "speed"
            metricField = 'speedBuckets';
            yLabel = 'Median speed (fold baseline)';
        case "mad"
            metricField = 'madBuckets';
            yLabel = 'MAD (fold baseline)';
        case "sal"
            metricField = 'salBuckets';
            yLabel = 'SAL (fold baseline)';
        otherwise
            error('Unsupported metric: %s', metric);
    end

    nGroups = numel(outArr);
    outlineColor = [0 0 0];

    % All groups share the same video ordering
    vids = outArr(1).videoIDs;
    [~, groupCodes, uniqueGroups, groupColorMap] = resolveStimVideoColors(vids, codingTable);

    % Stim groups to plot (exclude baseline/0)
    stimGroups = unique(groupCodes(~strcmp(groupCodes, '0')), 'stable');

    nCols = min(3, nGroups);
    nRows = ceil(nGroups / nCols);
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');

    for groupIdx = 1:nGroups
        % Each outArr entry corresponds to one marker (bodypart) group.
        groupOut = outArr(groupIdx);
        if ~isfield(groupOut, metricField), continue; end
        buckets = groupOut.(metricField); % 1 x nVideos cell array of normalized values
        nexttile; hold on;

        % Loop over stimulus groups (emotion groups), pooling all videos that map to that group.
        for stimIdx = 1:numel(stimGroups)
            grpCode = stimGroups{stimIdx};
            vidIdxs = find(strcmp(groupCodes, grpCode)); % indices of videos belonging to this stim group
            pooled = [];
            for k = 1:numel(vidIdxs)
                if vidIdxs(k) > numel(buckets), continue; end
                pooled = [pooled; buckets{vidIdxs(k)}(:)]; %#ok<AGROW>
            end
            pooled = pooled(~isnan(pooled));
            if isempty(pooled), continue; end
            if ~isempty(outlierQuantile)
                cutoff = quantile(pooled, outlierQuantile);
                pooled(pooled > cutoff) = [];
            end
            if isempty(pooled), continue; end
            [dens, xi] = ksdensity(pooled);
            dens = 0.35 * dens / max(dens);
            col = groupColorMap(grpCode);
            xCenter = stimIdx;
            fill(xCenter + [ -dens, fliplr(dens) ], [xi, fliplr(xi)], col, ...
                'EdgeColor', outlineColor, 'FaceAlpha', 0.6, 'LineWidth', 1);
            medVal = median(pooled, 'omitnan');
            plot([xCenter-0.25 xCenter+0.25], [medVal medVal], 'Color', outlineColor, 'LineWidth', 1.5);
        end

        xlim([0.5 numel(stimGroups)+0.5]);
        set(gca, 'XTick', 1:numel(stimGroups), 'XTickLabel', stimGroups);
        ylabel(yLabel);
        title(sprintf('%s (%s)', groupOut.targetGroup, metric));
        grid on;
    end

    % Legend for stim groups
    if exist('uniqueGroups','var') && ~isempty(uniqueGroups)
        lgdHandles = gobjects(numel(uniqueGroups),1);
        lgdLabels = cell(numel(uniqueGroups),1);
        idx = 0;
        for i = 1:numel(uniqueGroups)
            grp = uniqueGroups{i};
            if strcmp(grp,'0'), continue; end
            idx = idx + 1;
            c = groupColorMap(grp);
            lgdHandles(idx) = plot(NaN, NaN, '-', 'Color', c, 'LineWidth', 2);
            lgdLabels{idx} = grp;
        end
        lgdHandles = lgdHandles(1:idx);
        lgdLabels = lgdLabels(1:idx);
        legend(lgdHandles, lgdLabels, 'Location', 'eastoutside');
    end
end
