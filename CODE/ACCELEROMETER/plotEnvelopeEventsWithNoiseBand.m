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
%   'WindowSeconds2'                   default []
%       Optional second [start end] window to include. If empty, only the
%       primary window is used.
%   'BaselineWindowSeconds'            default 15
%   'NoiseWindowSeconds'               default 30
%   'ThresholdSigma'                   default 4
%   'CompoundSearchWindowSeconds'      default [-1.5 4.5]
%   'CompoundSubpeakThresholdSigma'    default 2
%   'CompoundSubpeakMinDistanceSeconds' default 0.35
%   'CompoundValleyFraction'           default 0.50
%   'MarkerOffsetFraction'             default 0.035
%   'ShowSlowEnvelope'                 default true
%   'SlowEnvelopeWindowSeconds'        default 10
%   'ShowSlowEnvelopeBand'             default true
%   'SlowEnvelopeBandScale'            default 1
%   'ShowSlowEnvelopeChangePoints'     default true
%   'SlowEnvelopeChangePointMaxCount'  default 5
%   'SlowEnvelopeChangePointMinSeconds' default 20
%   'ShowWavelet'                      default true
%   'WaveletSource'                    default "motionEnvelope"
%       One of "eventSignal", "motionEnvelope", or "residual".
%   'ShowWaveletBandPower'             default true
%   'WaveletBandPowerHz'               default [7 9]
%   'ShowWaveletBandPowerTrend'        default true
%   'WaveletBandPowerTrendWindowSeconds' default 30
%   'ShowWaveletBandPowerMinima'       default true
%   'WaveletBandPowerMinSeparationSeconds' default 30
%   'WaveletBandPowerMinProminence'    default 0
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

addParameter(inputParserObject, 'WindowSeconds2', [], ...
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

addParameter(inputParserObject, 'ShowSlowEnvelope', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'SlowEnvelopeWindowSeconds', 10, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'ShowSlowEnvelopeBand', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'SlowEnvelopeBandScale', 1, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'ShowSlowEnvelopeChangePoints', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'SlowEnvelopeChangePointMaxCount', 5, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0);

addParameter(inputParserObject, 'SlowEnvelopeChangePointMinSeconds', 60, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'ShowWavelet', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveletSource', "motionEnvelope", ...
    @(value) any(strcmpi(string(value), ["eventSignal", "motionEnvelope", "residual"])));

addParameter(inputParserObject, 'ShowWaveletBandPower', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveletBandPowerHz', [7 9], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) > 0 && value(1) < value(2));

addParameter(inputParserObject, 'ShowWaveletBandPowerTrend', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveletBandPowerTrendWindowSeconds', 10, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'ShowWaveletBandPowerMinima', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveletBandPowerMinSeparationSeconds', 60, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'WaveletBandPowerMinProminence', 0, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0);

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

[windowRanges, windowStartSec, windowEndSec] = localBuildWindowRanges(timeSec, options.WindowSeconds, options.WindowSeconds2);
windowMask = localIsInWindows(timeSec, windowRanges);
if ~any(windowMask)
    error('plotEnvelopeEventsWithNoiseBand:EmptyWindow', ...
        'Requested windows do not overlap the file.');
end

[windowTimeSec, windowEnvelope, windowThreshold, windowEventSignal, windowResidual, ...
    slowEnvelope, slowEnvelopeMad, changePointTimes] = localCollectWindowSegments(timeSec, motionEnvelope, ...
    envelopeThreshold, eventOutput.noiseEstimate.eventSignal, eventOutput.noiseEstimate.residual, ...
    windowRanges, windowStartSec, samplingFrequency, options);

figureHandle = figure('Color', 'w', 'Visible', 'on', ...
    'WindowStyle', 'normal', ...
    'WindowState', 'normal', ...
    'Units', 'pixels', ...
    'Position', options.FigurePosition);

showWavelet = logical(options.ShowWavelet);
showBandPower = logical(options.ShowWaveletBandPower);
showStacked = showWavelet || showBandPower;

if showStacked
    panelCount = 1 + (2 * showWavelet) + showBandPower;
    tiledLayoutHandle = tiledlayout(figureHandle, panelCount, 1, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');
    axesHandle = nexttile(tiledLayoutHandle, 1);
    slowAxesHandle = [];
    bandPowerAxesHandle = [];
    waveletAxesHandle = [];
    if showWavelet && showBandPower
        slowAxesHandle = nexttile(tiledLayoutHandle, 2);
        bandPowerAxesHandle = nexttile(tiledLayoutHandle, 3);
        waveletAxesHandle = nexttile(tiledLayoutHandle, 4);
    elseif showWavelet
        slowAxesHandle = nexttile(tiledLayoutHandle, 2);
        waveletAxesHandle = nexttile(tiledLayoutHandle, 3);
    else
        bandPowerAxesHandle = nexttile(tiledLayoutHandle, 2);
    end
else
    tiledLayoutHandle = [];
    axesHandle = axes(figureHandle);
    slowAxesHandle = [];
    bandPowerAxesHandle = [];
    waveletAxesHandle = [];
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
if size(windowRanges, 1) > 1
    unitaryPeakRows = unitaryPeakRows(localIsInWindows(unitaryPeakRows.timeSec, windowRanges), :);
    compoundSubpeakRows = compoundSubpeakRows(localIsInWindows(compoundSubpeakRows.timeSec, windowRanges), :);
end

markerOffset = options.MarkerOffsetFraction .* yLimitTop;
localPlotPeakDots(axesHandle, unitaryPeakRows, windowStartSec, markerOffset, yLimitTop, ...
    [0.05 0.35 0.70], 'unitary peak');
localPlotPeakDots(axesHandle, compoundSubpeakRows, windowStartSec, markerOffset, yLimitTop, ...
    [0.80 0.30 0.10], 'compound subpeaks');

ylim(axesHandle, [0 yLimitTop]);
xlim(axesHandle, [min(windowTimeSec) max(windowTimeSec)]);
grid(axesHandle, 'on');
if size(windowRanges, 1) == 1
    xlabel(axesHandle, sprintf('time within %.0f-%.0f s segment (s)', windowStartSec, windowEndSec));
else
    xlabel(axesHandle, 'time within selected segments (s)');
end
ylabel(axesHandle, 'motion envelope');

if strlength(string(options.FigureTitle)) > 0
    title(axesHandle, options.FigureTitle, 'Interpreter', 'none', 'FontWeight', 'normal');
else
    [~, fileStem, ~] = fileparts(magnitudeFilePath);
    title(axesHandle, sprintf('Motion envelope with event peaks: %s', fileStem), ...
        'Interpreter', 'none', 'FontWeight', 'normal');
end

legend(axesHandle, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');

if isempty(slowAxesHandle)
    if logical(options.ShowSlowEnvelope)
        if logical(options.ShowSlowEnvelopeBand)
            localPlotSlowEnvelopeBand(axesHandle, windowTimeSec, slowEnvelope, slowEnvelopeMad, options);
        end
        plot(axesHandle, windowTimeSec, slowEnvelope, ...
            'Color', [0.35 0.45 0.90], ...
            'LineWidth', 2.2, ...
            'DisplayName', sprintf('slow envelope (%.0f s median)', options.SlowEnvelopeWindowSeconds));
        legend(axesHandle, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
    end
else
    hold(slowAxesHandle, 'on');
    if logical(options.ShowSlowEnvelope)
        if logical(options.ShowSlowEnvelopeBand)
            localPlotSlowEnvelopeBand(slowAxesHandle, windowTimeSec, slowEnvelope, slowEnvelopeMad, options);
        end
        plot(slowAxesHandle, windowTimeSec, slowEnvelope, ...
            'Color', [0.35 0.45 0.90], ...
            'LineWidth', 2.2, ...
            'DisplayName', sprintf('slow envelope (%.0f s median)', options.SlowEnvelopeWindowSeconds));
    end
    if ~isempty(changePointTimes)
        localPlotChangePointMarkers(slowAxesHandle, changePointTimes);
    end
    xlim(slowAxesHandle, [min(windowTimeSec) max(windowTimeSec)]);
    grid(slowAxesHandle, 'on');
    ylabel(slowAxesHandle, 'slow envelope');
end

waveletOutput = struct();
if showWavelet
    waveletAxes = waveletAxesHandle;
    waveletSignal = localSelectWaveletSignal(options.WaveletSource, ...
        windowEventSignal, windowEnvelope, windowResidual);
    waveletOutput = localPlotWaveletPanel(waveletAxes, windowTimeSec, waveletSignal, ...
        samplingFrequency, options.WaveletFrequencyLimitsHz, ...
        logical(options.UseWaveletFrequencyLimits), options.WaveletName, ...
        options.WaveletVoicesPerOctave, options.WaveletMaxSamples, ...
        logical(options.CenterWaveletSignal), logical(options.NormalizeWaveletSignal), ...
        options.WaveletColorPercentile, logical(options.ShowWaveletEventLines), ...
        unitaryPeakRows, compoundSubpeakRows, windowStartSec, options.WaveletSource, ...
        options.WaveletBandPowerHz);
    linkAxesList = [axesHandle waveletAxes];
    if ~isempty(slowAxesHandle)
        linkAxesList = [linkAxesList slowAxesHandle];
    end
    if showBandPower && ~isempty(bandPowerAxesHandle)
        linkAxesList = [linkAxesList bandPowerAxesHandle];
    end
    linkaxes(linkAxesList, 'x');
    xlim(waveletAxes, [min(windowTimeSec) max(windowTimeSec)]);
end

if showBandPower && ~isempty(bandPowerAxesHandle)
    localPlotWaveletBandPower(bandPowerAxesHandle, waveletOutput, options);
    grid(bandPowerAxesHandle, 'on');
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
plotOutput.windowSeconds = windowRanges;
plotOutput.unitaryPeakRows = unitaryPeakRows;
plotOutput.compoundSubpeakRows = compoundSubpeakRows;
plotOutput.slowEnvelope = slowEnvelope;
plotOutput.slowEnvelopeMad = slowEnvelopeMad;
plotOutput.slowEnvelopeChangePointTimes = changePointTimes;
plotOutput.waveletBandPower = localExtractWaveletBandPowerSummary(waveletOutput);
plotOutput.figureHandle = figureHandle;
end

function [slowEnvelope, slowEnvelopeMad] = localComputeSlowEnvelopeStats(windowEnvelope, samplingFrequency, options)
if ~logical(options.ShowSlowEnvelope)
    slowEnvelope = nan(size(windowEnvelope));
    slowEnvelopeMad = nan(size(windowEnvelope));
    return;
end

windowSamples = max(3, round(options.SlowEnvelopeWindowSeconds .* samplingFrequency));
if mod(windowSamples, 2) == 0
    windowSamples = windowSamples + 1;
end
windowSamples = min(windowSamples, max(3, numel(windowEnvelope)));
slowEnvelope = movmedian(windowEnvelope, windowSamples, 'omitnan');
slowEnvelopeMad = movmad(windowEnvelope, windowSamples, 1, 'omitnan') .* options.SlowEnvelopeBandScale;
slowEnvelope = slowEnvelope(:);
slowEnvelopeMad = slowEnvelopeMad(:);
end

function localPlotSlowEnvelopeBand(axesHandle, windowTimeSec, slowEnvelope, slowEnvelopeMad, options)
if ~logical(options.ShowSlowEnvelopeBand)
    return;
end

upperBand = slowEnvelope + slowEnvelopeMad;
lowerBand = max(0, slowEnvelope - slowEnvelopeMad);
bandColor = [0.35 0.45 0.90];
patch(axesHandle, [windowTimeSec(:); flipud(windowTimeSec(:))], ...
    [lowerBand(:); flipud(upperBand(:))], ...
    bandColor, ...
    'FaceAlpha', 0.18, ...
    'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
end

function [windowTimeSec, windowEnvelope, windowThreshold, windowEventSignal, windowResidual, ...
    slowEnvelope, slowEnvelopeMad, changePointTimes] = localCollectWindowSegments(timeSec, motionEnvelope, ...
    envelopeThreshold, eventSignal, residualSignal, windowRanges, windowStartSec, samplingFrequency, options)

segmentCount = size(windowRanges, 1);
timeCells = cell(segmentCount, 1);
envelopeCells = cell(segmentCount, 1);
thresholdCells = cell(segmentCount, 1);
eventSignalCells = cell(segmentCount, 1);
residualCells = cell(segmentCount, 1);
slowEnvelopeCells = cell(segmentCount, 1);
slowMadCells = cell(segmentCount, 1);
changePointTimes = [];

for segmentIndex = 1:segmentCount
    segmentStart = windowRanges(segmentIndex, 1);
    segmentEnd = windowRanges(segmentIndex, 2);
    segmentMask = timeSec >= segmentStart & timeSec <= segmentEnd;
    if ~any(segmentMask)
        error('plotEnvelopeEventsWithNoiseBand:EmptyWindow', ...
            'Requested window %.3f-%.3f s does not overlap the file.', ...
            segmentStart, segmentEnd);
    end
    timeCells{segmentIndex} = timeSec(segmentMask) - windowStartSec;
    envelopeCells{segmentIndex} = motionEnvelope(segmentMask);
    thresholdCells{segmentIndex} = envelopeThreshold(segmentMask);
    eventSignalCells{segmentIndex} = eventSignal(segmentMask);
    residualCells{segmentIndex} = residualSignal(segmentMask);
    [slowEnvelopeCells{segmentIndex}, slowMadCells{segmentIndex}] = ...
        localComputeSlowEnvelopeStats(envelopeCells{segmentIndex}, samplingFrequency, options);
    changePointTimes = [changePointTimes; ...
        localFindSlowEnvelopeChangePoints(timeCells{segmentIndex}, slowMadCells{segmentIndex}, ...
        samplingFrequency, options)]; %#ok<AGROW>
end

[windowTimeSec, windowEnvelope, windowThreshold, windowEventSignal, windowResidual] = ...
    localConcatenateSegments(timeCells, envelopeCells, thresholdCells, eventSignalCells, residualCells);
[~, slowEnvelope, slowEnvelopeMad] = ...
    localConcatenateSegments(timeCells, slowEnvelopeCells, slowMadCells);
changePointTimes = sort(changePointTimes(:));
end

function [windowRanges, windowStartSec, windowEndSec] = localBuildWindowRanges(timeSec, windowSeconds, windowSeconds2)
timeMin = min(timeSec);
timeMax = max(timeSec);

if isempty(windowSeconds)
    windowSeconds = [timeMin timeMax];
    windowSeconds2 = [];
end

windowRanges = double(windowSeconds(:).');
if ~isempty(windowSeconds2)
    windowRanges = [windowRanges; double(windowSeconds2(:).')];
end

windowRanges = sortrows(windowRanges, 1);
windowStartSec = min(windowRanges(:, 1));
windowEndSec = max(windowRanges(:, 2));
end

function windowMask = localIsInWindows(timeValues, windowRanges)
windowMask = false(size(timeValues));
for index = 1:size(windowRanges, 1)
    windowMask = windowMask | (timeValues >= windowRanges(index, 1) & timeValues <= windowRanges(index, 2));
end
end

function [combinedTime, varargout] = localConcatenateSegments(timeCells, varargin)
segmentCount = numel(timeCells);
combinedTime = [];
varargout = cell(1, numel(varargin));
for index = 1:numel(varargin)
    varargout{index} = [];
end

for segmentIndex = 1:segmentCount
    segmentTime = timeCells{segmentIndex}(:);
    combinedTime = [combinedTime; segmentTime]; %#ok<AGROW>
    for index = 1:numel(varargin)
        segmentData = varargin{index}{segmentIndex}(:);
        varargout{index} = [varargout{index}; segmentData]; %#ok<AGROW>
    end
    if segmentIndex < segmentCount
        combinedTime = [combinedTime; NaN]; %#ok<AGROW>
        for index = 1:numel(varargin)
            varargout{index} = [varargout{index}; NaN]; %#ok<AGROW>
        end
    end
end
end

function changePointTimes = localFindSlowEnvelopeChangePoints(windowTimeSec, slowEnvelopeMad, samplingFrequency, options)
changePointTimes = [];
if ~logical(options.ShowSlowEnvelopeChangePoints)
    return;
end

if options.SlowEnvelopeChangePointMaxCount <= 0
    return;
end

validMask = isfinite(windowTimeSec(:)) & isfinite(slowEnvelopeMad(:));
if nnz(validMask) < 10
    return;
end

analysisTime = windowTimeSec(validMask);
analysisSignal = slowEnvelopeMad(validMask);
minDistanceSamples = max(1, round(options.SlowEnvelopeChangePointMinSeconds .* samplingFrequency));

try
    changePointIndex = findchangepts(analysisSignal, ...
        'Statistic', 'mean', ...
        'MaxNumChanges', options.SlowEnvelopeChangePointMaxCount, ...
        'MinDistance', minDistanceSamples);
catch
    return;
end

if isempty(changePointIndex)
    return;
end

changePointIndex = changePointIndex(changePointIndex >= 1 & changePointIndex <= numel(analysisTime));
changePointTimes = analysisTime(changePointIndex);
changePointTimes = sort(changePointTimes(:));
end

function localPlotChangePointMarkers(axesHandle, changePointTimes)
if isempty(changePointTimes)
    return;
end

for index = 1:numel(changePointTimes)
    xline(axesHandle, changePointTimes(index), '--', ...
        'Color', [0.82 0.25 0.25], ...
        'LineWidth', 2.0, ...
        'HandleVisibility', 'off');
end
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
    unitaryPeakRows, compoundSubpeakRows, windowStartSec, waveletSource, bandPowerHz)

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
waveletOutput.bandPower = localComputeWaveletBandPower(analysisTimeSec, frequencyHz, waveletMagnitude, ...
    bandPowerHz);
end

function bandPowerOutput = localComputeWaveletBandPower(analysisTimeSec, frequencyHz, waveletMagnitude, bandLimitsHz)
bandPowerOutput = struct('timeSec', [], 'bandHz', [], 'power', []);
if isempty(analysisTimeSec) || isempty(frequencyHz) || isempty(waveletMagnitude)
    return;
end

bandMask = frequencyHz >= bandLimitsHz(1) & frequencyHz <= bandLimitsHz(2);
if ~any(bandMask)
    return;
end

bandPower = mean(waveletMagnitude(bandMask, :), 1, 'omitnan');
bandPowerOutput.timeSec = analysisTimeSec(:);
bandPowerOutput.bandHz = bandLimitsHz(:).';
bandPowerOutput.power = bandPower(:);
end

function localPlotWaveletBandPower(axesHandle, waveletOutput, options)
bandPowerOutput = localExtractWaveletBandPowerSummary(waveletOutput);
if isempty(bandPowerOutput.timeSec)
    return;
end

hold(axesHandle, 'on');
timeSec = bandPowerOutput.timeSec(:);
power = bandPowerOutput.power(:);

if logical(options.ShowWaveletBandPowerTrend)
    trend = localComputeBandPowerTrend(timeSec, power, options);
    if ~isempty(trend)
        plot(axesHandle, timeSec, trend, ...
            'Color', [0.15 0.35 0.10], ...
            'LineWidth', 1.15, ...
            'DisplayName', sprintf('CWT %.1f-%.1f Hz trend', options.WaveletBandPowerHz));
        if logical(options.ShowWaveletBandPowerMinima)
            minimaMask = localFindBandPowerMinima(timeSec, trend, options);
            if any(minimaMask)
                plot(axesHandle, timeSec(minimaMask), trend(minimaMask), 'v', ...
                    'Color', [0.15 0.10 0.10], ...
                    'MarkerFaceColor', [0.10 0.10 0.10], ...
                    'MarkerSize', 5, ...
                    'HandleVisibility', 'off');
            end
        end
    end
end

ylabel(axesHandle, sprintf('CWT %.1f-%.1f Hz power', options.WaveletBandPowerHz));
end

function trend = localComputeBandPowerTrend(timeSec, power, options)
trend = [];
if numel(timeSec) < 5
    return;
end

timeStep = median(diff(timeSec), 'omitnan');
if ~isfinite(timeStep) || timeStep <= 0
    return;
end

windowSamples = max(3, round(options.WaveletBandPowerTrendWindowSeconds ./ timeStep));
if mod(windowSamples, 2) == 0
    windowSamples = windowSamples + 1;
end
windowSamples = min(windowSamples, max(3, numel(power)));
trend = movmedian(power, windowSamples, 'omitnan');
trend = trend(:);
end

function minimaMask = localFindBandPowerMinima(timeSec, trend, options)
minimaMask = false(size(trend));
if numel(trend) < 5
    return;
end

timeStep = median(diff(timeSec), 'omitnan');
if ~isfinite(timeStep) || timeStep <= 0
    return;
end

minSeparationSamples = max(1, round(options.WaveletBandPowerMinSeparationSeconds ./ timeStep));
minimaMask = islocalmin(trend, ...
    'MinSeparation', minSeparationSamples, ...
    'MinProminence', options.WaveletBandPowerMinProminence);
end

function bandPowerOutput = localExtractWaveletBandPowerSummary(waveletOutput)
if isstruct(waveletOutput) && isfield(waveletOutput, 'bandPower')
    bandPowerOutput = waveletOutput.bandPower;
else
    bandPowerOutput = struct('timeSec', [], 'bandHz', [], 'power', []);
end
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
