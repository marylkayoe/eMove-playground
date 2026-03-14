% analyze_regime_distinctness_subject_level.m
%
% Subject-level follow-up to the pooled regime-distinctness analysis.
%
% Main question:
%   Are regime-dependent changes visible within individual subjects, or are
%   they mainly a pooled-across-subjects artifact?
%
% Strategy:
%   1. For each subject and bodypart, build emotion vectors from:
%      - medianSpeed (full)
%      - medianSpeedImmobile (micro)
%   2. Compare full vs micro emotion ordering within subject using Spearman rho.
%   3. For every emotion pair, ask whether the within-subject contrast flips sign
%      between full and micro.
%   4. Summarize by bodypart:
%      - median subject rho
%      - fraction of negative subject rho
%      - fraction of subjects showing sign flips for each emotion pair

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
baselineEmotion = 'BASELINE';

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
outDir = fullfile(repoRoot, 'outputs', 'figures', ['regime_subject_level_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
codingTable = localLoadStimCodingTable(stimCsv);
[vidToEmotion, codingEmotions] = localBuildVideoMap(codingTable);
emotionList = setdiff(codingEmotions, {'BASELINE','0','X','AMUSEMENT',''}, 'stable');
markerGroups = localCollectMarkerGroups(resultsCell);
[pairTable, pairLabels] = localEmotionPairs(emotionList);

fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Output dir: %s\n', outDir);

subjectVectorRows = {};
rhoRows = {};
flipRows = {};

for normIdx = 1:2
    doBaselineNormalize = normIdx == 2;
    normLabel = localNormLabel(doBaselineNormalize);

    for s = 1:numel(resultsCell)
        rc = resultsCell{s};
        subjID = localSubjectID(rc, s);
        if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
            continue;
        end
        st = rc.summaryTable;
        emoCol = localEmotionColumn(st, vidToEmotion);
        if isempty(emoCol)
            continue;
        end

        for g = 1:numel(markerGroups)
            mg = markerGroups{g};
            fullVec = nan(numel(emotionList), 1);
            microVec = nan(numel(emotionList), 1);

            baseFull = 1;
            baseMicro = 1;
            if doBaselineNormalize
                baseFull = localBaselineSummaryScalar(st, emoCol, mg, baselineEmotion, 'medianSpeed');
                baseMicro = localBaselineSummaryScalar(st, emoCol, mg, baselineEmotion, 'medianSpeedImmobile');
            end

            for e = 1:numel(emotionList)
                emo = emotionList{e};
                fullVal = localEmotionSummaryScalar(st, emoCol, mg, emo, 'medianSpeed');
                microVal = localEmotionSummaryScalar(st, emoCol, mg, emo, 'medianSpeedImmobile');

                if doBaselineNormalize
                    if isfinite(baseFull) && baseFull > 0 && isfinite(fullVal)
                        fullVal = fullVal ./ baseFull;
                    else
                        fullVal = NaN;
                    end
                    if isfinite(baseMicro) && baseMicro > 0 && isfinite(microVal)
                        microVal = microVal ./ baseMicro;
                    else
                        microVal = NaN;
                    end
                end

                fullVec(e) = fullVal;
                microVec(e) = microVal;

                subjectVectorRows(end+1, :) = {normLabel, subjID, mg, emo, fullVal, microVal}; %#ok<AGROW>
            end

            validMask = isfinite(fullVec) & isfinite(microVec);
            rho = NaN;
            nValid = nnz(validMask);
            if nValid >= 3
                rho = corr(fullVec(validMask), microVec(validMask), 'Type', 'Spearman');
            end
            rhoRows(end+1, :) = {normLabel, subjID, mg, nValid, rho}; %#ok<AGROW>

            for pIdx = 1:height(pairTable)
                iA = pairTable.idxA(pIdx);
                iB = pairTable.idxB(pIdx);
                deltaFull = fullVec(iB) - fullVec(iA);
                deltaMicro = microVec(iB) - microVec(iA);
                comparable = isfinite(deltaFull) && isfinite(deltaMicro);
                signFlip = false;
                if comparable
                    signFlip = sign(deltaFull) ~= 0 && sign(deltaMicro) ~= 0 && sign(deltaFull) ~= sign(deltaMicro);
                end
                flipRows(end+1, :) = {normLabel, subjID, mg, pairLabels{pIdx}, comparable, deltaFull, deltaMicro, signFlip}; %#ok<AGROW>
            end
        end
    end
end

subjectVectorTbl = cell2table(subjectVectorRows, ...
    'VariableNames', {'normalization','subjectID','markerGroup','emotion','fullMedian','microMedian'});
rhoTbl = cell2table(rhoRows, ...
    'VariableNames', {'normalization','subjectID','markerGroup','nValidEmotions','spearmanRho'});
flipTbl = cell2table(flipRows, ...
    'VariableNames', {'normalization','subjectID','markerGroup','pairLabel','comparable','deltaFull','deltaMicro','signFlip'});

writetable(subjectVectorTbl, fullfile(outDir, 'subject_regime_vectors.csv'));
writetable(rhoTbl, fullfile(outDir, 'subject_regime_rho.csv'));
writetable(flipTbl, fullfile(outDir, 'subject_pairwise_flips.csv'));

%% Bodypart summary table
summaryRows = {};
for normIdx = 1:2
    normLabel = localNormLabel(normIdx == 2);
    for g = 1:numel(markerGroups)
        mg = markerGroups{g};
        idxR = strcmp(rhoTbl.normalization, normLabel) & strcmp(rhoTbl.markerGroup, mg);
        rv = rhoTbl.spearmanRho(idxR);
        rv = rv(isfinite(rv));
        medRho = median(rv, 'omitnan');
        fracNegRho = mean(rv < 0, 'omitnan');

        idxF = strcmp(flipTbl.normalization, normLabel) & strcmp(flipTbl.markerGroup, mg) & flipTbl.comparable;
        FT = flipTbl(idxF, :);
        pairFlipFracs = nan(height(pairTable), 1);
        for pIdx = 1:height(pairTable)
            iPair = strcmp(FT.pairLabel, pairLabels{pIdx});
            if any(iPair)
                pairFlipFracs(pIdx) = mean(FT.signFlip(iPair));
            end
        end
        medianPairFlip = median(pairFlipFracs, 'omitnan');
        maxPairFlip = max(pairFlipFracs, [], 'omitnan');
        summaryRows(end+1, :) = {normLabel, mg, medRho, fracNegRho, medianPairFlip, maxPairFlip}; %#ok<AGROW>
    end
end
summaryTbl = cell2table(summaryRows, ...
    'VariableNames', {'normalization','markerGroup','medianSubjectRho','fractionNegativeRho','medianPairFlipFraction','maxPairFlipFraction'});
writetable(summaryTbl, fullfile(outDir, 'subject_regime_summary.csv'));

%% Figure 1: subject-level rho / flip summary heatmap
f1 = figure('Color', 'w', 'Units', 'pixels', 'Position', [120 120 980 900]);
tl = tiledlayout(f1, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, 'Subject-level regime-distinctness summary', 'FontSize', 20, 'FontWeight', 'bold');

panels = { ...
    {'medianSubjectRho', 'Median subject Spearman rho', [-1 1], parula}, ...
    {'fractionNegativeRho', 'Fraction of subjects with negative rho', [0 1], turbo}, ...
    {'medianPairFlipFraction', 'Median across emotion-pair subject flip fractions', [0 1], turbo}};

for i = 1:3
    ax = nexttile(tl, i);
    fieldName = panels{i}{1};
    panelTitle = panels{i}{2};
    clim = panels{i}{3};
    cmap = panels{i}{4};
    mat = localSummaryMatrix(summaryTbl, markerGroups, {'absolute','baseline-normalized'}, fieldName);
    imagesc(ax, mat, clim);
    colormap(ax, cmap);
    cb = colorbar(ax);
    ylabel(cb, fieldName, 'Interpreter', 'none');
    title(ax, panelTitle, 'FontSize', 14, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:2, 'XTickLabel', {'Absolute','Normalized'}, ...
        'YTick', 1:numel(markerGroups), 'YTickLabel', strrep(markerGroups, '_', '-'), ...
        'FontSize', 12, 'LineWidth', 1.0, 'Box', 'off');
    for r = 1:size(mat,1)
        for c = 1:size(mat,2)
            if isfinite(mat(r,c))
                text(ax, c, r, sprintf('%.2f', mat(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'FontWeight', 'bold', 'Color', localHeatmapTextColor(mat(r,c), i == 1));
            end
        end
    end
end
exportgraphics(f1, fullfile(outDir, 'subject_regime_summary.png'), 'Resolution', 220);
exportgraphics(f1, fullfile(outDir, 'subject_regime_summary.pdf'), 'ContentType', 'vector');
savefig(f1, fullfile(outDir, 'subject_regime_summary.fig'));

%% Figure 2: pairwise sign-flip fractions by bodypart
for normIdx = 1:2
    normLabel = localNormLabel(normIdx == 2);
    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [120 120 1200 900]);
    ax = axes('Parent', f);
    mat = localPairFlipMatrix(flipTbl, markerGroups, pairLabels, normLabel);
    imagesc(ax, mat, [0 1]);
    colormap(ax, turbo);
    colorbar(ax);
    title(ax, sprintf('Subject-level sign-flip fraction by emotion pair | %s', normLabel), ...
        'Interpreter', 'none', 'FontSize', 18, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:numel(pairLabels), 'XTickLabel', pairLabels, ...
        'YTick', 1:numel(markerGroups), 'YTickLabel', strrep(markerGroups, '_', '-'), ...
        'FontSize', 11, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax, 40);
    for r = 1:size(mat,1)
        for c = 1:size(mat,2)
            if isfinite(mat(r,c))
                text(ax, c, r, sprintf('%.2f', mat(r,c)), 'HorizontalAlignment', 'center', ...
                    'FontSize', 9, 'FontWeight', 'bold', 'Color', localHeatmapTextColor(mat(r,c), false));
            end
        end
    end
    baseName = sprintf('subject_pair_flip_heatmap_%s', strrep(normLabel, '-', '_'));
    exportgraphics(f, fullfile(outDir, [baseName '.png']), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, [baseName '.pdf']), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, [baseName '.fig']));
end

fprintf('Saved subject-level regime outputs under:\n%s\n', outDir);

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

function subjID = localSubjectID(rc, fallbackIndex)
    if isfield(rc, 'subjectID') && ~isempty(rc.subjectID)
        subjID = char(string(rc.subjectID));
    else
        subjID = sprintf('subj%02d', fallbackIndex);
    end
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

function val = localBaselineSummaryScalar(st, emoCol, markerGroup, baselineEmotion, fieldName)
    val = localEmotionSummaryScalar(st, emoCol, markerGroup, baselineEmotion, fieldName);
end

function val = localEmotionSummaryScalar(st, emoCol, markerGroup, emotion, fieldName)
    val = NaN;
    if ~ismember(fieldName, st.Properties.VariableNames)
        return;
    end
    idx = strcmp(st.markerGroup, markerGroup) & strcmp(emoCol, emotion);
    if ~any(idx)
        return;
    end
    v = st.(fieldName)(idx);
    v = v(~isnan(v));
    if isempty(v)
        return;
    end
    val = median(v, 'omitnan');
end

function label = localNormLabel(doBaselineNormalize)
    if doBaselineNormalize
        label = 'baseline-normalized';
    else
        label = 'absolute';
    end
end

function mat = localSummaryMatrix(summaryTbl, markerGroups, normLabels, fieldName)
    mat = nan(numel(markerGroups), numel(normLabels));
    for r = 1:numel(markerGroups)
        for c = 1:numel(normLabels)
            idx = strcmp(summaryTbl.markerGroup, markerGroups{r}) & strcmp(summaryTbl.normalization, normLabels{c});
            if any(idx)
                mat(r,c) = summaryTbl.(fieldName)(find(idx,1));
            end
        end
    end
end

function mat = localPairFlipMatrix(flipTbl, markerGroups, pairLabels, normLabel)
    mat = nan(numel(markerGroups), numel(pairLabels));
    T = flipTbl(strcmp(flipTbl.normalization, normLabel) & flipTbl.comparable, :);
    for r = 1:numel(markerGroups)
        for c = 1:numel(pairLabels)
            idx = strcmp(T.markerGroup, markerGroups{r}) & strcmp(T.pairLabel, pairLabels{c});
            if any(idx)
                mat(r,c) = mean(T.signFlip(idx));
            end
        end
    end
end

function c = localHeatmapTextColor(val, useDivergingRule)
    if useDivergingRule
        if abs(val) > 0.45
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
