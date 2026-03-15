% make_single_subject_disgust_cdf_figure.m
%
% Build a single-subject disgust-focused CDF figure for head and torso.
% Each panel compares one disgust-centered emotion pair and overlays:
%   - full-motion CDFs
%   - micromovement CDFs
%
% Output:
%   - absolute figure
%   - baseline-normalized figure
%   - summary CSV with medians and sample counts

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');

subjectID = "SC3001";
markerGroups = {'HEAD', 'LTORSO'};
pairList = {
    'DISGUST', 'NEUTRAL';
    'DISGUST', 'JOY';
    'DISGUST', 'SAD'
};
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
outDir = fullfile(repoRoot, 'outputs', 'figures', ['single_subject_disgust_cdf_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
codingTable = localLoadStimCodingTable(stimCsv);
[vidToEmotion, ~] = localBuildVideoMap(codingTable);
emotionColorMap = localBuildEmotionColorMap(codingTable, unique(string(pairList(:)), 'stable'));

rc = localFindSubjectResults(resultsCell, subjectID);
fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Subject: %s\n', subjectID);
fprintf('Output dir: %s\n', outDir);

summaryRows = {};
legendHandles = gobjects(4,1);
for normIdx = 1:2
    doBaselineNormalize = normIdx == 2;
    normLabel = localNormLabel(doBaselineNormalize);

    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [90 70 1650 980]);
    tl = tiledlayout(f, numel(markerGroups), size(pairList,1), 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s | disgust-centered subject CDFs | %s', strrep(normLabel, '-', ' '), subjectID), ...
        'FontSize', 22, 'FontWeight', 'bold', 'Interpreter', 'none');

    for r = 1:numel(markerGroups)
        mg = markerGroups{r};
        for c = 1:size(pairList,1)
            emoA = pairList{c,1};
            emoB = pairList{c,2};
            ax = nexttile(tl, (r-1) * size(pairList,1) + c);
            hold(ax, 'on');

            fullA = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, mg, emoA, 'speedArray', ...
                doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples);
            fullB = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, mg, emoB, 'speedArray', ...
                doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples);
            microA = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, mg, emoA, 'speedArrayImmobile', ...
                doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples);
            microB = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, mg, emoB, 'speedArrayImmobile', ...
                doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples);

            fullA = localApplyOutlierCut(fullA, outlierQuantile);
            fullB = localApplyOutlierCut(fullB, outlierQuantile);
            microA = localApplyOutlierCut(microA, outlierQuantile);
            microB = localApplyOutlierCut(microB, outlierQuantile);

            h1 = localPlotEcdf(ax, fullA, emotionColorMap(char(emoA)), '-', 2.6);
            h2 = localPlotEcdf(ax, fullB, emotionColorMap(char(emoB)), '-', 2.6);
            h3 = localPlotEcdf(ax, microA, emotionColorMap(char(emoA)), '--', 2.6);
            h4 = localPlotEcdf(ax, microB, emotionColorMap(char(emoB)), '--', 2.6);
            if r == 1 && c == 1
                legendHandles = [h1; h2; h3; h4];
            end

            xlim(ax, localPaddedLimits([fullA(:); fullB(:); microA(:); microB(:)]));
            ylim(ax, [0 1]);
            grid(ax, 'on');
            set(ax, 'Box', 'off', 'LineWidth', 1.0, 'FontSize', 11);
            ax.Toolbar.Visible = 'off';

            if r == numel(markerGroups)
                if doBaselineNormalize
                    xlabel(ax, 'Speed (fold baseline)', 'FontSize', 12, 'FontWeight', 'bold');
                else
                    xlabel(ax, 'Speed (mm/s)', 'FontSize', 12, 'FontWeight', 'bold');
                end
            end
            if c == 1
                ylabel(ax, sprintf('%s\nCDF', strrep(mg, '_', '-')), 'FontSize', 12, 'FontWeight', 'bold');
            end

            title(ax, sprintf('%s vs %s', emoA, emoB), 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
            localAnnotatePanel(ax, fullA, fullB, microA, microB, immobilityThresholdMmps);

            summaryRows(end+1, :) = {char(subjectID), normLabel, mg, sprintf('%s-%s', emoA, emoB), ...
                numel(fullA), median(fullA, 'omitnan'), numel(fullB), median(fullB, 'omitnan'), ...
                numel(microA), median(microA, 'omitnan'), numel(microB), median(microB, 'omitnan')}; %#ok<AGROW>
        end
    end

    lgd = legend(legendHandles, { ...
        sprintf('%s full', pairList{1,1}), sprintf('%s full', pairList{1,2}), ...
        sprintf('%s micro', pairList{1,1}), sprintf('%s micro', pairList{1,2})}, ...
        'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
    set(lgd, 'FontSize', 12);

    annotation(f, 'textbox', [0.13 0.02 0.76 0.04], ...
        'String', sprintf('Solid = full motion | dashed = micromovement <= %d mm/s | same-color curves compare DISGUST-centered pairs within one subject', immobilityThresholdMmps), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);

    pngPath = fullfile(outDir, sprintf('single_subject_disgust_cdf_%s.png', strrep(normLabel, '-', '_')));
    pdfPath = fullfile(outDir, sprintf('single_subject_disgust_cdf_%s.pdf', strrep(normLabel, '-', '_')));
    figPath = fullfile(outDir, sprintf('single_subject_disgust_cdf_%s.fig', strrep(normLabel, '-', '_')));
    exportgraphics(f, pngPath, 'Resolution', 220);
    exportgraphics(f, pdfPath, 'ContentType', 'vector');
    savefig(f, figPath);
end

summaryTbl = cell2table(summaryRows, ...
    'VariableNames', {'subjectID','normalization','markerGroup','pairLabel', ...
    'nFullA','medianFullA','nFullB','medianFullB','nMicroA','medianMicroA','nMicroB','medianMicroB'});
writetable(summaryTbl, fullfile(outDir, 'single_subject_disgust_cdf_summary.csv'));

fprintf('Saved single-subject disgust CDF figures under:\n%s\n', outDir);

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
        if isfield(resultsCell{i}, 'subjectID') && string(resultsCell{i}.subjectID) == subjectID
            rc = resultsCell{i};
            return;
        end
    end
    error('Subject %s not found in resultsCell.', subjectID);
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
    if isstring(vids)
        vids = cellstr(vids);
    end
    if isstring(emos)
        emos = cellstr(emos);
    end
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
        e = char(string(emotionList(i)));
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

function h = localPlotEcdf(ax, vals, color, lineStyle, lineWidth)
    vals = vals(isfinite(vals));
    if isempty(vals)
        h = plot(ax, nan, nan, 'Color', color, 'LineStyle', lineStyle, 'LineWidth', lineWidth);
        return;
    end
    [f, x] = ecdf(vals);
    h = plot(ax, x, f, 'Color', color, 'LineStyle', lineStyle, 'LineWidth', lineWidth);
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

function localAnnotatePanel(ax, fullA, fullB, microA, microB, immobilityThresholdMmps)
    txt = sprintf('full med: %.2f vs %.2f\nmicro med: %.2f vs %.2f\nn micro: %d vs %d | <= %d mm/s', ...
        median(fullA, 'omitnan'), median(fullB, 'omitnan'), ...
        median(microA, 'omitnan'), median(microB, 'omitnan'), ...
        numel(microA), numel(microB), immobilityThresholdMmps);
    text(ax, 0.98, 0.05, txt, 'Units', 'normalized', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
        'FontSize', 9, 'BackgroundColor', [1 1 1 0.74], 'Margin', 4, 'Color', [0.2 0.2 0.2]);
end
