function plotMotionMetricsSummary(resultsCell, varargin)
% plotMotionMetricsSummary - Aggregate motion metrics across subjects and plot violin plots.
%
%   plotMotionMetricsSummary(resultsCell, ...)
%
% Inputs:
%   resultsCell - cell array from runMotionMetricsBatch (each entry has .results)
%
% Optional name-value pairs:
%   'markerGroupNames' - order of marker groups to plot (default: inferred)
%   'showRaw'          - logical, overlay jittered raw points (default: false)
%   'outlierQuantile'  - upper quantile cutoff to drop extremes (default: 0.99; set [] to disable)
%
% Behavior:
%   Creates a single figure with three panels (averageSpeed, mad3d,
%   spectralArcLength). Each panel shows a violin plot per marker group
%   pooling per-marker values across all subjects and videos.

    p = inputParser;
    addRequired(p, 'resultsCell', @iscell);
    addParameter(p, 'markerGroupNames', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'showRaw', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'outlierQuantile', 0.99, @(x) isempty(x) || (isscalar(x) && x>0 && x<1));
    parse(p, resultsCell, varargin{:});

    markerGroupNames = p.Results.markerGroupNames;
    if ischar(markerGroupNames) || isstring(markerGroupNames)
        markerGroupNames = cellstr(markerGroupNames);
    end

    % Infer marker group names if not provided
    if isempty(markerGroupNames)
        markerGroupNames = inferMarkerGroups(resultsCell);
    end

    metricsList = { ...
        'averageSpeed',      'Average speed (mm/s)'; ...
        'mad3d',             'MAD radius (mm)'; ...
        'spectralArcLength', 'Spectral arc length' ...
        };

    nGroups = numel(markerGroupNames);
    nCols = 3; nRows = 1; % three panels (metrics)

    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');

    for m = 1:size(metricsList,1)
        metricName = metricsList{m,1};
        metricLabel = metricsList{m,2};

        valsAll = cell(1, nGroups);
        for g = 1:nGroups
            valsAll{g} = collectValues(resultsCell, markerGroupNames{g}, metricName, p.Results.outlierQuantile);
        end

        nexttile;
        hold on;
        % simple violin via kernel density mirrored
        for g = 1:nGroups
            vals = valsAll{g};
            if isempty(vals), continue; end
            [f, xi] = ksdensity(vals);
            f = f / max(f); % normalize width
            width = 0.4;
            xLeft = g - f*width;
            xRight = g + f*width;
            patch([xLeft, fliplr(xRight)], [xi, fliplr(xi)], [0.6 0.8 1], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
            if p.Results.showRaw
                scatter(g + 0.02*randn(size(vals)), vals, 8, 'k', 'filled', 'MarkerFaceAlpha', 0.4);
            end
            medv = median(vals,'omitnan');
            plot([g-0.3 g+0.3], [medv medv], 'k-', 'LineWidth', 1.5);
        end
        xlim([0.5, nGroups+0.5]);
        set(gca, 'XTick', 1:nGroups, 'XTickLabel', markerGroupNames);
        xtickangle(30);
        ylabel(metricLabel);
        title(metricLabel);
        grid on;
    end
    sgtitle('Pooled motion metrics across subjects (all stim videos)');
end

function names = inferMarkerGroups(resultsCell)
    names = {};
    for i = 1:numel(resultsCell)
        rc = resultsCell{i};
        if ~isfield(rc, 'results'), continue; end
        rArr = rc.results;
        if isempty(rArr), continue; end
        names = unique([names; {rArr.markerGroupName}'], 'stable');
    end
end

function vals = collectValues(resultsCell, groupName, fieldName, outlierQuantile)
    vals = [];
    for i = 0:numel(resultsCell)-1
        % (For clarity and to avoid off-by-one, explicit loop below.)
    end
    for i = 1:numel(resultsCell)
        rc = resultsCell{i};
        if ~isfield(rc, 'results'), continue; end
        rArr = rc.results;
        for r = 1:numel(rArr)
            if ~isfield(rArr(r), 'markerGroupName') || ~strcmp(rArr(r).markerGroupName, groupName)
                continue;
            end
            if ~isfield(rArr(r), 'perMarkerMetrics'), continue; end
            pm = rArr(r).perMarkerMetrics;
            for k = 1:numel(pm)
                if isfield(pm{k}, fieldName)
                    v = pm{k}.(fieldName);
                    if isnumeric(v)
                        vals = [vals; v(:)]; %#ok<AGROW>
                    end
                end
            end
        end
    end
    vals = vals(~isnan(vals));
    if ~isempty(outlierQuantile) && ~isempty(vals)
        cutoff = quantile(vals, outlierQuantile);
        vals(vals > cutoff) = [];
    end
end
