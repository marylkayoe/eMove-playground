function run_external_vs_playground_ab_qc()
% A/B comparison: run identical metric chain with
% 1) external legacy code folder and 2) current playground code.
% Writes row-level KS diffs and focused FEAR-JOY summary.

fprintf('=== External vs playground A/B QC ===\n');

playgroundRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
externalCodeRoot = '/Users/yoe/Documents/REPOS/eMove-analysis-project/CODE';
dataRoot = '/Users/yoe/Documents/DATA/eMOVE-matlab-new';
groupCsv = fullfile(playgroundRoot, 'resources', 'bodypart_marker_grouping.csv');
stimCsv = fullfile(playgroundRoot, 'resources', 'stim_video_encoding_SINGLES.csv');

outRoot = fullfile(playgroundRoot, 'outputs', 'qc');
if ~exist(outRoot, 'dir'), mkdir(outRoot); end
ts = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(outRoot, ['external_vs_playground_ab_' ts]);
mkdir(outDir);

% Load grouping/coding using playground helper to keep exact same inputs.
addpath(fullfile(playgroundRoot, 'CODE'));
addpath(fullfile(playgroundRoot, 'CODE', 'HELPERS'));
[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);
stimCoding = localLoadStimCoding(stimCsv);

% Run using external code tree.
fprintf('Running external code: %s\n', externalCodeRoot);
localActivateCodeTree(externalCodeRoot);
rcExternal = runMotionMetricsBatch(dataRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'immobilityThreshold', 25, ...
    'stimVideoEmotionCoding', stimCoding);
ksExternal = computeKsDistancesFromResultsCell(rcExternal, stimCoding);

% Run using playground code tree.
fprintf('Running playground code: %s\n', fullfile(playgroundRoot, 'CODE'));
localActivateCodeTree(fullfile(playgroundRoot, 'CODE'));
rcPlayground = runMotionMetricsBatch(dataRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'immobilityThreshold', 25, ...
    'stimVideoEmotionCoding', stimCoding);
ksPlayground = computeKsDistancesFromResultsCell(rcPlayground, stimCoding);

% Save raw outputs.
save(fullfile(outDir, 'results_external.mat'), 'rcExternal', 'ksExternal', '-v7.3');
save(fullfile(outDir, 'results_playground.mat'), 'rcPlayground', 'ksPlayground', '-v7.3');

% Harmonize for row-wise diff.
ke = localCanonizeKs(ksExternal);
kp = localCanonizeKs(ksPlayground);

ke = renamevars(ke, {'ksDistance','signedDelta','nSubjects'}, {'ksDistance_ext','signedDelta_ext','nSubjects_ext'});
kp = renamevars(kp, {'ksDistance','signedDelta','nSubjects'}, {'ksDistance_pg','signedDelta_pg','nSubjects_pg'});

joined = outerjoin(ke, kp, ...
    'Keys', {'markerGroup','emotion1','emotion2'}, ...
    'MergeKeys', true, ...
    'Type', 'full');

joined = movevars(joined, {'markerGroup','emotion1','emotion2'}, 'Before', 1);
joined.deltaD = joined.ksDistance_pg - joined.ksDistance_ext;
joined.deltaSigned = joined.signedDelta_pg - joined.signedDelta_ext;
joined.deltaN = joined.nSubjects_pg - joined.nSubjects_ext;

% Sort by largest KS discrepancy.
[~, ord] = sort(abs(joined.deltaD), 'descend', 'MissingPlacement', 'last');
joined = joined(ord, :);

writetable(joined, fullfile(outDir, 'ks_row_discrepancy.csv'));

% Focus row for quick sanity.
focus = joined(strcmpi(joined.emotion1, 'FEAR') & strcmpi(joined.emotion2, 'JOY'), :);
writetable(focus, fullfile(outDir, 'fear_joy_discrepancy.csv'));

fprintf('\nSaved A/B report to:\n%s\n', outDir);
fprintf('Top 10 absolute deltaD rows:\n');
disp(joined(1:min(10,height(joined)), ...
    {'markerGroup','emotion1','emotion2','ksDistance_ext','ksDistance_pg','deltaD','signedDelta_ext','signedDelta_pg','deltaSigned','nSubjects_ext','nSubjects_pg','deltaN'}));
end

function tbl = localCanonizeKs(tblIn)
tbl = tblIn;
v = string(tbl.Properties.VariableNames);

markerVar = localPickVar(v, ["markerGroup","marker_group"]);
emo1Var = localPickVar(v, ["emotion1","emotionA","emo1"]);
emo2Var = localPickVar(v, ["emotion2","emotionB","emo2"]);
ksVar = localPickVar(v, ["ksDistance","ksD","D"]);
signedVar = localPickVar(v, ["signedDelta","deltaMedian_sorted","deltaMedian_AminusB","delta"]);
subjectVar = localPickVar(v, ["subjectID","subjectId","subject"]);

tbl.markerGroup = lower(strtrim(string(tbl.(markerVar))));
tbl.emotion1 = upper(strtrim(string(tbl.(emo1Var))));
tbl.emotion2 = upper(strtrim(string(tbl.(emo2Var))));
tbl.ksDistance = double(tbl.(ksVar));
tbl.signedDelta = double(tbl.(signedVar));

if ~isempty(subjectVar)
    tbl.subjectID = upper(strtrim(string(tbl.(subjectVar))));
else
    tbl.subjectID = strings(height(tbl), 1);
end

% Convert to one row per markerGroup+emotion pair using median across subjects.
[G, gMarker, gE1, gE2] = findgroups(tbl.markerGroup, tbl.emotion1, tbl.emotion2);
tbl = table(gMarker, gE1, gE2, ...
    splitapply(@(x) median(x,'omitnan'), tbl.ksDistance, G), ...
    splitapply(@(x) median(x,'omitnan'), tbl.signedDelta, G), ...
    splitapply(@(x) numel(unique(x)), tbl.subjectID, G), ...
    'VariableNames', {'markerGroup','emotion1','emotion2','ksDistance','signedDelta','nSubjects'});
end

function out = localPickVar(names, candidates)
out = "";
for i = 1:numel(candidates)
    hit = find(strcmpi(names, candidates(i)), 1);
    if ~isempty(hit)
        out = names(hit);
        return;
    end
end
if strlength(out) == 0
    error('Required variable not found. Tried: %s', strjoin(cellstr(candidates), ', '));
end
end

function localActivateCodeTree(codeRoot)
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
