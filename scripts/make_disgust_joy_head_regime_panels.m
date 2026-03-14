% make_disgust_joy_head_regime_panels.m
%
% Build pooled-across-subject figure panels for the observed regime reversal:
%   full-speed HEAD motion: DISGUST slower than JOY
%   micromovement HEAD motion: DISGUST faster than JOY
%
% Output:
%   - one 2x3 figure:
%       row 1 = absolute values
%       row 2 = baseline-normalized values
%       col 1 = pooled full-speed CDF
%       col 2 = pooled micromovement CDF
%       col 3 = regime contrast (emotion medians across regimes)
%   - summary CSV of pooled medians and sample counts

clearvars;
clc;
close all;

%% Configuration
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
markerGroup = 'HEAD';
emotionList = {'DISGUST', 'JOY'};
baselineEmotion = 'BASELINE';
immobilityThresholdMmps = 35;
outlierQuantile = 0.99;
minBaselineSamples = 20;

addpath(genpath(fullfile(repoRoot, 'CODE')));

analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');
latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');

if ~isfile(resultsCellPath)
    error('resultsCell.mat not found: %s', resultsCellPath);
end
if ~isfile(stimCsv)
    error('Stim coding CSV not found: %s', stimCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['disgust_joy_head_regime_' runStamp]);
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

%% Collect pooled raw values
summaryRows = {};
pooled = struct();
for normalizeIdx = 1:2
    doBaselineNormalize = normalizeIdx == 2;
    normLabel = localNormLabel(doBaselineNormalize);

    for regimeIdx = 1:2
        useImmobile = regimeIdx == 2;
        if useImmobile
            speedField = 'speedArrayImmobile';
            baselineFromField = 'speedArrayImmobile';
            regimeLabel = sprintf('micromovement <= %d mm/s', immobilityThresholdMmps);
        else
            speedField = 'speedArray';
            baselineFromField = 'speedArray';
            regimeLabel = 'full speed';
        end

        key = matlab.lang.makeValidName(sprintf('%s_%s', normLabel, regimeLabel));
        pooled.(key) = cell(numel(emotionList), 1);

        for e = 1:numel(emotionList)
            emo = emotionList{e};
            valsAll = [];
            for sIdx = 1:numel(resultsCell)
                rc = resultsCell{sIdx};
                vals = localCollectRawSamplesForSubjectNormalized( ...
                    rc, vidToEmotion, markerGroup, emo, speedField, ...
                    doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);
                vals = localApplyOutlierCut(vals, outlierQuantile);
                valsAll = [valsAll; vals(:)]; %#ok<AGROW>
            end
            pooled.(key){e} = valsAll;
            summaryRows(end+1, :) = {normLabel, regimeLabel, emo, numel(valsAll), median(valsAll, 'omitnan')}; %#ok<AGROW>
        end
    end
end

summaryTbl = cell2table(summaryRows, ...
    'VariableNames', {'normalization','regime','emotion','nSamples','medianValue'});
writetable(summaryTbl, fullfile(outDir, 'pooled_summary.csv'));

%% Build figure
f = figure('Color', 'w', 'Units', 'pixels', 'Position', [120 80 1500 920]);
tl = tiledlayout(f, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, sprintf('HEAD | DISGUST vs JOY | pooled raw samples | regime contrast'), ...
    'Interpreter', 'none', 'FontSize', 20, 'FontWeight', 'bold');

rowConfigs = { ...
    struct('doBaselineNormalize', false, 'normLabel', 'absolute'), ...
    struct('doBaselineNormalize', true,  'normLabel', 'baseline-normalized')};

for rowIdx = 1:2
    cfg = rowConfigs{rowIdx};
    fullKey = matlab.lang.makeValidName(sprintf('%s_%s', cfg.normLabel, 'full speed'));
    microKey = matlab.lang.makeValidName(sprintf('%s_%s', cfg.normLabel, sprintf('micromovement <= %d mm/s', immobilityThresholdMmps)));

    % Full-speed CDF
    ax1 = nexttile(tl, (rowIdx - 1) * 3 + 1);
    localPlotPooledEcdfs(ax1, pooled.(fullKey), emotionList, emotionColorMap);
    localStyleCdfAxes(ax1, cfg.doBaselineNormalize, false);
    title(ax1, sprintf('%s | full speed', localPanelRowLabel(cfg)), 'FontSize', 15, 'FontWeight', 'bold');
    localAnnotatePair(ax1, pooled.(fullKey), emotionList);

    % Micromovement CDF
    ax2 = nexttile(tl, (rowIdx - 1) * 3 + 2);
    localPlotPooledEcdfs(ax2, pooled.(microKey), emotionList, emotionColorMap);
    localStyleCdfAxes(ax2, cfg.doBaselineNormalize, true);
    title(ax2, sprintf('%s | micromovement <= %d mm/s', localPanelRowLabel(cfg), immobilityThresholdMmps), ...
        'FontSize', 15, 'FontWeight', 'bold');
    localAnnotatePair(ax2, pooled.(microKey), emotionList);

    % Regime contrast panel
    ax3 = nexttile(tl, (rowIdx - 1) * 3 + 3);
    localPlotRegimeContrast(ax3, pooled.(fullKey), pooled.(microKey), emotionList, emotionColorMap, cfg.doBaselineNormalize);
    title(ax3, sprintf('%s | regime contrast', localPanelRowLabel(cfg)), 'FontSize', 15, 'FontWeight', 'bold');
end

lgd = legend(findall(f, 'Type', 'Line', '-and', 'LineWidth', 2.4), fliplr(emotionList), ...
    'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
set(lgd, 'FontSize', 13);

annotation(f, 'textbox', [0.70 0.935 0.28 0.05], ...
    'String', 'Crossing lines in col. 3 indicate a regime-dependent sign flip', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'right', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);

exportgraphics(f, fullfile(outDir, 'disgust_joy_head_regime_panels.png'), 'Resolution', 220);
exportgraphics(f, fullfile(outDir, 'disgust_joy_head_regime_panels.pdf'), 'ContentType', 'vector');
savefig(f, fullfile(outDir, 'disgust_joy_head_regime_panels.fig'));

fprintf('Saved figure and summary table under:\n%s\n', outDir);

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

function vals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroup, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples)
    vals = localCollectRawSamplesForSubject(rc, vidToEmotion, markerGroup, emotion, speedField);
    if ~doBaselineNormalize
        return;
    end
    baseVal = localBaselineScalarForSubject(rc, vidToEmotion, markerGroup, baselineEmotion, baselineFromField, minBaselineSamples);
    if ~isfinite(baseVal)
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
    if isempty(emoCol)
        return;
    end
    idx = strcmp(st.markerGroup, markerGroup) & strcmp(emoCol, emotion);
    if ~any(idx)
        return;
    end
    cellVals = st.(speedField)(idx);
    for i = 1:numel(cellVals)
        v = cellVals{i};
        if isempty(v), continue; end
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
    if ~isfield(rc,'summaryTable') || isempty(rc.summaryTable)
        return;
    end
    st = rc.summaryTable;
    if ~ismember('markerGroup', st.Properties.VariableNames) || ~ismember('videoID', st.Properties.VariableNames)
        return;
    end
    emoCol = localEmotionColumn(st, vidToEmotion);
    idx = strcmp(st.markerGroup, markerGroup) & strcmp(emoCol, baselineEmotion);
    if ~any(idx) || ~ismember(baselineFromField, st.Properties.VariableNames)
        return;
    end
    v = st.(baselineFromField)(idx);
    if iscell(v)
        vv = [];
        for i = 1:numel(v)
            if ~isempty(v{i})
                vv = [vv; v{i}(:)]; %#ok<AGROW>
            end
        end
        vv = vv(~isnan(vv));
        if numel(vv) < minBaselineSamples
            return;
        end
        baseVal = median(vv, 'omitnan');
    else
        v = v(~isnan(v));
        if isempty(v)
            return;
        end
        baseVal = median(v, 'omitnan');
    end
    if ~(isfinite(baseVal) && baseVal > 0)
        baseVal = NaN;
    end
end

function v = localApplyOutlierCut(v, outlierQuantile)
    v = v(~isnan(v));
    if isempty(v) || isempty(outlierQuantile)
        return;
    end
    cutoff = quantile(v, outlierQuantile);
    v(v > cutoff) = [];
end

function localPlotPooledEcdfs(ax, pooledVals, emotionList, emotionColorMap)
    hold(ax, 'on');
    for i = 1:numel(pooledVals)
        v = pooledVals{i};
        if isempty(v), continue; end
        [f, x] = ecdf(v);
        emo = emotionList{i};
        stairs(ax, x, f, 'LineWidth', 2.4, 'Color', emotionColorMap(emo), 'DisplayName', emo);
    end
end

function localStyleCdfAxes(ax, doBaselineNormalize, useImmobile)
    grid(ax, 'on');
    set(ax, 'FontSize', 13, 'LineWidth', 1.0, 'Box', 'off');
    ylabel(ax, 'CDF', 'FontSize', 14, 'FontWeight', 'bold');
    if doBaselineNormalize
        xlabel(ax, 'Speed samples (fold baseline)', 'FontSize', 14, 'FontWeight', 'bold');
    else
        xlabel(ax, 'Speed samples (mm/s)', 'FontSize', 14, 'FontWeight', 'bold');
    end
    if useImmobile
        xlim(ax, 'tight');
    end
end

function localAnnotatePair(ax, pooledVals, emotionList)
    if numel(pooledVals) ~= 2
        return;
    end
    a = pooledVals{1};
    b = pooledVals{2};
    if isempty(a) || isempty(b)
        return;
    end
    pKW = kruskalwallis([a(:); b(:)], [repmat(emotionList(1), numel(a), 1); repmat(emotionList(2), numel(b), 1)], 'off');
    [~, pPair] = kstest2(a, b);
    text(ax, 0.02, 0.96, sprintf('KW p=%.2g', pKW), 'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold');
    text(ax, 0.02, 0.89, sprintf('%s vs %s KS p=%.2g', emotionList{1}, emotionList{2}, pPair), ...
        'Units', 'normalized', 'FontSize', 10, 'Color', [0.25 0.25 0.25]);
end

function localPlotRegimeContrast(ax, fullVals, microVals, emotionList, emotionColorMap, doBaselineNormalize)
    hold(ax, 'on');
    x = [1 2];
    medFull = zeros(1, numel(emotionList));
    medMicro = zeros(1, numel(emotionList));
    for i = 1:numel(emotionList)
        medFull(i) = median(fullVals{i}, 'omitnan');
        medMicro(i) = median(microVals{i}, 'omitnan');
        plot(ax, x, [medFull(i), medMicro(i)], '-o', ...
            'Color', emotionColorMap(emotionList{i}), ...
            'LineWidth', 2.8, ...
            'MarkerFaceColor', emotionColorMap(emotionList{i}), ...
            'MarkerSize', 8, ...
            'DisplayName', emotionList{i});
    end
    set(ax, 'XTick', x, 'XTickLabel', {'Full', 'Micro'}, 'FontSize', 13, 'LineWidth', 1.0, 'Box', 'off');
    grid(ax, 'on');
    if doBaselineNormalize
        ylabel(ax, 'Median speed (fold baseline)', 'FontSize', 14, 'FontWeight', 'bold');
    else
        ylabel(ax, 'Median speed (mm/s)', 'FontSize', 14, 'FontWeight', 'bold');
    end

    deltaFull = medFull(1) - medFull(2);
    deltaMicro = medMicro(1) - medMicro(2);
    text(ax, 0.03, 0.95, sprintf('\\Delta(full) = %.3g', deltaFull), 'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold');
    text(ax, 0.03, 0.88, sprintf('\\Delta(micro) = %.3g', deltaMicro), 'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold');
    yline(ax, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
end

function label = localNormLabel(doBaselineNormalize)
    if doBaselineNormalize
        label = 'baseline-normalized';
    else
        label = 'absolute';
    end
end

function label = localPanelRowLabel(cfg)
    if cfg.doBaselineNormalize
        label = 'Baseline-normalized';
    else
        label = 'Absolute';
    end
end
