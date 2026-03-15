% make_disgust_subject_example_pack.m
%
% Build a compact subject example pack for one disgust-focused subject:
%   - subject-level disgust-pair scatter (absolute + baseline-normalized)
%   - subject-level density plots (absolute + baseline-normalized)

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
figRoot = fullfile(repoRoot, 'outputs', 'figures');
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');
subjectLevelRoot = fullfile(repoRoot, 'outputs', 'figures');

subjectID = "SC3001";
markerGroupsScatter = {'HEAD', 'UTORSO', 'UPPER_LIMB_L', 'UPPER_LIMB_R', 'WRIST_L', 'WRIST_R', 'LTORSO'};
markerGroupsDensity = {'HEAD', 'UTORSO', 'LTORSO'};
emotionList = {'DISGUST', 'NEUTRAL', 'JOY', 'SAD'};
comparisonEmotions = {'NEUTRAL', 'JOY', 'SAD'};
baselineEmotion = 'BASELINE';
immobilityThresholdMmps = 35;
outlierQuantile = 0.99;
minBaselineSamples = 20;

addpath(genpath(fullfile(repoRoot, 'CODE')));

latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');
latestSubjectLevelDir = localFindLatestStampedDir(subjectLevelRoot, 'regime_subject_level_');
subjectFlipCsv = fullfile(latestSubjectLevelDir, 'subject_pairwise_flips.csv');
if ~isfile(resultsCellPath)
    error('Missing resultsCell: %s', resultsCellPath);
end
if ~isfile(stimCsv)
    error('Missing stim coding CSV: %s', stimCsv);
end
if ~isfile(subjectFlipCsv)
    error('Missing subject_pairwise_flips.csv: %s', subjectFlipCsv);
end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(figRoot, ['disgust_subject_pack_' runStamp '_' char(subjectID)]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
flipTbl = readtable(subjectFlipCsv, 'TextType', 'string');
codingTable = localLoadStimCodingTable(stimCsv);
[vidToEmotion, ~] = localBuildVideoMap(codingTable);
emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList);
rc = localFindSubjectResults(resultsCell, subjectID);

fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Subject: %s\n', subjectID);
fprintf('Output dir: %s\n', outDir);

localMakeScatterFigure(outDir, subjectID, markerGroupsScatter, flipTbl, true);
localMakeDensityFigure(outDir, subjectID, markerGroupsDensity, emotionList, rc, vidToEmotion, emotionColorMap, true, baselineEmotion, minBaselineSamples, outlierQuantile, immobilityThresholdMmps);

fprintf('Saved subject example pack under:\n%s\n', outDir);

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

function latestDir = localFindLatestStampedDir(rootDir, prefix)
    d = dir(rootDir);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(names ~= "." & names ~= "..");
    names = sort(names(startsWith(names, prefix)));
    if isempty(names)
        error('No directories starting with %s under %s', prefix, rootDir);
    end
    latestDir = fullfile(rootDir, char(names(end)));
end

function rc = localFindSubjectResults(resultsCell, subjectID)
    rc = [];
    for i = 1:numel(resultsCell)
        if isfield(resultsCell{i}, 'subjectID') && upper(string(resultsCell{i}.subjectID)) == upper(string(subjectID))
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

function localMakeScatterFigure(outDir, subjectID, markerGroups, flipTbl, doBaselineNormalize)
    normLabel = localNormLabel(doBaselineNormalize);
    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [100 100 1260 920]);
    ax = axes('Parent', f, 'Position', [0.10 0.14 0.60 0.76]);
    hold(ax, 'on');

    Tsub = flipTbl(flipTbl.subjectID == subjectID & flipTbl.comparable == 1 & ...
        flipTbl.normalization == normLabel & contains(flipTbl.pairLabel, "DISGUST") & ...
        ismember(flipTbl.markerGroup, markerGroups), :);
    pairLabels = unique(Tsub.pairLabel, 'stable');
    pairColors = lines(numel(pairLabels));
    xVals = Tsub.deltaFull;
    yVals = Tsub.deltaMicro;

    [xLims, yLims] = localAxisLimits(xVals, yVals);
    localShadeReversalQuadrants(ax, xLims, yLims);
    diagMin = min([xLims(1), yLims(1)]);
    diagMax = max([xLims(2), yLims(2)]);
    plot(ax, [diagMin diagMax], [diagMin diagMax], '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 1.1);
    xline(ax, 0, ':', 'Color', [0.65 0.65 0.65]);
    yline(ax, 0, ':', 'Color', [0.65 0.65 0.65]);
    localAnnotateReversalQuadrants(ax, xLims, yLims);
    for g = 1:numel(markerGroups)
        mg = markerGroups{g};
        Tg = Tsub(Tsub.markerGroup == mg, :);
        for p = 1:height(Tg)
            pairIdx = find(strcmp(cellstr(pairLabels), char(Tg.pairLabel(p))), 1);
            scatter(ax, Tg.deltaFull(p), Tg.deltaMicro(p), 420, ...
                'MarkerFaceColor', pairColors(pairIdx,:), ...
                'MarkerEdgeColor', [0.1 0.1 0.1], ...
                'LineWidth', 1.0, ...
                'MarkerFaceAlpha', ternary(logical(Tg.signFlip(p)), 0.95, 0.25), ...
                'MarkerEdgeAlpha', 0.95);
            text(ax, Tg.deltaFull(p), Tg.deltaMicro(p), sprintf('%d', g), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 14, 'FontWeight', 'bold', 'Color', ternaryColor(logical(Tg.signFlip(p))));
        end
    end
    xlim(ax, xLims);
    ylim(ax, yLims);
    grid(ax, 'on');
    set(ax, 'FontSize', 12, 'LineWidth', 1.0, 'Box', 'off');
    ax.Toolbar.Visible = 'off';
    xlabel(ax, '\Delta full', 'FontSize', 13, 'FontWeight', 'bold');
    ylabel(ax, '\Delta micro', 'FontSize', 13, 'FontWeight', 'bold');
    title(ax, sprintf('%s | disgust-centered subject scatter | %s', strrep(normLabel, '-', ' '), subjectID), ...
        'Interpreter', 'none', 'FontSize', 18, 'FontWeight', 'bold');

    axKey = axes('Parent', f, 'Position', [0.75 0.14 0.20 0.76]);
    axis(axKey, 'off');
    hold(axKey, 'on');
    xlim(axKey, [0 1]);
    ylim(axKey, [0 1]);
    text(axKey, 0.0, 0.98, 'Emotion-pair colors', 'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    for i = 1:numel(pairLabels)
        y = 0.88 - (i-1) * 0.12;
        patch(axKey, [0.02 0.10 0.10 0.02], [y-0.025 y-0.025 y+0.025 y+0.025], pairColors(i,:), ...
            'EdgeColor', [0.1 0.1 0.1], 'LineWidth', 0.8);
        text(axKey, 0.14, y, strrep(pairLabels{i}, '_', '-'), 'FontSize', 12, 'Interpreter', 'none', 'VerticalAlignment', 'middle');
    end
    text(axKey, 0.0, 0.52, 'Bodypart numbers', 'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    for i = 1:numel(markerGroups)
        y = 0.43 - (i-1) * 0.06;
        text(axKey, 0.08, y, sprintf('%d  %s', i, strrep(markerGroups{i}, '_', '-')), ...
            'FontSize', 12.5, 'FontWeight', 'bold', 'Interpreter', 'none');
    end

    exportgraphics(f, fullfile(outDir, sprintf('subject_scatter_%s.png', strrep(normLabel, '-', '_'))), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, sprintf('subject_scatter_%s.pdf', strrep(normLabel, '-', '_'))), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, sprintf('subject_scatter_%s.fig', strrep(normLabel, '-', '_'))));

    writetable(Tsub, fullfile(outDir, sprintf('subject_scatter_%s.csv', strrep(normLabel, '-', '_'))));
    close(f);
end

function localMakeDensityFigure(outDir, subjectID, markerGroups, emotionList, rc, vidToEmotion, emotionColorMap, doBaselineNormalize, baselineEmotion, minBaselineSamples, outlierQuantile, immobilityThresholdMmps)
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

    lgd = legend(legendHandles, emotionList, 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
    set(lgd, 'FontSize', 12);
    annotation(f, 'textbox', [0.12 0.02 0.78 0.04], ...
        'String', sprintf('Separate x-axes for full and micromovement. Thin vertical lines mark medians. Subject: %s', subjectID), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);

    exportgraphics(f, fullfile(outDir, sprintf('subject_density_%s.png', strrep(normLabel, '-', '_'))), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, sprintf('subject_density_%s.pdf', strrep(normLabel, '-', '_'))), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, sprintf('subject_density_%s.fig', strrep(normLabel, '-', '_'))));
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

function label = localNormLabel(doBaselineNormalize)
    if doBaselineNormalize
        label = 'baseline-normalized';
    else
        label = 'absolute';
    end
end

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function c = ternaryColor(isFlip)
    if isFlip
        c = [1 1 1];
    else
        c = [0.1 0.1 0.1];
    end
end

function xlab = localXAxisLabel(doBaselineNormalize)
    if doBaselineNormalize
        xlab = 'Speed (fold baseline)';
    else
        xlab = 'Speed (mm/s)';
    end
end

function [xLims, yLims] = localAxisLimits(xVals, yVals)
    xLims = localPaddedLimits(xVals);
    yLims = localPaddedLimits(yVals);
end

function localShadeReversalQuadrants(ax, xLims, yLims)
    patch(ax, [xLims(1) 0 0 xLims(1)], [0 0 yLims(2) yLims(2)], [0.70 0.88 0.72], ...
        'FaceAlpha', 0.16, 'EdgeColor', 'none');
    patch(ax, [0 xLims(2) xLims(2) 0], [yLims(1) yLims(1) 0 0], [0.93 0.72 0.72], ...
        'FaceAlpha', 0.16, 'EdgeColor', 'none');
end

function localAnnotateReversalQuadrants(ax, xLims, yLims)
    xSpan = xLims(2) - xLims(1);
    if xLims(1) < 0 && yLims(2) > 0
        text(ax, xLims(1) + 0.04*xSpan, 0.5 * yLims(2), 'micro contrast becomes more positive', ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.18 0.40 0.18], ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
    end
    if xLims(2) > 0 && yLims(1) < 0
        text(ax, xLims(2) - 0.04*xSpan, 0.5 * yLims(1), 'micro contrast becomes more negative', ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.55 0.18 0.18], ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
    end
end
