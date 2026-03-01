function outTbl = computeKsDistancesFromResultsCell(resultsCell, codingTable, varargin)
% computeKsDistancesFromResultsCell - Within-subject KS distances between emotion conditions.
%
%   outTbl = computeKsDistancesFromResultsCell(resultsCell, codingTable, ...)
%
% Inputs:
%   resultsCell - cell array from runMotionMetricsBatch (each entry with .summaryTable)
%   codingTable - table or cell array {videoID, emotionLabel}
%
% Optional name-value:
%   'speedField'           - 'speedArrayImmobile' (default) or 'speedArray'
%   'minSamplesPerCond'    - minimum samples per emotion (default 200)
%   'emotionPairs'         - cell array Nx2 of emotion labels (default: all pairs)
%   'excludeBaseline'      - logical (default true)
%
% Output:
%   outTbl - table with per-subject KS distances

p = inputParser;
addParameter(p, 'speedField', 'speedArrayImmobile', @(x) ischar(x) || isstring(x));
addParameter(p, 'minSamplesPerCond', 200, @(x) isscalar(x) && x >= 0);
addParameter(p, 'emotionPairs', {}, @(x) iscell(x) || isstring(x));
addParameter(p, 'excludeBaseline', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

speedField = char(p.Results.speedField);
minSamples = p.Results.minSamplesPerCond;
emotionPairs = p.Results.emotionPairs;
excludeBaseline = p.Results.excludeBaseline;

[vidToEmotion, allEmotions] = localBuildVideoMap(codingTable);
excludeEmotions = {'X'};
allEmotions = setdiff(allEmotions, excludeEmotions, 'stable');


if ischar(emotionPairs) || isstring(emotionPairs)
    emotionPairs = cellstr(emotionPairs);
end
if isempty(emotionPairs)
    emotionPairs = nchoosek(allEmotions, 2);
end

rows = [];
for sIdx = 1:numel(resultsCell)
    rc = resultsCell{sIdx};
    if ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
        continue;
    end
    subjID = '';
    if isfield(rc, 'subjectID'), subjID = char(rc.subjectID); end
    if isempty(subjID), subjID = sprintf('subj%d', sIdx); end

    st = rc.summaryTable;
    if ~ismember(speedField, st.Properties.VariableNames)
        warning('computeKsDistancesFromResultsCell:MissingField', ...
            'Missing field "%s" in summaryTable for subject %s', speedField, subjID);
        continue;
    end

    % map video IDs to emotions
    emotion = cell(height(st), 1);
    for r = 1:height(st)
        vid = st.videoID{r};
        if excludeBaseline && localIsBaseline(vid)
            emotion{r} = '';
            continue;
        end
        if isKey(vidToEmotion, vid)
            emotion{r} = vidToEmotion(vid);
        else
            emotion{r} = '';
        end
    end
    st.emotion = emotion;

    groupNames = unique(st.markerGroup, 'stable');
    for g = 1:numel(groupNames)
        gName = groupNames{g};
        gRows = strcmp(st.markerGroup, gName) & ~strcmp(st.emotion, '');
        if ~any(gRows)
            continue;
        end

        for pIdx = 1:size(emotionPairs, 1)
            eA = emotionPairs{pIdx, 1};
            eB = emotionPairs{pIdx, 2};
            idxA = gRows & strcmp(st.emotion, eA);
            idxB = gRows & strcmp(st.emotion, eB);
            if ~any(idxA) || ~any(idxB)
                continue;
            end

            valsA = localConcatCells(st.(speedField)(idxA));
            valsB = localConcatCells(st.(speedField)(idxB));

            medA = median(valsA, 'omitnan');
            medB = median(valsB, 'omitnan');

            row.medianA = medA;
            row.medianB = medB;
            row.deltaMedian_AminusB = medA - medB;

            % canonical (order-insensitive) pair label + canonical delta
            emoPair = sort(string({eA,eB}));
            row.pairLabel = char(emoPair(1) + "-" + emoPair(2));

            % define canonical delta as (second - first) in sorted order
            if string(eA) == emoPair(1)
                row.deltaMedian_sorted = medB - medA; % (emo2 - emo1)
            else
                row.deltaMedian_sorted = medA - medB; % (emo2 - emo1)
            end


            nA = numel(valsA);
            nB = numel(valsB);
            if nA < minSamples || nB < minSamples
                continue;
            end

            [~, ~, ksD] = kstest2(valsA, valsB);

            row.subjectID = subjID;
            row.markerGroup = gName;
            row.emotionA = eA;
            row.emotionB = eB;
            row.ksD = ksD;
            row.nSamplesA = nA;
            row.nSamplesB = nB;
            row.nVideosA = sum(idxA);
            row.nVideosB = sum(idxB);
            rows = [rows; row]; %#ok<AGROW>
        end
    end
end

if isempty(rows)
    outTbl = table();
else
    outTbl = struct2table(rows);
end
end

function vals = localConcatCells(cellVals)
vals = [];
for i = 1:numel(cellVals)
    v = cellVals{i};
    if ~isempty(v)
        vals = [vals; v(:)]; %#ok<AGROW>
    end
end
end

function tf = localIsBaseline(vid)
tf = contains(lower(vid), 'baseline') || strcmp(vid, 'BASELINE') || strcmp(vid, '0');
end

function [vidToEmotion, emotions] = localBuildVideoMap(codingTable)
vidToEmotion = containers.Map;
emotions = {};
if istable(codingTable)
    vNames = codingTable.Properties.VariableNames;
    if numel(vNames) >= 2
        vids = codingTable{:, 1};
        emos = codingTable{:, 2};
    else
        vids = {}; emos = {};
    end
elseif iscell(codingTable)
    vids = codingTable(:, 1);
    emos = codingTable(:, 2);
else
    vids = {}; emos = {};
end

if isstring(vids)
    vids = cellstr(vids);
end
if isstring(emos)
    emos = cellstr(emos);
end

for i = 1:numel(vids)
    vid = vids{i};
    emo = emos{i};
    if localIsMissingScalar(vid) || localIsMissingScalar(emo)
        continue;
    end
    vid = char(string(vid));
    emo = char(string(emo));
    vidToEmotion(vid) = emo;
    emotions{end+1,1} = emo; %#ok<AGROW>
end
emotions = unique(emotions, 'stable');
end

function tf = localIsMissingScalar(x)
if isempty(x)
    tf = true;
    return;
end
if isstring(x)
    tf = all(ismissing(x));
    return;
end
if ischar(x)
    tf = isempty(strtrim(x));
    return;
end
if isnumeric(x)
    tf = all(isnan(x));
    return;
end
tf = false;
end
