function compare_external_playground_same_subjects()
% Compare external vs playground KS results using exactly the same subjects.

playgroundRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
externalCodeRoot = '/Users/yoe/Documents/REPOS/eMove-analysis-project/CODE';
dataRoot = '/Users/yoe/Documents/DATA/eMOVE-matlab-new';
groupCsv = fullfile(playgroundRoot, 'resources', 'bodypart_marker_grouping.csv');
stimCsv = fullfile(playgroundRoot, 'resources', 'stim_video_encoding_SINGLES.csv');

outRoot = fullfile(playgroundRoot, 'outputs', 'qc');
if ~exist(outRoot, 'dir'), mkdir(outRoot); end
ts = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(outRoot, ['same_subjects_external_vs_playground_' ts]);
mkdir(outDir);

addpath(fullfile(playgroundRoot, 'CODE'));
addpath(fullfile(playgroundRoot, 'CODE', 'HELPERS'));
[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);
stimCoding = localLoadStimCoding(stimCsv);

% Run external
localActivate(externalCodeRoot);
rcE = runMotionMetricsBatch(dataRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'immobilityThreshold', 25, ...
    'stimVideoEmotionCoding', stimCoding);
idsE = localResultSubjectIDs(rcE);

% Run playground with exclusions OFF (for parity extraction)
localActivate(fullfile(playgroundRoot, 'CODE'));
rcP = runMotionMetricsBatch(dataRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'immobilityThreshold', 25, ...
    'stimVideoEmotionCoding', stimCoding, ...
    'applySubjectExclusions', false);
idsP = localResultSubjectIDs(rcP);

commonIDs = intersect(idsE, idsP);
onlyExternal = setdiff(idsE, idsP);
onlyPlayground = setdiff(idsP, idsE);

writetable(table(idsE, 'VariableNames', {'subjectID'}), fullfile(outDir, 'subjects_external.csv'));
writetable(table(idsP, 'VariableNames', {'subjectID'}), fullfile(outDir, 'subjects_playground.csv'));
writetable(table(commonIDs, 'VariableNames', {'subjectID'}), fullfile(outDir, 'subjects_common.csv'));
writetable(table(onlyExternal, 'VariableNames', {'subjectID'}), fullfile(outDir, 'subjects_only_external.csv'));
writetable(table(onlyPlayground, 'VariableNames', {'subjectID'}), fullfile(outDir, 'subjects_only_playground.csv'));

% Force both to the exact same subjects
rcE2 = localKeepSubjects(rcE, commonIDs);
rcP2 = localKeepSubjects(rcP, commonIDs);

% Compute KS and compare medians across subjects
localActivate(externalCodeRoot);
ksE = computeKsDistancesFromResultsCell(rcE2, stimCoding);
localActivate(fullfile(playgroundRoot, 'CODE'));
ksP = computeKsDistancesFromResultsCell(rcP2, stimCoding);

mE = groupsummary(ksE, {'markerGroup','emotionA','emotionB'}, 'median', {'ksD','deltaMedian_sorted'});
mP = groupsummary(ksP, {'markerGroup','emotionA','emotionB'}, 'median', {'ksD','deltaMedian_sorted'});
J = innerjoin(mE, mP, 'Keys', {'markerGroup','emotionA','emotionB'});
J.deltaD = J.median_ksD_mP - J.median_ksD_mE;
J.deltaSigned = J.median_deltaMedian_sorted_mP - J.median_deltaMedian_sorted_mE;
[~,ord] = sort(abs(J.deltaD), 'descend');
J = J(ord,:);
writetable(J, fullfile(outDir, 'ks_discrepancy_same_subjects.csv'));

fprintf('Output: %s\n', outDir);
fprintf('nExternal=%d nPlayground=%d nCommon=%d\n', numel(idsE), numel(idsP), numel(commonIDs));
fprintf('maxAbsDeltaD=%.6f medianAbsDeltaD=%.6f\n', max(abs(J.deltaD)), median(abs(J.deltaD)));
idx = strcmpi(J.markerGroup,'wrist_l') & strcmpi(J.emotionA,'FEAR') & strcmpi(J.emotionB,'JOY');
if any(idx)
    r = J(find(idx,1),:);
    fprintf('WRIST_L FEAR-JOY ext=%.5f pg=%.5f delta=%.5f\n', r.median_ksD_mE, r.median_ksD_mP, r.deltaD);
end
end

function ids = localResultSubjectIDs(rc)
ids = strings(numel(rc),1);
for i = 1:numel(rc)
    if isfield(rc{i}, 'subjectID')
        ids(i) = upper(strtrim(string(rc{i}.subjectID)));
    end
end
ids = unique(ids(strlength(ids)>0));
end

function rcOut = localKeepSubjects(rc, keepIDs)
rcOut = {};
for i = 1:numel(rc)
    if isfield(rc{i}, 'subjectID')
        sid = upper(strtrim(string(rc{i}.subjectID)));
        if any(strcmpi(sid, keepIDs))
            rcOut{end+1} = rc{i}; %#ok<AGROW>
        end
    end
end
end

function localActivate(codeRoot)
restoredefaultpath();
addpath(codeRoot);
addpath(fullfile(codeRoot, 'HELPERS'));
addpath(fullfile(codeRoot, 'ANALYSIS'));
addpath(fullfile(codeRoot, 'PLOTTING'));
end

function codingTbl = localLoadStimCoding(csvPath)
opts = detectImportOptions(csvPath);
opts = setvartype(opts, {'videoID', 'emotionTag'}, 'string');
opts = setvaropts(opts, {'videoID', 'emotionTag'}, 'WhitespaceRule', 'trim');
opts = setvaropts(opts, {'videoID', 'emotionTag'}, 'EmptyFieldRule', 'auto');
codingTbl = readtable(csvPath, opts);
codingTbl.videoID = upper(strtrim(codingTbl.videoID));
codingTbl.emotionTag = upper(strtrim(codingTbl.emotionTag));
codingTbl = codingTbl(~ismissing(codingTbl.videoID) & ~ismissing(codingTbl.emotionTag), :);
end
