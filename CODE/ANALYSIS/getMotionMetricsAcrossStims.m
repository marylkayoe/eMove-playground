function [results, summaryTable] = getMotionMetricsAcrossStims(trialData, markerLists, varargin)
% getMotionMetricsAcrossStims - Compute motion metrics for marker groups across all stimuli.
%
% Pipeline stage:
%   Per-subject aggregation layer.
%   Iterates over (marker group x video) and collects metric outputs.
%
%   [results, summaryTable] = getMotionMetricsAcrossStims(trialData, markerLists, ...)
%
% Inputs:
%   trialData    - struct containing trajectoryData, markerNames, metaData (with videoIDs/stimScheduling)
%   markerLists  - cell array of marker name lists (e.g., body parts). Each element is a cellstr/string/char list.
%
% Optional name-value pairs (forwarded where applicable):
%   'markerGroupNames'        - names for each marker list (default: auto)
%   'videoIDs'                - override list of video IDs (default: trialData.metaData.videoIDs)
%   'FRAMERATE'               - frames per second (default: trialData.metaData.captureFrameRate or 120)
%   'speedWindow'             - speed window in seconds (default: 0.1)
%   'computeFrequencyMetrics' - logical (default: false)
%   'freqBands'               - struct of bands
%   'freqMakePlot'            - logical
%   'makePlot'                - logical, pass to per-marker plotting (default: false)
%
% Outputs:
%   results      - struct array with fields:
%                    markerGroupName, markerNames, videoID, summaryMetrics, perMarkerMetrics
%   summaryTable - table of summary metrics (one row per markerGroup/videoID) with numeric fields expanded

    p = inputParser;
    addRequired(p, 'trialData');
    addRequired(p, 'markerLists', @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'markerGroupNames', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'videoIDs', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'FRAMERATE', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'speedWindow', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'computeFrequencyMetrics', false, @(x) islogical(x) && isscalar(x));
    defaultBands = struct( ...
        'tremor', [6 12], ...
        'low',    [0.5 3], ...
        'mid',    [3 6], ...
        'high',   [12 20]);
    addParameter(p, 'freqBands', defaultBands, @isstruct);
    addParameter(p, 'freqMakePlot', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'makePlot', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'plotBands', {'mid','tremor','high'}, @(x) iscell(x) || isstring(x));
    addParameter(p, 'stimVideoEmotionCoding', {}, @(x) istable(x) || iscell(x));
    addParameter(p, 'immobilityThreshold', 35, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'subjectID', '', @(x) ischar(x) || isstring(x));
    parse(p, trialData, markerLists, varargin{:});

    markerGroupNames = p.Results.markerGroupNames;
    if ischar(markerGroupNames) || isstring(markerGroupNames)
        markerGroupNames = cellstr(markerGroupNames);
    end

    % Normalize markerLists to cell-of-cellstr
    if ischar(markerLists) || isstring(markerLists)
        markerLists = {cellstr(markerLists)};
    else
        markerLists = cellfun(@cellstr, markerLists, 'UniformOutput', false);
    end

    if isempty(markerGroupNames)
        markerGroupNames = cellfun(@(lst,idx) sprintf('Group %d', idx), markerLists, num2cell(1:numel(markerLists))', 'UniformOutput', false);
    end

    metaData = struct();
    if isfield(trialData, 'metaData')
        metaData = trialData.metaData;
    end

    videoIDs = p.Results.videoIDs;
    if isempty(videoIDs)
        if isfield(metaData, 'videoIDs')
            videoIDs = metaData.videoIDs;
        else
            videoIDs = {};
        end
    end
    if ischar(videoIDs) || isstring(videoIDs)
        videoIDs = cellstr(videoIDs);
    end

    frameRate = p.Results.FRAMERATE;
    if isempty(frameRate)
        if isfield(metaData, 'captureFrameRate')
            frameRate = metaData.captureFrameRate;
        else
            frameRate = 120;
        end
    end

    results = struct('markerGroupName', {}, 'markerNames', {}, 'videoID', {}, 'summaryMetrics', {}, 'perMarkerMetrics', {});
    resIdx = 1;
    summaryRows = [];

    for g = 1:numel(markerLists)
        for v = 1:numel(videoIDs)
            vid = videoIDs{v};
            metricsCell = getMotionMetricsForMarkers(trialData, markerLists{g}, vid, ...
                'FRAMERATE', frameRate, ...
                'speedWindow', p.Results.speedWindow, ...
                'computeFrequencyMetrics', p.Results.computeFrequencyMetrics, ...
                'freqBands', p.Results.freqBands, ...
                'freqMakePlot', p.Results.freqMakePlot, ...
                'immobilityThreshold', p.Results.immobilityThreshold, ...
                'makePlot', false); % disable per-marker plots here

            summaryMetrics = metricsCell{end};
            perMarkerMetrics = metricsCell(1:end-1);

            results(resIdx).markerGroupName = markerGroupNames{g};
            results(resIdx).markerNames = markerLists{g};
            results(resIdx).videoID = vid;
            results(resIdx).summaryMetrics = summaryMetrics;
            results(resIdx).perMarkerMetrics = perMarkerMetrics;

            % build summary row for table (numeric scalar fields)
            if isempty(summaryRows)
                numericFields = fieldnames(summaryMetrics);
                numericFields = numericFields(structfun(@(v) isnumeric(v) && isscalar(v), summaryMetrics));
            end
            row.markerGroup = markerGroupNames{g};
            row.videoID = vid;
            for k = 1:numel(numericFields)
                fn = numericFields{k};
                row.(fn) = summaryMetrics.(fn);
            end
            % pooled speed arrays (stored as cell fields)
            row.speedArray = {localConcatField(perMarkerMetrics, 'speedArray')};
            row.speedArrayImmobile = {localConcatField(perMarkerMetrics, 'speedArrayImmobile')};
            summaryRows = [summaryRows; row]; %#ok<AGROW>

            resIdx = resIdx + 1;
        end
    end

    if isempty(summaryRows)
        summaryTable = table();
    else
        summaryTable = struct2table(summaryRows);
    end

    if p.Results.makePlot
        subjID = p.Results.subjectID;
        if isempty(subjID) && isfield(trialData, 'subjectID')
            subjID = char(trialData.subjectID);
        end
        plotSummaryResults(results, markerGroupNames, videoIDs, p.Results.plotBands, p.Results.stimVideoEmotionCoding, subjID);
    end
end

function vals = localConcatField(perMarkerMetrics, fieldName)
    vals = [];
    for k = 1:numel(perMarkerMetrics)
        if isfield(perMarkerMetrics{k}, fieldName)
            v = perMarkerMetrics{k}.(fieldName);
            if ~isempty(v)
                vals = [vals; v(:)]; %#ok<AGROW>
            end
        end
    end
end

function plotSummaryResults(results, markerGroupNames, videoIDs, plotBands, codingTable, subjectID)
    groupNames = markerGroupNames(:);
    vidNames = videoIDs(:);
    catNamesFull = categorical(vidNames, vidNames, 'Ordinal', true);
    nG = numel(groupNames);
    nV = numel(vidNames);

    avgSpeedMat = NaN(nG, nV);
    madMat = NaN(nG, nV);
    salMat = NaN(nG, nV);

    for r = 1:numel(results)
        gIdx = find(strcmp(groupNames, results(r).markerGroupName));
        vIdx = find(strcmp(vidNames, results(r).videoID));
        if isempty(gIdx) || isempty(vIdx)
            continue;
        end
        sm = results(r).summaryMetrics;
        if isfield(sm, 'averageSpeed'), avgSpeedMat(gIdx, vIdx) = sm.averageSpeed; end
        if isfield(sm, 'mad3d'), madMat(gIdx, vIdx) = sm.mad3d; end
        if isfield(sm, 'spectralArcLength'), salMat(gIdx, vIdx) = sm.spectralArcLength; end
    end

    % Helper for subplot grid
    nCols = min(3, nG);
    nRows = ceil(nG / nCols);

    % Resolve colors for videos based on emotion coding
    [vidColors, groupCodes, uniqueGroups, groupColorMap] = localResolveColors(vidNames, codingTable);

    % Identify baseline columns (group code '0' or video name contains baseline)
    baselineIdx = find(strcmp(groupCodes, '0') | contains(lower(vidNames), 'baseline'));

    % Identify baseline columns (group code '0' or video name contains baseline)
    baselineIdx = find(strcmp(groupCodes, '0') | contains(lower(vidNames), 'baseline'));
    nonBaseMask = true(size(vidNames));
    nonBaseMask(baselineIdx) = false;
    catNames = catNamesFull(nonBaseMask);

    % Figure for avg speed (relative to baseline)
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for g = 1:nG
        nexttile;
        relVals = avgSpeedMat(g, :);
        if ~isempty(baselineIdx)
            baseVal = mean(avgSpeedMat(g, baselineIdx), 'omitnan');
            relVals = relVals - baseVal;
        end
        b = bar(catNames, relVals(nonBaseMask), 'FaceColor', 'flat');
        b.CData = vidColors(nonBaseMask, :);
        title(sprintf('%s - Avg speed (rel. baseline)', groupNames{g}));
        ylabel('mm/s');
        grid on;
    end
    % add group legend
    addGroupLegend(uniqueGroups, groupColorMap);
    if isempty(subjectID), subjectID = ''; end
    sgtitle(sprintf('%s Average speed across stimuli', subjectID));

    % Figure for MAD (relative to baseline)
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for g = 1:nG
        nexttile;
        relVals = madMat(g, :);
        if ~isempty(baselineIdx)
            baseVal = mean(madMat(g, baselineIdx), 'omitnan');
            relVals = relVals - baseVal;
        end
        b = bar(catNames, relVals(nonBaseMask), 'FaceColor', 'flat');
        b.CData = vidColors(nonBaseMask, :);
        title(sprintf('%s - MAD radius (rel. baseline)', groupNames{g}));
        ylabel('mm');
        grid on;
    end
    addGroupLegend(uniqueGroups, groupColorMap);
    sgtitle(sprintf('%s Spatial spread (MAD) across stimuli', subjectID));

    % Figure for Spectral Arc Length (fold relative to baseline)
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for g = 1:nG
        nexttile;
        foldVals = salMat(g, :);
        if ~isempty(baselineIdx)
            baseVal = mean(salMat(g, baselineIdx), 'omitnan');
            if baseVal ~= 0 && ~isnan(baseVal)
                foldVals = foldVals ./ baseVal;
            else
                foldVals(:) = NaN;
            end
        end
        b = bar(catNames, foldVals(nonBaseMask), 'FaceColor', 'flat');
        b.CData = vidColors(nonBaseMask, :);
        title(sprintf('%s - Spectral arc length (fold vs baseline)', groupNames{g}));
        ylabel('Fold of baseline SAL');
        grid on;
    end
    addGroupLegend(uniqueGroups, groupColorMap);
    sgtitle(sprintf('%s Spectral arc length across stimuli (lower is smoother)', subjectID));

    % Mean PSD per group across markers, with separate subplots per group
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for g = 1:nG
        nexttile;
        hold on;
        hasPSD = false;
        for v = 1:nV
            resIdx = find(strcmp({results.markerGroupName}, groupNames{g}) & strcmp({results.videoID}, vidNames{v}), 1);
            if isempty(resIdx), continue; end
            pm = results(resIdx).perMarkerMetrics;
            psdList = {};
            freqVec = [];
            for m = 1:numel(pm)
                if isfield(pm{m}, 'freqMetrics') && isfield(pm{m}.freqMetrics, 'freq') ...
                        && ~isempty(pm{m}.freqMetrics.freq)
                    if isempty(freqVec)
                        freqVec = pm{m}.freqMetrics.freq(:);
                    end
                    psdList{end+1} = pm{m}.freqMetrics.psd(:); %#ok<AGROW>
                end
            end
            if isempty(psdList) || isempty(freqVec)
                continue;
            end
            % ensure all PSD vectors align to freqVec length
            psdMat = cell2mat(cellfun(@(p) padOrTrim(p, numel(freqVec)), psdList, 'UniformOutput', false));
            meanPsd = mean(psdMat, 2, 'omitnan');
            % color by group code
            if ~isempty(groupCodes) && numel(groupCodes) >= v && isKey(groupColorMap, groupCodes{v})
                c = groupColorMap(groupCodes{v});
            else
                c = vidColors(v,:);
            end
            semilogy(freqVec, meanPsd, 'Color', c, 'LineWidth', 1.2);
            hasPSD = true;
        end
        xlabel('Frequency (Hz)');
        ylabel('PSD');
        set(gca, 'YScale', 'log');
     
        title(sprintf('%s - Mean PSD', groupNames{g}));
        grid on;
        if ~hasPSD
            text(0.5,0.5,'No PSD data','HorizontalAlignment','center');
        end
        % add group-coded legend per subplot for clarity
        addGroupLegend(uniqueGroups, groupColorMap);
    end
    sgtitle('Mean PSD across markers (per group, per video)');
end

function x = padOrTrim(x, N)
    x = x(:);
    if numel(x) < N
        x(end+1:N) = NaN;
    elseif numel(x) > N
        x = x(1:N);
    end
end

function addGroupLegend(uniqueGroups, groupColorMap)
    if isempty(uniqueGroups) || isempty(groupColorMap)
        return;
    end
    hold on;
    dummy = gobjects(numel(uniqueGroups),1);
    for i = 1:numel(uniqueGroups)
        c = groupColorMap(uniqueGroups{i});
        dummy(i) = plot(NaN, NaN, '-', 'Color', c, 'LineWidth', 2);
    end
    legend(dummy, uniqueGroups, 'Location', 'eastoutside');
end
