function make_waseda_departure_metric_cdfs(varargin)
%MAKE_WASEDA_DEPARTURE_METRIC_CDFS Render departure-metric CDFs split by condition.
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
[deskIntervals, videoIntervals] = localStrictIntervalsByCondition(strictBursts);

deskMask = strcmp(string(strictBursts.condition), "desk_work_stand");
videoMask = strcmp(string(strictBursts.condition), "watching_videos_stand");

deskDur = str2double(string(strictBursts.duration_sec(deskMask)));
videoDur = str2double(string(strictBursts.duration_sec(videoMask)));
deskAmp = str2double(string(strictBursts.env_delta(deskMask)));
videoAmp = str2double(string(strictBursts.env_delta(videoMask)));
deskRet = str2double(string(strictBursts.return_time_sec(deskMask)));
videoRet = str2double(string(strictBursts.return_time_sec(videoMask)));

deskRet = deskRet(~isnan(deskRet));
videoRet = videoRet(~isnan(videoRet));

figureHandle = figure('Color', 'w', 'Position', [100 100 1480 980]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Departure Metric CDFs By Condition', 'FontSize', 20, 'FontWeight', 'bold');
subtitle(t, 'Strict artifact-screened compound events. Desk work vs watching videos.', 'FontSize', 12);

localPlotCdfTile(nexttile(t), deskDur, videoDur, [0.30 0.47 0.65], [0.96 0.52 0.13], ...
    'departure duration (s)', localClipLimits(deskDur, videoDur, opts.clipQuantile), 'Duration');
localPlotCdfTile(nexttile(t), deskAmp, videoAmp, [0.30 0.47 0.65], [0.96 0.52 0.13], ...
    'departure amplitude above baseline', localClipLimits(deskAmp, videoAmp, opts.clipQuantile), 'Amplitude');
localPlotCdfTile(nexttile(t), deskRet, videoRet, [0.30 0.47 0.65], [0.96 0.52 0.13], ...
    'return-to-baseline time (s)', localClipLimits(deskRet, videoRet, opts.clipQuantile), 'Return');
localPlotCdfTile(nexttile(t), deskIntervals, videoIntervals, [0.30 0.47 0.65], [0.96 0.52 0.13], ...
    'inter-event interval (s)', localClipLimits(deskIntervals, videoIntervals, opts.clipQuantile), 'Inter-Event Interval');

exportgraphics(figureHandle, fullfile(opts.outputRoot, 'waseda_departure_metric_cdfs_by_condition_matlab.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(opts.outputRoot, 'waseda_departure_metric_cdfs_by_condition_matlab.fig'));
close(figureHandle);

fprintf('Wrote Waseda departure metric CDFs to %s\n', opts.outputRoot);
end

function opts = localParseInputs(varargin)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
p = inputParser;
p.addParameter('quietRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'quiet_dynamics_probe'));
p.addParameter('outputRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'figure_set'));
p.addParameter('clipQuantile', 0.98);
p.parse(varargin{:});
opts = p.Results;
end

function localPlotCdfTile(ax, deskValues, videoValues, deskColor, videoColor, xlabelText, xLimits, panelTitle)
[fDesk, xDesk] = ecdf(deskValues);
[fVideo, xVideo] = ecdf(videoValues);
plot(ax, xDesk, fDesk, 'Color', deskColor, 'LineWidth', 2.0); hold(ax, 'on');
plot(ax, xVideo, fVideo, 'Color', videoColor, 'LineWidth', 2.0);
xline(ax, median(deskValues, 'omitnan'), '-', 'Color', deskColor, 'LineWidth', 1.2);
xline(ax, median(videoValues, 'omitnan'), '-', 'Color', videoColor, 'LineWidth', 1.2);
xlabel(ax, xlabelText);
ylabel(ax, 'ECDF');
title(ax, panelTitle);
grid(ax, 'on');
xlim(ax, xLimits);
legend(ax, {localStatsLabel('desk work', deskValues), ...
    localStatsLabel('watching videos', videoValues)}, ...
    'Location', 'southeast', 'Box', 'off');
end

function label = localStatsLabel(name, values)
label = sprintf('%s (n=%d, median=%.3f, IQR=%.3f)', ...
    name, numel(values), median(values, 'omitnan'), iqr(values));
end

function [deskIntervals, videoIntervals] = localStrictIntervalsByCondition(strictBursts)
deskIntervals = [];
videoIntervals = [];
groups = findgroups(string(strictBursts.recording_id), string(strictBursts.subject_id), string(strictBursts.condition), string(strictBursts.note_window));
for g = 1:max(groups)
    rows = strictBursts(groups == g, :);
    [~, order] = sort(str2double(string(rows.peak_sec)));
    rows = rows(order, :);
    peaks = str2double(string(rows.peak_sec));
    if numel(peaks) < 2
        continue;
    end
    intervals = diff(peaks);
    condition = string(rows.condition(1));
    if condition == "desk_work_stand"
        deskIntervals = [deskIntervals; intervals]; %#ok<AGROW>
    elseif condition == "watching_videos_stand"
        videoIntervals = [videoIntervals; intervals]; %#ok<AGROW>
    end
end
end

function xLimits = localClipLimits(deskValues, videoValues, clipQuantile)
allValues = [deskValues(:); videoValues(:)];
allValues = allValues(~isnan(allValues));
if isempty(allValues)
    xLimits = [0 1];
    return;
end
upper = quantile(allValues, clipQuantile);
if upper <= 0
    upper = max(allValues);
end
if upper <= 0
    upper = 1;
end
xLimits = [0 upper];
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
