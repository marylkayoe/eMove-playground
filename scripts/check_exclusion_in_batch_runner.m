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

rc = runMotionMetricsBatch('/Users/yoe/Documents/DATA/eMOVE-matlab-new', groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'immobilityThreshold', 25, ...
    'stimVideoEmotionCoding', coding);

sids = strings(numel(rc),1);
for i = 1:numel(rc)
    sids(i) = upper(string(rc{i}.subjectID));
end

fprintf('nResults=%d\n', numel(rc));
fprintf('hasAB1502=%d\n', any(sids == "AB1502"));

function out = localToLogical(v)
    if islogical(v), out = v; return; end
    if isnumeric(v), out = v ~= 0; return; end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end

