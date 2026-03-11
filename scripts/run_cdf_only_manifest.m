% run_cdf_only_manifest.m
%
% Generate CDF plots only (no KS, no stimulus-distance clustering).
% Produces:
%   1) perVideoMedian CDFs (one value per subject/video/marker-group row)
%   2) pooledRaw CDFs (all speed samples pooled across rows/subjects)
% Uses existing resultsCell from a prior run by default for speed.

clearvars;
clc;
close all;

%% Paths / Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources/stim_video_encoding_SINGLES.csv');

% Fast path: reuse latest resultsCell from a completed manifest run.
analysisRunsRoot = fullfile(dataRoot, 'derived', 'analysis_runs');
latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');

runStamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['cdf_only_' char(runStamp)]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

% Default trimmed marker set (excludes OTHER/HAND/WRIST by default).
markerGroupsToPlot = { ...
    'HEAD', ...
    'UTORSO', ...
    'LTORSO', ...
    'UPPER_LIMB_L', ...
    'UPPER_LIMB_R', ...
    'WRIST_L', ...
    'WRIST_R', ...
    'LOWER_LIMB_L', ...
    'LOWER_LIMB_R'};

% Which families to export in this run.
doFullSpeed = false;
doImmobile = true;
immobilityThresholdMmps = 35;

fprintf('=== eMove CDF-Only Run ===\n');
fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Output dir: %s\n', outDir);
[~, stimName, stimExt] = fileparts(stimCsv);
stimLabel = [stimName stimExt];

if ~isfile(resultsCellPath)
    error('resultsCell.mat not found: %s', resultsCellPath);
end
if ~isfile(stimCsv)
    error('Stim CSV not found: %s', stimCsv);
end

S = load(resultsCellPath, 'resultsCell');
if ~isfield(S, 'resultsCell')
    error('resultsCell variable missing in %s', resultsCellPath);
end
resultsCell = S.resultsCell;

codingTable = localLoadStimCodingTable(stimCsv);

if doFullSpeed
    % A1) Median-based CDF, baseline-normalized.
    figBefore = findall(groot, 'Type', 'figure');
    plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
        'markerGroups', markerGroupsToPlot, ...
        'plotMode', 'perVideoMedian', ...
        'useImmobile', false, ...
        'summaryField', 'medianSpeed', ...
        'doBaselineNormalize', true, ...
        'baselineEmotion', 'BASELINE', ...
        'baselineFromField', 'medianSpeed', ...
        'figureTitle', sprintf('%s | perVideoMedian | full-speed | normalized', stimLabel), ...
        'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''});
    localSaveNewFigures(figBefore, outDir, 'cdf_perVideoMedian_fullspeed_norm');

    % A2) Median-based CDF, absolute values (no baseline normalization).
    figBefore = findall(groot, 'Type', 'figure');
    plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
        'markerGroups', markerGroupsToPlot, ...
        'plotMode', 'perVideoMedian', ...
        'useImmobile', false, ...
        'summaryField', 'medianSpeed', ...
        'doBaselineNormalize', false, ...
        'figureTitle', sprintf('%s | perVideoMedian | full-speed | absolute', stimLabel), ...
        'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''});
    localSaveNewFigures(figBefore, outDir, 'cdf_perVideoMedian_fullspeed_abs');

    % B1) All-samples CDF, baseline-normalized.
    figBefore = findall(groot, 'Type', 'figure');
    plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
        'markerGroups', markerGroupsToPlot, ...
        'plotMode', 'pooledRaw', ...
        'useImmobile', false, ...
        'immobilityField', 'speedArray', ...
        'doBaselineNormalize', true, ...
        'baselineEmotion', 'BASELINE', ...
        'baselineFromField', 'speedArray', ...
        'minBaselineSamples', 20, ...
        'figureTitle', sprintf('%s | pooledRaw | full-speed | normalized', stimLabel), ...
        'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''});
    localSaveNewFigures(figBefore, outDir, 'cdf_pooledRaw_fullspeed_norm');

    % B2) All-samples CDF, absolute values (no baseline normalization).
    figBefore = findall(groot, 'Type', 'figure');
    plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
        'markerGroups', markerGroupsToPlot, ...
        'plotMode', 'pooledRaw', ...
        'useImmobile', false, ...
        'immobilityField', 'speedArray', ...
        'doBaselineNormalize', false, ...
        'figureTitle', sprintf('%s | pooledRaw | full-speed | absolute', stimLabel), ...
        'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''});
    localSaveNewFigures(figBefore, outDir, 'cdf_pooledRaw_fullspeed_abs');
end

if doImmobile
    immLabel = sprintf('immobile-speed (<=%d mm/s)', immobilityThresholdMmps);

    % C1) Median-based CDF, immobile speed, baseline-normalized.
    figBefore = findall(groot, 'Type', 'figure');
    plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
        'markerGroups', markerGroupsToPlot, ...
        'plotMode', 'perVideoMedian', ...
        'useImmobile', true, ...
        'summaryField', 'medianSpeedImmobile', ...
        'doBaselineNormalize', true, ...
        'baselineEmotion', 'BASELINE', ...
        'baselineFromField', 'medianSpeedImmobile', ...
        'figureTitle', sprintf('%s | perVideoMedian | %s | normalized', stimLabel, immLabel), ...
        'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''});
    localSaveNewFigures(figBefore, outDir, 'cdf_perVideoMedian_immobile_norm');

    % C2) Median-based CDF, immobile speed, absolute.
    figBefore = findall(groot, 'Type', 'figure');
    plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
        'markerGroups', markerGroupsToPlot, ...
        'plotMode', 'perVideoMedian', ...
        'useImmobile', true, ...
        'summaryField', 'medianSpeedImmobile', ...
        'doBaselineNormalize', false, ...
        'figureTitle', sprintf('%s | perVideoMedian | %s | absolute', stimLabel, immLabel), ...
        'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''});
    localSaveNewFigures(figBefore, outDir, 'cdf_perVideoMedian_immobile_abs');

    % D1) All-samples CDF, immobile speed arrays, baseline-normalized.
    figBefore = findall(groot, 'Type', 'figure');
    plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
        'markerGroups', markerGroupsToPlot, ...
        'plotMode', 'pooledRaw', ...
        'useImmobile', true, ...
        'immobilityField', 'speedArrayImmobile', ...
        'doBaselineNormalize', true, ...
        'baselineEmotion', 'BASELINE', ...
        'baselineFromField', 'speedArrayImmobile', ...
        'minBaselineSamples', 20, ...
        'figureTitle', sprintf('%s | pooledRaw | %s | normalized', stimLabel, immLabel), ...
        'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''});
    localSaveNewFigures(figBefore, outDir, 'cdf_pooledRaw_immobile_norm');

    % D2) All-samples CDF, immobile speed arrays, absolute.
    figBefore = findall(groot, 'Type', 'figure');
    plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
        'markerGroups', markerGroupsToPlot, ...
        'plotMode', 'pooledRaw', ...
        'useImmobile', true, ...
        'immobilityField', 'speedArrayImmobile', ...
        'doBaselineNormalize', false, ...
        'figureTitle', sprintf('%s | pooledRaw | %s | absolute', stimLabel, immLabel), ...
        'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''});
    localSaveNewFigures(figBefore, outDir, 'cdf_pooledRaw_immobile_abs');
end

fprintf('Done. CDF figures saved under:\n%s\n', outDir);

%% Local helpers
function latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot)
    if ~isfolder(analysisRunsRoot)
        error('Analysis runs folder not found: %s', analysisRunsRoot);
    end
    d = dir(analysisRunsRoot);
    d = d([d.isdir]);
    names = string({d.name});
    names = names(names ~= "." & names ~= "..");
    % Expected run folder names: yyyyMMdd_HHmmss
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
        error('Stim CSV requires videoID and include columns.');
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
