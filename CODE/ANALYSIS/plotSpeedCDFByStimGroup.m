function plotSpeedCDFByStimGroup(outArr, codingTable, varargin)
% plotSpeedCDFByStimGroup - ECDFs of baseline-normalized metrics by stimulus group.
%
%   plotSpeedCDFByStimGroup(outArr, codingTable, ...)
%
% Inputs:
%   outArr      - output from buildNormalizedMetricsBuckets (one entry per marker group)
%   codingTable - table or cell array {videoID, groupCode}; used to map videos to stim groups
%
% Optional name-value:
%   'metric'          - 'speed' (default), 'mad', or 'sal'
%   'outlierQuantile' - upper quantile cutoff to drop outliers (default 0.99; [] to disable)
%
% Behavior:
%   For each marker group (bodypart), pools the selected metric
%   across all videos that belong to each stimulus group (baseline is skipped),
%   plots ECDFs per stim group, and shows simple summary stats (n, median, IQR).
%   A Kruskal-Wallis p-value (effect of stim group) is reported in the title.

    p = inputParser;
    addParameter(p, 'metric', 'speed', @(x) ischar(x) || isstring(x));
    addParameter(p, 'outlierQuantile', 0.99, @(x) isempty(x) || (isscalar(x) && x>0 && x<1));
    addParameter(p, 'stimGroups', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'useImmobile', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'codingName', '', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});
    metric = lower(string(p.Results.metric));
    outlierQuantile = p.Results.outlierQuantile;
    stimGroupsOverride = p.Results.stimGroups;
    if ischar(stimGroupsOverride) || isstring(stimGroupsOverride)
        stimGroupsOverride = cellstr(stimGroupsOverride);
    end
    useImmobile = p.Results.useImmobile;
    codingName = string(p.Results.codingName);

    % If codingName not provided, try to infer from codingTable
    if codingName == "" && istable(codingTable)
        varMatches = strcmpi(codingTable.Properties.VariableNames, 'codingName');
        if any(varMatches)
            vals = string(codingTable{:, find(varMatches,1)});
            vals = vals(vals ~= "");
            u = unique(vals);
            if numel(u) == 1
                codingName = u;
            end
        end
    end

    switch metric
        case "speed"
            if useImmobile
                fieldName = 'immobileMedian';
                xLabel = 'Median speed while immobile (mm/s)';
            else
                fieldName = 'speedBuckets';
                xLabel = 'Median speed (fold baseline)';
            end
        case "mad"
            fieldName = 'madBuckets';
            xLabel = 'MAD (fold baseline)';
        case "sal"
            fieldName = 'salBuckets';
            xLabel = 'SAL (fold baseline)';
        otherwise
            error('Unsupported metric: %s', metric);
    end

    nGroups = numel(outArr);
    if nGroups == 0
        warning('No marker groups provided.');
        return;
    end

    % Video ordering and group codes from the first entry
    videoIDs = outArr(1).videoIDs;
    [~, groupCodes, uniqueGroups, groupColorMap] = resolveStimVideoColors(videoIDs, codingTable);
    % Keep baseline for plotting but exclude from stats
    baseMask = strcmp(groupCodes, '0');
    keepMask = ~baseMask;
    videoIDsNoBase = videoIDs(keepMask);
    groupCodesNoBase = groupCodes(keepMask);

    stimGroups = unique(groupCodesNoBase, 'stable');
    if ~isempty(stimGroupsOverride)
        stimGroups = intersect(stimGroups, stimGroupsOverride, 'stable');
    end
    nStim = numel(stimGroups);

    if nStim == 0
        warning('No non-baseline stim groups found.');
        return;
    end

    nCols = min(3, nGroups);
    nRows = ceil(nGroups / nCols);
    figure;
    tl = tiledlayout(nRows, nCols, 'Padding', 'compact', 'TileSpacing', 'compact');
    if codingName ~= ""
        title(tl, codingName, 'FontWeight', 'bold');
    end

    for g = 1:nGroups
        groupOut = outArr(g);
        if ~isfield(groupOut, fieldName)
            continue;
        end
        buckets = groupOut.(fieldName);
        % buckets align to videoIDs; keepMask removes baseline when needed for stats

        % Pool values per stim group
        pooledPerStim = cell(nStim,1);
        for s = 1:nStim
            grpCode = stimGroups{s};
            vidIdxs = find(strcmp(groupCodes, grpCode)); % indices of non-baseline videos in this stim group
            vals = [];
            for k = 1:numel(vidIdxs)
                idx = vidIdxs(k);
                if idx <= numel(buckets)
                    vals = [vals; buckets{idx}(:)]; %#ok<AGROW>
                end
            end
            vals = vals(~isnan(vals));
            if ~isempty(outlierQuantile)
                cutoff = quantile(vals, outlierQuantile);
                vals(vals > cutoff) = [];
            end
            pooledPerStim{s} = vals;
        end

        nexttile; hold on;
        dataAll = [];
        groupAll = {};
        % Plot baseline separately (optional)
        if any(baseMask) && numel(buckets) >= numel(videoIDs)
            baseVals = buckets(baseMask);
            baseVals = vertcat(baseVals{:});
            baseVals = baseVals(~isnan(baseVals));
            if ~isempty(outlierQuantile) && ~isempty(baseVals)
                cutoff = quantile(baseVals, outlierQuantile);
                baseVals(baseVals > cutoff) = [];
            end
            if ~isempty(baseVals)
                [fBase, xBase] = ecdf(baseVals);
                stairs(xBase, fBase, 'Color', [0 0 0], 'LineWidth', 1.2, 'LineStyle', '--');
            end
        end

        for s = 1:nStim
            vals = pooledPerStim{s};
            if isempty(vals), continue; end
            [f, x] = ecdf(vals);
            c = groupColorMap(stimGroups{s});
            stairs(x, f, 'Color', c, 'LineWidth', 1.3);
            nVals = numel(vals);
            dataAll = [dataAll; vals]; %#ok<AGROW>
            groupAll = [groupAll; repmat(stimGroups(s), nVals, 1)]; %#ok<AGROW>
        end
        xlabel(xLabel);
        ylabel('CDF');
        grid on;

        % Kruskal-Wallis across stim groups (nonparametric), excluding baseline
        pKW = NaN;
        posthocTbl = [];
        if numel(unique(groupAll)) > 1
            pKW = kruskalwallis(dataAll, groupAll, 'off');
            % Dunn-Sidak post-hoc comparisons
            try
                [~, ~, stats] = kruskalwallis(dataAll, groupAll, 'off');
                c = multcompare(stats, 'Display', 'off', 'CType', 'dunn-sidak');
                % columns: group1, group2, lowerCI, diff, upperCI, pValue
                posthocTbl = array2table(c, 'VariableNames', {'g1','g2','lower','diff','upper','p'});
                grpLabels = stats.gnames;
                posthocTbl.g1 = grpLabels(posthocTbl.g1);
                posthocTbl.g2 = grpLabels(posthocTbl.g2);
            catch
                posthocTbl = [];
            end
        end
        if isnan(pKW)
            title(sprintf('%s (no stats)', groupOut.targetGroup));
        else
            % significance stars
            if pKW < 0.001
                starStr = '***';
            elseif pKW < 0.01
                starStr = '**';
            elseif pKW < 0.05
                starStr = '*';
            else
                starStr = 'n.s.';
            end
            title(sprintf('%s (KW p=%.3g)', groupOut.targetGroup, pKW));
            text(0.02, 0.95, starStr, 'Units','normalized', 'FontSize',12, 'FontWeight','bold');
            if ~isempty(posthocTbl)
                [minP, idxMin] = min(posthocTbl.p);
                pairStr = sprintf('%s vs %s p=%.3g', posthocTbl.g1{idxMin}, posthocTbl.g2{idxMin}, minP);
                text(0.02, 0.88, pairStr, 'Units','normalized', 'FontSize',10, 'Color',[0.3 0.3 0.3]);
            end
        end
    end

    % Single legend for stim groups, placed inside best location
    if exist('uniqueGroups','var') && ~isempty(uniqueGroups)
        axList = findobj(tl, 'Type', 'Axes');
        if ~isempty(axList)
            axLegend = axList(1); % use first axes for legend anchors
            lgdHandles = gobjects(numel(stimGroups),1);
            for i = 1:numel(stimGroups)
                grp = stimGroups{i};
                c = groupColorMap(grp);
                lgdHandles(i) = line(axLegend, NaN, NaN, 'Color', c, 'LineWidth', 2);
            end
            legend(axLegend, lgdHandles, stimGroups, 'Location', 'southeast');
        end
    end
end
