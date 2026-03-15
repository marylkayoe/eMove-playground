% make_pooled_disgust_density_figure.m
%
% Build pooled disgust-focused density figures across all subjects.
% Each row is one bodypart. Left column = full-motion density, right column =
% micromovement density, each with its own x-scale and median markers.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');

markerGroups = {'HEAD', 'UTORSO', 'LTORSO'};
emotionList = {'DISGUST', 'NEUTRAL', 'JOY', 'SAD'};
baselineEmotion = 'BASELINE';
immobilityThresholdMmps = 35;
outlierQuantile = 0.99;
minBaselineSamples = 20;

addpath(genpath(fullfile(repoRoot, 'CODE')));

latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');
if ~isfile(resultsCellPath)
    error('Missing resultsCell: %s', resultsCellPath);
end
if ~isfile(stimCsv)
    error('Missing stim coding CSV: %s', stimCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['pooled_disgust_density_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
codingTable = localLoadStimCodingTable(stimCsv);
[vidToEmotion, ~] = localBuildVideoMap(codingTable);
emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList);

fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Output dir: %s\n', outDir);

summaryRows = {};
for normIdx = 1:2
    doBaselineNormalize = normIdx == 2;
    normLabel = localNormLabel(doBaselineNormalize);

    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [90 60 1550 1180]);
    tl = tiledlayout(f, numel(markerGroups), 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s | disgust-focused pooled distributions | all subjects', strrep(normLabel, '-', ' ')), ...
        'FontSize', 22, 'FontWeight', 'bold', 'Interpreter', 'none');

    legendHandles = gobjects(numel(emotionList), 1);

    for r = 1:numel(markerGroups)
        mg = markerGroups{r};
        fullVals = cell(numel(emotionList), 1);
        microVals = cell(numel(emotionList), 1);

        for e = 1:numel(emotionList)
            emo = emotionList{e};
            fullVals{e} = localCollectPooledRaw(resultsCell, vidToEmotion, mg, emo, ...
                'speedArray', doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples, outlierQuantile);
            microVals{e} = localCollectPooledRaw(resultsCell, vidToEmotion, mg, emo, ...
                'speedArrayImmobile', doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples, outlierQuantile);

            summaryRows(end+1, :) = {normLabel, mg, emo, ...
                numel(fullVals{e}), median(fullVals{e}, 'omitnan'), ...
                numel(microVals{e}), median(microVals{e}, 'omitnan')}; %#ok<AGROW>
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
    end

    lgd = legend(legendHandles, emotionList, 'Location', 'southoutside', ...
        'Orientation', 'horizontal', 'Box', 'off');
    set(lgd, 'FontSize', 12);

    annotation(f, 'textbox', [0.12 0.02 0.78 0.04], ...
        'String', 'Separate x-axes for full and micromovement. Thin vertical lines mark pooled medians.', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);

    exportgraphics(f, fullfile(outDir, sprintf('pooled_disgust_density_%s.png', strrep(normLabel, '-', '_'))), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, sprintf('pooled_disgust_density_%s.pdf', strrep(normLabel, '-', '_'))), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, sprintf('pooled_disgust_density_%s.fig', strrep(normLabel, '-', '_'))));
end

summaryTbl = cell2table(summaryRows, ...
    'VariableNames', {'normalization','markerGroup','emotion','nFull','medianFull','nMicro','medianMicro'});
writetable(summaryTbl, fullfile(outDir, 'pooled_disgust_density_summary.csv'));

fprintf('Saved pooled disgust density figures under:\n%s\n', outDir);

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

function vals = localCollectPooledRaw(resultsCell, vidToEmotion, markerGroup, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples, outlierQuantile)
    vals = [];
    for i = 1:numel(resultsCell)
        rc = resultsCell{i};
        subjVals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroup, emotion, speedField, ...
            doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);
        if isempty(subjVals)
            continue;
        end
        vals = [vals; subjVals(:)]; %#ok<AGROW>
    end
    vals = vals(~isnan(vals));
    vals = localApplyOutlierCut(vals, outlierQuantile);
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
