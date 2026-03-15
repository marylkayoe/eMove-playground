% diagnose_manifest_vs_premanifest.m
%
% Compare KS immobility outputs between:
%   1) manifest-built MAT corpus
%   2) pre-manifest (sortedEMOVE/*/matlab) MAT corpus
%
% This isolates data-corpus effects while keeping analysis settings fixed.

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
manifestCsv = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/master_file_list_preview.csv';
manifestMatRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest';
preRoot = '/Users/yoe/Documents/DATA/sortedEMOVE';
groupCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
legacyGroupingCsv = '/Users/yoe/Desktop/legacy_grouped_markers.csv';

immobilityThreshold = 35;
minSamplesPerCond = 200;

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['manifest_vs_premanifest_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
stagedPreMatRoot = fullfile(outDir, 'premanifest_matroot');

addpath(genpath(fullfile(repoRoot, 'CODE')));

codingTable = localLoadStimCodingTable(stimCsv);
[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);

% Optional check: current included grouping vs legacy grouping.
grpCmp = localCompareGroupingCsvs(legacyGroupingCsv, groupCsv);
writetable(grpCmp, fullfile(outDir, 'grouping_comparison.csv'));

% Build pre-manifest manifest-like table and staged matRoot from sortedEMOVE folders.
[preTbl, stagingMap] = localBuildPreManifestTable(preRoot, stagedPreMatRoot);
writetable(preTbl(:, {'assignedSubject','sourcePath'}), fullfile(outDir, 'pre_manifest_subject_mat_paths.csv'));
writetable(stagingMap, fullfile(outDir, 'pre_manifest_staging_map.csv'));

% Run both batches with identical compute settings.
fprintf('Running MANIFEST corpus...\n');
resManifest = runMotionMetricsBatchFromManifest(manifestCsv, manifestMatRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'stimVideoEmotionCoding', codingTable, ...
    'computeFrequencyMetrics', false, ...
    'immobilityThreshold', immobilityThreshold, ...
    'continueOnError', true, ...
    'verbose', true);
save(fullfile(outDir, 'results_manifest.mat'), 'resManifest', '-v7.3');

fprintf('Running PRE-MANIFEST corpus...\n');
resPre = runMotionMetricsBatchFromManifest(preTbl, stagedPreMatRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'stimVideoEmotionCoding', codingTable, ...
    'computeFrequencyMetrics', false, ...
    'immobilityThreshold', immobilityThreshold, ...
    'continueOnError', true, ...
    'verbose', true);
save(fullfile(outDir, 'results_premanifest.mat'), 'resPre', '-v7.3');

% Compute KS tables.
ksManifest = computeKsDistancesFromResultsCell(resManifest, codingTable, ...
    'speedField', 'speedArrayImmobile', ...
    'excludeBaseline', true, ...
    'minSamplesPerCond', minSamplesPerCond);
ksPre = computeKsDistancesFromResultsCell(resPre, codingTable, ...
    'speedField', 'speedArrayImmobile', ...
    'excludeBaseline', true, ...
    'minSamplesPerCond', minSamplesPerCond);
writetable(ksManifest, fullfile(outDir, 'ks_manifest.csv'));
writetable(ksPre, fullfile(outDir, 'ks_premanifest.csv'));

% Row-aligned KS deltas.
cmp = localCompareKsTables(ksManifest, ksPre);
writetable(cmp, fullfile(outDir, 'ks_manifest_vs_premanifest.csv'));

% Requested targeted check: WRIST_L FEAR-JOY.
target = localPickTarget(cmp, 'WRIST_L', 'FEAR-JOY');
writetable(target, fullfile(outDir, 'target_WRIST_L_FEAR-JOY.csv'));
disp(target);

% Also include HEAD FEAR-JOY for continuity with prior checks.
targetHead = localPickTarget(cmp, 'HEAD', 'FEAR-JOY');
writetable(targetHead, fullfile(outDir, 'target_HEAD_FEAR-JOY.csv'));
disp(targetHead);

fprintf('Done. Output folder:\n%s\n', outDir);

%% Local helpers
function [T, stagingMap] = localBuildPreManifestTable(preRoot, stagedPreMatRoot)
    if ~exist(stagedPreMatRoot, 'dir')
        mkdir(stagedPreMatRoot);
    end

    subjDirs = dir(preRoot);
    subjDirs = subjDirs([subjDirs.isdir]);
    keep = ~ismember({subjDirs.name}, {'.', '..'});
    subjDirs = subjDirs(keep);

    subj = strings(0,1);
    src = strings(0,1);
    modality = strings(0,1);
    stagedPath = strings(0,1);

    for i = 1:numel(subjDirs)
        sid = upper(string(subjDirs(i).name));
        if isempty(regexp(char(sid), '^[A-Z]{2}\d{4}$', 'once'))
            continue;
        end
        matDir = fullfile(subjDirs(i).folder, subjDirs(i).name, 'matlab');
        if ~isfolder(matDir)
            continue;
        end
        mats = dir(fullfile(matDir, '*.mat'));
        if isempty(mats)
            continue;
        end
        % sortedEMOVE has one MAT per subject in practice; choose latest as guard.
        [~, idx] = max([mats.datenum]);
        fullPath = fullfile(mats(idx).folder, mats(idx).name);
        subjOut = fullfile(stagedPreMatRoot, char(sid));
        if ~exist(subjOut, 'dir')
            mkdir(subjOut);
        end
        stagedMat = fullfile(subjOut, mats(idx).name);
        if ~isfile(stagedMat)
            copyfile(fullPath, stagedMat);
        end

        subj(end+1,1) = sid; %#ok<AGROW>
        src(end+1,1) = string(fullPath); %#ok<AGROW>
        modality(end+1,1) = "mocap"; %#ok<AGROW>
        stagedPath(end+1,1) = string(stagedMat); %#ok<AGROW>
    end

    T = table(subj, modality, src, 'VariableNames', {'assignedSubject','modality','sourcePath'});
    stagingMap = table(subj, src, stagedPath, 'VariableNames', {'assignedSubject','sourcePath','stagedMatPath'});
end

function codingTable = localLoadStimCodingTable(stimCsv)
    opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
    strCols = {'videoID','emotionTag','groupCode'};
    strCols = intersect(strCols, opts.VariableNames, 'stable');
    if ~isempty(strCols)
        opts = setvartype(opts, strCols, 'string');
    end
    T = readtable(stimCsv, opts);

    vid = upper(strtrim(string(T.videoID)));
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));

    include = localToLogical(T.include);
    if ismember('groupCode', T.Properties.VariableNames)
        code = upper(strtrim(string(T.groupCode)));
    else
        code = upper(strtrim(string(T.emotionTag)));
    end
    keep = include & vid ~= "" & code ~= "";
    codingTable = table(vid(keep), code(keep), 'VariableNames', {'videoID','groupCode'});
end

function out = localToLogical(v)
    if islogical(v), out = v; return; end
    if isnumeric(v), out = v ~= 0; return; end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
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

function cmp = localCompareKsTables(ksA, ksB)
    if isempty(ksA) || ~ismember('markerGroup', ksA.Properties.VariableNames)
        error('Manifest KS table missing expected columns.');
    end
    if isempty(ksB) || ~ismember('markerGroup', ksB.Properties.VariableNames)
        error('Pre-manifest KS table missing expected columns.');
    end

    a = table(string(ksA.markerGroup), string(ksA.pairLabel), ksA.ksD, ksA.deltaMedian_sorted, ...
        'VariableNames', {'markerGroup','pairLabel','ksD_manifest','delta_manifest'});
    b = table(string(ksB.markerGroup), string(ksB.pairLabel), ksB.ksD, ksB.deltaMedian_sorted, ...
        'VariableNames', {'markerGroup','pairLabel','ksD_premanifest','delta_premanifest'});

    cmp = outerjoin(a, b, 'Keys', {'markerGroup','pairLabel'}, 'MergeKeys', true, 'Type', 'full');
    cmp.dKs = cmp.ksD_manifest - cmp.ksD_premanifest;
    cmp.dDelta = cmp.delta_manifest - cmp.delta_premanifest;
    cmp = sortrows(cmp, {'markerGroup','pairLabel'});
end

function T = localPickTarget(cmp, marker, pair)
    m = string(cmp.markerGroup) == string(marker) & string(cmp.pairLabel) == string(pair);
    T = cmp(m, :);
end
