function run_waseda_quiet_dynamics_probe(varargin)
%RUN_WASEDA_QUIET_DYNAMICS_PROBE Port of the Waseda quiet-dynamics Python probe.
%
% Default outputs go under:
%   scratch/waseda_acc_matlab/quiet_dynamics_probe/

opts = localParseInputs(varargin{:});
manifest = loadWasedaAccManifest(opts.manifestPath);
recordings = localFlattenRecordings(manifest);
if ~isfolder(opts.rawRoot)
    error('Raw Waseda ACC root not found: %s', opts.rawRoot);
end
if ~isfolder(opts.outputRoot)
    mkdir(opts.outputRoot);
end

windowRows = struct([]);
epochRows = struct([]);
burstRows = struct([]);

for iRec = 1:numel(recordings)
    recording = recordings(iRec);
    sensors = localResolveSensors(recording, opts.sensorMode);
    for iSensor = 1:numel(sensors)
        sensorKey = sensors{iSensor};
        series = discoverWasedaAccSeries(opts.rawRoot, recording, sensorKey);
        env = computeWasedaDynamicMagnitude(series, opts.envWindowSec);
        envSmooth = localRollingMeanCentered(env, localSamplesForSeconds(series.sample_rate_hz, opts.smoothSec));
        [envSmooth, ~, ~] = preprocessWasedaDynamicEnvelope(series.times_sec, envSmooth, ...
            'artifactThreshold', opts.artifactEnvThreshold);
        envRate = localAbsDerivative(series.times_sec, envSmooth);

        for iWin = 1:numel(recording.windows)
            window = recording.windows(iWin);
            [startSec, endSec] = parseWasedaNoteWindow(window.note_window, series.reference_abs_sec);
            idxs = find(series.times_sec >= startSec & series.times_sec < endSec);
            if isempty(idxs)
                continue;
            end
            windowEnv = envSmooth(idxs);
            windowRate = envRate(idxs);
            artifactMask = windowEnv >= opts.artifactEnvThreshold;
            stableMask = localStableReferenceMask(windowEnv, artifactMask, opts);
            stableEnv = windowEnv(stableMask);
            if isempty(stableEnv)
                stableEnv = windowEnv(~artifactMask);
            end
            if isempty(stableEnv)
                stableEnv = windowEnv;
            end
            envCenter = median(stableEnv);
            envMad = localMedianAbsDeviation(stableEnv, envCenter);
            stableUpper = quantile(stableEnv, opts.stableUpperQuantile);
            stableBand = max(stableUpper - envCenter, opts.stableMadMultiplier * envMad);
            if stableBand <= 0
                stableBand = max(1e-9, iqr(stableEnv));
            end
            burstThreshold = envCenter + stableBand;
            bursts = localDetectStableBandDepartures(series, envSmooth, envRate, idxs, envCenter, stableBand, artifactMask, opts);
            currentEpochRows = localBuildEpochRows(series, window, startSec, endSec, envSmooth, envRate, ...
                envCenter, stableBand, bursts, opts);
            epochRows = localAppendStructRows(epochRows, currentEpochRows);
            windowRows = localAppendStructRows(windowRows, ...
                localWindowSummaryRow(series, window, startSec, endSec, windowEnv, windowRate, ...
                envCenter, envMad, stableBand, burstThreshold, bursts, currentEpochRows));
            currentBurstRows = localBuildBurstRows(series, window, bursts);
            burstRows = localAppendStructRows(burstRows, currentBurstRows);
        end
    end
end

localWriteStructCsv(fullfile(opts.outputRoot, 'quiet_window_summary.csv'), windowRows);
localWriteStructCsv(fullfile(opts.outputRoot, 'quiet_epoch_summary.csv'), epochRows);
if isempty(burstRows)
    burstRows = localEmptyBurstRow();
end
localWriteStructCsv(fullfile(opts.outputRoot, 'quiet_burst_events.csv'), burstRows);
localWriteRunManifest(fullfile(opts.outputRoot, 'run_manifest.json'), opts, numel(windowRows), numel(epochRows), numel(burstRows));

fprintf('Wrote Waseda quiet-dynamics probe outputs to %s\n', opts.outputRoot);
fprintf('Window rows: %d\n', numel(windowRows));
fprintf('Epoch rows: %d\n', numel(epochRows));
fprintf('Burst rows: %d\n', numel(burstRows));
end

function opts = localParseInputs(varargin)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
defaultManifest = fullfile(repoRoot, 'resources', 'waseda_acc', 'dataset_manifest.json');
defaultRawRoot = '/Users/yoe/Documents/DATA/Waseda-ACC';
defaultOutputRoot = fullfile(repoRoot, 'scratch', 'waseda_acc_matlab', 'quiet_dynamics_probe');
p = inputParser;
p.addParameter('manifestPath', defaultManifest, @(x) ischar(x) || isstring(x));
p.addParameter('rawRoot', defaultRawRoot, @(x) ischar(x) || isstring(x));
p.addParameter('outputRoot', defaultOutputRoot, @(x) ischar(x) || isstring(x));
p.addParameter('sensorMode', 'chest', @(x) any(strcmp(x, {'chest', 'forearm_left', 'both'})));
p.addParameter('envWindowSec', 1.0, @isscalar);
p.addParameter('smoothSec', 2.0, @isscalar);
p.addParameter('epochSec', 60.0, @isscalar);
p.addParameter('stableMadMultiplier', 3.0, @isscalar);
p.addParameter('burstQuantile', 0.99, @isscalar);
p.addParameter('burstMadMultiplier', 6.0, @isscalar);
p.addParameter('burstMergeGapSec', 0.30, @isscalar);
p.addParameter('burstContextSec', 5.0, @isscalar);
p.addParameter('returnWindowSec', 12.0, @isscalar);
p.addParameter('minBurstDurationSec', 0.01, @isscalar);
p.addParameter('compoundMergeGapSec', 0.35, @isscalar);
p.addParameter('stableGapToleranceSec', 0.05, @isscalar);
p.addParameter('artifactEnvThreshold', 0.50, @isscalar);
p.addParameter('stableReferenceQuantile', 0.80, @isscalar);
p.addParameter('stableUpperQuantile', 0.95, @isscalar);
p.addParameter('supportBandFraction', 0.00, @isscalar);
p.parse(varargin{:});
opts = p.Results;
opts.manifestPath = char(opts.manifestPath);
opts.rawRoot = char(opts.rawRoot);
opts.outputRoot = char(opts.outputRoot);
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

function sensors = localResolveSensors(recording, sensorMode)
if strcmp(sensorMode, 'both')
    names = fieldnames(recording.file_patterns);
    sensors = reshape(names, 1, []);
else
    sensors = {sensorMode};
end
end

function samples = localSamplesForSeconds(sampleRateHz, secondsValue)
samples = max(1, round(secondsValue * sampleRateHz));
if mod(samples, 2) == 0
    samples = samples + 1;
end
end

function valuesOut = localRollingMeanCentered(valuesIn, windowSamples)
halfWindow = floor(windowSamples / 2);
valuesOut = movmean(valuesIn, [halfWindow, halfWindow], 'Endpoints', 'shrink');
end

function rate = localAbsDerivative(timesSec, values)
rate = zeros(size(values));
dt = diff(timesSec);
dv = diff(values);
valid = dt > 0;
rate(2:end) = 0;
rate(find(valid) + 1) = abs(dv(valid) ./ dt(valid));
end

function madValue = localMedianAbsDeviation(values, centerValue)
if nargin < 2 || isempty(centerValue)
    centerValue = median(values);
end
madValue = median(abs(values - centerValue));
end

function stableMask = localStableReferenceMask(windowEnv, artifactMask, opts)
stableMask = ~artifactMask;
if ~any(stableMask)
    stableMask = true(size(windowEnv));
    return;
end
cutoff = quantile(windowEnv(~artifactMask), opts.stableReferenceQuantile);
stableMask = stableMask & (windowEnv <= cutoff);
if ~any(stableMask)
    stableMask = ~artifactMask;
end
end

function bursts = localDetectStableBandDepartures(series, env, envRate, idxs, envCenter, stableBand, windowArtifactMask, opts)
upperThreshold = envCenter + stableBand;
lowerThreshold = envCenter + opts.supportBandFraction * stableBand;
supportMask = false(size(series.times_sec));
windowSupportMask = env(idxs) > lowerThreshold;
windowSupportMask(windowArtifactMask) = false;
supportMask(idxs) = windowSupportMask;
supportMask = localFillShortFalseGaps(series.times_sec, supportMask, opts.stableGapToleranceSec);
runs = localMaskToRuns(supportMask);
rawBursts = struct([]);
for iRun = 1:size(runs, 1)
    startIdx = runs(iRun, 1);
    endIdx = runs(iRun, 2);
    runMask = idxs >= startIdx & idxs <= endIdx;
    runArtifactMask = windowArtifactMask(runMask);
    if any(runArtifactMask)
        continue;
    end
    if ~any(env(startIdx:endIdx) > upperThreshold)
        continue;
    end
    [~, peakOffset] = max(env(startIdx:endIdx));
    peakIdx = startIdx + peakOffset - 1;
    baselineEnv = envCenter;
    envDelta = max(0, env(peakIdx) - baselineEnv);
    areaDelta = 0;
    for idx = startIdx:endIdx
        areaDelta = areaDelta + max(0, env(idx) - baselineEnv) * localDt(series.times_sec, idx);
    end
    returnTimeSec = localEstimateReturnTime(series.times_sec, env, peakIdx, baselineEnv, envDelta, opts.returnWindowSec, stableBand);
    row = struct();
    row.start_idx = startIdx;
    row.end_idx = endIdx;
    row.peak_idx = peakIdx;
    row.start_sec = series.times_sec(startIdx);
    row.end_sec = series.times_sec(endIdx);
    row.peak_sec = series.times_sec(peakIdx);
    row.duration_sec = max(0, series.times_sec(endIdx) - series.times_sec(startIdx));
    row.peak_rate = envRate(peakIdx);
    row.peak_env = env(peakIdx);
    row.baseline_env = baselineEnv;
    row.env_delta = envDelta;
    row.area_env_delta = areaDelta;
    row.return_time_sec = returnTimeSec;
    rawBursts = localAppendStructRows(rawBursts, row);
end

bursts = localMergeBurstsWithoutRecovery(rawBursts, env, envRate, series.times_sec, stableBand, opts);
bursts = bursts(arrayfun(@(burst) burst.peak_env < opts.artifactEnvThreshold, bursts));
bursts = bursts(arrayfun(@(burst) burst.duration_sec >= opts.minBurstDurationSec, bursts));
end

function dt = localDt(timesSec, idx)
if idx <= 1
    if numel(timesSec) > 1
        dt = timesSec(2) - timesSec(1);
    else
        dt = 0;
    end
else
    dt = max(0, timesSec(idx) - timesSec(idx - 1));
end
end

function returnTimeSec = localEstimateReturnTime(timesSec, env, peakIdx, baselineEnv, envDelta, returnWindowSec, stableBand)
if envDelta <= 0
    returnTimeSec = 0;
    return;
end
target = baselineEnv + stableBand;
peakTime = timesSec(peakIdx);
candidateIdxs = find(timesSec >= peakTime & timesSec <= peakTime + returnWindowSec);
returnTimeSec = NaN;
for iIdx = 1:numel(candidateIdxs)
    idx = candidateIdxs(iIdx);
    if env(idx) <= target
        returnTimeSec = max(0, timesSec(idx) - peakTime);
        return;
    end
end
end

function burstsOut = localMergeBurstsWithoutRecovery(burstsIn, env, envRate, timesSec, stableBand, opts)
if isempty(burstsIn)
    burstsOut = burstsIn;
    return;
end

burstsOut = burstsIn(1);
for iBurst = 2:numel(burstsIn)
    currentBurst = burstsIn(iBurst);
    previousBurst = burstsOut(end);
    if localShouldMergeBursts(previousBurst, currentBurst, env, timesSec, stableBand, opts)
        mergedBurst = localBuildMergedBurst(previousBurst, currentBurst, env, envRate, timesSec, stableBand, opts);
        burstsOut(end) = mergedBurst;
    else
        burstsOut(end + 1) = currentBurst; %#ok<AGROW>
    end
end
end

function shouldMerge = localShouldMergeBursts(firstBurst, secondBurst, env, timesSec, stableBand, opts)
gapSec = secondBurst.start_sec - firstBurst.end_sec;
betweenIdx = firstBurst.end_idx:secondBurst.start_idx;
if any(env(betweenIdx) >= opts.artifactEnvThreshold)
    shouldMerge = false;
    return;
end
if gapSec <= opts.compoundMergeGapSec
    shouldMerge = true;
    return;
end

if secondBurst.start_idx <= firstBurst.peak_idx
    shouldMerge = true;
    return;
end

betweenIdx = firstBurst.peak_idx:secondBurst.peak_idx;
if isempty(betweenIdx)
    shouldMerge = false;
    return;
end

recoveryThreshold = min(firstBurst.baseline_env, secondBurst.baseline_env) + stableBand;
segment = env(betweenIdx) <= recoveryThreshold;
segmentGap = localLongestTrueRunDuration(timesSec(betweenIdx), segment);
shouldMerge = segmentGap < opts.stableGapToleranceSec;
end

function mergedBurst = localBuildMergedBurst(firstBurst, secondBurst, env, envRate, timesSec, stableBand, opts)
startIdx = firstBurst.start_idx;
endIdx = secondBurst.end_idx;
[~, peakOffset] = max(env(startIdx:endIdx));
peakIdx = startIdx + peakOffset - 1;

baselineStartTime = timesSec(peakIdx) - opts.burstContextSec;
baselineIdx = find(timesSec >= baselineStartTime & timesSec < timesSec(peakIdx));
if isempty(baselineIdx)
    baselineEnv = min(firstBurst.baseline_env, secondBurst.baseline_env);
else
    baselineEnv = min(median(env(baselineIdx)), min(firstBurst.baseline_env, secondBurst.baseline_env));
end

envDelta = max(0, env(peakIdx) - baselineEnv);
areaDelta = 0;
for idx = startIdx:endIdx
    areaDelta = areaDelta + max(0, env(idx) - baselineEnv) * localDt(timesSec, idx);
end

mergedBurst = struct();
mergedBurst.start_idx = startIdx;
mergedBurst.end_idx = endIdx;
mergedBurst.peak_idx = peakIdx;
mergedBurst.start_sec = timesSec(startIdx);
mergedBurst.end_sec = timesSec(endIdx);
mergedBurst.peak_sec = timesSec(peakIdx);
mergedBurst.duration_sec = max(0, timesSec(endIdx) - timesSec(startIdx));
mergedBurst.peak_rate = envRate(peakIdx);
mergedBurst.peak_env = env(peakIdx);
mergedBurst.baseline_env = baselineEnv;
mergedBurst.env_delta = envDelta;
mergedBurst.area_env_delta = areaDelta;
mergedBurst.return_time_sec = localEstimateReturnTime(timesSec, env, peakIdx, baselineEnv, envDelta, opts.returnWindowSec, stableBand);
end

function rows = localBuildEpochRows(series, window, startSec, endSec, env, envRate, envCenter, stableBand, bursts, opts)
rows = struct([]);
epochIndex = 1;
cursor = startSec;
while cursor < endSec
    epochEnd = min(endSec, cursor + opts.epochSec);
    idxs = find(series.times_sec >= cursor & series.times_sec < epochEnd);
    vals = env(idxs);
    rates = envRate(idxs);
    durationMin = max(1e-9, (epochEnd - cursor) / 60);
    epochBursts = bursts(arrayfun(@(b) b.peak_sec >= cursor && b.peak_sec < epochEnd, bursts));
    outsideFrac = 0;
    if ~isempty(vals)
        outsideFrac = mean(abs(vals - envCenter) > stableBand);
    end
    strictBursts = epochBursts(arrayfun(@(b) b.env_delta >= stableBand, epochBursts));
    strongBursts = epochBursts(arrayfun(@(b) b.env_delta >= 2 * stableBand, epochBursts));
    row = struct();
    row.probe_version = "waseda_quiet_dynamics_v1";
    row.session_id = string(series.recording.session_id);
    row.recording_id = string(series.recording.recording_id);
    row.subject_id = string(series.recording.subject_id);
    row.sensor = string(series.sensor_key);
    row.condition = string(window.condition);
    row.note_window = string(window.note_window);
    row.epoch_index = string(epochIndex);
    row.epoch_start_clock = string(formatWasedaAbsoluteClockLabel(series.reference_abs_sec + cursor, true));
    row.epoch_start_sec = localFmt(cursor, 3);
    row.epoch_end_sec = localFmt(epochEnd, 3);
    row.env_median = localFmt(localMedianOrNaN(vals));
    row.env_iqr = localFmt(localIqrOrNaN(vals));
    row.env_p95 = localFmt(localQuantileOrNaN(vals, 0.95));
    row.env_rate_p95 = localFmt(localQuantileOrNaN(rates, 0.95));
    row.env_rate_p99 = localFmt(localQuantileOrNaN(rates, 0.99));
    row.outside_stable_frac = localFmt(outsideFrac);
    row.candidate_burst_count = string(numel(epochBursts));
    row.candidate_burst_rate_per_min = localFmt(numel(epochBursts) / durationMin);
    row.strict_burst_count = string(numel(strictBursts));
    row.strict_burst_rate_per_min = localFmt(numel(strictBursts) / durationMin);
    row.strong_burst_count = string(numel(strongBursts));
    row.strong_burst_rate_per_min = localFmt(numel(strongBursts) / durationMin);
    row.median_burst_peak_rate = localFmt(localMedianOrNaN([epochBursts.peak_rate]));
    row.median_burst_return_time_sec = localFmt(localMedianOrNaN([epochBursts.return_time_sec]));
    row.median_strict_burst_return_time_sec = localFmt(localMedianOrNaN([strictBursts.return_time_sec]));
    row.claim_status = "exploratory_candidate_only";
    rows = localAppendStructRows(rows, row);
    epochIndex = epochIndex + 1;
    cursor = epochEnd;
end
end

function row = localWindowSummaryRow(series, window, startSec, endSec, envValues, rateValues, envCenter, envMad, stableBand, burstThreshold, bursts, epochRows)
durationMin = max(1e-9, (endSec - startSec) / 60);
strictBursts = bursts(arrayfun(@(b) b.env_delta >= stableBand, bursts));
strongBursts = bursts(arrayfun(@(b) b.env_delta >= 2 * stableBand, bursts));
burstRates = str2double(string({epochRows.candidate_burst_rate_per_min}));
strictBurstRates = str2double(string({epochRows.strict_burst_rate_per_min}));
outsideFracs = str2double(string({epochRows.outside_stable_frac}));
envMedians = str2double(string({epochRows.env_median}));
rateP95 = str2double(string({epochRows.env_rate_p95}));
epochs = str2double(string({epochRows.epoch_index}));
row = struct();
row.probe_version = "waseda_quiet_dynamics_v1";
row.session_id = string(series.recording.session_id);
row.recording_id = string(series.recording.recording_id);
row.subject_id = string(series.recording.subject_id);
row.sensor = string(series.sensor_key);
row.condition = string(window.condition);
row.note_window = string(window.note_window);
row.duration_sec = localFmt(endSec - startSec, 3);
row.env_center = localFmt(envCenter);
row.env_mad = localFmt(envMad);
row.stable_band = localFmt(stableBand);
row.env_median = localFmt(localMedianOrNaN(envValues));
row.env_iqr = localFmt(localIqrOrNaN(envValues));
row.env_p95 = localFmt(localQuantileOrNaN(envValues, 0.95));
row.rate_p95 = localFmt(localQuantileOrNaN(rateValues, 0.95));
row.rate_p99 = localFmt(localQuantileOrNaN(rateValues, 0.99));
row.burst_threshold = localFmt(burstThreshold);
row.candidate_burst_count = string(numel(bursts));
row.candidate_burst_rate_per_min = localFmt(numel(bursts) / durationMin);
row.strict_burst_count = string(numel(strictBursts));
row.strict_burst_rate_per_min = localFmt(numel(strictBursts) / durationMin);
row.strong_burst_count = string(numel(strongBursts));
row.strong_burst_rate_per_min = localFmt(numel(strongBursts) / durationMin);
row.median_burst_peak_rate = localFmt(localMedianOrNaN([bursts.peak_rate]));
row.median_burst_env_delta = localFmt(localMedianOrNaN([bursts.env_delta]));
row.median_burst_env_delta_over_stable_band = localFmt(localMedianOrNaN([bursts.env_delta]) / max(stableBand, eps));
row.median_strict_burst_env_delta_over_stable_band = localFmt(localMedianOrNaN([strictBursts.env_delta]) / max(stableBand, eps));
row.median_burst_return_time_sec = localFmt(localMedianOrNaN([bursts.return_time_sec]));
row.median_strict_burst_return_time_sec = localFmt(localMedianOrNaN([strictBursts.return_time_sec]));
row.env_median_slope_per_epoch = localFmt(localSlope(epochs, envMedians));
row.rate_p95_slope_per_epoch = localFmt(localSlope(epochs, rateP95));
row.burst_rate_slope_per_epoch = localFmt(localSlope(epochs, burstRates));
row.strict_burst_rate_slope_per_epoch = localFmt(localSlope(epochs, strictBurstRates));
row.outside_stable_slope_per_epoch = localFmt(localSlope(epochs, outsideFracs));
if numel(envMedians) >= 2
    row.first_to_last_env_median_delta = localFmt(envMedians(end) - envMedians(1));
    row.first_to_last_env_median_delta_over_stable_band = localFmt((envMedians(end) - envMedians(1)) / max(stableBand, eps));
else
    row.first_to_last_env_median_delta = localFmt(0);
    row.first_to_last_env_median_delta_over_stable_band = localFmt(0);
end
if numel(burstRates) >= 2
    row.first_to_last_burst_rate_delta = localFmt(burstRates(end) - burstRates(1));
    row.first_to_last_strict_burst_rate_delta = localFmt(strictBurstRates(end) - strictBurstRates(1));
else
    row.first_to_last_burst_rate_delta = localFmt(0);
    row.first_to_last_strict_burst_rate_delta = localFmt(0);
end
row.claim_status = "exploratory_candidate_only";
end

function rows = localBuildBurstRows(series, window, bursts)
rows = struct([]);
for iBurst = 1:numel(bursts)
    burst = bursts(iBurst);
    row = struct();
    row.probe_version = "waseda_quiet_dynamics_v1";
    row.event_label = "candidate_within_lar_rate_burst";
    row.claim_status = "exploratory_candidate_only";
    row.session_id = string(series.recording.session_id);
    row.recording_id = string(series.recording.recording_id);
    row.subject_id = string(series.recording.subject_id);
    row.sensor = string(series.sensor_key);
    row.condition = string(window.condition);
    row.note_window = string(window.note_window);
    row.event_id = string(sprintf('%s_%s_%s_%s_quietburst_%03d', ...
        series.recording.session_id, series.recording.subject_id, window.condition, series.sensor_key, iBurst));
    row.start_sec = localFmt(burst.start_sec, 3);
    row.end_sec = localFmt(burst.end_sec, 3);
    row.peak_sec = localFmt(burst.peak_sec, 3);
    row.peak_clock = string(formatWasedaAbsoluteClockLabel(series.reference_abs_sec + burst.peak_sec, true));
    row.duration_sec = localFmt(burst.duration_sec, 3);
    row.peak_rate = localFmt(burst.peak_rate);
    row.peak_env = localFmt(burst.peak_env);
    row.baseline_env = localFmt(burst.baseline_env);
    row.env_delta = localFmt(burst.env_delta);
    row.area_env_delta = localFmt(burst.area_env_delta);
    row.return_time_sec = localFmt(burst.return_time_sec);
    row.terminology_guardrail = "candidate within-LAR burst only; not confirmed attention or LAR evidence";
    rows = localAppendStructRows(rows, row);
end
end

function row = localEmptyBurstRow()
row = struct();
row.probe_version = "waseda_quiet_dynamics_v1";
row.event_label = "candidate_within_lar_rate_burst";
row.claim_status = "no_events_or_not_run";
row.session_id = "";
row.recording_id = "";
row.subject_id = "";
row.sensor = "";
row.condition = "";
row.note_window = "";
row.event_id = "";
row.start_sec = "";
row.end_sec = "";
row.peak_sec = "";
row.peak_clock = "";
row.duration_sec = "";
row.peak_rate = "";
row.peak_env = "";
row.baseline_env = "";
row.env_delta = "";
row.area_env_delta = "";
row.return_time_sec = "";
row.terminology_guardrail = "candidate within-LAR burst only; not confirmed attention or LAR evidence";
end

function localWriteRunManifest(jsonPath, opts, nWindow, nEpoch, nBurst)
payload = struct();
payload.run_timestamp_local = char(string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss')));
payload.probe_version = 'waseda_quiet_dynamics_v1';
payload.raw_root = opts.rawRoot;
payload.output_root = opts.outputRoot;
payload.config = rmfield(opts, {'manifestPath', 'rawRoot', 'outputRoot'});
payload.row_counts = struct('quiet_window_summary', nWindow, 'quiet_epoch_summary', nEpoch, 'quiet_burst_events', nBurst);
payload.claim_status = 'exploratory candidate-finding only; no Waseda claim upgrade';
payload.terminology_guardrail = 'Waseda recordings are treated as broadly low-animation; this probes within-quiet drift and perturbation candidates.';
fid = fopen(jsonPath, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(payload, 'PrettyPrint', true));
end

function localWriteStructCsv(csvPath, rows)
tbl = struct2table(rows);
writetable(tbl, csvPath);
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

function value = localFmt(numberValue, digits)
if nargin < 2
    digits = 6;
end
if isempty(numberValue) || any(isnan(numberValue))
    value = "";
else
    value = string(sprintf(['%0.', num2str(digits), 'f'], numberValue));
end
end

function q = localQuantileOrNaN(values, p)
if isempty(values)
    q = NaN;
else
    q = quantile(values, p);
end
end

function value = localMedianOrNaN(values)
values = values(~isnan(values));
if isempty(values)
    value = NaN;
else
    value = median(values);
end
end

function value = localIqrOrNaN(values)
if isempty(values)
    value = NaN;
else
    value = iqr(values);
end
end

function slopeValue = localSlope(xValues, yValues)
valid = ~(isnan(xValues) | isnan(yValues));
xValues = xValues(valid);
yValues = yValues(valid);
if numel(xValues) < 2
    slopeValue = 0;
    return;
end
xMean = mean(xValues);
yMean = mean(yValues);
denom = sum((xValues - xMean) .^ 2);
if denom == 0
    slopeValue = 0;
else
    slopeValue = sum((xValues - xMean) .* (yValues - yMean)) / denom;
end
end

function maskOut = localFillShortFalseGaps(timesSec, maskIn, maxGapSec)
maskOut = maskIn;
i = 1;
while i <= numel(maskOut)
    if maskOut(i)
        i = i + 1;
        continue;
    end
    j = i;
    while j <= numel(maskOut) && ~maskOut(j)
        j = j + 1;
    end
    if i > 1 && j <= numel(maskOut) && maskOut(i - 1) && maskOut(j)
        duration = timesSec(j - 1) - timesSec(i);
        if duration <= maxGapSec
            maskOut(i:j - 1) = true;
        end
    end
    i = j;
end
end

function runs = localMaskToRuns(mask)
runs = zeros(0, 2);
i = 1;
while i <= numel(mask)
    if ~mask(i)
        i = i + 1;
        continue;
    end
    j = i;
    while j <= numel(mask) && mask(j)
        j = j + 1;
    end
    runs(end + 1, :) = [i, j - 1]; %#ok<AGROW>
    i = j;
end
end

function durationSec = localLongestTrueRunDuration(timesSec, mask)
durationSec = 0;
runs = localMaskToRuns(mask);
for iRun = 1:size(runs, 1)
    startIdx = runs(iRun, 1);
    endIdx = runs(iRun, 2);
    if endIdx <= startIdx
        runDuration = 0;
    else
        runDuration = max(0, timesSec(endIdx) - timesSec(startIdx));
    end
    durationSec = max(durationSec, runDuration);
end
end
