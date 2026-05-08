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
%   - unitary event peaks and compound-event subpeaks.
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
%   'OutputPngPath'                    default ""
%   'OutputFigPath'                    default ""
%   'FigureTitle'                      default ""
%   'FigurePosition'                   default [100 100 1200 600]
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

addParameter(inputParserObject, 'OutputPngPath', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'OutputFigPath', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'FigureTitle', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'FigurePosition', [100 100 1200 600], ...
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

figureHandle = figure('Color', 'w', 'Visible', 'on', ...
    'WindowStyle', 'normal', ...
    'WindowState', 'normal', ...
    'Units', 'pixels', ...
    'Position', options.FigurePosition);
axesHandle = axes(figureHandle);
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
plotOutput.windowMask = windowMask;
plotOutput.windowSeconds = [windowStartSec windowEndSec];
plotOutput.unitaryPeakRows = unitaryPeakRows;
plotOutput.compoundSubpeakRows = compoundSubpeakRows;
plotOutput.figureHandle = figureHandle;
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
