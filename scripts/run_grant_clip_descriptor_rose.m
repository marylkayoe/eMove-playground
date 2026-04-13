% run_grant_clip_descriptor_rose.m
%
% Build one radar / rose-style summary plot for four clip descriptors
% (valence, arousal, liking, familiarity) across five selected modalities:
%   - Front STb clip motion
%   - E4 BVP variability
%   - E4 HR mean
%   - BH3 HR mean
%   - BH3 breathing rate mean
%   - E4 EDA variability
%   - E4 IBI mean
%
% Effect size is the absolute within-subject mixed-model beta from:
%   outcomeZ ~ ratingWSZ + ratingBSZ + (1 + ratingWSZ | participantID)

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(repoRoot));
matRoot = '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted/mat';

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'figures', ['emowear_grant_clip_descriptor_rose_' runStamp]);
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
    keepSurveyVars = intersect({'seq','exp','valence','arousal','liking','familiarity'}, surveys.Properties.VariableNames, 'stable');
    surveys = surveys(:, keepSurveyVars);
    surveys.participantID = repmat(string(participantID), height(surveys), 1);

    front = localGetFrontMotion(S.signals);
    if isempty(front.timestamp)
        continue;
    end

    e4bvp = localGetValueTrace(S.signals, 'e4', 'bvp');
    e4hr = localGetValueTrace(S.signals, 'e4', 'hr');
    e4ibi = localGetValueTrace(S.signals, 'e4', 'ibi');
    e4eda = localGetValueTrace(S.signals, 'e4', 'eda');
    bh3br = localGetValueTrace(S.signals, 'bh3', 'br');
    bh3hr = localGetValueTrace(S.signals, 'bh3', 'hr');

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

        clipMaskFront = front.timestamp >= vidB & front.timestamp < surveyB;
        clipMaskFrontLow = clipMaskFront & front.lowMask;
        if any(clipMaskFrontLow)
            row.front_clip_motion = median(front.motion(clipMaskFrontLow), 'omitnan');
        else
            row.front_clip_motion = NaN;
        end
        [row.e4_bvp_std, ~] = localWindowStdN(e4bvp, vidB, surveyB);
        [row.e4_hr_mean, ~, ~] = localWindowMeanStdN(e4hr, vidB, surveyB);
        [row.e4_ibi_mean, ~, ~, ~] = localWindowIntervalFeatures(e4ibi, vidB, surveyB);
        [row.bh3_hr_mean, ~, ~] = localWindowMeanStdN(bh3hr, vidB, surveyB);
        [row.bh3_br_mean, ~, ~] = localWindowMeanStdN(bh3br, vidB, surveyB);
        [~, row.e4_eda_std, ~] = localWindowMeanStdN(e4eda, vidB, surveyB);

        participantRows = [participantRows; row]; %#ok<AGROW>
    end

    if ~isempty(participantRows)
        participantRows = innerjoin(participantRows, surveys, 'Keys', {'participantID','seq','exp'});
        rows = [rows; participantRows]; %#ok<AGROW>
    end
end

J = rows;
writetable(J, fullfile(outDir, 'clip_descriptor_joined.csv'));

features = { ...
    struct('field','front_clip_motion','label','Front STb motion'), ...
    struct('field','e4_bvp_std','label','E4 BVP variability'), ...
    struct('field','e4_hr_mean','label','E4 HR mean'), ...
    struct('field','bh3_br_mean','label','BH3 breathing rate'), ...
    struct('field','bh3_hr_mean','label','BH3 HR mean'), ...
    struct('field','e4_eda_std','label','E4 EDA variability'), ...
    struct('field','e4_ibi_mean','label','E4 IBI mean') ...
    };
ratings = {'valence','arousal','liking','familiarity'};

summary = table();
for rIdx = 1:numel(ratings)
    rating = ratings{rIdx};
    for fIdx = 1:numel(features)
        res = localFitMixed(J, features{fIdx}.field, rating);
        res.rating = string(rating);
        res.feature = string(features{fIdx}.field);
        res.label = string(features{fIdx}.label);
        summary = [summary; res]; %#ok<AGROW>
    end
end
writetable(summary, fullfile(outDir, 'clip_descriptor_mixed_model_summary.csv'));

fig = figure('Color', [0.987 0.982 0.972], 'Position', [100 100 980 900]);
ax = axes(fig, 'Position', [0.08 0.16 0.84 0.72]);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, 'off');

featOrder = string(cellfun(@(s) s.label, features, 'UniformOutput', false));
nFeat = numel(features);
theta = pi/2 - (0:nFeat-1) * 2*pi/nFeat;

% Common positive scale for informativeness.
rMin = 0;
rMax = 0.16;
rSpan = rMax - rMin;
tickVals = [0.00 0.04 0.08 0.12 0.16];

gridColor = [0.80 0.80 0.78];
spokeColor = [0.84 0.84 0.82];
zeroColor = [0.46 0.46 0.44];

% Polygon grid
for tv = tickVals
    rr = (tv - rMin) / rSpan;
    [xg, yg] = pol2cart(theta, rr * ones(size(theta)));
    xg = [xg xg(1)];
    yg = [yg yg(1)];
    if abs(tv) < 1e-12
        plot(ax, xg, yg, ':', 'Color', zeroColor, 'LineWidth', 1.1);
    else
        plot(ax, xg, yg, '-', 'Color', gridColor, 'LineWidth', 0.9, 'HandleVisibility', 'off');
    end
end

% Spokes
for i = 1:nFeat
    [xs, ys] = pol2cart(theta(i), [0 1.04]);
    plot(ax, xs, ys, '-', 'Color', spokeColor, 'LineWidth', 0.9, 'HandleVisibility', 'off');
end

% Radial labels on the BH3 HR spoke, where there is more open space.
hrSpokeIdx = 5;
hrTheta = theta(hrSpokeIdx);
for tv = tickVals
    rr = (tv - rMin) / rSpan;
    [xt, yt] = pol2cart(hrTheta, rr);
    text(ax, xt - 0.03, yt, sprintf('%.2f', tv), ...
        'FontSize', 14, 'Color', [0.34 0.34 0.34], ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end

% Spoke labels
labelRadius = 1.12;
labelText = ["Front STb motion", "E4 BVP variability", "E4 HR mean", "BH3 breathing rate", "BH3 HR mean", "E4 EDA variability", "E4 IBI mean"];
for i = 1:nFeat
    [xl, yl] = pol2cart(theta(i), labelRadius);
    ha = 'center';
    if cos(theta(i)) > 0.25
        ha = 'left';
    elseif cos(theta(i)) < -0.25
        ha = 'right';
    end
    text(ax, xl, yl, labelText(i), ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'Color', [0.22 0.22 0.22], ...
        'HorizontalAlignment', ha, 'VerticalAlignment', 'middle');
end

colors = [ ...
    0.73 0.22 0.16;  % valence
    0.20 0.43 0.70;  % arousal
    0.20 0.57 0.38;  % liking
    0.53 0.34 0.63   % familiarity
    ];
ratingLabels = ["Valence","Arousal","Liking","Familiarity"];
mainHandles = gobjects(numel(ratings), 1);

for rIdx = 1:numel(ratings)
    rating = ratings{rIdx};
    S = summary(summary.rating == string(rating), :);
    [~, ord] = ismember(S.label, featOrder);
    S = sortrows(addvars(S, ord, 'Before', 1, 'NewVariableNames', 'ord'), 'ord');
    rr = abs(S.within_beta) / rSpan;
    [xp, yp] = pol2cart(theta, rr');
    xp = [xp xp(1)];
    yp = [yp yp(1)];
    patch(ax, xp, yp, colors(rIdx,:), ...
        'FaceAlpha', 0.10, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    mainHandles(rIdx) = plot(ax, xp, yp, '-o', ...
        'LineWidth', 2.4, ...
        'Color', colors(rIdx,:), ...
        'MarkerFaceColor', colors(rIdx,:), ...
        'MarkerEdgeColor', 'w', ...
        'MarkerSize', 8, ...
        'DisplayName', char(ratingLabels(rIdx)));
end

lgd = legend(ax, mainHandles, cellstr(ratingLabels), 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 14);
title(lgd, '');
sgtitle(fig, 'Clip descriptors across motion and physiological signals', ...
    'FontWeight', 'bold', 'FontSize', 22, 'Color', [0.16 0.16 0.16]);

annotation(fig, 'textbox', [0.22 0.03 0.56 0.06], ...
    'String', 'Radius = absolute within-subject mixed-model beta on a common scale', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 12, 'Color', [0.28 0.28 0.28]);

exportgraphics(fig, fullfile(outDir, 'grant_clip_descriptor_rose.png'), 'Resolution', 240);
savefig(fig, fullfile(outDir, 'grant_clip_descriptor_rose.fig'));

disp(summary);
fprintf('Saved outputs to:\n%s\n', outDir);

function res = localFitMixed(J, feat, rating)
D = J(:, {'participantID', feat, rating});
D.Properties.VariableNames = {'participantID','outcome','ratingValue'};
D = D(isfinite(D.outcome) & isfinite(D.ratingValue), :);
D.participantID = categorical(string(D.participantID));
[G, ~] = findgroups(D.participantID);
subjMeanRating = splitapply(@mean, D.ratingValue, G);
D.ratingBS = subjMeanRating(G);
D.ratingWS = D.ratingValue - D.ratingBS;
D.ratingBS = D.ratingBS - mean(D.ratingBS, 'omitnan');
D.outcomeZ = localZ(D.outcome);
D.ratingWSZ = localZ(D.ratingWS);
D.ratingBSZ = localZ(D.ratingBS);
formula = 'outcomeZ ~ 1 + ratingWSZ + ratingBSZ + (1 + ratingWSZ | participantID)';
try
    mdl = fitlme(D, formula, 'FitMethod', 'REML');
catch
    mdl = fitlme(D, 'outcomeZ ~ 1 + ratingWSZ + ratingBSZ + (1 | participantID)', 'FitMethod', 'REML');
end
coef = mdl.Coefficients;
row = strcmp(coef.Name, 'ratingWSZ');
res = table();
res.nRows = height(D);
res.nSubjects = numel(categories(removecats(D.participantID)));
res.within_beta = coef.Estimate(row);
res.within_SE = coef.SE(row);
res.within_p = coef.pValue(row);
res.within_CI_lo = coef.Lower(row);
res.within_CI_hi = coef.Upper(row);
end

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
