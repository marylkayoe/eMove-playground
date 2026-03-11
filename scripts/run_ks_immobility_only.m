% run_ks_immobility_only.m
%
% Recompute KS distances and stick-figure plots focused on immobility speeds.
% Uses an existing resultsCell by default (no full batch recomputation).

clearvars;
clc;
close all;

%% Paths / Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
analysisRunsRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/analysis_runs';
latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');

runStamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['ks_immobile_' char(runStamp)]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

immobilityThresholdMmps = 35;
minSamplesPerCond = 200;
minSamplesPerCondCompare = 200;
makeLegacyStyleCompare = false;

addpath(genpath(fullfile(repoRoot, 'CODE')));

fprintf('=== KS Immobility Run ===\n');
fprintf('resultsCell: %s\n', resultsCellPath);
fprintf('stimCsv: %s\n', stimCsv);
fprintf('outDir: %s\n', outDir);

if ~isfile(resultsCellPath)
    error('Missing resultsCell MAT: %s', resultsCellPath);
end
if ~isfile(stimCsv)
    error('Missing stim encoding CSV: %s', stimCsv);
end

S = load(resultsCellPath, 'resultsCell');
if ~isfield(S, 'resultsCell')
    error('Variable resultsCell missing in %s', resultsCellPath);
end
resultsCell = S.resultsCell;

codingTable = localLoadStimCodingTable(stimCsv);

%% Compute KS table (immobility focus)
ksTbl = computeKsDistancesFromResultsCell(resultsCell, codingTable, ...
    'speedField', 'speedArrayImmobile', ...
    'excludeBaseline', true, ...
    'minSamplesPerCond', minSamplesPerCond);

writetable(ksTbl, fullfile(outDir, 'ks_distances_immobile.csv'));
save(fullfile(outDir, 'ks_distances_immobile.mat'), 'ksTbl', '-v7.3');

if makeLegacyStyleCompare && minSamplesPerCondCompare ~= minSamplesPerCond
    ksTbl200 = computeKsDistancesFromResultsCell(resultsCell, codingTable, ...
        'speedField', 'speedArrayImmobile', ...
        'excludeBaseline', true, ...
        'minSamplesPerCond', minSamplesPerCondCompare);
    writetable(ksTbl200, fullfile(outDir, 'ks_distances_immobile_min200.csv'));
    save(fullfile(outDir, 'ks_distances_immobile_min200.mat'), 'ksTbl200', '-v7.3');
end

%% Plot: heatmap
figBefore = findall(groot, 'Type', 'figure');
plotKsHeatmap(ksTbl, ...
    'excludeEmotions', {'X','0','BASELINE','FEAR'}, ...
    'annotateKs', false, ...
    'titleText', sprintf('KS heatmap | immobile speed (<=%d mm/s)', immobilityThresholdMmps));
localTuneCurrentFigure(1700, 1300);
localSaveNewFigures(figBefore, outDir, 'ks_heatmap_immobile');

%% Plot: legacy-style heatmap (bodypart subset/order and D+delta annotations)
markerOrderRaw = {'HEAD','UTORSO','UPPER_LIMB_L','UPPER_LIMB_R','LOWER_LIMB_L','LOWER_LIMB_R','WRIST_L','WRIST_R','LTORSO'};
markerOrderPretty = {'head','uppertorso','L-arm','R-arm','L-leg','R-leg','L-Wrist','R-Wrist','Waist'};
ksTblLegacy = localBuildLegacyMarkerTable(ksTbl, markerOrderRaw, markerOrderPretty);

figBefore = findall(groot, 'Type', 'figure');
plotKsHeatmap(ksTblLegacy, ...
    'excludeEmotions', {'X','0','BASELINE','FEAR'}, ...
    'sortPairsByMean', true, ...
    'sortMarkersByMean', false, ...
    'annotateKs', true, ...
    'annotateField', 'deltaMedian_sorted', ...
    'annotateFormat', '%+.2f', ...
    'titleText', sprintf('Median KS distance across subjects (immobility <=%d mm/s; minSamples=%d)', ...
        immobilityThresholdMmps, minSamplesPerCond));
localTuneCurrentFigure(1900, 1400);
localSaveNewFigures(figBefore, outDir, 'ks_heatmap_immobile_legacy');

if makeLegacyStyleCompare && exist('ksTbl200','var')
    ksTblLegacy200 = localBuildLegacyMarkerTable(ksTbl200, markerOrderRaw, markerOrderPretty);
    figBefore = findall(groot, 'Type', 'figure');
    plotKsHeatmap(ksTblLegacy200, ...
        'excludeEmotions', {'X','0','BASELINE','FEAR'}, ...
        'sortPairsByMean', true, ...
        'sortMarkersByMean', false, ...
        'annotateKs', true, ...
        'annotateField', 'deltaMedian_sorted', ...
        'annotateFormat', '%+.2f', ...
        'titleText', sprintf('Median KS distance across subjects (immobility <=%d mm/s; minSamples=%d)', ...
            immobilityThresholdMmps, minSamplesPerCondCompare));
    localTuneCurrentFigure(1900, 1400);
    localSaveNewFigures(figBefore, outDir, 'ks_heatmap_immobile_legacy_min200');
end

%% Plot: stick figures (all available pairs)
figBefore = findall(groot, 'Type', 'figure');
plotKsBodyPartStickFigureAllPairs(ksTbl, ...
    'excludeEmotions', {'X','0','BASELINE','FEAR'}, ...
    'maxPairs', 6, ...
    'annotateDelta', false, ...
    'showValues', false, ...
    'showGroupLabels', true, ...
    'useSharedCLim', false, ...
    'titleText', sprintf('KS stick figures | immobile speed (<=%d mm/s)', immobilityThresholdMmps));
localTuneCurrentFigure(1800, 1200);
localSaveNewFigures(figBefore, outDir, 'ks_stickfig_immobile');

fprintf('Done. KS immobility outputs:\n%s\n', outDir);

%% Local helpers
function latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot)
    if ~isfolder(analysisRunsRoot)
        error('Analysis runs folder not found: %s', analysisRunsRoot);
    end
    d = dir(analysisRunsRoot);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(names ~= "." & names ~= "..");
    isRun = ~cellfun('isempty', regexp(cellstr(names), '^\d{8}_\d{6}$', 'once'));
    names = names(isRun);
    if isempty(names)
        error('No timestamped analysis run folders found under %s', analysisRunsRoot);
    end
    names = sort(names);
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

    if ~ismember('videoID', T.Properties.VariableNames) || ~ismember('include', T.Properties.VariableNames)
        error('Stim CSV requires columns videoID and include.');
    end
    if ismember('groupCode', T.Properties.VariableNames)
        code = string(T.groupCode);
    elseif ismember('emotionTag', T.Properties.VariableNames)
        code = string(T.emotionTag);
    else
        error('Stim CSV requires groupCode or emotionTag.');
    end

    vid = upper(strtrim(string(T.videoID)));
    include = localToLogical(T.include);
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));

    code = upper(strtrim(code));
    keep = include & vid ~= "" & code ~= "";
    codingTable = table(vid(keep), code(keep), 'VariableNames', {'videoID','groupCode'});
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
        figPath = fullfile(outDir, [baseName '.fig']);
        try
            exportgraphics(f, pngPath, 'Resolution', 220);
        catch
            saveas(f, pngPath);
        end
        try
            exportgraphics(f, pdfPath, 'ContentType', 'vector');
        catch
            saveas(f, pdfPath);
        end
        try
            savefig(f, figPath);
        catch
            saveas(f, figPath);
        end
    end
end

function localTuneCurrentFigure(w, h)
    f = gcf;
    set(f, 'Units', 'pixels');
    pos = get(f, 'Position');
    set(f, 'Position', [pos(1), pos(2), w, h]);
end

function T = localBuildLegacyMarkerTable(ksTbl, markerOrderRaw, markerOrderPretty)
    T = ksTbl;
    keep = ismember(string(T.markerGroup), string(markerOrderRaw));
    T = T(keep, :);

    oldNames = string(markerOrderRaw);
    newNames = string(markerOrderPretty);
    mg = string(T.markerGroup);
    for i = 1:numel(oldNames)
        mg(mg == oldNames(i)) = newNames(i);
    end
    T.markerGroup = cellstr(mg);

    ordMap = containers.Map(cellstr(newNames), num2cell(1:numel(newNames)));
    ord = zeros(height(T),1);
    for r = 1:height(T)
        k = T.markerGroup{r};
        if isKey(ordMap, k)
            ord(r) = ordMap(k);
        else
            ord(r) = 999;
        end
    end
    T = sortrows(addvars(T, ord, 'Before', 1, 'NewVariableNames', 'markerOrder'), 'markerOrder');
    T.markerOrder = [];
end
