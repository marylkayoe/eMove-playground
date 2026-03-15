% run_repro_matrix_qc.m
%
% Repro matrix for legacy KS values across data roots and immobility thresholds.

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
groupCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');

dataRoots = { ...
    '/Users/yoe/Documents/DATA/eMOVE-matlab', ...
    '/Users/yoe/Documents/DATA/eMOVE-matlab-new' ...
    };
thresholds = [25, 35];

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['repro_matrix_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));
[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);
coding = localLoadStimCoding(stimCsv);

rows = table();

for r = 1:numel(dataRoots)
    root = dataRoots{r};
    if ~isfolder(root)
        warning('Missing data root: %s', root);
        continue;
    end
    for t = 1:numel(thresholds)
        thr = thresholds(t);
        fprintf('Running root=%s threshold=%d\n', root, thr);
        rc = runMotionMetricsBatch(root, groupedMarkerNames, ...
            'markerGroupNames', groupedBodypartNames, ...
            'immobilityThreshold', thr, ...
            'stimVideoEmotionCoding', coding);

        ks = computeKsDistancesFromResultsCell(rc, coding); % default immobile+min200
        tag = sprintf('%s_thr%d', localShortRoot(root), thr);
        writetable(ks, fullfile(outDir, ['ks_' tag '.csv']));

        s = localMedianSummary(ks, tag);
        writetable(s, fullfile(outDir, ['ks_median_' tag '.csv']));

        tgt = localTargets(s);
        tgt.dataRoot = repmat(string(root), height(tgt), 1);
        tgt.threshold = repmat(thr, height(tgt), 1);
        rows = [rows; tgt]; %#ok<AGROW>
    end
end

writetable(rows, fullfile(outDir, 'target_rows_matrix.csv'));
disp(rows);
fprintf('Done. %s\n', outDir);

function coding = localLoadStimCoding(stimCsv)
    opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, intersect({'videoID','emotionTag','groupCode'}, opts.VariableNames, 'stable'), 'string');
    T = readtable(stimCsv, opts);
    include = localToLogical(T.include);
    vid = upper(strtrim(string(T.videoID)));
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));
    emo = upper(strtrim(string(T.emotionTag)));
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

function T = localTargets(S)
    k = S.Properties.VariableNames;
    ksCol = k{contains(k, 'ksD_median_')};
    dCol = k{contains(k, 'delta_median_')};
    nCol = k{contains(k, 'n_')};
    mask = (strcmp(string(S.markerGroup), 'HEAD') & strcmp(string(S.pairLabel), 'FEAR-JOY')) | ...
           (strcmp(string(S.markerGroup), 'WRIST_L') & strcmp(string(S.pairLabel), 'FEAR-JOY')) | ...
           (strcmp(string(S.markerGroup), 'WRIST_R') & strcmp(string(S.pairLabel), 'FEAR-JOY'));
    T = table(S.markerGroup(mask), S.pairLabel(mask), S.(ksCol)(mask), S.(dCol)(mask), S.(nCol)(mask), ...
        'VariableNames', {'markerGroup','pairLabel','ksD','delta','nRows'});
end

function s = localShortRoot(root)
    if contains(root, 'eMOVE-matlab-new')
        s = 'matlab_new';
    elseif contains(root, 'eMOVE-matlab')
        s = 'matlab_old';
    else
        s = 'root';
    end
end

