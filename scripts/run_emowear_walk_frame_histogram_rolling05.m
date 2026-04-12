% run_emowear_walk_frame_histogram_rolling05.m
%
% Pool all per-frame BH3 rolling-motion values from the walk windows
% [walkB, walkE] across all participants/sequences, then visualize the
% distribution to guide a continuous-walking threshold.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279';
matRoot = fullfile(dataRoot, 'mat_extracted', 'mat');

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_walk_frame_histogram_rolling05_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

d = dir(matRoot);
d = d([d.isdir]);
ids = string({d.name});
ids = ids(ids ~= "." & ids ~= "..");
ids = sort(ids);

allVals = [];
rowSummaries = struct('participantID', {}, 'seq', {}, 'exp', {}, 'nSamples', {}, ...
    'medianVal', {}, 'maxVal', {});

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
    motionMag = localRollingMotionMagnitude(t, x, y, z, 0.5);

    for r = 1:height(phase2)
        walkB = localMaybeGetNumeric(phase2, 'walkB', r);
        walkE = localMaybeGetNumeric(phase2, 'walkE', r);
        if isnan(walkB) || isnan(walkE) || walkE <= walkB
            continue;
        end

        walkMask = t >= walkB & t <= walkE;
        if ~any(walkMask)
            continue;
        end

        vals = motionMag(walkMask);
        vals = vals(isfinite(vals));
        if isempty(vals)
            continue;
        end

        allVals = [allVals; vals(:)]; %#ok<AGROW>

        row = struct();
        row.participantID = participantID;
        row.seq = localMaybeGetNumeric(phase2, 'seq', r);
        row.exp = localMaybeGetNumeric(phase2, 'exp', r);
        row.nSamples = numel(vals);
        row.medianVal = median(vals, 'omitnan');
        row.maxVal = max(vals, [], 'omitnan');
        rowSummaries(end+1, 1) = row; %#ok<AGROW>
    end
end

if isempty(allVals)
    error('No walk rolling-motion values were collected.');
end

q = quantile(allVals, [0.01 0.05 0.1 0.25 0.5 0.75 0.9 0.95 0.97 0.98 0.99]);
summaryTbl = table( ...
    ["n_values"; "p01"; "p05"; "p10"; "p25"; "median"; "p75"; "p90"; "p95"; "p97"; "p98"; "p99"; "max"], ...
    [numel(allVals); q(:); max(allVals)], ...
    'VariableNames', {'metric', 'value'});
writetable(summaryTbl, fullfile(outDir, 'distribution_summary.csv'));
writetable(struct2table(rowSummaries), fullfile(outDir, 'walk_window_summaries.csv'));

edges = 0:5:400;
fig1 = figure('Color', 'w', 'Position', [100 100 920 640]);
histogram(allVals, edges, 'FaceColor', [0.2 0.45 0.8], 'EdgeColor', 'none');
grid on;
xlabel('Per-frame rolling-motion magnitude (BH3, 0.5 s window)');
ylabel('Count');
title(sprintf('All walk frames pooled (n = %d)', numel(allVals)));
hold on;
pctLabels = [10 25 50 75 90 95];
qPlot = [q(3) q(4) q(5) q(6) q(7) q(8)];
for i = 1:numel(qPlot)
    xline(qPlot(i), '--', sprintf('p%d = %.1f', pctLabels(i), qPlot(i)), ...
        'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'middle');
end
hold off;
exportgraphics(fig1, fullfile(outDir, 'walk_frame_histogram.png'), 'Resolution', 180);

fineEdges = 0:2:300;
figFine = figure('Color', 'w', 'Position', [120 120 920 640]);
histogram(allVals, fineEdges, 'FaceColor', [0.2 0.45 0.8], 'EdgeColor', 'none');
grid on;
xlabel('Per-frame rolling-motion magnitude (BH3, 0.5 s window)');
ylabel('Count');
title(sprintf('All walk frames pooled, fine bins (n = %d)', numel(allVals)));
xlim([0 250]);
hold on;
for i = 1:numel(qPlot)
    xline(qPlot(i), '--', sprintf('p%d = %.1f', pctLabels(i), qPlot(i)), ...
        'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'middle');
end
hold off;
exportgraphics(figFine, fullfile(outDir, 'walk_frame_histogram_finebins.png'), 'Resolution', 180);

fig2 = figure('Color', 'w', 'Position', [140 140 920 640]);
[f, xvals] = ecdf(allVals);
plot(xvals, f, 'LineWidth', 1.5, 'Color', [0.2 0.45 0.8]);
grid on;
xlabel('Per-frame rolling-motion magnitude (BH3, 0.5 s window)');
ylabel('Cumulative fraction');
title('ECDF of pooled walk frame values');
ylim([0 1]);
exportgraphics(fig2, fullfile(outDir, 'walk_frame_ecdf.png'), 'Resolution', 180);

fprintf('Saved outputs to:\n%s\n', outDir);
disp(summaryTbl);

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
