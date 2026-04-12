% run_emowear_regime_scatter_comparison.m
%
% Compare pre-walk vs locomotion scatter plots under explicit regime-based
% selection, with different summary domains:
%   1. dynamic -> dynamic
%   2. raw -> raw
%   3. dynamic -> raw
%
% Regime definitions:
% - pre-walk candidate window: [walkB - 5 s, walkB)
% - low-animation selector: rolling-motion < 40, min 0.5 s, max high gap 0.1 s
% - walking candidate window: [walkB, walkFinish]
% - sustained-walking selector: rolling-motion > 100, min 1.0 s, max low gap 0.25 s

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(repoRoot));
dataRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279';
matRoot = fullfile(dataRoot, 'mat_extracted', 'mat');

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_regime_scatter_comparison_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

variantSpecs = { ...
    struct('name', 'dynamic_to_dynamic', 'preField', 'preDynamicMedian', 'walkField', 'walkDynamicMedian', ...
           'preLabel', 'Pre-walk low-animation dynamic median', 'walkLabel', 'Walking dynamic median'), ...
    struct('name', 'raw_to_raw', 'preField', 'preRawMedian', 'walkField', 'walkRawMedian', ...
           'preLabel', 'Pre-walk low-animation raw median', 'walkLabel', 'Walking raw median'), ...
    struct('name', 'dynamic_to_raw', 'preField', 'preDynamicMedian', 'walkField', 'walkRawMedian', ...
           'preLabel', 'Pre-walk low-animation dynamic median', 'walkLabel', 'Walking raw median') ...
    };

d = dir(matRoot);
d = d([d.isdir]);
ids = string({d.name});
ids = ids(ids ~= "." & ids ~= "..");
ids = sort(ids);

rows = struct( ...
    'participantID', {}, ...
    'participantCode', {}, ...
    'seq', {}, ...
    'exp', {}, ...
    'prewalkStart', {}, ...
    'walkB', {}, ...
    'walkE', {}, ...
    'walkFinish', {}, ...
    'preCandidateN', {}, ...
    'preSelectedN', {}, ...
    'walkCandidateN', {}, ...
    'walkSelectedN', {}, ...
    'preLowAnimFrac', {}, ...
    'walkContinuousFrac', {}, ...
    'preDynamicMedian', {}, ...
    'preRawMedian', {}, ...
    'walkDynamicMedian', {}, ...
    'walkRawMedian', {});

for i = 1:numel(ids)
    participantID = char(ids(i));
    base = fullfile(matRoot, participantID);

    S = load(fullfile(base, 'signals.mat'));
    M = load(fullfile(base, 'markers.mat'));
    if ~isfield(S.signals, 'bh3') || ~isfield(S.signals.bh3, 'acc')
        continue;
    end
    if ~isfield(M.markers, 'phase2') || ~istable(M.markers.phase2)
        continue;
    end

    acc = S.signals.bh3.acc;
    phase2 = M.markers.phase2;
    if ~all(ismember({'timestamp','x','y','z'}, acc.Properties.VariableNames))
        continue;
    end

    t = double(acc.timestamp);
    x = double(acc.x);
    y = double(acc.y);
    z = double(acc.z);
    rawMag = sqrt(x.^2 + y.^2 + z.^2);
    motionMag = localRollingMotionMagnitude(t, x, y, z, 0.5);

    [lowMask, ~] = getLowAnimationFramesFromMotionMagnitude(motionMag, t, ...
        'threshold', 40, 'minLowDurationSec', 0.5, 'maxHighGapSec', 0.1);
    [walkMask, ~] = getContinuousWalkingFramesFromMotionMagnitude(motionMag, t, ...
        'threshold', 100, 'minWalkDurationSec', 1.0, 'maxLowGapSec', 0.25);

    for r = 1:height(phase2)
        walkB = localMaybeGetNumeric(phase2, 'walkB', r);
        walkE = localMaybeGetNumeric(phase2, 'walkE', r);
        walkFinish = localMaybeGetNumeric(phase2, 'walkFinish', r);
        if isnan(walkB) || isnan(walkE) || walkE <= walkB
            continue;
        end
        if ~isfinite(walkFinish) || walkFinish <= walkB
            walkFinish = walkE;
        end

        preStart = walkB - 5;
        preCandidate = t >= preStart & t < walkB;
        walkCandidate = t >= walkB & t <= walkFinish;
        if ~any(preCandidate) || ~any(walkCandidate)
            continue;
        end

        preSelected = preCandidate & lowMask;
        walkSelected = walkCandidate & walkMask;
        if ~any(isfinite(motionMag(preSelected))) || ~any(isfinite(motionMag(walkSelected)))
            continue;
        end

        row = struct();
        row.participantID = participantID;
        toks = regexp(participantID, '^(\d+)\-(.+)$', 'tokens', 'once');
        if isempty(toks)
            row.participantCode = participantID;
        else
            row.participantCode = char(string(toks{2}));
        end
        row.seq = localMaybeGetNumeric(phase2, 'seq', r);
        row.exp = localMaybeGetNumeric(phase2, 'exp', r);
        row.prewalkStart = preStart;
        row.walkB = walkB;
        row.walkE = walkE;
        row.walkFinish = walkFinish;
        row.preCandidateN = nnz(preCandidate);
        row.preSelectedN = nnz(preSelected);
        row.walkCandidateN = nnz(walkCandidate);
        row.walkSelectedN = nnz(walkSelected);
        row.preLowAnimFrac = nnz(preSelected) / nnz(preCandidate);
        row.walkContinuousFrac = nnz(walkSelected) / nnz(walkCandidate);
        row.preDynamicMedian = median(motionMag(preSelected), 'omitnan');
        row.preRawMedian = median(rawMag(preSelected), 'omitnan');
        row.walkDynamicMedian = median(motionMag(walkSelected), 'omitnan');
        row.walkRawMedian = median(rawMag(walkSelected), 'omitnan');
        rows(end+1, 1) = row; %#ok<AGROW>
    end
end

if isempty(rows)
    error('No usable rows were extracted.');
end

T = struct2table(rows);
writetable(T, fullfile(outDir, 'regime_features.csv'));

allStats = table();
for i = 1:numel(variantSpecs)
    spec = variantSpecs{i};
    x = T.(spec.preField);
    y = T.(spec.walkField);

    [rPearson, pPearson] = corr(x, y, 'Rows', 'complete', 'Type', 'Pearson');
    [rSpearman, pSpearman] = corr(x, y, 'Rows', 'complete', 'Type', 'Spearman');

    subjectTbl = localAggregateBySubject(T, spec.preField, spec.walkField);
    [rSubject, pSubject] = corr(subjectTbl.preValue, subjectTbl.walkValue, ...
        'Rows', 'complete', 'Type', 'Pearson');
    writetable(subjectTbl, fullfile(outDir, sprintf('subject_means_%s.csv', spec.name)));

    statsTbl = table( ...
        string(spec.name), height(T), numel(unique(string(T.participantID))), ...
        mean(T.preLowAnimFrac, 'omitnan'), mean(T.walkContinuousFrac, 'omitnan'), ...
        rPearson, pPearson, rSpearman, pSpearman, rSubject, pSubject, ...
        'VariableNames', {'variant','nRows','nParticipants','meanPreSelectedFrac','meanWalkSelectedFrac', ...
        'pearson_r','pearson_p','spearman_rho','spearman_p','subject_pearson_r','subject_pearson_p'});
    allStats = [allStats; statsTbl]; %#ok<AGROW>

    fig1 = figure('Color', 'w', 'Position', [100 100 820 640]);
    scatter(x, y, 18, [0.25 0.45 0.8], 'filled', ...
        'MarkerFaceAlpha', 0.45, 'MarkerEdgeAlpha', 0.45);
    grid on;
    xlabel(spec.preLabel);
    ylabel(spec.walkLabel);
    title(sprintf('%s | pooled episodes (r = %.3f, p = %.3g, n = %d)', ...
        spec.name, rPearson, pPearson, height(T)), 'Interpreter', 'none');
    hold on;
    localAddLeastSquaresLine(x, y);
    hold off;
    exportgraphics(fig1, fullfile(outDir, sprintf('pooled_scatter_%s.png', spec.name)), 'Resolution', 180);
    savefig(fig1, fullfile(outDir, sprintf('pooled_scatter_%s.fig', spec.name)));

    fig2 = figure('Color', 'w', 'Position', [140 120 820 640]);
    scatter(subjectTbl.preValue, subjectTbl.walkValue, 40, [0.8 0.3 0.25], 'filled', ...
        'MarkerFaceAlpha', 0.75, 'MarkerEdgeAlpha', 0.75);
    grid on;
    xlabel(['Participant mean ' lower(spec.preLabel)]);
    ylabel(['Participant mean ' lower(spec.walkLabel)]);
    title(sprintf('%s | participant means (r = %.3f, p = %.3g, n = %d)', ...
        spec.name, rSubject, pSubject, height(subjectTbl)), 'Interpreter', 'none');
    hold on;
    localAddLeastSquaresLine(subjectTbl.preValue, subjectTbl.walkValue);
    text(subjectTbl.preValue, subjectTbl.walkValue, subjectTbl.participantID, ...
        'FontSize', 7, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
    hold off;
    exportgraphics(fig2, fullfile(outDir, sprintf('subject_mean_scatter_%s.png', spec.name)), 'Resolution', 180);
    savefig(fig2, fullfile(outDir, sprintf('subject_mean_scatter_%s.fig', spec.name)));
end

writetable(allStats, fullfile(outDir, 'comparison_stats.csv'));
fprintf('Saved outputs to:\n%s\n', outDir);
disp(allStats);

function out = localMaybeGetNumeric(T, varName, rowIdx)
out = NaN;
if ismember(varName, T.Properties.VariableNames)
    out = double(T.(varName)(rowIdx));
end
end

function subjectTbl = localAggregateBySubject(T, preField, walkField)
subjectIDs = unique(string(T.participantID), 'stable');
rows = struct('participantID', {}, 'nSeq', {}, 'preValue', {}, 'walkValue', {});
for i = 1:numel(subjectIDs)
    mask = string(T.participantID) == subjectIDs(i);
    row = struct();
    row.participantID = char(subjectIDs(i));
    row.nSeq = nnz(mask);
    row.preValue = mean(T.(preField)(mask), 'omitnan');
    row.walkValue = mean(T.(walkField)(mask), 'omitnan');
    rows(end+1, 1) = row; %#ok<AGROW>
end
subjectTbl = struct2table(rows);
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
