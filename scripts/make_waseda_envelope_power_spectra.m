function make_waseda_envelope_power_spectra(varargin)
%MAKE_WASEDA_ENVELOPE_POWER_SPECTRA Render power spectra for all 8 Waseda envelope windows.
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
        row.sample_rate_hz = series.sample_rate_hz;
        row.signal = envAnalysis(idx);
        panels = localAppendStructRows(panels, row);
    end
end

panels = localSortPanels(panels);
figureHandle = figure('Color', 'w', 'Position', [80 80 1750 1450]);
t = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Waseda Chest ACC Dynamic Envelope Power Spectra', 'FontSize', 20, 'FontWeight', 'bold');
subtitle(t, sprintf('Cleaned and median-centered envelope. Dashed line marks 1 Hz = 60 bpm. Displayed range 0-%.1f Hz.', ...
    opts.maxFreqHz), 'FontSize', 12);

for iPanel = 1:numel(panels)
    ax = nexttile(t);
    panel = panels(iPanel);
    localPlotSpectrum(ax, panel, opts);
    title(ax, sprintf('%s | %s', char(panel.subject_id), strrep(strrep(char(panel.condition), '_stand', ''), '_', ' ')), ...
        'FontWeight', 'normal');
    if mod(iPanel, 2) == 1
        ylabel(ax, 'power / Hz');
    end
end

xlabel(t, 'frequency (Hz)');
savefig(figureHandle, fullfile(opts.outputRoot, 'waseda_envelope_power_spectra_all_conditions.fig'));
exportgraphics(figureHandle, fullfile(opts.outputRoot, 'waseda_envelope_power_spectra_all_conditions.png'), 'Resolution', 180);
close(figureHandle);

fprintf('Wrote Waseda envelope power spectra to %s\n', opts.outputRoot);
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
p.addParameter('maxFreqHz', 3.0);
p.parse(varargin{:});
opts = p.Results;
end

function localPlotSpectrum(ax, panel, opts)
[pxx, f] = pwelch(panel.signal, [], [], [], panel.sample_rate_hz);
keep = f <= opts.maxFreqHz;
plot(ax, f(keep), pxx(keep), 'k', 'LineWidth', 1.2); hold(ax, 'on');
xline(ax, 1.0, '--', 'Color', [0.75 0.15 0.15], 'LineWidth', 1.1);
grid(ax, 'on');
xlim(ax, [0 opts.maxFreqHz]);
set(ax, 'YScale', 'log');
peakMask = f > 0 & f <= opts.maxFreqHz;
if any(peakMask)
    [~, idx] = max(pxx(peakMask));
    fSel = f(peakMask);
    pSel = pxx(peakMask);
    peakFreq = fSel(idx);
    peakPower = pSel(idx);
    scatter(ax, peakFreq, peakPower, 18, [0.15 0.35 0.75], 'filled');
    text(ax, peakFreq, peakPower, sprintf('  %.2f Hz', peakFreq), 'FontSize', 8, 'Color', [0.15 0.35 0.75]);
end
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
