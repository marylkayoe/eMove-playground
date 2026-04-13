% run_emowear_clipview_motion_vs_ratings_survey.m
%
% Join low-animation clip-viewing motion features to subject survey ratings
% and test whether clip-viewing motion magnitude correlates with valence
% and dominance.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(repoRoot));
dataRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted/mat';

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_clipview_motion_vs_ratings_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

d = dir(dataRoot);
d = d([d.isdir]);
ids = string({d.name});
ids = ids(ids ~= "." & ids ~= "..");
ids = sort(ids);

motionRows = [];
surveyRows = [];

for i = 1:numel(ids)
    participantID = char(ids(i));
    base = fullfile(dataRoot, participantID);

    Sig = load(fullfile(base, 'signals.mat'));
    Mark = load(fullfile(base, 'markers.mat'));
    Surv = load(fullfile(base, 'surveys.mat'));
    if ~isfield(Sig.signals, 'bh3') || ~isfield(Sig.signals.bh3, 'acc')
        continue;
    end
    if ~isfield(Mark.markers, 'phase2') || ~istable(Mark.markers.phase2)
        continue;
    end
    if ~isfield(Surv, 'surveys') || ~istable(Surv.surveys)
        continue;
    end

    acc = Sig.signals.bh3.acc;
    phase2 = Mark.markers.phase2;
    surveys = Surv.surveys;
    if ~all(ismember({'timestamp','x','y','z'}, acc.Properties.VariableNames))
        continue;
    end
    if ~all(ismember({'seq','exp','valence','dominance'}, surveys.Properties.VariableNames))
        continue;
    end

    surveys.participantID = repmat(string(participantID), height(surveys), 1);
    keepSurveyVars = intersect({'participantID','seq','exp','valence','dominance','arousal','liking','familiarity'}, ...
        surveys.Properties.VariableNames, 'stable');
    surveyRows = [surveyRows; surveys(:, keepSurveyVars)]; %#ok<AGROW>

    t = double(acc.timestamp);
    x = double(acc.x);
    y = double(acc.y);
    z = double(acc.z);
    motionMag = localRollingMotionMagnitude(t, x, y, z, 0.5);
    [lowMask, ~] = getLowAnimationFramesFromMotionMagnitude(motionMag, t, ...
        'threshold', 40, 'minLowDurationSec', 0.5, 'maxHighGapSec', 0.1);

    for r = 1:height(phase2)
        vidB = localMaybeGetNumeric(phase2, 'vidB', r);
        surveyB = localMaybeGetNumeric(phase2, 'surveyB', r);
        if ~isfinite(vidB) || ~isfinite(surveyB) || surveyB <= vidB
            continue;
        end

        clipCandidate = t >= vidB & t < surveyB;
        clipSelected = clipCandidate & lowMask;
        if ~any(clipSelected)
            continue;
        end

        motionRows = [motionRows; table( ...
            string(participantID), ...
            localMaybeGetNumeric(phase2, 'seq', r), ...
            localMaybeGetNumeric(phase2, 'exp', r), ...
            median(motionMag(clipSelected), 'omitnan'), ...
            nnz(clipSelected) / max(1, nnz(clipCandidate)), ...
            nnz(clipCandidate), ...
            'VariableNames', {'participantID','seq','exp','clipDynamicMedian','clipSelectedFrac','clipCandidateSamples'})]; %#ok<AGROW>
    end
end

surveyRows.participantID = string(surveyRows.participantID);
motionRows.participantID = string(motionRows.participantID);
J = innerjoin(motionRows, surveyRows, 'Keys', {'participantID','seq','exp'});
writetable(J, fullfile(outDir, 'clipview_motion_ratings_joined.csv'));

stats = [];
tests = { ...
    struct('x','clipDynamicMedian','y','valence'), ...
    struct('x','clipDynamicMedian','y','dominance') ...
    };

for i = 1:numel(tests)
    x = J.(tests{i}.x);
    y = J.(tests{i}.y);
    [rPearson, pPearson] = corr(x, y, 'Rows', 'complete', 'Type', 'Pearson');
    [rSpearman, pSpearman] = corr(x, y, 'Rows', 'complete', 'Type', 'Spearman');
    [rWithin, pWithin] = localWithinSubjectCorr(J, tests{i}.x, tests{i}.y);
    stats = [stats; table(string(tests{i}.x), string(tests{i}.y), height(J), ...
        rPearson, pPearson, rSpearman, pSpearman, rWithin, pWithin, ...
        mean(J.clipSelectedFrac, 'omitnan'), ...
        'VariableNames', {'motionMetric','ratingMetric','nRows','pearson_r','pearson_p','spearman_rho','spearman_p','withinSubject_r','withinSubject_p','meanSelectedFrac'})]; %#ok<AGROW>

    fig = figure('Color', 'w', 'Position', [100 100 820 640]);
    scatter(x, y, 18, [0.25 0.45 0.8], 'filled', 'MarkerFaceAlpha', 0.4, 'MarkerEdgeAlpha', 0.4);
    grid on;
    xlabel(tests{i}.x, 'Interpreter', 'none');
    ylabel(tests{i}.y, 'Interpreter', 'none');
    title(sprintf('%s vs %s | clip-view low-animation (r = %.3f, p = %.3g, within-r = %.3f, p = %.3g)', ...
        tests{i}.x, tests{i}.y, rPearson, pPearson, rWithin, pWithin), 'Interpreter', 'none');
    hold on;
    localAddLeastSquaresLine(x, y);
    hold off;
    exportgraphics(fig, fullfile(outDir, sprintf('scatter_%s_vs_%s.png', tests{i}.x, tests{i}.y)), 'Resolution', 180);
    savefig(fig, fullfile(outDir, sprintf('scatter_%s_vs_%s.fig', tests{i}.x, tests{i}.y)));
end
writetable(stats, fullfile(outDir, 'clipview_motion_rating_stats.csv'));

clipAgg = groupsummary(J, 'exp', 'mean', {'clipDynamicMedian','valence','dominance'});
writetable(clipAgg, fullfile(outDir, 'clipview_mean_motion_ratings.csv'));

clipStats = [];
clipPairs = { ...
    {'mean_clipDynamicMedian','mean_valence'}, ...
    {'mean_clipDynamicMedian','mean_dominance'} ...
    };
for i = 1:numel(clipPairs)
    x = clipAgg.(clipPairs{i}{1});
    y = clipAgg.(clipPairs{i}{2});
    [rPearson, pPearson] = corr(x, y, 'Rows', 'complete', 'Type', 'Pearson');
    [rSpearman, pSpearman] = corr(x, y, 'Rows', 'complete', 'Type', 'Spearman');
    clipStats = [clipStats; table(string(clipPairs{i}{1}), string(clipPairs{i}{2}), height(clipAgg), ...
        rPearson, pPearson, rSpearman, pSpearman, ...
        'VariableNames', {'motionMetric','ratingMetric','nClips','pearson_r','pearson_p','spearman_rho','spearman_p'})]; %#ok<AGROW>
end
writetable(clipStats, fullfile(outDir, 'clipview_mean_motion_rating_stats.csv'));

figFrac = figure('Color', 'w', 'Position', [120 120 760 520]);
histogram(J.clipSelectedFrac, 20, 'FaceColor', [0.2 0.55 0.35], 'EdgeColor', 'none');
grid on;
xlabel('Low-animation fraction within vidB -> surveyB');
ylabel('Episode count');
title(sprintf('Clip-view low-animation retention (mean = %.3f)', mean(J.clipSelectedFrac, 'omitnan')));
exportgraphics(figFrac, fullfile(outDir, 'clipview_selected_fraction_histogram.png'), 'Resolution', 180);
savefig(figFrac, fullfile(outDir, 'clipview_selected_fraction_histogram.fig'));

disp(stats);
disp(clipStats);
fprintf('Saved outputs to:\n%s\n', outDir);

function [r, p] = localWithinSubjectCorr(T, xField, yField)
subjectIDs = unique(string(T.participantID), 'stable');
xAll = [];
yAll = [];
for i = 1:numel(subjectIDs)
    mask = string(T.participantID) == subjectIDs(i);
    x = T.(xField)(mask);
    y = T.(yField)(mask);
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
if numel(timeVec) < 5
    motionMag = nan(size(timeVec));
    return;
end
dt = diff(timeVec);
dt = dt(isfinite(dt) & dt > 0);
if isempty(dt)
    motionMag = nan(size(timeVec));
    return;
end
sampleRate = 1 / median(dt, 'omitnan');
if ~isfinite(sampleRate) || sampleRate <= 0
    motionMag = nan(size(timeVec));
    return;
end
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
if ~any(finiteMask)
    out = nan(size(x));
    return;
end
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
