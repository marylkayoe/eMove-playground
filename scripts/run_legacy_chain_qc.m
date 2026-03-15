% run_legacy_chain_qc.m
%
% Reproduce user's legacy analysis chain exactly and emit QC comparison files.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/eMOVE-matlab-new';
groupCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');

immobilityThreshold = 25;

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['legacy_chain_qc_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);
stimVideoEmotionCodingSINGLES = localLoadStimCoding(stimCsv);

% 1) Exact legacy chain
resultsCellSingles = runMotionMetricsBatch(dataRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'immobilityThreshold', immobilityThreshold, ...
    'stimVideoEmotionCoding', stimVideoEmotionCodingSINGLES);

singlesBuckets = buildNormalizedMetricsBuckets(resultsCellSingles, groupedBodypartNames, 'makePlot', false);
ksTbl = computeKsDistancesFromResultsCell(resultsCellSingles, stimVideoEmotionCodingSINGLES);

save(fullfile(outDir, 'resultsCellSingles.mat'), 'resultsCellSingles', '-v7.3');
save(fullfile(outDir, 'singlesBuckets.mat'), 'singlesBuckets', '-v7.3');
writetable(ksTbl, fullfile(outDir, 'ksTbl_default.csv'));

% 2) Recreate CDFs in legacy bucket pathway
figBefore = findall(groot, 'Type', 'figure');
plotSpeedCDFByStimGroup(singlesBuckets, stimVideoEmotionCodingSINGLES, ...
    'metric', 'speed', 'useImmobile', false);
localSaveNewFigures(figBefore, outDir, 'cdf_bucket_fullspeed');

figBefore = findall(groot, 'Type', 'figure');
plotSpeedCDFByStimGroup(singlesBuckets, stimVideoEmotionCodingSINGLES, ...
    'metric', 'speed', 'useImmobile', true);
localSaveNewFigures(figBefore, outDir, 'cdf_bucket_immobile');

% 3) Recreate KS heatmap with defaults
figBefore = findall(groot, 'Type', 'figure');
plotKsHeatmap(ksTbl);
localSaveNewFigures(figBefore, outDir, 'ks_heatmap_default');

% 4) Side-by-side KS variants for interpretation
ksTblImmobile200 = computeKsDistancesFromResultsCell(resultsCellSingles, stimVideoEmotionCodingSINGLES, ...
    'speedField', 'speedArrayImmobile', 'minSamplesPerCond', 200, 'excludeBaseline', true);
ksTblImmobile5000 = computeKsDistancesFromResultsCell(resultsCellSingles, stimVideoEmotionCodingSINGLES, ...
    'speedField', 'speedArrayImmobile', 'minSamplesPerCond', 5000, 'excludeBaseline', true);
ksTblFull200 = computeKsDistancesFromResultsCell(resultsCellSingles, stimVideoEmotionCodingSINGLES, ...
    'speedField', 'speedArray', 'minSamplesPerCond', 200, 'excludeBaseline', true);

writetable(ksTblImmobile200, fullfile(outDir, 'ksTbl_immobile_min200.csv'));
writetable(ksTblImmobile5000, fullfile(outDir, 'ksTbl_immobile_min5000.csv'));
writetable(ksTblFull200, fullfile(outDir, 'ksTbl_fullspeed_min200.csv'));

% 5) Median summaries used in heatmap tiles
sumDefault = localMedianSummary(ksTbl, 'default');
sumImm200 = localMedianSummary(ksTblImmobile200, 'immobile200');
sumImm5000 = localMedianSummary(ksTblImmobile5000, 'immobile5000');
sumFull200 = localMedianSummary(ksTblFull200, 'full200');

writetable(sumDefault, fullfile(outDir, 'ks_median_summary_default.csv'));
writetable(sumImm200, fullfile(outDir, 'ks_median_summary_immobile200.csv'));
writetable(sumImm5000, fullfile(outDir, 'ks_median_summary_immobile5000.csv'));
writetable(sumFull200, fullfile(outDir, 'ks_median_summary_full200.csv'));

% 6) Target rows for quick QC
targets = localCollectTargets(sumDefault);
writetable(targets, fullfile(outDir, 'ks_target_rows.csv'));
disp(targets);

% 7) Compare to one earlier run from this project (manifest immobile min200)
prev = '/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/ks_diagnose_20260311_134803/ks_from_resultsCell35_min200.csv';
if isfile(prev)
    prevTbl = readtable(prev);
    prevSum = localMedianSummary(prevTbl, 'prev_manifest35');
    cmp = outerjoin(sumImm200, prevSum, 'Keys', {'markerGroup','pairLabel'}, 'MergeKeys', true, 'Type', 'full');
    cmp.dKs = cmp.ksD_median_immobile200 - cmp.ksD_median_prev_manifest35;
    cmp.dDelta = cmp.delta_median_immobile200 - cmp.delta_median_prev_manifest35;
    writetable(cmp, fullfile(outDir, 'compare_legacy25_vs_prev_manifest35.csv'));
end

fprintf('Done. Outputs:\n%s\n', outDir);

function coding = localLoadStimCoding(stimCsv)
    opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, intersect({'videoID','emotionTag','groupCode'}, opts.VariableNames, 'stable'), 'string');
    T = readtable(stimCsv, opts);
    include = localToLogical(T.include);
    vid = upper(strtrim(string(T.videoID)));
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));
    if ismember('groupCode', T.Properties.VariableNames)
        emo = upper(strtrim(string(T.groupCode)));
    else
        emo = upper(strtrim(string(T.emotionTag)));
    end
    keep = include & vid ~= "" & emo ~= "";
    coding = table(vid(keep), emo(keep), 'VariableNames', {'videoID','groupCode'});
end

function out = localToLogical(v)
    if islogical(v), out = v; return; end
    if isnumeric(v), out = v ~= 0; return; end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end

function S = localMedianSummary(T, tag)
    if isempty(T)
        S = table();
        return;
    end
    mg = string(T.markerGroup);
    pl = string(T.pairLabel);
    [G, mgU, plU] = findgroups(mg, pl);
    ksMed = splitapply(@(x) median(x, 'omitnan'), T.ksD, G);
    dMed = splitapply(@(x) median(x, 'omitnan'), T.deltaMedian_sorted, G);
    nRows = splitapply(@numel, T.ksD, G);
    S = table(cellstr(mgU), cellstr(plU), ksMed, dMed, nRows, ...
        'VariableNames', {'markerGroup','pairLabel', ...
        ['ksD_median_' tag], ['delta_median_' tag], ['n_' tag]});
end

function T = localCollectTargets(S)
    if isempty(S)
        T = table();
        return;
    end
    mask = (strcmp(string(S.markerGroup), 'HEAD') & strcmp(string(S.pairLabel), 'FEAR-JOY')) | ...
           (strcmp(string(S.markerGroup), 'WRIST_L') & strcmp(string(S.pairLabel), 'FEAR-JOY')) | ...
           (strcmp(string(S.markerGroup), 'WRIST_R') & strcmp(string(S.pairLabel), 'FEAR-JOY'));
    T = S(mask, :);
end

function localSaveNewFigures(figBefore, outDir, prefix)
    figAfter = findall(groot, 'Type', 'figure');
    newFigs = setdiff(figAfter, figBefore);
    for i = 1:numel(newFigs)
        f = newFigs(i);
        base = sprintf('%s_%02d', prefix, i);
        pngPath = fullfile(outDir, [base '.png']);
        figPath = fullfile(outDir, [base '.fig']);
        try
            exportgraphics(f, pngPath, 'Resolution', 220);
        catch
            saveas(f, pngPath);
        end
        try
            savefig(f, figPath);
        catch
            saveas(f, figPath);
        end
    end
end

