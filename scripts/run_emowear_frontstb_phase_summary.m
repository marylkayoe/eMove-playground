% run_emowear_frontstb_phase_summary.m
%
% Fast numeric summary of front STb rolling-motion distributions by phase.
% This is intended for threshold calibration before any heavier figure pass.

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(repoRoot));
matRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted/mat';

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_frontstb_phase_summary_' runStamp]);
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
            valsBaseline = [valsBaseline; localSampleVec(motionMag(t >= preB & t < vidB), sampleStride)]; %#ok<AGROW>
        end
        if isfinite(vidB) && isfinite(postB) && postB > vidB
            valsVideo = [valsVideo; localSampleVec(motionMag(t >= vidB & t < postB), sampleStride)]; %#ok<AGROW>
        end
        if isfinite(postB) && isfinite(surveyB) && surveyB > postB
            valsPost = [valsPost; localSampleVec(motionMag(t >= postB & t < surveyB), sampleStride)]; %#ok<AGROW>
        end
        if isfinite(walkB)
            if ~isfinite(walkFinish) || walkFinish <= walkB
                walkFinish = walkE;
            end
            if isfinite(walkFinish) && walkFinish > walkB
                valsWalking = [valsWalking; localSampleVec(motionMag(t >= walkB & t <= walkFinish), sampleStride)]; %#ok<AGROW>
            end
        end
    end
end

phaseSpecs = { ...
    'baseline', valsBaseline; ...
    'video', valsVideo; ...
    'post', valsPost; ...
    'walking', valsWalking ...
    };

summaryRows = [];
for i = 1:size(phaseSpecs, 1)
    phaseName = string(phaseSpecs{i,1});
    vals = phaseSpecs{i,2};
    vals = vals(isfinite(vals));
    summaryRows = [summaryRows; table( ...
        phaseName, numel(vals), mean(vals, 'omitnan'), std(vals, 'omitnan'), ...
        median(vals, 'omitnan'), prctile(vals, 75), prctile(vals, 90), ...
        prctile(vals, 95), prctile(vals, 97), prctile(vals, 99), max(vals), ...
        'VariableNames', {'phase','nFrames','mean','std','median','p75','p90','p95','p97','p99','max'})]; %#ok<AGROW>
end

writetable(summaryRows, fullfile(outDir, 'frontstb_phase_summary.csv'));
fprintf('Saved outputs to:\n%s\n', outDir);
disp(summaryRows);

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

function y = localSampleVec(x, stride)
x = x(:);
y = x(1:stride:end);
end

function [tOut, xOut, yOut, zOut] = localDecimate4(t, x, y, z, factor)
idx = 1:factor:numel(t);
tOut = t(idx);
xOut = x(idx);
yOut = y(idx);
zOut = z(idx);
end
