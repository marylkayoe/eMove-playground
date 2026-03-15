% make_disgust_fear_ks_stickfigures.m
%
% Build clean unsigned KS stick-figure panels in the original style:
%   - one figure for DISGUST against all other emotions
%   - one figure for FEAR against all other emotions
% Each figure has:
%   top row    = full motion
%   bottom row = micromovement

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
outDir = fullfile(repoRoot, 'outputs', 'figures', ['disgust_fear_ks_stickfigures_' char(runStamp)]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

immobilityThresholdMmps = 35;
minSamplesPerCond = 200;

pairSets = {
    'DISGUST', {'DISGUST','NEUTRAL'; 'DISGUST','JOY'; 'DISGUST','SAD'; 'DISGUST','FEAR'};
    'FEAR',    {'FEAR','NEUTRAL'; 'FEAR','JOY'; 'FEAR','SAD'; 'FEAR','DISGUST'};
    };

addpath(genpath(fullfile(repoRoot, 'CODE')));

fprintf('=== Disgust/Fear KS stick figures ===\n');
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

writetable(ksFull, fullfile(outDir, 'ks_full_unsigned.csv'));
writetable(ksMicro, fullfile(outDir, 'ks_micro_unsigned.csv'));

for s = 1:size(pairSets,1)
    focusEmotion = pairSets{s,1};
    emotionPairs = pairSets{s,2};
    sharedCLim = localSharedCLimAcrossTables({ksFull, ksMicro}, emotionPairs, 'ksD', 'median', 1);

    f = figure('Color', 'w', 'Units', 'pixels', 'Position', [80 80 1800 1050]);
    tl = tiledlayout(f, 2, size(emotionPairs,1), 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('Body-part discriminability for %s pairs | full motion vs micromovement', focusEmotion), ...
        'FontSize', 20, 'FontWeight', 'bold');

    for i = 1:size(emotionPairs,1)
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
            'cLim', sharedCLim, ...
            'colormapName', 'turbo', ...
            'titleText', sprintf('%s-%s | full motion', pair{1}, pair{2}));

        ax2 = nexttile(tl, i + size(emotionPairs,1));
        plotKsBodyPartStickFigure(ksMicro, pair, ...
            'plotWhere', ax2, ...
            'aggFcn', 'median', ...
            'minSubjects', 1, ...
            'valueField', 'ksD', ...
            'annotateDelta', false, ...
            'showValues', false, ...
            'showGroupLabels', true, ...
            'showColorbar', false, ...
            'cLim', sharedCLim, ...
            'colormapName', 'turbo', ...
            'titleText', sprintf('%s-%s | micromovement', pair{1}, pair{2}));
    end

    cbAx = axes(f, 'Visible', 'off', 'Units', 'normalized', 'Position', [0.92 0.14 0.001 0.72]); %#ok<LAXES>
    colormap(cbAx, turbo(256));
    caxis(cbAx, sharedCLim);
    cb = colorbar(cbAx, 'Location', 'eastoutside');
    cb.Label.String = 'KS D';
    cb.FontSize = 10;

    annotation(f, 'textbox', [0.05 0.02 0.84 0.04], ...
        'String', sprintf('Shared color scale within figure. Top row: full motion. Bottom row: micromovement (<=%d mm/s).', immobilityThresholdMmps), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 10.5, 'Color', [0.25 0.25 0.25]);

    baseName = lower(char(focusEmotion)) + "_ks_stickfigures";
    exportgraphics(f, fullfile(outDir, baseName + ".png"), 'Resolution', 220);
    exportgraphics(f, fullfile(outDir, baseName + ".pdf"), 'ContentType', 'vector');
    savefig(f, fullfile(outDir, baseName + ".fig"));
end

fprintf('Saved disgust/fear KS stick figures under:\n%s\n', outDir);

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
