function make_waseda_candidate_pattern_summary(varargin)
%MAKE_WASEDA_CANDIDATE_PATTERN_SUMMARY Build a MATLAB summary figure from probe outputs.
%
% Default inputs:
%   quietRoot  = scratch/waseda_acc_matlab/quiet_dynamics_probe
%   outputRoot = scratch/waseda_acc_matlab/summary

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

figureHandle = figure('Color', [0.97 0.95 0.92], 'Position', [50 50 1500 1900]);
tMain = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tMain, 'Waseda chest ACC: actual candidate phasic patterns', 'FontSize', 18, 'FontWeight', 'bold');
subtitle(tMain, 'Extracted from the MATLAB Waseda quiet-dynamics port. These are candidate sparse-ACC patterns to test in better experiments, not evidence of attention loss.', 'FontSize', 11);

localPlotDriftCandidate(figureHandle, nexttile(tMain), windowTbl, seriesMap, windowMap, opts);
localPlotEventGallery(figureHandle, nexttile(tMain), windowTbl, burstTbl, seriesMap, windowMap, opts);
localPlotIntervalStructure(figureHandle, nexttile(tMain), windowTbl, burstTbl);
localPlotDistributions(figureHandle, nexttile(tMain), windowTbl, burstTbl);

exportgraphics(figureHandle, fullfile(opts.outputRoot, 'waseda_acc_actual_candidate_phasic_patterns_matlab.png'), 'Resolution', 180);
close(figureHandle);
fprintf('Wrote summary figure to %s\n', opts.outputRoot);
end

function opts = localParseInputs(varargin)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
p = inputParser;
p.addParameter('manifestPath', fullfile(repoRoot, 'resources', 'waseda_acc', 'dataset_manifest.json'));
p.addParameter('rawRoot', '/Users/yoe/Documents/DATA/Waseda-ACC');
p.addParameter('quietRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'quiet_dynamics_probe'));
p.addParameter('outputRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'summary'));
p.addParameter('sensorKey', 'chest');
p.addParameter('envWindowSec', 1.0);
p.addParameter('smoothSec', 2.0);
p.addParameter('eventContextSec', 20.0);
p.addParameter('artifactEnvThreshold', 0.5);
p.parse(varargin{:});
opts = p.Results;
end

function localPlotDriftCandidate(parentFig, placeholderAx, windowTbl, seriesMap, windowMap, opts)
target = windowTbl(strcmp(string(windowTbl.sensor), opts.sensorKey) & ...
    strcmp(string(windowTbl.subject_id), "sub1") & ...
    strcmp(string(windowTbl.condition), "watching_videos_stand"), :);
[~, idx] = max(abs(str2double(string(target.first_to_last_env_median_delta_over_stable_band))));
row = target(idx, :);
key = localWindowKey(localTextValue(row.recording_id), localTextValue(row.subject_id), localTextValue(row.condition), localTextValue(row.note_window));
payload = seriesMap(key);
windowSec = windowMap(key);
series = payload.series;
envAnalysis = payload.envAnalysis;
envDisplay = payload.envDisplay;
startSec = windowSec(1);
endSec = windowSec(2);
idxs = find(series.times_sec >= startSec & series.times_sec < endSec);
minutes = (series.times_sec(idxs) - startSec) / 60;
[center, band] = localStableBand(envAnalysis(idxs));

t = localCreatePanelLayout(parentFig, placeholderAx, 3, 1);
title(t, '1. Slow drift candidate in actual signal', 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
subtitle(t, sprintf('Waseda chest ACC actual signal: sub1 video drift candidate | %s-%s; first-last env drift = %.3f stable-band widths', ...
    formatWasedaAbsoluteClockLabel(series.reference_abs_sec + startSec, true), ...
    formatWasedaAbsoluteClockLabel(series.reference_abs_sec + endSec, true), ...
    str2double(string(row.first_to_last_env_median_delta_over_stable_band))), 'FontSize', 10);

ax1 = nexttile(t);
plot(ax1, minutes, localCentered(series.ax(idxs)), 'Color', [0.30 0.47 0.65], 'LineWidth', 0.6); hold(ax1, 'on');
plot(ax1, minutes, localCentered(series.ay(idxs)), 'Color', [0.96 0.52 0.13], 'LineWidth', 0.6);
plot(ax1, minutes, localCentered(series.az(idxs)), 'Color', [0.33 0.64 0.33], 'LineWidth', 0.6);
ylabel(ax1, {'raw ACC axes', 'centered (g)'});
legend(ax1, {'X', 'Y', 'Z'}, 'Location', 'northeastoutside', 'Orientation', 'horizontal');
grid(ax1, 'on');

ax2 = nexttile(t);
rawMag = sqrt(series.ax(idxs).^2 + series.ay(idxs).^2 + series.az(idxs).^2);
plot(ax2, minutes, localCentered(rawMag), 'Color', [0.35 0.35 0.35], 'LineWidth', 0.7);
ylabel(ax2, {'raw magnitude', 'centered (g)'});
grid(ax2, 'on');

ax3 = nexttile(t);
plot(ax3, minutes, envDisplay(idxs), 'k', 'LineWidth', 0.8); hold(ax3, 'on');
yline(ax3, center, '-', 'Color', [0.30 0.47 0.65], 'LineWidth', 1.0);
patch(ax3, [minutes(1) minutes(end) minutes(end) minutes(1)], [center-band center-band center+band center+band], ...
    [0.30 0.47 0.65], 'FaceAlpha', 0.12, 'EdgeColor', 'none');
ylabel(ax3, 'dynamic envelope');
xlabel(ax3, 'minutes from condition start');
grid(ax3, 'on');
ylim(ax3, [0 localRobustUpperLimit(envDisplay(idxs), center, band)]);
end

function localPlotEventGallery(parentFig, placeholderAx, windowTbl, burstTbl, seriesMap, windowMap, opts)
t = localCreatePanelLayout(parentFig, placeholderAx, 5, 2);
title(t, '2. Candidate departures with baseline and recovery', 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
subtitle(t, 'Artifact-screened examples show transient departures from baseline with measurable return times, rather than only raw stillness or arbitrary threshold crossings.', 'FontSize', 10);

stableBandMap = containers.Map();
for i = 1:height(windowTbl)
    key = localWindowKey(windowTbl.recording_id{i}, windowTbl.subject_id{i}, windowTbl.condition{i}, windowTbl.note_window{i});
    stableBandMap(key) = str2double(string(windowTbl.stable_band(i)));
end
targets = {
    "sub1", "watching_videos_stand";
    "sub2", "watching_videos_stand";
    "sub3", "watching_videos_stand";
    "sub4", "desk_work_stand";
    };
selectedRows = localSelectGalleryEvents(burstTbl, stableBandMap, targets, 0.10);
for iRow = 1:size(targets, 1)
    if iRow > numel(selectedRows)
        break;
    end
    event = selectedRows{iRow};
    key = localWindowKey(localTextValue(event.recording_id), localTextValue(event.subject_id), localTextValue(event.condition), localTextValue(event.note_window));
    payload = seriesMap(key);
    windowSec = windowMap(key);
    series = payload.series;
    envAnalysis = payload.envAnalysis;
    envDisplay = payload.envDisplay;
    [center, band] = localStableBand(envAnalysis(series.times_sec >= windowSec(1) & series.times_sec < windowSec(2)));
    peakSec = str2double(string(event.peak_sec));
    leftSec = max(windowSec(1), peakSec - opts.eventContextSec);
    rightSec = min(windowSec(2), peakSec + opts.eventContextSec);
    idxs = find(series.times_sec >= leftSec & series.times_sec < rightSec);
    x = series.times_sec(idxs) - peakSec;

    axRaw = nexttile(t);
    plot(axRaw, x, localCentered(series.ax(idxs)), 'Color', [0.30 0.47 0.65], 'LineWidth', 0.7); hold(axRaw, 'on');
    plot(axRaw, x, localCentered(series.ay(idxs)), 'Color', [0.96 0.52 0.13], 'LineWidth', 0.7);
    plot(axRaw, x, localCentered(series.az(idxs)), 'Color', [0.33 0.64 0.33], 'LineWidth', 0.7);
    xline(axRaw, 0, 'r-', 'LineWidth', 0.8);
    grid(axRaw, 'on');
    ylabel(axRaw, {'raw axes', 'centered (g)'});
    if iRow == 1
        legend(axRaw, {'X', 'Y', 'Z'}, 'Location', 'northeastoutside', 'Orientation', 'horizontal');
    end
    title(axRaw, sprintf('%s %s %s | delta=%.4f, return=%ss', ...
        localTextValue(event.subject_id), strrep(strrep(localTextValue(event.condition), '_stand', ''), '_', ' '), ...
        localTextValue(event.peak_clock), str2double(string(event.env_delta)), localTextValue(event.return_time_sec)), ...
        'FontSize', 9, 'FontWeight', 'normal', 'HorizontalAlignment', 'left');

    axEnv = nexttile(t);
    plot(axEnv, x, envDisplay(idxs), 'k', 'LineWidth', 0.9); hold(axEnv, 'on');
    patch(axEnv, [x(1) x(end) x(end) x(1)], [center-band center-band center+band center+band], ...
        [0.30 0.47 0.65], 'FaceAlpha', 0.12, 'EdgeColor', 'none');
    yline(axEnv, center, '-', 'Color', [0.30 0.47 0.65], 'LineWidth', 0.8);
    xline(axEnv, 0, 'r-', 'LineWidth', 0.8);
    scatter(axEnv, 0, str2double(string(event.peak_env)), 16, 'r', 'filled');
    grid(axEnv, 'on');
    ylabel(axEnv, 'dynamic envelope');
    xlabel(axEnv, 'seconds from candidate peak');
    ylim(axEnv, [0 localRobustUpperLimit(envDisplay(idxs), center, band)]);
end
end

function localPlotIntervalStructure(parentFig, placeholderAx, windowTbl, burstTbl)
t = localCreatePanelLayout(parentFig, placeholderAx, 2, 1);
title(t, '3. Inter-event interval structure', 'FontWeight', 'bold', 'HorizontalAlignment', 'left');

[deskIntervals, videoIntervals] = localStrictIntervalsByCondition(windowTbl, burstTbl);
ax1 = nexttile(t);
edges = logspace(-1, 2.6, 24);
histogram(ax1, deskIntervals, edges, 'FaceColor', [0.30 0.47 0.65], 'FaceAlpha', 0.55, 'EdgeAlpha', 0.2); hold(ax1, 'on');
histogram(ax1, videoIntervals, edges, 'FaceColor', [0.96 0.52 0.13], 'FaceAlpha', 0.55, 'EdgeAlpha', 0.2);
xline(ax1, median(deskIntervals, 'omitnan'), '-', 'Color', [0.30 0.47 0.65], 'LineWidth', 1.2);
xline(ax1, median(videoIntervals, 'omitnan'), '-', 'Color', [0.96 0.52 0.13], 'LineWidth', 1.2);
set(ax1, 'XScale', 'log');
ylabel(ax1, 'count');
legend(ax1, {sprintf('desk work (n=%d)', numel(deskIntervals)), sprintf('watching videos (n=%d)', numel(videoIntervals))}, 'Location', 'northeast');
grid(ax1, 'on');

ax2 = nexttile(t);
[fDesk, xDesk] = ecdf(deskIntervals);
[fVideo, xVideo] = ecdf(videoIntervals);
plot(ax2, xDesk, fDesk, 'Color', [0.30 0.47 0.65], 'LineWidth', 1.4); hold(ax2, 'on');
plot(ax2, xVideo, fVideo, 'Color', [0.96 0.52 0.13], 'LineWidth', 1.4);
set(ax2, 'XScale', 'log');
xlabel(ax2, 'inter-departure interval (s)');
ylabel(ax2, 'ECDF');
legend(ax2, {sprintf('desk work median=%.1fs', median(deskIntervals, 'omitnan')), sprintf('watching videos median=%.1fs', median(videoIntervals, 'omitnan'))}, 'Location', 'southeast');
grid(ax2, 'on');
text(ax2, 0.01, -0.28, 'Aggregate strict-departure intervals differ in distribution between desk and video in this preliminary dataset, but the subject-level heterogeneity is still large.', ...
    'Units', 'normalized', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
end

function localPlotDistributions(parentFig, placeholderAx, windowTbl, burstTbl)
t = localCreatePanelLayout(parentFig, placeholderAx, 1, 3);
title(t, '4. Departure duration and amplitude distributions', 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
[strictBursts, ~] = localStrictBurstRows(windowTbl, burstTbl);
durations = str2double(string(strictBursts.duration_sec));
amplitudes = str2double(string(strictBursts.env_delta));
returns = str2double(string(strictBursts.return_time_sec));
returns = returns(~isnan(returns));

ax1 = nexttile(t);
durationEdges = linspace(0, 2.0, 26);
histogram(ax1, durations, durationEdges, 'FaceColor', [0.30 0.47 0.65], 'EdgeAlpha', 0.2);
xlabel(ax1, 'departure duration (s)');
ylabel(ax1, 'count');
title(ax1, sprintf('n=%d\nmedian=%.3f', numel(durations), median(durations, 'omitnan')));
grid(ax1, 'on');
xlim(ax1, [0 2.0]);

ax2 = nexttile(t);
amplitudeEdges = linspace(0, 0.05, 21);
histogram(ax2, amplitudes, amplitudeEdges, 'FaceColor', [0.96 0.52 0.13], 'EdgeAlpha', 0.2);
xlabel(ax2, 'departure amplitude above baseline');
title(ax2, sprintf('n=%d\nmedian=%.3f', numel(amplitudes), median(amplitudes, 'omitnan')));
grid(ax2, 'on');
xlim(ax2, [0 0.05]);

ax3 = nexttile(t);
returnEdges = linspace(0, 5.0, 26);
histogram(ax3, returns, returnEdges, 'FaceColor', [0.33 0.64 0.33], 'EdgeAlpha', 0.2);
xlabel(ax3, 'return-to-baseline time (s)');
title(ax3, sprintf('n=%d\nmedian=%.3f', numel(returns), median(returns, 'omitnan')));
grid(ax3, 'on');
xlim(ax3, [0 5.0]);
text(ax1, 0.0, -0.24, 'These tighter histograms use only strict artifact-screened departures, with x-ranges chosen to show the informative part of the distribution rather than the extreme tail.', ...
    'Units', 'normalized', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
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

function t = localCreatePanelLayout(parentFig, placeholderAx, nRows, nCols)
panel = uipanel('Parent', parentFig, ...
    'Units', placeholderAx.Units, ...
    'Position', placeholderAx.Position, ...
    'BorderType', 'none', ...
    'BackgroundColor', [0.97 0.95 0.92]);
delete(placeholderAx);
t = tiledlayout(panel, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
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
stableBandByWindow = containers.Map();
for i = 1:height(windowTbl)
    key = localWindowKey(windowTbl.recording_id{i}, windowTbl.subject_id{i}, windowTbl.condition{i}, windowTbl.note_window{i});
    stableBandByWindow(key) = str2double(string(windowTbl.stable_band(i)));
end
keep = false(height(burstTbl), 1);
for i = 1:height(burstTbl)
    if strlength(string(burstTbl.event_id{i})) == 0
        continue;
    end
    key = localWindowKey(burstTbl.recording_id{i}, burstTbl.subject_id{i}, burstTbl.condition{i}, burstTbl.note_window{i});
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
