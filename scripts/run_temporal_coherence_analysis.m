% Analyze temporal coherence of primitive-like subpeaks within compound bouts.
%
% The earlier timing histogram included the anchor event itself, creating an
% expected spike at 0 s. This script deduplicates valley-delimited bouts,
% aligns each bout to its dominant subpeak, and analyzes only non-dominant
% same-bout subpeaks and adjacent inter-subpeak intervals.

clear;
close all;
clc;

set(0, 'DefaultFigureVisible', 'off');

scriptPath = mfilename('fullpath');
repoRoot = fileparts(fileparts(scriptPath));
scratchRoot = fullfile(repoRoot, 'scratch', 'unitary_event_validation_20260508');
outputRoot = fullfile(scratchRoot, 'outputs');
tableRoot = fullfile(scratchRoot, 'tables');
workspacePath = fullfile(scratchRoot, 'valley_lobe_compound_decomposition_workspace.mat');
magnitudeRoot = '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED/MAGNITUDES';

loadedWorkspace = load(workspacePath, 'anchorTable', 'subelementTable', 'settings');
anchorTable = loadedWorkspace.anchorTable;
subelementTable = loadedWorkspace.subelementTable;
settings = loadedWorkspace.settings;

rng(42);
nNullIterations = 500;
relativeTimeEdges = -2.0:0.05:4.5;
intervalEdges = 0:0.05:3.5;

samplingFrequencyByFile = LF_getSamplingFrequencyByFile(subelementTable, magnitudeRoot);
boutTable = LF_buildUniqueBoutTable(anchorTable, subelementTable, samplingFrequencyByFile);
secondaryTable = LF_buildSecondarySubpeakTable(boutTable);
intervalTable = LF_buildIntervalTable(boutTable);
[relativeNull, intervalNull] = LF_buildTemporalNulls(boutTable, nNullIterations, ...
    relativeTimeEdges, intervalEdges);
summaryTable = LF_buildTemporalSummaryTable(boutTable, secondaryTable, intervalTable, ...
    relativeNull, intervalNull, relativeTimeEdges, intervalEdges);

writetable(boutTable, fullfile(tableRoot, 'temporal_coherence_bouts.csv'));
writetable(secondaryTable, fullfile(tableRoot, 'temporal_coherence_secondary_subpeaks.csv'));
writetable(intervalTable, fullfile(tableRoot, 'temporal_coherence_intervals.csv'));
writetable(summaryTable, fullfile(tableRoot, 'temporal_coherence_summary.csv'));

save(fullfile(scratchRoot, 'temporal_coherence_workspace.mat'), ...
    'settings', 'boutTable', 'secondaryTable', 'intervalTable', 'summaryTable', ...
    'relativeNull', 'intervalNull', 'relativeTimeEdges', 'intervalEdges', '-v7.3');

LF_makeTemporalCoherenceFigure(boutTable, secondaryTable, intervalTable, ...
    relativeNull, intervalNull, relativeTimeEdges, intervalEdges, outputRoot);
LF_appendTemporalReport(scratchRoot, outputRoot, tableRoot, summaryTable);

fprintf('Temporal coherence analysis complete.\n');

function samplingFrequencyByFile = LF_getSamplingFrequencyByFile(subelementTable, magnitudeRoot)
fileNames = unique(string(subelementTable.fileName));
samplingFrequencyByFile = containers.Map('KeyType', 'char', 'ValueType', 'double');
for fileIndex = 1:numel(fileNames)
    magnitudePath = fullfile(magnitudeRoot, char(fileNames(fileIndex)));
    loadedMagnitude = load(magnitudePath, 'motionData');
    samplingFrequency = loadedMagnitude.motionData.meta.sampleRateHz;
    if ~isfinite(samplingFrequency) || samplingFrequency <= 0
        error('Could not read sampling frequency for %s.', fileNames(fileIndex));
    end
    samplingFrequencyByFile(char(fileNames(fileIndex))) = samplingFrequency;
end
end

function boutTable = LF_buildUniqueBoutTable(anchorTable, subelementTable, samplingFrequencyByFile)
rowStruct = struct([]);
seenKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for anchorIndex = 1:height(anchorTable)
    anchorRow = anchorTable(anchorIndex, :);
    subRows = subelementTable(string(subelementTable.fileName) == string(anchorRow.fileName) & ...
        subelementTable.anchorPeakIndex == anchorRow.anchorPeakIndex, :);
    if height(subRows) < 1
        continue;
    end

    [subpeakIndices, order] = sort(subRows.subpeakIndex);
    subRows = subRows(order, :);
    boutKey = sprintf('%s|%s', char(anchorRow.fileName), sprintf('%d_', subpeakIndices));
    if isKey(seenKeys, boutKey)
        continue;
    end
    seenKeys(boutKey) = true;

    samplingFrequency = samplingFrequencyByFile(char(anchorRow.fileName));
    [dominantValue, dominantLocalIndex] = max(subRows.subpeakValue);
    dominantPeakIndex = subRows.subpeakIndex(dominantLocalIndex);
    relativeTimesToDominant = (subpeakIndices - dominantPeakIndex) ./ samplingFrequency;
    templateLikeCount = sum(subRows.isTemplateLike);

    boundaryShiftSec = (anchorRow.anchorPeakIndex - dominantPeakIndex) ./ samplingFrequency;
    leftBoundaryToDominantSec = anchorRow.leftLobeBoundarySec + boundaryShiftSec;
    rightBoundaryToDominantSec = anchorRow.rightLobeBoundarySec + boundaryShiftSec;
    boutDurationSec = rightBoundaryToDominantSec - leftBoundaryToDominantSec;
    activeLeftToDominantSec = min(relativeTimesToDominant, [], 'omitnan');
    activeRightToDominantSec = max(relativeTimesToDominant, [], 'omitnan');
    activeSubpeakSpanSec = activeRightToDominantSec - activeLeftToDominantSec;

    rowStruct(end + 1, 1).fileName = anchorRow.fileName; %#ok<AGROW>
    rowStruct(end, 1).subjectID = anchorRow.subjectID;
    rowStruct(end, 1).condition = anchorRow.condition;
    rowStruct(end, 1).boutKey = string(boutKey);
    rowStruct(end, 1).anchorPeakIndex = anchorRow.anchorPeakIndex;
    rowStruct(end, 1).dominantPeakIndex = dominantPeakIndex;
    rowStruct(end, 1).dominantPeakValue = dominantValue;
    rowStruct(end, 1).nSubpeaks = height(subRows);
    rowStruct(end, 1).nSecondarySubpeaks = max(0, height(subRows) - 1);
    rowStruct(end, 1).nTemplateLikeSubpeaks = templateLikeCount;
    rowStruct(end, 1).nTemplateLikeSecondarySubpeaks = ...
        sum(subRows.isTemplateLike & subRows.subpeakIndex ~= dominantPeakIndex);
    rowStruct(end, 1).leftBoundaryToDominantSec = leftBoundaryToDominantSec;
    rowStruct(end, 1).rightBoundaryToDominantSec = rightBoundaryToDominantSec;
    rowStruct(end, 1).boutDurationSec = boutDurationSec;
    rowStruct(end, 1).activeLeftToDominantSec = activeLeftToDominantSec;
    rowStruct(end, 1).activeRightToDominantSec = activeRightToDominantSec;
    rowStruct(end, 1).activeSubpeakSpanSec = activeSubpeakSpanSec;
    rowStruct(end, 1).subpeakIndicesText = string(strjoin(cellstr(string(subpeakIndices(:).')), ';'));
    rowStruct(end, 1).relativeTimesToDominantText = ...
        string(strjoin(cellstr(string(round(relativeTimesToDominant(:).', 4))), ';'));
end

boutTable = struct2table(rowStruct);
end

function secondaryTable = LF_buildSecondarySubpeakTable(boutTable)
rowStruct = struct([]);
for boutIndex = 1:height(boutTable)
    subpeakIndices = LF_parseNumberList(boutTable.subpeakIndicesText(boutIndex));
    relativeTimes = LF_parseNumberList(boutTable.relativeTimesToDominantText(boutIndex));
    secondaryMask = subpeakIndices ~= boutTable.dominantPeakIndex(boutIndex);
    for subIndex = find(secondaryMask(:).')
        rowStruct(end + 1, 1).fileName = boutTable.fileName(boutIndex); %#ok<AGROW>
        rowStruct(end, 1).subjectID = boutTable.subjectID(boutIndex);
        rowStruct(end, 1).condition = boutTable.condition(boutIndex);
        rowStruct(end, 1).boutKey = boutTable.boutKey(boutIndex);
        rowStruct(end, 1).dominantPeakIndex = boutTable.dominantPeakIndex(boutIndex);
        rowStruct(end, 1).subpeakIndex = subpeakIndices(subIndex);
        rowStruct(end, 1).relativeTimeToDominantSec = relativeTimes(subIndex);
        rowStruct(end, 1).absoluteDelaySec = abs(relativeTimes(subIndex));
        rowStruct(end, 1).isBeforeDominant = relativeTimes(subIndex) < 0;
        rowStruct(end, 1).isAfterDominant = relativeTimes(subIndex) > 0;
    end
end
secondaryTable = struct2table(rowStruct);
end

function intervalTable = LF_buildIntervalTable(boutTable)
rowStruct = struct([]);
for boutIndex = 1:height(boutTable)
    relativeTimes = sort(LF_parseNumberList(boutTable.relativeTimesToDominantText(boutIndex)));
    intervals = diff(relativeTimes);
    for intervalIndex = 1:numel(intervals)
        rowStruct(end + 1, 1).fileName = boutTable.fileName(boutIndex); %#ok<AGROW>
        rowStruct(end, 1).subjectID = boutTable.subjectID(boutIndex);
        rowStruct(end, 1).condition = boutTable.condition(boutIndex);
        rowStruct(end, 1).boutKey = boutTable.boutKey(boutIndex);
        rowStruct(end, 1).intervalSec = intervals(intervalIndex);
        rowStruct(end, 1).intervalOrder = intervalIndex;
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

function [relativeNull, intervalNull] = LF_buildTemporalNulls(boutTable, nNullIterations, relativeTimeEdges, intervalEdges)
relativeNull = NaN(nNullIterations, numel(relativeTimeEdges) - 1);
intervalNull = NaN(nNullIterations, numel(intervalEdges) - 1);

for iteration = 1:nNullIterations
    nullRelativeTimes = [];
    nullIntervals = [];
    for boutIndex = 1:height(boutTable)
        nSubpeaks = boutTable.nSubpeaks(boutIndex);
        if nSubpeaks < 2
            continue;
        end
        leftBoundary = boutTable.activeLeftToDominantSec(boutIndex);
        rightBoundary = boutTable.activeRightToDominantSec(boutIndex);
        if ~isfinite(leftBoundary) || ~isfinite(rightBoundary) || leftBoundary == rightBoundary
            halfSpan = max(0.5, 0.5 .* boutTable.activeSubpeakSpanSec(boutIndex));
            leftBoundary = -halfSpan;
            rightBoundary = halfSpan;
        end
        nullSubpeaks = [0; leftBoundary + (rightBoundary - leftBoundary) .* rand(nSubpeaks - 1, 1)];
        nullSubpeaks = sort(nullSubpeaks);
        nullRelativeTimes = [nullRelativeTimes; nullSubpeaks(nullSubpeaks ~= 0)]; %#ok<AGROW>
        nullIntervals = [nullIntervals; diff(nullSubpeaks)]; %#ok<AGROW>
    end
    relativeNull(iteration, :) = histcounts(nullRelativeTimes, relativeTimeEdges, ...
        'Normalization', 'probability');
    intervalNull(iteration, :) = histcounts(nullIntervals, intervalEdges, ...
        'Normalization', 'probability');
end
end

function summaryTable = LF_buildTemporalSummaryTable(boutTable, secondaryTable, intervalTable, ...
    relativeNull, intervalNull, relativeTimeEdges, intervalEdges)
observedRelativeProbability = histcounts(secondaryTable.relativeTimeToDominantSec, ...
    relativeTimeEdges, 'Normalization', 'probability');
observedIntervalProbability = histcounts(intervalTable.intervalSec, ...
    intervalEdges, 'Normalization', 'probability');
nullRelativeMean = mean(relativeNull, 1, 'omitnan');
nullIntervalMean = mean(intervalNull, 1, 'omitnan');

summary = struct();
summary.nUniqueBouts = height(boutTable);
summary.nMultiSubpeakBouts = sum(boutTable.nSubpeaks >= 2);
summary.nTemplateDecomposableBouts = sum(boutTable.nTemplateLikeSubpeaks >= 2);
summary.nSecondarySubpeaks = height(secondaryTable);
summary.nIntervals = height(intervalTable);
summary.medianBoutSubpeaks = median(boutTable.nSubpeaks, 'omitnan');
summary.medianBoutDurationSec = median(boutTable.boutDurationSec, 'omitnan');
summary.medianActiveSubpeakSpanSec = median(boutTable.activeSubpeakSpanSec, 'omitnan');
summary.medianSecondaryDelaySec = median(secondaryTable.relativeTimeToDominantSec, 'omitnan');
summary.medianAbsoluteSecondaryDelaySec = median(secondaryTable.absoluteDelaySec, 'omitnan');
summary.fractionSecondaryBeforeDominant = mean(secondaryTable.isBeforeDominant, 'omitnan');
summary.fractionSecondaryAfterDominant = mean(secondaryTable.isAfterDominant, 'omitnan');
summary.medianInterSubpeakIntervalSec = median(intervalTable.intervalSec, 'omitnan');
summary.fractionIntervalsBelow500ms = mean(intervalTable.intervalSec < 0.5, 'omitnan');
summary.fractionIntervalsBelow700ms = mean(intervalTable.intervalSec < 0.7, 'omitnan');
summary.fractionIntervalsBelow1000ms = mean(intervalTable.intervalSec < 1.0, 'omitnan');
summary.relativeTimingKLDivergenceBits = LF_klBits(observedRelativeProbability, nullRelativeMean);
summary.intervalKLDivergenceBits = LF_klBits(observedIntervalProbability, nullIntervalMean);
summary.maxRelativeTimingExcessProbability = max(observedRelativeProbability - nullRelativeMean, [], 'omitnan');
summary.maxIntervalExcessProbability = max(observedIntervalProbability - nullIntervalMean, [], 'omitnan');

summaryTable = struct2table(summary);
end

function klValue = LF_klBits(observedProbability, nullProbability)
epsilonValue = 1e-12;
observedProbability = observedProbability + epsilonValue;
nullProbability = nullProbability + epsilonValue;
observedProbability = observedProbability ./ sum(observedProbability);
nullProbability = nullProbability ./ sum(nullProbability);
klValue = sum(observedProbability .* log2(observedProbability ./ nullProbability), 'omitnan');
end

function LF_makeTemporalCoherenceFigure(boutTable, secondaryTable, intervalTable, ...
    relativeNull, intervalNull, relativeTimeEdges, intervalEdges, outputRoot)
relativeCenters = relativeTimeEdges(1:end-1) + diff(relativeTimeEdges) ./ 2;
intervalCenters = intervalEdges(1:end-1) + diff(intervalEdges) ./ 2;

observedRelativeCounts = histcounts(secondaryTable.relativeTimeToDominantSec, relativeTimeEdges);
observedRelativeProbability = histcounts(secondaryTable.relativeTimeToDominantSec, ...
    relativeTimeEdges, 'Normalization', 'probability');
nullRelativeMean = mean(relativeNull, 1, 'omitnan');
nullRelativeLow = prctile(relativeNull, 2.5, 1);
nullRelativeHigh = prctile(relativeNull, 97.5, 1);

observedIntervalCounts = histcounts(intervalTable.intervalSec, intervalEdges);
observedIntervalProbability = histcounts(intervalTable.intervalSec, ...
    intervalEdges, 'Normalization', 'probability');
nullIntervalMean = mean(intervalNull, 1, 'omitnan');
nullIntervalLow = prctile(intervalNull, 2.5, 1);
nullIntervalHigh = prctile(intervalNull, 97.5, 1);

figureHandle = figure('Color', 'w', 'Position', [100 70 1450 900]);
t = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Temporal coherence of same-bout subpeaks', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Bouts are deduplicated and aligned to the dominant subpeak; non-dominant subpeaks test temporal structure.', ...
    'FontSize', 11);

ax = nexttile(t, 1);
histogram(ax, boutTable.nSubpeaks, 'BinEdges', 0.5:1:(max(boutTable.nSubpeaks) + 0.5), ...
    'FaceColor', [0.10 0.40 0.70], 'EdgeColor', 'w');
grid(ax, 'on');
xlabel(ax, 'subpeaks per unique bout');
ylabel(ax, 'bout count');
title(ax, 'Bout multiplicity', 'FontWeight', 'normal');

ax = nexttile(t, 2);
histogram(ax, boutTable.activeSubpeakSpanSec, 'BinEdges', 0:0.10:6, ...
    'FaceColor', [0.25 0.55 0.45], 'EdgeColor', 'none');
grid(ax, 'on');
xlabel(ax, 'active subpeak span (s)');
ylabel(ax, 'bout count');
title(ax, 'Active subpeak span', 'FontWeight', 'normal');

ax = nexttile(t, 3);
histogram(ax, secondaryTable.relativeTimeToDominantSec, 'BinEdges', relativeTimeEdges, ...
    'FaceColor', [0.75 0.35 0.10], 'EdgeColor', 'none');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'secondary subpeak time from dominant (s)');
ylabel(ax, 'secondary subpeak count');
title(ax, 'Non-dominant subpeak timing', 'FontWeight', 'normal');

ax = nexttile(t, 4);
hold(ax, 'on');
LF_plotNullBand(ax, relativeCenters, nullRelativeLow, nullRelativeHigh, [0.70 0.70 0.70]);
plot(ax, relativeCenters, nullRelativeMean, 'Color', [0.35 0.35 0.35], ...
    'LineWidth', 1.5, 'DisplayName', 'uniform-within-bout null');
plot(ax, relativeCenters, observedRelativeProbability, 'Color', [0.75 0.25 0.10], ...
    'LineWidth', 2.0, 'DisplayName', 'observed');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'secondary subpeak time from dominant (s)');
ylabel(ax, 'probability per 50 ms bin');
title(ax, 'Timing vs null', 'FontWeight', 'normal');
legend(ax, 'Location', 'northeast', 'Box', 'off');

ax = nexttile(t, 5);
histogram(ax, intervalTable.intervalSec, 'BinEdges', intervalEdges, ...
    'FaceColor', [0.20 0.45 0.75], 'EdgeColor', 'none');
grid(ax, 'on');
xlabel(ax, 'adjacent inter-subpeak interval (s)');
ylabel(ax, 'interval count');
title(ax, 'Adjacent intervals', 'FontWeight', 'normal');

ax = nexttile(t, 6);
hold(ax, 'on');
LF_plotNullBand(ax, intervalCenters, nullIntervalLow, nullIntervalHigh, [0.70 0.70 0.70]);
plot(ax, intervalCenters, nullIntervalMean, 'Color', [0.35 0.35 0.35], ...
    'LineWidth', 1.5, 'DisplayName', 'uniform-within-bout null');
plot(ax, intervalCenters, observedIntervalProbability, 'Color', [0.20 0.45 0.75], ...
    'LineWidth', 2.0, 'DisplayName', 'observed');
grid(ax, 'on');
xlabel(ax, 'adjacent inter-subpeak interval (s)');
ylabel(ax, 'probability per 50 ms bin');
title(ax, 'Intervals vs null', 'FontWeight', 'normal');
legend(ax, 'Location', 'northeast', 'Box', 'off');

exportgraphics(figureHandle, fullfile(outputRoot, 'temporal_coherence_subpeak_timing.png'), ...
    'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'temporal_coherence_subpeak_timing.fig'));
close(figureHandle);

figureHandle = figure('Color', 'w', 'Position', [120 90 1300 760]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Temporal coherence excess over uniform-within-bout null', ...
    'FontSize', 16, 'FontWeight', 'bold');

ax = nexttile(t, 1);
bar(ax, relativeCenters, observedRelativeProbability - nullRelativeMean, 1.0, ...
    'FaceColor', [0.75 0.35 0.10], 'EdgeColor', 'none');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
yline(ax, 0, '-k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'secondary subpeak time from dominant (s)');
ylabel(ax, 'observed - null probability');
title(ax, 'Relative timing excess', 'FontWeight', 'normal');

ax = nexttile(t, 2);
bar(ax, intervalCenters, observedIntervalProbability - nullIntervalMean, 1.0, ...
    'FaceColor', [0.20 0.45 0.75], 'EdgeColor', 'none');
yline(ax, 0, '-k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'adjacent interval (s)');
ylabel(ax, 'observed - null probability');
title(ax, 'Interval excess', 'FontWeight', 'normal');

ax = nexttile(t, 3);
boxchart(ax, categorical(boutTable.subjectID), boutTable.nSubpeaks);
grid(ax, 'on');
set(ax, 'TickLabelInterpreter', 'none');
xlabel(ax, 'subject');
ylabel(ax, 'subpeaks per bout');
title(ax, 'Bout multiplicity by subject', 'FontWeight', 'normal');

ax = nexttile(t, 4);
boxchart(ax, categorical(boutTable.condition), boutTable.nSubpeaks);
grid(ax, 'on');
set(ax, 'TickLabelInterpreter', 'none');
xlabel(ax, 'condition');
ylabel(ax, 'subpeaks per bout');
title(ax, 'Bout multiplicity by condition', 'FontWeight', 'normal');

exportgraphics(figureHandle, fullfile(outputRoot, 'temporal_coherence_excess_controls.png'), ...
    'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'temporal_coherence_excess_controls.fig'));
close(figureHandle);

% The count vectors are intentionally kept in scope for easier debugging if
% the figure is modified.
assignin('base', 'observedRelativeCounts', observedRelativeCounts);
assignin('base', 'observedIntervalCounts', observedIntervalCounts);
end

function LF_plotNullBand(ax, xValues, lowValues, highValues, colorValue)
patch(ax, [xValues fliplr(xValues)], [lowValues fliplr(highValues)], colorValue, ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none', 'DisplayName', '95% null band');
end

function LF_appendTemporalReport(scratchRoot, outputRoot, tableRoot, summaryTable)
reportPath = fullfile(scratchRoot, 'UNITARY_EVENT_VALIDATION_REPORT.md');
fid = fopen(reportPath, 'a');
cleanupObject = onCleanup(@() fclose(fid));

fprintf(fid, '\n## Temporal Coherence Of Same-Bout Subelements (Active-Span Null)\n\n');
fprintf(fid, 'This pass tests whether subpeaks inside revised valley-delimited compound bouts are temporally organized. The analysis deduplicates bouts, aligns each bout to its dominant subpeak, and removes the dominant subpeak from the timing histogram. This avoids the artificial zero-lag spike caused by including the anchor itself.\n\n');

fprintf(fid, '### Methods\n\n');
fprintf(fid, '- Use the revised valley-delimited compound-bout output with valley fraction `0.50`.\n');
fprintf(fid, '- Deduplicate physical bouts by file and same-bout subpeak set.\n');
fprintf(fid, '- Align each unique bout to its dominant subpeak, not necessarily the originally detected anchor.\n');
fprintf(fid, '- Analyze non-dominant subpeak timing and adjacent inter-subpeak intervals using `50 ms` bins.\n');
fprintf(fid, '- Compare observed timing to a null model that preserves each bout active subpeak span and number of subpeaks but places secondary subpeaks uniformly within that active span.\n');
fprintf(fid, '- Interpret intervals below the detector minimum spacing cautiously: the subpeak finder used a `0.35 s` minimum distance, so very short intervals are suppressed by construction.\n\n');

fprintf(fid, '### Quantitative Results\n\n');
fprintf(fid, '- Unique valley-delimited bouts: `%d`\n', summaryTable.nUniqueBouts);
fprintf(fid, '- Multi-subpeak bouts: `%d`\n', summaryTable.nMultiSubpeakBouts);
fprintf(fid, '- Template-decomposable bouts: `%d`\n', summaryTable.nTemplateDecomposableBouts);
fprintf(fid, '- Non-dominant same-bout subpeaks analyzed: `%d`\n', summaryTable.nSecondarySubpeaks);
fprintf(fid, '- Adjacent inter-subpeak intervals analyzed: `%d`\n', summaryTable.nIntervals);
fprintf(fid, '- Median subpeaks per bout: `%.2f`\n', summaryTable.medianBoutSubpeaks);
fprintf(fid, '- Median valley-boundary bout duration: `%.3f s`\n', summaryTable.medianBoutDurationSec);
fprintf(fid, '- Median active subpeak span: `%.3f s`\n', summaryTable.medianActiveSubpeakSpanSec);
fprintf(fid, '- Median secondary delay relative to dominant: `%.3f s`\n', summaryTable.medianSecondaryDelaySec);
fprintf(fid, '- Median absolute secondary delay: `%.3f s`\n', summaryTable.medianAbsoluteSecondaryDelaySec);
fprintf(fid, '- Fraction secondary subpeaks before dominant: `%.3f`\n', summaryTable.fractionSecondaryBeforeDominant);
fprintf(fid, '- Fraction secondary subpeaks after dominant: `%.3f`\n', summaryTable.fractionSecondaryAfterDominant);
fprintf(fid, '- Median adjacent inter-subpeak interval: `%.3f s`\n', summaryTable.medianInterSubpeakIntervalSec);
fprintf(fid, '- Fraction intervals below `500 ms`: `%.3f`\n', summaryTable.fractionIntervalsBelow500ms);
fprintf(fid, '- Fraction intervals below `700 ms`: `%.3f`\n', summaryTable.fractionIntervalsBelow700ms);
fprintf(fid, '- Fraction intervals below `1000 ms`: `%.3f`\n', summaryTable.fractionIntervalsBelow1000ms);
fprintf(fid, '- Relative timing KL divergence from uniform-within-bout null: `%.3f bits`\n', summaryTable.relativeTimingKLDivergenceBits);
fprintf(fid, '- Interval KL divergence from uniform-within-bout null: `%.3f bits`\n\n', summaryTable.intervalKLDivergenceBits);

fprintf(fid, '### Figures\n\n');
fprintf(fid, '- `%s`\n', fullfile(outputRoot, 'temporal_coherence_subpeak_timing.png'));
fprintf(fid, '- `%s`\n\n', fullfile(outputRoot, 'temporal_coherence_excess_controls.png'));

fprintf(fid, '### Interpretation\n\n');
fprintf(fid, 'Temporal coherence should be treated as a critical intermediate claim. If secondary subpeaks were arbitrary nearby detections, their times should be close to the uniform-within-bout null after conditioning on bout duration and subpeak count. Structured departures from that null support the idea that compound bouts are organized sequences of primitive-like elements rather than chance clusters of peaks. This analysis is still conditional on the revised bout definition and should be repeated over a valley-threshold sensitivity sweep and hand-marked examples before promoting the strongest wording.\n\n');

fprintf(fid, 'Files added:\n\n');
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'temporal_coherence_bouts.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'temporal_coherence_secondary_subpeaks.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'temporal_coherence_intervals.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'temporal_coherence_summary.csv'));
fprintf(fid, '- `%s`\n', fullfile(outputRoot, 'temporal_coherence_subpeak_timing.png'));
fprintf(fid, '- `%s`\n', fullfile(outputRoot, 'temporal_coherence_excess_controls.png'));
fprintf(fid, '- `%s`\n', fullfile(scratchRoot, 'temporal_coherence_workspace.mat'));
end
