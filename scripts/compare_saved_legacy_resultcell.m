clearvars;
clc;

addpath(genpath('/Users/yoe/Documents/REPOS/eMove-playground/CODE'));

legacyMat = '/Users/yoe/Documents/REPOS/eMove-playground/legacy_resultCellSingles.mat';
stimCsv = '/Users/yoe/Documents/REPOS/eMove-playground/resources/stim_video_encoding_SINGLES.csv';
outDir = '/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/legacy_saved_mat_qc';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% Load saved legacy resultsCellSingles (v7.3 via matfile)
m = matfile(legacyMat);
rcLegacy = m.resultsCellSingles;

% Build coding table
opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
opts = setvartype(opts, intersect({'videoID','emotionTag'}, opts.VariableNames, 'stable'), 'string');
T = readtable(stimCsv, opts);
include = localToLogical(T.include);
vid = upper(strtrim(string(T.videoID)));
isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
vid(isNum) = compose('%04d', str2double(vid(isNum)));
emo = upper(strtrim(string(T.emotionTag)));
coding = table(vid(include), emo(include), 'VariableNames', {'videoID','groupCode'});

% KS from saved legacy resultCellSingles
ksLegacy = computeKsDistancesFromResultsCell(rcLegacy, coding, ...
    'speedField', 'speedArrayImmobile', ...
    'minSamplesPerCond', 200, ...
    'excludeBaseline', true);
writetable(ksLegacy, fullfile(outDir, 'ks_from_saved_legacy_resultCellSingles.csv'));

S = localMedianSummary(ksLegacy);
writetable(S, fullfile(outDir, 'ks_from_saved_legacy_resultCellSingles_median.csv'));

mask = (strcmp(string(S.markerGroup), 'HEAD') | ...
        strcmp(string(S.markerGroup), 'WRIST_L') | ...
        strcmp(string(S.markerGroup), 'WRIST_R')) & ...
       strcmp(string(S.pairLabel), 'FEAR-JOY');
disp(S(mask, :));

function out = localToLogical(v)
    if islogical(v), out = v; return; end
    if isnumeric(v), out = v ~= 0; return; end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end

function S = localMedianSummary(T)
    mg = string(T.markerGroup);
    pl = string(T.pairLabel);
    [G, mgU, plU] = findgroups(mg, pl);
    ksMed = splitapply(@(x) median(x, 'omitnan'), T.ksD, G);
    dMed = splitapply(@(x) median(x, 'omitnan'), T.deltaMedian_sorted, G);
    nRows = splitapply(@numel, T.ksD, G);
    S = table(cellstr(mgU), cellstr(plU), ksMed, dMed, nRows, ...
        'VariableNames', {'markerGroup','pairLabel','ksD','delta','nRows'});
end

