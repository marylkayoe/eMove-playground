function analysisOutput = analyzeFrequencyStructure(magnitudeMatPath, varargin)
%ANALYZEFREQUENCYSTRUCTURE Inspect frequency structure in one magnitude trace.
%
% analysisOutput = analyzeFrequencyStructure(magnitudeMatPath)
%
% Purpose
%   Load one saved Waseda magnitude MAT file and display:
%   1. the original motion-envelope trace,
%   2. a conventional spectrogram over the same time axis,
%   3. a wavelet time-frequency view over the same time axis,
%   4. a power spectral density estimate.
%
% Input
%   magnitudeMatPath
%       Path to a MAT file created by `createWasedaChestMagnitudeEnvelopeFiles`.
%       The file must contain a `motionData` structure with:
%         - `timeSec`
%         - `motionEnvelope`
%         - `meta.sampleRateHz`
%
% Optional name-value inputs
%   'MaxFrequencyHz'             default 3.0
%   'PsdWindowSeconds'           default 64.0
%   'PsdOverlapFraction'         default 0.50
%   'CenterForFrequencyAnalysis' default true
%   'FigureTitle'                default ""
%
% Notes
%   The original envelope is plotted unchanged in the top panel.
%   For the frequency analyses, median-centering is enabled by default so
%   the PSD and wavelet view are not dominated by the envelope offset.
%
% Output
%   analysisOutput.figureHandle
%   analysisOutput.timeSec
%   analysisOutput.motionEnvelope
%   analysisOutput.analysisSignal
%   analysisOutput.sampleRateHz
%   analysisOutput.psd.frequencyHz
%   analysisOutput.psd.powerPerHz
%   analysisOutput.spectrogram.frequencyHz
%   analysisOutput.spectrogram.timeSec
%   analysisOutput.spectrogram.powerDb
%   analysisOutput.wavelet.frequencyHz
%   analysisOutput.wavelet.coefficients

inputParserObject = inputParser;

addRequired(inputParserObject, 'magnitudeMatPath', @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'MaxFrequencyHz', 3.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'PsdWindowSeconds', 64.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'PsdOverlapFraction', 0.50, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0 && value < 1);

addParameter(inputParserObject, 'CenterForFrequencyAnalysis', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'FigureTitle', "", ...
    @(value) ischar(value) || isstring(value));

parse(inputParserObject, magnitudeMatPath, varargin{:});

options = inputParserObject.Results;
magnitudeMatPath = char(string(options.magnitudeMatPath));

loadedData = load(magnitudeMatPath, 'motionData');

if ~isfield(loadedData, 'motionData')
    error('analyzeFrequencyStructure:MissingMotionData', ...
        'MAT file does not contain motionData: %s', magnitudeMatPath);
end

motionData = loadedData.motionData;

if ~isfield(motionData, 'timeSec') || ~isfield(motionData, 'motionEnvelope')
    error('analyzeFrequencyStructure:MissingRequiredFields', ...
        'motionData must contain timeSec and motionEnvelope.');
end

timeSec = motionData.timeSec(:);
motionEnvelope = motionData.motionEnvelope(:);

if numel(timeSec) ~= numel(motionEnvelope)
    error('analyzeFrequencyStructure:TimeLengthMismatch', ...
        'motionData.timeSec and motionData.motionEnvelope must have the same length.');
end

sampleRateHz = localResolveSampleRateHz(motionData, timeSec);
nyquistFrequency = sampleRateHz / 2;
maxFrequencyHz = min(options.MaxFrequencyHz, nyquistFrequency);

analysisSignal = motionEnvelope;

if logical(options.CenterForFrequencyAnalysis)
    analysisSignal = analysisSignal - median(analysisSignal, 'omitnan');
end

validMask = isfinite(analysisSignal);
if ~all(validMask)
    if nnz(validMask) < 2
        error('analyzeFrequencyStructure:NotEnoughValidSamples', ...
            'The motion envelope does not have enough finite samples for frequency analysis.');
    end

    analysisSignal = fillmissing(analysisSignal, 'linear', ...
        'SamplePoints', timeSec, ...
        'EndValues', 'nearest');
end

[psdFrequencyHz, psdPowerPerHz] = localComputePsd(analysisSignal, sampleRateHz, ...
    options.PsdWindowSeconds, options.PsdOverlapFraction);

[spectrogramPowerDb, spectrogramFrequencyHz, spectrogramTimeSec] = ...
    localComputeSpectrogram(analysisSignal, sampleRateHz, ...
    options.PsdWindowSeconds, options.PsdOverlapFraction);

[waveletCoefficients, waveletFrequencyHz] = cwt(analysisSignal, sampleRateHz);

figureTitle = string(options.FigureTitle);
if strlength(figureTitle) == 0
    [~, fileName, extension] = fileparts(magnitudeMatPath);
    figureTitle = string(fileName) + string(extension);
end

figureHandle = figure('Color', 'w', 'Position', [100 60 1500 1100]);
tiledLayoutHandle = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tiledLayoutHandle, char(figureTitle), 'Interpreter', 'none', 'FontSize', 16, 'FontWeight', 'bold');

topAxes = nexttile(tiledLayoutHandle);
plot(topAxes, timeSec, motionEnvelope, 'k', 'LineWidth', 1.0);
grid(topAxes, 'on');
ylabel(topAxes, 'motion envelope');
title(topAxes, 'Original magnitude trace', 'FontWeight', 'normal');
xlim(topAxes, [timeSec(1), timeSec(end)]);

middleAxes = nexttile(tiledLayoutHandle);
imagesc(middleAxes, spectrogramTimeSec, spectrogramFrequencyHz, spectrogramPowerDb);
axis(middleAxes, 'xy');
ylim(middleAxes, [0, maxFrequencyHz]);
grid(middleAxes, 'on');
colormap(middleAxes, turbo);
colorbar(middleAxes);
ylabel(middleAxes, 'frequency (Hz)');
title(middleAxes, 'Conventional spectrogram', 'FontWeight', 'normal');
xlim(middleAxes, [timeSec(1), timeSec(end)]);

lowerMiddleAxes = nexttile(tiledLayoutHandle);
waveletMagnitude = abs(waveletCoefficients);
imagesc(lowerMiddleAxes, timeSec, waveletFrequencyHz, waveletMagnitude);
axis(lowerMiddleAxes, 'xy');
ylim(lowerMiddleAxes, [0, maxFrequencyHz]);
grid(lowerMiddleAxes, 'on');
colormap(lowerMiddleAxes, turbo);
colorbar(lowerMiddleAxes);
ylabel(lowerMiddleAxes, 'frequency (Hz)');
title(lowerMiddleAxes, 'Wavelet time-frequency magnitude', 'FontWeight', 'normal');
xlim(lowerMiddleAxes, [timeSec(1), timeSec(end)]);

bottomAxes = nexttile(tiledLayoutHandle);
psdMask = psdFrequencyHz <= maxFrequencyHz;
plot(bottomAxes, psdFrequencyHz(psdMask), psdPowerPerHz(psdMask), 'k', 'LineWidth', 1.2);
grid(bottomAxes, 'on');
xlim(bottomAxes, [0, maxFrequencyHz]);
set(bottomAxes, 'YScale', 'log');
hold(bottomAxes, 'on');
xline(bottomAxes, 1.0, '--', 'Color', [0.75 0.15 0.15], 'LineWidth', 1.0);
xlabel(bottomAxes, 'frequency (Hz)');
ylabel(bottomAxes, 'power / Hz');
title(bottomAxes, 'Welch PSD', 'FontWeight', 'normal');

linkaxes([topAxes, middleAxes, lowerMiddleAxes], 'x');

analysisOutput = struct();
analysisOutput.figureHandle = figureHandle;
analysisOutput.timeSec = timeSec;
analysisOutput.motionEnvelope = motionEnvelope;
analysisOutput.analysisSignal = analysisSignal;
analysisOutput.sampleRateHz = sampleRateHz;
analysisOutput.psd = struct();
analysisOutput.psd.frequencyHz = psdFrequencyHz;
analysisOutput.psd.powerPerHz = psdPowerPerHz;
analysisOutput.spectrogram = struct();
analysisOutput.spectrogram.frequencyHz = spectrogramFrequencyHz;
analysisOutput.spectrogram.timeSec = spectrogramTimeSec;
analysisOutput.spectrogram.powerDb = spectrogramPowerDb;
analysisOutput.wavelet = struct();
analysisOutput.wavelet.frequencyHz = waveletFrequencyHz;
analysisOutput.wavelet.coefficients = waveletCoefficients;

end

function sampleRateHz = localResolveSampleRateHz(motionData, timeSec)
% The saved metadata should remain the timing authority for frequency work.
% The exported time vector is still useful for display and for filling short
% gaps, but sampleRateHz is the more stable source for PSD and wavelet axes.

sampleRateHz = NaN;

if isfield(motionData, 'meta') && isfield(motionData.meta, 'sampleRateHz')
    sampleRateHz = motionData.meta.sampleRateHz;
end

if ismissing(sampleRateHz) || isempty(sampleRateHz) || ~isfinite(sampleRateHz) || sampleRateHz <= 0
    timeDiffSec = diff(timeSec);
    timeDiffSec = timeDiffSec(isfinite(timeDiffSec) & timeDiffSec > 0);

    if isempty(timeDiffSec)
        error('analyzeFrequencyStructure:MissingSampleRate', ...
            'Could not resolve sample rate from motionData.meta.sampleRateHz or timeSec.');
    end

    sampleRateHz = 1 ./ median(timeDiffSec);
end
end

function [frequencyHz, powerPerHz] = localComputePsd(signalIn, sampleRateHz, windowSeconds, overlapFraction)
windowSamples = max(8, round(windowSeconds .* sampleRateHz));
windowSamples = min(windowSamples, numel(signalIn));
overlapSamples = floor(overlapFraction .* windowSamples);
nfft = 2 ^ nextpow2(max(windowSamples, 256));
[powerPerHz, frequencyHz] = pwelch(signalIn, windowSamples, overlapSamples, nfft, sampleRateHz);
end

function [powerDb, frequencyHz, timeSec] = localComputeSpectrogram(signalIn, sampleRateHz, windowSeconds, overlapFraction)
windowSamples = max(16, round(windowSeconds .* sampleRateHz));
windowSamples = min(windowSamples, numel(signalIn));
overlapSamples = floor(overlapFraction .* windowSamples);
nfft = 2 ^ nextpow2(max(windowSamples, 256));
[spectrogramValues, frequencyHz, timeSec] = spectrogram(signalIn, windowSamples, overlapSamples, nfft, sampleRateHz);
powerDb = 10 * log10(abs(spectrogramValues) .^ 2 + eps);
end
