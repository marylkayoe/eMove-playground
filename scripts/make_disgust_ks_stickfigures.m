% make_disgust_ks_stickfigures.m
%
% Build disgust-focused stick-figure discriminability panels for:
%   - full motion
%   - micromovement
%
% Each panel uses KS D aggregated across subjects for selected emotion pairs.

clearvars;
clc;
close all;

%% Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
analysisRunsRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/analysis_runs';
latestRunDir = localFindLatestAnalysisRun(analysisRunsRoot);
resultsCellPath = fullfile(latestRunDir, 'resultsCell.mat');

runStamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['disgust_ks_stickfigures_' char(runStamp)]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

emotionPairs = {'DISGUST','NEUTRAL'; 'DISGUST','JOY'; 'DISGUST','SAD'};
immobilityThresholdMmps = 35;
minSamplesPerCond = 200;

addpath(genpath(fullfile(repoRoot, 'CODE')));

fprintf('=== Disgust KS stick figures ===\n');
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
resultsCell = S.resultsCell;
codingTable = localLoadStimCodingTable(stimCsv);

ksFull = computeKsDistancesFromResultsCell(resultsCell, codingTable, ...
    'speedField', 'speedArray', ...
    'excludeBaseline', true, ...
    'minSamplesPerCond', minSamplesPerCond);

ksMicro = computeKsDistancesFromResultsCell(resultsCell, codingTable, ...
    'speedField', 'speedArrayImmobile', ...
    'excludeBaseline', true, ...
    'minSamplesPerCond', minSamplesPerCond);

writetable(ksFull, fullfile(outDir, 'ks_disgust_full.csv'));
writetable(ksMicro, fullfile(outDir, 'ks_disgust_micro.csv'));
save(fullfile(outDir, 'ks_disgust_full.mat'), 'ksFull', '-v7.3');
save(fullfile(outDir, 'ks_disgust_micro.mat'), 'ksMicro', '-v7.3');

climVals = localSharedCLimAcrossTables({ksFull, ksMicro}, emotionPairs, 'ksD', 'median', 1);

f = figure('Color', 'w', 'Units', 'pixels', 'Position', [80 80 1680 1080]);
tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Body-part discriminability for disgust pairs | full motion vs micromovement (<=%d mm/s)', ...
    immobilityThresholdMmps), 'FontSize', 20, 'FontWeight', 'bold');

for i = 1:size(emotionPairs, 1)
    pair = emotionPairs(i, :);

    ax1 = nexttile(tl, i);
    plotKsBodyPartStickFigure(ksFull, pair, ...
        'plotWhere', ax1, ...
        'aggFcn', 'median', ...
        'minSubjects', 1, ...
        'valueField', 'ksD', ...
        'annotateDelta', false, ...
        'showValues', false, ...
        'showGroupLabels', true, ...
        'showColorbar', false, ...
        'cLim', climVals, ...
        'colormapName', 'turbo', ...
        'titleText', sprintf('%s-%s | full motion', pair{1}, pair{2}));

    ax2 = nexttile(tl, i + 3);
    plotKsBodyPartStickFigure(ksMicro, pair, ...
        'plotWhere', ax2, ...
        'aggFcn', 'median', ...
        'minSubjects', 1, ...
        'valueField', 'ksD', ...
        'annotateDelta', false, ...
        'showValues', false, ...
        'showGroupLabels', true, ...
        'showColorbar', false, ...
        'cLim', climVals, ...
        'colormapName', 'turbo', ...
        'titleText', sprintf('%s-%s | micromovement', pair{1}, pair{2}));
end

cbAx = axes(f, 'Visible', 'off', 'Units', 'normalized', 'Position', [0.91 0.12 0.001 0.76]); %#ok<LAXES>
colormap(cbAx, turbo(256));
caxis(cbAx, climVals);
cb = colorbar(cbAx, 'Location', 'eastoutside');
cb.Label.String = 'KS D';
cb.FontSize = 10;

exportgraphics(f, fullfile(outDir, 'disgust_ks_stickfigures.png'), 'Resolution', 220);
exportgraphics(f, fullfile(outDir, 'disgust_ks_stickfigures.pdf'), 'ContentType', 'vector');
savefig(f, fullfile(outDir, 'disgust_ks_stickfigures.fig'));

fprintf('Saved disgust KS stick figures under:\n%s\n', outDir);

%% Helpers
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

function cLim = localSharedCLimAcrossTables(tbls, emotionPairs, valueField, aggFcnName, minSubjects)
    vals = [];
    for i = 1:numel(tbls)
        T = tbls{i};
        for p = 1:size(emotionPairs,1)
            pair = emotionPairs(p,:);
            R = plotKsBodyPartStickFigure(T, pair, ...
                'aggFcn', aggFcnName, ...
                'minSubjects', minSubjects, ...
                'valueField', valueField, ...
                'annotateDelta', false, ...
                'showValues', false, ...
                'showGroupLabels', false, ...
                'showColorbar', false);
            vals = [vals; R.summaryTable.value(:)]; %#ok<AGROW>
            close(R.figure);
        end
    end
    vals = vals(isfinite(vals));
    if isempty(vals)
        cLim = [0 1];
    elseif numel(unique(vals)) == 1
        cLim = [max(0, vals(1)-0.05), vals(1)+0.05];
    else
        cLim = [min(vals), max(vals)];
    end
end
