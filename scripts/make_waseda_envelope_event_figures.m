function make_waseda_envelope_event_figures(varargin)
%MAKE_WASEDA_ENVELOPE_EVENT_FIGURES Render zoomable MATLAB figures of envelopes and events.
%
% Outputs default to:
%   scratch/waseda_acc_matlab/envelope_event_figures/

opts = localParseInputs(varargin{:});
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

localMakeConditionFigure('desk_work_stand', 'desk', windowTbl, burstTbl, seriesMap, windowMap, opts);
localMakeConditionFigure('watching_videos_stand', 'video', windowTbl, burstTbl, seriesMap, windowMap, opts);
localMakeConditionFigure('', 'all_conditions', windowTbl, burstTbl, seriesMap, windowMap, opts);

fprintf('Wrote Waseda envelope/event figures to %s\n', opts.outputRoot);
end

function opts = localParseInputs(varargin)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
p = inputParser;
p.addParameter('manifestPath', fullfile(repoRoot, 'resources', 'waseda_acc', 'dataset_manifest.json'));
p.addParameter('rawRoot', '/Users/yoe/Documents/DATA/Waseda-ACC');
p.addParameter('quietRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'quiet_dynamics_probe'));
p.addParameter('outputRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'envelope_event_figures'));
p.addParameter('sensorKey', 'chest');
p.addParameter('envWindowSec', 1.0);
p.addParameter('smoothSec', 2.0);
p.addParameter('artifactEnvThreshold', 0.5);
p.parse(varargin{:});
opts = p.Results;
end

function localMakeConditionFigure(conditionName, fileStem, windowTbl, burstTbl, seriesMap, windowMap, opts)
subjectOrder = {'sub1', 'sub2', 'sub3', 'sub4'};
windowRows = localSelectWindowRows(windowTbl, conditionName, subjectOrder, opts.sensorKey);
if isempty(windowRows)
    return;
end

figureHandle = figure('Color', 'w', 'Position', [80 80 1700 1100]);
axisCount = numel(windowRows);
t = tiledlayout(axisCount, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
if isempty(conditionName)
    titleText = 'Waseda chest ACC dynamic envelopes and identified events';
    subtitleText = 'All work and video windows. Red circles = all candidate events. Dark markers = strict events (env delta >= stable band).';
else
    titleText = sprintf('Waseda chest ACC dynamic envelopes and identified events: %s', strrep(strrep(conditionName, '_stand', ''), '_', ' '));
    subtitleText = 'Red circles = all candidate events. Dark markers = strict events (env delta >= stable band).';
end
title(t, titleText, 'FontSize', 20, 'FontWeight', 'bold');
subtitle(t, subtitleText, 'FontSize', 12);

for iRow = 1:numel(windowRows)
    row = windowRows(iRow);
    key = localWindowKey(localTextValue(row.recording_id), localTextValue(row.subject_id), localTextValue(row.condition), localTextValue(row.note_window));
    payload = seriesMap(key);
    windowSec = windowMap(key);
    series = payload.series;
    envAnalysis = payload.envAnalysis;
    envDisplay = payload.envDisplay;
    idxs = find(series.times_sec >= windowSec(1) & series.times_sec < windowSec(2));
    xMinutes = (series.times_sec(idxs) - windowSec(1)) / 60;
    envValues = envDisplay(idxs);
    envCenter = str2double(string(row.env_center));
    stableBand = str2double(string(row.stable_band));
    ylimUpper = localRobustUpperLimit(envDisplay(idxs), envCenter, stableBand);
    ylimLower = 0;

    ax = nexttile(t);
    patch(ax, [xMinutes(1) xMinutes(end) xMinutes(end) xMinutes(1)], ...
        [envCenter - stableBand envCenter - stableBand envCenter + stableBand envCenter + stableBand], ...
        [0.30 0.47 0.65], 'FaceAlpha', 0.10, 'EdgeColor', 'none'); hold(ax, 'on');
    plot(ax, xMinutes, envValues, 'k', 'LineWidth', 0.9);
    yline(ax, envCenter, '-', 'Color', [0.30 0.47 0.65], 'LineWidth', 0.9);

    eventRows = localSelectEventRows(burstTbl, row);
    if ~isempty(eventRows)
        eventStartSec = str2double(string({eventRows.start_sec}));
        eventEndSec = str2double(string({eventRows.end_sec}));
        eventPeakSec = str2double(string({eventRows.peak_sec}));
        eventPeakEnv = str2double(string({eventRows.peak_env}));
        eventPeakEnv = min(eventPeakEnv, ylimUpper * 0.98);
        eventStartMin = (eventStartSec - windowSec(1)) / 60;
        eventEndMin = (eventEndSec - windowSec(1)) / 60;
        eventXMinutes = (eventPeakSec - windowSec(1)) / 60;
        localPlotDurationBars(ax, eventStartMin, eventEndMin, ylimLower, ylimUpper);
        scatter(ax, eventXMinutes, eventPeakEnv, 18, [0.86 0.18 0.18], 'o', ...
            'MarkerFaceColor', [0.86 0.18 0.18], 'MarkerFaceAlpha', 0.45, 'MarkerEdgeAlpha', 0.45);

        strictMask = localStrictEventMask(eventRows, stableBand);
        if any(strictMask)
            scatter(ax, eventXMinutes(strictMask), eventPeakEnv(strictMask), 24, [0.45 0.00 0.00], '^', ...
                'MarkerFaceColor', [0.45 0.00 0.00], 'MarkerEdgeColor', [0.45 0.00 0.00]);
        end
    end

    grid(ax, 'on');
    ylabel(ax, 'dynamic envelope');
    ylim(ax, [ylimLower ylimUpper]);
    title(ax, sprintf('%s | %s | all=%d, strict=%d, drift=%.2f band widths', ...
        localTextValue(row.subject_id), strrep(strrep(localTextValue(row.condition), '_stand', ''), '_', ' '), ...
        str2double(string(row.candidate_burst_count)), str2double(string(row.strict_burst_count)), ...
        str2double(string(row.first_to_last_env_median_delta_over_stable_band))), ...
        'FontWeight', 'normal', 'HorizontalAlignment', 'left');
    if iRow == 1
        legend(ax, {'stable band', 'dynamic envelope', 'window median', 'compound duration', 'candidate event', 'strict event'}, ...
            'Location', 'northeastoutside', 'Box', 'off');
    end
end

xlabel(t, 'minutes from condition start');
savefig(figureHandle, fullfile(opts.outputRoot, sprintf('waseda_envelopes_events_%s.fig', fileStem)));
exportgraphics(figureHandle, fullfile(opts.outputRoot, sprintf('waseda_envelopes_events_%s.png', fileStem)), 'Resolution', 180);
close(figureHandle);
end

function rows = localSelectWindowRows(windowTbl, conditionName, subjectOrder, sensorKey)
mask = strcmp(string(windowTbl.sensor), sensorKey);
if ~isempty(conditionName)
    mask = mask & strcmp(string(windowTbl.condition), conditionName);
end
tbl = windowTbl(mask, :);
rows = table2struct(tbl);
orderedRows = struct([]);
for iSubject = 1:numel(subjectOrder)
    matches = rows(strcmp(string({rows.subject_id}), subjectOrder{iSubject}));
    if isempty(matches)
        continue;
    end
    if isempty(orderedRows)
        orderedRows = matches;
    else
        orderedRows = [orderedRows; matches(:)]; %#ok<AGROW>
    end
end
rows = orderedRows;
end

function eventRows = localSelectEventRows(burstTbl, row)
mask = strcmp(string(burstTbl.recording_id), localTextValue(row.recording_id)) & ...
    strcmp(string(burstTbl.subject_id), localTextValue(row.subject_id)) & ...
    strcmp(string(burstTbl.condition), localTextValue(row.condition)) & ...
    strcmp(string(burstTbl.note_window), localTextValue(row.note_window));
    eventRows = table2struct(burstTbl(mask, :));
end

function strictMask = localStrictEventMask(eventRows, stableBand)
strictMask = false(numel(eventRows), 1);
for iEvent = 1:numel(eventRows)
    strictMask(iEvent) = str2double(string(eventRows(iEvent).env_delta)) >= stableBand;
end
end

function localPlotDurationBars(ax, startMin, endMin, ylimLower, ylimUpper)
barBottom = ylimLower + 0.90 * (ylimUpper - ylimLower);
barTop = ylimLower + 0.97 * (ylimUpper - ylimLower);
for iEvent = 1:numel(startMin)
    patch(ax, [startMin(iEvent) endMin(iEvent) endMin(iEvent) startMin(iEvent)], ...
        [barBottom barBottom barTop barTop], [0.60 0.10 0.10], ...
        'FaceAlpha', 0.18, 'EdgeColor', 'none');
end
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

function window = localCenteredWindow(secondsValue, sampleRateHz)
samples = max(1, round(secondsValue * sampleRateHz));
if mod(samples, 2) == 0
    samples = samples + 1;
end
window = [floor(samples / 2), floor(samples / 2)];
end
