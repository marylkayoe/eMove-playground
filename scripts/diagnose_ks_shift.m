% diagnose_ks_shift.m
%
% Diagnose why KS immobility maps differ from prior runs.
% Compares:
%   A) existing resultsCell (immobility threshold likely 35)
%   B) recomputed resultsCell with immobilityThreshold=25
% using same coding table and minSamplesPerCond=200.

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
manifestCsv = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/master_file_list_preview.csv';
matRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest';
groupCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
existingResultsPath = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/analysis_runs/20260311_110642/resultsCell.mat';
legacyGroupingCsv = '/Users/yoe/Desktop/legacy_grouped_markers.csv';

outDir = fullfile(repoRoot, 'outputs', 'figures', ['ks_diagnose_' char(string(datetime('now','Format','yyyyMMdd_HHmmss')))]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

% 1) Load coding table and summarize emotion coverage.
codingTable = localLoadStimCodingTable(stimCsv);
[emoSummary, pairList] = localSummarizeCoding(codingTable);
writetable(emoSummary, fullfile(outDir, 'coding_emotion_summary.csv'));
writetable(pairList, fullfile(outDir, 'coding_pair_list.csv'));

% 2) Verify legacy grouping equals current included grouping.
grpCmp = localCompareGroupingCsvs(legacyGroupingCsv, groupCsv);
writetable(grpCmp, fullfile(outDir, 'grouping_comparison.csv'));

% 3A) KS from existing resultsCell (baseline run).
S = load(existingResultsPath, 'resultsCell');
resultsCell35 = S.resultsCell;
ks35 = computeKsDistancesFromResultsCell(resultsCell35, codingTable, ...
    'speedField', 'speedArrayImmobile', ...
    'excludeBaseline', true, ...
    'minSamplesPerCond', 200);
writetable(ks35, fullfile(outDir, 'ks_from_resultsCell35_min200.csv'));

% 3B) Recompute metrics with immobilityThreshold=25 and then KS.
[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);
resultsCell25 = runMotionMetricsBatchFromManifest(manifestCsv, matRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'stimVideoEmotionCoding', codingTable, ...
    'computeFrequencyMetrics', false, ...
    'immobilityThreshold', 25, ...
    'continueOnError', true, ...
    'verbose', true);
save(fullfile(outDir, 'resultsCell_immobile25.mat'), 'resultsCell25', '-v7.3');

ks25 = computeKsDistancesFromResultsCell(resultsCell25, codingTable, ...
    'speedField', 'speedArrayImmobile', ...
    'excludeBaseline', true, ...
    'minSamplesPerCond', 200);
writetable(ks25, fullfile(outDir, 'ks_from_resultsCell25_min200.csv'));

% 4) Targeted head FEAR-JOY summary.
cmpTbl = localComparePairMarker(ks35, ks25, 'HEAD', 'FEAR', 'JOY');
writetable(cmpTbl, fullfile(outDir, 'head_fear_joy_compare.csv'));
disp(cmpTbl);

fprintf('Done. Diagnostic outputs:\n%s\n', outDir);

%% Local helpers
function codingTable = localLoadStimCodingTable(stimCsv)
    opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, intersect({'videoID','emotionTag','groupCode'}, opts.VariableNames, 'stable'), 'string');
    T = readtable(stimCsv, opts);
    include = localToLogical(T.include);
    vid = upper(strtrim(string(T.videoID)));
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));
    if ismember('groupCode', T.Properties.VariableNames)
        emo = upper(strtrim(string(T.groupCode)));
    else
        emo = upper(strtrim(string(T.emotionTag)));
    end
    keep = include & vid ~= "" & emo ~= "";
    codingTable = table(vid(keep), emo(keep), 'VariableNames', {'videoID','groupCode'});
end

function out = localToLogical(v)
    if islogical(v), out = v; return; end
    if isnumeric(v), out = v ~= 0; return; end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end

function [emoSummary, pairList] = localSummarizeCoding(codingTable)
    T = codingTable;
    T = T(~ismember(T.groupCode, {'BASELINE','0','X',''}), :);
    [u, ~, idx] = unique(T.groupCode, 'stable');
    n = accumarray(idx, 1);
    emoSummary = table(u, n, 'VariableNames', {'emotion','nVideos'});

    if numel(u) >= 2
        P = nchoosek(cellstr(u), 2);
        pairList = cell2table(P, 'VariableNames', {'emotionA','emotionB'});
    else
        pairList = table();
    end
end

function tbl = localCompareGroupingCsvs(legacyCsv, currentCsv)
    L = readtable(legacyCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    C = readtable(currentCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    C = C(localToLogical(C.include), :);
    Lk = sortrows(table(upper(strtrim(L.groupName)), upper(strtrim(L.markerName)), ...
        'VariableNames', {'groupName','markerName'}));
    Ck = sortrows(table(upper(strtrim(C.groupName)), upper(strtrim(C.markerName)), ...
        'VariableNames', {'groupName','markerName'}));

    keyL = Lk.groupName + "|" + Lk.markerName;
    keyC = Ck.groupName + "|" + Ck.markerName;
    onlyLegacy = setdiff(keyL, keyC);
    onlyCurrent = setdiff(keyC, keyL);

    metric = ["legacy_rows"; "current_rows"; "only_legacy"; "only_current"];
    value = [height(Lk); height(Ck); numel(onlyLegacy); numel(onlyCurrent)];
    tbl = table(metric, value);
end

function out = localComparePairMarker(ks35, ks25, marker, emoA, emoB)
    s = sort(string({emoA, emoB}));
    pair = s(1) + "-" + s(2);
    metric = ["nRows_35"; "medianD_35"; "medianDelta_35"; "nRows_25"; "medianD_25"; "medianDelta_25"];
    value = nan(numel(metric),1);

    m35 = string(ks35.markerGroup) == string(marker) & string(ks35.pairLabel) == pair;
    m25 = string(ks25.markerGroup) == string(marker) & string(ks25.pairLabel) == pair;
    value(1) = nnz(m35);
    value(2) = median(ks35.ksD(m35), 'omitnan');
    value(3) = median(ks35.deltaMedian_sorted(m35), 'omitnan');
    value(4) = nnz(m25);
    value(5) = median(ks25.ksD(m25), 'omitnan');
    value(6) = median(ks25.deltaMedian_sorted(m25), 'omitnan');
    out = table(metric, value);
end
