function eventWaveforms = extractEnvelopeEventWaveforms(signal, peakLocations, varargin)
%EXTRACTENVELOPEEVENTWAVEFORMS Extract peak-centered event waveforms from an envelope.
%
% eventWaveforms = extractEnvelopeEventWaveforms(signal, peakLocations)
%
% Purpose
%   Use detected peak sample locations to extract full event waveforms from
%   a 1D envelope signal. Each event is defined from the local minimum
%   preceding the peak to the local minimum following the peak.
%
% Input
%   signal
%       Column or row vector containing the signal to extract. This is
%       usually the original envelope trace.
%   peakLocations
%       Vector of peak sample indices, such as the output of
%       `detectEnvelopeEvents`.
%
% Optional name-value inputs
%   'EventSignal'               default []
%   'NoiseSigma'                default []
%   'SamplingFrequency'         default []
%   'TimeSec'                   default []
%   'MaxStartLookbackSeconds'   default 2.0
%   'MaxEndLookaheadSeconds'    default 2.0
%   'MakeFigure'                default false
%   'FigureTitle'               default "Extracted event waveforms"
%
% Notes
%   - Peak locations are interpreted as sample indices.
%   - Event start is the minimum preceding the peak, searched only within
%     a bounded lookback window.
%   - Event end is the minimum following the peak, searched only within
%     a bounded lookahead window.
%   - Output waveforms are aligned by peak, not by event start.
%   - Output waveforms are padded with NaN to the longest pre/post-peak span.
%
% Output
%   eventWaveforms.waveformCube
%       nAlignedSamples x nEvents x 1 array of extracted waveforms.
%   eventWaveforms.timeCubeSec
%       nAlignedSamples x nEvents x 1 array of event time values if TimeSec
%       is supplied, otherwise [].
%   eventWaveforms.relativeTimeCubeSec
%       nAlignedSamples x nEvents x 1 array of time relative to the peak if
%       TimeSec is supplied, otherwise [].
%   eventWaveforms.peakLocations
%   eventWaveforms.eventTable
%       Table with event boundaries, lengths, peak timing, and half-height
%       width measurements.
%   eventWaveforms.figureHandle

%% Parse inputs

inputParserObject = inputParser;

addRequired(inputParserObject, 'signal', @(value) isnumeric(value) && isvector(value));
addRequired(inputParserObject, 'peakLocations', @(value) isnumeric(value) && isvector(value));

addParameter(inputParserObject, 'EventSignal', [], ...
    @(value) isempty(value) || (isnumeric(value) && isvector(value)));
addParameter(inputParserObject, 'NoiseSigma', [], ...
    @(value) isempty(value) || (isnumeric(value) && isvector(value)));
addParameter(inputParserObject, 'SamplingFrequency', [], ...
    @(value) isempty(value) || (isnumeric(value) && isscalar(value) && value > 0));
addParameter(inputParserObject, 'TimeSec', [], @(value) isempty(value) || (isnumeric(value) && isvector(value)));
addParameter(inputParserObject, 'MaxStartLookbackSeconds', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);
addParameter(inputParserObject, 'MaxEndLookaheadSeconds', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);
addParameter(inputParserObject, 'MakeFigure', false, ...
    @(value) islogical(value) || isnumeric(value));
addParameter(inputParserObject, 'FigureTitle', "Extracted event waveforms", ...
    @(value) ischar(value) || isstring(value));

parse(inputParserObject, signal, peakLocations, varargin{:});

signal = inputParserObject.Results.signal(:);
peakLocations = round(inputParserObject.Results.peakLocations(:));
eventSignal = inputParserObject.Results.EventSignal;
noiseSigma = inputParserObject.Results.NoiseSigma;
samplingFrequency = inputParserObject.Results.SamplingFrequency;
timeSec = inputParserObject.Results.TimeSec;
maxStartLookbackSeconds = inputParserObject.Results.MaxStartLookbackSeconds;
maxEndLookaheadSeconds = inputParserObject.Results.MaxEndLookaheadSeconds;
makeFigure = logical(inputParserObject.Results.MakeFigure);
figureTitle = string(inputParserObject.Results.FigureTitle);

if isempty(eventSignal)
    eventSignal = signal;
else
    eventSignal = eventSignal(:);
end

if isempty(noiseSigma)
    noiseSigma = zeros(size(signal));
else
    noiseSigma = noiseSigma(:);
end

if ~isempty(timeSec)
    timeSec = timeSec(:);
    if numel(timeSec) ~= numel(signal)
        error('extractEnvelopeEventWaveforms:TimeLengthMismatch', ...
            'TimeSec must have the same number of samples as signal.');
    end
end

if numel(eventSignal) ~= numel(signal)
    error('extractEnvelopeEventWaveforms:EventSignalLengthMismatch', ...
        'EventSignal must have the same number of samples as signal.');
end

if numel(noiseSigma) ~= numel(signal)
    error('extractEnvelopeEventWaveforms:NoiseSigmaLengthMismatch', ...
        'NoiseSigma must have the same number of samples as signal.');
end

samplingFrequency = localResolveSamplingFrequency(samplingFrequency, timeSec, signal);
maxStartLookbackSamples = max(1, round(maxStartLookbackSeconds .* samplingFrequency));
maxEndLookaheadSamples = max(1, round(maxEndLookaheadSeconds .* samplingFrequency));

nSamples = numel(signal);

if isempty(peakLocations)
    eventWaveforms = localEmptyOutput();
    return;
end

peakLocations = peakLocations(isfinite(peakLocations));
peakLocations = peakLocations(peakLocations >= 1 & peakLocations <= nSamples);
peakLocations = unique(peakLocations, 'stable');

if isempty(peakLocations)
    eventWaveforms = localEmptyOutput();
    return;
end

%% Find event boundaries for each peak

nEvents = numel(peakLocations);
eventRows = repmat(struct( ...
    'peakIndex', NaN, ...
    'startIndex', NaN, ...
    'endIndex', NaN, ...
    'peakValue', NaN, ...
    'startValue', NaN, ...
    'endValue', NaN, ...
    'peakTimeSec', NaN, ...
    'startTimeSec', NaN, ...
    'endTimeSec', NaN, ...
    'lengthSamples', NaN, ...
    'halfHeightWidthSamples', NaN, ...
    'halfHeightWidthSec', NaN), nEvents, 1);

eventLengths = NaN(nEvents, 1);
samplesBeforePeak = NaN(nEvents, 1);
samplesAfterPeak = NaN(nEvents, 1);

for eventIndex = 1:nEvents
    peakIndex = peakLocations(eventIndex);

    startIndex = localFindPreviousMinimumWithinLookback(signal, peakIndex, maxStartLookbackSamples);
    endIndex = localFindNextMinimumWithinLookahead(signal, peakIndex, maxEndLookaheadSamples);
    halfHeightWidthSamples = localComputeHalfHeightWidthSamples(eventSignal, peakIndex, startIndex, endIndex);

    eventRows(eventIndex).peakIndex = peakIndex;
    eventRows(eventIndex).startIndex = startIndex;
    eventRows(eventIndex).endIndex = endIndex;
    eventRows(eventIndex).peakValue = signal(peakIndex);
    eventRows(eventIndex).startValue = signal(startIndex);
    eventRows(eventIndex).endValue = signal(endIndex);
    eventRows(eventIndex).lengthSamples = endIndex - startIndex + 1;
    eventRows(eventIndex).halfHeightWidthSamples = halfHeightWidthSamples;

    if ~isempty(timeSec)
        eventRows(eventIndex).peakTimeSec = timeSec(peakIndex);
        eventRows(eventIndex).startTimeSec = timeSec(startIndex);
        eventRows(eventIndex).endTimeSec = timeSec(endIndex);
        eventRows(eventIndex).halfHeightWidthSec = localConvertWidthToSeconds( ...
            halfHeightWidthSamples, timeSec, startIndex, endIndex);
    end

    eventLengths(eventIndex) = eventRows(eventIndex).lengthSamples;
    samplesBeforePeak(eventIndex) = peakIndex - startIndex;
    samplesAfterPeak(eventIndex) = endIndex - peakIndex;
end

maxSamplesBeforePeak = max(samplesBeforePeak);
maxSamplesAfterPeak = max(samplesAfterPeak);
nAlignedSamples = maxSamplesBeforePeak + maxSamplesAfterPeak + 1;
alignedPeakRow = maxSamplesBeforePeak + 1;

%% Pack NaN-padded waveforms

waveformCube = NaN(nAlignedSamples, nEvents, 1);

if isempty(timeSec)
    timeCubeSec = [];
    relativeTimeCubeSec = [];
else
    timeCubeSec = NaN(nAlignedSamples, nEvents, 1);
    relativeTimeCubeSec = NaN(nAlignedSamples, nEvents, 1);
end

for eventIndex = 1:nEvents
    startIndex = eventRows(eventIndex).startIndex;
    endIndex = eventRows(eventIndex).endIndex;
    peakIndex = eventRows(eventIndex).peakIndex;
    currentIndices = startIndex:endIndex;
    currentLength = numel(currentIndices);
    currentPeakRow = alignedPeakRow - (peakIndex - startIndex);
    currentRows = currentPeakRow:(currentPeakRow + currentLength - 1);

    waveformCube(currentRows, eventIndex, 1) = signal(currentIndices);

    if ~isempty(timeSec)
        currentTimesSec = timeSec(currentIndices);
        timeCubeSec(currentRows, eventIndex, 1) = currentTimesSec;
        relativeTimeCubeSec(currentRows, eventIndex, 1) = currentTimesSec - timeSec(peakIndex);
    end
end

%% Package output

eventWaveforms = struct();
eventWaveforms.waveformCube = waveformCube;
eventWaveforms.waveformMatrix = waveformCube(:, :, 1);
eventWaveforms.timeCubeSec = timeCubeSec;
if ~isempty(timeCubeSec)
    eventWaveforms.timeMatrixSec = timeCubeSec(:, :, 1);
else
    eventWaveforms.timeMatrixSec = [];
end
eventWaveforms.relativeTimeCubeSec = relativeTimeCubeSec;
if ~isempty(relativeTimeCubeSec)
    eventWaveforms.relativeTimeMatrixSec = relativeTimeCubeSec(:, :, 1);
else
    eventWaveforms.relativeTimeMatrixSec = [];
end
eventWaveforms.peakLocations = peakLocations;
eventWaveforms.alignedPeakRow = alignedPeakRow;
eventWaveforms.alignedStartRow = [];
eventWaveforms.eventTable = struct2table(eventRows);
eventWaveforms.normalizedWaveformMatrix = localNormalizeWaveformsByStartAndPeak(eventWaveforms.waveformMatrix, eventRows);
eventWaveforms.figureHandle = [];

if makeFigure
    eventWaveforms.figureHandle = localPlotWaveforms(eventWaveforms.waveformMatrix, ...
        eventWaveforms.relativeTimeMatrixSec, alignedPeakRow, figureTitle);
end

end

function samplingFrequency = localResolveSamplingFrequency(samplingFrequency, timeSec, signal)
if ~isempty(samplingFrequency)
    return;
end

if ~isempty(timeSec)
    timeDiffSec = diff(timeSec);
    timeDiffSec = timeDiffSec(isfinite(timeDiffSec) & timeDiffSec > 0);
    if ~isempty(timeDiffSec)
        samplingFrequency = 1 ./ median(timeDiffSec);
        return;
    end
end

if numel(signal) >= 2
    samplingFrequency = 1;
else
    samplingFrequency = 1;
end
end

function startIndex = localFindPreviousMinimumWithinLookback(signal, peakIndex, maxStartLookbackSamples)
searchStartIndex = max(1, peakIndex - maxStartLookbackSamples);
searchIndices = searchStartIndex:peakIndex;
[~, minimumOffset] = min(signal(searchIndices));
startIndex = searchStartIndex + minimumOffset - 1;
end

function endIndex = localFindNextMinimumWithinLookahead(signal, peakIndex, maxEndLookaheadSamples)
nSamples = numel(signal);
if peakIndex >= nSamples
    endIndex = nSamples;
    return;
end

searchEndIndex = min(nSamples, peakIndex + maxEndLookaheadSamples);
searchIndices = peakIndex:searchEndIndex;
[~, minimumOffset] = min(signal(searchIndices));
endIndex = peakIndex + minimumOffset - 1;
end

function halfHeightWidthSamples = localComputeHalfHeightWidthSamples(eventSignal, peakIndex, startIndex, endIndex)
peakValue = eventSignal(peakIndex);
halfHeight = 0.5 .* peakValue;

leftIndex = peakIndex;
while leftIndex > startIndex && eventSignal(leftIndex - 1) >= halfHeight
    leftIndex = leftIndex - 1;
end

rightIndex = peakIndex;
while rightIndex < endIndex && eventSignal(rightIndex + 1) >= halfHeight
    rightIndex = rightIndex + 1;
end

halfHeightWidthSamples = rightIndex - leftIndex + 1;
end

function halfHeightWidthSec = localConvertWidthToSeconds(widthSamples, timeSec, startIndex, endIndex)
if widthSamples <= 1
    halfHeightWidthSec = 0;
    return;
end

windowTimes = timeSec(startIndex:endIndex);
timeDiffSec = diff(windowTimes);
timeDiffSec = timeDiffSec(isfinite(timeDiffSec) & timeDiffSec > 0);

if isempty(timeDiffSec)
    halfHeightWidthSec = NaN;
else
    halfHeightWidthSec = (widthSamples - 1) .* median(timeDiffSec);
end
end

function eventWaveforms = localEmptyOutput()
eventWaveforms = struct();
eventWaveforms.waveformCube = NaN(0, 0, 1);
eventWaveforms.waveformMatrix = NaN(0, 0);
eventWaveforms.timeCubeSec = [];
eventWaveforms.timeMatrixSec = [];
eventWaveforms.relativeTimeCubeSec = [];
eventWaveforms.relativeTimeMatrixSec = [];
eventWaveforms.peakLocations = [];
eventWaveforms.alignedPeakRow = [];
eventWaveforms.alignedStartRow = [];
eventWaveforms.eventTable = table();
eventWaveforms.normalizedWaveformMatrix = NaN(0, 0);
eventWaveforms.figureHandle = [];
end

function normalizedWaveformMatrix = localNormalizeWaveformsByStartAndPeak(waveformMatrix, eventRows)
normalizedWaveformMatrix = NaN(size(waveformMatrix));

for eventIndex = 1:size(waveformMatrix, 2)
    waveform = waveformMatrix(:, eventIndex);
    finiteMask = isfinite(waveform);
    if ~any(finiteMask)
        continue;
    end

    finiteIndices = find(finiteMask);
    startValue = waveform(finiteIndices(1));
    peakValue = eventRows(eventIndex).peakValue;
    peakDelta = peakValue - startValue;

    if ~isfinite(peakDelta) || peakDelta <= 0
        normalizedWaveformMatrix(finiteMask, eventIndex) = waveform(finiteMask) - startValue;
    else
        normalizedWaveformMatrix(finiteMask, eventIndex) = ...
            (waveform(finiteMask) - startValue) ./ peakDelta;
    end
end
end

function figureHandle = localPlotWaveforms(waveformMatrix, relativeTimeMatrixSec, alignedPeakRow, figureTitle)
meanWaveform = mean(waveformMatrix, 2, 'omitnan');

if ~isempty(relativeTimeMatrixSec)
    xValues = mean(relativeTimeMatrixSec, 2, 'omitnan');
else
    xValues = ((1:size(waveformMatrix, 1)) - alignedPeakRow).';
end

figureHandle = figure('Color', 'w', 'Position', [120 120 900 650]);
ax = axes(figureHandle); %#ok<LAXES>
plot(ax, xValues, waveformMatrix, 'Color', [0.70 0.70 0.70], 'LineWidth', 0.8);
hold(ax, 'on');
plot(ax, xValues, meanWaveform, 'k', 'LineWidth', 2.4);
xline(ax, 0, '--', 'Color', [0.75 0.15 0.15], 'LineWidth', 1.0);
grid(ax, 'on');
xlabel(ax, 'time relative to peak');
ylabel(ax, 'envelope');
title(ax, char(figureTitle), 'Interpreter', 'none');
end
