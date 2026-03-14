% make_disgust_neutral_panels.m
%
% Create presentation-oriented group summary panels comparing DISGUST vs
% NEUTRAL for:
%   C) full-speed regime
%   D) micromovement / immobility regime
%
% The script uses the latest manifest-derived resultsCell by default and
% saves vector + raster outputs under outputs/figures/.

clearvars;
clc;
close all;

%% User-facing knobs
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');

% Start with one strong bodypart for presentation. Good candidates:
%   'UTORSO', 'WRIST_L', 'WRIST_R', 'HEAD'
markerGroupsToPlot = {'UTORSO'};

% Use one value per subject/video segment. This is usually easiest to explain.
plotMode = 'perVideoMedian';

% Set true for fold-baseline values; false for absolute mm/s.
doBaselineNormalize = true;

% Immobility threshold used upstream for the current manifest results.
immobilityThresholdMmps = 35;

%% Paths / loading
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
outDir = fullfile(repoRoot, 'outputs', 'figures', ['disgust_neutral_panels_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

S = load(resultsCellPath, 'resultsCell');
resultsCell = S.resultsCell;
codingTable = localLoadStimCodingTable(stimCsv);

fprintf('Using resultsCell: %s\n', resultsCellPath);
fprintf('Output dir: %s\n', outDir);
fprintf('Marker groups: %s\n', strjoin(markerGroupsToPlot, ', '));

%% Panel C: full speed
panelLabel = localPanelModeLabel(plotMode);
normLabel = localNormLabel(doBaselineNormalize);
figBefore = findall(groot, 'Type', 'figure');
plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
    'markerGroups', markerGroupsToPlot, ...
    'emotionInclude', {'DISGUST', 'NEUTRAL'}, ...
    'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''}, ...
    'plotMode', plotMode, ...
    'useImmobile', false, ...
    'summaryField', 'medianSpeed', ...
    'doBaselineNormalize', doBaselineNormalize, ...
    'baselineEmotion', 'BASELINE', ...
    'baselineFromField', 'medianSpeed', ...
    'showStats', true, ...
    'statsPair', {'DISGUST','NEUTRAL'}, ...
    'tileCols', 1, ...
    'figureTitle', sprintf('Panel C | DISGUST vs NEUTRAL | full speed | %s | %s', panelLabel, normLabel));
localStyleCurrentFigure('Panel C');
localSaveNewFigures(figBefore, outDir, 'panel_C_disgust_vs_neutral_fullspeed');

%% Panel D: micromovement regime
figBefore = findall(groot, 'Type', 'figure');
plotSpeedCDFByStimGroupFromResultsCell(resultsCell, codingTable, ...
    'markerGroups', markerGroupsToPlot, ...
    'emotionInclude', {'DISGUST', 'NEUTRAL'}, ...
    'emotionExclude', {'BASELINE','0','X','AMUSEMENT',''}, ...
    'plotMode', plotMode, ...
    'useImmobile', true, ...
    'summaryField', 'medianSpeedImmobile', ...
    'doBaselineNormalize', doBaselineNormalize, ...
    'baselineEmotion', 'BASELINE', ...
    'baselineFromField', 'medianSpeedImmobile', ...
    'showStats', true, ...
    'statsPair', {'DISGUST','NEUTRAL'}, ...
    'tileCols', 1, ...
    'figureTitle', sprintf('Panel D | DISGUST vs NEUTRAL | micromovement (<=%d mm/s) | %s | %s', ...
        immobilityThresholdMmps, panelLabel, normLabel));
localStyleCurrentFigure('Panel D');
localSaveNewFigures(figBefore, outDir, 'panel_D_disgust_vs_neutral_micromovement');

fprintf('Done. Saved Panel C/D candidates under:\n%s\n', outDir);

%% Local helpers
function label = localPanelModeLabel(plotMode)
    switch char(string(plotMode))
        case 'perVideoMedian'
            label = 'per-video median';
        case 'pooledRaw'
            label = 'pooled raw samples';
        otherwise
            label = char(string(plotMode));
    end
end

function label = localNormLabel(doBaselineNormalize)
    if doBaselineNormalize
        label = 'baseline-normalized';
    else
        label = 'absolute';
    end
end

function localStyleCurrentFigure(panelName)
    figs = findall(groot, 'Type', 'figure');
    if isempty(figs)
        return;
    end
    f = figs(1);
    set(f, 'Color', 'w', 'Units', 'pixels', 'Position', [160 140 760 640]);
    axs = findall(f, 'Type', 'axes');
    for i = 1:numel(axs)
        set(axs(i), 'FontSize', 13, 'LineWidth', 1.0, 'Box', 'off');
        titleObj = get(axs(i), 'Title');
        if isgraphics(titleObj)
            set(titleObj, 'FontSize', 16, 'FontWeight', 'bold');
        end
        xlabelObj = get(axs(i), 'XLabel');
        ylabelObj = get(axs(i), 'YLabel');
        if isgraphics(xlabelObj), set(xlabelObj, 'FontSize', 14, 'FontWeight', 'bold'); end
        if isgraphics(ylabelObj), set(ylabelObj, 'FontSize', 14, 'FontWeight', 'bold'); end
    end

    tl = findall(f, 'Type', 'tiledlayout');
    if ~isempty(tl)
        title(tl(1), get(tl(1).Title, 'String'), 'Interpreter', 'none', 'FontSize', 18, 'FontWeight', 'bold');
    end

    lgd = findall(f, 'Type', 'legend');
    for i = 1:numel(lgd)
        set(lgd(i), 'Location', 'eastoutside', 'FontSize', 13, 'Box', 'off');
    end

    annotation(f, 'textbox', [0.01 0.955 0.05 0.04], ...
        'String', panelName, ...
        'EdgeColor', 'none', ...
        'FontSize', 20, ...
        'FontWeight', 'bold');
end

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

function localSaveNewFigures(figBefore, outDir, baseName)
    figAfter = findall(groot, 'Type', 'figure');
    newFigs = setdiff(figAfter, figBefore);
    if isempty(newFigs)
        warning('No new figure found for %s', baseName);
        return;
    end
    for i = 1:numel(newFigs)
        f = newFigs(i);
        exportgraphics(f, fullfile(outDir, sprintf('%s_%02d.png', baseName, i)), 'Resolution', 220);
        exportgraphics(f, fullfile(outDir, sprintf('%s_%02d.pdf', baseName, i)), 'ContentType', 'vector');
        savefig(f, fullfile(outDir, sprintf('%s_%02d.fig', baseName, i)));
    end
end
