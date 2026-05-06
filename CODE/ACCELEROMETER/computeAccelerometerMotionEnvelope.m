function imuEnvelope = computeAccelerometerMotionEnvelope(imuCorrected, varargin)
%COMPUTEACCELEROMETERMOTIONENVELOPE Compute accelerometer motion envelope.
%
% imuEnvelope = computeAccelerometerMotionEnvelope(imuCorrected)
%
% This function takes gravity-corrected accelerometer data and converts it
% into a scalar movement-intensity signal.
%
% Processing steps:
%   1. Take gravity-corrected acceleration x/y/z.
%   2. Mark remaining very large artefacts.
%   3. Optionally interpolate those artefact samples.
%   4. Bandpass-filter each acceleration axis.
%   5. Compute vector magnitude of the filtered 3D signal.
%   6. Compute a local RMS envelope.
%
% Input:
%   imuCorrected.acc.linear       nSamples x 3 gravity-corrected acceleration in g
%   imuCorrected.timeSec          nSamples x 1 time vector in seconds
%   imuCorrected.samplingFrequency
%   imuCorrected.meta
%
% Important terminology:
%   Here, "linear acceleration" means acceleration after gravity has been
%   removed using the quaternion-derived gravity estimate. It does not mean
%   linear fitting or straight-line movement.
%
% Working defaults:
%   FrequencyBandHz = [0.2 10]
%       Broad movement band. This preserves low-frequency body movement
%       while not yet discarding the upper range, where tremor-related
%       components could in principle appear. With 31.25 Hz sampling, the
%       Nyquist frequency is 15.625 Hz, so 10 Hz is a practical upper bound.
%
%   EnvelopeWindowSeconds = 1.0
%       A 1 s RMS window gives a local movement-energy estimate. This is
%       currently a working choice for proposal figures, not a final
%       analysis constant. Later analyses should test sensitivity to this
%       window length.
%
% Optional name-value inputs:
%   'FrequencyBandHz'             default [0.2 10]
%   'EnvelopeWindowSeconds'       default 1.0
%   'ArtefactMagnitudeMaxG'       default 2.0
%   'InterpolateArtefacts'        default true
%   'MakePlots'                   default true
%
% Output:
%   imuEnvelope.acc.linear        original gravity-corrected acceleration
%   imuEnvelope.acc.clean         after artefact marking/interpolation
%   imuEnvelope.acc.filtered      bandpass-filtered x/y/z acceleration
%
%   imuEnvelope.magnitude.linear
%   imuEnvelope.magnitude.filtered
%
%   imuEnvelope.envelope.rms
%   imuEnvelope.envelope.windowSeconds
%   imuEnvelope.envelope.windowSamples
%
%   imuEnvelope.filter.frequencyBandHz
%   imuEnvelope.qc
%   imuEnvelope.meta

%% Parse options

inputParserObject = inputParser;

addRequired(inputParserObject, 'imuCorrected', @isstruct);

addParameter(inputParserObject, 'FrequencyBandHz', [0.2 10], ...
    @(value) isnumeric(value) && numel(value) == 2 && value(1) > 0 && value(2) > value(1));

addParameter(inputParserObject, 'EnvelopeWindowSeconds', 1.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'ArtefactMagnitudeMaxG', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'InterpolateArtefacts', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'MakePlots', true, ...
    @(value) islogical(value) || isnumeric(value));

parse(inputParserObject, imuCorrected, varargin{:});

frequencyBandHz = inputParserObject.Results.FrequencyBandHz;
envelopeWindowSeconds = inputParserObject.Results.EnvelopeWindowSeconds;
artefactMagnitudeMaxG = inputParserObject.Results.ArtefactMagnitudeMaxG;

interpolateArtefacts = logical(inputParserObject.Results.InterpolateArtefacts);
makePlots = logical(inputParserObject.Results.MakePlots);

%% Extract and validate input data

% accLinear is the gravity-corrected acceleration from the previous
% processing stage. It should already be in g.

accLinear = imuCorrected.acc.linear;
timeSec = imuCorrected.timeSec(:);
samplingFrequency = imuCorrected.samplingFrequency;

nSamples = size(accLinear, 1);

if size(accLinear, 2) ~= 3
    error('imuCorrected.acc.linear must be nSamples x 3.');
end

if numel(timeSec) ~= nSamples
    error('imuCorrected.timeSec must match imuCorrected.acc.linear.');
end

if ~isscalar(samplingFrequency) || ~isnumeric(samplingFrequency) || samplingFrequency <= 0
    error('imuCorrected.samplingFrequency must be a positive numeric scalar.');
end

nyquistFrequency = samplingFrequency ./ 2;

if frequencyBandHz(2) >= nyquistFrequency
    error('Upper frequency %.3f Hz must be below Nyquist frequency %.3f Hz.', ...
        frequencyBandHz(2), nyquistFrequency);
end

%% Compute gravity-corrected acceleration magnitude

% This is the vector length of the gravity-corrected 3D acceleration.
% It is useful for QC and artefact detection, but the final envelope is
% computed after bandpass filtering the x/y/z axes.

linearMagnitude = sqrt(sum(accLinear.^2, 2));

%% Mark remaining large artefacts

% This stage is intentionally simple and conservative.
%
% These artefacts are detected after gravity correction. The aim is only to
% catch remaining extreme samples that would dominate the envelope. This is
% not meant to classify gross movement versus micromotion.
%
% For real analyses, gross movement should probably be handled as a separate
% behavioural mask, not mixed with sensor artefact detection.

badArtefact = linearMagnitude > artefactMagnitudeMaxG | ...
    any(isnan(accLinear), 2) | ...
    any(isinf(accLinear), 2);

%% Interpolate or retain artefact samples

% For proposal figures and first-pass visualization, interpolating isolated
% artefact samples is useful because otherwise one bad point can contaminate
% the bandpass and RMS envelope.
%
% If InterpolateArtefacts is false, artefact samples remain NaN. This is
% more conservative, but can complicate filtering.

accClean = accLinear;

if interpolateArtefacts

    accClean(badArtefact, :) = NaN;

    for axisIndex = 1:3

        axisData = accClean(:, axisIndex);

        if all(isnan(axisData))
            continue
        end

        axisData = fillmissing(axisData, 'linear', ...
            'SamplePoints', timeSec, ...
            'EndValues', 'nearest');

        accClean(:, axisIndex) = axisData;

    end

else

    accClean(badArtefact, :) = NaN;

end

%% Bandpass-filter each acceleration axis

% Filtering is done before computing magnitude.
%
% This matters because vector magnitude is nonlinear. If magnitude is
% computed first, positive and negative fluctuations can no longer cancel
% and noise becomes rectified upward.
%
% Current working band:
%   0.2-10 Hz
%
% This is deliberately broad. It keeps slow body movement and also retains
% the upper frequencies available at this sampling rate.

accFiltered = NaN(size(accClean));

for axisIndex = 1:3

    axisData = accClean(:, axisIndex);

    if all(isnan(axisData))
        continue
    end

    accFiltered(:, axisIndex) = bandpass(axisData, frequencyBandHz, samplingFrequency);

end

%% Compute band-limited vector magnitude

% This converts the filtered 3D acceleration into a scalar movement signal.
% Directional information is discarded here. The result answers:
%
%   "How large is the band-limited acceleration vector at this time?"

filteredMagnitude = sqrt(sum(accFiltered.^2, 2));

%% Compute RMS movement envelope

% The RMS envelope estimates local movement energy.
%
% The window length is part of the measurement. A 1 s window means that
% short acceleration fluctuations are summarized into a movement-intensity
% signal over approximately one second.

windowSamples = max(1, round(envelopeWindowSeconds .* samplingFrequency));

rmsEnvelope = sqrt(movmean(filteredMagnitude.^2, ...
    windowSamples, ...
    'omitnan'));

%% Package output

imuEnvelope = struct();

imuEnvelope.timeSec = timeSec;
imuEnvelope.samplingFrequency = samplingFrequency;

imuEnvelope.acc.linear = accLinear;
imuEnvelope.acc.clean = accClean;
imuEnvelope.acc.filtered = accFiltered;

imuEnvelope.magnitude.linear = linearMagnitude;
imuEnvelope.magnitude.filtered = filteredMagnitude;

imuEnvelope.envelope.rms = rmsEnvelope;
imuEnvelope.envelope.windowSeconds = envelopeWindowSeconds;
imuEnvelope.envelope.windowSamples = windowSamples;

imuEnvelope.filter.frequencyBandHz = frequencyBandHz;
imuEnvelope.filter.nyquistFrequency = nyquistFrequency;

%% Store QC information

imuEnvelope.qc.badArtefact = badArtefact;
imuEnvelope.qc.artefactMagnitudeMaxG = artefactMagnitudeMaxG;
imuEnvelope.qc.nBadArtefact = sum(badArtefact);
imuEnvelope.qc.fractionBadArtefact = mean(badArtefact);

imuEnvelope.qc.interpolatedArtefacts = interpolateArtefacts;

%% Store metadata

imuEnvelope.meta = imuCorrected.meta;

imuEnvelope.meta.dataStage = 'motion envelope';
imuEnvelope.meta.accelerationUnit = 'g';

imuEnvelope.meta.envelopeWindowSeconds = envelopeWindowSeconds;
imuEnvelope.meta.envelopeWindowSamples = windowSamples;
imuEnvelope.meta.frequencyBandHz = frequencyBandHz;

imuEnvelope.meta.processingNote = ...
    'Motion envelope computed from quaternion gravity-corrected acceleration, bandpass-filtered by axis, converted to vector magnitude, then summarized with RMS window.';

imuEnvelope.meta.analysisCaution = ...
    'Envelope amplitude and timing may depend on frequency band and RMS window length; test sensitivity before final quantitative analysis.';

%% Same-shape output for plotting functions

% Some plotting functions expect the same field structure as the original
% accData input: acc, quat, timeSec, meta.
%
% Since the envelope is scalar, it is repeated across three columns here.
% This is only for compatibility with plotting code. It should not be
% interpreted as real x/y/z acceleration.

imuEnvelope.envelopeAsInput = struct();

imuEnvelope.envelopeAsInput.acc = [rmsEnvelope, rmsEnvelope, rmsEnvelope];
imuEnvelope.envelopeAsInput.quat = imuCorrected.quat;
imuEnvelope.envelopeAsInput.timeSec = timeSec;
imuEnvelope.envelopeAsInput.meta = imuEnvelope.meta;

imuEnvelope.envelopeAsInput.meta.dataStage = 'motion envelope repeated as acc columns for plotting compatibility';

%% Optional plots

if makePlots
    makeAccelerometerEnvelopePlots(imuEnvelope);
end

end

function makeAccelerometerEnvelopePlots(imuEnvelope)
%MAKEACCELEROMETERENVELOPEPLOTS Plot intermediate and final envelope signals.
%
% The three panels show:
%   1. Gravity-corrected acceleration magnitude before bandpass filtering.
%   2. Band-limited acceleration magnitude.
%   3. RMS movement envelope.

timeSec = imuEnvelope.timeSec;

figure('Name', 'Accelerometer motion envelope');

%% Panel 1: gravity-corrected acceleration magnitude

subplot(3, 1, 1);

plot(timeSec, imuEnvelope.magnitude.linear, ...
    'DisplayName', 'Gravity-corrected magnitude');
hold on;

plot(timeSec(imuEnvelope.qc.badArtefact), ...
    imuEnvelope.magnitude.linear(imuEnvelope.qc.badArtefact), '.', ...
    'DisplayName', 'Marked artefact');

ylabel('Magnitude (g)');
title('Gravity-corrected acceleration magnitude');
legend('Location', 'best');

%% Panel 2: band-limited magnitude

subplot(3, 1, 2);

plot(timeSec, imuEnvelope.magnitude.filtered, ...
    'DisplayName', 'Band-limited magnitude');

ylabel('Magnitude (g)');

title(sprintf('Band-limited magnitude %.2f-%.2f Hz', ...
    imuEnvelope.filter.frequencyBandHz(1), ...
    imuEnvelope.filter.frequencyBandHz(2)));

legend('Location', 'best');

%% Panel 3: RMS envelope

subplot(3, 1, 3);

plot(timeSec, imuEnvelope.envelope.rms, ...
    'DisplayName', 'RMS envelope');

xlabel('Time (s)');
ylabel('RMS acceleration (g)');

title(sprintf('RMS movement envelope, %.2f s window', ...
    imuEnvelope.envelope.windowSeconds));

legend('Location', 'best');

end