function make_waseda_event_metric_scatter_vs_time(varargin)
%MAKE_WASEDA_EVENT_METRIC_SCATTER_VS_TIME Scatter plots of event metrics vs elapsed trial time.
%
% Outputs default to:
%   scratch/waseda_acc_matlab/figure_set/

opts = localParseInputs(varargin{:});
if ~isfolder(opts.quietRoot)
    error('Quiet probe output folder not found: %s', opts.quietRoot);
end
if ~isfolder(opts.outputRoot)
    mkdir(opts.outputRoot);
end

windowTbl = readtable(fullfile(opts.quietRoot, 'quiet_window_summary.csv'), 'VariableNamingRule', 'preserve');
burstTbl = readtable(fullfile(opts.quietRoot, 'quiet_burst_events.csv'), 'VariableNamingRule', 'preserve');
[strictBursts, ~] = localStrictBurstRows(windowTbl, burstTbl);
metricTbl = localBuildMetricTable(strictBursts);

figureHandle = figure('Color', 'w', 'Position', [100 100 1480 980]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Event Metrics Vs Elapsed Trial Time', 'FontSize', 20, 'FontWeight', 'bold');
subtitle(t, 'Strict artifact-screened compound events. Elapsed time is relative to condition-window start.', 'FontSize', 12);

localPlotMetricScatter(nexttile(t), metricTbl, 'duration_sec', 'duration (s)', [0 12]);
localPlotMetricScatter(nexttile(t), metricTbl, 'env_delta', 'amplitude above baseline', [0 0.08]);
localPlotMetricScatter(nexttile(t), metricTbl, 'return_time_sec', 'return-to-baseline time (s)', [0 12]);
localPlotMetricScatter(nexttile(t), metricTbl, 'interval_sec', 'inter-event interval (s)', [0 60]);

exportgraphics(figureHandle, fullfile(opts.outputRoot, 'waseda_event_metric_scatter_vs_time_matlab.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(opts.outputRoot, 'waseda_event_metric_scatter_vs_time_matlab.fig'));
close(figureHandle);

fprintf('Wrote Waseda event metric scatter plots to %s\n', opts.outputRoot);
end

function opts = localParseInputs(varargin)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
p = inputParser;
p.addParameter('quietRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'quiet_dynamics_probe'));
p.addParameter('outputRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'figure_set'));
p.parse(varargin{:});
opts = p.Results;
end

function localPlotMetricScatter(ax, metricTbl, fieldName, yLabelText, yLimits)
deskMask = strcmp(string(metricTbl.condition), "desk_work_stand") & ~isnan(metricTbl.(fieldName));
videoMask = strcmp(string(metricTbl.condition), "watching_videos_stand") & ~isnan(metricTbl.(fieldName));

scatter(ax, metricTbl.elapsed_min(deskMask), metricTbl.(fieldName)(deskMask), 18, ...
    [0.30 0.47 0.65], 'filled', 'MarkerFaceAlpha', 0.55, 'MarkerEdgeAlpha', 0.15); hold(ax, 'on');
scatter(ax, metricTbl.elapsed_min(videoMask), metricTbl.(fieldName)(videoMask), 18, ...
    [0.96 0.52 0.13], 'filled', 'MarkerFaceAlpha', 0.55, 'MarkerEdgeAlpha', 0.15);

xlabel(ax, 'minutes from trial start');
ylabel(ax, yLabelText);
grid(ax, 'on');
ylim(ax, yLimits);
title(ax, localPanelTitle(fieldName, metricTbl, deskMask, videoMask));

if strcmp(fieldName, 'duration_sec')
    legend(ax, {'desk work', 'watching videos'}, 'Location', 'northeast', 'Box', 'off');
end
end

function titleText = localPanelTitle(fieldName, metricTbl, deskMask, videoMask)
[deskRho, deskP] = corr(metricTbl.elapsed_min(deskMask), metricTbl.(fieldName)(deskMask), ...
    'Type', 'Spearman', 'Rows', 'complete');
[videoRho, videoP] = corr(metricTbl.elapsed_min(videoMask), metricTbl.(fieldName)(videoMask), ...
    'Type', 'Spearman', 'Rows', 'complete');
titleText = sprintf('desk rho=%.2f (p=%s) | video rho=%.2f (p=%s)', ...
    deskRho, localFmtP(deskP), videoRho, localFmtP(videoP));
end

function textValue = localFmtP(pValue)
if isnan(pValue)
    textValue = 'NaN';
elseif pValue < 0.001
    textValue = '<0.001';
else
    textValue = sprintf('%.3f', pValue);
end
end

function metricTbl = localBuildMetricTable(strictBursts)
nRows = height(strictBursts);
elapsedSec = NaN(nRows, 1);
intervalSec = NaN(nRows, 1);

for i = 1:nRows
    elapsedSec(i) = localElapsedSinceTrialStartSec(string(strictBursts.note_window(i)), string(strictBursts.peak_clock(i)));
end

groups = findgroups(string(strictBursts.recording_id), string(strictBursts.subject_id), string(strictBursts.condition), string(strictBursts.note_window));
for g = 1:max(groups)
    idx = find(groups == g);
    [~, order] = sort(elapsedSec(idx));
    idx = idx(order);
    if numel(idx) >= 2
        intervalSec(idx(2:end)) = diff(elapsedSec(idx));
    end
end

metricTbl = table();
metricTbl.condition = string(strictBursts.condition);
metricTbl.elapsed_min = elapsedSec ./ 60;
metricTbl.duration_sec = str2double(string(strictBursts.duration_sec));
metricTbl.env_delta = str2double(string(strictBursts.env_delta));
metricTbl.return_time_sec = str2double(string(strictBursts.return_time_sec));
metricTbl.interval_sec = intervalSec;
end

function elapsedSec = localElapsedSinceTrialStartSec(noteWindow, peakClock)
parts = split(string(noteWindow), '-');
startClock = strtrim(parts(1));
startAbs = sscanf(startClock, '%d:%d', 2);
peakAbs = sscanf(char(strtrim(string(peakClock))), '%d:%d:%f', 3);
startSec = startAbs(1) * 3600 + startAbs(2) * 60;
peakSec = peakAbs(1) * 3600 + peakAbs(2) * 60 + peakAbs(3);
if peakSec < startSec
    peakSec = peakSec + 24 * 3600;
end
elapsedSec = peakSec - startSec;
end

function [strictBursts, stableBandByWindow] = localStrictBurstRows(windowTbl, burstTbl)
stableBandByWindow = localStableBandMap(windowTbl);
keep = false(height(burstTbl), 1);
for i = 1:height(burstTbl)
    if strlength(string(burstTbl.event_id(i))) == 0
        continue;
    end
    key = localWindowKey(localTextValue(burstTbl.recording_id(i)), localTextValue(burstTbl.subject_id(i)), ...
        localTextValue(burstTbl.condition(i)), localTextValue(burstTbl.note_window(i)));
    keep(i) = str2double(string(burstTbl.env_delta(i))) >= stableBandByWindow(key);
end
strictBursts = burstTbl(keep, :);
end

function stableBandMap = localStableBandMap(windowTbl)
stableBandMap = containers.Map();
for i = 1:height(windowTbl)
    key = localWindowKey(localTextValue(windowTbl.recording_id(i)), localTextValue(windowTbl.subject_id(i)), ...
        localTextValue(windowTbl.condition(i)), localTextValue(windowTbl.note_window(i)));
    stableBandMap(key) = str2double(string(windowTbl.stable_band(i)));
end
end

function key = localWindowKey(recordingId, subjectId, condition, noteWindow)
key = strjoin({char(recordingId), char(subjectId), char(condition), char(noteWindow)}, '||');
end

function value = localTextValue(inputValue)
if iscell(inputValue)
    value = string(inputValue{1});
elseif isstring(inputValue)
    value = string(inputValue(1));
elseif ischar(inputValue)
    value = string(inputValue);
else
    value = string(inputValue(1));
end
value = char(value);
end
