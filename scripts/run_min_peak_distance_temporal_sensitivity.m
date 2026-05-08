% Test sensitivity of temporal coherence to subpeak minimum peak distance.
%
% This focused analysis asks whether the temporal peaks in same-bout subpeak
% timing are stable when the lower-threshold subpeak detector is allowed to
% resolve closer peaks.

clear;
close all;
clc;

set(0, 'DefaultFigureVisible', 'off');

scriptPath = mfilename('fullpath');
repoRoot = fileparts(fileparts(scriptPath));
scratchRoot = fullfile(repoRoot, 'scratch', 'unitary_event_validation_20260508');
outputRoot = fullfile(scratchRoot, 'outputs');
tableRoot = fullfile(scratchRoot, 'tables');

addpath(fullfile(repoRoot, 'CODE', 'ACCELEROMETER'));
addpath(fullfile(repoRoot, 'CODE', 'ANALYSIS'));

magnitudeRoot = '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED/MAGNITUDES';
templateWorkspacePath = fullfile(scratchRoot, 'compound_event_decomposition_workspace.mat');
loadedTemplate = load(templateWorkspacePath, 'unitTemplate', 'unitRelativeTimeSec', 'settings');
unitTemplate = loadedTemplate.unitTemplate;
unitRelativeTimeSec = loadedTemplate.unitRelativeTimeSec;

baseSettings = loadedTemplate.settings;
baseSettings.lobeSearchWindowSeconds = [-1.5 4.5];
baseSettings.lobeValleyFraction = 0.50;

minPeakDistanceSecondsList = [0.20 0.25 0.30 0.35 0.45 0.50];
relativeTimeEdges = -2.0:0.05:4.5;
intervalEdges = 0:0.05:3.5;

magnitudeFiles = dir(fullfile(magnitudeRoot, '*_acc1_chest_motionEnvelope.mat'));
if isempty(magnitudeFiles)
    error('No magnitude files found in %s.', magnitudeRoot);
end

summaryRows = struct([]);
secondaryRows = struct([]);
intervalRows = struct([]);

fprintf('Running min-peak-distance sensitivity on %d files.\n', numel(magnitudeFiles));

for settingIndex = 1:numel(minPeakDistanceSecondsList)
    settings = baseSettings;
    settings.subpeakMinDistanceSeconds = minPeakDistanceSecondsList(settingIndex);
    fprintf('  MinPeakDistance %.2f s\n', settings.subpeakMinDistanceSeconds);

    boutRows = struct([]);
    seenKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for fileIndex = 1:numel(magnitudeFiles)
        fileName = magnitudeFiles(fileIndex).name;
        fileContext = LF_buildFileContext(fileName, magnitudeRoot, settings);
        unitRelativeSamples = round(unitRelativeTimeSec .* fileContext.samplingFrequency);

        for eventIndex = 1:height(fileContext.eventTable)
            anchorPeakIndex = fileContext.eventTable.peakIndex(eventIndex);
            lobeOutput = LF_getAnchorLobeSubpeaks(fileContext, anchorPeakIndex, settings);
            if isempty(lobeOutput.lobeSubpeaks)
                continue;
            end

            boutKey = sprintf('%s|%s', fileName, sprintf('%d_', lobeOutput.lobeSubpeaks));
            if isKey(seenKeys, boutKey)
                continue;
            end
            seenKeys(boutKey) = true;

            subpeakValues = fileContext.eventSignal(lobeOutput.lobeSubpeaks);
            [dominantValue, dominantPosition] = max(subpeakValues);
            dominantPeakIndex = lobeOutput.lobeSubpeaks(dominantPosition);
            relativeTimesToDominant = (lobeOutput.lobeSubpeaks - dominantPeakIndex) ./ fileContext.samplingFrequency;

            nTemplateLike = 0;
            for subpeakIndex = 1:numel(lobeOutput.lobeSubpeaks)
                subpeakSample = lobeOutput.lobeSubpeaks(subpeakIndex);
                eventSignalSnippet = LF_extractSnippet(fileContext.eventSignal, subpeakSample, unitRelativeSamples);
                templateCorrelation = LF_vectorCorrelation(LF_normalizeSnippet(eventSignalSnippet), unitTemplate);
                nTemplateLike = nTemplateLike + double(templateCorrelation >= settings.templateCorrelationThreshold);
            end

            boutRows(end + 1, 1).minPeakDistanceSeconds = settings.subpeakMinDistanceSeconds; %#ok<AGROW>
            boutRows(end, 1).fileName = string(fileName);
            boutRows(end, 1).subjectID = fileContext.subjectID;
            boutRows(end, 1).condition = fileContext.condition;
            boutRows(end, 1).boutKey = string(boutKey);
            boutRows(end, 1).anchorPeakIndex = anchorPeakIndex;
            boutRows(end, 1).dominantPeakIndex = dominantPeakIndex;
            boutRows(end, 1).dominantPeakValue = dominantValue;
            boutRows(end, 1).nSubpeaks = numel(lobeOutput.lobeSubpeaks);
            boutRows(end, 1).nTemplateLikeSubpeaks = nTemplateLike;
            boutRows(end, 1).activeSubpeakSpanSec = max(relativeTimesToDominant) - min(relativeTimesToDominant);
            boutRows(end, 1).relativeTimesToDominantText = ...
                string(strjoin(cellstr(string(round(relativeTimesToDominant(:).', 4))), ';'));
        end
    end

    boutTable = struct2table(boutRows);
    [settingSecondaryRows, settingIntervalRows] = LF_extractTemporalRows(boutTable);
    secondaryRows = LF_appendStructRows(secondaryRows, settingSecondaryRows);
    intervalRows = LF_appendStructRows(intervalRows, settingIntervalRows);

    secondaryTable = struct2table(settingSecondaryRows);
    intervalTable = struct2table(settingIntervalRows);
    observedIntervalProbability = histcounts(intervalTable.intervalSec, intervalEdges, 'Normalization', 'probability');
    intervalCenters = intervalEdges(1:end-1) + diff(intervalEdges) ./ 2;
    [~, primaryPeakIndex] = max(observedIntervalProbability);
    secondaryPeakMask = intervalCenters >= 0.9 & intervalCenters <= 1.5;
    if any(secondaryPeakMask)
        [secondaryPeakProbability, secondaryLocalIndex] = max(observedIntervalProbability(secondaryPeakMask));
        secondaryCenters = intervalCenters(secondaryPeakMask);
        secondaryPeakSec = secondaryCenters(secondaryLocalIndex);
    else
        secondaryPeakProbability = NaN;
        secondaryPeakSec = NaN;
    end

    summaryRows(end + 1, 1).minPeakDistanceSeconds = settings.subpeakMinDistanceSeconds; %#ok<AGROW>
    summaryRows(end, 1).nUniqueBouts = height(boutTable);
    summaryRows(end, 1).nMultiSubpeakBouts = sum(boutTable.nSubpeaks >= 2);
    summaryRows(end, 1).nTemplateDecomposableBouts = sum(boutTable.nTemplateLikeSubpeaks >= 2);
    summaryRows(end, 1).nSecondarySubpeaks = height(secondaryTable);
    summaryRows(end, 1).nIntervals = height(intervalTable);
    summaryRows(end, 1).medianSubpeaksPerBout = median(boutTable.nSubpeaks, 'omitnan');
    summaryRows(end, 1).medianActiveSubpeakSpanSec = median(boutTable.activeSubpeakSpanSec, 'omitnan');
    summaryRows(end, 1).medianSecondaryDelaySec = median(secondaryTable.relativeTimeToDominantSec, 'omitnan');
    summaryRows(end, 1).medianAbsoluteSecondaryDelaySec = median(secondaryTable.absoluteDelaySec, 'omitnan');
    summaryRows(end, 1).medianIntervalSec = median(intervalTable.intervalSec, 'omitnan');
    summaryRows(end, 1).fractionIntervalsBelow300ms = mean(intervalTable.intervalSec < 0.3, 'omitnan');
    summaryRows(end, 1).fractionIntervalsBelow500ms = mean(intervalTable.intervalSec < 0.5, 'omitnan');
    summaryRows(end, 1).fractionIntervalsBelow700ms = mean(intervalTable.intervalSec < 0.7, 'omitnan');
    summaryRows(end, 1).primaryIntervalPeakSec = intervalCenters(primaryPeakIndex);
    summaryRows(end, 1).primaryIntervalPeakProbability = observedIntervalProbability(primaryPeakIndex);
    summaryRows(end, 1).secondaryIntervalPeakSec = secondaryPeakSec;
    summaryRows(end, 1).secondaryIntervalPeakProbability = secondaryPeakProbability;
end

summaryTable = struct2table(summaryRows);
secondaryTable = struct2table(secondaryRows);
intervalTable = struct2table(intervalRows);

writetable(summaryTable, fullfile(tableRoot, 'min_peak_distance_temporal_sensitivity_summary.csv'));
writetable(secondaryTable, fullfile(tableRoot, 'min_peak_distance_temporal_sensitivity_secondary.csv'));
writetable(intervalTable, fullfile(tableRoot, 'min_peak_distance_temporal_sensitivity_intervals.csv'));

save(fullfile(scratchRoot, 'min_peak_distance_temporal_sensitivity_workspace.mat'), ...
    'summaryTable', 'secondaryTable', 'intervalTable', ...
    'relativeTimeEdges', 'intervalEdges', 'minPeakDistanceSecondsList', '-v7.3');

LF_makeSensitivityFigure(summaryTable, secondaryTable, intervalTable, relativeTimeEdges, intervalEdges, outputRoot);
LF_appendSensitivityReport(scratchRoot, outputRoot, tableRoot, summaryTable);

fprintf('Min-peak-distance sensitivity complete.\n');

function fileContext = LF_buildFileContext(fileName, magnitudeRoot, settings)
magnitudePath = fullfile(magnitudeRoot, fileName);
loadedMagnitude = load(magnitudePath, 'motionData');
motionData = loadedMagnitude.motionData;
samplingFrequency = motionData.meta.sampleRateHz;

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
fileContext.eventSignal = eventOutput.noiseEstimate.eventSignal(:);
fileContext.noiseSigma = eventOutput.noiseEstimate.noiseSigma(:);
fileContext.eventTable = eventOutput.eventTable;
end

function fileInfo = LF_parseWasedaFileName(fileName)
tokens = regexp(fileName, '^\d+_(sub\d+)_(.+)_acc1_chest_motionEnvelope\.mat$', 'tokens', 'once');
if isempty(tokens)
    error('Could not parse file name: %s', fileName);
end
fileInfo = struct();
fileInfo.subjectID = tokens{1};
fileInfo.condition = tokens{2};
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
    leftPeak = allSubpeaks(lobeStartPosition - 1);
    rightPeak = allSubpeaks(lobeStartPosition);
    if LF_isDeepValley(eventSignal, leftPeak, rightPeak, settings.lobeValleyFraction)
        break;
    end
    lobeStartPosition = lobeStartPosition - 1;
end

lobeEndPosition = anchorPosition;
while lobeEndPosition < numel(allSubpeaks)
    leftPeak = allSubpeaks(lobeEndPosition);
    rightPeak = allSubpeaks(lobeEndPosition + 1);
    if LF_isDeepValley(eventSignal, leftPeak, rightPeak, settings.lobeValleyFraction)
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

function [secondaryRows, intervalRows] = LF_extractTemporalRows(boutTable)
secondaryRows = struct([]);
intervalRows = struct([]);
for boutIndex = 1:height(boutTable)
    relativeTimes = LF_parseNumberList(boutTable.relativeTimesToDominantText(boutIndex));
    secondaryTimes = relativeTimes(relativeTimes ~= 0);
    for timeIndex = 1:numel(secondaryTimes)
        secondaryRows(end + 1, 1).minPeakDistanceSeconds = boutTable.minPeakDistanceSeconds(boutIndex); %#ok<AGROW>
        secondaryRows(end, 1).fileName = boutTable.fileName(boutIndex);
        secondaryRows(end, 1).subjectID = boutTable.subjectID(boutIndex);
        secondaryRows(end, 1).condition = boutTable.condition(boutIndex);
        secondaryRows(end, 1).boutKey = boutTable.boutKey(boutIndex);
        secondaryRows(end, 1).relativeTimeToDominantSec = secondaryTimes(timeIndex);
        secondaryRows(end, 1).absoluteDelaySec = abs(secondaryTimes(timeIndex));
    end
    intervals = diff(sort(relativeTimes));
    for intervalIndex = 1:numel(intervals)
        intervalRows(end + 1, 1).minPeakDistanceSeconds = boutTable.minPeakDistanceSeconds(boutIndex); %#ok<AGROW>
        intervalRows(end, 1).fileName = boutTable.fileName(boutIndex);
        intervalRows(end, 1).subjectID = boutTable.subjectID(boutIndex);
        intervalRows(end, 1).condition = boutTable.condition(boutIndex);
        intervalRows(end, 1).boutKey = boutTable.boutKey(boutIndex);
        intervalRows(end, 1).intervalSec = intervals(intervalIndex);
    end
end
end

function values = LF_parseNumberList(textValue)
if strlength(textValue) == 0
    values = [];
else
    values = str2double(split(string(textValue), ';')).';
end
end

function rows = LF_appendStructRows(rows, newRows)
if isempty(newRows)
    return;
end
if isempty(rows)
    rows = newRows;
else
    rows(end + (1:numel(newRows)), 1) = newRows;
end
end

function snippet = LF_extractSnippet(signal, centerIndex, relativeSamples)
sampleIndices = round(centerIndex) + relativeSamples(:);
if any(sampleIndices < 1) || any(sampleIndices > numel(signal)) || ~isfinite(centerIndex)
    snippet = NaN(numel(relativeSamples), 1);
else
    snippet = signal(sampleIndices);
end
end

function normalizedSnippet = LF_normalizeSnippet(snippet)
normalizedSnippet = snippet(:);
finiteMask = isfinite(normalizedSnippet);
if any(finiteMask)
    normalizedSnippet = normalizedSnippet - median(normalizedSnippet(finiteMask), 'omitnan');
    scaleValue = max(abs(normalizedSnippet(finiteMask)), [], 'omitnan');
    if isfinite(scaleValue) && scaleValue > 0
        normalizedSnippet = normalizedSnippet ./ scaleValue;
    end
end
end

function correlationValue = LF_vectorCorrelation(a, b)
a = a(:);
b = b(:);
finiteMask = isfinite(a) & isfinite(b);
if sum(finiteMask) < 3
    correlationValue = NaN;
else
    correlationValue = corr(a(finiteMask), b(finiteMask));
end
end

function LF_makeSensitivityFigure(summaryTable, secondaryTable, intervalTable, relativeTimeEdges, intervalEdges, outputRoot)
settingValues = unique(summaryTable.minPeakDistanceSeconds);
colors = lines(numel(settingValues));
relativeCenters = relativeTimeEdges(1:end-1) + diff(relativeTimeEdges) ./ 2;
intervalCenters = intervalEdges(1:end-1) + diff(intervalEdges) ./ 2;

figureHandle = figure('Color', 'w', 'Position', [100 80 1450 880]);
t = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Sensitivity of temporal coherence to subpeak MinPeakDistance', ...
    'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Only lower-threshold subpeak spacing is changed; valley fraction remains 0.50.', 'FontSize', 11);

ax = nexttile(t, 1);
hold(ax, 'on');
for settingIndex = 1:numel(settingValues)
    mask = secondaryTable.minPeakDistanceSeconds == settingValues(settingIndex);
    probability = histcounts(secondaryTable.relativeTimeToDominantSec(mask), ...
        relativeTimeEdges, 'Normalization', 'probability');
    plot(ax, relativeCenters, probability, 'LineWidth', 1.7, ...
        'Color', colors(settingIndex, :), ...
        'DisplayName', sprintf('%.2f s', settingValues(settingIndex)));
end
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'secondary subpeak time from dominant (s)');
ylabel(ax, 'probability per 50 ms bin');
title(ax, 'Secondary timing distribution', 'FontWeight', 'normal');
legend(ax, 'Location', 'northeast', 'Box', 'off');

ax = nexttile(t, 2);
hold(ax, 'on');
for settingIndex = 1:numel(settingValues)
    mask = intervalTable.minPeakDistanceSeconds == settingValues(settingIndex);
    probability = histcounts(intervalTable.intervalSec(mask), ...
        intervalEdges, 'Normalization', 'probability');
    plot(ax, intervalCenters, probability, 'LineWidth', 1.7, ...
        'Color', colors(settingIndex, :), ...
        'DisplayName', sprintf('%.2f s', settingValues(settingIndex)));
end
grid(ax, 'on');
xlabel(ax, 'adjacent inter-subpeak interval (s)');
ylabel(ax, 'probability per 50 ms bin');
title(ax, 'Adjacent interval distribution', 'FontWeight', 'normal');

ax = nexttile(t, 3);
plot(ax, summaryTable.minPeakDistanceSeconds, summaryTable.primaryIntervalPeakSec, '-o', ...
    'LineWidth', 1.8, 'DisplayName', 'primary peak');
hold(ax, 'on');
plot(ax, summaryTable.minPeakDistanceSeconds, summaryTable.secondaryIntervalPeakSec, '-o', ...
    'LineWidth', 1.8, 'DisplayName', 'secondary peak 0.9-1.5 s');
grid(ax, 'on');
xlabel(ax, 'MinPeakDistance (s)');
ylabel(ax, 'interval peak location (s)');
title(ax, 'Do interval peaks move?', 'FontWeight', 'normal');
legend(ax, 'Location', 'northwest', 'Box', 'off');

ax = nexttile(t, 4);
plot(ax, summaryTable.minPeakDistanceSeconds, summaryTable.nSecondarySubpeaks, '-o', ...
    'LineWidth', 1.8);
grid(ax, 'on');
xlabel(ax, 'MinPeakDistance (s)');
ylabel(ax, 'non-dominant subpeak count');
title(ax, 'Resolved subpeak count', 'FontWeight', 'normal');

ax = nexttile(t, 5);
plot(ax, summaryTable.minPeakDistanceSeconds, summaryTable.medianIntervalSec, '-o', ...
    'LineWidth', 1.8, 'DisplayName', 'median interval');
hold(ax, 'on');
plot(ax, summaryTable.minPeakDistanceSeconds, summaryTable.medianAbsoluteSecondaryDelaySec, '-o', ...
    'LineWidth', 1.8, 'DisplayName', 'median abs delay');
grid(ax, 'on');
xlabel(ax, 'MinPeakDistance (s)');
ylabel(ax, 'seconds');
title(ax, 'Median timing metrics', 'FontWeight', 'normal');
legend(ax, 'Location', 'northwest', 'Box', 'off');

ax = nexttile(t, 6);
plot(ax, summaryTable.minPeakDistanceSeconds, summaryTable.fractionIntervalsBelow300ms, '-o', ...
    'LineWidth', 1.8, 'DisplayName', '<300 ms');
hold(ax, 'on');
plot(ax, summaryTable.minPeakDistanceSeconds, summaryTable.fractionIntervalsBelow500ms, '-o', ...
    'LineWidth', 1.8, 'DisplayName', '<500 ms');
plot(ax, summaryTable.minPeakDistanceSeconds, summaryTable.fractionIntervalsBelow700ms, '-o', ...
    'LineWidth', 1.8, 'DisplayName', '<700 ms');
grid(ax, 'on');
xlabel(ax, 'MinPeakDistance (s)');
ylabel(ax, 'fraction of intervals');
title(ax, 'Short-interval fractions', 'FontWeight', 'normal');
legend(ax, 'Location', 'northeast', 'Box', 'off');

exportgraphics(figureHandle, fullfile(outputRoot, 'min_peak_distance_temporal_sensitivity.png'), ...
    'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'min_peak_distance_temporal_sensitivity.fig'));
close(figureHandle);
end

function LF_appendSensitivityReport(scratchRoot, outputRoot, tableRoot, summaryTable)
reportPath = fullfile(scratchRoot, 'UNITARY_EVENT_VALIDATION_REPORT.md');
fid = fopen(reportPath, 'a');
cleanupObject = onCleanup(@() fclose(fid));

fprintf(fid, '\n## MinPeakDistance Sensitivity Of Temporal Coherence\n\n');
fprintf(fid, 'This focused test changes only the lower-threshold subpeak `MinPeakDistance` parameter and asks whether the temporal-coherence peaks move or disappear. The revised valley split remains fixed at `0.50 * min(adjacent peaks)`.\n\n');
fprintf(fid, '### Settings Tested\n\n');
for rowIndex = 1:height(summaryTable)
    fprintf(fid, '- `%.2f s`\n', summaryTable.minPeakDistanceSeconds(rowIndex));
end
fprintf(fid, '\n### Summary Table\n\n');
fprintf(fid, '| MinPeakDistance | Secondary subpeaks | Median interval | Primary interval peak | Secondary interval peak |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|\n');
for rowIndex = 1:height(summaryTable)
    fprintf(fid, '| %.2f s | %d | %.3f s | %.3f s | %.3f s |\n', ...
        summaryTable.minPeakDistanceSeconds(rowIndex), ...
        summaryTable.nSecondarySubpeaks(rowIndex), ...
        summaryTable.medianIntervalSec(rowIndex), ...
        summaryTable.primaryIntervalPeakSec(rowIndex), ...
        summaryTable.secondaryIntervalPeakSec(rowIndex));
end
fprintf(fid, '\n### Interpretation\n\n');
fprintf(fid, 'If the observed temporal peaks are purely detector artifacts from the `0.35 s` minimum spacing, lowering the spacing to `0.20 s` should strongly shift or erase them. If they reflect stable bout timing, the main peaks should remain near similar lags while the lower spacing mainly adds extra short-interval structure and changes peak amplitudes.\n\n');
fprintf(fid, 'Figure:\n\n');
fprintf(fid, '- `%s`\n\n', fullfile(outputRoot, 'min_peak_distance_temporal_sensitivity.png'));
fprintf(fid, 'Tables:\n\n');
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'min_peak_distance_temporal_sensitivity_summary.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'min_peak_distance_temporal_sensitivity_secondary.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'min_peak_distance_temporal_sensitivity_intervals.csv'));
end
