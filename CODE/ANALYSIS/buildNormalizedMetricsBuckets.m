function out = buildNormalizedMetricsBuckets(resultsCell, markerGroupNames, varargin)
% buildNormalizedMetricsBuckets - Collect per-marker metrics (baseline-normalized) per video.
%
%   out = buildNormalizedMetricsBuckets(resultsCell, markerGroupNames)
%   out = buildNormalizedMetricsBuckets(..., 'makePlot', true)
%
% Inputs:
%   resultsCell       - cell array from runMotionMetricsBatch (each entry has .results)
%   markerGroupNames  - cell array of marker group names (uses all; if single, still works)
%
% Optional name-value:
%   'makePlot'         - logical (default false) to create quick violin plot summaries
%   'outlierQuantile'  - upper quantile cutoff to drop outliers (default: 0.99, [] disables)
%
% Output:
%   out               - struct array (one per marker group) with fields:
%       .videoIDs       ordered list of video IDs (baseline first if present, others sorted)
%       .speedBuckets   1 x nVideos cell array of fold-change median speeds vs that subject's baseline
%       .madBuckets     1 x nVideos cell array of fold-change MAD vs baseline
%       .salBuckets     1 x nVideos cell array of fold-change SAL vs baseline
%       .immobileFrac   1 x nVideos cell array of percent immobile (not normalized)
%       .immobileMedian 1 x nVideos cell array of median speed while immobile (not normalized)
%       .mobileMean     1 x nVideos cell array of mean speed while mobile (not normalized)
%       .targetGroup    marker group name
%       .counts         counts per video bucket (speed)
%
% Notes:
%   - Speeds are normalized to per-subject baseline for the same marker (median speed).
%   - MAD and SAL are likewise normalized to each subject's baseline for that marker.
%   - If some videos are missing, their bucket will be empty.

    p = inputParser;
    addParameter(p, 'makePlot', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'outlierQuantile', 0.99, @(x) isempty(x) || (isscalar(x) && x>0 && x<1));
    parse(p, varargin{:});

    if ischar(markerGroupNames) || isstring(markerGroupNames)
        markerGroupNames = cellstr(markerGroupNames);
    end
    if isrow(markerGroupNames); markerGroupNames = markerGroupNames(:); end
    % ensure unique group names to avoid over-allocation when duplicates are present
    markerGroupNames = unique(markerGroupNames, 'stable');

    % Collect all video IDs present across subjects
    allVideoIDs = {};
    for subjIdx = 1:numel(resultsCell)
        resEntry = resultsCell{subjIdx};
        if ~isfield(resEntry, 'results'), continue; end
        resArray = resEntry.results;
        allVideoIDs = [allVideoIDs; {resArray.videoID}']; %#ok<AGROW>
    end
    allVideoIDs = unique(allVideoIDs);
    % Order: baseline first (if present), then alphabetical
    isBaseline = contains(lower(allVideoIDs), 'baseline') | strcmp(allVideoIDs, 'BASELINE') | strcmp(allVideoIDs, '0');
    baselineIDs = allVideoIDs(isBaseline);
    otherIDs = sort(allVideoIDs(~isBaseline));
    videoIDs = [baselineIDs; otherIDs];
    nVideos = numel(videoIDs);

    % Preallocate output per marker group
    outTemplate = struct('videoIDs', videoIDs, ...
                         'speedBuckets', [], ...
                         'madBuckets', [], ...
                         'salBuckets', [], ...
                         'immobileFrac', [], ...
                         'immobileMedian', [], ...
                         'mobileMean', [], ...
                         'targetGroup', '', ...
                         'counts', []);
    %out = repmat(outTemplate, numel(markerGroupNames), 1);

    for groupIdx = 1:numel(markerGroupNames)
        targetGroup = markerGroupNames{groupIdx};

        speedBuckets = cell(1, nVideos);
        madBuckets = cell(1, nVideos);
        salBuckets = cell(1, nVideos);
        immFracBuckets = cell(1, nVideos);
        immMedBuckets = cell(1, nVideos);
        mobileMeanBuckets = cell(1, nVideos);

        % Build baseline map per subject -> markerName -> baseline metrics for this group
        baselineMap = containers.Map;
        for subjIdx = 1:numel(resultsCell)
            resEntry = resultsCell{subjIdx};
            subjID = '';
            if isfield(resEntry, 'subjectID'), subjID = char(resEntry.subjectID); end
            if isempty(subjID), subjID = sprintf('subj%d', subjIdx); end
            if ~isfield(resEntry, 'results'), continue; end
            resArray = resEntry.results;
            for resIdx = 1:numel(resArray)
                if ~strcmp(resArray(resIdx).markerGroupName, targetGroup), continue; end
                vid = resArray(resIdx).videoID;
                if ~(contains(lower(vid), 'baseline') || strcmp(vid, 'BASELINE') || strcmp(vid, '0'))
                    continue;
                end
                if ~isfield(resArray(resIdx), 'perMarkerMetrics'), continue; end
                perMarker = resArray(resIdx).perMarkerMetrics;
                for markerIdx = 1:numel(perMarker)
                    if ~isfield(perMarker{markerIdx}, 'markerName'), continue; end
                    markerName = perMarker{markerIdx}.markerName;
                    if isfield(perMarker{markerIdx}, 'medianSpeed') && ~isnan(perMarker{markerIdx}.medianSpeed)
                        baseStruct = struct();
                        if isKey(baselineMap, subjID)
                            baseStruct = baselineMap(subjID);
                        end
                        % store baseline metrics for this marker
                        markerKey = matlab.lang.makeValidName(markerName);
                        baseMetric = struct();
                        baseMetric.speed = perMarker{markerIdx}.medianSpeed;
                        if isfield(perMarker{markerIdx}, 'mad3d')
                            baseMetric.mad = perMarker{markerIdx}.mad3d;
                        else
                            baseMetric.mad = NaN;
                        end
                        if isfield(perMarker{markerIdx}, 'spectralArcLength')
                            baseMetric.sal = perMarker{markerIdx}.spectralArcLength;
                        else
                            baseMetric.sal = NaN;
                        end
                        baseStruct.(markerKey) = baseMetric;
                        baselineMap(subjID) = baseStruct;
                    end
                end
            end
        end

        % Collect fold-change metrics per subject/video relative to that subject's baseline
        for subjIdx = 1:numel(resultsCell)
            resEntry = resultsCell{subjIdx};
            subjID = '';
            if isfield(resEntry, 'subjectID'), subjID = char(resEntry.subjectID); end
            if isempty(subjID), subjID = sprintf('subj%d', subjIdx); end
            if ~isfield(resEntry, 'results'), continue; end
            resArray = resEntry.results;
            baseStruct = struct();
            if isKey(baselineMap, subjID)
                baseStruct = baselineMap(subjID);
            end
            for resIdx = 1:numel(resArray)
                if ~strcmp(resArray(resIdx).markerGroupName, targetGroup)
                    continue;
                end
                vid = resArray(resIdx).videoID;
                vidIdx = find(strcmp(videoIDs, vid), 1);
                if isempty(vidIdx), continue; end
                if ~isfield(resArray(resIdx), 'perMarkerMetrics'), continue; end
                perMarker = resArray(resIdx).perMarkerMetrics;
                for markerIdx = 1:numel(perMarker)
                    if ~isfield(perMarker{markerIdx}, 'medianSpeed') || isnan(perMarker{markerIdx}.medianSpeed)
                        continue;
                    end
                    if ~isfield(perMarker{markerIdx}, 'markerName')
                        continue;
                    end
                    markerKey = matlab.lang.makeValidName(perMarker{markerIdx}.markerName);
                    if ~isfield(baseStruct, markerKey)
                        continue; % no baseline for this marker
                    end
                    baseMetric = baseStruct.(markerKey);
                    % speed fold-change
                    if ~isnan(baseMetric.speed) && baseMetric.speed ~= 0
                        speedBuckets{vidIdx}(end+1,1) = perMarker{markerIdx}.medianSpeed / baseMetric.speed; %#ok<AGROW>
                    end
                    % MAD fold-change
                    if isfield(perMarker{markerIdx}, 'mad3d') && ~isnan(perMarker{markerIdx}.mad3d) ...
                            && ~isnan(baseMetric.mad) && baseMetric.mad ~= 0
                        madBuckets{vidIdx}(end+1,1) = perMarker{markerIdx}.mad3d / baseMetric.mad; %#ok<AGROW>
                    end
                    % SAL fold-change
                    if isfield(perMarker{markerIdx}, 'spectralArcLength') && ~isnan(perMarker{markerIdx}.spectralArcLength) ...
                            && ~isnan(baseMetric.sal) && baseMetric.sal ~= 0
                        salBuckets{vidIdx}(end+1,1) = perMarker{markerIdx}.spectralArcLength / baseMetric.sal; %#ok<AGROW>
                    end
                    % immobility stats (not normalized)
                    if isfield(perMarker{markerIdx}, 'percentImmobile')
                        immFracBuckets{vidIdx}(end+1,1) = perMarker{markerIdx}.percentImmobile; %#ok<AGROW>
                    end
                    if isfield(perMarker{markerIdx}, 'medianSpeedImmobile')
                        immMedBuckets{vidIdx}(end+1,1) = perMarker{markerIdx}.medianSpeedImmobile; %#ok<AGROW>
                    end
                    if isfield(perMarker{markerIdx}, 'avgSpeedMobile')
                        mobileMeanBuckets{vidIdx}(end+1,1) = perMarker{markerIdx}.avgSpeedMobile; %#ok<AGROW>
                    end
                end
            end
        end

        counts = cellfun(@numel, speedBuckets);

        out(groupIdx).videoIDs = videoIDs;
        out(groupIdx).speedBuckets = speedBuckets;
        out(groupIdx).madBuckets = madBuckets;
        out(groupIdx).salBuckets = salBuckets;
        out(groupIdx).immobileFrac = immFracBuckets;
        out(groupIdx).immobileMedian = immMedBuckets;
        out(groupIdx).mobileMean = mobileMeanBuckets;
        out(groupIdx).targetGroup = targetGroup;
        out(groupIdx).counts = counts;
    end

    if p.Results.makePlot
        makeQuickPlot(out, p.Results.outlierQuantile);
    end
end

function makeQuickPlot(outArr, outlierQuantile)
    % Quick multi-panel violin plots for speed, MAD, and SAL.
    nGroups = numel(outArr);
    outlineColor = [0 0 0]; % uniform outline color

    % All groups share the same video ordering
    vids = outArr(1).videoIDs;
    [vidColors, ~, uniqueGroups, groupColorMap] = resolveStimVideoColors(vids, []);
    % Drop baseline for visualization
    baseMask = contains(lower(vids), 'baseline') | strcmp(vids, 'BASELINE') | strcmp(vids, '0');
    keepIdx = find(~baseMask);
    vids = vids(~baseMask);
    vidColors = vidColors(~baseMask, :);
    nVideos = numel(vids);

    nCols = min(3, nGroups);
    nRows = ceil(nGroups / nCols);

    % Speed
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for groupIdx = 1:nGroups
        groupOut = outArr(groupIdx);
        nexttile; hold on;
        filteredBuckets = groupOut.speedBuckets(keepIdx);
        plotMetric(filteredBuckets, 'Median speed (fold baseline)', vidColors, vids, outlineColor, nVideos, outlierQuantile);
        title(sprintf('%s (median speed)', groupOut.targetGroup));
    end
    addVideoLegend(uniqueGroups, groupColorMap);

    % MAD
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for groupIdx = 1:nGroups
        groupOut = outArr(groupIdx);
        nexttile; hold on;
        filteredBuckets = groupOut.madBuckets(keepIdx);
        plotMetric(filteredBuckets, 'MAD (fold baseline)', vidColors, vids, outlineColor, nVideos, outlierQuantile);
        title(sprintf('%s (MAD)', groupOut.targetGroup));
    end
    addVideoLegend(uniqueGroups, groupColorMap);

    % SAL
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for groupIdx = 1:nGroups
        groupOut = outArr(groupIdx);
        nexttile; hold on;
        filteredBuckets = groupOut.salBuckets(keepIdx);
        plotMetric(filteredBuckets, 'SAL (fold baseline)', vidColors, vids, outlineColor, nVideos, outlierQuantile);
        title(sprintf('%s (SAL)', groupOut.targetGroup));
    end
    addVideoLegend(uniqueGroups, groupColorMap);

    % Immobility median speed (not normalized)
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for groupIdx = 1:nGroups
        groupOut = outArr(groupIdx);
        nexttile; hold on;
        filteredBuckets = groupOut.immobileMedian(keepIdx);
        plotMetric(filteredBuckets, 'Median speed while immobile (mm/s)', vidColors, vids, outlineColor, nVideos, outlierQuantile);
        title(sprintf('%s (immobile speed)', groupOut.targetGroup));
    end
    addVideoLegend(uniqueGroups, groupColorMap);

    % Immobility fraction (percent)
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for groupIdx = 1:nGroups
        groupOut = outArr(groupIdx);
        nexttile; hold on;
        filteredBuckets = groupOut.immobileFrac(keepIdx);
        plotMetric(filteredBuckets, 'Percent immobile (%)', vidColors, vids, outlineColor, nVideos, outlierQuantile);
        title(sprintf('%s (immobile fraction)', groupOut.targetGroup));
    end
    addVideoLegend(uniqueGroups, groupColorMap);
end

function plotMetric(buckets, yLabel, vidColors, vids, outlineColor, nVideos, outlierQuantile)
    for vidIdx = 1:nVideos
        vals = buckets{vidIdx};
        if isempty(vals), continue; end
        if ~isempty(outlierQuantile)
            cutoff = quantile(vals, outlierQuantile);
            vals(vals > cutoff) = [];
        end
        if isempty(vals), continue; end
        [dens, xi] = ksdensity(vals);
        dens = 0.35 * dens / max(dens);
        col = vidColors(vidIdx,:);
        fill(vidIdx + [ -dens, fliplr(dens) ], [xi, fliplr(xi)], col, ...
            'EdgeColor', outlineColor, 'FaceAlpha', 0.6, 'LineWidth', 1);
        medVal = median(vals,'omitnan');
        plot([vidIdx-0.25 vidIdx+0.25], [medVal medVal], 'Color', outlineColor, 'LineWidth', 1.5);
    end
    xlim([0.5 nVideos+0.5]);
    set(gca, 'XTick', 1:nVideos, 'XTickLabel', vids, 'XTickLabelRotation', 45);
    ylabel(yLabel);
    grid on;
end

function addVideoLegend(uniqueGroups, groupColorMap)
    if ~exist('uniqueGroups','var') || isempty(uniqueGroups)
        return;
    end
    lgdHandles = gobjects(numel(uniqueGroups),1);
    lgdLabels = uniqueGroups;
    for i = 1:numel(uniqueGroups)
        grp = uniqueGroups{i};
        c = groupColorMap(grp);
        lgdHandles(i) = plot(NaN, NaN, '-', 'Color', c, 'LineWidth', 2);
    end
    legend(lgdHandles, lgdLabels, 'Location', 'eastoutside');
end
