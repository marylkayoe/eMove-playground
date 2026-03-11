% run_full_analysis_manifest_once.m
%
% Run the current motion-analysis pipeline once on manifest-built trialData.
% This script writes outputs to a timestamped folder and saves key figures.
%
% Notes:
% - Uses the existing algorithms as-is (no metric logic changes).
% - Intended for a smoke run to confirm end-to-end execution and outputs.

clearvars;
clc;
close all;

%% Paths / Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';

manifestCsv = fullfile(dataRoot, 'master_file_list_preview.csv');
matRoot = fullfile(dataRoot, 'matlab_from_manifest');
groupCsv = fullfile(repoRoot, 'resources/bodypart_marker_grouping.csv');
stimCsv = fullfile(repoRoot, 'resources/stim_video_encoding_SINGLES.csv');

runStamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(dataRoot, 'derived', 'analysis_runs', char(runStamp));
repoFigDir = fullfile(repoRoot, 'outputs', 'figures', char(runStamp));
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if ~exist(repoFigDir, 'dir')
    mkdir(repoFigDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

fprintf('=== eMove Full Analysis Run (Manifest) ===\n');
fprintf('Run stamp: %s\n', runStamp);
fprintf('Output dir: %s\n', outDir);
fprintf('Repo figure dir: %s\n', repoFigDir);

mustExist = {repoRoot, manifestCsv, matRoot, groupCsv, stimCsv};
for i = 1:numel(mustExist)
    p = mustExist{i};
    if ~(isfolder(p) || isfile(p))
        error('Missing required path: %s', p);
    end
end

%% 1) Load grouping + coding assets
[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);
codingTable = localLoadStimCodingTable(stimCsv);
fprintf('Marker groups: %d\n', numel(groupedBodypartNames));
fprintf('Stim coding rows (included): %d\n', height(codingTable));

%% 2) Batch metrics in manifest subject order
tBatch = tic;
resultsCell = runMotionMetricsBatchFromManifest(manifestCsv, matRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'stimVideoEmotionCoding', codingTable, ...
    'computeFrequencyMetrics', false, ...
    'continueOnError', true, ...
    'verbose', true);
batchSec = toc(tBatch);
fprintf('Batch metrics done in %.1f s\n', batchSec);

save(fullfile(outDir, 'resultsCell.mat'), 'resultsCell', '-v7.3');
runTbl = localBuildRunSummary(resultsCell);
writetable(runTbl, fullfile(outDir, 'run_summary.csv'));

%% 3) Baseline-normalized buckets + grouped plots
t = tic;
outBuckets = buildNormalizedMetricsBuckets(resultsCell, groupedBodypartNames, 'makePlot', false);
save(fullfile(outDir, 'normalized_buckets.mat'), 'outBuckets', '-v7.3');

figBefore = findall(groot, 'Type', 'figure');
plotMetricsByStimGroup(outBuckets, codingTable, 'metric', 'speed');
localSaveNewFigures(figBefore, outDir, 'metrics_by_group_speed');

figBefore = findall(groot, 'Type', 'figure');
plotMetricsByStimGroup(outBuckets, codingTable, 'metric', 'mad');
localSaveNewFigures(figBefore, outDir, 'metrics_by_group_mad');

figBefore = findall(groot, 'Type', 'figure');
plotMetricsByStimGroup(outBuckets, codingTable, 'metric', 'sal');
localSaveNewFigures(figBefore, outDir, 'metrics_by_group_sal');

figBefore = findall(groot, 'Type', 'figure');
plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
    'plotMode', 'perVideoMedian', ...
    'doBaselineNormalize', true, ...
    'useImmobile', true);
localSaveNewFigures(figBefore, outDir, 'cdf_perVideoMedian_immobile');
fprintf('Bucket + grouped plots done in %.1f s\n', toc(t));

%% 4) Stimulus distance matrix + clustering plots
t = tic;
perStim = collectSpeedByStimVideo(resultsCell, groupedBodypartNames, ...
    'normalizeToBaseline', true, ...
    'outlierQuantile', 0.99, ...
    'includeBaseline', false);

[D, Ddetails] = computeStimDistanceWasserstein(perStim, ...
    'combine', 'mean', ...
    'metric', 'wasserstein', ...
    'minSamples', 10, ...
    'maxSamplesPerDist', 5000, ...
    'verbose', true);
save(fullfile(outDir, 'stim_distance_wasserstein.mat'), 'D', 'Ddetails', 'perStim', '-v7.3');
writematrix(D, fullfile(outDir, 'stim_distance_wasserstein.csv'));

figBefore = findall(groot, 'Type', 'figure');
plotStimDistanceSummary(D, perStim.videoIDs);
localSaveNewFigures(figBefore, outDir, 'stim_distance_summary');

figBefore = findall(groot, 'Type', 'figure');
clusterOut = clusterStimuliFromDistance(D, perStim.videoIDs, ...
    'excludeBaseline', false, ...
    'makePlot', true, ...
    'plotSilhouette', true);
localSaveNewFigures(figBefore, outDir, 'stim_distance_cluster');
save(fullfile(outDir, 'stim_distance_cluster.mat'), 'clusterOut');
fprintf('Distance + clustering done in %.1f s\n', toc(t));

%% 5) KS distances + heatmap + stick figures
t = tic;
ksTbl = computeKsDistancesFromResultsCell(resultsCell, codingTable, ...
    'speedField', 'speedArrayImmobile', ...
    'excludeBaseline', true, ...
    'minSamplesPerCond', 200);

if ~isempty(ksTbl)
    writetable(ksTbl, fullfile(outDir, 'ks_distances_by_subject.csv'));
end

figBefore = findall(groot, 'Type', 'figure');
plotKsHeatmap(ksTbl, 'excludeEmotions', {'X','0'});
localSaveNewFigures(figBefore, outDir, 'ks_heatmap');

figBefore = findall(groot, 'Type', 'figure');
plotKsBodyPartStickFigureAllPairs(ksTbl, ...
    'excludeEmotions', {'X','0'}, ...
    'maxPairs', 6, ...
    'annotateDelta', true);
localSaveNewFigures(figBefore, outDir, 'ks_stickfig_allpairs');
fprintf('KS + stick figures done in %.1f s\n', toc(t));

%% 6) Run metadata
meta = struct();
meta.runStamp = runStamp;
meta.createdAt = string(datetime('now'));
meta.repoRoot = string(repoRoot);
meta.dataRoot = string(dataRoot);
meta.manifestCsv = string(manifestCsv);
meta.matRoot = string(matRoot);
meta.groupCsv = string(groupCsv);
meta.stimCsv = string(stimCsv);
meta.repoFigureDir = string(repoFigDir);
meta.nSubjects = height(runTbl);
meta.nSubjectErrors = nnz(runTbl.status ~= "ok");
meta.batchSeconds = batchSec;
save(fullfile(outDir, 'run_meta.mat'), 'meta');
localMirrorFigureFiles(outDir, repoFigDir);

fprintf('Done. Outputs saved under:\n%s\n', outDir);
fprintf('Figures mirrored to repo under:\n%s\n', repoFigDir);

%% Local functions
function codingTable = localLoadStimCodingTable(stimCsv)
    opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
    strCols = {'videoID','emotionTag','groupCode','emotionCategory','notes'};
    strCols = intersect(strCols, opts.VariableNames, 'stable');
    if ~isempty(strCols)
        opts = setvartype(opts, strCols, 'string');
    end
    T = readtable(stimCsv, opts);

    if ~ismember('videoID', T.Properties.VariableNames)
        error('Stim encoding table missing required column "videoID".');
    end
    if ~ismember('include', T.Properties.VariableNames)
        error('Stim encoding table missing required column "include".');
    end

    if ismember('groupCode', T.Properties.VariableNames)
        groupCol = string(T.groupCode);
    elseif ismember('emotionTag', T.Properties.VariableNames)
        groupCol = string(T.emotionTag);
    else
        error('Stim encoding table needs "groupCode" or "emotionTag" column.');
    end

    vid = upper(strtrim(string(T.videoID)));
    include = localToLogical(T.include);
    if ismember('isBaseline', T.Properties.VariableNames)
        isBase = localToLogical(T.isBaseline);
        % Only coerce baseline-like IDs. Keep non-baseline IDs even if isBaseline is mislabeled.
        looksBaseline = (vid == "" | vid == "0" | vid == "BASELINE");
        forceBase = isBase & looksBaseline;
        vid(forceBase) = "BASELINE";
        badBase = isBase & ~looksBaseline;
        if any(badBase)
            fprintf('Warning: %d rows have isBaseline=1 with non-baseline videoID; keeping original videoID values.\n', nnz(badBase));
        end
    end
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));

    groupCol = upper(strtrim(groupCol));
    keep = include & vid ~= "";
    codingTable = table(vid(keep), groupCol(keep), 'VariableNames', {'videoID','groupCode'});
end

function out = localToLogical(v)
    if islogical(v)
        out = v;
        return;
    end
    if isnumeric(v)
        out = v ~= 0;
        return;
    end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end

function tbl = localBuildRunSummary(resultsCell)
    n = numel(resultsCell);
    subjectID = strings(n,1);
    fileName = strings(n,1);
    status = strings(n,1);
    errorMessage = strings(n,1);
    nResultRows = zeros(n,1);
    nSummaryRows = zeros(n,1);

    for i = 1:n
        rc = resultsCell{i};
        if isfield(rc, 'subjectID') && ~isempty(rc.subjectID)
            subjectID(i) = string(rc.subjectID);
        else
            subjectID(i) = "UNKNOWN";
        end
        if isfield(rc, 'fileName') && ~isempty(rc.fileName)
            fileName(i) = string(rc.fileName);
        else
            fileName(i) = "";
        end
        if isfield(rc, 'results') && ~isempty(rc.results)
            nResultRows(i) = numel(rc.results);
        end
        if isfield(rc, 'summaryTable') && istable(rc.summaryTable)
            nSummaryRows(i) = height(rc.summaryTable);
        end
        if isfield(rc, 'errorMessage') && strlength(string(rc.errorMessage)) > 0
            status(i) = "error";
            errorMessage(i) = string(rc.errorMessage);
        else
            status(i) = "ok";
            errorMessage(i) = "";
        end
    end

    tbl = table(subjectID, fileName, status, nResultRows, nSummaryRows, errorMessage);
end

function localSaveNewFigures(figBefore, outDir, prefix)
    figAfter = findall(groot, 'Type', 'figure');
    newFigs = setdiff(figAfter, figBefore);
    if isempty(newFigs)
        return;
    end

    for i = 1:numel(newFigs)
        f = newFigs(i);
        baseName = sprintf('%s_%02d', prefix, i);
        pngPath = fullfile(outDir, [baseName '.png']);
        pdfPath = fullfile(outDir, [baseName '.pdf']);
        try
            exportgraphics(f, pngPath, 'Resolution', 200);
        catch
            saveas(f, pngPath);
        end
        try
            exportgraphics(f, pdfPath, 'ContentType', 'vector');
        catch
            saveas(f, pdfPath);
        end
    end
end

function localMirrorFigureFiles(sourceDir, targetDir)
    exts = {'*.png', '*.pdf'};
    for i = 1:numel(exts)
        files = dir(fullfile(sourceDir, exts{i}));
        for k = 1:numel(files)
            src = fullfile(files(k).folder, files(k).name);
            dst = fullfile(targetDir, files(k).name);
            copyfile(src, dst);
        end
    end
end
