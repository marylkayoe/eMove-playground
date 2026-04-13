% run_emowear_frontstb_phase_histograms.m
%
% Compute sampled pooled dynamic-motion distributions for the front STb
% accelerometer across task phases. This is the STb analogue of the earlier
% BH3 threshold-inspection step and is intended to support regime threshold
% selection from the data rather than from imported cutoffs.
%
% Note:
% The front STb stream is much denser than BH3. To keep the threshold
% inspection lightweight and responsive, this script samples the motion
% trace at a fixed stride within each phase instead of pooling every raw
% frame.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(repoRoot));
matRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted/mat';

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_frontstb_phase_histograms_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

d = dir(matRoot);
d = d([d.isdir]);
ids = string({d.name});
ids = ids(ids ~= "." & ids ~= "..");
ids = sort(ids);

valsBaseline = [];
valsVideo = [];
valsPost = [];
valsWalking = [];
sampleStride = 20;

summaryRows = [];

for i = 1:numel(ids)
    participantID = char(ids(i));
    base = fullfile(matRoot, participantID);

    S = load(fullfile(base, 'signals.mat'));
    M = load(fullfile(base, 'markers.mat'));
    if ~isfield(S.signals, 'front') || ~isfield(S.signals.front, 'acc')
        continue;
    end
    if ~isfield(M.markers, 'phase2') || ~istable(M.markers.phase2)
        continue;
    end

    acc = S.signals.front.acc;
    needVars = {'timestamp','x1_lis2dw12','y1_lis2dw12','z1_lis2dw12'};
    if ~all(ismember(needVars, acc.Properties.VariableNames))
        continue;
    end

    t = double(acc.timestamp);
    x = double(acc.x1_lis2dw12);
    y = double(acc.y1_lis2dw12);
    z = double(acc.z1_lis2dw12);
    [t, x, y, z] = localDecimate4(t, x, y, z, 10);
    motionMag = localRollingMotionMagnitude(t, x, y, z, 0.5);

    phase2 = M.markers.phase2;
    for r = 1:height(phase2)
        preB = localMaybeGetNumeric(phase2, 'preB', r);
        vidB = localMaybeGetNumeric(phase2, 'vidB', r);
        postB = localMaybeGetNumeric(phase2, 'postB', r);
        surveyB = localMaybeGetNumeric(phase2, 'surveyB', r);
        walkB = localMaybeGetNumeric(phase2, 'walkB', r);
        walkFinish = localMaybeGetNumeric(phase2, 'walkFinish', r);
        walkE = localMaybeGetNumeric(phase2, 'walkE', r);

        if isfinite(preB) && isfinite(vidB) && vidB > preB
            mask = t >= preB & t < vidB;
            valsBaseline = [valsBaseline; localSampleVec(motionMag(mask), sampleStride)]; %#ok<AGROW>
        end
        if isfinite(vidB) && isfinite(postB) && postB > vidB
            mask = t >= vidB & t < postB;
            valsVideo = [valsVideo; localSampleVec(motionMag(mask), sampleStride)]; %#ok<AGROW>
        end
        if isfinite(postB) && isfinite(surveyB) && surveyB > postB
            mask = t >= postB & t < surveyB;
            valsPost = [valsPost; localSampleVec(motionMag(mask), sampleStride)]; %#ok<AGROW>
        end
        if isfinite(walkB)
            if ~isfinite(walkFinish) || walkFinish <= walkB
                walkFinish = walkE;
            end
            if isfinite(walkFinish) && walkFinish > walkB
                mask = t >= walkB & t <= walkFinish;
                valsWalking = [valsWalking; localSampleVec(motionMag(mask), sampleStride)]; %#ok<AGROW>
            end
        end
    end
end

phaseSpecs = { ...
    'baseline', valsBaseline, [0.30 0.45 0.80]; ...
    'video', valsVideo, [0.20 0.55 0.35]; ...
    'post', valsPost, [0.80 0.45 0.20]; ...
    'walking', valsWalking, [0.75 0.25 0.25] ...
    };

for i = 1:size(phaseSpecs, 1)
    phaseName = string(phaseSpecs{i,1});
    vals = phaseSpecs{i,2};
    vals = vals(isfinite(vals));
    summaryRows = [summaryRows; table( ...
        phaseName, numel(vals), ...
        mean(vals, 'omitnan'), std(vals, 'omitnan'), median(vals, 'omitnan'), ...
        prctile(vals, 75), prctile(vals, 90), prctile(vals, 95), prctile(vals, 99), max(vals), ...
        'VariableNames', {'phase','nFrames','mean','std','median','p75','p90','p95','p99','max'})]; %#ok<AGROW>
end

writetable(summaryRows, fullfile(outDir, 'frontstb_phase_distribution_summary.csv'));

fig1 = figure('Color', 'w', 'Position', [80 80 1100 760]);
tiledlayout(fig1, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:size(phaseSpecs, 1)
    nexttile;
    vals = phaseSpecs{i,2};
    vals = vals(isfinite(vals));
    histogram(vals, 'BinWidth', 1, 'FaceColor', phaseSpecs{i,3}, 'EdgeColor', 'none');
    grid on;
    title(sprintf('%s | median %.2f | p95 %.2f', phaseSpecs{i,1}, median(vals), prctile(vals,95)));
    xlabel('Front STb rolling-motion magnitude');
    ylabel('Frame count');
    xlim([0 max(100, min(500, prctile(vals, 99.9) * 1.05))]);
end
exportgraphics(fig1, fullfile(outDir, 'frontstb_phase_histograms.png'), 'Resolution', 180);
savefig(fig1, fullfile(outDir, 'frontstb_phase_histograms.fig'));

fig2 = figure('Color', 'w', 'Position', [100 100 980 620]);
hold on;
for i = 1:size(phaseSpecs, 1)
    vals = phaseSpecs{i,2};
    vals = vals(isfinite(vals));
    [f, x] = ecdf(vals);
    plot(x, f, 'LineWidth', 2.0, 'Color', phaseSpecs{i,3}, 'DisplayName', phaseSpecs{i,1});
end
grid on;
xlabel('Front STb rolling-motion magnitude');
ylabel('ECDF');
legend('Location', 'southeast');
title('Front STb phase ECDFs');
hold off;
exportgraphics(fig2, fullfile(outDir, 'frontstb_phase_ecdfs.png'), 'Resolution', 180);
savefig(fig2, fullfile(outDir, 'frontstb_phase_ecdfs.fig'));

fprintf('Saved outputs to:\n%s\n', outDir);
disp(summaryRows);

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

function y = localSampleVec(x, stride)
x = x(:);
if isempty(x)
    y = x;
    return;
end
y = x(1:stride:end);
end

function [tOut, xOut, yOut, zOut] = localDecimate4(t, x, y, z, factor)
idx = 1:factor:numel(t);
tOut = t(idx);
xOut = x(idx);
yOut = y(idx);
zOut = z(idx);
end
