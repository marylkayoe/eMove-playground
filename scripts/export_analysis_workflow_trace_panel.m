% export_analysis_workflow_trace_panel.m
%
% Export a clean trace/threshold panel for the analysis-workflow explainer.
% The panel uses one subject/example trial and shows:
%   - average X position over time for HEAD / UTORSO / LTORSO
%   - average instantaneous speed for the same groups
%   - a 35 mm/s micromovement threshold
%   - shaded low-motion bouts in the pooled average speed

clearvars;
clc;
close all;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest/SC3001';
matPath = fullfile(dataRoot, 'SC3001_mocap_Take_2025_08_25_05_19_25_PM.mat');
groupCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');

outDir = fullfile(repoRoot, 'outputs', 'figures', 'analysis_workflow_20260322');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

if ~isfile(matPath)
    error('Missing MAT file: %s', matPath);
end

if ~isfile(groupCsv)
    error('Missing grouping CSV: %s', groupCsv);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

S = load(matPath, 'trialData');
trialData = S.trialData;

groupMap = localLoadGroups(groupCsv, {'HEAD', 'UTORSO', 'LTORSO'});
groupNames = {'HEAD', 'UTORSO', 'LTORSO'};
groupColors = [0.84 0.33 0.10; 0.00 0.45 0.74; 0.49 0.18 0.56];

videoID = '0602';
preStimSec = 10;
postStimSec = 10;
speedWindowSec = 0.1;
immobileThreshold = 35;
immobileMinDurationSec = 1.0;

nGroups = numel(groupNames);
posSeries = cell(nGroups, 1);
speedSeries = cell(nGroups, 1);
labels = cell(nGroups, 1);
x = [];
stimBounds = [];
frameRate = [];

for g = 1:nGroups
    gName = groupNames{g};
    markers = groupMap(gName);
    E = extractMarkerTrajectoryForVideo( ...
        trialData, markers, videoID, ...
        'clipSec', 0, ...
        'preStimSec', preStimSec, ...
        'postStimSec', postStimSec);

    if isempty(x)
        x = E.timeSec(:);
        if ~isempty(x)
            x = x - x(1);
        end
        stimBounds = [E.stimStartOffsetSec, E.stimEndOffsetSec];
        frameRate = E.frameRate;
    end

    traj = squeeze(E.trajectories(:, 1, :)); % X dimension only
    if isvector(traj)
        traj = traj(:);
    end
    posSeries{g} = mean(traj, 2, 'omitnan');

    spd = nan(size(traj, 1), size(traj, 2));
    for m = 1:size(traj, 2)
        spd(:, m) = getTrajectorySpeed(E.trajectories(:, :, m), E.frameRate, speedWindowSec);
    end
    speedSeries{g} = mean(spd, 2, 'omitnan');
    labels{g} = strrep(gName, '_', '-');
end

speedMat = nan(numel(speedSeries{1}), nGroups);
for g = 1:nGroups
    speedMat(:, g) = speedSeries{g}(:);
end
avgSpeed = mean(speedMat, 2, 'omitnan');
[immobileMask, ~, bouts] = getImmobileFramesFromSpeed(avgSpeed, frameRate, ...
    'thresholdMmPerSec', immobileThreshold, ...
    'minDurationSec', immobileMinDurationSec);

f = figure('Color', 'w', 'Units', 'pixels', 'Position', [100 80 1100 720]);
tlo = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
hold(ax1, 'on');
for g = 1:nGroups
    plot(ax1, x, posSeries{g}, 'LineWidth', 2.6, 'Color', groupColors(g,:), 'DisplayName', labels{g});
end
localShadeBouts(ax1, x, immobileMask, [0.78 0.78 0.78], 0.18);
localDrawStimBounds(ax1, stimBounds, [0.25 0.25 0.25]);
ylabel(ax1, 'Mean X position (mm)', 'FontWeight', 'bold');
title(ax1, '2. One trial: average bodypart movement over time', 'FontSize', 16, 'FontWeight', 'bold');
grid(ax1, 'on');
set(ax1, 'Box', 'off', 'LineWidth', 1.0, 'FontSize', 12);
legend(ax1, 'Location', 'northwest', 'Box', 'off');

ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
for g = 1:nGroups
    plot(ax2, x, speedSeries{g}, 'LineWidth', 2.2, 'Color', groupColors(g,:));
end
plot(ax2, x, avgSpeed, 'k', 'LineWidth', 2.8, 'DisplayName', 'Average speed');
localShadeBouts(ax2, x, immobileMask, [0.78 0.78 0.78], 0.18);
yline(ax2, immobileThreshold, '--', sprintf('Micromovement threshold (%d mm/s)', immobileThreshold), ...
    'Color', [0.35 0.35 0.35], 'LineWidth', 1.4, ...
    'LabelHorizontalAlignment', 'left', 'LabelVerticalAlignment', 'bottom');
localDrawStimBounds(ax2, stimBounds, [0.25 0.25 0.25]);
ylabel(ax2, 'Instantaneous speed (mm/s)', 'FontWeight', 'bold');
xlabel(ax2, 'Time (s)', 'FontWeight', 'bold');
title(ax2, '3. Keep only low-speed samples during sustained bouts', 'FontSize', 16, 'FontWeight', 'bold');
grid(ax2, 'on');
set(ax2, 'Box', 'off', 'LineWidth', 1.0, 'FontSize', 12);
txt = sprintf('Shaded = mean speed < %d mm/s for at least %.1f s | video %s', ...
    immobileThreshold, immobileMinDurationSec, videoID);
text(ax2, 0.01, 0.98, txt, 'Units', 'normalized', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'FontSize', 10.5, 'Color', [0.25 0.25 0.25], ...
    'BackgroundColor', [1 1 1 0.65], 'Margin', 3);

exportgraphics(f, fullfile(outDir, 'workflow_trace_panel.png'), 'Resolution', 220);
exportgraphics(f, fullfile(outDir, 'workflow_trace_panel.pdf'), 'ContentType', 'vector');
savefig(f, fullfile(outDir, 'workflow_trace_panel.fig'));

summaryTbl = table(groupNames(:), ...
    cellfun(@numel, speedSeries(:)), ...
    repmat(sum(immobileMask), nGroups, 1), ...
    'VariableNames', {'groupName','nFrames','nImmobileFramesCombined'});
writetable(summaryTbl, fullfile(outDir, 'workflow_trace_panel_summary.csv'));

fprintf('Saved workflow trace panel under:\n%s\n', outDir);

function groupMap = localLoadGroups(groupCsv, wantedGroups)
    T = readtable(groupCsv, 'TextType', 'string');
    T = T(T.include == 1, :);
    groupMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:numel(wantedGroups)
        g = wantedGroups{i};
        rows = T.groupName == g;
        groupMap(g) = cellstr(T.markerName(rows));
    end
end

function localDrawStimBounds(ax, stimBounds, colorVal)
    xline(ax, stimBounds(1), '--', 'Stim start', ...
        'Color', colorVal, 'LineWidth', 1.2, ...
        'LabelOrientation', 'aligned', ...
        'LabelVerticalAlignment', 'middle');
    xline(ax, stimBounds(2), '--', 'Stim end', ...
        'Color', colorVal, 'LineWidth', 1.2, ...
        'LabelOrientation', 'aligned', ...
        'LabelVerticalAlignment', 'middle');
end

function localShadeBouts(ax, x, mask, colorVal, alphaVal)
    if isempty(mask) || ~any(mask)
        return;
    end
    yL = ylim(ax);
    d = diff([false; mask(:); false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    for k = 1:numel(starts)
        xs = [x(starts(k)) x(ends(k)) x(ends(k)) x(starts(k))];
        ys = [yL(1) yL(1) yL(2) yL(2)];
        patch(ax, xs, ys, colorVal, 'FaceAlpha', alphaVal, 'EdgeColor', 'none');
    end
    ylim(ax, yL);
end
