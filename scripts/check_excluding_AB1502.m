clearvars;
clc;

addpath(genpath('/Users/yoe/Documents/REPOS/eMove-playground/CODE'));

[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV( ...
    '/Users/yoe/Documents/REPOS/eMove-playground/resources/bodypart_marker_grouping.csv');

opts = detectImportOptions('/Users/yoe/Documents/REPOS/eMove-playground/resources/stim_video_encoding_SINGLES.csv', ...
    'VariableNamingRule', 'preserve');
opts = setvartype(opts, intersect({'videoID','emotionTag'}, opts.VariableNames, 'stable'), 'string');
T = readtable('/Users/yoe/Documents/REPOS/eMove-playground/resources/stim_video_encoding_SINGLES.csv', opts);
include = localToLogical(T.include);
vid = upper(strtrim(string(T.videoID)));
isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
vid(isNum) = compose('%04d', str2double(vid(isNum)));
emo = upper(strtrim(string(T.emotionTag)));
coding = table(vid(include), emo(include), 'VariableNames', {'videoID','groupCode'});

resultsCell = runMotionMetricsBatch('/Users/yoe/Documents/DATA/eMOVE-matlab-new', groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'immobilityThreshold', 25, ...
    'stimVideoEmotionCoding', coding);

keep = true(numel(resultsCell),1);
for i = 1:numel(resultsCell)
    sid = "";
    if isfield(resultsCell{i}, 'subjectID')
        sid = upper(string(resultsCell{i}.subjectID));
    end
    if sid == "AB1502"
        keep(i) = false;
    end
end
resultsCell = resultsCell(keep);

ks = computeKsDistancesFromResultsCell(resultsCell, coding, ...
    'speedField', 'speedArrayImmobile', ...
    'minSamplesPerCond', 200, ...
    'excludeBaseline', true);

S = localMedianSummary(ks);
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

