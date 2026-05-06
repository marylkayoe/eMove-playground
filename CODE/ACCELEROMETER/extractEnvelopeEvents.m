function eventOutput = extractEnvelopeEvents(signal, samplingFrequency, varargin)
%EXTRACTENVELOPEEVENTS Run noise estimation, peak detection, and waveform extraction.
%
% eventOutput = extractEnvelopeEvents(signal, samplingFrequency)
%
% Purpose
%   Provide one small wrapper around the current envelope-event workflow:
%   1. estimate local baseline and noise
%   2. detect significant envelope peaks
%   3. extract aligned event waveforms around those peaks
%
% Input
%   signal
%       Column or row vector containing the envelope signal.
%   samplingFrequency
%       Sampling frequency in Hz.
%
% Optional name-value inputs
%   'TimeSec'                   default []
%   'BaselineWindowSeconds'     default 15
%   'NoiseWindowSeconds'        default 30
%   'RectifyResidual'           default true
%   'ThresholdSigma'            default 4
%   'MaxStartLookbackSeconds'   default 2.0
%   'MaxEndLookaheadSeconds'    default 2.0
%   'CompoundPreWindowSeconds'  default 1.0
%   'CompoundPostWindowSeconds' default 4.0
%   'MakeWaveformFigure'        default false
%   'WaveformFigureTitle'       default "Extracted event waveforms"
%   'MakeSummaryFigure'         default false
%   'SummaryFigureTitle'        default "Envelope event summary"
%
% Output
%   eventOutput.signal
%   eventOutput.samplingFrequency
%   eventOutput.timeSec
%   eventOutput.noiseEstimate
%   eventOutput.peakLocations
%   eventOutput.peakValues
%   eventOutput.peakWidthsSamples
%   eventOutput.peakWidthsSec
%   eventOutput.waveforms
%   eventOutput.waveformSourceSignal
%   eventOutput.eventTable
%   eventOutput.summaryFigureHandle

%% Parse inputs

inputParserObject = inputParser;

addRequired(inputParserObject, 'signal', @(value) isnumeric(value) && isvector(value));
addRequired(inputParserObject, 'samplingFrequency', ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'TimeSec', [], ...
    @(value) isempty(value) || (isnumeric(value) && isvector(value)));

addParameter(inputParserObject, 'BaselineWindowSeconds', 15, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'NoiseWindowSeconds', 30, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'RectifyResidual', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'ThresholdSigma', 4, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'MaxStartLookbackSeconds', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'MaxEndLookaheadSeconds', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'CompoundPreWindowSeconds', 1.0, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0);

addParameter(inputParserObject, 'CompoundPostWindowSeconds', 4.0, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0);

addParameter(inputParserObject, 'MakeWaveformFigure', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveformFigureTitle', "Extracted event waveforms", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'MakeSummaryFigure', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'SummaryFigureTitle', "Envelope event summary", ...
    @(value) ischar(value) || isstring(value));

parse(inputParserObject, signal, samplingFrequency, varargin{:});

signal = inputParserObject.Results.signal(:);
samplingFrequency = inputParserObject.Results.samplingFrequency;
timeSec = inputParserObject.Results.TimeSec;

if ~isempty(timeSec)
    timeSec = timeSec(:);
    if numel(timeSec) ~= numel(signal)
        error('extractEnvelopeEvents:TimeLengthMismatch', ...
            'TimeSec must have the same number of samples as signal.');
    end
end

%% Estimate local noise and baseline

noiseEstimate = estimateLocalSignalNoise(signal, samplingFrequency, ...
    'BaselineWindowSeconds', inputParserObject.Results.BaselineWindowSeconds, ...
    'NoiseWindowSeconds', inputParserObject.Results.NoiseWindowSeconds, ...
    'RectifyResidual', logical(inputParserObject.Results.RectifyResidual));

%% Detect peaks using the current detector

[peakLocations, peakValues, peakWidthsSamples] = detectEnvelopeEvents( ...
    noiseEstimate.eventSignal, ...
    noiseEstimate.noiseSigma, ...
    'ThresholdSigma', inputParserObject.Results.ThresholdSigma, ...
    'SamplingFrequency', samplingFrequency);

%% Extract waveforms around the detected peaks

waveforms = extractEnvelopeEventWaveforms(noiseEstimate.eventSignal, peakLocations, ...
    'EventSignal', noiseEstimate.eventSignal, ...
    'NoiseSigma', noiseEstimate.noiseSigma, ...
    'SamplingFrequency', samplingFrequency, ...
    'TimeSec', timeSec, ...
    'MaxStartLookbackSeconds', inputParserObject.Results.MaxStartLookbackSeconds, ...
    'MaxEndLookaheadSeconds', inputParserObject.Results.MaxEndLookaheadSeconds, ...
    'MakeFigure', logical(inputParserObject.Results.MakeWaveformFigure), ...
    'FigureTitle', inputParserObject.Results.WaveformFigureTitle);

%% Merge event-level outputs

eventTable = waveforms.eventTable;

if ~isempty(peakWidthsSamples)
    peakWidthsSamples = peakWidthsSamples(:);
    peakWidthsSec = localConvertPeakWidthsToSeconds(peakWidthsSamples, samplingFrequency, timeSec);
else
    peakWidthsSamples = zeros(0, 1);
    peakWidthsSec = zeros(0, 1);
end

if height(eventTable) ~= numel(peakWidthsSamples)
    error('extractEnvelopeEvents:PeakCountMismatch', ...
        'Peak widths from detectEnvelopeEvents do not match extracted event count.');
end

if ~isempty(eventTable)
    eventTable.peakWidthSamples = peakWidthsSamples;
    eventTable.peakWidthSec = peakWidthsSec;
    eventTable = localAddCompoundFlags(eventTable, samplingFrequency, ...
        inputParserObject.Results.CompoundPreWindowSeconds, ...
        inputParserObject.Results.CompoundPostWindowSeconds);
end

%% Package output

eventOutput = struct();
eventOutput.signal = signal;
eventOutput.samplingFrequency = samplingFrequency;
eventOutput.timeSec = timeSec;
eventOutput.noiseEstimate = noiseEstimate;
eventOutput.peakLocations = peakLocations;
eventOutput.peakValues = peakValues;
eventOutput.peakWidthsSamples = peakWidthsSamples;
eventOutput.peakWidthsSec = peakWidthsSec;
eventOutput.waveforms = waveforms;
eventOutput.waveformSourceSignal = noiseEstimate.eventSignal;
eventOutput.eventTable = eventTable;
eventOutput.summaryFigureHandle = [];

if logical(inputParserObject.Results.MakeSummaryFigure)
    eventOutput.summaryFigureHandle = localPlotSummaryFigure( ...
        waveforms, ...
        eventTable, ...
        peakValues, ...
        peakWidthsSec, ...
        timeSec, ...
        inputParserObject.Results.SummaryFigureTitle);
end

end

function peakWidthsSec = localConvertPeakWidthsToSeconds(peakWidthsSamples, samplingFrequency, timeSec)
if ~isempty(timeSec)
    timeDiffSec = diff(timeSec);
    timeDiffSec = timeDiffSec(isfinite(timeDiffSec) & timeDiffSec > 0);

    if isempty(timeDiffSec)
        peakWidthsSec = peakWidthsSamples ./ samplingFrequency;
    else
        peakWidthsSec = peakWidthsSamples .* median(timeDiffSec);
    end
else
    peakWidthsSec = peakWidthsSamples ./ samplingFrequency;
end
end

function eventTable = localAddCompoundFlags(eventTable, samplingFrequency, compoundPreWindowSeconds, compoundPostWindowSeconds)
peakIndices = eventTable.peakIndex;

nEvents = height(eventTable);
hasNeighborBefore = false(nEvents, 1);
hasNeighborAfter = false(nEvents, 1);
preWindowSamples = round(compoundPreWindowSeconds .* samplingFrequency);
postWindowSamples = round(compoundPostWindowSeconds .* samplingFrequency);

for eventIndex = 1:nEvents
    currentPeakIndex = peakIndices(eventIndex);
    sampleDelta = peakIndices - currentPeakIndex;
    hasNeighborBefore(eventIndex) = any(sampleDelta < 0 & sampleDelta >= -preWindowSamples);
    hasNeighborAfter(eventIndex) = any(sampleDelta > 0 & sampleDelta <= postWindowSamples);
end

eventTable.hasNeighborBefore = hasNeighborBefore;
eventTable.hasNeighborAfter = hasNeighborAfter;
eventTable.isCompoundEvent = hasNeighborBefore | hasNeighborAfter;
eventTable.isIsolatedEvent = ~eventTable.isCompoundEvent;
end

function figureHandle = localPlotSummaryFigure(waveforms, eventTable, peakValues, peakWidthsSec, timeSec, figureTitle)
waveformMatrix = waveforms.waveformMatrix;
relativeTimeMatrixSec = waveforms.relativeTimeMatrixSec;
alignedPeakRow = waveforms.alignedPeakRow;

if ~isempty(relativeTimeMatrixSec)
    xValues = mean(relativeTimeMatrixSec, 2, 'omitnan');
    xLabelText = 'time relative to peak';
else
    xValues = ((1:size(waveformMatrix, 1)) - alignedPeakRow).';
    xLabelText = 'sample offset from peak';
end

meanWaveform = mean(waveformMatrix, 2, 'omitnan');

if height(eventTable) >= 2 && ~isempty(timeSec) && all(isfinite(eventTable.peakTimeSec))
    interEventIntervalsSec = diff(eventTable.peakTimeSec);
else
    interEventIntervalsSec = [];
end

figureHandle = figure('Color', 'w', 'Position', [100 80 1500 900]);
tiledLayoutHandle = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tiledLayoutHandle, char(string(figureTitle)), 'Interpreter', 'none', 'FontSize', 16, 'FontWeight', 'bold');

waveformAxes = nexttile(tiledLayoutHandle, 1);
plot(waveformAxes, xValues, waveformMatrix, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
hold(waveformAxes, 'on');
plot(waveformAxes, xValues, meanWaveform, 'k', 'LineWidth', 2.6);
xline(waveformAxes, 0, '--', 'Color', [0.75 0.15 0.15], 'LineWidth', 1.0);
grid(waveformAxes, 'on');
xlabel(waveformAxes, xLabelText);
ylabel(waveformAxes, 'event signal');
title(waveformAxes, 'Aligned event-signal waveforms', 'FontWeight', 'normal');

amplitudeAxes = nexttile(tiledLayoutHandle, 2);
localPlotHistogram(amplitudeAxes, peakValues, 'event amplitude', 'count');
title(amplitudeAxes, 'Peak amplitudes', 'FontWeight', 'normal');

intervalAxes = nexttile(tiledLayoutHandle, 3);
if isempty(interEventIntervalsSec)
    text(intervalAxes, 0.5, 0.5, 'Need at least two events with peak times.', ...
        'HorizontalAlignment', 'center');
    axis(intervalAxes, 'off');
else
    localPlotHistogram(intervalAxes, interEventIntervalsSec, 'inter-event interval (s)', 'count');
    title(intervalAxes, 'Inter-event intervals', 'FontWeight', 'normal');
end

widthAxes = nexttile(tiledLayoutHandle, 4);
localPlotHistogram(widthAxes, peakWidthsSec, 'half-height width (s)', 'count');
title(widthAxes, 'Detector peak widths', 'FontWeight', 'normal');

extractorWidthAxes = nexttile(tiledLayoutHandle, 5);
if ismember('halfHeightWidthSec', eventTable.Properties.VariableNames)
    localPlotHistogram(extractorWidthAxes, eventTable.halfHeightWidthSec, 'half-height width (s)', 'count');
    title(extractorWidthAxes, 'Extractor half-height widths', 'FontWeight', 'normal');
else
    text(extractorWidthAxes, 0.5, 0.5, 'No extractor width values available.', ...
        'HorizontalAlignment', 'center');
    axis(extractorWidthAxes, 'off');
end

scatterAxes = nexttile(tiledLayoutHandle, 6);
if ismember('halfHeightWidthSec', eventTable.Properties.VariableNames)
    localPlotWidthScatter(scatterAxes, peakWidthsSec, eventTable.halfHeightWidthSec);
else
    text(scatterAxes, 0.5, 0.5, 'No extractor width values available.', ...
        'HorizontalAlignment', 'center');
    axis(scatterAxes, 'off');
end
end

function localPlotHistogram(ax, valuesIn, xLabelText, yLabelText)
values = valuesIn(isfinite(valuesIn));
if isempty(values)
    text(ax, 0.5, 0.5, 'No values available.', 'HorizontalAlignment', 'center');
    axis(ax, 'off');
    return;
end

clipUpper = quantile(values, 0.95);
valuesClipped = values(values <= clipUpper);
if isempty(valuesClipped)
    valuesClipped = values;
end

if numel(valuesClipped) == 1
    singleValue = valuesClipped(1);
    localHalfSpan = max(abs(singleValue) * 0.1, 0.5);
    histogram(ax, valuesClipped, 'BinEdges', [singleValue - localHalfSpan, singleValue + localHalfSpan], ...
        'FaceColor', [0.45 0.45 0.45], 'EdgeColor', 'none');
else
    binWidth = localFreedmanDiaconisBinWidth(valuesClipped);
    if ~isfinite(binWidth) || binWidth <= 0
        histogram(ax, valuesClipped, 'NumBins', max(12, min(40, ceil(2 * sqrt(numel(valuesClipped))))), 'FaceColor', [0.45 0.45 0.45], 'EdgeColor', 'none');
    else
        histogram(ax, valuesClipped, 'BinWidth', max(binWidth / 2, eps), ...
            'FaceColor', [0.45 0.45 0.45], 'EdgeColor', 'none');
    end
end

grid(ax, 'on');
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
if min(valuesClipped) == max(valuesClipped)
    localHalfSpan = max(abs(valuesClipped(1)) * 0.1, 0.5);
    xlim(ax, [valuesClipped(1) - localHalfSpan, valuesClipped(1) + localHalfSpan]);
else
    xlim(ax, [min(valuesClipped), max(valuesClipped)]);
end
text(ax, 0.98, 0.96, 'display clipped at 95%', 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 9);
end

function localPlotWidthScatter(ax, detectorWidthsSec, extractorWidthsSec)
detectorWidthsSec = detectorWidthsSec(:);
extractorWidthsSec = extractorWidthsSec(:);
validMask = isfinite(detectorWidthsSec) & isfinite(extractorWidthsSec);

if ~any(validMask)
    text(ax, 0.5, 0.5, 'No paired width values available.', ...
        'HorizontalAlignment', 'center');
    axis(ax, 'off');
    return;
end

xValues = detectorWidthsSec(validMask);
yValues = extractorWidthsSec(validMask);

scatter(ax, xValues, yValues, 24, 'filled', ...
    'MarkerFaceColor', [0.20 0.40 0.70], 'MarkerFaceAlpha', 0.75);
hold(ax, 'on');

axisLimit = max([xValues; yValues]);
if ~isfinite(axisLimit) || axisLimit <= 0
    axisLimit = 1;
end

plot(ax, [0 axisLimit], [0 axisLimit], '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.0);
grid(ax, 'on');
xlabel(ax, 'detector width (s)');
ylabel(ax, 'extractor half-height width (s)');
title(ax, 'Width comparison', 'FontWeight', 'normal');
xlim(ax, [0 axisLimit]);
ylim(ax, [0 axisLimit]);
end

function binWidth = localFreedmanDiaconisBinWidth(values)
if numel(values) < 2
    binWidth = NaN;
    return;
end

iqrValue = iqr(values);
if ~isfinite(iqrValue) || iqrValue <= 0
    binWidth = NaN;
    return;
end

binWidth = 2 * iqrValue / nthroot(numel(values), 3);
end
