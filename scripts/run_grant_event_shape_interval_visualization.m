% Grant-oriented visualization of unitary and compound LAR event structure.
%
% This script uses the revised valley-delimited compound-bout definition:
% peaks belong to the same bout unless the valley between adjacent subpeaks
% drops below 50% of the smaller adjacent peak. Subpeaks are detected with
% MinPeakDistance = 0.35 s, retained after the focused sensitivity test.

clear;
close all;
clc;

set(0, 'DefaultFigureVisible', 'off');

scriptPath = mfilename('fullpath');
repoRoot = fileparts(fileparts(scriptPath));
scratchRoot = fullfile(repoRoot, 'scratch', 'unitary_event_validation_20260508');
outputRoot = fullfile(scratchRoot, 'outputs');
tableRoot = fullfile(scratchRoot, 'tables');
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end
if ~isfolder(tableRoot)
    mkdir(tableRoot);
end

addpath(fullfile(repoRoot, 'CODE', 'ACCELEROMETER'));
addpath(fullfile(repoRoot, 'CODE', 'ANALYSIS'));

magnitudeRoot = LF_resolveFolder({ ...
    '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED/MAGNITUDES', ...
    '/Users/yoe/Dropbox/WORK/Data/Waseda-ACC/MAGNITUDES', ...
    '/Users/yoe/Library/CloudStorage/Dropbox/WORK/Data/Waseda-ACC/MAGNITUDES'});
rawRoot = LF_resolveOptionalFolder({ ...
    '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED/CONCATENATED'});

settings = struct();
settings.baselineWindowSeconds = 15;
settings.noiseWindowSeconds = 30;
settings.thresholdSigma = 4;
settings.lowThresholdSigma = 2;
settings.lobeSearchWindowSeconds = [-1.5 4.5];
settings.lobeValleyFraction = 0.50;
settings.subpeakMinDistanceSeconds = 0.35;
settings.shapeWindowSeconds = [-1.5 2.5];
settings.quaternionJumpMaxDeg = 60;
settings.useConjugate = true;
settings.nExampleRows = 3;

magnitudeFiles = dir(fullfile(magnitudeRoot, '*_acc1_chest_motionEnvelope.mat'));
if isempty(magnitudeFiles)
    error('No magnitude files found in %s.', magnitudeRoot);
end

boutRows = struct([]);
subpeakRows = struct([]);
eventSignalSnippets = [];
linearMagnitudeSnippets = [];
envelopeSnippets = [];
snippetMetadata = struct([]);

fprintf('Building revised-bout grant visualization dataset from %d files.\n', numel(magnitudeFiles));

for fileIndex = 1:numel(magnitudeFiles)
    fileName = magnitudeFiles(fileIndex).name;
    fprintf('  [%d/%d] %s\n', fileIndex, numel(magnitudeFiles), fileName);
    fileContext = LF_buildFileContext(fileName, magnitudeRoot, rawRoot, settings);
    relativeSamples = round(settings.shapeWindowSeconds(1) .* fileContext.samplingFrequency): ...
        round(settings.shapeWindowSeconds(2) .* fileContext.samplingFrequency);
    relativeTimeSec = relativeSamples(:) ./ fileContext.samplingFrequency;
    seenKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for eventIndex = 1:height(fileContext.eventTable)
        anchorPeakIndex = fileContext.eventTable.peakIndex(eventIndex);
        lobeOutput = LF_getAnchorLobeSubpeaks(fileContext, anchorPeakIndex, settings);
        boutKey = sprintf('%s|%s', fileName, sprintf('%d_', lobeOutput.lobeSubpeaks));
        if isKey(seenKeys, boutKey)
            continue;
        end
        seenKeys(boutKey) = true;

        subpeakValues = fileContext.eventSignal(lobeOutput.lobeSubpeaks);
        [dominantPeakValue, dominantPosition] = max(subpeakValues);
        dominantPeakIndex = lobeOutput.lobeSubpeaks(dominantPosition);
        relativeSubpeakTimes = (lobeOutput.lobeSubpeaks - dominantPeakIndex) ./ fileContext.samplingFrequency;
        isCompoundBout = numel(lobeOutput.lobeSubpeaks) >= 2;

        eventSignalSnippet = LF_extractSnippet(fileContext.eventSignal, dominantPeakIndex, relativeSamples);
        linearMagnitudeSnippet = LF_extractSnippet(fileContext.linearMagnitude, dominantPeakIndex, relativeSamples);
        envelopeSnippet = LF_extractSnippet(fileContext.motionEnvelope, dominantPeakIndex, relativeSamples);

        if any(~isfinite(eventSignalSnippet)) || any(~isfinite(linearMagnitudeSnippet))
            continue;
        end

        snippetIndex = size(eventSignalSnippets, 2) + 1;
        eventSignalSnippets(:, snippetIndex) = eventSignalSnippet(:); %#ok<SAGROW>
        linearMagnitudeSnippets(:, snippetIndex) = linearMagnitudeSnippet(:); %#ok<SAGROW>
        envelopeSnippets(:, snippetIndex) = envelopeSnippet(:); %#ok<SAGROW>

        boutRows(end + 1, 1).fileName = string(fileName); %#ok<AGROW>
        boutRows(end, 1).subjectID = fileContext.subjectID;
        boutRows(end, 1).condition = fileContext.condition;
        boutRows(end, 1).dominantPeakIndex = dominantPeakIndex;
        boutRows(end, 1).dominantPeakTimeSec = fileContext.timeSec(dominantPeakIndex);
        boutRows(end, 1).dominantPeakValue = dominantPeakValue;
        boutRows(end, 1).nSubpeaks = numel(lobeOutput.lobeSubpeaks);
        boutRows(end, 1).isUnitaryBout = ~isCompoundBout;
        boutRows(end, 1).isCompoundBout = isCompoundBout;
        boutRows(end, 1).activeSubpeakSpanSec = max(relativeSubpeakTimes) - min(relativeSubpeakTimes);
        boutRows(end, 1).snippetIndex = snippetIndex;
        boutRows(end, 1).relativeSubpeakTimesText = ...
            string(strjoin(cellstr(string(round(relativeSubpeakTimes(:).', 4))), ';'));

        snippetMetadata(end + 1, 1).fileName = string(fileName); %#ok<AGROW>
        snippetMetadata(end, 1).condition = fileContext.condition;
        snippetMetadata(end, 1).nSubpeaks = numel(lobeOutput.lobeSubpeaks);
        snippetMetadata(end, 1).isCompoundBout = isCompoundBout;

        for subpeakIndex = 1:numel(lobeOutput.lobeSubpeaks)
            subpeakRows(end + 1, 1).fileName = string(fileName); %#ok<AGROW>
            subpeakRows(end, 1).subjectID = fileContext.subjectID;
            subpeakRows(end, 1).condition = fileContext.condition;
            subpeakRows(end, 1).dominantPeakIndex = dominantPeakIndex;
            subpeakRows(end, 1).subpeakIndex = lobeOutput.lobeSubpeaks(subpeakIndex);
            subpeakRows(end, 1).relativeTimeToDominantSec = relativeSubpeakTimes(subpeakIndex);
            subpeakRows(end, 1).subpeakValue = fileContext.eventSignal(lobeOutput.lobeSubpeaks(subpeakIndex));
            subpeakRows(end, 1).isDominantSubpeak = lobeOutput.lobeSubpeaks(subpeakIndex) == dominantPeakIndex;
            subpeakRows(end, 1).isCompoundBout = isCompoundBout;
        end
    end
end

boutTable = struct2table(boutRows);
subpeakTable = struct2table(subpeakRows);
snippetMetadataTable = struct2table(snippetMetadata);

intervalTable = LF_buildIntervalTable(boutTable);
summaryTable = LF_buildSummaryTable(boutTable, intervalTable);

writetable(boutTable, fullfile(tableRoot, 'grant_revised_bout_shape_bouts.csv'));
writetable(subpeakTable, fullfile(tableRoot, 'grant_revised_bout_shape_subpeaks.csv'));
writetable(intervalTable, fullfile(tableRoot, 'grant_revised_bout_shape_intervals.csv'));
writetable(summaryTable, fullfile(tableRoot, 'grant_revised_bout_shape_summary.csv'));

save(fullfile(scratchRoot, 'grant_revised_bout_shape_workspace.mat'), ...
    'settings', 'relativeTimeSec', 'boutTable', 'subpeakTable', 'intervalTable', ...
    'summaryTable', 'eventSignalSnippets', 'linearMagnitudeSnippets', ...
    'envelopeSnippets', 'snippetMetadataTable', '-v7.3');

LF_makeGrantShapeFigure(relativeTimeSec, eventSignalSnippets, linearMagnitudeSnippets, ...
    envelopeSnippets, snippetMetadataTable, boutTable, subpeakTable, intervalTable, outputRoot);
LF_makeGrantExamplesFigure(settings, magnitudeRoot, rawRoot, boutTable, subpeakTable, outputRoot);
LF_appendGrantReport(scratchRoot, outputRoot, tableRoot, summaryTable);

fprintf('Grant event shape and interval visualization complete.\n');

function fileContext = LF_buildFileContext(fileName, magnitudeRoot, rawRoot, settings)
magnitudePath = fullfile(magnitudeRoot, fileName);
loadedMagnitude = load(magnitudePath, 'motionData');
motionData = loadedMagnitude.motionData;
samplingFrequency = motionData.meta.sampleRateHz;
linearMagnitude = LF_getLinearMagnitude(motionData, fileName, rawRoot, settings);

existingFigures = findall(0, 'Type', 'figure');
eventOutput = extractEnvelopeEvents(motionData.motionEnvelope, samplingFrequency, ...
    'TimeSec', motionData.timeSec, ...
    'BaselineWindowSeconds', settings.baselineWindowSeconds, ...
    'NoiseWindowSeconds', settings.noiseWindowSeconds, ...
    'RectifyResidual', true, ...
    'ThresholdSigma', settings.thresholdSigma, ...
    'MakeWaveformFigure', false, ...
    'MakeSummaryFigure', false);
newFigures = setdiff(findall(0, 'Type', 'figure'), existingFigures);
close(newFigures);

fileInfo = LF_parseWasedaFileName(fileName);
fileContext = struct();
fileContext.fileName = string(fileName);
fileContext.subjectID = string(fileInfo.subjectID);
fileContext.condition = string(fileInfo.condition);
fileContext.samplingFrequency = samplingFrequency;
fileContext.timeSec = motionData.timeSec(:);
fileContext.motionEnvelope = motionData.motionEnvelope(:);
fileContext.eventSignal = eventOutput.noiseEstimate.eventSignal(:);
fileContext.noiseSigma = eventOutput.noiseEstimate.noiseSigma(:);
fileContext.linearMagnitude = linearMagnitude(:);
fileContext.eventTable = eventOutput.eventTable;
end

function folderPath = LF_resolveFolder(candidateFolders)
for folderIndex = 1:numel(candidateFolders)
    candidateFolder = candidateFolders{folderIndex};
    if isfolder(candidateFolder)
        folderPath = candidateFolder;
        return;
    end
end
error('Could not find any candidate folder:\n%s', strjoin(string(candidateFolders), newline));
end

function folderPath = LF_resolveOptionalFolder(candidateFolders)
folderPath = "";
for folderIndex = 1:numel(candidateFolders)
    candidateFolder = candidateFolders{folderIndex};
    if isfolder(candidateFolder)
        folderPath = string(candidateFolder);
        return;
    end
end
end

function linearMagnitude = LF_getLinearMagnitude(motionData, fileName, rawRoot, settings)
if strlength(string(rawRoot)) > 0
    rawPath = fullfile(char(rawRoot), replace(fileName, '_motionEnvelope.mat', '.mat'));
    if isfile(rawPath)
        loadedRaw = load(rawPath, 'accData');
        imuPrepared = prepareAccelerometerQuaternionData(loadedRaw.accData, ...
            'AccelerationUnit', 'auto', ...
            'QuaternionOrder', 'wxyz', ...
            'QuaternionJumpMaxDeg', settings.quaternionJumpMaxDeg, ...
            'MakeQcPlots', false);
        imuCorrected = removeGravityFromPreparedImu(imuPrepared, ...
            'UseConjugate', settings.useConjugate, ...
            'MakeQcPlots', false);
        linearMagnitude = sqrt(sum(imuCorrected.acc.linear.^2, 2));
        return;
    end
end

if isfield(motionData, 'gravityCorrectedAcc')
    linearAcceleration = motionData.gravityCorrectedAcc;
    if isstruct(linearAcceleration) && isfield(linearAcceleration, 'linear')
        linearAcceleration = linearAcceleration.linear;
    end
    linearMagnitude = sqrt(sum(linearAcceleration.^2, 2));
    return;
end

error('No raw converted MAT file or motionData.gravityCorrectedAcc available for %s.', fileName);
end

function fileInfo = LF_parseWasedaFileName(fileName)
tokens = regexp(fileName, '^\d+_(sub\d+)_(.+)_acc1_chest_motionEnvelope\.mat$', 'tokens', 'once');
if isempty(tokens)
    error('Could not parse file name: %s', fileName);
end
fileInfo = struct();
fileInfo.subjectID = string(tokens{1});
fileInfo.condition = string(tokens{2});
end

function lobeOutput = LF_getAnchorLobeSubpeaks(fileContext, anchorPeakIndex, settings)
samplingFrequency = fileContext.samplingFrequency;
eventSignal = fileContext.eventSignal;
searchSamples = round(settings.lobeSearchWindowSeconds .* samplingFrequency);
searchIndices = (anchorPeakIndex + searchSamples(1)):(anchorPeakIndex + searchSamples(2));
searchIndices = searchIndices(searchIndices >= 1 & searchIndices <= numel(eventSignal));
searchSignal = eventSignal(searchIndices);

typicalNoiseSigma = median(fileContext.noiseSigma, 'omitnan');
lowThreshold = settings.lowThresholdSigma .* typicalNoiseSigma;
minimumDistanceSamples = max(1, round(settings.subpeakMinDistanceSeconds .* samplingFrequency));

[~, localLocations] = findpeaks(searchSignal, ...
    'MinPeakHeight', lowThreshold, ...
    'MinPeakDistance', minimumDistanceSamples);
allSubpeaks = searchIndices(1) + localLocations - 1;
allSubpeaks = unique([allSubpeaks(:); anchorPeakIndex], 'stable');
allSubpeaks = sort(allSubpeaks(:));

[~, anchorPosition] = min(abs(allSubpeaks - anchorPeakIndex));
lobeStartPosition = anchorPosition;
while lobeStartPosition > 1
    if LF_isDeepValley(eventSignal, allSubpeaks(lobeStartPosition - 1), ...
            allSubpeaks(lobeStartPosition), settings.lobeValleyFraction)
        break;
    end
    lobeStartPosition = lobeStartPosition - 1;
end

lobeEndPosition = anchorPosition;
while lobeEndPosition < numel(allSubpeaks)
    if LF_isDeepValley(eventSignal, allSubpeaks(lobeEndPosition), ...
            allSubpeaks(lobeEndPosition + 1), settings.lobeValleyFraction)
        break;
    end
    lobeEndPosition = lobeEndPosition + 1;
end

lobeOutput = struct();
lobeOutput.lobeSubpeaks = allSubpeaks(lobeStartPosition:lobeEndPosition);
end

function isDeep = LF_isDeepValley(eventSignal, leftPeak, rightPeak, valleyFraction)
indices = leftPeak:rightPeak;
valleyValue = min(eventSignal(indices), [], 'omitnan');
thresholdValue = valleyFraction .* min(eventSignal(leftPeak), eventSignal(rightPeak));
isDeep = valleyValue < thresholdValue;
end

function snippet = LF_extractSnippet(signal, centerIndex, relativeSamples)
sampleIndices = centerIndex + relativeSamples(:);
if any(sampleIndices < 1) || any(sampleIndices > numel(signal))
    snippet = NaN(numel(relativeSamples), 1);
else
    snippet = signal(sampleIndices);
end
end

function intervalTable = LF_buildIntervalTable(boutTable)
rowStruct = struct([]);
for boutIndex = 1:height(boutTable)
    relativeTimes = LF_parseNumberList(boutTable.relativeSubpeakTimesText(boutIndex));
    intervals = diff(sort(relativeTimes));
    for intervalIndex = 1:numel(intervals)
        rowStruct(end + 1, 1).fileName = boutTable.fileName(boutIndex); %#ok<AGROW>
        rowStruct(end, 1).subjectID = boutTable.subjectID(boutIndex);
        rowStruct(end, 1).condition = boutTable.condition(boutIndex);
        rowStruct(end, 1).dominantPeakIndex = boutTable.dominantPeakIndex(boutIndex);
        rowStruct(end, 1).intervalSec = intervals(intervalIndex);
    end
end
intervalTable = struct2table(rowStruct);
end

function values = LF_parseNumberList(textValue)
if strlength(textValue) == 0
    values = [];
else
    values = str2double(split(string(textValue), ';')).';
end
end

function summaryTable = LF_buildSummaryTable(boutTable, intervalTable)
summary = struct();
summary.nBouts = height(boutTable);
summary.nUnitaryBouts = sum(boutTable.isUnitaryBout);
summary.nCompoundBouts = sum(boutTable.isCompoundBout);
summary.fractionCompoundBouts = mean(boutTable.isCompoundBout);
summary.medianCompoundSubpeaks = median(boutTable.nSubpeaks(boutTable.isCompoundBout), 'omitnan');
summary.medianCompoundActiveSpanSec = median(boutTable.activeSubpeakSpanSec(boutTable.isCompoundBout), 'omitnan');
summary.medianCompoundIntervalSec = median(intervalTable.intervalSec, 'omitnan');
summary.fractionCompoundIntervalsBelow700ms = mean(intervalTable.intervalSec < 0.7, 'omitnan');
summary.fractionCompoundIntervalsBelow1000ms = mean(intervalTable.intervalSec < 1.0, 'omitnan');
summaryTable = struct2table(summary);
end

function normalizedMatrix = LF_normalizeColumns(matrix)
normalizedMatrix = matrix;
for columnIndex = 1:size(matrix, 2)
    values = matrix(:, columnIndex);
    baseline = median(values(1:min(20, numel(values))), 'omitnan');
    values = values - baseline;
    scaleValue = max(abs(values), [], 'omitnan');
    if isfinite(scaleValue) && scaleValue > 0
        values = values ./ scaleValue;
    end
    normalizedMatrix(:, columnIndex) = values;
end
end

function [medianTrace, lowTrace, highTrace] = LF_traceSummary(matrix)
medianTrace = median(matrix, 2, 'omitnan');
lowTrace = prctile(matrix, 25, 2);
highTrace = prctile(matrix, 75, 2);
end

function LF_plotShadedTrace(ax, xValues, medianTrace, lowTrace, highTrace, colorValue, displayName)
patch(ax, [xValues(:); flipud(xValues(:))], [lowTrace(:); flipud(highTrace(:))], ...
    colorValue, 'FaceAlpha', 0.16, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, xValues, medianTrace, 'Color', colorValue, 'LineWidth', 2.5, 'DisplayName', displayName);
end

function LF_makeGrantShapeFigure(relativeTimeSec, eventSignalSnippets, linearMagnitudeSnippets, ...
    envelopeSnippets, snippetMetadataTable, boutTable, subpeakTable, intervalTable, outputRoot)
unitaryMask = ~snippetMetadataTable.isCompoundBout;
compoundMask = snippetMetadataTable.isCompoundBout;

eventSignalNormalized = LF_normalizeColumns(eventSignalSnippets);
linearMagnitudeNormalized = LF_normalizeColumns(linearMagnitudeSnippets);
envelopeNormalized = LF_normalizeColumns(envelopeSnippets);

[unitEventMedian, unitEventLow, unitEventHigh] = LF_traceSummary(eventSignalNormalized(:, unitaryMask));
[compoundEventMedian, compoundEventLow, compoundEventHigh] = LF_traceSummary(eventSignalNormalized(:, compoundMask));
[unitLinearMedian, unitLinearLow, unitLinearHigh] = LF_traceSummary(linearMagnitudeNormalized(:, unitaryMask));
[compoundLinearMedian, compoundLinearLow, compoundLinearHigh] = LF_traceSummary(linearMagnitudeNormalized(:, compoundMask));
[unitEnvelopeMedian, unitEnvelopeLow, unitEnvelopeHigh] = LF_traceSummary(envelopeNormalized(:, unitaryMask));
[compoundEnvelopeMedian, compoundEnvelopeLow, compoundEnvelopeHigh] = LF_traceSummary(envelopeNormalized(:, compoundMask));

secondaryTimes = subpeakTable.relativeTimeToDominantSec(subpeakTable.isCompoundBout & ~subpeakTable.isDominantSubpeak);
intervalValues = intervalTable.intervalSec;

figureHandle = figure('Color', 'w', 'Position', [80 80 1500 980]);
t = tiledlayout(3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Primitive-like and compound LAR event structure', 'FontSize', 18, 'FontWeight', 'bold');
subtitle(t, 'Revised definition: compound bout = two or more subpeaks within the same valley-delimited movement episode.', 'FontSize', 11);

ax = nexttile(t, 1);
hold(ax, 'on');
LF_plotShadedTrace(ax, relativeTimeSec, unitEventMedian, unitEventLow, unitEventHigh, [0.05 0.35 0.70], 'unitary');
LF_plotShadedTrace(ax, relativeTimeSec, compoundEventMedian, compoundEventLow, compoundEventHigh, [0.80 0.30 0.10], 'compound');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'time from dominant peak (s)');
ylabel(ax, 'normalized eventSignal');
title(ax, 'Detector-space event shape', 'FontWeight', 'normal');
legend(ax, 'Location', 'northeast', 'Box', 'off');

ax = nexttile(t, 2);
hold(ax, 'on');
LF_plotShadedTrace(ax, relativeTimeSec, unitLinearMedian, unitLinearLow, unitLinearHigh, [0.05 0.35 0.70], 'unitary');
LF_plotShadedTrace(ax, relativeTimeSec, compoundLinearMedian, compoundLinearLow, compoundLinearHigh, [0.80 0.30 0.10], 'compound');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'time from dominant peak (s)');
ylabel(ax, 'normalized gravity-corrected acceleration');
title(ax, 'Raw-motion support', 'FontWeight', 'normal');

ax = nexttile(t, 3);
hold(ax, 'on');
LF_plotShadedTrace(ax, relativeTimeSec, unitEnvelopeMedian, unitEnvelopeLow, unitEnvelopeHigh, [0.05 0.35 0.70], 'unitary');
LF_plotShadedTrace(ax, relativeTimeSec, compoundEnvelopeMedian, compoundEnvelopeLow, compoundEnvelopeHigh, [0.80 0.30 0.10], 'compound');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'time from dominant peak (s)');
ylabel(ax, 'normalized motion envelope');
title(ax, 'Motion-envelope shape', 'FontWeight', 'normal');

ax = nexttile(t, 4);
compoundSnippetIndices = find(compoundMask);
[~, sortOrder] = sort(snippetMetadataTable.nSubpeaks(compoundSnippetIndices));
compoundSnippetIndices = compoundSnippetIndices(sortOrder);
imagesc(ax, relativeTimeSec, 1:numel(compoundSnippetIndices), ...
    eventSignalNormalized(:, compoundSnippetIndices).');
colormap(ax, turbo);
xline(ax, 0, '--w', 'LineWidth', 1.2);
grid(ax, 'off');
xlabel(ax, 'time from dominant peak (s)');
ylabel(ax, 'compound bouts');
title(ax, 'Compound-bout shape raster', 'FontWeight', 'normal');

ax = nexttile(t, 5);
histogram(ax, secondaryTimes, 'BinEdges', -1.5:0.05:2.5, ...
    'FaceColor', [0.80 0.30 0.10], 'EdgeColor', 'none');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'secondary subpeak time from dominant (s)');
ylabel(ax, 'subpeak count');
title(ax, 'Where secondary elements occur', 'FontWeight', 'normal');

ax = nexttile(t, 6);
histogram(ax, intervalValues, 'BinEdges', 0:0.05:2.5, ...
    'FaceColor', [0.20 0.45 0.75], 'EdgeColor', 'none');
grid(ax, 'on');
xlabel(ax, 'adjacent inter-subpeak interval (s)');
ylabel(ax, 'interval count');
title(ax, 'Spacing between adjacent elements', 'FontWeight', 'normal');

ax = nexttile(t, 7);
bar(ax, categorical({'unitary', 'compound'}), [sum(unitaryMask), sum(compoundMask)], ...
    'FaceColor', [0.45 0.55 0.65]);
grid(ax, 'on');
ylabel(ax, 'bout count');
title(ax, 'Bout classes', 'FontWeight', 'normal');

ax = nexttile(t, 8);
histogram(ax, boutTable.nSubpeaks(boutTable.isCompoundBout), 'BinEdges', 1.5:1:(max(boutTable.nSubpeaks) + 0.5), ...
    'FaceColor', [0.80 0.30 0.10], 'EdgeColor', 'w');
grid(ax, 'on');
xlabel(ax, 'subpeaks per compound bout');
ylabel(ax, 'bout count');
title(ax, 'Compound-bout complexity', 'FontWeight', 'normal');

ax = nexttile(t, 9);
boxchart(ax, categorical(boutTable.condition), boutTable.nSubpeaks);
set(ax, 'TickLabelInterpreter', 'none');
grid(ax, 'on');
xlabel(ax, 'condition');
ylabel(ax, 'subpeaks per bout');
title(ax, 'Complexity by context', 'FontWeight', 'normal');

exportgraphics(figureHandle, fullfile(outputRoot, 'grant_unitary_vs_compound_event_shapes.png'), 'Resolution', 220);
savefig(figureHandle, fullfile(outputRoot, 'grant_unitary_vs_compound_event_shapes.fig'));
close(figureHandle);
end

function LF_makeGrantExamplesFigure(settings, magnitudeRoot, rawRoot, boutTable, subpeakTable, outputRoot)
unitaryCandidates = sortrows(boutTable(boutTable.isUnitaryBout, :), 'dominantPeakValue', 'descend');
compoundCandidates = sortrows(boutTable(boutTable.isCompoundBout, :), 'nSubpeaks', 'descend');
nRows = settings.nExampleRows;
selectedTable = [unitaryCandidates(1:min(nRows, height(unitaryCandidates)), :); ...
    compoundCandidates(1:min(nRows, height(compoundCandidates)), :)];

contextCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
figureHandle = figure('Color', 'w', 'Position', [90 70 1400 1050]);
t = tiledlayout(nRows, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Example unitary and compound LAR events under the revised definition', ...
    'FontSize', 17, 'FontWeight', 'bold');
subtitle(t, 'Blue trace is eventSignal; orange dots are same-bout subpeaks; green span is the active subpeak span.', 'FontSize', 11);

for rowIndex = 1:height(selectedTable)
    row = selectedTable(rowIndex, :);
    fileName = char(row.fileName);
    if isKey(contextCache, fileName)
        fileContext = contextCache(fileName);
    else
        fileContext = LF_buildFileContext(fileName, magnitudeRoot, rawRoot, settings);
        contextCache(fileName) = fileContext;
    end
    ax = nexttile(t, rowIndex);
    LF_plotExampleBout(ax, fileContext, row, subpeakTable, settings);
end

exportgraphics(figureHandle, fullfile(outputRoot, 'grant_unitary_compound_event_examples.png'), 'Resolution', 220);
savefig(figureHandle, fullfile(outputRoot, 'grant_unitary_compound_event_examples.fig'));
close(figureHandle);
end

function LF_plotExampleBout(ax, fileContext, row, subpeakTable, settings)
dominantPeakIndex = row.dominantPeakIndex;
samplingFrequency = fileContext.samplingFrequency;
plotSamples = round(settings.shapeWindowSeconds .* samplingFrequency);
plotIndices = (dominantPeakIndex + plotSamples(1)):(dominantPeakIndex + plotSamples(2));
plotIndices = plotIndices(plotIndices >= 1 & plotIndices <= numel(fileContext.eventSignal));
relativeTime = (plotIndices - dominantPeakIndex) ./ samplingFrequency;
plot(ax, relativeTime, fileContext.eventSignal(plotIndices), ...
    'Color', [0.05 0.30 0.65], 'LineWidth', 1.8);
hold(ax, 'on');
subRows = subpeakTable(string(subpeakTable.fileName) == string(row.fileName) & ...
    subpeakTable.dominantPeakIndex == dominantPeakIndex, :);
subTimes = subRows.relativeTimeToDominantSec;
yl = [0 max(fileContext.eventSignal(plotIndices), [], 'omitnan') .* 1.15];
if ~isfinite(yl(2)) || yl(2) <= 0
    yl = [0 1];
end
ylim(ax, yl);
if ~isempty(subTimes)
    patch(ax, [min(subTimes) max(subTimes) max(subTimes) min(subTimes)], ...
        [yl(1) yl(1) yl(2) yl(2)], [0.30 0.75 0.55], ...
        'FaceAlpha', 0.12, 'EdgeColor', 'none');
    plot(ax, relativeTime, fileContext.eventSignal(plotIndices), ...
        'Color', [0.05 0.30 0.65], 'LineWidth', 1.8);
end
for subIndex = 1:height(subRows)
    plot(ax, subRows.relativeTimeToDominantSec(subIndex), subRows.subpeakValue(subIndex), ...
        'o', 'MarkerFaceColor', [0.85 0.35 0.05], 'MarkerEdgeColor', [0.85 0.35 0.05], ...
        'MarkerSize', 5);
end
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'time from dominant peak (s)');
ylabel(ax, 'eventSignal');
if row.isCompoundBout
    classText = sprintf('compound, %d subpeaks', row.nSubpeaks);
else
    classText = 'unitary';
end
title(ax, sprintf('%s | %s', erase(char(row.condition), '_stand'), classText), ...
    'Interpreter', 'none', 'FontWeight', 'normal');
end

function LF_appendGrantReport(scratchRoot, outputRoot, tableRoot, summaryTable)
reportPath = fullfile(scratchRoot, 'UNITARY_EVENT_VALIDATION_REPORT.md');
fid = fopen(reportPath, 'a');
cleanupObject = onCleanup(@() fclose(fid));

fprintf(fid, '\n## Grant-Oriented Revised Bout Shape And Interval Visualization\n\n');
fprintf(fid, 'This pass reruns event-shape and interval visualization using the revised compound-bout definition: a compound bout contains at least two subpeaks within the same valley-delimited movement episode. The valley split is `0.50 * min(adjacent peaks)` and subpeak `MinPeakDistance` is `0.35 s`.\n\n');
fprintf(fid, '### Summary\n\n');
fprintf(fid, '- Total revised bouts: `%d`\n', summaryTable.nBouts);
fprintf(fid, '- Unitary bouts: `%d`\n', summaryTable.nUnitaryBouts);
fprintf(fid, '- Compound bouts: `%d`\n', summaryTable.nCompoundBouts);
fprintf(fid, '- Fraction compound: `%.3f`\n', summaryTable.fractionCompoundBouts);
fprintf(fid, '- Median compound subpeaks: `%.2f`\n', summaryTable.medianCompoundSubpeaks);
fprintf(fid, '- Median compound active span: `%.3f s`\n', summaryTable.medianCompoundActiveSpanSec);
fprintf(fid, '- Median compound interval: `%.3f s`\n', summaryTable.medianCompoundIntervalSec);
fprintf(fid, '- Compound intervals below `700 ms`: `%.3f`\n', summaryTable.fractionCompoundIntervalsBelow700ms);
fprintf(fid, '- Compound intervals below `1 s`: `%.3f`\n\n', summaryTable.fractionCompoundIntervalsBelow1000ms);
fprintf(fid, '### Figures\n\n');
fprintf(fid, '- `%s`\n', fullfile(outputRoot, 'grant_unitary_vs_compound_event_shapes.png'));
fprintf(fid, '- `%s`\n\n', fullfile(outputRoot, 'grant_unitary_compound_event_examples.png'));
fprintf(fid, '### Tables\n\n');
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'grant_revised_bout_shape_bouts.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'grant_revised_bout_shape_subpeaks.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'grant_revised_bout_shape_intervals.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'grant_revised_bout_shape_summary.csv'));
end
