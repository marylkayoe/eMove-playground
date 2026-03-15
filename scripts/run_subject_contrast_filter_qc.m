% run_subject_contrast_filter_qc.m
%
% Sensitivity analysis for subject-level reversal counting.
%
% Methods:
%   1. Reference: no filtering beyond comparability.
%   2. Dead-zone filter:
%      - absolute data use absolute dead-zone thresholds
%      - normalized data use normalized dead-zone thresholds
%   3. Bootstrap-CI filter:
%      - include a subject-cell only if full or micro pairwise contrast CI excludes zero

clearvars;
clc;
close all;
rng(1);

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
baselineEmotion = 'BASELINE';
markerGroupsPlot = {'UTORSO','HEAD','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};
outlierQuantile = 0.99;
minBaselineSamples = 20;
deadZoneQuantile = 0.20;
nBootstrap = 30;

addpath(genpath(fullfile(repoRoot, 'CODE')));

analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');
latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');
subjectFlipCsv = fullfile(repoRoot, 'outputs', 'figures', 'regime_subject_level_20260314_195909', 'subject_pairwise_flips.csv');

if ~isfile(resultsCellPath), error('Missing resultsCell: %s', resultsCellPath); end
if ~isfile(stimCsv), error('Missing stim CSV: %s', stimCsv); end
if ~isfile(subjectFlipCsv), error('Missing subject flip CSV: %s', subjectFlipCsv); end

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['subject_contrast_filter_qc_' runStamp]);
if ~exist(outDir, 'dir'), mkdir(outDir); end

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
subjectFlipTbl = readtable(subjectFlipCsv, 'TextType', 'string');
codingTable = localLoadStimCodingTable(stimCsv);
[vidToEmotion, codingEmotions] = localBuildVideoMap(codingTable);
emotionList = setdiff(codingEmotions, {'BASELINE','0','X','AMUSEMENT','','FEAR'}, 'stable');
[pairTable, pairLabels] = localEmotionPairs(emotionList);
pairDisplayLabels = cell(size(pairLabels));
for i = 1:numel(pairLabels)
    pairDisplayLabels{i} = localReversePairLabel(pairLabels{i});
end

subjectFlipTbl = subjectFlipTbl(~contains(subjectFlipTbl.pairLabel, "FEAR") & ...
    ismember(subjectFlipTbl.markerGroup, markerGroupsPlot) & subjectFlipTbl.comparable == 1, :);

fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Output dir: %s\n', outDir);

%% Dead-zone thresholds
deadZoneRows = {};
for normLabel = ["absolute","baseline-normalized"]
    Tn = subjectFlipTbl(subjectFlipTbl.normalization == normLabel, :);
    thrFull = quantile(abs(Tn.deltaFull), deadZoneQuantile);
    thrMicro = quantile(abs(Tn.deltaMicro), deadZoneQuantile);
    deadZoneRows(end+1, :) = {char(normLabel), thrFull, thrMicro}; %#ok<AGROW>
end
deadZoneTbl = cell2table(deadZoneRows, 'VariableNames', {'normalization','thrFull','thrMicro'});
writetable(deadZoneTbl, fullfile(outDir, 'deadzone_thresholds.csv'));

%% Bootstrap-CI inclusion flags
bootRows = {};
for normIdx = 1:2
    doBaselineNormalize = normIdx == 2;
    normLabel = localNormLabel(doBaselineNormalize);
    for s = 1:numel(resultsCell)
        rc = resultsCell{s};
        subjID = localSubjectID(rc, s);
        for g = 1:numel(markerGroupsPlot)
            mg = markerGroupsPlot{g};
            for pIdx = 1:height(pairTable)
                emoA = emotionList{pairTable.idxA(pIdx)};
                emoB = emotionList{pairTable.idxB(pIdx)};
                pairLabel = pairLabels{pIdx};

                [dFull, ciFull, okFull] = localBootstrapPairContrast(rc, vidToEmotion, mg, emoA, emoB, ...
                    'speedArray', doBaselineNormalize, baselineEmotion, 'speedArray', minBaselineSamples, outlierQuantile, nBootstrap);
                [dMicro, ciMicro, okMicro] = localBootstrapPairContrast(rc, vidToEmotion, mg, emoA, emoB, ...
                    'speedArrayImmobile', doBaselineNormalize, baselineEmotion, 'speedArrayImmobile', minBaselineSamples, outlierQuantile, nBootstrap);

                includeCI = false;
                if okFull
                    includeCI = includeCI || (ciFull(1) > 0 || ciFull(2) < 0);
                end
                if okMicro
                    includeCI = includeCI || (ciMicro(1) > 0 || ciMicro(2) < 0);
                end
                bootRows(end+1, :) = {char(normLabel), subjID, mg, pairLabel, dFull, ciFull(1), ciFull(2), ...
                    dMicro, ciMicro(1), ciMicro(2), okFull, okMicro, includeCI}; %#ok<AGROW>
            end
        end
    end
end
bootTbl = cell2table(bootRows, 'VariableNames', {'normalization','subjectID','markerGroup','pairLabel', ...
    'deltaFull','ciFullLow','ciFullHigh','deltaMicro','ciMicroLow','ciMicroHigh','okFull','okMicro','includeCI'});
writetable(bootTbl, fullfile(outDir, 'bootstrap_ci_cells.csv'));

%% Build per-method summary
summaryRows = {};
for normIdx = 1:2
    normLabel = localNormLabel(normIdx == 2);
    Tn = subjectFlipTbl(subjectFlipTbl.normalization == normLabel, :);
    Bn = bootTbl(strcmp(bootTbl.normalization, normLabel), :);
    dzRow = deadZoneTbl(strcmp(deadZoneTbl.normalization, normLabel), :);
    thrFull = dzRow.thrFull;
    thrMicro = dzRow.thrMicro;

    for g = 1:numel(markerGroupsPlot)
        mg = markerGroupsPlot{g};
        for p = 1:numel(pairLabels)
            pairLabel = pairLabels{p};
            rows = Tn(Tn.markerGroup == mg & Tn.pairLabel == pairLabel, :);
            brow = Bn(strcmp(Bn.markerGroup, mg) & strcmp(Bn.pairLabel, pairLabel), :);
            if isempty(rows)
                continue;
            end

            refInclude = true(height(rows),1);
            dzInclude = abs(rows.deltaFull) >= thrFull | abs(rows.deltaMicro) >= thrMicro;

            includeCI = false(height(rows),1);
            if ~isempty(brow)
                [lia, loc] = ismember(rows.subjectID, brow.subjectID);
                includeCI(lia) = brow.includeCI(loc(lia));
            end

            methodName = 'reference';
            includeMask = refInclude;
            nTotal = height(rows);
            nIncluded = sum(includeMask);
            flipFrac = NaN;
            if nIncluded > 0
                flipFrac = mean(localSignFlipMask(rows.signFlip(includeMask)));
            end
            summaryRows(end+1, :) = {char(normLabel), mg, pairLabel, methodName, ...
                nIncluded, nTotal, flipFrac}; %#ok<AGROW>

            methodName = 'deadzone';
            includeMask = dzInclude;
            nTotal = height(rows);
            nIncluded = sum(includeMask);
            flipFrac = NaN;
            if nIncluded > 0
                flipFrac = mean(localSignFlipMask(rows.signFlip(includeMask)));
            end
            summaryRows(end+1, :) = {char(normLabel), mg, pairLabel, methodName, ...
                nIncluded, nTotal, flipFrac}; %#ok<AGROW>

            methodName = 'bootstrap_ci';
            includeMask = includeCI;
                nTotal = height(rows);
                nIncluded = sum(includeMask);
                flipFrac = NaN;
                if nIncluded > 0
                    flipFrac = mean(localSignFlipMask(rows.signFlip(includeMask)));
                end
            summaryRows(end+1, :) = {char(normLabel), mg, pairLabel, methodName, ...
                nIncluded, nTotal, flipFrac}; %#ok<AGROW>
        end
    end
end

summaryTbl = cell2table(summaryRows, 'VariableNames', {'normalization','markerGroup','pairLabel','method','nIncluded','nTotal','flipFraction'});
writetable(summaryTbl, fullfile(outDir, 'subject_contrast_filter_summary.csv'));

%% Figure
f = figure('Color', 'w', 'Units', 'pixels', 'Position', [60 40 1650 1320]);
tl = tiledlayout(f, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Subject-level reversal sensitivity to inclusion rules | dead-zone q=%.2f | bootstrap n=%d', deadZoneQuantile, nBootstrap), ...
    'FontSize', 22, 'FontWeight', 'bold');

methods = {'reference','deadzone','bootstrap_ci'};
methodTitles = { ...
    'Reference: all comparable subject cells', ...
    sprintf('Dead-zone filter: include if |\\Delta full|>=thr or |\\Delta micro|>=thr\n(thr from %.0fth percentile of |\\Delta|)', deadZoneQuantile*100), ...
    'Bootstrap-CI filter: include if full or micro 95% CI excludes zero'};
normLabels = {'absolute','baseline-normalized'};

for r = 1:3
    for c = 1:2
        ax = nexttile(tl, (r-1)*2 + c);
        methodName = methods{r};
        normLabel = normLabels{c};
        localPlotSummaryMatrix(ax, summaryTbl, markerGroupsPlot, pairLabels, pairDisplayLabels, methodName, normLabel, methodTitles{r});
    end
end

annotation(f, 'textbox', [0.08 0.01 0.84 0.05], ...
    'String', 'Each cell shows: fraction of included subjects with sign reversal, then included/total subjects. This is a reversal-specific inclusion analysis, not a KS-significance filter.', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.25 0.25 0.25]);

exportgraphics(f, fullfile(outDir, 'subject_contrast_filter_qc.png'), 'Resolution', 220);
exportgraphics(f, fullfile(outDir, 'subject_contrast_filter_qc.pdf'), 'ContentType', 'vector');
savefig(f, fullfile(outDir, 'subject_contrast_filter_qc.fig'));

%% Report
reportPath = fullfile(repoRoot, 'docs', sprintf('SUBJECT_CONTRAST_FILTER_REPORT_%s.md', datestr(now, 'yyyy-mm-dd')));
localWriteReport(reportPath, outDir, summaryTbl, deadZoneTbl);

fprintf('Saved subject-contrast filter QC under:\n%s\n', outDir);
fprintf('Saved report:\n%s\n', reportPath);

%% Helpers
function latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot)
    d = dir(analysisRunsRoot);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(names ~= "." & names ~= "..");
    isRun = ~cellfun('isempty', regexp(cellstr(names), '^\d{8}_\d{6}$', 'once'));
    names = sort(names(isRun));
    if isempty(names)
        error('No timestamped analysis runs under %s', analysisRunsRoot);
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

function label = localNormLabel(doBaselineNormalize)
    if doBaselineNormalize
        label = 'baseline-normalized';
    else
        label = 'absolute';
    end
end

function subjID = localSubjectID(rc, fallbackIdx)
    subjID = sprintf('S%03d', fallbackIdx);
    if isfield(rc, 'subjectID') && ~isempty(rc.subjectID)
        subjID = char(string(rc.subjectID));
        return;
    end
    if isfield(rc, 'summaryTable') && ~isempty(rc.summaryTable) ...
            && ismember('subjectID', rc.summaryTable.Properties.VariableNames)
        v = rc.summaryTable.subjectID;
        if iscell(v) && ~isempty(v) && ~isempty(v{1})
            subjID = char(string(v{1}));
        end
    end
end

function [delta, ci, ok] = localBootstrapPairContrast(rc, vidToEmotion, markerGroup, emoA, emoB, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples, outlierQuantile, nBootstrap)
    aVals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroup, emoA, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);
    bVals = localCollectRawSamplesForSubjectNormalized(rc, vidToEmotion, markerGroup, emoB, speedField, doBaselineNormalize, baselineEmotion, baselineFromField, minBaselineSamples);
    aVals = localApplyOutlierCut(aVals, outlierQuantile);
    bVals = localApplyOutlierCut(bVals, outlierQuantile);

    ok = numel(aVals) >= 10 && numel(bVals) >= 10;
    delta = NaN;
    ci = [NaN NaN];
    if ~ok
        return;
    end

    delta = median(bVals, 'omitnan') - median(aVals, 'omitnan');
    boot = nan(nBootstrap, 1);
    nA = numel(aVals);
    nB = numel(bVals);
    for b = 1:nBootstrap
        sa = aVals(randi(nA, nA, 1));
        sb = bVals(randi(nB, nB, 1));
        boot(b) = median(sb, 'omitnan') - median(sa, 'omitnan');
    end
    ci = prctile(boot, [2.5 97.5]);
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

    v = st.(baselineFromField)(idx);
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
    if ~(isfinite(baseVal) && baseVal > 0)
        baseVal = NaN;
    end
end

function v = localApplyOutlierCut(v, outlierQuantile)
    v = v(~isnan(v));
    if isempty(v)
        return;
    end
    cutoff = quantile(v, outlierQuantile);
    v(v > cutoff) = [];
end

function out = localReversePairLabel(label)
    parts = split(string(label), "-");
    if numel(parts) == 2
        out = char(parts(2) + "-" + parts(1));
    else
        out = char(label);
    end
end

function localPlotSummaryMatrix(ax, summaryTbl, markerGroupsPlot, pairLabels, pairDisplayLabels, methodName, normLabel, rowTitle)
    M = nan(numel(markerGroupsPlot), numel(pairLabels));
    N = nan(numel(markerGroupsPlot), numel(pairLabels));
    Tot = nan(numel(markerGroupsPlot), numel(pairLabels));
    Ts = summaryTbl(strcmp(summaryTbl.method, methodName) & strcmp(summaryTbl.normalization, normLabel), :);

    for r = 1:numel(markerGroupsPlot)
        for c = 1:numel(pairLabels)
            row = Ts(strcmp(Ts.markerGroup, markerGroupsPlot{r}) & strcmp(Ts.pairLabel, pairLabels{c}), :);
            if ~isempty(row)
                M(r,c) = row.flipFraction(1);
                N(r,c) = row.nIncluded(1);
                Tot(r,c) = row.nTotal(1);
            end
        end
    end

    imagesc(ax, M, [0 1]);
    colormap(ax, turbo);
    colorbar(ax);
    title(ax, sprintf('%s | %s', rowTitle, strrep(normLabel, '-', ' ')), 'Interpreter', 'none', 'FontSize', 13, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:numel(pairLabels), 'XTickLabel', strrep(pairDisplayLabels, '_', '-'), ...
        'YTick', 1:numel(markerGroupsPlot), 'YTickLabel', strrep(markerGroupsPlot, '_', '-'), ...
        'FontSize', 10, 'LineWidth', 1.0, 'Box', 'off');
    xtickangle(ax, 35);

    for r = 1:size(M,1)
        for c = 1:size(M,2)
            if isfinite(M(r,c))
                txtColor = [0 0 0];
                if M(r,c) > 0.55
                    txtColor = [1 1 1];
                end
                text(ax, c, r, sprintf('%.2f\n%d/%d', M(r,c), N(r,c), Tot(r,c)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold', 'Color', txtColor);
            end
        end
    end
end

function localWriteReport(reportPath, outDir, summaryTbl, deadZoneTbl)
    fid = fopen(reportPath, 'w');
    assert(fid ~= -1, 'Could not open report for writing: %s', reportPath);
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Subject Contrast Filter Report (%s)\n\n', datestr(now, 'yyyy-mm-dd'));
    fprintf(fid, 'This report compares three subject-cell inclusion rules for reversal counting.\n\n');
    fprintf(fid, 'Figure:\n');
    fprintf(fid, '- ![Subject contrast filter QC](%s)\n\n', fullfile(outDir, 'subject_contrast_filter_qc.png'));
    fprintf(fid, 'Dead-zone thresholds:\n');
    for i = 1:height(deadZoneTbl)
        fprintf(fid, '- `%s`: |Δfull| threshold `%.3f`, |Δmicro| threshold `%.3f`\n', deadZoneTbl.normalization{i}, deadZoneTbl.thrFull(i), deadZoneTbl.thrMicro(i));
    end
    fprintf(fid, '\nInterpretation guidance:\n');
    fprintf(fid, '- Reference row: all comparable subject cells are counted.\n');
    fprintf(fid, '- Dead-zone row: weak near-zero contrasts are excluded before counting reversals.\n');
    fprintf(fid, '- Bootstrap-CI row: a subject-cell is counted only if full or micro contrast CI excludes zero.\n');
    fprintf(fid, '\nThis is a reversal-specific filter analysis. It is not based on KS significance, because KS addresses a different question (distributional difference rather than directional reversal).\n');
end

function tf = localSignFlipMask(v)
    if isnumeric(v) || islogical(v)
        tf = v ~= 0;
        return;
    end
    sv = string(v);
    tf = sv == "1" | lower(sv) == "true";
end
