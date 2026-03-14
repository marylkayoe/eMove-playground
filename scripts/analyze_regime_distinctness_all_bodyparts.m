% analyze_regime_distinctness_all_bodyparts.m
%
% Ask whether low-animation / micromovement behavior looks like a simple
% downscaled shadow of full movement, or whether emotion relationships change
% across regimes.
%
% Strategy:
%   1. Use pooled raw samples across subjects.
%   2. For each bodypart and emotion, compute pooled medians in:
%      - full-speed regime
%      - micromovement regime
%   3. Quantify regime agreement using:
%      - Spearman rank correlation across emotion medians
%      - fraction of emotion-pair contrasts that flip sign
%   4. Plot pairwise-contrast scatter:
%      x = full-regime contrast
%      y = micro-regime contrast
%      If micro is just a shadow of full movement, points should stay on one
%      diagonal and preserve sign. Quadrant flips argue against that.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
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
outDir = fullfile(repoRoot, 'outputs', 'figures', ['regime_distinctness_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
codingTable = localLoadStimCodingTable(stimCsv);
[vidToEmotion, codingEmotions] = localBuildVideoMap(codingTable);
emotionList = setdiff(codingEmotions, {'BASELINE','0','X','AMUSEMENT','','FEAR'}, 'stable');
markerGroups = localCollectMarkerGroups(resultsCell);
emotionColorMap = localBuildEmotionColorMap(codingTable, emotionList);
[pairTable, pairLabels] = localEmotionPairs(emotionList);
markerGroupsPlot = setdiff(markerGroups, {'LOWER_LIMB_L','LOWER_LIMB_R'}, 'stable');

fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Output dir: %s\n', outDir);
fprintf('Marker groups: %s\n', strjoin(markerGroups, ', '));
fprintf('Emotions: %s\n', strjoin(emotionList, ', '));
fprintf('Presentation plot groups: %s\n', strjoin(markerGroupsPlot, ', '));

%% Collect pooled medians
medianRecords = {};
diagnosticRows = {};
pairwiseRows = {};

for normIdx = 1:2
    doBaselineNormalize = normIdx == 2;
    normLabel = localNormLabel(doBaselineNormalize);

    for g = 1:numel(markerGroups)
        mg = markerGroups{g};
        fullVals = cell(numel(emotionList), 1);
        microVals = cell(numel(emotionList), 1);
        fullMed = nan(numel(emotionList), 1);
        microMed = nan(numel(emotionList), 1);

        for e = 1:numel(emotionList)
            emo = emotionList{e};
            fullVals{e} = localCollectPooledRaw(resultsCell, vidToEmotion, mg, emo, ...
                'speedArray', doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples, outlierQuantile);
            microVals{e} = localCollectPooledRaw(resultsCell, vidToEmotion, mg, emo, ...
                'speedArrayImmobile', doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples, outlierQuantile);
            fullMed(e) = median(fullVals{e}, 'omitnan');
            microMed(e) = median(microVals{e}, 'omitnan');

            medianRecords(end+1, :) = {normLabel, mg, emo, 'full', numel(fullVals{e}), fullMed(e)}; %#ok<AGROW>
            medianRecords(end+1, :) = {normLabel, mg, emo, 'micro', numel(microVals{e}), microMed(e)}; %#ok<AGROW>
        end

        validMask = isfinite(fullMed) & isfinite(microMed);
        if nnz(validMask) >= 3
            rho = corr(fullMed(validMask), microMed(validMask), 'Type', 'Spearman');
        else
            rho = NaN;
        end

        nFlip = 0;
        nComparable = 0;
        for pIdx = 1:height(pairTable)
            iA = pairTable.idxA(pIdx);
            iB = pairTable.idxB(pIdx);
            deltaFull = fullMed(iB) - fullMed(iA);
            deltaMicro = microMed(iB) - microMed(iA);
            if ~(isfinite(deltaFull) && isfinite(deltaMicro))
                continue;
            end
            nComparable = nComparable + 1;
            signFlip = sign(deltaFull) ~= 0 && sign(deltaMicro) ~= 0 && sign(deltaFull) ~= sign(deltaMicro);
            if signFlip
                nFlip = nFlip + 1;
            end
            pairwiseRows(end+1, :) = {normLabel, mg, pairLabels{pIdx}, deltaFull, deltaMicro, signFlip}; %#ok<AGROW>
        end
        if nComparable > 0
            flipFrac = nFlip / nComparable;
        else
            flipFrac = NaN;
        end

        diagnosticRows(end+1, :) = {normLabel, mg, rho, nFlip, nComparable, flipFrac}; %#ok<AGROW>
    end
end

medianTbl = cell2table(medianRecords, ...
    'VariableNames', {'normalization','markerGroup','emotion','regime','nSamples','medianValue'});
diagnosticTbl = cell2table(diagnosticRows, ...
    'VariableNames', {'normalization','markerGroup','spearmanRho','nSignFlip','nComparablePairs','signFlipFraction'});
pairwiseTbl = cell2table(pairwiseRows, ...
    'VariableNames', {'normalization','markerGroup','pairLabel','deltaFull','deltaMicro','signFlip'});

writetable(medianTbl, fullfile(outDir, 'pooled_regime_medians.csv'));
writetable(diagnosticTbl, fullfile(outDir, 'regime_diagnostics.csv'));
writetable(pairwiseTbl, fullfile(outDir, 'pairwise_regime_contrasts.csv'));

%% Figure 1: pooled medians by bodypart/emotion/regime
for normIdx = 1:2
    normLabel = localNormLabel(normIdx == 2);
    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [120 100 1500 820]);
    tl = tiledlayout(f, 3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    title(tl, sprintf('Pooled emotion medians by bodypart (upper body focus) | %s', normLabel), ...
        'Interpreter', 'none', 'FontSize', 20, 'FontWeight', 'bold');

    T = medianTbl(strcmp(medianTbl.normalization, normLabel), :);
    for g = 1:numel(markerGroupsPlot)
        mg = markerGroupsPlot{g};
        ax = nexttile(tl, g); hold(ax, 'on');
        Tmg = T(strcmp(T.markerGroup, mg), :);

        fullMed = nan(numel(emotionList),1);
        microMed = nan(numel(emotionList),1);
        for e = 1:numel(emotionList)
            emo = emotionList{e};
            idxFull = strcmp(Tmg.emotion, emo) & strcmp(Tmg.regime, 'full');
            idxMicro = strcmp(Tmg.emotion, emo) & strcmp(Tmg.regime, 'micro');
            if any(idxFull), fullMed(e) = Tmg.medianValue(find(idxFull, 1)); end
            if any(idxMicro), microMed(e) = Tmg.medianValue(find(idxMicro, 1)); end
            plot(ax, 1, fullMed(e), 'o', 'MarkerFaceColor', emotionColorMap(emo), ...
                'MarkerEdgeColor', emotionColorMap(emo), 'MarkerSize', 7, 'HandleVisibility', 'off');
            plot(ax, 2, microMed(e), 'o', 'MarkerFaceColor', emotionColorMap(emo), ...
                'MarkerEdgeColor', emotionColorMap(emo), 'MarkerSize', 7, 'HandleVisibility', 'off');
            plot(ax, [1 2], [fullMed(e) microMed(e)], '-', 'Color', emotionColorMap(emo), ...
                'LineWidth', 2.0, 'DisplayName', emo);
        end

        set(ax, 'XTick', [1 2], 'XTickLabel', {'Full','Micro'}, 'FontSize', 12, 'Box', 'off', 'LineWidth', 1.0);
        grid(ax, 'on');
        title(ax, strrep(mg, '_', '-'), 'Interpreter', 'none', 'FontSize', 14, 'FontWeight', 'bold');
        if normIdx == 1
            ylabel(ax, 'Median speed (mm/s)', 'FontSize', 13, 'FontWeight', 'bold');
        else
            ylabel(ax, 'Median speed (fold baseline)', 'FontSize', 13, 'FontWeight', 'bold');
        end
    end

    lgd = legend(findall(f, 'Type', 'Line', '-and', 'LineWidth', 2), fliplr(emotionList), ...
        'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
    set(lgd, 'FontSize', 12);
    baseName = sprintf('regime_medians_%s', strrep(normLabel, '-', '_'));
    exportgraphics(f, fullfile(outDir, [baseName '.png']), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, [baseName '.pdf']), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, [baseName '.fig']));
end

%% Figure 2: regime diagnostics summary
fDiag = figure('Color', 'w', 'Units', 'pixels', 'Position', [140 120 980 760]);
tlDiag = tiledlayout(fDiag, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tlDiag, 'Regime distinctness diagnostics across bodyparts (upper body focus)', ...
    'FontSize', 20, 'FontWeight', 'bold');

for panelIdx = 1:2
    ax = nexttile(tlDiag, panelIdx);
    if panelIdx == 1
        mat = localDiagnosticMatrix(diagnosticTbl, markerGroupsPlot, {'absolute','baseline-normalized'}, 'spearmanRho');
        imagesc(ax, mat, [-1 1]);
        colormap(ax, parula);
        cb = colorbar(ax);
        ylabel(cb, 'Spearman rho');
        title(ax, 'Emotion-rank agreement: full vs micro', 'FontSize', 15, 'FontWeight', 'bold');
        fmt = '%.2f';
    else
        mat = localDiagnosticMatrix(diagnosticTbl, markerGroupsPlot, {'absolute','baseline-normalized'}, 'signFlipFraction');
        imagesc(ax, mat, [0 1]);
        colormap(ax, turbo);
        cb = colorbar(ax);
        ylabel(cb, 'Sign-flip fraction');
        title(ax, 'Fraction of emotion-pair contrasts that flip sign', 'FontSize', 15, 'FontWeight', 'bold');
        fmt = '%.2f';
    end
    set(ax, 'XTick', 1:2, 'XTickLabel', {'Absolute','Normalized'}, ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 12, 'LineWidth', 1.0, 'Box', 'off');
    for r = 1:size(mat,1)
        for c = 1:size(mat,2)
            if isfinite(mat(r,c))
                text(ax, c, r, sprintf(fmt, mat(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'FontWeight', 'bold', 'Color', localHeatmapTextColor(mat(r,c), panelIdx));
            end
        end
    end
end
exportgraphics(fDiag, fullfile(outDir, 'regime_diagnostics_summary.png'), 'Resolution', 220);
exportgraphics(fDiag, fullfile(outDir, 'regime_diagnostics_summary.pdf'), 'ContentType', 'vector');
savefig(fDiag, fullfile(outDir, 'regime_diagnostics_summary.fig'));

%% Figure 3: pairwise contrast scatter
for normIdx = 1:2
    normLabel = localNormLabel(normIdx == 2);
    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [120 80 1500 900]);
    tl = tiledlayout(f, 3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    title(tl, sprintf('Pairwise emotion contrasts (FEAR excluded): full vs micro | %s | upper body focus', normLabel), ...
        'Interpreter', 'none', 'FontSize', 20, 'FontWeight', 'bold');

    T = pairwiseTbl(strcmp(pairwiseTbl.normalization, normLabel), :);
    for g = 1:numel(markerGroupsPlot)
        mg = markerGroupsPlot{g};
        ax = nexttile(tl, g); hold(ax, 'on');
        Tmg = T(strcmp(T.markerGroup, mg), :);
        [xLims, yLims] = localAxisLimits(Tmg.deltaFull, Tmg.deltaMicro);
        diagMin = min([xLims(1), yLims(1)]);
        diagMax = max([xLims(2), yLims(2)]);
        plot(ax, [diagMin diagMax], [diagMin diagMax], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2, 'HandleVisibility', 'off');
        xline(ax, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
        yline(ax, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');

        for pIdx = 1:height(Tmg)
            if Tmg.signFlip(pIdx)
                mkFace = [0 0 0];
                mkSize = 70;
            else
                mkFace = [0.85 0.85 0.85];
                mkSize = 40;
            end
            scatter(ax, Tmg.deltaFull(pIdx), Tmg.deltaMicro(pIdx), mkSize, ...
                'MarkerFaceColor', mkFace, 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 1.0);
            text(ax, Tmg.deltaFull(pIdx), Tmg.deltaMicro(pIdx), [' ' Tmg.pairLabel{pIdx}], ...
                'FontSize', 8, 'Interpreter', 'none');
        end

        drow = diagnosticTbl(strcmp(diagnosticTbl.normalization, normLabel) & strcmp(diagnosticTbl.markerGroup, mg), :);
        title(ax, sprintf('%s | rho=%.2f | flip=%.2f', strrep(mg, '_', '-'), drow.spearmanRho(1), drow.signFlipFraction(1)), ...
            'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
        xlabel(ax, '\Delta full', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel(ax, '\Delta micro', 'FontSize', 12, 'FontWeight', 'bold');
        xlim(ax, xLims);
        ylim(ax, yLims);
        grid(ax, 'on');
        set(ax, 'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    end

    annotation(f, 'textbox', [0.70 0.945 0.28 0.04], ...
        'String', 'Black-filled points = sign flips between regimes', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'right', 'FontSize', 11, 'Color', [0.25 0.25 0.25]);
    baseName = sprintf('pairwise_contrast_scatter_%s', strrep(normLabel, '-', '_'));
    exportgraphics(f, fullfile(outDir, [baseName '.png']), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, [baseName '.pdf']), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, [baseName '.fig']));
end

fprintf('Saved regime-distinctness outputs under:\n%s\n', outDir);

%% Local helpers
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

function markerGroups = localCollectMarkerGroups(resultsCell)
    markerGroups = {};
    for s = 1:numel(resultsCell)
        rc = resultsCell{s};
        if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
            continue;
        end
        st = rc.summaryTable;
        if ismember('markerGroup', st.Properties.VariableNames)
            markerGroups = [markerGroups; unique(cellstr(string(st.markerGroup)), 'stable')]; %#ok<AGROW>
        end
    end
    markerGroups = unique(markerGroups, 'stable');
end

function [pairTable, pairLabels] = localEmotionPairs(emotionList)
    rows = {};
    pairLabels = {};
    for i = 1:numel(emotionList)-1
        for j = i+1:numel(emotionList)
            rows(end+1, :) = {i, j}; %#ok<AGROW>
            pairLabels{end+1,1} = sprintf('%s-%s', emotionList{i}, emotionList{j}); %#ok<AGROW>
        end
    end
    pairTable = cell2table(rows, 'VariableNames', {'idxA','idxB'});
end

function vals = localCollectPooledRaw(resultsCell, vidToEmotion, markerGroup, emotion, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples, outlierQuantile)
    vals = [];
    for s = 1:numel(resultsCell)
        rc = resultsCell{s};
        v = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroup, emotion, speedField, ...
            doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);
        v = localApplyOutlierCut(v, outlierQuantile);
        vals = [vals; v(:)]; %#ok<AGROW>
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

function label = localNormLabel(doBaselineNormalize)
    if doBaselineNormalize
        label = 'baseline-normalized';
    else
        label = 'absolute';
    end
end

function mat = localDiagnosticMatrix(diagnosticTbl, markerGroups, normLabels, fieldName)
    mat = nan(numel(markerGroups), numel(normLabels));
    for r = 1:numel(markerGroups)
        for c = 1:numel(normLabels)
            idx = strcmp(diagnosticTbl.markerGroup, markerGroups{r}) & strcmp(diagnosticTbl.normalization, normLabels{c});
            if any(idx)
                mat(r,c) = diagnosticTbl.(fieldName)(find(idx,1));
            end
        end
    end
end

function [xLims, yLims] = localAxisLimits(xVals, yVals)
    xLims = localPaddedLimits(xVals);
    yLims = localPaddedLimits(yVals);
end

function lims = localPaddedLimits(vals)
    vals = vals(isfinite(vals));
    if isempty(vals)
        lims = [-1 1];
        return;
    end
    vMin = min(vals);
    vMax = max(vals);
    if vMin == vMax
        pad = max(0.15 * max(abs(vMin), 1), 0.25);
    else
        pad = max(0.12 * (vMax - vMin), 0.15);
    end
    lims = [vMin - pad, vMax + pad];
end

function c = localHeatmapTextColor(val, panelIdx)
    if panelIdx == 1
        if abs(val) > 0.55
            c = [1 1 1];
        else
            c = [0 0 0];
        end
    else
        if val > 0.45
            c = [1 1 1];
        else
            c = [0 0 0];
        end
    end
end
