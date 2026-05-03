function make_waseda_departure_figure_set(varargin)
%MAKE_WASEDA_DEPARTURE_FIGURE_SET Render focused departure figures from MATLAB probe outputs.
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

manifest = loadWasedaAccManifest(opts.manifestPath);
recordings = localFlattenRecordings(manifest);
seriesMap = containers.Map();
windowMap = containers.Map();
for iRec = 1:numel(recordings)
    recording = recordings(iRec);
    if ~isfield(recording.file_patterns, opts.sensorKey)
        continue;
    end
    series = discoverWasedaAccSeries(opts.rawRoot, recording, opts.sensorKey);
    env = computeWasedaDynamicMagnitude(series, opts.envWindowSec);
    env = movmean(env, localCenteredWindow(opts.smoothSec, series.sample_rate_hz), 'Endpoints', 'shrink');
    [envAnalysis, envDisplay, ~] = preprocessWasedaDynamicEnvelope(series.times_sec, env, ...
        'artifactThreshold', opts.artifactEnvThreshold);
    for iWin = 1:numel(recording.windows)
        window = recording.windows(iWin);
        key = localWindowKey(recording.recording_id, recording.subject_id, window.condition, window.note_window);
        [startSec, endSec] = parseWasedaNoteWindow(window.note_window, series.reference_abs_sec);
        payload = struct('series', series, 'envAnalysis', envAnalysis, 'envDisplay', envDisplay);
        seriesMap(key) = payload;
        windowMap(key) = [startSec, endSec];
    end
end

localMakeDepartureExamplesFigure(windowTbl, burstTbl, seriesMap, windowMap, opts);
localMakeInterEventFigure(windowTbl, burstTbl, opts);
localMakeDistributionFigure(windowTbl, burstTbl, opts);

fprintf('Wrote Waseda departure figures to %s\n', opts.outputRoot);
end

function opts = localParseInputs(varargin)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
p = inputParser;
p.addParameter('manifestPath', fullfile(repoRoot, 'resources', 'waseda_acc', 'dataset_manifest.json'));
p.addParameter('rawRoot', '/Users/yoe/Documents/DATA/Waseda-ACC');
p.addParameter('quietRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'quiet_dynamics_probe'));
p.addParameter('outputRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'figure_set'));
p.addParameter('sensorKey', 'chest');
p.addParameter('envWindowSec', 1.0);
p.addParameter('smoothSec', 2.0);
p.addParameter('eventContextSec', 20.0);
p.addParameter('artifactEnvThreshold', 0.5);
p.parse(varargin{:});
opts = p.Results;
end

function localMakeDepartureExamplesFigure(windowTbl, burstTbl, seriesMap, windowMap, opts)
figureHandle = figure('Color', 'w', 'Position', [80 80 1650 1380]);
t = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Candidate Departures With Baseline And Recovery', 'FontSize', 20, 'FontWeight', 'bold');
subtitle(t, 'Waseda chest ACC actual signal around candidate stable-band departures: artifact-screened departures', 'FontSize', 14, 'FontWeight', 'bold');

stableBandMap = localStableBandMap(windowTbl);
targets = {
    "sub1", "watching_videos_stand";
    "sub2", "watching_videos_stand";
    "sub3", "watching_videos_stand";
    "sub4", "desk_work_stand";
    };
selectedRows = localSelectGalleryEvents(burstTbl, stableBandMap, targets, 0.10);

for iRow = 1:numel(selectedRows)
    event = selectedRows{iRow};
    key = localWindowKey(localTextValue(event.recording_id), localTextValue(event.subject_id), ...
        localTextValue(event.condition), localTextValue(event.note_window));
    payload = seriesMap(key);
    windowSec = windowMap(key);
    series = payload.series;
    envAnalysis = payload.envAnalysis;
    envDisplay = payload.envDisplay;
    idxWindow = series.times_sec >= windowSec(1) & series.times_sec < windowSec(2);
    [center, band] = localStableBand(envAnalysis(idxWindow));
    peakSec = str2double(string(event.peak_sec));
    leftSec = max(windowSec(1), peakSec - opts.eventContextSec);
    rightSec = min(windowSec(2), peakSec + opts.eventContextSec);
    idxs = find(series.times_sec >= leftSec & series.times_sec < rightSec);
    x = series.times_sec(idxs) - peakSec;

    axRaw = nexttile(t);
    plot(axRaw, x, localCentered(series.ax(idxs)), 'Color', [0.30 0.47 0.65], 'LineWidth', 0.75); hold(axRaw, 'on');
    plot(axRaw, x, localCentered(series.ay(idxs)), 'Color', [0.96 0.52 0.13], 'LineWidth', 0.75);
    plot(axRaw, x, localCentered(series.az(idxs)), 'Color', [0.33 0.64 0.33], 'LineWidth', 0.75);
    xline(axRaw, 0, '-', 'Color', [0.86 0.18 0.18], 'LineWidth', 1.1);
    ylabel(axRaw, {'raw axes', 'centered (g)'});
    xlabel(axRaw, 'seconds from candidate peak');
    grid(axRaw, 'on');
    if iRow == 1
        legend(axRaw, {'X', 'Y', 'Z'}, 'Location', 'northeast', 'Orientation', 'horizontal', 'Box', 'off');
    end
    title(axRaw, sprintf('%s %s %s | delta=%.4f, return=%ss', ...
        localTextValue(event.subject_id), strrep(strrep(localTextValue(event.condition), '_stand', ''), '_', ' '), ...
        localTextValue(event.peak_clock), str2double(string(event.env_delta)), localTextValue(event.return_time_sec)), ...
        'FontSize', 11, 'FontWeight', 'normal', 'HorizontalAlignment', 'left');

    axEnv = nexttile(t);
    plot(axEnv, x, envDisplay(idxs), 'k', 'LineWidth', 1.0); hold(axEnv, 'on');
    patch(axEnv, [x(1) x(end) x(end) x(1)], [center-band center-band center+band center+band], ...
        [0.30 0.47 0.65], 'FaceAlpha', 0.12, 'EdgeColor', 'none');
    yline(axEnv, center, '-', 'Color', [0.30 0.47 0.65], 'LineWidth', 0.9);
    xline(axEnv, 0, '-', 'Color', [0.86 0.18 0.18], 'LineWidth', 1.1);
    scatter(axEnv, 0, str2double(string(event.peak_env)), 28, [0.86 0.18 0.18], 'filled');
    ylabel(axEnv, 'dynamic envelope');
    xlabel(axEnv, 'seconds from candidate peak');
    grid(axEnv, 'on');
    ylim(axEnv, [0 localRobustUpperLimit(envDisplay(idxs), center, band)]);
end

exportgraphics(figureHandle, fullfile(opts.outputRoot, 'waseda_candidate_departures_examples_matlab.png'), 'Resolution', 180);
close(figureHandle);
end

function localMakeInterEventFigure(windowTbl, burstTbl, opts)
[deskIntervals, videoIntervals] = localStrictIntervalsByCondition(windowTbl, burstTbl);
figureHandle = figure('Color', 'w', 'Position', [90 90 1700 980]);
t = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Inter-Event Interval Structure', 'FontSize', 20, 'FontWeight', 'bold');
subtitle(t, 'Strict-screened departures only. Log-scaled x axis.', 'FontSize', 12);

ax1 = nexttile(t);
edges = logspace(-1, 2.6, 26);
histogram(ax1, deskIntervals, edges, 'FaceColor', [0.30 0.47 0.65], 'FaceAlpha', 0.55, 'EdgeAlpha', 0.25); hold(ax1, 'on');
histogram(ax1, videoIntervals, edges, 'FaceColor', [0.96 0.52 0.13], 'FaceAlpha', 0.55, 'EdgeAlpha', 0.25);
xline(ax1, median(deskIntervals, 'omitnan'), '-', 'Color', [0.30 0.47 0.65], 'LineWidth', 2.0);
xline(ax1, median(videoIntervals, 'omitnan'), '-', 'Color', [0.96 0.52 0.13], 'LineWidth', 2.0);
set(ax1, 'XScale', 'log');
ylabel(ax1, 'count');
grid(ax1, 'on');
legend(ax1, {sprintf('desk work (n=%d)', numel(deskIntervals)), sprintf('watching videos (n=%d)', numel(videoIntervals))}, ...
    'Location', 'northeast', 'Box', 'off');

ax2 = nexttile(t);
[fDesk, xDesk] = ecdf(deskIntervals);
[fVideo, xVideo] = ecdf(videoIntervals);
plot(ax2, xDesk, fDesk, 'Color', [0.30 0.47 0.65], 'LineWidth', 1.8); hold(ax2, 'on');
plot(ax2, xVideo, fVideo, 'Color', [0.96 0.52 0.13], 'LineWidth', 1.8);
set(ax2, 'XScale', 'log');
xlabel(ax2, 'inter-departure interval (s)');
ylabel(ax2, 'ECDF');
grid(ax2, 'on');
legend(ax2, {sprintf('desk work median=%.1fs', median(deskIntervals, 'omitnan')), ...
    sprintf('watching videos median=%.1fs', median(videoIntervals, 'omitnan'))}, ...
    'Location', 'southeast', 'Box', 'off');

exportgraphics(figureHandle, fullfile(opts.outputRoot, 'waseda_interevent_interval_structure_matlab.png'), 'Resolution', 180);
close(figureHandle);
end

function localMakeDistributionFigure(windowTbl, burstTbl, opts)
[strictBursts, ~] = localStrictBurstRows(windowTbl, burstTbl);
durations = str2double(string(strictBursts.duration_sec));
amplitudes = str2double(string(strictBursts.env_delta));
returns = str2double(string(strictBursts.return_time_sec));
returns = returns(~isnan(returns));

figureHandle = figure('Color', 'w', 'Position', [100 100 1700 640]);
t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Departure Duration And Amplitude Distributions', 'FontSize', 20, 'FontWeight', 'bold');
subtitle(t, 'Strict artifact-screened departures only. Histogram x-ranges clipped at the pooled 98th percentile with higher-resolution bins.', 'FontSize', 12);

ax1 = nexttile(t);
durationUpper = quantile(durations, 0.98);
durationView = durations(durations <= durationUpper);
durationEdges = localHistogramEdges(durationView, 18, 55);
histogram(ax1, durationView, durationEdges, 'FaceColor', [0.30 0.47 0.65], 'EdgeColor', 'w', 'EdgeAlpha', 0.35); hold(ax1, 'on');
xline(ax1, median(durations, 'omitnan'), 'k-', 'LineWidth', 1.7);
xlabel(ax1, 'departure duration (s)');
ylabel(ax1, 'count');
title(ax1, sprintf('n=%d shown<=%.3f\nmedian=%.3f, max=%.3f', numel(durationView), durationUpper, median(durations, 'omitnan'), max(durations)));
grid(ax1, 'on');
xlim(ax1, [min(durationEdges) max(durationEdges)]);
localAddHistogramInset(figureHandle, ax1, durationView, [0.30 0.47 0.65], median(durations, 'omitnan'), ...
    localInsetUpper(durationView, 0.65));

ax2 = nexttile(t);
amplitudeUpper = quantile(amplitudes, 0.98);
amplitudeView = amplitudes(amplitudes <= amplitudeUpper);
amplitudeEdges = localHistogramEdges(amplitudeView, 18, 55);
histogram(ax2, amplitudeView, amplitudeEdges, 'FaceColor', [0.96 0.52 0.13], 'EdgeColor', 'w', 'EdgeAlpha', 0.35); hold(ax2, 'on');
xline(ax2, median(amplitudes, 'omitnan'), 'k-', 'LineWidth', 1.7);
xlabel(ax2, 'departure amplitude above baseline');
title(ax2, sprintf('n=%d shown<=%.3f\nmedian=%.3f, max=%.3f', numel(amplitudeView), amplitudeUpper, median(amplitudes, 'omitnan'), max(amplitudes)));
grid(ax2, 'on');
xlim(ax2, [min(amplitudeEdges) max(amplitudeEdges)]);
localAddHistogramInset(figureHandle, ax2, amplitudeView, [0.96 0.52 0.13], median(amplitudes, 'omitnan'), ...
    localInsetUpper(amplitudeView, 0.70));

ax3 = nexttile(t);
returnUpper = quantile(returns, 0.98);
returnView = returns(returns <= returnUpper);
returnEdges = localHistogramEdges(returnView, 18, 55);
histogram(ax3, returnView, returnEdges, 'FaceColor', [0.33 0.64 0.33], 'EdgeColor', 'w', 'EdgeAlpha', 0.35); hold(ax3, 'on');
xline(ax3, median(returns, 'omitnan'), 'k-', 'LineWidth', 1.7);
xlabel(ax3, 'return-to-baseline time (s)');
title(ax3, sprintf('n=%d shown<=%.3f\nmedian=%.3f, max=%.3f', numel(returnView), returnUpper, median(returns, 'omitnan'), max(returns)));
grid(ax3, 'on');
xlim(ax3, [min(returnEdges) max(returnEdges)]);
localAddHistogramInset(figureHandle, ax3, returnView, [0.33 0.64 0.33], median(returns, 'omitnan'), ...
    localInsetUpper(returnView, 0.70));

exportgraphics(figureHandle, fullfile(opts.outputRoot, 'waseda_departure_metric_distributions_matlab.png'), 'Resolution', 180);
close(figureHandle);
end

function ylimUpper = localRobustUpperLimit(envValues, envCenter, stableBand)
validValues = envValues(~isnan(envValues));
if isempty(validValues)
    ylimUpper = max(envCenter + 3 * stableBand, 0.05);
    return;
end
upperCandidate = quantile(validValues, 0.995);
ylimUpper = max([upperCandidate, envCenter + 2.5 * stableBand, median(validValues) + 4 * iqr(validValues), 0.05]);
end

function edges = localHistogramEdges(values, minBins, maxBins)
if nargin < 2
    minBins = 12;
end
if nargin < 3
    maxBins = 45;
end
values = values(~isnan(values));
if isempty(values)
    edges = [0 1];
    return;
end
minValue = min(values);
maxValue = max(values);
if minValue == maxValue
    delta = max(abs(minValue) * 0.1, 1e-3);
    edges = [minValue - delta, maxValue + delta];
    return;
end
iqrValue = iqr(values);
n = numel(values);
if iqrValue <= 0 || n < 2
    nBins = min(maxBins, max(minBins, ceil(sqrt(n))));
else
    binWidth = 2 * iqrValue / nthroot(n, 3);
    if ~isfinite(binWidth) || binWidth <= 0
        nBins = min(maxBins, max(minBins, ceil(sqrt(n))));
    else
        nBins = ceil((maxValue - minValue) / binWidth);
        nBins = min(maxBins, max(minBins, nBins));
    end
end
edges = linspace(minValue, maxValue, nBins + 1);
end

function upper = localInsetUpper(values, quantileValue)
values = values(~isnan(values));
if isempty(values)
    upper = 1;
    return;
end
upper = quantile(values, quantileValue);
if upper <= min(values)
    upper = max(values);
end
if upper <= 0
    upper = 1;
end
end

function localAddHistogramInset(parentFigure, parentAx, values, faceColor, medianValue, insetUpper)
values = values(~isnan(values) & values <= insetUpper);
if isempty(values)
    return;
end
parentPos = parentAx.Position;
insetPos = [parentPos(1) + 0.56 * parentPos(3), ...
    parentPos(2) + 0.50 * parentPos(4), ...
    0.34 * parentPos(3), ...
    0.34 * parentPos(4)];
insetAx = axes('Parent', parentFigure, 'Position', insetPos);
edges = localHistogramEdges(values, 16, 40);
histogram(insetAx, values, edges, 'FaceColor', faceColor, 'EdgeColor', 'w', 'EdgeAlpha', 0.25); hold(insetAx, 'on');
if medianValue <= insetUpper
    xline(insetAx, medianValue, 'k-', 'LineWidth', 1.0);
end
grid(insetAx, 'on');
xlim(insetAx, [min(edges) max(edges)]);
title(insetAx, sprintf('left-end <= %.3f', insetUpper), 'FontSize', 8, 'FontWeight', 'normal');
set(insetAx, 'FontSize', 8);
box(insetAx, 'on');
end

function stableBandMap = localStableBandMap(windowTbl)
stableBandMap = containers.Map();
for i = 1:height(windowTbl)
    key = localWindowKey(localTextValue(windowTbl.recording_id(i)), localTextValue(windowTbl.subject_id(i)), ...
        localTextValue(windowTbl.condition(i)), localTextValue(windowTbl.note_window(i)));
    stableBandMap(key) = str2double(string(windowTbl.stable_band(i)));
end
end

function selected = localSelectGalleryEvents(burstTbl, stableBandMap, targets, maxEnvDelta)
selected = {};
for iKey = 1:size(targets, 1)
    subjectId = targets{iKey, 1};
    condition = targets{iKey, 2};
    isTarget = strcmp(string(burstTbl.subject_id), subjectId) & strcmp(string(burstTbl.condition), condition);
    candidates = burstTbl(isTarget, :);
    keep = false(height(candidates), 1);
    for iRow = 1:height(candidates)
        key = localWindowKey(localTextValue(candidates.recording_id(iRow)), localTextValue(candidates.subject_id(iRow)), ...
            localTextValue(candidates.condition(iRow)), localTextValue(candidates.note_window(iRow)));
        stableBand = stableBandMap(key);
        envDelta = str2double(string(candidates.env_delta(iRow)));
        keep(iRow) = envDelta >= stableBand;
        if ~isempty(maxEnvDelta)
            keep(iRow) = keep(iRow) && envDelta <= maxEnvDelta;
        end
    end
    candidates = candidates(keep, :);
    if isempty(candidates)
        continue;
    end
    [~, idx] = max(str2double(string(candidates.env_delta)));
    selected{end + 1} = candidates(idx, :); %#ok<AGROW>
end
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

function [deskIntervals, videoIntervals] = localStrictIntervalsByCondition(windowTbl, burstTbl)
[strictBursts, ~] = localStrictBurstRows(windowTbl, burstTbl);
deskIntervals = [];
videoIntervals = [];
groups = findgroups(string(strictBursts.recording_id), string(strictBursts.subject_id), string(strictBursts.condition), string(strictBursts.note_window));
for g = 1:max(groups)
    rows = strictBursts(groups == g, :);
    [~, order] = sort(str2double(string(rows.peak_sec)));
    peakSec = str2double(string(rows.peak_sec(order)));
    intervals = diff(peakSec);
    if isempty(intervals)
        continue;
    end
    condition = string(localTextValue(rows.condition(1)));
    if condition == "desk_work_stand"
        deskIntervals = [deskIntervals; intervals(:)]; %#ok<AGROW>
    elseif condition == "watching_videos_stand"
        videoIntervals = [videoIntervals; intervals(:)]; %#ok<AGROW>
    end
end
end

function recordings = localFlattenRecordings(manifest)
recordings = struct([]);
sessions = localJsonList(manifest.sessions);
for iSession = 1:numel(sessions)
    session = sessions{iSession};
    rawRecordings = localJsonList(session.recordings);
    for iRec = 1:numel(rawRecordings)
        rawRec = rawRecordings{iRec};
        rec = struct();
        rec.session_id = session.session_id;
        rec.recording_id = rawRec.recording_id;
        rec.subject_id = rawRec.subject_id;
        rec.relative_dir = rawRec.relative_dir;
        rec.file_patterns = rawRec.file_patterns;
        if isfield(rawRec, 'condition_windows')
            windowCells = localJsonList(rawRec.condition_windows);
            rec.windows = [windowCells{:}];
        else
            rec.windows = struct('condition', rawRec.condition, 'note_window', rawRec.note_window);
        end
        if isempty(recordings)
            recordings = rec;
        else
            recordings(end + 1, 1) = rec; %#ok<AGROW>
        end
    end
end
end

function values = localJsonList(value)
if iscell(value)
    values = value;
else
    if isempty(value)
        values = {};
    elseif numel(value) == 1
        values = {value};
    else
        values = num2cell(value);
    end
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

function values = localCentered(values)
values = values - median(values, 'omitnan');
end

function [center, band] = localStableBand(values)
center = median(values, 'omitnan');
band = 3 * median(abs(values - center), 'omitnan');
if band <= 0
    band = max(1e-9, iqr(values));
end
end

function window = localCenteredWindow(secondsValue, sampleRateHz)
samples = max(1, round(secondsValue * sampleRateHz));
if mod(samples, 2) == 0
    samples = samples + 1;
end
window = [floor(samples / 2), floor(samples / 2)];
end
