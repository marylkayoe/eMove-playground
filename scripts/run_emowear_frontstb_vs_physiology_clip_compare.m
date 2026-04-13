% run_emowear_frontstb_vs_physiology_clip_compare.m
%
% Compare the front STb clip-view low-animation motion effect against
% simple physiology summaries extracted over the same clip-view window
% (vidB -> surveyB).

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(repoRoot));
matRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted/mat';

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_frontstb_vs_physiology_clip_compare_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

d = dir(matRoot);
d = d([d.isdir]);
ids = string({d.name});
ids = ids(ids ~= "." & ids ~= "..");
ids = sort(ids);

rows = [];

for i = 1:numel(ids)
    participantID = char(ids(i));
    base = fullfile(matRoot, participantID);

    S = load(fullfile(base, 'signals.mat'));
    M = load(fullfile(base, 'markers.mat'));
    U = load(fullfile(base, 'surveys.mat'));
    if ~isfield(M.markers, 'phase2') || ~istable(M.markers.phase2)
        continue;
    end
    if ~isfield(U, 'surveys') || ~istable(U.surveys)
        continue;
    end

    phase2 = M.markers.phase2;
    surveys = U.surveys;
    surveyKeep = intersect({'seq','exp','valence','dominance','arousal','liking','familiarity'}, surveys.Properties.VariableNames, 'stable');
    surveys = surveys(:, surveyKeep);
    surveys.participantID = repmat(string(participantID), height(surveys), 1);

    hasFront = isfield(S.signals, 'front') && isfield(S.signals.front, 'acc');
    if ~hasFront
        continue;
    end
    acc = S.signals.front.acc;
    needVars = {'timestamp','x1_lis2dw12','y1_lis2dw12','z1_lis2dw12'};
    if ~all(ismember(needVars, acc.Properties.VariableNames))
        continue;
    end
    tFront = double(acc.timestamp);
    x = double(acc.x1_lis2dw12);
    y = double(acc.y1_lis2dw12);
    z = double(acc.z1_lis2dw12);
    [tFront, x, y, z] = localDecimate4(tFront, x, y, z, 10);
    frontMotion = localRollingMotionMagnitude(tFront, x, y, z, 0.5);
    [frontLowMask, ~] = getLowAnimationFramesFromMotionMagnitude(frontMotion, tFront, ...
        'threshold', 40, 'minLowDurationSec', 0.5, 'maxHighGapSec', 0.1);

    e4eda = localGetValueTrace(S.signals, 'e4', 'eda');
    e4hr = localGetValueTrace(S.signals, 'e4', 'hr');
    e4skt = localGetValueTrace(S.signals, 'e4', 'skt');
    bh3br = localGetValueTrace(S.signals, 'bh3', 'br');
    bh3hr = localGetValueTrace(S.signals, 'bh3', 'hr');

    participantRows = [];
    for r = 1:height(phase2)
        vidB = localMaybeGetNumeric(phase2, 'vidB', r);
        surveyB = localMaybeGetNumeric(phase2, 'surveyB', r);
        if ~isfinite(vidB) || ~isfinite(surveyB) || surveyB <= vidB
            continue;
        end

        clipMaskFront = tFront >= vidB & tFront < surveyB;
        clipMaskFrontLow = clipMaskFront & frontLowMask;
        if ~any(clipMaskFrontLow)
            continue;
        end

        row = table();
        row.participantID = string(participantID);
        row.seq = localMaybeGetNumeric(phase2, 'seq', r);
        row.exp = localMaybeGetNumeric(phase2, 'exp', r);
        row.clipDynamicMedian = median(frontMotion(clipMaskFrontLow), 'omitnan');
        row.frontClipSelectedFrac = nnz(clipMaskFrontLow) / max(1, nnz(clipMaskFront));

        row.e4_eda_mean = localWindowMean(e4eda, vidB, surveyB);
        row.e4_eda_std = localWindowStd(e4eda, vidB, surveyB);
        row.e4_hr_mean = localWindowMean(e4hr, vidB, surveyB);
        row.e4_skt_mean = localWindowMean(e4skt, vidB, surveyB);
        row.bh3_br_mean = localWindowMean(bh3br, vidB, surveyB);
        row.bh3_hr_mean = localWindowMean(bh3hr, vidB, surveyB);

        participantRows = [participantRows; row]; %#ok<AGROW>
    end

    if ~isempty(participantRows)
        participantRows = innerjoin(participantRows, surveys, ...
            'Keys', {'participantID','seq','exp'});
        rows = [rows; participantRows]; %#ok<AGROW>
    end
end

J = rows;
writetable(J, fullfile(outDir, 'frontstb_vs_physiology_joined.csv'));

metrics = { ...
    'clipDynamicMedian', ...
    'e4_eda_mean', ...
    'e4_eda_std', ...
    'e4_hr_mean', ...
    'e4_skt_mean', ...
    'bh3_br_mean', ...
    'bh3_hr_mean' ...
    };
ratings = {'valence','dominance','arousal','liking','familiarity'};

stats = [];
for i = 1:numel(metrics)
    for j = 1:numel(ratings)
        x = J.(metrics{i});
        y = J.(ratings{j});
        keep = isfinite(x) & isfinite(y);
        if nnz(keep) < 20
            continue;
        end
        [rPearson, pPearson] = corr(x(keep), y(keep), 'Rows', 'complete', 'Type', 'Pearson');
        [rSpearman, pSpearman] = corr(x(keep), y(keep), 'Rows', 'complete', 'Type', 'Spearman');
        [rWithin, pWithin, nWithin] = localWithinSubjectCorr(J, metrics{i}, ratings{j});
        stats = [stats; table(string(metrics{i}), string(ratings{j}), nnz(keep), ...
            rPearson, pPearson, rSpearman, pSpearman, rWithin, pWithin, nWithin, ...
            'VariableNames', {'metric','rating','nRows','pearson_r','pearson_p','spearman_rho','spearman_p','withinSubject_r','withinSubject_p','withinRows'})]; %#ok<AGROW>
    end
end
writetable(stats, fullfile(outDir, 'frontstb_vs_physiology_stats.csv'));

valenceStats = stats(stats.rating == "valence", :);
[~, order] = sort(abs(valenceStats.withinSubject_r), 'descend');
valenceStats = valenceStats(order, :);
writetable(valenceStats, fullfile(outDir, 'frontstb_vs_physiology_valence_ranked.csv'));

fig = figure('Color', 'w', 'Position', [100 100 920 620]);
bar(categorical(valenceStats.metric), valenceStats.withinSubject_r, 'FaceColor', [0.30 0.48 0.82]);
grid on;
ylabel('Within-subject Pearson r with valence');
title('Clip-window within-subject associations with valence');
xtickangle(30);
exportgraphics(fig, fullfile(outDir, 'within_subject_valence_comparison.png'), 'Resolution', 180);
savefig(fig, fullfile(outDir, 'within_subject_valence_comparison.fig'));

disp(valenceStats);
fprintf('Saved outputs to:\n%s\n', outDir);

function trace = localGetValueTrace(signalsStruct, deviceName, signalName)
trace = struct('timestamp', [], 'value', []);
if ~isfield(signalsStruct, deviceName)
    return;
end
dev = signalsStruct.(deviceName);
if ~isfield(dev, signalName)
    return;
end
T = dev.(signalName);
if ~istable(T) || ~all(ismember({'timestamp','value'}, T.Properties.VariableNames))
    return;
end
trace.timestamp = double(T.timestamp);
trace.value = double(T.value);
end

function m = localWindowMean(trace, tStart, tEnd)
m = NaN;
if isempty(trace.timestamp)
    return;
end
mask = trace.timestamp >= tStart & trace.timestamp < tEnd;
if ~any(mask)
    return;
end
m = mean(trace.value(mask), 'omitnan');
end

function s = localWindowStd(trace, tStart, tEnd)
s = NaN;
if isempty(trace.timestamp)
    return;
end
mask = trace.timestamp >= tStart & trace.timestamp < tEnd;
if nnz(mask) < 2
    return;
end
s = std(trace.value(mask), 0, 'omitnan');
end

function [r, p, nRows] = localWithinSubjectCorr(T, xField, yField)
subjectIDs = unique(string(T.participantID), 'stable');
xAll = [];
yAll = [];
for i = 1:numel(subjectIDs)
    mask = string(T.participantID) == subjectIDs(i);
    x = T.(xField)(mask);
    y = T.(yField)(mask);
    keep = isfinite(x) & isfinite(y);
    x = x(keep);
    y = y(keep);
    if numel(x) < 2
        continue;
    end
    x = x - mean(x, 'omitnan');
    y = y - mean(y, 'omitnan');
    xAll = [xAll; x]; %#ok<AGROW>
    yAll = [yAll; y]; %#ok<AGROW>
end
nRows = numel(xAll);
if nRows < 3
    r = NaN;
    p = NaN;
    return;
end
[r, p] = corr(xAll, yAll, 'Rows', 'complete', 'Type', 'Pearson');
end

function out = localMaybeGetNumeric(T, varName, rowIdx)
out = NaN;
if ismember(varName, T.Properties.VariableNames)
    out = double(T.(varName)(rowIdx));
end
end

function motionMag = localRollingMotionMagnitude(timeVec, X, Y, Z, winSec)
dt = diff(timeVec);
dt = dt(isfinite(dt) & dt > 0);
if isempty(dt)
    motionMag = nan(size(timeVec));
    return;
end
sampleRate = 1 / median(dt, 'omitnan');
winSamples = max(5, round(winSec * sampleRate));
if mod(winSamples, 2) == 0
    winSamples = winSamples + 1;
end
xStd = localMovStdNanSafe(X, winSamples);
yStd = localMovStdNanSafe(Y, winSamples);
zStd = localMovStdNanSafe(Z, winSamples);
motionMag = sqrt(xStd.^2 + yStd.^2 + zStd.^2);
end

function out = localMovStdNanSafe(x, winSamples)
x = double(x);
finiteMask = isfinite(x);
xFilled = x;
xFilled(~finiteMask) = interp1(find(finiteMask), x(finiteMask), find(~finiteMask), 'linear', 'extrap');
out = movstd(xFilled, winSamples, 0, 'omitnan', 'Endpoints', 'shrink');
out(~finiteMask) = nan;
end

function [tOut, xOut, yOut, zOut] = localDecimate4(t, x, y, z, factor)
idx = 1:factor:numel(t);
tOut = t(idx);
xOut = x(idx);
yOut = y(idx);
zOut = z(idx);
end
