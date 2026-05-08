function [figureHandle, plotOutput] = plotEnvelopeEventsWithNoiseBand(magnitudeFilePath, varargin)
%PLOTENVELOPEEVENTSWITHNOISEBAND Plot motion envelope with event markers.
%
% [figureHandle, plotOutput] = plotEnvelopeEventsWithNoiseBand(magnitudeFilePath)
%
% Purpose
%   Plot an accelerometer motion-envelope MAT file with:
%   - the original motion envelope,
%   - a shaded local background/noise region,
%   - the envelope-domain event threshold,
%   - unitary event peaks and compound-event subpeaks,
%   - an optional wavelet time-frequency panel under the trace.
%
% Input
%   magnitudeFilePath
%       Path to a MAT file containing motionData.motionEnvelope,
%       motionData.timeSec, and motionData.meta.sampleRateHz.
%
% Name-value options
%   'WindowSeconds'                    default []
%       Two-element [start end] window in the file's original time seconds.
%       If empty, the full file is plotted.
%   'BaselineWindowSeconds'            default 15
%   'NoiseWindowSeconds'               default 30
%   'ThresholdSigma'                   default 4
%   'CompoundSearchWindowSeconds'      default [-1.5 4.5]
%   'CompoundSubpeakThresholdSigma'    default 2
%   'CompoundSubpeakMinDistanceSeconds' default 0.35
%   'CompoundValleyFraction'           default 0.50
%   'MarkerOffsetFraction'             default 0.035
%   'ShowWavelet'                      default true
%   'WaveletSource'                    default "motionEnvelope"
%       One of "eventSignal", "motionEnvelope", or "residual".
%   'WaveletFrequencyLimitsHz'         default [0.1 10]
%   'UseWaveletFrequencyLimits'        default false
%       If false, use cwt(signal, fs) like analyzeFrequencyStructure.m and
%       only crop the displayed y-axis. This is the closest match to the
%       earlier frequency diagnostic figures.
%   'WaveletName'                      default "default"
%       "default" uses MATLAB's default cwt wavelet. Other values are passed
%       to cwt, for example "amor".
%   'WaveletVoicesPerOctave'           default 12
%   'WaveletMaxSamples'                default Inf
%   'CenterWaveletSignal'              default true
%   'NormalizeWaveletSignal'           default false
%   'WaveletColorPercentile'           default 100
%   'ShowWaveletEventLines'            default false
%   'OutputPngPath'                    default ""
%   'OutputFigPath'                    default ""
%   'FigureTitle'                      default ""
%   'FigurePosition'                   default [100 100 1200 780]
%
% Output
%   figureHandle
%       Handle to the generated figure.
%   plotOutput
%       Struct containing the event output, threshold vector, selected
%       window mask, and plotted event tables.
%
% Notes
%   The shaded region is the detector-equivalent envelope-domain background
%   region below localBaseline + ThresholdSigma * median(localNoiseSigma).
%   The detector itself works on eventSignal = max(motionEnvelope -
%   localBaseline, 0), and uses the median noise estimate as the minimum
%   peak height, so this line is the same threshold expressed in the
%   original motion-envelope units.

inputParserObject = inputParser;

addRequired(inputParserObject, 'magnitudeFilePath', ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'WindowSeconds', [], ...
    @(value) isempty(value) || (isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) < value(2)));

addParameter(inputParserObject, 'BaselineWindowSeconds', 15, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'NoiseWindowSeconds', 30, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'ThresholdSigma', 4, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'CompoundSearchWindowSeconds', [-1.5 4.5], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) < value(2));

addParameter(inputParserObject, 'CompoundSubpeakThresholdSigma', 2, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'CompoundSubpeakMinDistanceSeconds', 0.35, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'CompoundValleyFraction', 0.50, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0 && value < 1);

addParameter(inputParserObject, 'MarkerOffsetFraction', 0.035, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0);

addParameter(inputParserObject, 'ShowWavelet', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveletSource', "motionEnvelope", ...
    @(value) any(strcmpi(string(value), ["eventSignal", "motionEnvelope", "residual"])));

addParameter(inputParserObject, 'WaveletFrequencyLimitsHz', [0.1 10], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) > 0 && value(1) < value(2));

addParameter(inputParserObject, 'UseWaveletFrequencyLimits', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveletName', "default", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'WaveletVoicesPerOctave', 12, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'WaveletMaxSamples', Inf, ...
    @(value) isnumeric(value) && isscalar(value) && (isinf(value) || value >= 1000));

addParameter(inputParserObject, 'CenterWaveletSignal', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'NormalizeWaveletSignal', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveletColorPercentile', 100, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0 && value <= 100);

addParameter(inputParserObject, 'ShowWaveletEventLines', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'OutputPngPath', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'OutputFigPath', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'FigureTitle', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'FigurePosition', [100 100 1200 780], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 4);

parse(inputParserObject, magnitudeFilePath, varargin{:});
options = inputParserObject.Results;

magnitudeFilePath = char(options.magnitudeFilePath);
loadedData = load(magnitudeFilePath, 'motionData');
if ~isfield(loadedData, 'motionData')
    error('plotEnvelopeEventsWithNoiseBand:MissingMotionData', ...
        'File must contain a motionData struct: %s', magnitudeFilePath);
end

motionData = loadedData.motionData;
motionEnvelope = motionData.motionEnvelope(:);
timeSec = motionData.timeSec(:);
samplingFrequency = motionData.meta.sampleRateHz;

eventOutput = extractEnvelopeEvents(motionEnvelope, samplingFrequency, ...
    'TimeSec', timeSec, ...
    'BaselineWindowSeconds', options.BaselineWindowSeconds, ...
    'NoiseWindowSeconds', options.NoiseWindowSeconds, ...
    'RectifyResidual', true, ...
    'ThresholdSigma', options.ThresholdSigma, ...
    'CompoundSearchWindowSeconds', options.CompoundSearchWindowSeconds, ...
    'CompoundSubpeakThresholdSigma', options.CompoundSubpeakThresholdSigma, ...
    'CompoundSubpeakMinDistanceSeconds', options.CompoundSubpeakMinDistanceSeconds, ...
    'CompoundValleyFraction', options.CompoundValleyFraction, ...
    'MakeWaveformFigure', false, ...
    'MakeSummaryFigure', false);

detectorNoiseSigma = median(eventOutput.noiseEstimate.noiseSigma, 'omitnan');
envelopeThreshold = eventOutput.noiseEstimate.baseline + ...
    options.ThresholdSigma .* detectorNoiseSigma;
localEnvelopeThreshold = eventOutput.noiseEstimate.baseline + ...
    options.ThresholdSigma .* eventOutput.noiseEstimate.noiseSigma;

if isempty(options.WindowSeconds)
    windowStartSec = min(timeSec);
    windowEndSec = max(timeSec);
else
    windowStartSec = options.WindowSeconds(1);
    windowEndSec = options.WindowSeconds(2);
end

windowMask = timeSec >= windowStartSec & timeSec <= windowEndSec;
if ~any(windowMask)
    error('plotEnvelopeEventsWithNoiseBand:EmptyWindow', ...
        'Requested window %.3f-%.3f s does not overlap the file.', ...
        windowStartSec, windowEndSec);
end

windowTimeSec = timeSec(windowMask) - windowStartSec;
windowEnvelope = motionEnvelope(windowMask);
windowThreshold = envelopeThreshold(windowMask);
windowEventSignal = eventOutput.noiseEstimate.eventSignal(windowMask);
windowResidual = eventOutput.noiseEstimate.residual(windowMask);

figureHandle = figure('Color', 'w', 'Visible', 'on', ...
    'WindowStyle', 'normal', ...
    'WindowState', 'normal', ...
    'Units', 'pixels', ...
    'Position', options.FigurePosition);

if logical(options.ShowWavelet)
    tiledLayoutHandle = tiledlayout(figureHandle, 2, 1, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');
    axesHandle = nexttile(tiledLayoutHandle, 1);
else
    tiledLayoutHandle = [];
    axesHandle = axes(figureHandle);
end
hold(axesHandle, 'on');

yLimitTop = localChooseYLimitTop(windowEnvelope, windowThreshold);
localPlotNoiseBand(axesHandle, windowTimeSec, windowThreshold, yLimitTop);
plot(axesHandle, windowTimeSec, windowEnvelope, ...
    'Color', [0.02 0.02 0.02], ...
    'LineWidth', 0.85, ...
    'DisplayName', 'motion envelope');
plot(axesHandle, windowTimeSec, windowThreshold, ...
    'Color', [0.45 0.45 0.45], ...
    'LineStyle', '--', ...
    'LineWidth', 1.0, ...
    'DisplayName', sprintf('local threshold (%.1f sigma)', options.ThresholdSigma));

eventTable = eventOutput.eventTable;
[unitaryPeakRows, compoundSubpeakRows] = localBuildPeakTables(eventTable, timeSec, motionEnvelope);
unitaryPeakRows = unitaryPeakRows(unitaryPeakRows.timeSec >= windowStartSec & ...
    unitaryPeakRows.timeSec <= windowEndSec, :);
compoundSubpeakRows = compoundSubpeakRows(compoundSubpeakRows.timeSec >= windowStartSec & ...
    compoundSubpeakRows.timeSec <= windowEndSec, :);

markerOffset = options.MarkerOffsetFraction .* yLimitTop;
localPlotPeakDots(axesHandle, unitaryPeakRows, windowStartSec, markerOffset, yLimitTop, ...
    [0.05 0.35 0.70], 'unitary peak');
localPlotPeakDots(axesHandle, compoundSubpeakRows, windowStartSec, markerOffset, yLimitTop, ...
    [0.80 0.30 0.10], 'compound subpeaks');

ylim(axesHandle, [0 yLimitTop]);
xlim(axesHandle, [min(windowTimeSec) max(windowTimeSec)]);
grid(axesHandle, 'on');
xlabel(axesHandle, sprintf('time within %.0f-%.0f s segment (s)', windowStartSec, windowEndSec));
ylabel(axesHandle, 'motion envelope');

if strlength(string(options.FigureTitle)) > 0
    title(axesHandle, options.FigureTitle, 'Interpreter', 'none', 'FontWeight', 'normal');
else
    [~, fileStem, ~] = fileparts(magnitudeFilePath);
    title(axesHandle, sprintf('Motion envelope with event peaks: %s', fileStem), ...
        'Interpreter', 'none', 'FontWeight', 'normal');
end

legend(axesHandle, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');

waveletOutput = struct();
if logical(options.ShowWavelet)
    waveletAxes = nexttile(tiledLayoutHandle, 2);
    waveletSignal = localSelectWaveletSignal(options.WaveletSource, ...
        windowEventSignal, windowEnvelope, windowResidual);
    waveletOutput = localPlotWaveletPanel(waveletAxes, windowTimeSec, waveletSignal, ...
        samplingFrequency, options.WaveletFrequencyLimitsHz, ...
        logical(options.UseWaveletFrequencyLimits), options.WaveletName, ...
        options.WaveletVoicesPerOctave, options.WaveletMaxSamples, ...
        logical(options.CenterWaveletSignal), logical(options.NormalizeWaveletSignal), ...
        options.WaveletColorPercentile, logical(options.ShowWaveletEventLines), ...
        unitaryPeakRows, compoundSubpeakRows, windowStartSec, options.WaveletSource);
    linkaxes([axesHandle waveletAxes], 'x');
    xlim(waveletAxes, [min(windowTimeSec) max(windowTimeSec)]);
end

figureHandle.Visible = 'on';
figureHandle.WindowStyle = 'normal';
figureHandle.WindowState = 'normal';
figureHandle.Units = 'pixels';
figureHandle.Position = options.FigurePosition;
drawnow;

if strlength(string(options.OutputPngPath)) > 0
    exportgraphics(figureHandle, char(options.OutputPngPath), 'Resolution', 240);
end

if strlength(string(options.OutputFigPath)) > 0
    savefig(figureHandle, char(options.OutputFigPath));
end

plotOutput = struct();
plotOutput.eventOutput = eventOutput;
plotOutput.envelopeThreshold = envelopeThreshold;
plotOutput.localEnvelopeThreshold = localEnvelopeThreshold;
plotOutput.detectorNoiseSigma = detectorNoiseSigma;
plotOutput.wavelet = waveletOutput;
plotOutput.windowMask = windowMask;
plotOutput.windowSeconds = [windowStartSec windowEndSec];
plotOutput.unitaryPeakRows = unitaryPeakRows;
plotOutput.compoundSubpeakRows = compoundSubpeakRows;
plotOutput.figureHandle = figureHandle;
end

function waveletSignal = localSelectWaveletSignal(waveletSource, windowEventSignal, windowEnvelope, windowResidual)
switch lower(char(string(waveletSource)))
    case 'eventsignal'
        waveletSignal = windowEventSignal;
    case 'motionenvelope'
        waveletSignal = windowEnvelope;
    case 'residual'
        waveletSignal = windowResidual;
    otherwise
        error('plotEnvelopeEventsWithNoiseBand:UnknownWaveletSource', ...
            'Unknown WaveletSource: %s', char(string(waveletSource)));
end
waveletSignal = waveletSignal(:);
end

function waveletOutput = localPlotWaveletPanel(axesHandle, windowTimeSec, waveletSignal, ...
    samplingFrequency, frequencyLimitsHz, useWaveletFrequencyLimits, waveletName, ...
    voicesPerOctave, maxWaveletSamples, ...
    centerWaveletSignal, normalizeWaveletSignal, colorPercentile, showWaveletEventLines, ...
    unitaryPeakRows, compoundSubpeakRows, windowStartSec, waveletSource)

[analysisTimeSec, analysisSignal, analysisSamplingFrequency, downsampleFactor] = ...
    localPrepareWaveletSignal(windowTimeSec, waveletSignal, samplingFrequency, maxWaveletSamples);

displayFrequencyLimitsHz = localClampFrequencyLimits(frequencyLimitsHz, analysisSamplingFrequency);
if centerWaveletSignal
    analysisSignal = analysisSignal - median(analysisSignal, 'omitnan');
end
if normalizeWaveletSignal
    scaleValue = max(abs(analysisSignal), [], 'omitnan');
    if isfinite(scaleValue) && scaleValue > 0
        analysisSignal = analysisSignal ./ scaleValue;
    end
end

[coefficients, frequencyHz] = localComputeWavelet(analysisSignal, analysisSamplingFrequency, ...
    displayFrequencyLimitsHz, useWaveletFrequencyLimits, waveletName, voicesPerOctave);
waveletMagnitude = abs(coefficients);
colorScale = prctile(waveletMagnitude(:), colorPercentile);
if ~isfinite(colorScale) || colorScale <= 0
    colorScale = max(waveletMagnitude(:), [], 'omitnan');
end

imagesc(axesHandle, analysisTimeSec, frequencyHz, waveletMagnitude);
axis(axesHandle, 'xy');
ylim(axesHandle, displayFrequencyLimitsHz);
colormap(axesHandle, turbo);
colorbar(axesHandle);
if isfinite(colorScale) && colorScale > 0
    clim(axesHandle, [0 colorScale]);
end
hold(axesHandle, 'on');
if showWaveletEventLines
    localOverlayWaveletEventLines(axesHandle, unitaryPeakRows, windowStartSec, ...
        [0.05 0.35 0.70], '-');
    localOverlayWaveletEventLines(axesHandle, compoundSubpeakRows, windowStartSec, ...
        [0.80 0.30 0.10], '-');
end
grid(axesHandle, 'on');
xlabel(axesHandle, 'time within segment (s)');
ylabel(axesHandle, 'frequency (Hz)');
title(axesHandle, sprintf('CWT magnitude of %s, %.1f-%.1f Hz', ...
    char(string(waveletSource)), displayFrequencyLimitsHz(1), displayFrequencyLimitsHz(2)), ...
    'Interpreter', 'none', 'FontWeight', 'normal');

waveletOutput = struct();
waveletOutput.timeSec = analysisTimeSec;
waveletOutput.frequencyHz = frequencyHz;
waveletOutput.magnitude = waveletMagnitude;
waveletOutput.downsampleFactor = downsampleFactor;
waveletOutput.samplingFrequency = analysisSamplingFrequency;
waveletOutput.frequencyLimitsHz = displayFrequencyLimitsHz;
waveletOutput.useWaveletFrequencyLimits = useWaveletFrequencyLimits;
waveletOutput.waveletName = string(waveletName);
waveletOutput.colorPercentile = colorPercentile;
waveletOutput.colorScale = colorScale;
waveletOutput.centerWaveletSignal = centerWaveletSignal;
waveletOutput.normalizeWaveletSignal = normalizeWaveletSignal;
waveletOutput.showWaveletEventLines = showWaveletEventLines;
end

function [coefficients, frequencyHz] = localComputeWavelet(analysisSignal, samplingFrequency, ...
    frequencyLimitsHz, useWaveletFrequencyLimits, waveletName, voicesPerOctave)
waveletName = string(waveletName);

if strcmpi(waveletName, "default") && ~useWaveletFrequencyLimits
    [coefficients, frequencyHz] = cwt(analysisSignal, samplingFrequency);
elseif strcmpi(waveletName, "default")
    [coefficients, frequencyHz] = cwt(analysisSignal, samplingFrequency, ...
        'FrequencyLimits', frequencyLimitsHz, ...
        'VoicesPerOctave', voicesPerOctave);
elseif useWaveletFrequencyLimits
    [coefficients, frequencyHz] = cwt(analysisSignal, char(waveletName), samplingFrequency, ...
        'FrequencyLimits', frequencyLimitsHz, ...
        'VoicesPerOctave', voicesPerOctave);
else
    [coefficients, frequencyHz] = cwt(analysisSignal, char(waveletName), samplingFrequency, ...
        'VoicesPerOctave', voicesPerOctave);
end
end

function [analysisTimeSec, analysisSignal, analysisSamplingFrequency, downsampleFactor] = ...
    localPrepareWaveletSignal(windowTimeSec, waveletSignal, samplingFrequency, maxWaveletSamples)

finiteMask = isfinite(windowTimeSec(:)) & isfinite(waveletSignal(:));
analysisTimeSec = windowTimeSec(finiteMask);
analysisSignal = waveletSignal(finiteMask);

if numel(analysisSignal) < 10
    error('plotEnvelopeEventsWithNoiseBand:TooFewWaveletSamples', ...
        'Need at least 10 finite samples for the wavelet panel.');
end

downsampleFactor = max(1, ceil(numel(analysisSignal) ./ maxWaveletSamples));
if downsampleFactor > 1
    analysisTimeSec = analysisTimeSec(1:downsampleFactor:end);
    analysisSignal = analysisSignal(1:downsampleFactor:end);
end

analysisSamplingFrequency = samplingFrequency ./ downsampleFactor;
end

function frequencyLimitsHz = localClampFrequencyLimits(frequencyLimitsHz, samplingFrequency)
nyquistFrequency = samplingFrequency ./ 2;
frequencyLimitsHz = double(frequencyLimitsHz(:).');
frequencyLimitsHz(2) = min(frequencyLimitsHz(2), nyquistFrequency .* 0.95);
if frequencyLimitsHz(1) >= frequencyLimitsHz(2)
    frequencyLimitsHz(1) = max(0.01, frequencyLimitsHz(2) ./ 10);
end
end

function localOverlayWaveletEventLines(axesHandle, peakRows, windowStartSec, colorValue, lineStyle)
if isempty(peakRows)
    return;
end
for peakIndex = 1:height(peakRows)
    xline(axesHandle, peakRows.timeSec(peakIndex) - windowStartSec, lineStyle, ...
        'Color', colorValue, ...
        'LineWidth', 0.8, ...
        'HandleVisibility', 'off');
end
end

function localPlotNoiseBand(axesHandle, windowTimeSec, windowThreshold, yLimitTop)
noiseBandTop = min(windowThreshold(:), yLimitTop);
patch(axesHandle, [windowTimeSec(:); flipud(windowTimeSec(:))], ...
    [zeros(numel(noiseBandTop), 1); flipud(noiseBandTop(:))], ...
    [0.84 0.84 0.84], ...
    'FaceAlpha', 0.28, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'background/noise region');
end

function yLimitTop = localChooseYLimitTop(windowEnvelope, windowThreshold)
candidateValues = [windowEnvelope(:); windowThreshold(:)];
candidateValues = candidateValues(isfinite(candidateValues));
if isempty(candidateValues)
    yLimitTop = 1;
    return;
end
robustTop = prctile(candidateValues, 99.8) .* 1.25;
maxTop = max(candidateValues) .* 1.05;
yLimitTop = max(robustTop, prctile(windowThreshold, 95) .* 1.4);
yLimitTop = min(maxTop, yLimitTop);
if ~isfinite(yLimitTop) || yLimitTop <= 0
    yLimitTop = max(candidateValues);
end
end

function [unitaryPeakRows, compoundSubpeakRows] = localBuildPeakTables(eventTable, timeSec, motionEnvelope)
unitaryRows = struct([]);
compoundRows = struct([]);
seenCompoundPeaks = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for eventIndex = 1:height(eventTable)
    if eventTable.isCompoundEvent(eventIndex)
        subpeakIndices = localParseIndexList(eventTable.sameBoutSubpeakIndicesText(eventIndex));
        for subpeakIndex = 1:numel(subpeakIndices)
            sampleIndex = subpeakIndices(subpeakIndex);
            key = sprintf('%d', sampleIndex);
            if isKey(seenCompoundPeaks, key)
                continue;
            end
            seenCompoundPeaks(key) = true;
            compoundRows(end + 1, 1).sampleIndex = sampleIndex; %#ok<AGROW>
            compoundRows(end, 1).timeSec = timeSec(sampleIndex);
            compoundRows(end, 1).value = motionEnvelope(sampleIndex);
        end
    else
        sampleIndex = eventTable.peakIndex(eventIndex);
        unitaryRows(end + 1, 1).sampleIndex = sampleIndex; %#ok<AGROW>
        unitaryRows(end, 1).timeSec = timeSec(sampleIndex);
        unitaryRows(end, 1).value = motionEnvelope(sampleIndex);
    end
end

if isempty(unitaryRows)
    unitaryPeakRows = table([], [], [], 'VariableNames', {'sampleIndex', 'timeSec', 'value'});
else
    unitaryPeakRows = struct2table(unitaryRows);
end

if isempty(compoundRows)
    compoundSubpeakRows = table([], [], [], 'VariableNames', {'sampleIndex', 'timeSec', 'value'});
else
    compoundSubpeakRows = struct2table(compoundRows);
end
end

function indices = localParseIndexList(textValue)
if strlength(string(textValue)) == 0
    indices = [];
else
    indices = str2double(split(string(textValue), ';')).';
    indices = indices(isfinite(indices));
    indices = round(indices);
end
end

function localPlotPeakDots(axesHandle, peakRows, windowStartSec, markerOffset, yLimitTop, ...
    colorValue, displayName)
if isempty(peakRows)
    return;
end
markerTimes = peakRows.timeSec - windowStartSec;
markerValues = min(yLimitTop .* 0.96, peakRows.value + markerOffset);
plot(axesHandle, markerTimes, markerValues, '.', ...
    'Color', colorValue, ...
    'MarkerSize', 16, ...
    'DisplayName', displayName);
end
