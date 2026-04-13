% run_clip_physiology_quality_and_valence_sweep.m
%
% Sweep available physiology metrics in the clip window (vidB -> surveyB):
% 1) quantify practical quality/coverage
% 2) test valence association with mixed-effects models for usable metrics
%
% Front STb clip motion is included as the motion reference.

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(repoRoot));
matRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted/mat';

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_clip_physiology_quality_' runStamp]);
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

    surveys = U.surveys;
    keepSurveyVars = intersect({'seq','exp','valence'}, surveys.Properties.VariableNames, 'stable');
    surveys = surveys(:, keepSurveyVars);
    surveys.participantID = repmat(string(participantID), height(surveys), 1);

    front = localGetFrontMotion(S.signals);
    if isempty(front.timestamp)
        continue;
    end

    traces = struct();
    traces.e4_eda = localGetValueTrace(S.signals, 'e4', 'eda');
    traces.e4_hr = localGetValueTrace(S.signals, 'e4', 'hr');
    traces.e4_skt = localGetValueTrace(S.signals, 'e4', 'skt');
    traces.e4_bvp = localGetValueTrace(S.signals, 'e4', 'bvp');
    traces.e4_ibi = localGetValueTrace(S.signals, 'e4', 'ibi');
    traces.bh3_hr = localGetValueTrace(S.signals, 'bh3', 'hr');
    traces.bh3_hr_conf = localGetValueTrace(S.signals, 'bh3', 'hr_confidence');
    traces.bh3_br = localGetValueTrace(S.signals, 'bh3', 'br');
    traces.bh3_rr = localGetValueTrace(S.signals, 'bh3', 'rr');
    traces.bh3_bb = localGetValueTrace(S.signals, 'bh3', 'bb');
    traces.bh3_rsp = localGetValueTrace(S.signals, 'bh3', 'rsp');

    participantRows = [];
    phase2 = M.markers.phase2;
    for r = 1:height(phase2)
        vidB = localMaybeGetNumeric(phase2, 'vidB', r);
        surveyB = localMaybeGetNumeric(phase2, 'surveyB', r);
        if ~isfinite(vidB) || ~isfinite(surveyB) || surveyB <= vidB
            continue;
        end

        row = table();
        row.participantID = string(participantID);
        row.seq = localMaybeGetNumeric(phase2, 'seq', r);
        row.exp = localMaybeGetNumeric(phase2, 'exp', r);
        row.clipDurationSec = surveyB - vidB;

        % Motion reference: front STb low-animation clip motion
        clipMaskFront = front.timestamp >= vidB & front.timestamp < surveyB;
        clipMaskFrontLow = clipMaskFront & front.lowMask;
        if any(clipMaskFrontLow)
            row.front_clip_motion_median = median(front.motion(clipMaskFrontLow), 'omitnan');
            row.front_clip_motion_n = nnz(clipMaskFrontLow);
            row.front_clip_motion_frac = nnz(clipMaskFrontLow) / max(1, nnz(clipMaskFront));
        else
            row.front_clip_motion_median = NaN;
            row.front_clip_motion_n = 0;
            row.front_clip_motion_frac = 0;
        end

        [row.e4_eda_mean, row.e4_eda_std, row.e4_eda_n] = localWindowMeanStdN(traces.e4_eda, vidB, surveyB);
        [row.e4_hr_mean, row.e4_hr_std, row.e4_hr_n] = localWindowMeanStdN(traces.e4_hr, vidB, surveyB);
        [row.e4_skt_mean, row.e4_skt_std, row.e4_skt_n] = localWindowMeanStdN(traces.e4_skt, vidB, surveyB);
        [row.e4_bvp_std, row.e4_bvp_n] = localWindowStdN(traces.e4_bvp, vidB, surveyB);

        [row.e4_ibi_mean, row.e4_ibi_sdnn, row.e4_ibi_rmssd, row.e4_ibi_n] = localWindowIntervalFeatures(traces.e4_ibi, vidB, surveyB);
        [row.bh3_rr_mean, row.bh3_rr_sdnn, row.bh3_rr_rmssd, row.bh3_rr_n] = localWindowIntervalFeatures(traces.bh3_rr, vidB, surveyB);

        [row.bh3_hr_mean, row.bh3_hr_std, row.bh3_hr_n] = localWindowMeanStdN(traces.bh3_hr, vidB, surveyB);
        [row.bh3_br_mean, row.bh3_br_std, row.bh3_br_n] = localWindowMeanStdN(traces.bh3_br, vidB, surveyB);
        [row.bh3_bb_mean, row.bh3_bb_std, row.bh3_bb_n] = localWindowMeanStdN(traces.bh3_bb, vidB, surveyB);
        [row.bh3_rsp_std, row.bh3_rsp_n] = localWindowStdN(traces.bh3_rsp, vidB, surveyB);
        [row.bh3_hr_conf_mean, row.bh3_hr_conf_std, row.bh3_hr_conf_n] = localWindowMeanStdN(traces.bh3_hr_conf, vidB, surveyB);

        participantRows = [participantRows; row]; %#ok<AGROW>
    end

    if ~isempty(participantRows)
        participantRows = innerjoin(participantRows, surveys, 'Keys', {'participantID','seq','exp'});
        rows = [rows; participantRows]; %#ok<AGROW>
    end
end

J = rows;
writetable(J, fullfile(outDir, 'clip_physiology_joined.csv'));

featureDefs = { ...
    struct('feature','front_clip_motion_median','countField','front_clip_motion_n','label','Front STb clip motion'), ...
    struct('feature','e4_eda_mean','countField','e4_eda_n','label','E4 EDA mean'), ...
    struct('feature','e4_eda_std','countField','e4_eda_n','label','E4 EDA variability'), ...
    struct('feature','e4_hr_mean','countField','e4_hr_n','label','E4 HR mean'), ...
    struct('feature','e4_hr_std','countField','e4_hr_n','label','E4 HR variability'), ...
    struct('feature','e4_skt_mean','countField','e4_skt_n','label','E4 skin temperature mean'), ...
    struct('feature','e4_skt_std','countField','e4_skt_n','label','E4 skin temperature variability'), ...
    struct('feature','e4_bvp_std','countField','e4_bvp_n','label','E4 BVP variability'), ...
    struct('feature','e4_ibi_mean','countField','e4_ibi_n','label','E4 IBI mean'), ...
    struct('feature','e4_ibi_sdnn','countField','e4_ibi_n','label','E4 IBI SDNN'), ...
    struct('feature','e4_ibi_rmssd','countField','e4_ibi_n','label','E4 IBI RMSSD'), ...
    struct('feature','bh3_hr_mean','countField','bh3_hr_n','label','BH3 HR mean'), ...
    struct('feature','bh3_hr_std','countField','bh3_hr_n','label','BH3 HR variability'), ...
    struct('feature','bh3_br_mean','countField','bh3_br_n','label','BH3 breathing rate mean'), ...
    struct('feature','bh3_br_std','countField','bh3_br_n','label','BH3 breathing rate variability'), ...
    struct('feature','bh3_rr_mean','countField','bh3_rr_n','label','BH3 RR mean'), ...
    struct('feature','bh3_rr_sdnn','countField','bh3_rr_n','label','BH3 RR SDNN'), ...
    struct('feature','bh3_rr_rmssd','countField','bh3_rr_n','label','BH3 RR RMSSD'), ...
    struct('feature','bh3_bb_mean','countField','bh3_bb_n','label','BH3 breathing amplitude mean'), ...
    struct('feature','bh3_bb_std','countField','bh3_bb_n','label','BH3 breathing amplitude variability'), ...
    struct('feature','bh3_rsp_std','countField','bh3_rsp_n','label','BH3 respiration variability'), ...
    struct('feature','bh3_hr_conf_mean','countField','bh3_hr_conf_n','label','BH3 HR confidence') ...
    };

quality = table();
modelSummary = table();

for i = 1:numel(featureDefs)
    feat = featureDefs{i}.feature;
    countField = featureDefs{i}.countField;
    x = J.(feat);
    nObs = J.(countField);
    valid = isfinite(x);
    nValid = nnz(valid);
    subjValid = unique(string(J.participantID(valid)));
    q = table();
    q.feature = string(feat);
    q.label = string(featureDefs{i}.label);
    q.nValid = nValid;
    q.validFrac = nValid / height(J);
    q.nSubjects = numel(subjValid);
    q.medianObsPerValidWindow = median(nObs(valid), 'omitnan');
    q.p10ObsPerValidWindow = prctile(nObs(valid), 10);
    q.featureSD = std(x(valid), 0, 'omitnan');
    q.featureIQR = iqr(x(valid));
    q.reasonableQuality = q.validFrac >= 0.80 & q.nSubjects >= 40 & q.medianObsPerValidWindow >= 3;
    quality = [quality; q]; %#ok<AGROW>

    if q.reasonableQuality
        ms = localFitValenceMixedModel(J, feat);
        ms.feature = string(feat);
        ms.label = string(featureDefs{i}.label);
        modelSummary = [modelSummary; ms]; %#ok<AGROW>
    end
end

quality = sortrows(quality, {'reasonableQuality','validFrac','nSubjects'}, {'descend','descend','descend'});
modelSummary = sortrows(modelSummary, 'within_beta', 'descend');

writetable(quality, fullfile(outDir, 'physiology_quality_summary.csv'));
writetable(modelSummary, fullfile(outDir, 'valence_mixed_model_reasonable_features.csv'));

fig = figure('Color', 'w', 'Position', [120 120 1080 620]);
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1); hold(ax1, 'on'); box(ax1, 'off');
ax1.FontName = 'Helvetica'; ax1.FontSize = 11; ax1.XGrid = 'on'; ax1.GridAlpha = 0.15;
y = 1:height(quality);
scatter(ax1, quality.validFrac, y, 55, quality.reasonableQuality, 'filled');
ax1.YDir = 'reverse';
yticks(ax1, y);
yticklabels(ax1, quality.label);
xlabel(ax1, 'Valid window fraction');
title(ax1, 'Clip-window feature quality');
xlim(ax1, [0 1.02]);
colormap(ax1, [0.75 0.75 0.75; 0.18 0.47 0.72]);

ax2 = nexttile(tlo, 2); hold(ax2, 'on'); box(ax2, 'off');
ax2.FontName = 'Helvetica'; ax2.FontSize = 11; ax2.XGrid = 'on'; ax2.GridAlpha = 0.15;
yy = 1:height(modelSummary);
for i = 1:height(modelSummary)
    line(ax2, [0 modelSummary.within_beta(i)], [yy(i) yy(i)], 'Color', [0.72 0.78 0.84], 'LineWidth', 3);
end
errorbar(ax2, modelSummary.within_beta, yy, ...
    modelSummary.within_beta - modelSummary.within_CI_lo, ...
    modelSummary.within_CI_hi - modelSummary.within_beta, ...
    'horizontal', 'o', 'Color', [0.18 0.18 0.18], ...
    'MarkerFaceColor', [0.18 0.47 0.72], 'MarkerEdgeColor', 'w', ...
    'LineWidth', 1.4, 'CapSize', 8, 'MarkerSize', 8);
ax2.YDir = 'reverse';
yticks(ax2, yy);
yticklabels(ax2, modelSummary.label);
xlabel(ax2, 'Within-subject valence beta');
title(ax2, 'Reasonable-quality features: valence models');
xline(ax2, 0, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);

exportgraphics(fig, fullfile(outDir, 'quality_and_valence_summary.png'), 'Resolution', 220);
savefig(fig, fullfile(outDir, 'quality_and_valence_summary.fig'));

disp(quality);
disp(modelSummary);
fprintf('Saved outputs to:\n%s\n', outDir);

function front = localGetFrontMotion(signalsStruct)
front = struct('timestamp', [], 'motion', [], 'lowMask', []);
if ~isfield(signalsStruct, 'front') || ~isfield(signalsStruct.front, 'acc')
    return;
end
acc = signalsStruct.front.acc;
needVars = {'timestamp','x1_lis2dw12','y1_lis2dw12','z1_lis2dw12'};
if ~all(ismember(needVars, acc.Properties.VariableNames))
    return;
end
t = double(acc.timestamp);
x = double(acc.x1_lis2dw12);
y = double(acc.y1_lis2dw12);
z = double(acc.z1_lis2dw12);
[t, x, y, z] = localDecimate4(t, x, y, z, 10);
motion = localRollingMotionMagnitude(t, x, y, z, 0.5);
[lowMask, ~] = getLowAnimationFramesFromMotionMagnitude(motion, t, ...
    'threshold', 40, 'minLowDurationSec', 0.5, 'maxHighGapSec', 0.1);
front.timestamp = t;
front.motion = motion;
front.lowMask = lowMask;
end

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

function [m, s, n] = localWindowMeanStdN(trace, tStart, tEnd)
m = NaN; s = NaN; n = 0;
if isempty(trace.timestamp); return; end
mask = trace.timestamp >= tStart & trace.timestamp < tEnd & isfinite(trace.value);
n = nnz(mask);
if n == 0; return; end
m = mean(trace.value(mask), 'omitnan');
if n >= 2
    s = std(trace.value(mask), 0, 'omitnan');
end
end

function [s, n] = localWindowStdN(trace, tStart, tEnd)
s = NaN; n = 0;
if isempty(trace.timestamp); return; end
mask = trace.timestamp >= tStart & trace.timestamp < tEnd & isfinite(trace.value);
n = nnz(mask);
if n >= 2
    s = std(trace.value(mask), 0, 'omitnan');
end
end

function [m, sdnn, rmssd, n] = localWindowIntervalFeatures(trace, tStart, tEnd)
m = NaN; sdnn = NaN; rmssd = NaN; n = 0;
if isempty(trace.timestamp); return; end
mask = trace.timestamp >= tStart & trace.timestamp < tEnd & isfinite(trace.value);
vals = double(trace.value(mask));
n = numel(vals);
if n == 0; return; end
m = mean(vals, 'omitnan');
if n >= 2
    sdnn = std(vals, 0, 'omitnan');
    d = diff(vals);
    if ~isempty(d)
        rmssd = sqrt(mean(d.^2, 'omitnan'));
    end
end
end

function ms = localFitValenceMixedModel(J, feat)
D = J(:, {'participantID','valence', feat});
D.Properties.VariableNames{3} = 'outcome';
D = D(isfinite(D.outcome) & isfinite(D.valence), :);
D.participantID = categorical(string(D.participantID));
[G, ~] = findgroups(D.participantID);
subjMeanVal = splitapply(@mean, D.valence, G);
D.valenceBS = subjMeanVal(G);
D.valenceWS = D.valence - D.valenceBS;
D.valenceBS = D.valenceBS - mean(D.valenceBS, 'omitnan');
D.outcomeZ = localZ(D.outcome);
D.valenceWSZ = localZ(D.valenceWS);
D.valenceBSZ = localZ(D.valenceBS);
formula = 'outcomeZ ~ 1 + valenceWSZ + valenceBSZ + (1 + valenceWSZ | participantID)';
try
    mdl = fitlme(D, formula, 'FitMethod', 'REML');
    spec = formula;
catch
    spec = 'outcomeZ ~ 1 + valenceWSZ + valenceBSZ + (1 | participantID)';
    mdl = fitlme(D, spec, 'FitMethod', 'REML');
end
coef = mdl.Coefficients;
row = strcmp(coef.Name, 'valenceWSZ');
ms = table();
ms.nRows = height(D);
ms.nSubjects = numel(categories(removecats(D.participantID)));
ms.modelSpec = string(spec);
ms.within_beta = coef.Estimate(row);
ms.within_SE = coef.SE(row);
ms.within_p = coef.pValue(row);
ms.within_CI_lo = coef.Lower(row);
ms.within_CI_hi = coef.Upper(row);
ms.between_beta = coef.Estimate(strcmp(coef.Name, 'valenceBSZ'));
ms.between_p = coef.pValue(strcmp(coef.Name, 'valenceBSZ'));
end

function z = localZ(x)
x = double(x);
mu = mean(x, 'omitnan');
sd = std(x, 0, 'omitnan');
if ~isfinite(sd) || sd <= 0
    z = x - mu;
else
    z = (x - mu) ./ sd;
end
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
if ~any(finiteMask)
    out = nan(size(x));
    return;
end
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

