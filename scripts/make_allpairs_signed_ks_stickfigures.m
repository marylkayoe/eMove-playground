% make_allpairs_signed_ks_stickfigures.m
%
% Build signed all-pairs stick-figure discriminability panels for:
%   - full motion
%   - micromovement
%
% Color encodes signed KS-weighted median contrast:
%   signedKs = ksD * sign(deltaMedian_sorted)
% where deltaMedian_sorted follows the title order (second emotion minus first).
%
% Per-tile scaling is used so strong FEAR effects do not flatten other pairs.

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
outDir = fullfile(repoRoot, 'outputs', 'figures', ['allpairs_signed_ks_stickfigures_' char(runStamp)]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

immobilityThresholdMmps = 35;
minSamplesPerCond = 200;
divCmap = localBlueWhiteRed(256);

addpath(genpath(fullfile(repoRoot, 'CODE')));

fprintf('=== All-pairs signed KS stick figures ===\n');
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

ksFull.signedKs = ksFull.ksD .* sign(ksFull.deltaMedian_sorted);
ksMicro.signedKs = ksMicro.ksD .* sign(ksMicro.deltaMedian_sorted);

writetable(ksFull, fullfile(outDir, 'ks_full_signed.csv'));
writetable(ksMicro, fullfile(outDir, 'ks_micro_signed.csv'));
save(fullfile(outDir, 'ks_full_signed.mat'), 'ksFull', '-v7.3');
save(fullfile(outDir, 'ks_micro_signed.mat'), 'ksMicro', '-v7.3');

figBefore = findall(groot, 'Type', 'figure');
plotKsBodyPartStickFigureAllPairs(ksFull, ...
    'excludeEmotions', {'X','0','BASELINE'}, ...
    'annotateDelta', false, ...
    'showValues', false, ...
    'showGroupLabels', true, ...
    'useSharedCLim', false, ...
    'valueField', 'signedKs', ...
    'colormapName', divCmap, ...
    'titleText', 'Signed body-part emotion differences | full motion');
localAnnotateSignedFigure(gcf);
localTuneCurrentFigure(1900, 1300);
localSaveNewFigures(figBefore, outDir, 'signed_ks_stickfig_full');

figBefore = findall(groot, 'Type', 'figure');
plotKsBodyPartStickFigureAllPairs(ksMicro, ...
    'excludeEmotions', {'X','0','BASELINE'}, ...
    'annotateDelta', false, ...
    'showValues', false, ...
    'showGroupLabels', true, ...
    'useSharedCLim', false, ...
    'valueField', 'signedKs', ...
    'colormapName', divCmap, ...
    'titleText', sprintf('Signed body-part emotion differences | micromovement (<=%d mm/s)', immobilityThresholdMmps));
localAnnotateSignedFigure(gcf);
localTuneCurrentFigure(1900, 1300);
localSaveNewFigures(figBefore, outDir, 'signed_ks_stickfig_micro');

fprintf('Saved all-pairs signed KS stick figures under:\n%s\n', outDir);

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

function cmap = localBlueWhiteRed(n)
    if nargin < 1
        n = 256;
    end
    n1 = floor(n/2);
    n2 = n - n1;
    blue = [0.16 0.35 0.82];
    white = [1 1 1];
    red = [0.80 0.16 0.16];
    cmap1 = [linspace(blue(1), white(1), n1)', linspace(blue(2), white(2), n1)', linspace(blue(3), white(3), n1)'];
    cmap2 = [linspace(white(1), red(1), n2)', linspace(white(2), red(2), n2)', linspace(white(3), red(3), n2)'];
    cmap = [cmap1; cmap2];
end

function localAnnotateSignedFigure(fig)
    annotation(fig, 'textbox', [0.04 0.01 0.84 0.05], ...
        'String', ['Color encodes signed KS-weighted median contrast (signedKs = ksD * sign(deltaMedian_sorted)). ' ...
                   'For pair A-B, warm means B is faster; cool means A is faster. Per-tile scale.'], ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'FontSize', 10.5, 'Color', [0.25 0.25 0.25]);
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
