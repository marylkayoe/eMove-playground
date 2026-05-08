% Reanalyze compound decomposition with revised valley-delimited lobes.
%
% This revision uses a stricter split criterion than the first lobe pass.
% The prior rule split adjacent peaks only when the valley dropped below
% 20% of the smaller adjacent peak; that was too permissive for visually
% deep valleys followed by smaller peaks. Here, a valley below 50% of the
% smaller adjacent peak breaks the compound bout.

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
rawRoot = '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED/CONCATENATED';

templateWorkspacePath = fullfile(scratchRoot, 'compound_event_decomposition_workspace.mat');
if ~isfile(templateWorkspacePath)
    error('Missing previous decomposition workspace: %s', templateWorkspacePath);
end

loadedTemplate = load(templateWorkspacePath, 'unitTemplate', 'unitRelativeTimeSec', 'settings');
unitTemplate = loadedTemplate.unitTemplate;
unitRelativeTimeSec = loadedTemplate.unitRelativeTimeSec;

settings = loadedTemplate.settings;
settings.lobeSearchWindowSeconds = [-1.5 4.5];
settings.lobeValleyFraction = 0.50;
settings.nExamplePlots = 8;

magnitudeFiles = dir(fullfile(magnitudeRoot, '*_acc1_chest_motionEnvelope.mat'));
if isempty(magnitudeFiles)
    error('No magnitude files found in %s.', magnitudeRoot);
end

anchorRows = struct([]);
subelementRows = struct([]);
randomRows = struct([]);
exampleRows = struct([]);

fprintf('Running valley-lobe compound decomposition on %d files.\n', numel(magnitudeFiles));

for fileIndex = 1:numel(magnitudeFiles)
    fileName = magnitudeFiles(fileIndex).name;
    fprintf('  [%d/%d] %s\n', fileIndex, numel(magnitudeFiles), fileName);
    fileContext = LF_buildFileContext(fileName, magnitudeRoot, rawRoot, settings);

    unitRelativeSamples = round(unitRelativeTimeSec .* fileContext.samplingFrequency);
    randomCenters = LF_sampleRandomCenters(fileContext.eventSignal, fileContext.eventTable.peakIndex, ...
        fileContext.samplingFrequency, settings, 300);
    randomLinearEnergies = NaN(numel(randomCenters), 1);
    for randomIndex = 1:numel(randomCenters)
        randomSnippet = LF_extractSnippet(fileContext.eventSignal, randomCenters(randomIndex), unitRelativeSamples);
        randomLinearSnippet = LF_extractSnippet(fileContext.linearMagnitude, randomCenters(randomIndex), unitRelativeSamples);
        randomRows(end + 1, 1).fileName = fileContext.fileName; %#ok<SAGROW>
        randomRows(end, 1).subjectID = fileContext.subjectID;
        randomRows(end, 1).condition = fileContext.condition;
        randomRows(end, 1).templateCorrelation = LF_vectorCorrelation(LF_normalizeSnippet(randomSnippet), unitTemplate);
        randomRows(end, 1).linearEnergy = LF_rmsEnergy(randomLinearSnippet);
        randomLinearEnergies(randomIndex) = LF_rmsEnergy(randomLinearSnippet);
    end

    medianRandomLinearEnergy = median(randomLinearEnergies, 'omitnan');
    if ~isfinite(medianRandomLinearEnergy) || medianRandomLinearEnergy <= 0
        medianRandomLinearEnergy = 1;
    end

    for eventIndex = 1:height(fileContext.eventTable)
        anchorPeakIndex = fileContext.eventTable.peakIndex(eventIndex);
        lobeOutput = LF_getAnchorLobeSubpeaks(fileContext, anchorPeakIndex, settings);

        nTemplateLike = 0;
        templateCorrelations = NaN(numel(lobeOutput.lobeSubpeaks), 1);
        supportRatios = NaN(numel(lobeOutput.lobeSubpeaks), 1);

        for subpeakIndex = 1:numel(lobeOutput.lobeSubpeaks)
            subpeakSample = lobeOutput.lobeSubpeaks(subpeakIndex);
            eventSignalSnippet = LF_extractSnippet(fileContext.eventSignal, subpeakSample, unitRelativeSamples);
            linearMagnitudeSnippet = LF_extractSnippet(fileContext.linearMagnitude, subpeakSample, unitRelativeSamples);

            templateCorrelation = LF_vectorCorrelation(LF_normalizeSnippet(eventSignalSnippet), unitTemplate);
            supportRatio = LF_rmsEnergy(linearMagnitudeSnippet) ./ medianRandomLinearEnergy;
            isTemplateLike = templateCorrelation >= settings.templateCorrelationThreshold & ...
                supportRatio >= settings.linearSupportThreshold;

            nTemplateLike = nTemplateLike + double(isTemplateLike);
            templateCorrelations(subpeakIndex) = templateCorrelation;
            supportRatios(subpeakIndex) = supportRatio;

            subelementRows(end + 1, 1).fileName = fileContext.fileName; %#ok<SAGROW>
            subelementRows(end, 1).subjectID = fileContext.subjectID;
            subelementRows(end, 1).condition = fileContext.condition;
            subelementRows(end, 1).anchorPeakIndex = anchorPeakIndex;
            subelementRows(end, 1).subpeakIndex = subpeakSample;
            subelementRows(end, 1).relativeTimeToAnchorSec = ...
                (subpeakSample - anchorPeakIndex) ./ fileContext.samplingFrequency;
            subelementRows(end, 1).subpeakValue = fileContext.eventSignal(subpeakSample);
            subelementRows(end, 1).templateCorrelation = templateCorrelation;
            subelementRows(end, 1).linearSupportRatio = supportRatio;
            subelementRows(end, 1).isTemplateLike = isTemplateLike;
        end

        isCurrentCompound = fileContext.eventTable.isCompoundEvent(eventIndex);
        isLobeCompound = numel(lobeOutput.lobeSubpeaks) >= 2;
        isTemplateDecomposable = nTemplateLike >= 2;

        anchorRows(end + 1, 1).fileName = fileContext.fileName; %#ok<SAGROW>
        anchorRows(end, 1).subjectID = fileContext.subjectID;
        anchorRows(end, 1).condition = fileContext.condition;
        anchorRows(end, 1).anchorPeakIndex = anchorPeakIndex;
        anchorRows(end, 1).anchorPeakTimeSec = fileContext.eventTable.peakTimeSec(eventIndex);
        anchorRows(end, 1).anchorPeakValue = fileContext.eventTable.peakValue(eventIndex);
        anchorRows(end, 1).isCurrentCompoundFlag = isCurrentCompound;
        anchorRows(end, 1).nBroadWindowSubpeaks = numel(lobeOutput.allSubpeaks);
        anchorRows(end, 1).nLobeSubpeaks = numel(lobeOutput.lobeSubpeaks);
        anchorRows(end, 1).nTemplateLikeLobeSubpeaks = nTemplateLike;
        anchorRows(end, 1).medianLobeTemplateCorrelation = median(templateCorrelations, 'omitnan');
        anchorRows(end, 1).medianLobeLinearSupportRatio = median(supportRatios, 'omitnan');
        anchorRows(end, 1).leftLobeBoundarySec = lobeOutput.leftBoundarySec;
        anchorRows(end, 1).rightLobeBoundarySec = lobeOutput.rightBoundarySec;
        anchorRows(end, 1).isValleyLobeCompound = isLobeCompound;
        anchorRows(end, 1).isValleyLobeTemplateDecomposable = isTemplateDecomposable;

        if isCurrentCompound && ~isTemplateDecomposable && isempty(exampleRows)
            exampleRows = LF_addExampleRow(exampleRows, fileContext, anchorPeakIndex);
        elseif isCurrentCompound && isTemplateDecomposable && numel(exampleRows) < settings.nExamplePlots
            exampleRows = LF_addExampleRow(exampleRows, fileContext, anchorPeakIndex);
        end
    end
end

anchorTable = struct2table(anchorRows);
subelementTable = struct2table(subelementRows);
randomTable = struct2table(randomRows);
summaryTable = LF_buildSummaryTable(anchorTable, subelementTable, randomTable);

writetable(anchorTable, fullfile(tableRoot, 'valley_lobe_anchor_decomposition.csv'));
writetable(subelementTable, fullfile(tableRoot, 'valley_lobe_subelements.csv'));
writetable(randomTable, fullfile(tableRoot, 'valley_lobe_random_controls.csv'));
writetable(summaryTable, fullfile(tableRoot, 'valley_lobe_decomposition_metrics.csv'));

save(fullfile(scratchRoot, 'valley_lobe_compound_decomposition_workspace.mat'), ...
    'settings', 'unitTemplate', 'unitRelativeTimeSec', 'anchorTable', ...
    'subelementTable', 'randomTable', 'summaryTable', '-v7.3');

LF_makeValleyLobeSummaryFigure(anchorTable, subelementTable, randomTable, outputRoot, settings);
LF_makeValleyLobeExamplesFigure(anchorTable, subelementTable, outputRoot, magnitudeRoot, settings);
LF_appendReport(scratchRoot, outputRoot, tableRoot, summaryTable);

fprintf('Valley-lobe decomposition complete.\n');

function fileContext = LF_buildFileContext(fileName, magnitudeRoot, rawRoot, settings)
magnitudePath = fullfile(magnitudeRoot, fileName);
rawPath = fullfile(rawRoot, replace(fileName, '_motionEnvelope.mat', '.mat'));
loadedMagnitude = load(magnitudePath, 'motionData');
loadedRaw = load(rawPath, 'accData');
motionData = loadedMagnitude.motionData;
accData = loadedRaw.accData;
samplingFrequency = motionData.meta.sampleRateHz;

imuPrepared = prepareAccelerometerQuaternionData(accData, ...
    'AccelerationUnit', 'auto', ...
    'QuaternionOrder', 'wxyz', ...
    'QuaternionJumpMaxDeg', settings.quaternionJumpMaxDeg, ...
    'MakeQcPlots', false);
imuCorrected = removeGravityFromPreparedImu(imuPrepared, ...
    'UseConjugate', settings.useConjugate, ...
    'MakeQcPlots', false);

existingFigures = findall(0, 'Type', 'figure');
eventOutput = extractEnvelopeEvents( ...
    motionData.motionEnvelope, ...
    samplingFrequency, ...
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
fileContext.linearMagnitude = sqrt(sum(imuCorrected.acc.linear.^2, 2));
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

[subpeakValues, localLocations] = findpeaks(searchSignal, ...
    'MinPeakHeight', lowThreshold, ...
    'MinPeakDistance', minimumDistanceSamples);
allSubpeaks = searchIndices(1) + localLocations - 1;
allSubpeaks = unique([allSubpeaks(:); anchorPeakIndex], 'stable');
allSubpeaks = sort(allSubpeaks(:));
subpeakValues = eventSignal(allSubpeaks);

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

lobeSubpeaks = allSubpeaks(lobeStartPosition:lobeEndPosition);

leftBoundarySec = settings.lobeSearchWindowSeconds(1);
rightBoundarySec = settings.lobeSearchWindowSeconds(2);
if lobeStartPosition > 1
    leftBoundaryIndex = LF_valleyIndexBetween(eventSignal, allSubpeaks(lobeStartPosition - 1), allSubpeaks(lobeStartPosition));
    leftBoundarySec = (leftBoundaryIndex - anchorPeakIndex) ./ samplingFrequency;
end
if lobeEndPosition < numel(allSubpeaks)
    rightBoundaryIndex = LF_valleyIndexBetween(eventSignal, allSubpeaks(lobeEndPosition), allSubpeaks(lobeEndPosition + 1));
    rightBoundarySec = (rightBoundaryIndex - anchorPeakIndex) ./ samplingFrequency;
end

lobeOutput = struct();
lobeOutput.allSubpeaks = allSubpeaks;
lobeOutput.allSubpeakValues = subpeakValues;
lobeOutput.lobeSubpeaks = lobeSubpeaks;
lobeOutput.leftBoundarySec = leftBoundarySec;
lobeOutput.rightBoundarySec = rightBoundarySec;
end

function isDeep = LF_isDeepValley(eventSignal, leftPeak, rightPeak, valleyFraction)
valleyIndex = LF_valleyIndexBetween(eventSignal, leftPeak, rightPeak);
valleyValue = eventSignal(valleyIndex);
thresholdValue = valleyFraction .* min(eventSignal(leftPeak), eventSignal(rightPeak));
isDeep = valleyValue < thresholdValue;
end

function valleyIndex = LF_valleyIndexBetween(eventSignal, leftPeak, rightPeak)
indices = leftPeak:rightPeak;
[~, offset] = min(eventSignal(indices));
valleyIndex = indices(1) + offset - 1;
end

function randomCenters = LF_sampleRandomCenters(eventSignal, detectedPeaks, samplingFrequency, settings, targetCount)
unitSamples = round(settings.unitWindowSeconds .* samplingFrequency);
validStart = 1 - unitSamples(1);
validEnd = numel(eventSignal) - unitSamples(2);
candidateCenters = (validStart:validEnd).';
guardSamples = round(settings.randomGuardSeconds .* samplingFrequency);
keepMask = true(size(candidateCenters));
for peakIndex = 1:numel(detectedPeaks)
    keepMask = keepMask & abs(candidateCenters - detectedPeaks(peakIndex)) > guardSamples;
end
candidateCenters = candidateCenters(keepMask);
if isempty(candidateCenters)
    randomCenters = zeros(0, 1);
else
    candidateCenters = candidateCenters(randperm(numel(candidateCenters)));
    randomCenters = candidateCenters(1:min(targetCount, numel(candidateCenters)));
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

function energyValue = LF_rmsEnergy(snippet)
values = snippet(:);
finiteMask = isfinite(values);
if ~any(finiteMask)
    energyValue = NaN;
else
    values = values(finiteMask) - median(values(finiteMask), 'omitnan');
    energyValue = sqrt(mean(values.^2, 'omitnan'));
end
end

function exampleRows = LF_addExampleRow(exampleRows, fileContext, anchorPeakIndex)
newRow = struct();
newRow.fileName = fileContext.fileName;
newRow.subjectID = fileContext.subjectID;
newRow.condition = fileContext.condition;
newRow.anchorPeakIndex = anchorPeakIndex;
if isempty(exampleRows)
    exampleRows = newRow;
else
    exampleRows(end + 1, 1) = newRow;
end
end

function summaryTable = LF_buildSummaryTable(anchorTable, subelementTable, randomTable)
currentMask = anchorTable.isCurrentCompoundFlag;
summary = struct();
summary.nAnchors = height(anchorTable);
summary.nCurrentCompoundFlagged = sum(currentMask);
summary.nValleyLobeCompoundAllAnchors = sum(anchorTable.isValleyLobeCompound);
summary.nValleyLobeTemplateDecomposableAllAnchors = sum(anchorTable.isValleyLobeTemplateDecomposable);
summary.fractionCurrentCompoundStillLobeCompound = mean(anchorTable.isValleyLobeCompound(currentMask), 'omitnan');
summary.fractionCurrentCompoundTemplateDecomposable = mean(anchorTable.isValleyLobeTemplateDecomposable(currentMask), 'omitnan');
summary.medianLobeSubpeaksCurrentCompound = median(anchorTable.nLobeSubpeaks(currentMask), 'omitnan');
summary.medianTemplateLikeLobeSubpeaksCurrentCompound = median(anchorTable.nTemplateLikeLobeSubpeaks(currentMask), 'omitnan');
summary.medianBroadWindowSubpeaksCurrentCompound = median(anchorTable.nBroadWindowSubpeaks(currentMask), 'omitnan');
summary.medianSubelementTemplateCorrelation = median(subelementTable.templateCorrelation, 'omitnan');
summary.medianRandomTemplateCorrelation = median(randomTable.templateCorrelation, 'omitnan');
summary.medianSubelementLinearSupportRatio = median(subelementTable.linearSupportRatio, 'omitnan');
summaryTable = struct2table(summary);
end

function LF_makeValleyLobeSummaryFigure(anchorTable, subelementTable, randomTable, outputRoot, settings)
figureHandle = figure('Color', 'w', 'Position', [100 80 1350 780]);
t = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Revised valley-delimited compound-bout decomposition', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, sprintf('Deep valley split: valley < %.0f%% of the smaller adjacent subpeak.', ...
    100 .* settings.lobeValleyFraction), 'FontSize', 11);

currentMask = anchorTable.isCurrentCompoundFlag;
maximumCount = max([anchorTable.nBroadWindowSubpeaks(currentMask); anchorTable.nLobeSubpeaks(currentMask)], [], 'omitnan');
integerEdges = 0.5:1:(maximumCount + 0.5);
if numel(integerEdges) < 2
    integerEdges = 0.5:1:3.5;
end

ax = nexttile(t, 1);
histogram(ax, anchorTable.nBroadWindowSubpeaks(currentMask), 'BinEdges', integerEdges, ...
    'FaceColor', [0.55 0.55 0.55], 'EdgeColor', 'none', 'DisplayName', 'broad window');
hold(ax, 'on');
histogram(ax, anchorTable.nLobeSubpeaks(currentMask), 'BinEdges', integerEdges, ...
    'FaceColor', [0.10 0.40 0.70], 'FaceAlpha', 0.55, 'EdgeColor', 'none', 'DisplayName', 'valley lobe');
grid(ax, 'on');
xlabel(ax, 'subpeaks per current-compound anchor');
ylabel(ax, 'anchor count');
title(ax, 'Broad window vs same lobe', 'FontWeight', 'normal');
legend(ax, 'Location', 'northeast', 'Box', 'off');

ax = nexttile(t, 2);
templateLikeMaximum = max(anchorTable.nTemplateLikeLobeSubpeaks(currentMask), [], 'omitnan');
templateLikeEdges = 0.5:1:(templateLikeMaximum + 0.5);
if numel(templateLikeEdges) < 2
    templateLikeEdges = 0.5:1:3.5;
end
histogram(ax, anchorTable.nTemplateLikeLobeSubpeaks(currentMask), 'BinEdges', templateLikeEdges, ...
    'FaceColor', [0.75 0.25 0.15], 'EdgeColor', 'none');
xline(ax, 2, '--k');
grid(ax, 'on');
xlabel(ax, 'template-like subpeaks in anchor lobe');
ylabel(ax, 'anchor count');
title(ax, 'Lobe-restricted decomposition', 'FontWeight', 'normal');

ax = nexttile(t, 3);
bar(ax, categorical({'current compound', 'same-lobe compound', 'template decomposable'}), ...
    [sum(currentMask), sum(anchorTable.isValleyLobeCompound & currentMask), ...
    sum(anchorTable.isValleyLobeTemplateDecomposable & currentMask)]);
grid(ax, 'on');
ylabel(ax, 'anchor count');
title(ax, 'Current flag after lobe restriction', 'FontWeight', 'normal');

ax = nexttile(t, 4);
hold(ax, 'on');
LF_plotCdf(ax, subelementTable.templateCorrelation, [0.70 0.25 0.15], 'lobe subelements');
LF_plotCdf(ax, randomTable.templateCorrelation, [0.25 0.25 0.25], 'random windows');
grid(ax, 'on');
xlim(ax, [-1 1]);
xlabel(ax, 'template correlation');
ylabel(ax, 'CDF');
title(ax, 'Template correlation', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast', 'Box', 'off');

ax = nexttile(t, 5);
scatter(ax, subelementTable.templateCorrelation, subelementTable.linearSupportRatio, ...
    12, 'filled', 'MarkerFaceAlpha', 0.25);
xline(ax, 0.4, '--k');
yline(ax, 1, '--k');
grid(ax, 'on');
xlabel(ax, 'template correlation');
ylabel(ax, 'linear support ratio');
title(ax, 'Shape vs raw-motion support', 'FontWeight', 'normal');

ax = nexttile(t, 6);
boxchart(ax, categorical(anchorTable.subjectID(currentMask)), ...
    anchorTable.nTemplateLikeLobeSubpeaks(currentMask));
yline(ax, 2, '--k');
grid(ax, 'on');
xlabel(ax, 'subject');
ylabel(ax, 'template-like lobe subpeaks');
title(ax, 'Lobe decomposition by subject', 'FontWeight', 'normal');

exportgraphics(figureHandle, fullfile(outputRoot, 'valley_lobe_decomposition_diagnostics.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'valley_lobe_decomposition_diagnostics.fig'));
close(figureHandle);
end

function LF_plotCdf(ax, values, colorValue, displayName)
values = values(isfinite(values));
if isempty(values)
    return;
end
values = sort(values(:));
yValues = (1:numel(values)) ./ numel(values);
plot(ax, values, yValues, 'Color', colorValue, 'LineWidth', 2.0, 'DisplayName', displayName);
end

function LF_makeValleyLobeExamplesFigure(anchorTable, subelementTable, outputRoot, magnitudeRoot, settings)
currentTable = anchorTable(anchorTable.isCurrentCompoundFlag, :);
currentTable = sortrows(currentTable, 'nBroadWindowSubpeaks', 'descend');
nExamples = min(settings.nExamplePlots, height(currentTable));
if nExamples == 0
    return;
end

contextCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
figureHandle = figure('Color', 'w', 'Position', [80 80 1500 980]);
t = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Revised valley-lobe decomposition examples', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Green span is the anchor bout. Orange points are same-bout subpeaks; gray points are nearby subpeaks split off by revised valleys.', 'FontSize', 11);

for exampleIndex = 1:nExamples
    row = currentTable(exampleIndex, :);
    fileName = char(row.fileName);
    if isKey(contextCache, fileName)
        fileContext = contextCache(fileName);
    else
        fileContext = LF_buildPlotContext(fileName, magnitudeRoot, settings);
        contextCache(fileName) = fileContext;
    end
    ax = nexttile(t, exampleIndex);
    LF_plotValleyLobeExample(ax, fileContext, row, subelementTable, settings);
end

exportgraphics(figureHandle, fullfile(outputRoot, 'valley_lobe_decomposition_examples.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'valley_lobe_decomposition_examples.fig'));
close(figureHandle);
end

function fileContext = LF_buildPlotContext(fileName, magnitudeRoot, settings)
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
fileContext = struct();
fileContext.fileName = string(fileName);
fileContext.samplingFrequency = samplingFrequency;
fileContext.eventSignal = eventOutput.noiseEstimate.eventSignal(:);
fileContext.noiseSigma = eventOutput.noiseEstimate.noiseSigma(:);
fileContext.eventTable = eventOutput.eventTable;
end

function LF_plotValleyLobeExample(ax, fileContext, row, subelementTable, settings)
anchorPeakIndex = row.anchorPeakIndex;
samplingFrequency = fileContext.samplingFrequency;
eventSignal = fileContext.eventSignal;
lobeOutput = LF_getAnchorLobeSubpeaks(fileContext, anchorPeakIndex, settings);
plotSamples = round(settings.lobeSearchWindowSeconds .* samplingFrequency);
plotIndices = (anchorPeakIndex + plotSamples(1)):(anchorPeakIndex + plotSamples(2));
plotIndices = plotIndices(plotIndices >= 1 & plotIndices <= numel(eventSignal));
relativeTimeSec = (plotIndices - anchorPeakIndex) ./ samplingFrequency;

plot(ax, relativeTimeSec, eventSignal(plotIndices), ...
    'Color', [0.05 0.30 0.65], 'LineWidth', 1.6);
hold(ax, 'on');
yl = [0, max(eventSignal(plotIndices), [], 'omitnan') .* 1.12];
if yl(2) <= 0 || ~isfinite(yl(2))
    yl = [0 1];
end
ylim(ax, yl);
patch(ax, [row.leftLobeBoundarySec row.rightLobeBoundarySec row.rightLobeBoundarySec row.leftLobeBoundarySec], ...
    [yl(1) yl(1) yl(2) yl(2)], [0.30 0.75 0.55], ...
    'FaceAlpha', 0.12, 'EdgeColor', 'none');
plot(ax, relativeTimeSec, eventSignal(plotIndices), ...
    'Color', [0.05 0.30 0.65], 'LineWidth', 1.6);
xline(ax, 0, '--k');
xline(ax, row.leftLobeBoundarySec, ':', 'Color', [0.85 0.05 0.05]);
xline(ax, row.rightLobeBoundarySec, ':', 'Color', [0.85 0.05 0.05]);
plot(ax, 0, eventSignal(anchorPeakIndex), 'kd', 'MarkerFaceColor', 'k', 'MarkerSize', 6);

subRows = subelementTable(string(subelementTable.fileName) == string(row.fileName) & ...
    subelementTable.anchorPeakIndex == anchorPeakIndex, :);
sameBoutMask = ismember(lobeOutput.allSubpeaks, lobeOutput.lobeSubpeaks);
outsideSubpeaks = lobeOutput.allSubpeaks(~sameBoutMask);
for subIndex = 1:numel(outsideSubpeaks)
    relativeSubpeakTimeSec = (outsideSubpeaks(subIndex) - anchorPeakIndex) ./ samplingFrequency;
    plot(ax, relativeSubpeakTimeSec, eventSignal(outsideSubpeaks(subIndex)), ...
        'o', 'MarkerFaceColor', [0.55 0.55 0.55], 'MarkerEdgeColor', [0.55 0.55 0.55], ...
        'MarkerSize', 4);
end
for subIndex = 1:height(subRows)
    markerColor = [0.85 0.35 0.05];
    if ~subRows.isTemplateLike(subIndex)
        markerColor = [0.55 0.55 0.55];
    end
    plot(ax, subRows.relativeTimeToAnchorSec(subIndex), subRows.subpeakValue(subIndex), ...
        'o', 'MarkerFaceColor', markerColor, 'MarkerEdgeColor', markerColor, 'MarkerSize', 5);
end

grid(ax, 'on');
xlabel(ax, 'time from anchor peak (s)');
ylabel(ax, 'eventSignal');
title(ax, sprintf('%s | broad %d, lobe %d, template-like %d', ...
    erase(char(row.condition), '_stand'), row.nBroadWindowSubpeaks, ...
    row.nLobeSubpeaks, row.nTemplateLikeLobeSubpeaks), ...
    'Interpreter', 'none', 'FontWeight', 'normal');
end

function LF_appendReport(scratchRoot, outputRoot, tableRoot, summaryTable)
reportPath = fullfile(scratchRoot, 'UNITARY_EVENT_VALIDATION_REPORT.md');
fid = fopen(reportPath, 'a');
cleanupObject = onCleanup(@() fclose(fid));

fprintf(fid, '\n## Revised Valley-Delimited Compound-Bout Reanalysis\n\n');
fprintf(fid, 'This pass revises the previous valley-lobe definition in response to visual inspection. The previous split rule, `valley < 0.20 * min(adjacent peaks)`, was too permissive for visibly deep valleys followed by smaller peaks. The revised rule splits adjacent subpeaks when the valley drops below `0.50 * min(adjacent peaks)`.\n\n');

fprintf(fid, '### Definition Used Here\n\n');
fprintf(fid, '- Find lower-threshold local maxima around each anchor event.\n');
fprintf(fid, '- For adjacent lower-threshold peaks, compute the minimum between them.\n');
fprintf(fid, '- If the valley is below `0.50 * min(leftPeak, rightPeak)`, it is a deep valley and breaks the compound bout.\n');
fprintf(fid, '- Decompose only the connected compound bout containing the anchor peak.\n');
fprintf(fid, '- Histograms in the revised diagnostic figure use explicit integer bin edges for count variables rather than automatic coarse grouping.\n\n');

fprintf(fid, '### Quantitative Change\n\n');
fprintf(fid, '- Total detected anchors: `%d`\n', summaryTable.nAnchors);
fprintf(fid, '- Old current-compound flagged anchors: `%d`\n', summaryTable.nCurrentCompoundFlagged);
fprintf(fid, '- Current-compound anchors still containing at least two same-lobe subpeaks: `%.3f`\n', summaryTable.fractionCurrentCompoundStillLobeCompound);
fprintf(fid, '- Current-compound anchors with at least two template-like same-lobe subpeaks: `%.3f`\n', summaryTable.fractionCurrentCompoundTemplateDecomposable);
fprintf(fid, '- Median broad-window subpeaks among current-compound anchors: `%.1f`\n', summaryTable.medianBroadWindowSubpeaksCurrentCompound);
fprintf(fid, '- Median same-lobe subpeaks among current-compound anchors: `%.1f`\n', summaryTable.medianLobeSubpeaksCurrentCompound);
fprintf(fid, '- Median template-like same-lobe subpeaks among current-compound anchors: `%.1f`\n', summaryTable.medianTemplateLikeLobeSubpeaksCurrentCompound);
fprintf(fid, '- Median same-lobe subelement template correlation: `%.3f`\n', summaryTable.medianSubelementTemplateCorrelation);
fprintf(fid, '- Random-window median template correlation: `%.3f`\n', summaryTable.medianRandomTemplateCorrelation);
fprintf(fid, '- Median same-lobe subelement linear support ratio: `%.3f`\n\n', summaryTable.medianSubelementLinearSupportRatio);

fprintf(fid, '### Figures\n\n');
fprintf(fid, '- `%s`\n', fullfile(outputRoot, 'valley_lobe_decomposition_diagnostics.png'));
fprintf(fid, '- `%s`\n\n', fullfile(outputRoot, 'valley_lobe_decomposition_examples.png'));

fprintf(fid, '### Interpretation Update\n\n');
fprintf(fid, 'The revised rule better matches the visual criterion that a clear recovery valley separates movement bouts. The current `isCompoundEvent` flag remains a nearby-neighbor/context flag rather than a physiological compound-event definition. The useful compound definition should be valley-delimited and should probably expose the valley fraction as a sensitivity parameter rather than hard-coding a single value.\n');
fprintf(fid, '\nFiles added:\n\n');
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'valley_lobe_anchor_decomposition.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'valley_lobe_subelements.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'valley_lobe_random_controls.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'valley_lobe_decomposition_metrics.csv'));
end
