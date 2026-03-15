% screen_disgust_example_subjects.m
%
% Screen candidate subjects for a disgust-focused single-subject figure.
% For each candidate:
%   1. Compute disgust-centered reversal counts in HEAD/UTORSO/LTORSO.
%   2. Compute browser-style sustained immobility during the disgust video.
%   3. Export density figures (absolute + baseline-normalized).
%
% Main output:
%   - candidate_summary.csv
%   - candidate_ranking.csv
%   - one figure folder per candidate

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
groupCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');
analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');
matRoot = fullfile(dataRoot, 'matlab_from_manifest');

candidateIDs = upper(string({'KN9309','MB0502','XC3002','XJ1505','XJ1802','XM3001'}));
markerGroups = {'HEAD', 'UTORSO', 'LTORSO'};
emotionList = {'DISGUST', 'NEUTRAL', 'JOY', 'SAD'};
comparisonEmotions = {'NEUTRAL', 'JOY', 'SAD'};
baselineEmotion = 'BASELINE';
immobilityThresholdMmps = 35;
immobileMinDurationSec = 1;
outlierQuantile = 0.99;
minBaselineSamples = 20;
speedWindowSec = 0.1;

addpath(genpath(fullfile(repoRoot, 'CODE')));

latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');
if ~isfile(resultsCellPath), error('Missing resultsCell: %s', resultsCellPath); end
if ~isfile(stimCsv), error('Missing stim coding CSV: %s', stimCsv); end
if ~isfile(groupCsv), error('Missing bodypart grouping CSV: %s', groupCsv); end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['disgust_example_screen_' runStamp]);
if ~exist(outDir, 'dir'), mkdir(outDir); end

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
codingTable = localLoadStimCodingTable(stimCsv);
[vidToEmotion, ~] = localBuildVideoMap(codingTable);
emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList);
disgustVideoID = localFindVideoForEmotion(codingTable, 'DISGUST');
groupMap = localLoadGroupMap(groupCsv, markerGroups);

fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Screen output: %s\n', outDir);
fprintf('Disgust video ID: %s\n', disgustVideoID);

summaryRows = {};
detailRows = {};

for s = 1:numel(candidateIDs)
    subjectID = candidateIDs(s);
    rc = localFindSubjectResults(resultsCell, subjectID);
    if isempty(rc)
        warning('Subject not found in resultsCell: %s', subjectID);
        continue;
    end

    trialData = localLoadSubjectTrialData(matRoot, subjectID);
    sustained = localComputeSustainedImmobility(trialData, groupMap, markerGroups, disgustVideoID, ...
        immobilityThresholdMmps, immobileMinDurationSec, speedWindowSec);

    reversalCountAbs = 0;
    reversalCountNorm = 0;
    reversalMagnitudeAbs = 0;
    reversalMagnitudeNorm = 0;

    subjDir = fullfile(outDir, char(subjectID));
    if ~exist(subjDir, 'dir'), mkdir(subjDir); end
    localRenderDensityFigure(subjDir, subjectID, rc, vidToEmotion, emotionColorMap, markerGroups, emotionList, ...
        baselineEmotion, minBaselineSamples, outlierQuantile, immobilityThresholdMmps, false);
    localRenderDensityFigure(subjDir, subjectID, rc, vidToEmotion, emotionColorMap, markerGroups, emotionList, ...
        baselineEmotion, minBaselineSamples, outlierQuantile, immobilityThresholdMmps, true);

    for normIdx = 1:2
        doBaselineNormalize = normIdx == 2;
        for g = 1:numel(markerGroups)
            mg = markerGroups{g};
            dFull = localMedianForEmotion(rc, vidToEmotion, mg, 'DISGUST', 'speedArray', doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples, outlierQuantile);
            dMicro = localMedianForEmotion(rc, vidToEmotion, mg, 'DISGUST', 'speedArrayImmobile', doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples, outlierQuantile);
            for ce = 1:numel(comparisonEmotions)
                emo = comparisonEmotions{ce};
                oFull = localMedianForEmotion(rc, vidToEmotion, mg, emo, 'speedArray', doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples, outlierQuantile);
                oMicro = localMedianForEmotion(rc, vidToEmotion, mg, emo, 'speedArrayImmobile', doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples, outlierQuantile);
                deltaFull = oFull - dFull;
                deltaMicro = oMicro - dMicro;
                isReversal = isfinite(deltaFull) && isfinite(deltaMicro) && sign(deltaFull) ~= 0 && sign(deltaMicro) ~= 0 && sign(deltaFull) ~= sign(deltaMicro);
                if doBaselineNormalize
                    reversalCountNorm = reversalCountNorm + double(isReversal);
                    if isReversal
                        reversalMagnitudeNorm = reversalMagnitudeNorm + abs(deltaFull - deltaMicro);
                    end
                else
                    reversalCountAbs = reversalCountAbs + double(isReversal);
                    if isReversal
                        reversalMagnitudeAbs = reversalMagnitudeAbs + abs(deltaFull - deltaMicro);
                    end
                end
                detailRows(end+1, :) = {char(subjectID), localNormLabel(doBaselineNormalize), mg, emo, dFull, oFull, dMicro, oMicro, deltaFull, deltaMicro, isReversal}; %#ok<AGROW>
            end
        end
    end

    combinedFrac = sustained.combined.immobileFrac;
    longestBoutSec = sustained.combined.longestBoutSec;
    nBouts = sustained.combined.nBouts;
    score = reversalCountNorm * 2 + reversalCountAbs + 4 * combinedFrac + 0.5 * longestBoutSec;

    summaryRows(end+1, :) = {char(subjectID), reversalCountAbs, reversalCountNorm, reversalMagnitudeAbs, reversalMagnitudeNorm, ...
        combinedFrac, longestBoutSec, nBouts, sustained.HEAD.immobileFrac, sustained.UTORSO.immobileFrac, sustained.LTORSO.immobileFrac, score}; %#ok<AGROW>
end

summaryTbl = cell2table(summaryRows, 'VariableNames', { ...
    'subjectID','reversalCountAbs','reversalCountNorm','reversalMagnitudeAbs','reversalMagnitudeNorm', ...
    'combinedImmobileFrac','combinedLongestBoutSec','combinedNBouts','headImmobileFrac','uTorsoImmobileFrac','lTorsoImmobileFrac','screenScore'});
summaryTbl = sortrows(summaryTbl, 'screenScore', 'descend');
writetable(summaryTbl, fullfile(outDir, 'candidate_ranking.csv'));

detailTbl = cell2table(detailRows, 'VariableNames', { ...
    'subjectID','normalization','markerGroup','comparisonEmotion','disgustFullMedian','otherFullMedian', ...
    'disgustMicroMedian','otherMicroMedian','deltaFull','deltaMicro','isReversal'});
writetable(detailTbl, fullfile(outDir, 'candidate_detail.csv'));

fprintf('Saved candidate screening outputs under:\n%s\n', outDir);
disp(summaryTbl);

%% Helpers
function latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot)
    d = dir(analysisRunsRoot);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(names ~= "." & names ~= "..");
    isRun = ~cellfun('isempty', regexp(cellstr(names), '^\d{8}_\d{6}$', 'once'));
    names = sort(names(isRun));
    if isempty(names)
        error('No timestamped analysis runs found under %s', analysisRunsRoot);
    end
    latestRunDir = fullfile(analysisRunsRoot, char(names(end)));
end

function rc = localFindSubjectResults(resultsCell, subjectID)
    rc = [];
    for i = 1:numel(resultsCell)
        if isfield(resultsCell{i}, 'subjectID') && upper(string(resultsCell{i}.subjectID)) == upper(string(subjectID))
            rc = resultsCell{i};
            return;
        end
    end
end

function trialData = localLoadSubjectTrialData(matRoot, subjectID)
    subjDir = fullfile(matRoot, char(subjectID));
    mats = dir(fullfile(subjDir, '*.mat'));
    if isempty(mats)
        error('No MAT files under %s', subjDir);
    end
    S = load(fullfile(subjDir, mats(1).name));
    if isfield(S, 'trialData')
        trialData = S.trialData;
    else
        error('trialData variable missing in %s', fullfile(subjDir, mats(1).name));
    end
end

function codingTable = localLoadStimCodingTable(stimCsv)
    opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
    strCols = {'videoID','emotionTag','groupCode'};
    strCols = intersect(strCols, opts.VariableNames, 'stable');
    if ~isempty(strCols)
        opts = setvartype(opts, strCols, 'string');
    end
    T = readtable(stimCsv, opts);
    if ismember('groupCode', T.Properties.VariableNames)
        emo = string(T.groupCode);
    elseif ismember('emotionTag', T.Properties.VariableNames)
        emo = string(T.emotionTag);
    else
        error('Stim CSV requires groupCode or emotionTag.');
    end
    vid = upper(strtrim(string(T.videoID)));
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));
    emo = upper(strtrim(emo));
    keep = vid ~= "" & emo ~= "";
    codingTable = table(vid(keep), emo(keep), 'VariableNames', {'videoID','emotion'});
end

function [vidToEmotion, emotions] = localBuildVideoMap(codingTable)
    vidToEmotion = containers.Map;
    emotions = {};
    vids = codingTable{:,1};
    emos = codingTable{:,2};
    if isstring(vids), vids = cellstr(vids); end
    if isstring(emos), emos = cellstr(emos); end
    for i = 1:numel(vids)
        vid = char(string(vids{i}));
        emo = char(string(emos{i}));
        if isempty(strtrim(vid)) || isempty(strtrim(emo))
            continue;
        end
        vidToEmotion(vid) = emo;
        emotions{end+1,1} = emo; %#ok<AGROW>
    end
    emotions = unique(emotions, 'stable');
end

function emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList)
    emotionColorMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    vids = cellstr(string(codingTable{:,1}));
    grps = cellstr(string(codingTable{:,2}));
    codingCell = [vids, grps];
    [~, ~, uniqueGroups, groupColorMap] = resolveStimVideoColors(vids, codingCell);
    for i = 1:numel(uniqueGroups)
        g = char(string(uniqueGroups{i}));
        if isKey(groupColorMap, g)
            emotionColorMap(g) = groupColorMap(g);
        end
    end
    missing = {};
    for i = 1:numel(emotionList)
        e = char(string(emotionList{i}));
        if ~isKey(emotionColorMap, e)
            missing{end+1,1} = e; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        cmap = lines(numel(missing));
        for i = 1:numel(missing)
            emotionColorMap(missing{i}) = cmap(i,:);
        end
    end
end

function videoID = localFindVideoForEmotion(codingTable, emotion)
    row = codingTable(strcmp(string(codingTable.emotion), string(emotion)), :);
    if isempty(row)
        error('No video for emotion %s', emotion);
    end
    videoID = char(row.videoID(1));
end

function groupMap = localLoadGroupMap(groupCsv, groups)
    T = readtable(groupCsv, 'TextType', 'string');
    groupMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    if ismember('groupName', T.Properties.VariableNames)
        groupCol = 'groupName';
    elseif ismember('plotGroup', T.Properties.VariableNames)
        groupCol = 'plotGroup';
    else
        error('Grouping CSV missing groupName/plotGroup column.');
    end
    for i = 1:numel(groups)
        g = groups{i};
        rows = T(string(T.(groupCol)) == string(g) & double(T.include) == 1, :);
        groupMap(g) = cellstr(rows.markerName);
    end
end

function sustained = localComputeSustainedImmobility(trialData, groupMap, markerGroups, videoID, immobilityThresholdMmps, immobileMinDurationSec, speedWindowSec)
    sustained = struct();
    allMarkers = {};
    for i = 1:numel(markerGroups)
        g = markerGroups{i};
        markers = groupMap(g);
        sustained.(g) = localComputeGroupImmobility(trialData, markers, videoID, immobilityThresholdMmps, immobileMinDurationSec, speedWindowSec);
        allMarkers = [allMarkers; markers(:)]; %#ok<AGROW>
    end
    allMarkers = unique(allMarkers, 'stable');
    sustained.combined = localComputeGroupImmobility(trialData, allMarkers, videoID, immobilityThresholdMmps, immobileMinDurationSec, speedWindowSec);
end

function out = localComputeGroupImmobility(trialData, markerNames, videoID, immobilityThresholdMmps, immobileMinDurationSec, speedWindowSec)
    seg = extractMarkerTrajectoryForVideo(trialData, markerNames, videoID, 'preStimSec', 0, 'postStimSec', 0, 'clipSec', 0);
    nMarkers = size(seg.trajectories, 3);
    markerSpeeds = nan(size(seg.trajectories, 1), nMarkers);
    for m = 1:nMarkers
        markerSpeeds(:, m) = getTrajectorySpeed(seg.trajectories(:, :, m), seg.frameRate, speedWindowSec);
    end
    avgSpeed = mean(markerSpeeds, 2, 'omitnan');
    [immobileMask, ~, bouts] = getImmobileFramesFromSpeed(avgSpeed, seg.frameRate, ...
        'thresholdMmPerSec', immobilityThresholdMmps, ...
        'minDurationSec', immobileMinDurationSec);
    out = struct();
    out.immobileFrac = mean(immobileMask, 'omitnan');
    out.nBouts = numel(bouts);
    out.longestBoutSec = 0;
    if ~isempty(bouts)
        out.longestBoutSec = max([bouts.durationSec]);
    end
end

function localRenderDensityFigure(subjDir, subjectID, rc, vidToEmotion, emotionColorMap, markerGroups, emotionList, baselineEmotion, minBaselineSamples, outlierQuantile, immobilityThresholdMmps, doBaselineNormalize)
    normLabel = localNormLabel(doBaselineNormalize);
    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [90 60 1550 1180]);
    tl = tiledlayout(f, numel(markerGroups), 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s | disgust-focused subject distributions | %s', strrep(normLabel, '-', ' '), subjectID), ...
        'FontSize', 22, 'FontWeight', 'bold', 'Interpreter', 'none');

    legendHandles = gobjects(numel(emotionList), 1);
    for r = 1:numel(markerGroups)
        mg = markerGroups{r};
        fullVals = cell(numel(emotionList), 1);
        microVals = cell(numel(emotionList), 1);
        for e = 1:numel(emotionList)
            emo = emotionList{e};
            fullVals{e} = localApplyOutlierCut(localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, mg, emo, 'speedArray', doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples), outlierQuantile);
            microVals{e} = localApplyOutlierCut(localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, mg, emo, 'speedArrayImmobile', doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples), outlierQuantile);
        end

        axFull = nexttile(tl, (r-1) * 2 + 1);
        hold(axFull, 'on');
        maxDensityFull = 0;
        for e = 1:numel(emotionList)
            [h, peakY] = localPlotDensityWithMedian(axFull, fullVals{e}, emotionColorMap(emotionList{e}), '-');
            maxDensityFull = max(maxDensityFull, peakY);
            if r == 1
                legendHandles(e) = h;
            end
        end
        xlim(axFull, localPaddedLimits(cat(1, fullVals{:})));
        ylim(axFull, [0 max(0.05, maxDensityFull * 1.12)]);
        grid(axFull, 'on');
        set(axFull, 'Box', 'off', 'LineWidth', 1.0, 'FontSize', 11);
        axFull.Toolbar.Visible = 'off';
        title(axFull, sprintf('%s | full motion', strrep(mg, '_', '-')), 'FontSize', 15, 'FontWeight', 'bold');
        ylabel(axFull, 'Probability density', 'FontSize', 12, 'FontWeight', 'bold');
        if r == numel(markerGroups)
            xlabel(axFull, localXAxisLabel(doBaselineNormalize), 'FontSize', 12, 'FontWeight', 'bold');
        end
        localAnnotateDensityPanel(axFull, emotionList, fullVals, 'full');

        axMicro = nexttile(tl, (r-1) * 2 + 2);
        hold(axMicro, 'on');
        maxDensityMicro = 0;
        for e = 1:numel(emotionList)
            [~, peakY] = localPlotDensityWithMedian(axMicro, microVals{e}, emotionColorMap(emotionList{e}), '-');
            maxDensityMicro = max(maxDensityMicro, peakY);
        end
        xlim(axMicro, localPaddedLimits(cat(1, microVals{:})));
        ylim(axMicro, [0 max(0.05, maxDensityMicro * 1.12)]);
        grid(axMicro, 'on');
        set(axMicro, 'Box', 'off', 'LineWidth', 1.0, 'FontSize', 11);
        axMicro.Toolbar.Visible = 'off';
        title(axMicro, sprintf('%s | micromovement <= %d mm/s', strrep(mg, '_', '-'), immobilityThresholdMmps), ...
            'FontSize', 15, 'FontWeight', 'bold');
        if r == numel(markerGroups)
            xlabel(axMicro, localXAxisLabel(doBaselineNormalize), 'FontSize', 12, 'FontWeight', 'bold');
        end
        localAnnotateDensityPanel(axMicro, emotionList, microVals, 'micro');
    end

    lgd = legend(legendHandles, emotionList, 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
    set(lgd, 'FontSize', 12);
    annotation(f, 'textbox', [0.12 0.02 0.78 0.04], ...
        'String', sprintf('Separate x-axes for full and micromovement. Thin vertical lines mark medians. Subject: %s', subjectID), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);

    exportgraphics(f, fullfile(subjDir, sprintf('single_subject_disgust_density_%s.png', strrep(normLabel, '-', '_'))), 'Resolution', 220);
    exportgraphics(f, fullfile(subjDir, sprintf('single_subject_disgust_density_%s.pdf', strrep(normLabel, '-', '_'))), 'ContentType', 'vector');
    savefig(f, fullfile(subjDir, sprintf('single_subject_disgust_density_%s.fig', strrep(normLabel, '-', '_'))));
    close(f);
end

function medVal = localMedianForEmotion(rc, vidToEmotion, markerGroup, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples, outlierQuantile)
    vals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroup, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);
    vals = localApplyOutlierCut(vals, outlierQuantile);
    medVal = median(vals, 'omitnan');
end

function vals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroup, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples)
    vals = localCollectRawSamplesForSubject(rc, vidToEmotion, markerGroup, emotion, speedField);
    if ~doBaselineNormalize
        return;
    end
    baseVal = localBaselineScalarForSubject(rc, vidToEmotion, markerGroup, baselineEmotion, baselineFromField, minBaselineSamples);
    if ~(isfinite(baseVal) && baseVal > 0)
        vals = [];
        return;
    end
    vals = vals ./ baseVal;
end

function vals = localCollectRawSamplesForSubject(rc, vidToEmotion, markerGroup, emotion, speedField)
    vals = [];
    if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
        return;
    end
    st = rc.summaryTable;
    if ~ismember(speedField, st.Properties.VariableNames)
        return;
    end
    emoCol = localEmotionColumn(st, vidToEmotion);
    idx = strcmp(st.markerGroup, markerGroup) & strcmp(emoCol, emotion);
    if ~any(idx)
        return;
    end
    cellVals = st.(speedField)(idx);
    for i = 1:numel(cellVals)
        v = cellVals{i};
        if isempty(v)
            continue;
        end
        vals = [vals; v(:)]; %#ok<AGROW>
    end
    vals = vals(~isnan(vals));
end

function emoCol = localEmotionColumn(st, vidToEmotion)
    emoCol = repmat({''}, height(st), 1);
    if ~ismember('videoID', st.Properties.VariableNames)
        return;
    end
    for r = 1:height(st)
        vid = st.videoID{r};
        if isKey(vidToEmotion, vid)
            emoCol{r} = vidToEmotion(vid);
        end
    end
end

function baseVal = localBaselineScalarForSubject(rc, vidToEmotion, markerGroup, baselineEmotion, baselineFromField, minBaselineSamples)
    baseVal = NaN;
    if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
        return;
    end
    st = rc.summaryTable;
    emoCol = localEmotionColumn(st, vidToEmotion);
    idx = strcmp(st.markerGroup, markerGroup) & strcmp(emoCol, baselineEmotion);
    if ~any(idx) || ~ismember(baselineFromField, st.Properties.VariableNames)
        return;
    end
    vv = [];
    cells = st.(baselineFromField)(idx);
    for i = 1:numel(cells)
        if ~isempty(cells{i})
            vv = [vv; cells{i}(:)]; %#ok<AGROW>
        end
    end
    vv = vv(~isnan(vv));
    if numel(vv) < minBaselineSamples
        return;
    end
    baseVal = median(vv, 'omitnan');
    if ~(isfinite(baseVal) && baseVal > 0)
        baseVal = NaN;
    end
end

function vals = localApplyOutlierCut(vals, outlierQuantile)
    vals = vals(~isnan(vals));
    if isempty(vals)
        return;
    end
    cutoff = quantile(vals, outlierQuantile);
    vals(vals > cutoff) = [];
end

function [h, peakY] = localPlotDensityWithMedian(ax, vals, color, lineStyle)
    vals = vals(isfinite(vals));
    if numel(vals) < 10
        h = plot(ax, nan, nan, 'Color', color, 'LineStyle', lineStyle, 'LineWidth', 2.4);
        peakY = 0;
        return;
    end
    [f, x] = ksdensity(vals, 'Function', 'pdf');
    h = plot(ax, x, f, 'Color', color, 'LineStyle', lineStyle, 'LineWidth', 2.4);
    peakY = max(f);
    medVal = median(vals, 'omitnan');
    plot(ax, [medVal medVal], [0 peakY], '-', 'Color', color, 'LineWidth', 2.8, 'HandleVisibility', 'off');
    plot(ax, [medVal medVal], [0 peakY], ':', 'Color', min(color + 0.18, 1), 'LineWidth', 1.4, 'HandleVisibility', 'off');
end

function lims = localPaddedLimits(vals)
    vals = vals(isfinite(vals));
    if isempty(vals)
        lims = [0 1];
        return;
    end
    vMin = min(vals);
    vMax = max(vals);
    if vMin == vMax
        pad = max(0.15 * max(abs(vMin), 1), 0.25);
    else
        pad = max(0.08 * (vMax - vMin), 0.10);
    end
    lims = [vMin - pad, vMax + pad];
end

function localAnnotateDensityPanel(ax, emotionList, valCells, regimeLabel)
    lines = strings(numel(emotionList), 1);
    for i = 1:numel(emotionList)
        lines(i) = sprintf('%s med %.2f', emotionList{i}, median(valCells{i}, 'omitnan'));
    end
    text(ax, 0.98, 0.96, sprintf('%s\n%s', regimeLabel, strjoin(cellstr(lines), newline)), ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'FontSize', 8.5, 'BackgroundColor', [1 1 1 0.72], 'Margin', 4, 'Color', [0.2 0.2 0.2]);
end

function label = localNormLabel(doBaselineNormalize)
    if doBaselineNormalize
        label = 'baseline-normalized';
    else
        label = 'absolute';
    end
end

function xlab = localXAxisLabel(doBaselineNormalize)
    if doBaselineNormalize
        xlab = 'Speed (fold baseline)';
    else
        xlab = 'Speed (mm/s)';
    end
end
