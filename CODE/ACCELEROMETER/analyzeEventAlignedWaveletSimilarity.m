function waveletOutput = analyzeEventAlignedWaveletSimilarity(analysisOutput, varargin)
%ANALYZEEVENTALIGNEDWAVELETSIMILARITY Compare normalized event-centered wavelet structure.
%
% waveletOutput = analyzeEventAlignedWaveletSimilarity(analysisOutput)
%
% Purpose
%   Reuse the existing event peaks from `analyzePrimitiveEvents` and test
%   whether isolated envelope events share a normalized time-frequency
%   structure across subjects and conditions.
%
% Important assumption
%   This analysis is about normalized event shape, not event amplitude.
%   Each event snippet is optionally amplitude-normalized before wavelet
%   analysis, and each wavelet magnitude map is optionally normalized by
%   its own maximum.
%
% Input
%   analysisOutput
%       Structure returned by `analyzePrimitiveEvents`.
%
% Optional name-value inputs
%   'EventWindowSeconds'    default [-5 5]
%   'FrequencyLimitsHz'     default [0.2 10]
%   'WaveletName'           default 'amor'
%   'VoicesPerOctave'       default 12
%   'UseIsolatedEventsOnly' default true
%   'NormalizeEachEvent'    default true
%   'MakePlots'             default true
%
% Output
%   waveletOutput.eventWaveletMaps
%   waveletOutput.frequencyHz
%   waveletOutput.relativeTimeSec
%   waveletOutput.eventTable
%   waveletOutput.similarityMatrix
%   waveletOutput.similarityTable
%   waveletOutput.conditionMeanMaps
%   waveletOutput.subjectMeanMaps
%   waveletOutput.randomControl
%   waveletOutput.figureHandles

inputParserObject = inputParser;

addRequired(inputParserObject, 'analysisOutput', @isstruct);
addParameter(inputParserObject, 'EventWindowSeconds', [-5 5], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) < value(2));
addParameter(inputParserObject, 'FrequencyLimitsHz', [0.2 10], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) > 0 && value(1) < value(2));
addParameter(inputParserObject, 'WaveletName', 'amor', ...
    @(value) ischar(value) || isstring(value));
addParameter(inputParserObject, 'VoicesPerOctave', 12, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);
addParameter(inputParserObject, 'UseIsolatedEventsOnly', true, ...
    @(value) islogical(value) || isnumeric(value));
addParameter(inputParserObject, 'NormalizeEachEvent', true, ...
    @(value) islogical(value) || isnumeric(value));
addParameter(inputParserObject, 'MakePlots', true, ...
    @(value) islogical(value) || isnumeric(value));

parse(inputParserObject, analysisOutput, varargin{:});
options = inputParserObject.Results;

if ~isfield(analysisOutput, 'perFile') || isempty(analysisOutput.perFile)
    error('analyzeEventAlignedWaveletSimilarity:MissingPerFile', ...
        'analysisOutput.perFile is required.');
end

perFile = analysisOutput.perFile;
windowSamples = localConvertWindowSecondsToSamples(options.EventWindowSeconds, perFile);
nWindowSamples = windowSamples(2) - windowSamples(1) + 1;
relativeSampleOffsets = (windowSamples(1):windowSamples(2)).';
referenceSamplingFrequency = localGetReferenceSamplingFrequency(perFile);
relativeTimeSec = relativeSampleOffsets ./ referenceSamplingFrequency;

eventWaveletMapCells = {};
eventSnippetCells = {};
eventMetadataRows = struct([]);
randomWaveletMapCells = {};
randomSnippetCells = {};
randomMetadataRows = struct([]);
frequencyHz = [];

for fileIndex = 1:numel(perFile)
    currentPerFile = perFile(fileIndex);
    if isempty(currentPerFile.eventOutput) || isempty(currentPerFile.motionData)
        continue;
    end

    eventTable = currentPerFile.eventOutput.eventTable;
    if isempty(eventTable)
        continue;
    end

    if logical(options.UseIsolatedEventsOnly) && ismember('isIsolatedEvent', eventTable.Properties.VariableNames)
        eventTable = eventTable(eventTable.isIsolatedEvent, :);
    end

    if isempty(eventTable)
        continue;
    end

    waveformSourceSignal = currentPerFile.eventOutput.waveformSourceSignal(:);
    timeSec = [];
    if isfield(currentPerFile.motionData, 'timeSec')
        timeSec = currentPerFile.motionData.timeSec(:);
    end
    samplingFrequency = currentPerFile.eventOutput.samplingFrequency;

    eventCountThisFile = 0;
    usedPeakIndices = zeros(height(eventTable), 1);

    for eventIndex = 1:height(eventTable)
        peakIndex = eventTable.peakIndex(eventIndex);
        snippetIndices = peakIndex + relativeSampleOffsets;

        if any(snippetIndices < 1) || any(snippetIndices > numel(waveformSourceSignal))
            continue;
        end

        snippet = waveformSourceSignal(snippetIndices);
        snippet = snippet - median(snippet, 'omitnan');

        if logical(options.NormalizeEachEvent)
            snippetScale = max(abs(snippet), [], 'omitnan');
            if isfinite(snippetScale) && snippetScale > 0
                snippet = snippet ./ snippetScale;
            end
        end

        [waveletMap, currentFrequencyHz] = localComputeWaveletMap( ...
            snippet, samplingFrequency, options.FrequencyLimitsHz, ...
            options.WaveletName, options.VoicesPerOctave, logical(options.NormalizeEachEvent));

        if isempty(frequencyHz)
            frequencyHz = currentFrequencyHz;
        else
            localAssertMatchingFrequencyAxis(frequencyHz, currentFrequencyHz);
        end

        eventCountThisFile = eventCountThisFile + 1;
        usedPeakIndices(eventCountThisFile) = peakIndex;
        eventWaveletMapCells{end + 1, 1} = waveletMap; %#ok<AGROW>
        eventSnippetCells{end + 1, 1} = snippet; %#ok<AGROW>

        currentRow = localBuildEventMetadataRow( ...
            currentPerFile, eventTable(eventIndex, :), snippetIndices, ...
            relativeTimeSec, timeSec, false);

        if isempty(eventMetadataRows)
            eventMetadataRows = currentRow;
        else
            eventMetadataRows(end + 1, 1) = currentRow; %#ok<AGROW>
        end
    end

    usedPeakIndices = usedPeakIndices(1:eventCountThisFile);
    randomPeakIndices = localSampleRandomPeakIndices( ...
        numel(waveformSourceSignal), usedPeakIndices, windowSamples, eventCountThisFile);

    for randomIndex = 1:numel(randomPeakIndices)
        peakIndex = randomPeakIndices(randomIndex);
        snippetIndices = peakIndex + relativeSampleOffsets;
        snippet = waveformSourceSignal(snippetIndices);
        snippet = snippet - median(snippet, 'omitnan');

        if logical(options.NormalizeEachEvent)
            snippetScale = max(abs(snippet), [], 'omitnan');
            if isfinite(snippetScale) && snippetScale > 0
                snippet = snippet ./ snippetScale;
            end
        end

        [waveletMap, currentFrequencyHz] = localComputeWaveletMap( ...
            snippet, samplingFrequency, options.FrequencyLimitsHz, ...
            options.WaveletName, options.VoicesPerOctave, logical(options.NormalizeEachEvent));

        if isempty(frequencyHz)
            frequencyHz = currentFrequencyHz;
        else
            localAssertMatchingFrequencyAxis(frequencyHz, currentFrequencyHz);
        end

        randomWaveletMapCells{end + 1, 1} = waveletMap; %#ok<AGROW>
        randomSnippetCells{end + 1, 1} = snippet; %#ok<AGROW>

        randomRow = localBuildRandomMetadataRow(currentPerFile, peakIndex, snippetIndices, relativeTimeSec, timeSec);
        if isempty(randomMetadataRows)
            randomMetadataRows = randomRow;
        else
            randomMetadataRows(end + 1, 1) = randomRow; %#ok<AGROW>
        end
    end
end

eventWaveletMaps = localStackWaveletMaps(eventWaveletMapCells, frequencyHz, nWindowSamples);
eventSnippetMatrix = localStackSnippetMatrix(eventSnippetCells, nWindowSamples);
randomWaveletMaps = localStackWaveletMaps(randomWaveletMapCells, frequencyHz, nWindowSamples);
randomSnippetMatrix = localStackSnippetMatrix(randomSnippetCells, nWindowSamples);

eventTable = localMetadataStructToTable(eventMetadataRows);
randomTable = localMetadataStructToTable(randomMetadataRows);

similarityMatrix = localComputeSimilarityMatrix(eventWaveletMaps);
similarityTable = localBuildSimilarityTable(similarityMatrix, eventTable);

conditionMeanMaps = localBuildMeanMapStruct(eventWaveletMaps, eventTable, 'condition', frequencyHz, relativeTimeSec);
subjectMeanMaps = localBuildMeanMapStruct(eventWaveletMaps, eventTable, 'subjectID', frequencyHz, relativeTimeSec);
randomControl = localBuildRandomControl( ...
    eventWaveletMaps, eventTable, randomWaveletMaps, randomTable, similarityMatrix);

figureHandles = struct();
figureHandles.conditionMeanMaps = [];
figureHandles.subjectMeanMaps = [];
figureHandles.similarityMatrix = [];
figureHandles.similarityDistributions = [];
figureHandles.randomControl = [];

if logical(options.MakePlots)
    figureHandles.conditionMeanMaps = localMakeMeanMapFigure(conditionMeanMaps, 'Condition', options.NormalizeEachEvent);
    figureHandles.subjectMeanMaps = localMakeMeanMapFigure(subjectMeanMaps, 'Subject', options.NormalizeEachEvent);
    figureHandles.similarityMatrix = localMakeSimilarityMatrixFigure(similarityMatrix, eventTable);
    figureHandles.similarityDistributions = localMakeSimilarityDistributionFigure(similarityTable);
    figureHandles.randomControl = localMakeRandomControlFigure(randomControl);
end

waveletOutput = struct();
waveletOutput.eventWaveletMaps = eventWaveletMaps;
waveletOutput.eventSnippetMatrix = eventSnippetMatrix;
waveletOutput.frequencyHz = frequencyHz;
waveletOutput.relativeTimeSec = relativeTimeSec;
waveletOutput.eventTable = eventTable;
waveletOutput.similarityMatrix = similarityMatrix;
waveletOutput.similarityTable = similarityTable;
waveletOutput.conditionMeanMaps = conditionMeanMaps;
waveletOutput.subjectMeanMaps = subjectMeanMaps;
waveletOutput.randomControl = randomControl;
waveletOutput.figureHandles = figureHandles;
waveletOutput.options = options;
waveletOutput.randomControl.randomWaveletMaps = randomWaveletMaps;
waveletOutput.randomControl.randomSnippetMatrix = randomSnippetMatrix;

end

function windowSamples = localConvertWindowSecondsToSamples(eventWindowSeconds, perFile)
samplingFrequency = localGetReferenceSamplingFrequency(perFile);
windowSamples = round(eventWindowSeconds .* samplingFrequency);
if windowSamples(1) >= 0 || windowSamples(2) <= 0
    error('analyzeEventAlignedWaveletSimilarity:BadWindow', ...
        'EventWindowSeconds must span negative and positive time around the peak.');
end
end

function samplingFrequency = localGetReferenceSamplingFrequency(perFile)
samplingFrequency = [];
for fileIndex = 1:numel(perFile)
    if ~isempty(perFile(fileIndex).eventOutput)
        samplingFrequency = perFile(fileIndex).eventOutput.samplingFrequency;
        break;
    end
end

if isempty(samplingFrequency) || ~isfinite(samplingFrequency)
    error('analyzeEventAlignedWaveletSimilarity:MissingSamplingFrequency', ...
        'Could not determine sampling frequency from analysisOutput.perFile.');
end
end

function [waveletMap, frequencyHz] = localComputeWaveletMap(snippet, samplingFrequency, frequencyLimitsHz, waveletName, voicesPerOctave, normalizeEachEvent)
[coefficients, frequencyHz] = cwt(snippet, waveletName, samplingFrequency, ...
    'FrequencyLimits', frequencyLimitsHz, ...
    'VoicesPerOctave', voicesPerOctave);

waveletMap = abs(coefficients);
if logical(normalizeEachEvent)
    mapScale = max(waveletMap(:), [], 'omitnan');
    if isfinite(mapScale) && mapScale > 0
        waveletMap = waveletMap ./ mapScale;
    end
end
end

function localAssertMatchingFrequencyAxis(referenceFrequencyHz, currentFrequencyHz)
if numel(referenceFrequencyHz) ~= numel(currentFrequencyHz) || ...
        any(abs(referenceFrequencyHz - currentFrequencyHz) > 1e-9)
    error('analyzeEventAlignedWaveletSimilarity:FrequencyAxisMismatch', ...
        'CWT returned inconsistent frequency axes across events.');
end
end

function metadataRow = localBuildEventMetadataRow(currentPerFile, eventTableRow, snippetIndices, relativeTimeSec, timeSec, isRandom)
metadataRow = struct();
metadataRow.fileName = string(currentPerFile.fileName);
metadataRow.filePath = string(currentPerFile.filePath);
metadataRow.subjectID = string(currentPerFile.subjectID);
metadataRow.condition = string(currentPerFile.condition);
metadataRow.peakIndex = eventTableRow.peakIndex;
metadataRow.windowStartIndex = snippetIndices(1);
metadataRow.windowEndIndex = snippetIndices(end);
metadataRow.isRandomControl = logical(isRandom);

if ismember('detectorAmplitude', eventTableRow.Properties.VariableNames)
    metadataRow.detectorAmplitude = eventTableRow.detectorAmplitude;
else
    metadataRow.detectorAmplitude = NaN;
end

if ismember('detectorWidthSec', eventTableRow.Properties.VariableNames)
    metadataRow.detectorWidthSec = eventTableRow.detectorWidthSec;
else
    metadataRow.detectorWidthSec = NaN;
end

if ismember('interEventIntervalSec', eventTableRow.Properties.VariableNames)
    metadataRow.interEventIntervalSec = eventTableRow.interEventIntervalSec;
else
    metadataRow.interEventIntervalSec = NaN;
end

if ismember('isIsolatedEvent', eventTableRow.Properties.VariableNames)
    metadataRow.isIsolatedEvent = eventTableRow.isIsolatedEvent;
else
    metadataRow.isIsolatedEvent = true;
end

metadataRow.peakTimeSec = NaN;
metadataRow.windowStartTimeSec = NaN;
metadataRow.windowEndTimeSec = NaN;
if ~isempty(timeSec)
    metadataRow.peakTimeSec = timeSec(eventTableRow.peakIndex);
    metadataRow.windowStartTimeSec = timeSec(snippetIndices(1));
    metadataRow.windowEndTimeSec = timeSec(snippetIndices(end));
end

metadataRow.relativeTimeAtPeakSec = relativeTimeSec(find(relativeTimeSec == 0, 1, 'first'));
end

function metadataRow = localBuildRandomMetadataRow(currentPerFile, peakIndex, snippetIndices, relativeTimeSec, timeSec)
metadataRow = struct();
metadataRow.fileName = string(currentPerFile.fileName);
metadataRow.filePath = string(currentPerFile.filePath);
metadataRow.subjectID = string(currentPerFile.subjectID);
metadataRow.condition = string(currentPerFile.condition);
metadataRow.peakIndex = peakIndex;
metadataRow.windowStartIndex = snippetIndices(1);
metadataRow.windowEndIndex = snippetIndices(end);
metadataRow.isRandomControl = true;
metadataRow.detectorAmplitude = NaN;
metadataRow.detectorWidthSec = NaN;
metadataRow.interEventIntervalSec = NaN;
metadataRow.isIsolatedEvent = false;
metadataRow.peakTimeSec = NaN;
metadataRow.windowStartTimeSec = NaN;
metadataRow.windowEndTimeSec = NaN;
if ~isempty(timeSec)
    metadataRow.peakTimeSec = timeSec(peakIndex);
    metadataRow.windowStartTimeSec = timeSec(snippetIndices(1));
    metadataRow.windowEndTimeSec = timeSec(snippetIndices(end));
end
metadataRow.relativeTimeAtPeakSec = relativeTimeSec(find(relativeTimeSec == 0, 1, 'first'));
end

function randomPeakIndices = localSampleRandomPeakIndices(nSamples, usedPeakIndices, windowSamples, targetCount)
if targetCount <= 0
    randomPeakIndices = zeros(0, 1);
    return;
end

validPeakIndices = (1 - windowSamples(1)):(nSamples - windowSamples(2));
if isempty(validPeakIndices)
    randomPeakIndices = zeros(0, 1);
    return;
end

guardRadiusSamples = max(abs(windowSamples));
keepMask = true(size(validPeakIndices));
for eventIndex = 1:numel(usedPeakIndices)
    keepMask = keepMask & abs(validPeakIndices - usedPeakIndices(eventIndex)) > guardRadiusSamples;
end
candidatePeakIndices = validPeakIndices(keepMask);

if isempty(candidatePeakIndices)
    randomPeakIndices = zeros(0, 1);
    return;
end

randomOrder = randperm(numel(candidatePeakIndices));
randomPeakIndices = candidatePeakIndices(randomOrder(1:min(targetCount, numel(candidatePeakIndices)))).';
end

function waveletMaps = localStackWaveletMaps(waveletMapCells, frequencyHz, nWindowSamples)
if isempty(waveletMapCells)
    waveletMaps = NaN(numel(frequencyHz), nWindowSamples, 0);
    return;
end

nEvents = numel(waveletMapCells);
waveletMaps = NaN(size(waveletMapCells{1}, 1), size(waveletMapCells{1}, 2), nEvents);
for eventIndex = 1:nEvents
    waveletMaps(:, :, eventIndex) = waveletMapCells{eventIndex};
end
end

function snippetMatrix = localStackSnippetMatrix(snippetCells, nWindowSamples)
if isempty(snippetCells)
    snippetMatrix = NaN(nWindowSamples, 0);
    return;
end

snippetMatrix = NaN(nWindowSamples, numel(snippetCells));
for eventIndex = 1:numel(snippetCells)
    snippetMatrix(:, eventIndex) = snippetCells{eventIndex};
end
end

function metadataTable = localMetadataStructToTable(metadataRows)
if isempty(metadataRows)
    metadataTable = table();
else
    metadataTable = struct2table(metadataRows);
end
end

function similarityMatrix = localComputeSimilarityMatrix(eventWaveletMaps)
nEvents = size(eventWaveletMaps, 3);
if nEvents == 0
    similarityMatrix = NaN(0, 0);
    return;
end

flattenedMaps = reshape(eventWaveletMaps, [], nEvents).';
similarityMatrix = corr(flattenedMaps.', 'Rows', 'pairwise');
end

function similarityTable = localBuildSimilarityTable(similarityMatrix, eventTable)
if isempty(eventTable) || isempty(similarityMatrix)
    similarityTable = table();
    return;
end

nEvents = height(eventTable);
nPairs = nchoosek(nEvents, 2);
pairRows = repmat(struct( ...
    'eventIndex1', NaN, ...
    'eventIndex2', NaN, ...
    'fileName1', "", ...
    'fileName2', "", ...
    'subjectID1', "", ...
    'subjectID2', "", ...
    'condition1', "", ...
    'condition2', "", ...
    'similarity', NaN, ...
    'isWithinCondition', false, ...
    'isBetweenCondition', false, ...
    'isWithinSubject', false, ...
    'isBetweenSubject', false), nPairs, 1);

pairCounter = 0;
for eventIndex1 = 1:(nEvents - 1)
    for eventIndex2 = (eventIndex1 + 1):nEvents
        pairCounter = pairCounter + 1;
        pairRows(pairCounter).eventIndex1 = eventIndex1;
        pairRows(pairCounter).eventIndex2 = eventIndex2;
        pairRows(pairCounter).fileName1 = string(eventTable.fileName(eventIndex1));
        pairRows(pairCounter).fileName2 = string(eventTable.fileName(eventIndex2));
        pairRows(pairCounter).subjectID1 = string(eventTable.subjectID(eventIndex1));
        pairRows(pairCounter).subjectID2 = string(eventTable.subjectID(eventIndex2));
        pairRows(pairCounter).condition1 = string(eventTable.condition(eventIndex1));
        pairRows(pairCounter).condition2 = string(eventTable.condition(eventIndex2));
        pairRows(pairCounter).similarity = similarityMatrix(eventIndex1, eventIndex2);
        pairRows(pairCounter).isWithinCondition = pairRows(pairCounter).condition1 == pairRows(pairCounter).condition2;
        pairRows(pairCounter).isBetweenCondition = ~pairRows(pairCounter).isWithinCondition;
        pairRows(pairCounter).isWithinSubject = pairRows(pairCounter).subjectID1 == pairRows(pairCounter).subjectID2;
        pairRows(pairCounter).isBetweenSubject = ~pairRows(pairCounter).isWithinSubject;
    end
end

similarityTable = struct2table(pairRows);
end

function meanMapStruct = localBuildMeanMapStruct(eventWaveletMaps, eventTable, groupVariableName, frequencyHz, relativeTimeSec)
if isempty(eventTable)
    meanMapStruct = struct([]);
    return;
end

groupValues = unique(string(eventTable.(groupVariableName)), 'stable');
meanMapStruct = repmat(struct( ...
    'groupName', "", ...
    'groupVariable', string(groupVariableName), ...
    'meanMap', [], ...
    'nEvents', 0, ...
    'frequencyHz', frequencyHz, ...
    'relativeTimeSec', relativeTimeSec), numel(groupValues), 1);

for groupIndex = 1:numel(groupValues)
    currentGroup = groupValues(groupIndex);
    mask = string(eventTable.(groupVariableName)) == currentGroup;
    currentMaps = eventWaveletMaps(:, :, mask);

    meanMapStruct(groupIndex).groupName = currentGroup;
    meanMapStruct(groupIndex).meanMap = mean(currentMaps, 3, 'omitnan');
    meanMapStruct(groupIndex).nEvents = sum(mask);
end
end

function randomControl = localBuildRandomControl(eventWaveletMaps, eventTable, randomWaveletMaps, randomTable, similarityMatrix)
randomControl = struct();
randomControl.randomTable = randomTable;

eventRandomSimilarity = localComputeCrossSimilarity(eventWaveletMaps, randomWaveletMaps);
randomControl.eventRandomSimilarity = eventRandomSimilarity(:);

randomSimilarity = localComputeSimilarityMatrix(randomWaveletMaps);
randomControl.randomSimilarityMatrix = randomSimilarity;
randomControl.randomRandomSimilarity = localUpperTriangleValues(randomSimilarity);

randomControl.eventEventSimilarity = localUpperTriangleValues(similarityMatrix);
randomControl.summaryTable = localBuildRandomSummaryTable(eventTable, randomTable, similarityMatrix, eventRandomSimilarity);
end

function crossSimilarity = localComputeCrossSimilarity(eventWaveletMaps, randomWaveletMaps)
nEvents = size(eventWaveletMaps, 3);
nRandom = size(randomWaveletMaps, 3);
if nEvents == 0 || nRandom == 0
    crossSimilarity = NaN(nEvents, nRandom);
    return;
end

eventVectors = reshape(eventWaveletMaps, [], nEvents).';
randomVectors = reshape(randomWaveletMaps, [], nRandom).';
crossSimilarity = corr(eventVectors.', randomVectors.', 'Rows', 'pairwise');
end

function upperTriangleValues = localUpperTriangleValues(similarityMatrix)
if isempty(similarityMatrix)
    upperTriangleValues = [];
    return;
end

upperMask = triu(true(size(similarityMatrix)), 1);
upperTriangleValues = similarityMatrix(upperMask);
upperTriangleValues = upperTriangleValues(isfinite(upperTriangleValues));
end

function summaryTable = localBuildRandomSummaryTable(eventTable, randomTable, eventSimilarityMatrix, eventRandomSimilarity)
summaryTable = table();

eventEventValues = localUpperTriangleValues(eventSimilarityMatrix);
eventRandomValues = eventRandomSimilarity(isfinite(eventRandomSimilarity));

summaryTable.comparison = ["event-event"; "event-random"; "random-count"];
summaryTable.n = [numel(eventEventValues); numel(eventRandomValues); height(randomTable)];
summaryTable.medianSimilarity = [median(eventEventValues, 'omitnan'); median(eventRandomValues, 'omitnan'); NaN];
summaryTable.meanSimilarity = [mean(eventEventValues, 'omitnan'); mean(eventRandomValues, 'omitnan'); NaN];
summaryTable.nEventWindows = [height(eventTable); height(eventTable); NaN];
summaryTable.nRandomWindows = [height(randomTable); height(randomTable); height(randomTable)];
end

function figureHandle = localMakeMeanMapFigure(meanMapStruct, groupLabel, normalizeEachEvent)
figureHandle = figure('Color', 'w', 'Position', [100 100 1400 900]);
nGroups = max(1, numel(meanMapStruct));
t = tiledlayout(ceil(sqrt(nGroups)), ceil(nGroups / ceil(sqrt(nGroups))), 'TileSpacing', 'compact', 'Padding', 'compact');

if logical(normalizeEachEvent)
    subtitleText = 'Each event and each wavelet map were normalized before averaging.';
else
    subtitleText = 'Wavelet maps were averaged without per-event normalization.';
end
title(t, sprintf('%s mean normalized wavelet maps', groupLabel), 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, subtitleText, 'FontSize', 11);

for groupIndex = 1:numel(meanMapStruct)
    ax = nexttile(t, groupIndex);
    imagesc(ax, meanMapStruct(groupIndex).relativeTimeSec, meanMapStruct(groupIndex).frequencyHz, meanMapStruct(groupIndex).meanMap);
    axis(ax, 'xy');
    set(ax, 'YScale', 'log');
    grid(ax, 'on');
    xlabel(ax, 'time relative to peak (s)');
    ylabel(ax, 'frequency (Hz)');
    title(ax, sprintf('%s (n = %d)', char(meanMapStruct(groupIndex).groupName), meanMapStruct(groupIndex).nEvents), 'Interpreter', 'none', 'FontWeight', 'normal');
    colorbar(ax);
end
end

function figureHandle = localMakeSimilarityMatrixFigure(similarityMatrix, eventTable)
figureHandle = figure('Color', 'w', 'Position', [120 120 1000 900]);
ax = axes(figureHandle);
imagesc(ax, similarityMatrix, [-1 1]);
axis(ax, 'image');
colorbar(ax);
grid(ax, 'on');
xlabel(ax, 'event index');
ylabel(ax, 'event index');
title(ax, 'Event-by-event wavelet similarity matrix', 'FontWeight', 'bold');

if ~isempty(eventTable) && height(eventTable) <= 80
    tickValues = 1:height(eventTable);
    tickLabels = compose('%s|%s', string(eventTable.subjectID), string(eventTable.condition));
    ax.XTick = tickValues;
    ax.YTick = tickValues;
    ax.XTickLabel = tickLabels;
    ax.YTickLabel = tickLabels;
    ax.XTickLabelRotation = 90;
end
end

function figureHandle = localMakeSimilarityDistributionFigure(similarityTable)
figureHandle = figure('Color', 'w', 'Position', [140 140 1200 900]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Wavelet similarity distributions', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Similarity is correlation of normalized event-centered wavelet maps.', 'FontSize', 11);

distributionDefinitions = {
    similarityTable.similarity(similarityTable.isWithinCondition), 'within condition';
    similarityTable.similarity(similarityTable.isBetweenCondition), 'between condition';
    similarityTable.similarity(similarityTable.isWithinSubject), 'within subject';
    similarityTable.similarity(similarityTable.isBetweenSubject), 'between subject'};

for distributionIndex = 1:size(distributionDefinitions, 1)
    ax = nexttile(t, distributionIndex);
    values = distributionDefinitions{distributionIndex, 1};
    values = values(isfinite(values));
    if isempty(values)
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
        continue;
    end

    [f, x] = ecdf(values);
    plot(ax, x, f, 'LineWidth', 2);
    grid(ax, 'on');
    xlim(ax, [-1 1]);
    xlabel(ax, 'wavelet similarity');
    ylabel(ax, 'CDF');
    title(ax, distributionDefinitions{distributionIndex, 2}, 'FontWeight', 'normal');
end
end

function figureHandle = localMakeRandomControlFigure(randomControl)
figureHandle = figure('Color', 'w', 'Position', [160 160 1200 500]);
t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Random-window control', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Tests whether normalized event-centered maps are more self-similar than random non-event windows.', 'FontSize', 11);

ax1 = nexttile(t, 1);
hold(ax1, 'on');
eventEventValues = randomControl.eventEventSimilarity;
eventRandomValues = randomControl.eventRandomSimilarity;

eventEventValues = eventEventValues(isfinite(eventEventValues));
eventRandomValues = eventRandomValues(isfinite(eventRandomValues));

if ~isempty(eventEventValues)
    [f1, x1] = ecdf(eventEventValues);
    plot(ax1, x1, f1, 'LineWidth', 2, 'DisplayName', 'event-event');
end
if ~isempty(eventRandomValues)
    [f2, x2] = ecdf(eventRandomValues);
    plot(ax1, x2, f2, 'LineWidth', 2, 'DisplayName', 'event-random');
end
grid(ax1, 'on');
xlim(ax1, [-1 1]);
xlabel(ax1, 'wavelet similarity');
ylabel(ax1, 'CDF');
title(ax1, 'Similarity distributions', 'FontWeight', 'normal');
legend(ax1, 'Location', 'southeast');

ax2 = nexttile(t, 2);
axis(ax2, 'off');
summaryTable = randomControl.summaryTable;
summaryLines = strings(height(summaryTable), 1);
for rowIndex = 1:height(summaryTable)
    summaryLines(rowIndex) = sprintf('%s: n = %d, median = %.3f, mean = %.3f', ...
        char(summaryTable.comparison(rowIndex)), ...
        summaryTable.n(rowIndex), ...
        summaryTable.medianSimilarity(rowIndex), ...
        summaryTable.meanSimilarity(rowIndex));
end
text(ax2, 0.0, 1.0, strjoin(summaryLines, newline), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'FontName', 'Courier');
title(ax2, 'Summary', 'FontWeight', 'normal');
end
