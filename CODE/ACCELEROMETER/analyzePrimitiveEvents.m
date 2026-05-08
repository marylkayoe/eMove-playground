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
%   'UseIsolatedEventsOnly'     default false
%   'EventClassFilter'          default "all"
%       One of "all", "unitary", or "compound". This uses the current
%       valley-delimited bout definition from extractEnvelopeEvents.
%   'OnsetAlignedWindowSeconds' default [-0.25 4.25]
%       Window used for event-class waveform comparisons. t = 0 is the
%       low-threshold onset before the first same-bout subpeak.
%   'OnsetLookbackSeconds'      default 1.25
%   'OnsetThresholdSigma'       default 2
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
%   analysisOutput.eventClassSummaryTable
%   analysisOutput.conditionEventClassSummaryTable
%   analysisOutput.subjectEventClassSummaryTable
%   analysisOutput.boutTable
%   analysisOutput.boutConditionEventClassSummaryTable
%   analysisOutput.eventClassMeanWaveformTable
%       Onset-aligned bout waveforms for unitary/compound comparisons.
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

addParameter(inputParserObject, 'UseIsolatedEventsOnly', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'EventClassFilter', "all", ...
    @(value) any(strcmpi(string(value), ["all", "unitary", "compound"])));

addParameter(inputParserObject, 'OnsetAlignedWindowSeconds', [-0.25 4.25], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) < value(2));

addParameter(inputParserObject, 'OnsetLookbackSeconds', 1.25, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'OnsetThresholdSigma', 2, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

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
eventClassFilter = lower(string(options.EventClassFilter));
if useIsolatedEventsOnly
    eventClassFilter = "unitary";
end

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
eventClassMeanWaveformRows = struct([]);

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
        currentTable = localAddEventClassColumns(currentTable);
        currentTable.interEventIntervalSec = NaN(height(currentTable), 1);
        if height(currentTable) >= 2 && ismember('peakTimeSec', currentTable.Properties.VariableNames)
            currentTable.interEventIntervalSec(2:end) = diff(currentTable.peakTimeSec);
        end

        unfilteredTableForClassRows = currentTable;
        currentTable = localFilterByEventClass(currentTable, eventClassFilter);
    else
        unfilteredTableForClassRows = currentTable;
    end

    eventTables{fileIndex} = currentTable;

    perFile(fileIndex).fileName = string(fileName);
    perFile(fileIndex).filePath = string(filePath);
    perFile(fileIndex).subjectID = string(fileInfo.subjectID);
    perFile(fileIndex).condition = string(fileInfo.condition);
    perFile(fileIndex).motionData = motionData;
    perFile(fileIndex).eventOutput = eventOutput;

    currentClassRows = localBuildEventClassOnsetAlignedWaveformRows(fileName, fileInfo, ...
        eventOutput, unfilteredTableForClassRows, ...
        options.OnsetAlignedWindowSeconds, ...
        options.OnsetLookbackSeconds, ...
        options.OnsetThresholdSigma);
    if isempty(eventClassMeanWaveformRows)
        eventClassMeanWaveformRows = currentClassRows;
    elseif ~isempty(currentClassRows)
        eventClassMeanWaveformRows = [eventClassMeanWaveformRows; currentClassRows]; %#ok<AGROW>
    end
end

allEventTable = vertcat(eventTables{:});
fileSummaryTable = localBuildFileSummaryTable(perFile, allEventTable);
conditionSummaryTable = localBuildGroupedSummary(allEventTable, "condition");
subjectSummaryTable = localBuildGroupedSummary(allEventTable, "subjectID");
eventClassSummaryTable = localBuildGroupedSummary(allEventTable, "eventClass");
conditionEventClassSummaryTable = localBuildGroupedSummary(allEventTable, ["condition", "eventClass"]);
subjectEventClassSummaryTable = localBuildGroupedSummary(allEventTable, ["subjectID", "eventClass"]);
boutTable = localBuildBoutTable(allEventTable);
boutConditionEventClassSummaryTable = localBuildGroupedSummary(boutTable, ["condition", "eventClass"]);
eventClassMeanWaveformTable = struct2table(eventClassMeanWaveformRows);

%% Build summary figures

figureHandles = struct();
figureHandles.conditionCdf = [];
figureHandles.subjectCdf = [];
figureHandles.conditionEventClassCdf = [];
figureHandles.subjectEventClassCdf = [];
figureHandles.eventClassGroupedWaveforms = [];
figureHandles.amplitudeWidthScatter = [];

if logical(options.MakeFigures)
    figureHandles.conditionCdf = localMakeConditionCdfFigure(allEventTable);
    if strlength(string(outputFolder)) > 0
        localSaveFigurePair(figureHandles.conditionCdf, outputFolder, char(string(options.FigureStem) + "_cdfs_by_condition"));
    end

    figureHandles.subjectCdf = localMakeSubjectCdfFigure(allEventTable);
    if strlength(string(outputFolder)) > 0
        localSaveFigurePair(figureHandles.subjectCdf, outputFolder, char(string(options.FigureStem) + "_cdfs_by_subject"));
    end

    figureHandles.conditionEventClassCdf = localMakeConditionEventClassCdfFigure(allEventTable);
    if strlength(string(outputFolder)) > 0
        localSaveFigurePair(figureHandles.conditionEventClassCdf, outputFolder, char(string(options.FigureStem) + "_cdfs_by_condition_and_event_class"));
    end

    figureHandles.subjectEventClassCdf = localMakeSubjectEventClassCdfFigure(allEventTable);
    if strlength(string(outputFolder)) > 0
        localSaveFigurePair(figureHandles.subjectEventClassCdf, outputFolder, char(string(options.FigureStem) + "_cdfs_by_subject_and_event_class"));
    end

    figureHandles.eventClassGroupedWaveforms = localMakeEventClassGroupedWaveformFigure(eventClassMeanWaveformRows);
    if strlength(string(outputFolder)) > 0
        localSaveFigurePair(figureHandles.eventClassGroupedWaveforms, outputFolder, char(string(options.FigureStem) + "_event_class_grouped_mean_waveforms"));
    end

    figureHandles.amplitudeWidthScatter = localMakeAmplitudeWidthScatterFigure(allEventTable);
    if strlength(string(outputFolder)) > 0
        localSaveFigurePair(figureHandles.amplitudeWidthScatter, outputFolder, char(string(options.FigureStem) + "_amplitude_width_scatter"));
    end
end

if strlength(string(outputFolder)) > 0
    writetable(allEventTable, fullfile(outputFolder, char(string(options.FigureStem) + "_all_event_metrics.csv")));
    writetable(fileSummaryTable, fullfile(outputFolder, char(string(options.FigureStem) + "_file_summary.csv")));
    writetable(conditionSummaryTable, fullfile(outputFolder, char(string(options.FigureStem) + "_condition_summary.csv")));
    writetable(subjectSummaryTable, fullfile(outputFolder, char(string(options.FigureStem) + "_subject_summary.csv")));
    writetable(eventClassSummaryTable, fullfile(outputFolder, char(string(options.FigureStem) + "_event_class_summary.csv")));
    writetable(conditionEventClassSummaryTable, fullfile(outputFolder, char(string(options.FigureStem) + "_condition_event_class_summary.csv")));
    writetable(subjectEventClassSummaryTable, fullfile(outputFolder, char(string(options.FigureStem) + "_subject_event_class_summary.csv")));
    writetable(boutTable, fullfile(outputFolder, char(string(options.FigureStem) + "_bout_table.csv")));
    writetable(boutConditionEventClassSummaryTable, fullfile(outputFolder, char(string(options.FigureStem) + "_bout_condition_event_class_summary.csv")));
end

%% Package output

analysisOutput = struct();
analysisOutput.perFile = perFile;
analysisOutput.allEventTable = allEventTable;
analysisOutput.fileSummaryTable = fileSummaryTable;
analysisOutput.conditionSummaryTable = conditionSummaryTable;
analysisOutput.subjectSummaryTable = subjectSummaryTable;
analysisOutput.eventClassSummaryTable = eventClassSummaryTable;
analysisOutput.conditionEventClassSummaryTable = conditionEventClassSummaryTable;
analysisOutput.subjectEventClassSummaryTable = subjectEventClassSummaryTable;
analysisOutput.boutTable = boutTable;
analysisOutput.boutConditionEventClassSummaryTable = boutConditionEventClassSummaryTable;
analysisOutput.eventClassMeanWaveformTable = eventClassMeanWaveformTable;
analysisOutput.figureHandles = figureHandles;
analysisOutput.sourceFolder = string(magnitudeFolder);
analysisOutput.outputFolder = string(outputFolder);
analysisOutput.eventClassFilter = eventClassFilter;

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

function eventTable = localAddEventClassColumns(eventTable)
eventClass = strings(height(eventTable), 1);
eventClass(:) = "unknown";

if ismember('isIsolatedEvent', eventTable.Properties.VariableNames)
    eventClass(logical(eventTable.isIsolatedEvent)) = "unitary";
end
if ismember('isCompoundEvent', eventTable.Properties.VariableNames)
    eventClass(logical(eventTable.isCompoundEvent)) = "compound";
end

eventTable.eventClass = eventClass;
eventTable.isUnitaryBout = eventClass == "unitary";
eventTable.isCompoundBout = eventClass == "compound";
end

function filteredTable = localFilterByEventClass(eventTable, eventClassFilter)
switch lower(string(eventClassFilter))
    case "all"
        filteredTable = eventTable;
    case "unitary"
        filteredTable = eventTable(eventTable.eventClass == "unitary", :);
    case "compound"
        filteredTable = eventTable(eventTable.eventClass == "compound", :);
    otherwise
        error('analyzePrimitiveEvents:UnknownEventClassFilter', ...
            'Unknown EventClassFilter: %s', eventClassFilter);
end
end

function waveformRows = localBuildEventClassOnsetAlignedWaveformRows(fileName, fileInfo, ...
    eventOutput, eventTable, onsetAlignedWindowSeconds, onsetLookbackSeconds, onsetThresholdSigma)
eventClasses = ["unitary"; "compound"];
waveformRows = repmat(struct(), 0, 1);
samplingFrequency = eventOutput.samplingFrequency;
eventSignal = eventOutput.noiseEstimate.eventSignal(:);
noiseSigma = eventOutput.noiseEstimate.noiseSigma(:);
onsetThreshold = onsetThresholdSigma .* median(noiseSigma, 'omitnan');
relativeSampleIndex = round(onsetAlignedWindowSeconds(1) .* samplingFrequency): ...
    round(onsetAlignedWindowSeconds(2) .* samplingFrequency);
relativeSampleIndex = relativeSampleIndex(:);
relativeTimeSec = relativeSampleIndex ./ samplingFrequency;

for eventClassIndex = 1:numel(eventClasses)
    currentClass = eventClasses(eventClassIndex);
    if isempty(eventTable) || ~ismember('eventClass', eventTable.Properties.VariableNames)
        classTable = eventTable;
    else
        classTable = eventTable(eventTable.eventClass == currentClass, :);
    end

    [snippetMatrix, onsetTable] = localExtractOnsetAlignedBoutSnippets( ...
        eventSignal, classTable, samplingFrequency, relativeSampleIndex, ...
        onsetLookbackSeconds, onsetThreshold);

    meanWaveform = mean(snippetMatrix, 2, 'omitnan');
    semWaveform = localComputeSem(snippetMatrix);

    currentRow = struct();
    currentRow.fileName = string(fileName);
    currentRow.subjectID = string(fileInfo.subjectID);
    currentRow.condition = string(fileInfo.condition);
    currentRow.relativeSampleIndex = relativeSampleIndex;
    currentRow.relativeTimeSec = relativeTimeSec;
    currentRow.eventWaveformMatrix = snippetMatrix;
    currentRow.meanWaveform = meanWaveform;
    currentRow.semWaveform = semWaveform;
    currentRow.nEvents = size(snippetMatrix, 2);
    currentRow.eventClass = currentClass;
    currentRow.alignment = "onset";
    currentRow.onsetDefinition = "last eventSignal sample at or below 2*median(noiseSigma) before first same-bout subpeak";
    currentRow.onsetBoutTable = onsetTable;

    if isempty(waveformRows)
        waveformRows = currentRow;
    else
        waveformRows(end + 1, 1) = currentRow; %#ok<AGROW>
    end
end
end

function [snippetMatrix, onsetTable] = localExtractOnsetAlignedBoutSnippets( ...
    eventSignal, eventTable, samplingFrequency, relativeSampleIndex, ...
    onsetLookbackSeconds, onsetThreshold)
if isempty(eventTable)
    snippetMatrix = NaN(numel(relativeSampleIndex), 0);
    onsetTable = table();
    return;
end

boutKeys = strings(height(eventTable), 1);
for rowIndex = 1:height(eventTable)
    if ismember('sameBoutSubpeakIndicesText', eventTable.Properties.VariableNames) && ...
            strlength(string(eventTable.sameBoutSubpeakIndicesText(rowIndex))) > 0
        boutKeys(rowIndex) = string(eventTable.sameBoutSubpeakIndicesText(rowIndex));
    else
        boutKeys(rowIndex) = string(eventTable.peakIndex(rowIndex));
    end
end

[uniqueBoutKeys, ~, groupIndexByRow] = unique(boutKeys, 'stable');
snippetMatrix = NaN(numel(relativeSampleIndex), numel(uniqueBoutKeys));
onsetRows = struct([]);

nextColumn = 1;
for boutIndex = 1:numel(uniqueBoutKeys)
    rows = eventTable(groupIndexByRow == boutIndex, :);
    subpeakIndices = localParseIndexList(uniqueBoutKeys(boutIndex));
    if isempty(subpeakIndices)
        subpeakIndices = rows.peakIndex(1);
    end
    subpeakIndices = sort(subpeakIndices(:));
    firstSubpeakIndex = subpeakIndices(1);
    onsetIndex = localEstimateBoutOnsetIndex(eventSignal, firstSubpeakIndex, ...
        samplingFrequency, onsetLookbackSeconds, onsetThreshold);
    snippet = localExtractFixedSnippet(eventSignal, onsetIndex, relativeSampleIndex);
    if any(~isfinite(snippet))
        continue;
    end

    [~, representativeRowIndex] = max(rows.detectorAmplitude);
    representativeRow = rows(representativeRowIndex, :);

    snippetMatrix(:, nextColumn) = snippet(:);
    onsetRows(end + 1, 1).fileName = representativeRow.fileName; %#ok<AGROW>
    onsetRows(end, 1).subjectID = representativeRow.subjectID;
    onsetRows(end, 1).condition = representativeRow.condition;
    onsetRows(end, 1).eventClass = representativeRow.eventClass;
    onsetRows(end, 1).boutKey = uniqueBoutKeys(boutIndex);
    onsetRows(end, 1).onsetIndex = onsetIndex;
    onsetRows(end, 1).firstSubpeakIndex = firstSubpeakIndex;
    onsetRows(end, 1).representativePeakIndex = representativeRow.peakIndex;
    onsetRows(end, 1).nSameBoutSubpeaks = numel(subpeakIndices);
    onsetRows(end, 1).activeSubpeakSpanSec = representativeRow.activeSubpeakSpanSec;
    onsetRows(end, 1).firstSubpeakLatencySec = (firstSubpeakIndex - onsetIndex) ./ samplingFrequency;
    onsetRows(end, 1).representativePeakLatencySec = ...
        (representativeRow.peakIndex - onsetIndex) ./ samplingFrequency;
    onsetRows(end, 1).snippetIndex = nextColumn;
    nextColumn = nextColumn + 1;
end

snippetMatrix = snippetMatrix(:, 1:(nextColumn - 1));
if isempty(onsetRows)
    onsetTable = table();
else
    onsetTable = struct2table(onsetRows);
end
end

function onsetIndex = localEstimateBoutOnsetIndex(eventSignal, firstSubpeakIndex, ...
    samplingFrequency, onsetLookbackSeconds, onsetThreshold)
lookbackSamples = max(1, round(onsetLookbackSeconds .* samplingFrequency));
searchStart = max(1, firstSubpeakIndex - lookbackSamples);
searchValues = eventSignal(searchStart:firstSubpeakIndex);
belowThresholdPositions = find(searchValues <= onsetThreshold);

if ~isempty(belowThresholdPositions)
    onsetIndex = searchStart + belowThresholdPositions(end) - 1;
else
    [~, minimumPosition] = min(searchValues);
    onsetIndex = searchStart + minimumPosition - 1;
end

while onsetIndex < firstSubpeakIndex && eventSignal(onsetIndex) <= onsetThreshold
    onsetIndex = onsetIndex + 1;
end
onsetIndex = max(1, onsetIndex - 1);
end

function snippet = localExtractFixedSnippet(signal, centerIndex, relativeSampleIndex)
sampleIndices = centerIndex + relativeSampleIndex(:);
if any(sampleIndices < 1) || any(sampleIndices > numel(signal))
    snippet = NaN(numel(relativeSampleIndex), 1);
else
    snippet = signal(sampleIndices);
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

function summaryTable = localBuildGroupedSummary(eventTable, groupVariableNames)
groupVariableNames = string(groupVariableNames);
if isempty(eventTable)
    summaryTable = table();
    return;
end

groupKeyTable = eventTable(:, cellstr(groupVariableNames));
[groupRows, ~, groupIndexByRow] = unique(groupKeyTable, 'rows', 'stable');
summaryRows = repmat(struct( ...
    'groupName', "", ...
    'nEvents', NaN, ...
    'medianAmplitude', NaN, ...
    'medianDetectorWidthSec', NaN, ...
    'medianInterEventIntervalSec', NaN, ...
    'medianSameBoutSubpeaks', NaN, ...
    'medianActiveSubpeakSpanSec', NaN), height(groupRows), 1);

for groupIndex = 1:height(groupRows)
    mask = groupIndexByRow == groupIndex;
    currentTable = eventTable(mask, :);

    groupNameParts = strings(1, numel(groupVariableNames));
    for nameIndex = 1:numel(groupVariableNames)
        currentValues = groupRows.(groupVariableNames(nameIndex));
        groupNameParts(nameIndex) = string(currentValues(groupIndex));
    end
    summaryRows(groupIndex).groupName = strjoin(groupNameParts, " | ");
    summaryRows(groupIndex).nEvents = height(currentTable);
    summaryRows(groupIndex).medianAmplitude = localMedianIfPresent(currentTable, 'detectorAmplitude');
    summaryRows(groupIndex).medianDetectorWidthSec = localMedianIfPresent(currentTable, 'detectorWidthSec');
    summaryRows(groupIndex).medianInterEventIntervalSec = localMedianIfPresent(currentTable, 'interEventIntervalSec');
    summaryRows(groupIndex).medianSameBoutSubpeaks = localMedianIfPresent(currentTable, 'nSameBoutSubpeaks');
    summaryRows(groupIndex).medianActiveSubpeakSpanSec = localMedianIfPresent(currentTable, 'activeSubpeakSpanSec');
end

summaryTable = struct2table(summaryRows);
for nameIndex = 1:numel(groupVariableNames)
    summaryTable.(groupVariableNames(nameIndex)) = groupRows.(groupVariableNames(nameIndex));
end
summaryTable = movevars(summaryTable, cellstr(groupVariableNames), 'Before', 'groupName');
end

function value = localMedianIfPresent(inputTable, variableName)
if isempty(inputTable) || ~ismember(variableName, inputTable.Properties.VariableNames)
    value = NaN;
else
    value = median(inputTable.(variableName), 'omitnan');
end
end

function boutTable = localBuildBoutTable(eventTable)
if isempty(eventTable)
    boutTable = table();
    return;
end

boutRows = struct([]);
fileNames = unique(string(eventTable.fileName), 'stable');

for fileIndex = 1:numel(fileNames)
    fileTable = eventTable(string(eventTable.fileName) == fileNames(fileIndex), :);
    boutKeys = strings(height(fileTable), 1);
    for rowIndex = 1:height(fileTable)
        if ismember('sameBoutSubpeakIndicesText', fileTable.Properties.VariableNames) && ...
                strlength(string(fileTable.sameBoutSubpeakIndicesText(rowIndex))) > 0
            boutKeys(rowIndex) = string(fileTable.sameBoutSubpeakIndicesText(rowIndex));
        else
            boutKeys(rowIndex) = string(fileTable.peakIndex(rowIndex));
        end
    end

    [uniqueBoutKeys, ~, groupIndexByRow] = unique(boutKeys, 'stable');
    for boutIndex = 1:numel(uniqueBoutKeys)
        rows = fileTable(groupIndexByRow == boutIndex, :);
        subpeakIndices = localParseIndexList(uniqueBoutKeys(boutIndex));
        if isempty(subpeakIndices)
            subpeakIndices = rows.peakIndex(1);
        end

        [~, representativeRowIndex] = max(rows.detectorAmplitude);
        representativeRow = rows(representativeRowIndex, :);

        boutRows(end + 1, 1).fileName = representativeRow.fileName; %#ok<AGROW>
        boutRows(end, 1).filePath = representativeRow.filePath;
        boutRows(end, 1).subjectID = representativeRow.subjectID;
        boutRows(end, 1).condition = representativeRow.condition;
        boutRows(end, 1).eventClass = representativeRow.eventClass;
        boutRows(end, 1).boutKey = uniqueBoutKeys(boutIndex);
        boutRows(end, 1).nSameBoutSubpeaks = numel(subpeakIndices);
        boutRows(end, 1).firstSubpeakIndex = min(subpeakIndices);
        boutRows(end, 1).lastSubpeakIndex = max(subpeakIndices);
        boutRows(end, 1).representativePeakIndex = representativeRow.peakIndex;
        boutRows(end, 1).representativePeakTimeSec = representativeRow.peakTimeSec;
        boutRows(end, 1).representativeAmplitude = representativeRow.detectorAmplitude;
        boutRows(end, 1).detectorAmplitude = representativeRow.detectorAmplitude;
        boutRows(end, 1).detectorWidthSec = representativeRow.detectorWidthSec;
        boutRows(end, 1).activeSubpeakSpanSec = representativeRow.activeSubpeakSpanSec;
        boutRows(end, 1).nPrimaryAnchorsInBout = height(rows);
    end
end

if isempty(boutRows)
    boutTable = table();
    return;
end

boutTable = struct2table(boutRows);
boutTable = sortrows(boutTable, {'fileName', 'firstSubpeakIndex'});
boutTable.interEventIntervalSec = NaN(height(boutTable), 1);
for fileIndex = 1:numel(fileNames)
    mask = string(boutTable.fileName) == fileNames(fileIndex);
    rowIndices = find(mask);
    if numel(rowIndices) >= 2
        boutTable.interEventIntervalSec(rowIndices(2:end)) = diff(boutTable.representativePeakTimeSec(rowIndices));
    end
end
end

function indices = localParseIndexList(textValue)
textValue = string(textValue);
if strlength(textValue) == 0 || ismissing(textValue)
    indices = [];
    return;
end

parts = split(textValue, ';');
indices = str2double(parts);
indices = indices(isfinite(indices));
indices = indices(:);
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

function figureHandle = localMakeConditionEventClassCdfFigure(eventTable)
eventClasses = ["unitary", "compound"];
eventClassLabels = ["Unitary bouts", "Compound bouts"];
conditionOrder = ["desk_work_stand", "watching_videos_stand"];
conditionLabels = ["desk work", "watching videos"];
conditionColors = [0.15 0.35 0.70; 0.75 0.20 0.20];
metricDefinitions = { ...
    'detectorAmplitude', 'amplitude above baseline'; ...
    'interEventIntervalSec', 'inter-event interval (s)'; ...
    'detectorWidthSec', 'detector width (s)'};

figureHandle = figure('Color', 'w', 'Position', [100 80 1500 900]);
t = tiledlayout(numel(eventClasses), size(metricDefinitions, 1), ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Primitive event distributions by condition and event class', ...
    'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Event class uses the valley-delimited same-bout definition from extractEnvelopeEvents.', ...
    'FontSize', 11);

for classIndex = 1:numel(eventClasses)
    for metricIndex = 1:size(metricDefinitions, 1)
        ax = nexttile(t);
        hold(ax, 'on');
        for conditionIndex = 1:numel(conditionOrder)
            mask = eventTable.eventClass == eventClasses(classIndex) & ...
                string(eventTable.condition) == conditionOrder(conditionIndex);
            values = eventTable.(metricDefinitions{metricIndex, 1})(mask);
            localPlotCdf(ax, values, conditionColors(conditionIndex, :), ...
                char(conditionLabels(conditionIndex)));
        end
        grid(ax, 'on');
        xlabel(ax, metricDefinitions{metricIndex, 2});
        ylabel(ax, 'CDF');
        title(ax, sprintf('%s: %s', eventClassLabels(classIndex), metricDefinitions{metricIndex, 2}), ...
            'FontWeight', 'normal');
        if classIndex == 1 && metricIndex == 1
            legend(ax, 'Location', 'southeast', 'Box', 'off');
        end
    end
end
end

function figureHandle = localMakeSubjectEventClassCdfFigure(eventTable)
eventClasses = ["unitary", "compound"];
eventClassLabels = ["Unitary bouts", "Compound bouts"];
subjectOrder = ["sub1", "sub2", "sub3", "sub4"];
subjectColors = lines(numel(subjectOrder));
metricDefinitions = { ...
    'detectorAmplitude', 'amplitude above baseline'; ...
    'interEventIntervalSec', 'inter-event interval (s)'; ...
    'detectorWidthSec', 'detector width (s)'};

figureHandle = figure('Color', 'w', 'Position', [100 80 1500 900]);
t = tiledlayout(numel(eventClasses), size(metricDefinitions, 1), ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Primitive event distributions by subject and event class', ...
    'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Event class uses the valley-delimited same-bout definition from extractEnvelopeEvents.', ...
    'FontSize', 11);

for classIndex = 1:numel(eventClasses)
    for metricIndex = 1:size(metricDefinitions, 1)
        ax = nexttile(t);
        hold(ax, 'on');
        for subjectIndex = 1:numel(subjectOrder)
            mask = eventTable.eventClass == eventClasses(classIndex) & ...
                string(eventTable.subjectID) == subjectOrder(subjectIndex);
            values = eventTable.(metricDefinitions{metricIndex, 1})(mask);
            localPlotCdf(ax, values, subjectColors(subjectIndex, :), char(subjectOrder(subjectIndex)));
        end
        grid(ax, 'on');
        xlabel(ax, metricDefinitions{metricIndex, 2});
        ylabel(ax, 'CDF');
        title(ax, sprintf('%s: %s', eventClassLabels(classIndex), metricDefinitions{metricIndex, 2}), ...
            'FontWeight', 'normal');
        if classIndex == 1 && metricIndex == 1
            legend(ax, 'Location', 'southeast', 'Box', 'off');
        end
    end
end
end

function figureHandle = localMakeEventClassGroupedWaveformFigure(eventClassMeanWaveformRows)
figureHandle = figure('Color', 'w', 'Position', [100 80 1500 1700]);
t = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Onset-aligned event-signal waveforms by event class, condition, and subject', ...
    'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Rows show raw amplitude means and per-event peak-amplitude-normalized shape means.', ...
    'FontSize', 11);

conditionOrder = ["desk_work_stand", "watching_videos_stand"];
subjectOrder = ["sub1", "sub2", "sub3", "sub4"];
conditionColors = [0.15 0.35 0.70; 0.75 0.20 0.20];
subjectColors = lines(numel(subjectOrder));
eventClasses = ["unitary", "compound"];

for classIndex = 1:numel(eventClasses)
    classRows = eventClassMeanWaveformRows(arrayfun(@(row) ...
        string(row.eventClass) == eventClasses(classIndex), eventClassMeanWaveformRows));
    rawTileIndex = (classIndex - 1) * 4;

    conditionAxes = nexttile(t, rawTileIndex + 1);
    hold(conditionAxes, 'on');
    for conditionIndex = 1:numel(conditionOrder)
        localPlotGroupedMeanWaveform(conditionAxes, classRows, "condition", conditionOrder(conditionIndex), ...
            conditionColors(conditionIndex, :), ...
            strrep(strrep(char(conditionOrder(conditionIndex)), '_stand', ''), '_', ' '), false);
    end
    grid(conditionAxes, 'on');
    xlabel(conditionAxes, 'time from estimated bout onset (s)');
    ylabel(conditionAxes, 'mean event signal');
    title(conditionAxes, sprintf('%s: raw amplitude by condition', eventClasses(classIndex)), ...
        'FontWeight', 'normal');
    legend(conditionAxes, 'Location', 'northeast', 'Box', 'off');

    subjectAxes = nexttile(t, rawTileIndex + 2);
    hold(subjectAxes, 'on');
    for subjectIndex = 1:numel(subjectOrder)
        localPlotGroupedMeanWaveform(subjectAxes, classRows, "subjectID", subjectOrder(subjectIndex), ...
            subjectColors(subjectIndex, :), char(subjectOrder(subjectIndex)), false);
    end
    grid(subjectAxes, 'on');
    xlabel(subjectAxes, 'time from estimated bout onset (s)');
    ylabel(subjectAxes, 'mean event signal');
    title(subjectAxes, sprintf('%s: raw amplitude by subject', eventClasses(classIndex)), ...
        'FontWeight', 'normal');
    legend(subjectAxes, 'Location', 'northeast', 'Box', 'off');

    normalizedConditionAxes = nexttile(t, rawTileIndex + 3);
    hold(normalizedConditionAxes, 'on');
    for conditionIndex = 1:numel(conditionOrder)
        localPlotGroupedMeanWaveform(normalizedConditionAxes, classRows, "condition", conditionOrder(conditionIndex), ...
            conditionColors(conditionIndex, :), ...
            strrep(strrep(char(conditionOrder(conditionIndex)), '_stand', ''), '_', ' '), true);
    end
    grid(normalizedConditionAxes, 'on');
    xlabel(normalizedConditionAxes, 'time from estimated bout onset (s)');
    ylabel(normalizedConditionAxes, 'mean event signal / event peak');
    title(normalizedConditionAxes, sprintf('%s: peak-normalized by condition', eventClasses(classIndex)), ...
        'FontWeight', 'normal');
    legend(normalizedConditionAxes, 'Location', 'northeast', 'Box', 'off');

    normalizedSubjectAxes = nexttile(t, rawTileIndex + 4);
    hold(normalizedSubjectAxes, 'on');
    for subjectIndex = 1:numel(subjectOrder)
        localPlotGroupedMeanWaveform(normalizedSubjectAxes, classRows, "subjectID", subjectOrder(subjectIndex), ...
            subjectColors(subjectIndex, :), char(subjectOrder(subjectIndex)), true);
    end
    grid(normalizedSubjectAxes, 'on');
    xlabel(normalizedSubjectAxes, 'time from estimated bout onset (s)');
    ylabel(normalizedSubjectAxes, 'mean event signal / event peak');
    title(normalizedSubjectAxes, sprintf('%s: peak-normalized by subject', eventClasses(classIndex)), ...
        'FontWeight', 'normal');
    legend(normalizedSubjectAxes, 'Location', 'northeast', 'Box', 'off');
end
end

function localPlotGroupedMeanWaveform(ax, meanWaveformRows, groupField, groupValue, plotColor, displayName, normalizeToPeakAmplitude)
if nargin < 7
    normalizeToPeakAmplitude = false;
end
mask = arrayfun(@(row) string(row.(groupField)) == groupValue, meanWaveformRows);
selectedRows = meanWaveformRows(mask);
if isempty(selectedRows)
    return;
end

[commonTimeSec, stackedWaveforms] = localStackWaveformRows(selectedRows);
if normalizeToPeakAmplitude
    stackedWaveforms = localNormalizeEventColumnsToPeakAmplitude(stackedWaveforms);
end
groupMeanWaveform = mean(stackedWaveforms, 2, 'omitnan');
groupSemWaveform = localComputeSem(stackedWaveforms);
displayNameWithN = sprintf('%s (n=%d)', displayName, size(stackedWaveforms, 2));
localPlotMeanWithSem(ax, commonTimeSec, groupMeanWaveform, groupSemWaveform, plotColor, displayNameWithN);
xline(ax, 0, '--', 'Color', [0.75 0.15 0.15], 'LineWidth', 1.0, 'HandleVisibility', 'off');
end

function [commonTimeSec, stackedWaveforms] = localStackWaveformRows(meanWaveformRows)
[commonTimeSec, stackedWaveforms] = localStackEventWaveformRows(meanWaveformRows);
end

function [commonTimeSec, stackedWaveforms] = localStackEventWaveformRows(meanWaveformRows)
minSampleIndex = min(arrayfun(@(row) min(row.relativeSampleIndex), meanWaveformRows));
maxSampleIndex = max(arrayfun(@(row) max(row.relativeSampleIndex), meanWaveformRows));
commonSampleIndex = (minSampleIndex:maxSampleIndex).';
nEvents = sum(arrayfun(@(row) size(row.eventWaveformMatrix, 2), meanWaveformRows));
stackedWaveforms = NaN(numel(commonSampleIndex), nEvents);

nextColumn = 1;
for rowIndex = 1:numel(meanWaveformRows)
    currentMatrix = meanWaveformRows(rowIndex).eventWaveformMatrix;
    currentEventCount = size(currentMatrix, 2);
    if currentEventCount == 0
        continue;
    end

    [isMember, targetRows] = ismember(meanWaveformRows(rowIndex).relativeSampleIndex, commonSampleIndex);
    if ~all(isMember)
        error('analyzePrimitiveEvents:RelativeSampleMismatch', ...
            'Could not place event waveforms on the common relative sample axis.');
    end

    currentColumns = nextColumn:(nextColumn + currentEventCount - 1);
    stackedWaveforms(targetRows, currentColumns) = currentMatrix;
    nextColumn = nextColumn + currentEventCount;
end

stackedWaveforms = stackedWaveforms(:, 1:(nextColumn - 1));
samplePeriodSec = localEstimateSamplePeriodSec(meanWaveformRows);
commonTimeSec = commonSampleIndex .* samplePeriodSec;
if any(diff(commonTimeSec) <= 0)
    error('analyzePrimitiveEvents:NonMonotonicCommonTime', ...
        'Common event-aligned time axis must be strictly increasing.');
end
end

function semWaveform = localComputeSem(waveformMatrix)
nFinite = sum(isfinite(waveformMatrix), 2);
standardDeviation = std(waveformMatrix, 0, 2, 'omitnan');
semWaveform = standardDeviation ./ sqrt(nFinite);
semWaveform(nFinite < 2) = NaN;
end

function localPlotMeanWithSem(ax, xValues, meanWaveform, semWaveform, plotColor, displayName)
xValues = xValues(:);
meanWaveform = meanWaveform(:);
semWaveform = semWaveform(:);
finiteMask = isfinite(xValues) & isfinite(meanWaveform);

semMask = finiteMask & isfinite(semWaveform);
if any(semMask)
    upperBound = meanWaveform + semWaveform;
    lowerBound = meanWaveform - semWaveform;
    fill(ax, [xValues(semMask); flipud(xValues(semMask))], ...
        [upperBound(semMask); flipud(lowerBound(semMask))], ...
        plotColor, 'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

plot(ax, xValues(finiteMask), meanWaveform(finiteMask), ...
    'LineWidth', 2.1, 'Color', plotColor, 'DisplayName', displayName);
end

function normalizedMatrix = localNormalizeEventColumnsToPeakAmplitude(waveformMatrix)
normalizedMatrix = waveformMatrix;
for eventIndex = 1:size(waveformMatrix, 2)
    waveform = waveformMatrix(:, eventIndex);
    finiteMask = isfinite(waveform);
    if ~any(finiteMask)
        continue;
    end

    peakAmplitude = max(waveform(finiteMask));
    if isfinite(peakAmplitude) && peakAmplitude > 0
        normalizedMatrix(finiteMask, eventIndex) = waveform(finiteMask) ./ peakAmplitude;
    end
end
end

function samplePeriodSec = localEstimateSamplePeriodSec(meanWaveformRows)
samplePeriods = NaN(numel(meanWaveformRows), 1);
for rowIndex = 1:numel(meanWaveformRows)
    relativeSampleIndex = meanWaveformRows(rowIndex).relativeSampleIndex;
    relativeTimeSec = meanWaveformRows(rowIndex).relativeTimeSec;
    if numel(relativeSampleIndex) < 2 || numel(relativeTimeSec) < 2
        continue;
    end

    sampleStep = diff(relativeSampleIndex);
    timeStepSec = diff(relativeTimeSec);
    validMask = isfinite(sampleStep) & sampleStep > 0 & isfinite(timeStepSec) & timeStepSec > 0;
    if any(validMask)
        samplePeriods(rowIndex) = median(timeStepSec(validMask) ./ sampleStep(validMask), 'omitnan');
    end
end

samplePeriodSec = median(samplePeriods, 'omitnan');
if ~isfinite(samplePeriodSec) || samplePeriodSec <= 0
    samplePeriodSec = 1;
end
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
if isempty(figureHandle) || ~isvalid(figureHandle)
    warning('analyzePrimitiveEvents:InvalidFigureHandle', ...
        'Skipping save for invalid figure handle: %s', fileStem);
    return;
end
try
    savefig(figureHandle, fullfile(outputFolder, [fileStem '.fig']));
catch exception
    warning('analyzePrimitiveEvents:SaveFigFailed', ...
        'Could not save FIG for %s: %s', fileStem, exception.message);
end

if isempty(figureHandle) || ~isvalid(figureHandle)
    warning('analyzePrimitiveEvents:InvalidFigureHandleAfterSaveFig', ...
        'Skipping PNG export for invalid figure handle: %s', fileStem);
    return;
end

try
    exportgraphics(figureHandle, fullfile(outputFolder, [fileStem '.png']), 'Resolution', 180);
catch exception
    warning('analyzePrimitiveEvents:ExportGraphicsFailed', ...
        'Could not export PNG for %s: %s', fileStem, exception.message);
end
end
