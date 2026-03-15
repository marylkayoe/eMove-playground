clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
legacyMat = fullfile(repoRoot, 'legacy_resultCellSingles.mat');
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
outDir = fullfile(repoRoot, 'outputs', 'figures', 'legacy_saved_mat_qc');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

m = matfile(legacyMat);
resultsCellSingles = m.resultsCellSingles;

opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
opts = setvartype(opts, intersect({'videoID','emotionTag','groupCode'}, opts.VariableNames, 'stable'), 'string');
T = readtable(stimCsv, opts);
include = localToLogical(T.include);
vid = upper(strtrim(string(T.videoID)));
isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
vid(isNum) = compose('%04d', str2double(vid(isNum)));
emo = upper(strtrim(string(T.emotionTag)));
coding = table(vid(include), emo(include), 'VariableNames', {'videoID','groupCode'});

ksTbl = computeKsDistancesFromResultsCell(resultsCellSingles, coding, ...
    'speedField', 'speedArrayImmobile', ...
    'minSamplesPerCond', 200, ...
    'excludeBaseline', true);

figBefore = findall(groot, 'Type', 'figure');
plotKsHeatmap(ksTbl);
localSaveNewFigures(figBefore, outDir, 'ks_heatmap_from_saved_legacy');

figBefore = findall(groot, 'Type', 'figure');
plotSpeedCDFByStimGroupFromResultsCell(resultsCellSingles, coding, ...
    'plotMode', 'perVideoMedian', ...
    'useImmobile', true, ...
    'doBaselineNormalize', true, ...
    'figureTitle', 'Saved legacy resultCellSingles | perVideoMedian immobile');
localSaveNewFigures(figBefore, outDir, 'cdf_from_saved_legacy_perVideoMedian_immobile');

figBefore = findall(groot, 'Type', 'figure');
plotSpeedCDFByStimGroupFromResultsCell(resultsCellSingles, coding, ...
    'plotMode', 'perVideoMedian', ...
    'useImmobile', false, ...
    'doBaselineNormalize', true, ...
    'figureTitle', 'Saved legacy resultCellSingles | perVideoMedian fullspeed');
localSaveNewFigures(figBefore, outDir, 'cdf_from_saved_legacy_perVideoMedian_full');

fprintf('Saved outputs to %s\n', outDir);

function out = localToLogical(v)
    if islogical(v), out = v; return; end
    if isnumeric(v), out = v ~= 0; return; end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
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

