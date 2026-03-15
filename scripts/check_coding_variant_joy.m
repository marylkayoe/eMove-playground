clearvars;
clc;

S = load('/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/legacy_chain_qc_20260311_160023/resultsCellSingles.mat');
rc = S.resultsCellSingles;

T = readtable('/Users/yoe/Documents/REPOS/eMove-playground/resources/stim_video_encoding_SINGLES.csv', ...
    'VariableNamingRule', 'preserve');
T = T(T.include == 1, :);

vid = upper(strtrim(string(T.videoID)));
isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
vid(isNum) = compose('%04d', str2double(vid(isNum)));
emo = upper(strtrim(string(T.emotionTag)));

C1 = table(vid, emo, 'VariableNames', {'videoID','groupCode'});
k1 = computeKsDistancesFromResultsCell(rc, C1, ...
    'speedField', 'speedArrayImmobile', ...
    'minSamplesPerCond', 200, ...
    'excludeBaseline', true);
m1 = strcmp(string(k1.markerGroup), 'HEAD') & strcmp(string(k1.pairLabel), 'FEAR-JOY');
fprintf('current coding HEAD FEAR-JOY D=%g delta=%g n=%d\n', ...
    median(k1.ksD(m1), 'omitnan'), median(k1.deltaMedian_sorted(m1), 'omitnan'), nnz(m1));

C2 = C1;
C2.groupCode(C2.videoID == "4903") = "X";
C2.groupCode(C2.videoID == "4902") = "JOY";
k2 = computeKsDistancesFromResultsCell(rc, C2, ...
    'speedField', 'speedArrayImmobile', ...
    'minSamplesPerCond', 200, ...
    'excludeBaseline', true);
m2 = strcmp(string(k2.markerGroup), 'HEAD') & strcmp(string(k2.pairLabel), 'FEAR-JOY');
fprintf('joy=4902 coding HEAD FEAR-JOY D=%g delta=%g n=%d\n', ...
    median(k2.ksD(m2), 'omitnan'), median(k2.deltaMedian_sorted(m2), 'omitnan'), nnz(m2));

