function analysisOutput = analyzePrimitiveEvents(magnitudeFolder, varargin)
%ANALYZEPRIMITIVEEVENTS Analyze envelope events across a folder of magnitude files.
%
% analysisOutput = analyzePrimitiveEvents(magnitudeFolder)
%
% Purpose
%   Load all `*_motionEnvelope.mat` files in one folder, run the current
%   envelope-event pipeline on each file, and return one compiled MATLAB
%   output structure together with summary figures.
%
% Input
%   magnitudeFolder
%       Folder containing magnitude MAT files produced by the current
%       chest-envelope workflow.
%
% Optional name-value inputs
%   'FilePattern'               default '*_motionEnvelope.mat'
%   'ThresholdSigma'            default 4
%   'BaselineWindowSeconds'     default 15
%   'NoiseWindowSeconds'        default 30
%   'RectifyResidual'           default true
%   'MaxStartLookbackSeconds'   default 2.0
%   'MaxEndLookaheadSeconds'    default 2.0
%   'UseIsolatedEventsOnly'     default true
%   'MakeFigures'               default true
%   'OutputFolder'              default ""
%   'FigureStem'                default "primitive_event_summary"
%
% Output
%   analysisOutput.perFile
%       Struct array with one `extractEnvelopeEvents` result per file.
%   analysisOutput.allEventTable
%       Combined event-level table across files.
%   analysisOutput.fileSummaryTable
%   analysisOutput.conditionSummaryTable
%   analysisOutput.subjectSummaryTable
%   analysisOutput.meanWaveformTable
%   analysisOutput.figureHandles
%   analysisOutput.sourceFolder

%% Parse inputs

inputParserObject = inputParser;

addRequired(inputParserObject, 'magnitudeFolder', @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'FilePattern', '*_motionEnvelope.mat', ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'ThresholdSigma', 4, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'BaselineWindowSeconds', 15, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'NoiseWindowSeconds', 30, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'RectifyResidual', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'MaxStartLookbackSeconds', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'MaxEndLookaheadSeconds', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'UseIsolatedEventsOnly', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'MakeFigures', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'OutputFolder', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'FigureStem', "primitive_event_summary", ...
    @(value) ischar(value) || isstring(value));

parse(inputParserObject, magnitudeFolder, varargin{:});

options = inputParserObject.Results;
magnitudeFolder = char(string(options.magnitudeFolder));
useIsolatedEventsOnly = logical(options.UseIsolatedEventsOnly);

if ~isfolder(magnitudeFolder)
    error('analyzePrimitiveEvents:MissingMagnitudeFolder', ...
        'Magnitude folder not found: %s', magnitudeFolder);
end

filePattern = char(string(options.FilePattern));
fileListing = dir(fullfile(magnitudeFolder, filePattern));

if isempty(fileListing)
    error('analyzePrimitiveEvents:NoFilesFound', ...
        'No files matching %s found in %s', filePattern, magnitudeFolder);
end

outputFolder = char(string(options.OutputFolder));
if strlength(string(outputFolder)) > 0 && ~isfolder(outputFolder)
    mkdir(outputFolder);
end

%% Run event extraction for each file

perFile = repmat(struct( ...
    'fileName', "", ...
    'filePath', "", ...
    'subjectID', "", ...
    'condition', "", ...
    'motionData', [], ...
    'eventOutput', []), numel(fileListing), 1);

eventTables = cell(numel(fileListing), 1);
meanWaveformRows = struct([]);

for fileIndex = 1:numel(fileListing)
    fileName = fileListing(fileIndex).name;
    filePath = fullfile(fileListing(fileIndex).folder, fileName);
    loadedData = load(filePath, 'motionData');

    if ~isfield(loadedData, 'motionData')
        error('analyzePrimitiveEvents:MissingMotionData', ...
            'MAT file does not contain motionData: %s', filePath);
    end

    motionData = loadedData.motionData;
    fileInfo = localParseFileInfo(fileName);

    eventOutput = extractEnvelopeEvents( ...
        motionData.motionEnvelope, ...
        motionData.meta.sampleRateHz, ...
        'TimeSec', motionData.timeSec, ...
        'BaselineWindowSeconds', options.BaselineWindowSeconds, ...
        'NoiseWindowSeconds', options.NoiseWindowSeconds, ...
        'RectifyResidual', logical(options.RectifyResidual), ...
        'ThresholdSigma', options.ThresholdSigma, ...
        'MaxStartLookbackSeconds', options.MaxStartLookbackSeconds, ...
        'MaxEndLookaheadSeconds', options.MaxEndLookaheadSeconds, ...
        'MakeWaveformFigure', false, ...
        'MakeSummaryFigure', false);

    currentTable = eventOutput.eventTable;
    if ~isempty(currentTable)
        currentTable.fileName = repmat(string(fileName), height(currentTable), 1);
        currentTable.filePath = repmat(string(filePath), height(currentTable), 1);
        currentTable.subjectID = repmat(string(fileInfo.subjectID), height(currentTable), 1);
        currentTable.condition = repmat(string(fileInfo.condition), height(currentTable), 1);
        currentTable.detectorAmplitude = eventOutput.peakValues(:);
        currentTable.detectorWidthSec = eventOutput.peakWidthsSec(:);
        currentTable.interEventIntervalSec = NaN(height(currentTable), 1);
        if height(currentTable) >= 2 && ismember('peakTimeSec', currentTable.Properties.VariableNames)
            currentTable.interEventIntervalSec(2:end) = diff(currentTable.peakTimeSec);
        end

        if useIsolatedEventsOnly && ismember('isIsolatedEvent', currentTable.Properties.VariableNames)
            currentTable = currentTable(currentTable.isIsolatedEvent, :);
        end
    end

    eventTables{fileIndex} = currentTable;

    perFile(fileIndex).fileName = string(fileName);
    perFile(fileIndex).filePath = string(filePath);
    perFile(fileIndex).subjectID = string(fileInfo.subjectID);
    perFile(fileIndex).condition = string(fileInfo.condition);
    perFile(fileIndex).motionData = motionData;
    perFile(fileIndex).eventOutput = eventOutput;

    currentWaveformRow = localBuildMeanWaveformRow(fileName, fileInfo, eventOutput.waveforms, currentTable);
    if isempty(meanWaveformRows)
        meanWaveformRows = currentWaveformRow;
    else
        meanWaveformRows(end + 1, 1) = currentWaveformRow; %#ok<AGROW>
    end
end

allEventTable = vertcat(eventTables{:});
fileSummaryTable = localBuildFileSummaryTable(perFile, allEventTable);
conditionSummaryTable = localBuildGroupedSummary(allEventTable, "condition");
subjectSummaryTable = localBuildGroupedSummary(allEventTable, "subjectID");
meanWaveformTable = struct2table(meanWaveformRows);

%% Build summary figures

figureHandles = struct();
figureHandles.conditionCdf = [];
figureHandles.subjectCdf = [];
figureHandles.fileWaveforms = [];
figureHandles.groupedWaveforms = [];
figureHandles.amplitudeWidthScatter = [];

if logical(options.MakeFigures)
    figureHandles.conditionCdf = localMakeConditionCdfFigure(allEventTable);
    figureHandles.subjectCdf = localMakeSubjectCdfFigure(allEventTable);
    figureHandles.fileWaveforms = localMakeFileMeanWaveformFigure(meanWaveformRows);
    figureHandles.groupedWaveforms = localMakeGroupedMeanWaveformFigure(meanWaveformRows);
    figureHandles.amplitudeWidthScatter = localMakeAmplitudeWidthScatterFigure(allEventTable);

    if strlength(string(outputFolder)) > 0
        localSaveFigurePair(figureHandles.conditionCdf, outputFolder, char(string(options.FigureStem) + "_cdfs_by_condition"));
        localSaveFigurePair(figureHandles.subjectCdf, outputFolder, char(string(options.FigureStem) + "_cdfs_by_subject"));
        localSaveFigurePair(figureHandles.fileWaveforms, outputFolder, char(string(options.FigureStem) + "_file_mean_waveforms"));
        localSaveFigurePair(figureHandles.groupedWaveforms, outputFolder, char(string(options.FigureStem) + "_grouped_mean_waveforms"));
        localSaveFigurePair(figureHandles.amplitudeWidthScatter, outputFolder, char(string(options.FigureStem) + "_amplitude_width_scatter"));
    end
end

%% Package output

analysisOutput = struct();
analysisOutput.perFile = perFile;
analysisOutput.allEventTable = allEventTable;
analysisOutput.fileSummaryTable = fileSummaryTable;
analysisOutput.conditionSummaryTable = conditionSummaryTable;
analysisOutput.subjectSummaryTable = subjectSummaryTable;
analysisOutput.meanWaveformTable = meanWaveformTable;
analysisOutput.figureHandles = figureHandles;
analysisOutput.sourceFolder = string(magnitudeFolder);
analysisOutput.outputFolder = string(outputFolder);

end

function fileInfo = localParseFileInfo(fileName)
tokens = regexp(fileName, '^\d+_(sub\d+)_(.+)_acc1_chest_motionEnvelope\.mat$', 'tokens', 'once');
if isempty(tokens)
    error('analyzePrimitiveEvents:BadFileName', ...
        'Could not parse subject and condition from file name: %s', fileName);
end

fileInfo = struct();
fileInfo.subjectID = tokens{1};
fileInfo.condition = tokens{2};
end

function waveformRow = localBuildMeanWaveformRow(fileName, fileInfo, waveforms, filteredEventTable)
waveformMatrix = waveforms.waveformMatrix;

if isempty(filteredEventTable)
    selectedWaveformMatrix = NaN(size(waveformMatrix, 1), 0);
else
    selectedIndices = filteredEventTable.peakIndex;
    [isMatched, waveformColumnIndex] = ismember(selectedIndices, waveforms.peakLocations);
    waveformColumnIndex = waveformColumnIndex(isMatched & waveformColumnIndex > 0);
    if isempty(waveformColumnIndex)
        selectedWaveformMatrix = NaN(size(waveformMatrix, 1), 0);
    else
        selectedWaveformMatrix = waveformMatrix(:, waveformColumnIndex);
    end
end

meanWaveform = mean(selectedWaveformMatrix, 2, 'omitnan');

if ~isempty(waveforms.relativeTimeMatrixSec)
    if isempty(selectedWaveformMatrix)
        relativeTimeSec = mean(waveforms.relativeTimeMatrixSec, 2, 'omitnan');
    else
        relativeTimeSec = mean(waveforms.relativeTimeMatrixSec(:, waveformColumnIndex), 2, 'omitnan');
    end
else
    relativeTimeSec = ((1:size(waveformMatrix, 1)) - 1).';
end

meanWaveform = meanWaveform - localFirstFiniteValue(meanWaveform);

waveformRow = struct();
waveformRow.fileName = string(fileName);
waveformRow.subjectID = string(fileInfo.subjectID);
waveformRow.condition = string(fileInfo.condition);
waveformRow.relativeTimeSec = relativeTimeSec;
waveformRow.meanWaveform = meanWaveform;
waveformRow.nEvents = size(selectedWaveformMatrix, 2);
end

function firstValue = localFirstFiniteValue(values)
firstIndex = find(isfinite(values), 1, 'first');
if isempty(firstIndex)
    firstValue = 0;
else
    firstValue = values(firstIndex);
end
end

function summaryTable = localBuildFileSummaryTable(perFile, allEventTable)
summaryRows = repmat(struct( ...
    'fileName', "", ...
    'subjectID', "", ...
    'condition', "", ...
    'nEvents', NaN, ...
    'medianAmplitude', NaN, ...
    'medianDetectorWidthSec', NaN, ...
    'medianInterEventIntervalSec', NaN), numel(perFile), 1);

for fileIndex = 1:numel(perFile)
    fileName = string(perFile(fileIndex).fileName);
    mask = string(allEventTable.fileName) == fileName;
    currentTable = allEventTable(mask, :);

    summaryRows(fileIndex).fileName = fileName;
    summaryRows(fileIndex).subjectID = perFile(fileIndex).subjectID;
    summaryRows(fileIndex).condition = perFile(fileIndex).condition;
    summaryRows(fileIndex).nEvents = height(currentTable);
    summaryRows(fileIndex).medianAmplitude = median(currentTable.detectorAmplitude, 'omitnan');
    summaryRows(fileIndex).medianDetectorWidthSec = median(currentTable.detectorWidthSec, 'omitnan');
    summaryRows(fileIndex).medianInterEventIntervalSec = median(currentTable.interEventIntervalSec, 'omitnan');
end

summaryTable = struct2table(summaryRows);
end

function summaryTable = localBuildGroupedSummary(eventTable, groupVariableName)
groupValues = unique(string(eventTable.(groupVariableName)), 'stable');
summaryRows = repmat(struct( ...
    'groupName', "", ...
    'nEvents', NaN, ...
    'medianAmplitude', NaN, ...
    'medianDetectorWidthSec', NaN, ...
    'medianInterEventIntervalSec', NaN), numel(groupValues), 1);

for groupIndex = 1:numel(groupValues)
    currentGroup = groupValues(groupIndex);
    mask = string(eventTable.(groupVariableName)) == currentGroup;
    currentTable = eventTable(mask, :);

    summaryRows(groupIndex).groupName = currentGroup;
    summaryRows(groupIndex).nEvents = height(currentTable);
    summaryRows(groupIndex).medianAmplitude = median(currentTable.detectorAmplitude, 'omitnan');
    summaryRows(groupIndex).medianDetectorWidthSec = median(currentTable.detectorWidthSec, 'omitnan');
    summaryRows(groupIndex).medianInterEventIntervalSec = median(currentTable.interEventIntervalSec, 'omitnan');
end

summaryTable = struct2table(summaryRows);
end

function figureHandle = localMakeConditionCdfFigure(eventTable)
conditionOrder = ["desk_work_stand", "watching_videos_stand"];
conditionLabels = ["desk work", "watching videos"];
conditionColors = [0.15 0.35 0.70; 0.75 0.20 0.20];

figureHandle = figure('Color', 'w', 'Position', [100 80 1350 900]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Primitive event distributions by condition', 'FontSize', 16, 'FontWeight', 'bold');

metricDefinitions = { ...
    'detectorAmplitude', 'amplitude above baseline'; ...
    'interEventIntervalSec', 'inter-event interval (s)'; ...
    'detectorWidthSec', 'detector width (s)'};

for metricIndex = 1:size(metricDefinitions, 1)
    ax = nexttile(t);
    hold(ax, 'on');
    for conditionIndex = 1:numel(conditionOrder)
        mask = string(eventTable.condition) == conditionOrder(conditionIndex);
        values = eventTable.(metricDefinitions{metricIndex, 1})(mask);
        localPlotCdf(ax, values, conditionColors(conditionIndex, :), char(conditionLabels(conditionIndex)));
    end
    grid(ax, 'on');
    xlabel(ax, metricDefinitions{metricIndex, 2});
    ylabel(ax, 'CDF');
    title(ax, metricDefinitions{metricIndex, 2}, 'FontWeight', 'normal');
    if metricIndex == 1
        legend(ax, 'Location', 'southeast', 'Box', 'off');
    end
end
end

function figureHandle = localMakeSubjectCdfFigure(eventTable)
subjectOrder = ["sub1", "sub2", "sub3", "sub4"];
subjectColors = lines(numel(subjectOrder));

figureHandle = figure('Color', 'w', 'Position', [100 80 1350 900]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Primitive event distributions by subject', 'FontSize', 16, 'FontWeight', 'bold');

metricDefinitions = { ...
    'detectorAmplitude', 'amplitude above baseline'; ...
    'interEventIntervalSec', 'inter-event interval (s)'; ...
    'detectorWidthSec', 'detector width (s)'};

for metricIndex = 1:size(metricDefinitions, 1)
    ax = nexttile(t);
    hold(ax, 'on');
    for subjectIndex = 1:numel(subjectOrder)
        mask = string(eventTable.subjectID) == subjectOrder(subjectIndex);
        values = eventTable.(metricDefinitions{metricIndex, 1})(mask);
        localPlotCdf(ax, values, subjectColors(subjectIndex, :), char(subjectOrder(subjectIndex)));
    end
    grid(ax, 'on');
    xlabel(ax, metricDefinitions{metricIndex, 2});
    ylabel(ax, 'CDF');
    title(ax, metricDefinitions{metricIndex, 2}, 'FontWeight', 'normal');
    if metricIndex == 1
        legend(ax, 'Location', 'southeast', 'Box', 'off');
    end
end
end

function figureHandle = localMakeFileMeanWaveformFigure(meanWaveformRows)
figureHandle = figure('Color', 'w', 'Position', [100 80 1450 950]);
t = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Mean event-signal waveforms by file', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Waveforms come from baseline-relative eventSignal and are shifted so the first finite y value is 0.', 'FontSize', 11);

for fileIndex = 1:numel(meanWaveformRows)
    ax = nexttile(t);
    plot(ax, meanWaveformRows(fileIndex).relativeTimeSec, meanWaveformRows(fileIndex).meanWaveform, ...
        'k', 'LineWidth', 2.0);
    xline(ax, 0, '--', 'Color', [0.75 0.15 0.15], 'LineWidth', 1.0);
    grid(ax, 'on');
    xlabel(ax, 'time from event start');
    ylabel(ax, 'mean event signal');
    title(ax, sprintf('%s | %s | n=%d', ...
        char(meanWaveformRows(fileIndex).subjectID), ...
        strrep(strrep(char(meanWaveformRows(fileIndex).condition), '_stand', ''), '_', ' '), ...
        meanWaveformRows(fileIndex).nEvents), ...
        'FontWeight', 'normal');
end
end

function figureHandle = localMakeGroupedMeanWaveformFigure(meanWaveformRows)
figureHandle = figure('Color', 'w', 'Position', [100 80 1300 900]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Mean event-signal waveforms grouped across subjects and contexts', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Means come from baseline-relative eventSignal. The last panel shows peak-normalized subject means.', 'FontSize', 11);

conditionOrder = ["desk_work_stand", "watching_videos_stand"];
subjectOrder = ["sub1", "sub2", "sub3", "sub4"];
conditionColors = [0.15 0.35 0.70; 0.75 0.20 0.20];
subjectColors = lines(numel(subjectOrder));

ax1 = nexttile(t, 1);
hold(ax1, 'on');
for conditionIndex = 1:numel(conditionOrder)
    localPlotGroupedMeanWaveform(ax1, meanWaveformRows, "condition", conditionOrder(conditionIndex), ...
        conditionColors(conditionIndex, :), ...
        strrep(strrep(char(conditionOrder(conditionIndex)), '_stand', ''), '_', ' '));
end
grid(ax1, 'on');
xlabel(ax1, 'time from event start');
ylabel(ax1, 'mean event signal');
title(ax1, 'Grouped by condition', 'FontWeight', 'normal');
legend(ax1, 'Location', 'northeast', 'Box', 'off');

ax2 = nexttile(t, 2);
hold(ax2, 'on');
for subjectIndex = 1:numel(subjectOrder)
    localPlotGroupedMeanWaveform(ax2, meanWaveformRows, "subjectID", subjectOrder(subjectIndex), ...
        subjectColors(subjectIndex, :), char(subjectOrder(subjectIndex)));
end
grid(ax2, 'on');
xlabel(ax2, 'time from event start');
ylabel(ax2, 'mean event signal');
title(ax2, 'Grouped by subject', 'FontWeight', 'normal');
legend(ax2, 'Location', 'northeast', 'Box', 'off');

ax3 = nexttile(t, 3);
hold(ax3, 'on');
for rowIndex = 1:numel(meanWaveformRows)
    plot(ax3, meanWaveformRows(rowIndex).relativeTimeSec, meanWaveformRows(rowIndex).meanWaveform, ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%s %s', ...
        char(meanWaveformRows(rowIndex).subjectID), ...
        strrep(strrep(char(meanWaveformRows(rowIndex).condition), '_stand', ''), '_', ' ')));
end
grid(ax3, 'on');
xlabel(ax3, 'time from event start');
ylabel(ax3, 'mean event signal');
title(ax3, 'All 8 file means', 'FontWeight', 'normal');

ax4 = nexttile(t, 4);
hold(ax4, 'on');
subjectOrder = ["sub1", "sub2", "sub3", "sub4"];
subjectColors = lines(numel(subjectOrder));
for subjectIndex = 1:numel(subjectOrder)
    mask = arrayfun(@(row) string(row.subjectID) == subjectOrder(subjectIndex), meanWaveformRows);
    selectedRows = meanWaveformRows(mask);
    if isempty(selectedRows)
        continue;
    end
    [commonTimeSec, stackedWaveforms] = localStackWaveformRows(selectedRows);
    subjectMeanWaveform = mean(stackedWaveforms, 2, 'omitnan');
    normalizedWaveform = localNormalizeMeanWaveformToPeak(subjectMeanWaveform);
    plot(ax4, commonTimeSec, normalizedWaveform, ...
        'LineWidth', 2.0, 'Color', subjectColors(subjectIndex, :), ...
        'DisplayName', char(subjectOrder(subjectIndex)));
end
xline(ax4, 0, '--', 'Color', [0.75 0.15 0.15], 'LineWidth', 1.0);
grid(ax4, 'on');
xlabel(ax4, 'time from event start');
ylabel(ax4, 'normalized mean event signal');
title(ax4, 'Subject means: start = 0, peak = 1', 'FontWeight', 'normal');
legend(ax4, 'Location', 'eastoutside', 'Box', 'off');
end

function localPlotGroupedMeanWaveform(ax, meanWaveformRows, groupField, groupValue, plotColor, displayName)
mask = arrayfun(@(row) string(row.(groupField)) == groupValue, meanWaveformRows);
selectedRows = meanWaveformRows(mask);
if isempty(selectedRows)
    return;
end

[commonTimeSec, stackedWaveforms] = localStackWaveformRows(selectedRows);
groupMeanWaveform = mean(stackedWaveforms, 2, 'omitnan');
plot(ax, commonTimeSec, groupMeanWaveform, 'LineWidth', 2.3, 'Color', plotColor, 'DisplayName', displayName);
xline(ax, 0, '--', 'Color', [0.75 0.15 0.15], 'LineWidth', 1.0);
end

function [commonTimeSec, stackedWaveforms] = localStackWaveformRows(meanWaveformRows)
maxLength = max(arrayfun(@(row) numel(row.meanWaveform), meanWaveformRows));
stackedWaveforms = NaN(maxLength, numel(meanWaveformRows));
timeMatrix = NaN(maxLength, numel(meanWaveformRows));

for rowIndex = 1:numel(meanWaveformRows)
    currentLength = numel(meanWaveformRows(rowIndex).meanWaveform);
    stackedWaveforms(1:currentLength, rowIndex) = meanWaveformRows(rowIndex).meanWaveform;
    timeMatrix(1:currentLength, rowIndex) = meanWaveformRows(rowIndex).relativeTimeSec;
end

commonTimeSec = mean(timeMatrix, 2, 'omitnan');
end

function figureHandle = localMakeAmplitudeWidthScatterFigure(eventTable)
figureHandle = figure('Color', 'w', 'Position', [100 80 1200 500]);
t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Detector amplitude vs detector width', 'FontSize', 16, 'FontWeight', 'bold');

conditionOrder = ["desk_work_stand", "watching_videos_stand"];
conditionLabels = ["desk work", "watching videos"];
conditionColors = [0.15 0.35 0.70; 0.75 0.20 0.20];

ax1 = nexttile(t, 1);
hold(ax1, 'on');
for conditionIndex = 1:numel(conditionOrder)
    mask = string(eventTable.condition) == conditionOrder(conditionIndex);
    scatter(ax1, eventTable.detectorWidthSec(mask), eventTable.detectorAmplitude(mask), 20, ...
        'filled', 'MarkerFaceColor', conditionColors(conditionIndex, :), 'MarkerFaceAlpha', 0.35, ...
        'DisplayName', char(conditionLabels(conditionIndex)));
end
grid(ax1, 'on');
xlabel(ax1, 'detector width (s)');
ylabel(ax1, 'amplitude above baseline');
title(ax1, 'By condition', 'FontWeight', 'normal');
legend(ax1, 'Location', 'northeast', 'Box', 'off');

subjectOrder = ["sub1", "sub2", "sub3", "sub4"];
subjectColors = lines(numel(subjectOrder));
ax2 = nexttile(t, 2);
hold(ax2, 'on');
for subjectIndex = 1:numel(subjectOrder)
    mask = string(eventTable.subjectID) == subjectOrder(subjectIndex);
    scatter(ax2, eventTable.detectorWidthSec(mask), eventTable.detectorAmplitude(mask), 20, ...
        'filled', 'MarkerFaceColor', subjectColors(subjectIndex, :), 'MarkerFaceAlpha', 0.35, ...
        'DisplayName', char(subjectOrder(subjectIndex)));
end
grid(ax2, 'on');
xlabel(ax2, 'detector width (s)');
ylabel(ax2, 'amplitude above baseline');
title(ax2, 'By subject', 'FontWeight', 'normal');
legend(ax2, 'Location', 'northeast', 'Box', 'off');
end

function localPlotCdf(ax, valuesIn, plotColor, displayName)
values = valuesIn(isfinite(valuesIn));
if isempty(values)
    return;
end

clipUpper = quantile(values, 0.95);
values = values(values <= clipUpper);
if isempty(values)
    return;
end

values = sort(values);
yValues = (1:numel(values)) ./ numel(values);
plot(ax, values, yValues, 'LineWidth', 1.8, 'Color', plotColor, 'DisplayName', displayName);
end

function localSaveFigurePair(figureHandle, outputFolder, fileStem)
savefig(figureHandle, fullfile(outputFolder, [fileStem '.fig']));
exportgraphics(figureHandle, fullfile(outputFolder, [fileStem '.png']), 'Resolution', 180);
end

function normalizedWaveform = localNormalizeMeanWaveformToPeak(meanWaveform)
normalizedWaveform = meanWaveform;
finiteMask = isfinite(meanWaveform);
if ~any(finiteMask)
    return;
end

finiteIndices = find(finiteMask);
startValue = meanWaveform(finiteIndices(1));
peakValue = max(meanWaveform(finiteMask));
peakDelta = peakValue - startValue;

if ~isfinite(peakDelta) || peakDelta <= 0
    normalizedWaveform(finiteMask) = meanWaveform(finiteMask) - startValue;
else
    normalizedWaveform(finiteMask) = (meanWaveform(finiteMask) - startValue) ./ peakDelta;
end
end
