clearvars;
clc;

addpath(genpath('/Users/yoe/Documents/REPOS/eMove-playground/CODE'));
S = load('/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/analysis_runs/20260311_110642/resultsCell.mat', 'resultsCell');
resultsCell = S.resultsCell;

opts = detectImportOptions('/Users/yoe/Documents/REPOS/eMove-playground/resources/stim_video_encoding_SINGLES.csv', ...
    'VariableNamingRule', 'preserve');
opts = setvartype(opts, intersect({'videoID','emotionTag','groupCode'}, opts.VariableNames, 'stable'), 'string');
T = readtable('/Users/yoe/Documents/REPOS/eMove-playground/resources/stim_video_encoding_SINGLES.csv', opts);
include = localToLogical(T.include);
vid = upper(strtrim(string(T.videoID)));
if ismember('isBaseline', T.Properties.VariableNames)
    isBase = localToLogical(T.isBaseline);
    vid(isBase) = "BASELINE";
end
isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
vid(isNum) = compose('%04d', str2double(vid(isNum)));
if ismember('groupCode', T.Properties.VariableNames)
    code = upper(strtrim(string(T.groupCode)));
else
    code = upper(strtrim(string(T.emotionTag)));
end
mapTbl = table(vid(include), code(include), 'VariableNames', {'videoID','emotion'});
mapTbl = unique(mapTbl, 'rows');

markerGroups = {'HEAD','UTORSO','LTORSO','UPPER_LIMB_L','UPPER_LIMB_R','WRIST_L','WRIST_R','LOWER_LIMB_L','LOWER_LIMB_R'};
emotions = setdiff(unique(mapTbl.emotion, 'stable'), ["BASELINE","0","AMUSEMENT",""]);

fprintf('Emotions used: %s\n', strjoin(cellstr(emotions), ', '));
fprintf('\nCounts by marker/emotion (pooled samples across subjects)\n');

for g = 1:numel(markerGroups)
    mg = markerGroups{g};
    fprintf('\n[%s]\n', mg);
    for e = 1:numel(emotions)
        emo = emotions(e);
        nImm = 0;
        nAll = 0;
        nRows = 0;
        for s = 1:numel(resultsCell)
            rc = resultsCell{s};
            if ~isfield(rc,'summaryTable') || isempty(rc.summaryTable), continue; end
            st = rc.summaryTable;
            if ~all(ismember({'videoID','markerGroup','speedArrayImmobile','speedArray'}, st.Properties.VariableNames))
                continue;
            end
            m = strcmp(string(st.markerGroup), mg);
            if ~any(m), continue; end
            vids = string(st.videoID);
            emoCol = strings(height(st),1);
            for r = 1:height(st)
                idx = find(mapTbl.videoID == vids(r), 1);
                if ~isempty(idx)
                    emoCol(r) = mapTbl.emotion(idx);
                end
            end
            rows = m & emoCol == emo;
            if ~any(rows), continue; end
            nRows = nRows + sum(rows);
            c1 = st.speedArrayImmobile(rows);
            c2 = st.speedArray(rows);
            for k = 1:numel(c1)
                if ~isempty(c1{k}), nImm = nImm + numel(c1{k}); end
                if ~isempty(c2{k}), nAll = nAll + numel(c2{k}); end
            end
        end
        fprintf('  %s: rows=%d immobileSamples=%d allSpeedSamples=%d\n', emo, nRows, nImm, nAll);
    end
end

function out = localToLogical(v)
if islogical(v), out = v; return; end
if isnumeric(v), out = v ~= 0; return; end
s = upper(strtrim(string(v)));
out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end
