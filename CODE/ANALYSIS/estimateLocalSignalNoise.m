function noiseEstimate = estimateLocalSignalNoise(signal, samplingFrequency, varargin)
%ESTIMATELOCALSIGNALNOISE Estimate local baseline and robust noise level.
%
% noiseEstimate = estimateLocalSignalNoise(signal, samplingFrequency)
%
% This helper estimates:
%   baseline       slow local background using moving median
%   residual       signal - baseline
%   noiseSigma     robust local noise estimate from MAD of residual
%
% The output can be used for event detection:
%
%   eventSignal = signal - baseline;
%   threshold = baseline + thresholdSigma .* noiseSigma;
%
% Notes:
%   - This is not a full statistical noise model.
%   - It is a robust practical estimate for thresholding event-like signals.
%   - The window lengths are part of the analysis definition.

%% Parse options

inputParserObject = inputParser;

addRequired(inputParserObject, 'signal', ...
    @(value) isnumeric(value) && isvector(value));

addRequired(inputParserObject, 'samplingFrequency', ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'BaselineWindowSeconds', 15, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'NoiseWindowSeconds', 30, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'RectifyResidual', true, ...
    @(value) islogical(value) || isnumeric(value));

parse(inputParserObject, signal, samplingFrequency, varargin{:});

baselineWindowSeconds = inputParserObject.Results.BaselineWindowSeconds;
noiseWindowSeconds = inputParserObject.Results.NoiseWindowSeconds;
rectifyResidual = logical(inputParserObject.Results.RectifyResidual);

%% Prepare signal

signal = signal(:);

baselineWindowSamples = max(3, round(baselineWindowSeconds .* samplingFrequency));
noiseWindowSamples = max(3, round(noiseWindowSeconds .* samplingFrequency));

%% Estimate slow baseline

baseline = movmedian(signal, baselineWindowSamples, 'omitnan');

%% Compute residual

residual = signal - baseline;

if rectifyResidual
    eventSignal = residual;
    eventSignal(eventSignal < 0) = 0;
else
    eventSignal = residual;
end

%% Estimate robust local noise

% For local MAD, use the residual rather than the raw signal so slow baseline
% changes do not inflate the noise estimate.
%
% 1.4826 converts MAD to sigma-equivalent scale for Gaussian noise. The
% signal does not need to be Gaussian; this is just a conventional robust
% scale normalization.

absoluteDeviation = abs(residual - movmedian(residual, noiseWindowSamples, 'omitnan'));
localMad = movmedian(absoluteDeviation, noiseWindowSamples, 'omitnan');

noiseSigma = 1.4826 .* localMad;

% Avoid zero thresholds in very flat regions.
globalNoiseSigma = 1.4826 .* mad(residual, 1);

if isnan(globalNoiseSigma) || globalNoiseSigma <= 0
    globalNoiseSigma = eps;
end

noiseSigma(noiseSigma <= 0 | isnan(noiseSigma)) = globalNoiseSigma;

%% Package output

noiseEstimate = struct();

noiseEstimate.baseline = baseline;
noiseEstimate.residual = residual;
noiseEstimate.eventSignal = eventSignal;
noiseEstimate.noiseSigma = noiseSigma;
noiseEstimate.globalNoiseSigma = globalNoiseSigma;

noiseEstimate.parameters.baselineWindowSeconds = baselineWindowSeconds;
noiseEstimate.parameters.noiseWindowSeconds = noiseWindowSeconds;
noiseEstimate.parameters.baselineWindowSamples = baselineWindowSamples;
noiseEstimate.parameters.noiseWindowSamples = noiseWindowSamples;
noiseEstimate.parameters.rectifyResidual = rectifyResidual;

end