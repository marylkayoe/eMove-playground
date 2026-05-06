function make_waseda_envelope_spectrograms(varargin)
%MAKE_WASEDA_ENVELOPE_SPECTROGRAMS Render spectrograms for all 8 Waseda envelope windows.
%
% Outputs default to:
%   scratch/waseda_acc_matlab/spectrograms/

opts = localParseInputs(varargin{:});
if ~isfolder(opts.outputRoot)
    mkdir(opts.outputRoot);
end

manifest = loadWasedaAccManifest(opts.manifestPath);
recordings = localFlattenRecordings(manifest);

panels = struct([]);
for iRec = 1:numel(recordings)
    recording = recordings(iRec);
    if ~isfield(recording.file_patterns, opts.sensorKey)
        continue;
    end
    series = discoverWasedaAccSeries(opts.rawRoot, recording, opts.sensorKey);
    env = computeWasedaDynamicMagnitude(series, opts.envWindowSec);
    env = movmean(env, localCenteredWindow(opts.smoothSec, series.sample_rate_hz), 'Endpoints', 'shrink');
    [envAnalysis, ~, ~] = preprocessWasedaDynamicEnvelope(series.times_sec, env, ...
        'artifactThreshold', opts.artifactEnvThreshold);
    envAnalysis = envAnalysis - median(envAnalysis, 'omitnan');

    for iWin = 1:numel(recording.windows)
        window = recording.windows(iWin);
        [startSec, endSec] = parseWasedaNoteWindow(window.note_window, series.reference_abs_sec);
        idx = find(series.times_sec >= startSec & series.times_sec < endSec);
        if isempty(idx)
            continue;
        end
        row = struct();
        row.subject_id = string(recording.subject_id);
        row.condition = string(window.condition);
        row.times_min = (series.times_sec(idx) - startSec) / 60;
        row.sample_rate_hz = series.sample_rate_hz;
        row.signal = envAnalysis(idx);
        panels = localAppendStructRows(panels, row);
    end
end

panels = localSortPanels(panels);
figureHandle = figure('Color', 'w', 'Position', [80 80 1750 1450]);
t = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Waseda Chest ACC Dynamic Envelope Spectrograms', 'FontSize', 20, 'FontWeight', 'bold');
subtitle(t, sprintf('Cleaned and median-centered envelope. Window %.1fs, overlap %.1fs, freq range 0-%.1f Hz.', ...
    opts.specWindowSec, opts.specOverlapSec, opts.maxFreqHz), 'FontSize', 12);

for iPanel = 1:numel(panels)
    ax = nexttile(t);
    panel = panels(iPanel);
    localPlotSpectrogram(ax, panel, opts);
    title(ax, sprintf('%s | %s', char(panel.subject_id), strrep(strrep(char(panel.condition), '_stand', ''), '_', ' ')), ...
        'FontWeight', 'normal');
    if mod(iPanel, 2) == 1
        ylabel(ax, 'frequency (Hz)');
    end
end

xlabel(t, 'minutes from condition start');
savefig(figureHandle, fullfile(opts.outputRoot, 'waseda_envelope_spectrograms_all_conditions.fig'));
exportgraphics(figureHandle, fullfile(opts.outputRoot, 'waseda_envelope_spectrograms_all_conditions.png'), 'Resolution', 180);
close(figureHandle);

fprintf('Wrote Waseda envelope spectrograms to %s\n', opts.outputRoot);
end

function opts = localParseInputs(varargin)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
p = inputParser;
p.addParameter('manifestPath', fullfile(repoRoot, 'resources', 'waseda_acc', 'dataset_manifest.json'));
p.addParameter('rawRoot', '/Users/yoe/Documents/DATA/Waseda-ACC');
p.addParameter('outputRoot', fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'spectrograms'));
p.addParameter('sensorKey', 'chest');
p.addParameter('envWindowSec', 1.0);
p.addParameter('smoothSec', 2.0);
p.addParameter('artifactEnvThreshold', 0.5);
p.addParameter('specWindowSec', 20.0);
p.addParameter('specOverlapSec', 18.0);
p.addParameter('maxFreqHz', 3.0);
p.parse(varargin{:});
opts = p.Results;
end

function localPlotSpectrogram(ax, panel, opts)
windowSamples = max(16, round(opts.specWindowSec * panel.sample_rate_hz));
overlapSamples = min(windowSamples - 1, round(opts.specOverlapSec * panel.sample_rate_hz));
nfft = 2 ^ nextpow2(max(windowSamples, 256));
[s, f, t] = spectrogram(panel.signal, windowSamples, overlapSamples, nfft, panel.sample_rate_hz);
powerDb = 10 * log10(abs(s) .^ 2 + eps);
tMinutes = panel.times_min(1) + t / 60;
imagesc(ax, tMinutes, f, powerDb);
axis(ax, 'xy');
ylim(ax, [0 opts.maxFreqHz]);
colormap(ax, turbo);
yline(ax, 1.0, '--', 'Color', [0.95 0.95 0.95], 'LineWidth', 1.0);
grid(ax, 'on');
end

function panels = localSortPanels(panels)
if isempty(panels)
    return;
end
subjectOrder = ["sub1", "sub2", "sub3", "sub4"];
conditionOrder = ["desk_work_stand", "watching_videos_stand"];
order = zeros(numel(panels), 1);
for i = 1:numel(panels)
    sIdx = find(subjectOrder == panels(i).subject_id, 1, 'first');
    cIdx = find(conditionOrder == panels(i).condition, 1, 'first');
    order(i) = 10 * sIdx + cIdx;
end
[~, idx] = sort(order);
panels = panels(idx);
end

function samples = localCenteredWindow(secondsValue, sampleRateHz)
samples = max(1, round(secondsValue * sampleRateHz));
if mod(samples, 2) == 0
    samples = samples + 1;
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
        recordings = localAppendStructRows(recordings, rec);
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

function values = localAppendStructRows(values, newRows)
if isempty(newRows)
    return;
end
if isempty(values)
    values = newRows;
else
    values = [values; newRows]; %#ok<AGROW>
end
end
