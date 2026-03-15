% check_legacy_grouping_ks.m
%
% Focus check: use legacy grouped markers CSV to see effect on KS map values.

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/eMOVE-matlab-new';
legacyCsv = '/Users/yoe/Desktop/legacy_grouped_markers.csv';
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');

immobilityThreshold = 35;

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['legacy_grouping_check_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

C = readcell(legacyCsv, 'Delimiter', ',', 'TextType', 'string');
if size(C,2) < 2 || size(C,1) < 2
    error('Legacy grouping CSV appears malformed: %s', legacyCsv);
end
gVals = string(C(2:end, 1));
mVals = string(C(2:end, 2));
ok = gVals ~= "" & mVals ~= "";
gVals = gVals(ok);
mVals = mVals(ok);
grpNames = unique(cellstr(gVals), 'stable');
groupedMarkerNames = cell(numel(grpNames),1);
for i = 1:numel(grpNames)
    groupedMarkerNames{i} = cellstr(mVals(gVals == string(grpNames{i})));
end

coding = localLoadStimCoding(stimCsv);

rc = runMotionMetricsBatch(dataRoot, groupedMarkerNames, ...
    'markerGroupNames', grpNames, ...
    'immobilityThreshold', immobilityThreshold, ...
    'stimVideoEmotionCoding', coding);

ks = computeKsDistancesFromResultsCell(rc, coding, ...
    'speedField', 'speedArrayImmobile', ...
    'minSamplesPerCond', 200, ...
    'excludeBaseline', true);
writetable(ks, fullfile(outDir, 'ks_legacyGrouping_thr35_min200.csv'));

S = localMedianSummary(ks);
writetable(S, fullfile(outDir, 'ks_legacyGrouping_thr35_min200_median.csv'));

mask = strcmp(string(S.markerGroup), 'HEAD') & strcmp(string(S.pairLabel), 'FEAR-JOY');
disp(S(mask,:));

fprintf('Done: %s\n', outDir);

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

function S = localMedianSummary(T)
    mg = string(T.markerGroup);
    pl = string(T.pairLabel);
    [G, mgU, plU] = findgroups(mg, pl);
    ksMed = splitapply(@(x) median(x, 'omitnan'), T.ksD, G);
    dMed = splitapply(@(x) median(x, 'omitnan'), T.deltaMedian_sorted, G);
    nRows = splitapply(@numel, T.ksD, G);
    S = table(cellstr(mgU), cellstr(plU), ksMed, dMed, nRows, ...
        'VariableNames', {'markerGroup','pairLabel','ksD_median','delta_median','nRows'});
end
