% run_emowear_frontstb_regime_surveys.m
%
% STb analogue of the BH3 regime-based analyses:
% - front STb motion trace from lis2dw12 triad
% - 10x decimation before rolling-motion estimation
% - low-animation and sustained-walking masks using the same cleanup logic
% - baseline, clip-view, pre-walk, walking, and normalized summaries
% - association tests against valence and dominance

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(repoRoot));
matRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted/mat';

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_frontstb_regime_surveys_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

d = dir(matRoot);
d = d([d.isdir]);
ids = string({d.name});
ids = ids(ids ~= "." & ids ~= "..");
ids = sort(ids);

rows = [];
surveyRows = [];

for i = 1:numel(ids)
    participantID = char(ids(i));
    base = fullfile(matRoot, participantID);

    S = load(fullfile(base, 'signals.mat'));
    M = load(fullfile(base, 'markers.mat'));
    U = load(fullfile(base, 'surveys.mat'));
    if ~isfield(S.signals, 'front') || ~isfield(S.signals.front, 'acc')
        continue;
    end
    if ~isfield(M.markers, 'phase2') || ~istable(M.markers.phase2)
        continue;
    end
    if ~isfield(U, 'surveys') || ~istable(U.surveys)
        continue;
    end

    acc = S.signals.front.acc;
    needVars = {'timestamp','x1_lis2dw12','y1_lis2dw12','z1_lis2dw12'};
    if ~all(ismember(needVars, acc.Properties.VariableNames))
        continue;
    end

    surveys = U.surveys;
    keepSurveyVars = intersect({'seq','exp','valence','dominance','arousal','liking','familiarity'}, ...
        surveys.Properties.VariableNames, 'stable');
    surveys = surveys(:, keepSurveyVars);
    surveys.participantID = repmat(string(participantID), height(surveys), 1);
    surveyRows = [surveyRows; surveys]; %#ok<AGROW>

    t = double(acc.timestamp);
    x = double(acc.x1_lis2dw12);
    y = double(acc.y1_lis2dw12);
    z = double(acc.z1_lis2dw12);
    [t, x, y, z] = localDecimate4(t, x, y, z, 10);
    rawMag = sqrt(x.^2 + y.^2 + z.^2);
    motionMag = localRollingMotionMagnitude(t, x, y, z, 0.5);

    [lowMask, ~] = getLowAnimationFramesFromMotionMagnitude(motionMag, t, ...
        'threshold', 40, 'minLowDurationSec', 0.5, 'maxHighGapSec', 0.1);
    [walkMask, ~] = getContinuousWalkingFramesFromMotionMagnitude(motionMag, t, ...
        'threshold', 100, 'minWalkDurationSec', 1.0, 'maxLowGapSec', 0.25);

    phase2 = M.markers.phase2;
    for r = 1:height(phase2)
        preB = localMaybeGetNumeric(phase2, 'preB', r);
        vidB = localMaybeGetNumeric(phase2, 'vidB', r);
        surveyB = localMaybeGetNumeric(phase2, 'surveyB', r);
        walkB = localMaybeGetNumeric(phase2, 'walkB', r);
        walkFinish = localMaybeGetNumeric(phase2, 'walkFinish', r);
        walkE = localMaybeGetNumeric(phase2, 'walkE', r);
        if ~isfinite(preB) || ~isfinite(vidB) || vidB <= preB
            continue;
        end
        if ~isfinite(vidB) || ~isfinite(surveyB) || surveyB <= vidB
            continue;
        end
        if ~isfinite(walkB)
            continue;
        end
        if ~isfinite(walkFinish) || walkFinish <= walkB
            walkFinish = walkE;
        end
        if ~isfinite(walkFinish) || walkFinish <= walkB
            continue;
        end

        baselineCandidate = t >= preB & t < vidB;
        clipCandidate = t >= vidB & t < surveyB;
        preCandidate = t >= (walkB - 5) & t < walkB;
        walkCandidate = t >= walkB & t <= walkFinish;

        baselineSelected = baselineCandidate & lowMask;
        clipSelected = clipCandidate & lowMask;
        preSelected = preCandidate & lowMask;
        walkSelected = walkCandidate & walkMask;
        if ~any(baselineSelected) || ~any(clipSelected) || ~any(preSelected) || ~any(walkSelected)
            continue;
        end

        baselineDynamicMedian = median(motionMag(baselineSelected), 'omitnan');
        clipDynamicMedian = median(motionMag(clipSelected), 'omitnan');
        preDynamicMedian = median(motionMag(preSelected), 'omitnan');
        walkDynamicMedian = median(motionMag(walkSelected), 'omitnan');
        walkRawMedian = median(rawMag(walkSelected), 'omitnan');
        if ~isfinite(baselineDynamicMedian) || ~isfinite(clipDynamicMedian) || ~isfinite(preDynamicMedian) || ~isfinite(walkDynamicMedian)
            continue;
        end
        if preDynamicMedian <= 0 || baselineDynamicMedian <= 0
            continue;
        end

        rows = [rows; table( ...
            string(participantID), ...
            localMaybeGetNumeric(phase2, 'seq', r), ...
            localMaybeGetNumeric(phase2, 'exp', r), ...
            baselineDynamicMedian, ...
            clipDynamicMedian, ...
            preDynamicMedian, ...
            walkDynamicMedian, ...
            walkRawMedian, ...
            clipDynamicMedian - baselineDynamicMedian, ...
            clipDynamicMedian ./ baselineDynamicMedian, ...
            log(clipDynamicMedian ./ baselineDynamicMedian), ...
            clipDynamicMedian - preDynamicMedian, ...
            clipDynamicMedian ./ preDynamicMedian, ...
            log(clipDynamicMedian ./ preDynamicMedian), ...
            nnz(baselineSelected) / max(1, nnz(baselineCandidate)), ...
            nnz(clipSelected) / max(1, nnz(clipCandidate)), ...
            nnz(preSelected) / max(1, nnz(preCandidate)), ...
            nnz(walkSelected) / max(1, nnz(walkCandidate)), ...
            'VariableNames', {'participantID','seq','exp','baselineDynamicMedian','clipDynamicMedian','preDynamicMedian', ...
            'walkDynamicMedian','walkRawMedian','clipMinusBaseline','clipOverBaseline','logClipOverBaseline', ...
            'clipMinusPre','clipOverPre','logClipOverPre','baselineSelectedFrac','clipSelectedFrac','preSelectedFrac','walkSelectedFrac'})]; %#ok<AGROW>
    end
end

T = rows;
T.participantID = string(T.participantID);
surveyRows.participantID = string(surveyRows.participantID);
J = innerjoin(T, surveyRows, 'Keys', {'participantID','seq','exp'});
writetable(J, fullfile(outDir, 'frontstb_regime_joined.csv'));

stats = [];
tests = { ...
    struct('x','clipDynamicMedian','y','valence'), ...
    struct('x','clipDynamicMedian','y','dominance'), ...
    struct('x','clipMinusBaseline','y','valence'), ...
    struct('x','clipMinusBaseline','y','dominance'), ...
    struct('x','clipMinusPre','y','valence'), ...
    struct('x','clipMinusPre','y','dominance'), ...
    struct('x','baselineDynamicMedian','y','valence'), ...
    struct('x','baselineDynamicMedian','y','dominance'), ...
    struct('x','preDynamicMedian','y','walkDynamicMedian'), ...
    struct('x','walkDynamicMedian','y','valence'), ...
    struct('x','walkDynamicMedian','y','dominance') ...
    };

for i = 1:numel(tests)
    x = J.(tests{i}.x);
    y = J.(tests{i}.y);
    [rPearson, pPearson] = corr(x, y, 'Rows', 'complete', 'Type', 'Pearson');
    [rSpearman, pSpearman] = corr(x, y, 'Rows', 'complete', 'Type', 'Spearman');
    [rWithin, pWithin] = localWithinSubjectCorr(J, tests{i}.x, tests{i}.y);
    stats = [stats; table(string(tests{i}.x), string(tests{i}.y), height(J), ...
        rPearson, pPearson, rSpearman, pSpearman, rWithin, pWithin, ...
        mean(J.baselineSelectedFrac, 'omitnan'), mean(J.clipSelectedFrac, 'omitnan'), mean(J.preSelectedFrac, 'omitnan'), mean(J.walkSelectedFrac, 'omitnan'), ...
        'VariableNames', {'motionMetric','ratingMetric','nRows','pearson_r','pearson_p','spearman_rho','spearman_p','withinSubject_r','withinSubject_p','meanBaselineSelectedFrac','meanClipSelectedFrac','meanPreSelectedFrac','meanWalkSelectedFrac'})]; %#ok<AGROW>

    fig = figure('Color', 'w', 'Position', [100 100 820 640]);
    scatter(x, y, 18, [0.25 0.45 0.8], 'filled', 'MarkerFaceAlpha', 0.4, 'MarkerEdgeAlpha', 0.4);
    grid on;
    xlabel(tests{i}.x, 'Interpreter', 'none');
    ylabel(tests{i}.y, 'Interpreter', 'none');
    title(sprintf('front STb %s vs %s (r = %.3f, p = %.3g, within-r = %.3f, p = %.3g)', ...
        tests{i}.x, tests{i}.y, rPearson, pPearson, rWithin, pWithin), 'Interpreter', 'none');
    hold on;
    localAddLeastSquaresLine(x, y);
    hold off;
    exportgraphics(fig, fullfile(outDir, sprintf('scatter_%s_vs_%s.png', tests{i}.x, tests{i}.y)), 'Resolution', 180);
    savefig(fig, fullfile(outDir, sprintf('scatter_%s_vs_%s.fig', tests{i}.x, tests{i}.y)));
end

writetable(stats, fullfile(outDir, 'frontstb_regime_stats.csv'));
fprintf('Saved outputs to:\n%s\n', outDir);
disp(stats);

function [r, p] = localWithinSubjectCorr(T, xField, yField)
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

function localAddLeastSquaresLine(x, y)
mask = ~isnan(x) & ~isnan(y);
x = x(mask);
y = y(mask);
if numel(x) < 2
    return;
end
p = polyfit(x, y, 1);
xx = linspace(min(x), max(x), 200);
yy = polyval(p, xx);
plot(xx, yy, 'k-', 'LineWidth', 1.5);
end

function [tOut, xOut, yOut, zOut] = localDecimate4(t, x, y, z, factor)
idx = 1:factor:numel(t);
tOut = t(idx);
xOut = x(idx);
yOut = y(idx);
zOut = z(idx);
end
