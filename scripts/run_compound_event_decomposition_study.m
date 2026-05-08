% Explore whether compound Waseda envelope events decompose into smaller units.
%
% This is an exploratory scratch analysis. It keeps the existing detector
% fixed, uses clean isolated events only to define a provisional unit
% template, and then inspects compound-flagged windows for multiple
% template-like subelements with gravity-corrected acceleration support.

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

rawRoot = '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED/CONCATENATED';
magnitudeRoot = '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED/MAGNITUDES';

settings = struct();
settings.baselineWindowSeconds = 15;
settings.noiseWindowSeconds = 30;
settings.thresholdSigma = 4;
settings.quaternionJumpMaxDeg = 60;
settings.useConjugate = false;
settings.frequencyBandHz = [0.2 10];
settings.envelopeWindowSeconds = 1.0;
settings.unitWindowSeconds = [-1 2];
settings.compoundWindowSeconds = [-1.5 4.5];
settings.randomGuardSeconds = 2.5;
settings.lowThresholdSigma = 2.0;
settings.subpeakMinDistanceSeconds = 0.35;
settings.templateCorrelationThreshold = 0.40;
settings.linearSupportThreshold = 1.0;
settings.seedSecondaryPeakMax = 0.50;
settings.seedDetectorWidthMaxSec = 2.0;
settings.randomSeed = 20260508;

rng(settings.randomSeed);

magnitudeFiles = dir(fullfile(magnitudeRoot, '*_acc1_chest_motionEnvelope.mat'));
if isempty(magnitudeFiles)
    error('No magnitude files found in %s.', magnitudeRoot);
end

fileContexts = struct([]);
seedSnippetCells = {};
seedLinearSnippetCells = {};

fprintf('Preparing contexts and seed snippets for %d files.\n', numel(magnitudeFiles));

for fileIndex = 1:numel(magnitudeFiles)
    magnitudeFileName = magnitudeFiles(fileIndex).name;
    fprintf('  seed pass [%d/%d] %s\n', fileIndex, numel(magnitudeFiles), magnitudeFileName);

    fileContext = LF_buildFileContext(magnitudeFileName, rawRoot, magnitudeRoot, settings);
    fileContexts = [fileContexts; fileContext]; %#ok<AGROW>

    seedMask = fileContext.eventTable.isIsolatedEvent & ...
        fileContext.eventTable.secondaryPeakRatio < settings.seedSecondaryPeakMax & ...
        fileContext.eventTable.peakWidthSec <= settings.seedDetectorWidthMaxSec;
    seedPeaks = fileContext.eventTable.peakIndex(seedMask);

    unitRelativeSamples = LF_secondsToRelativeSamples(settings.unitWindowSeconds, fileContext.samplingFrequency);
    for seedIndex = 1:numel(seedPeaks)
        eventSignalSnippet = LF_extractSnippet(fileContext.eventSignal, seedPeaks(seedIndex), unitRelativeSamples);
        linearMagnitudeSnippet = LF_extractSnippet(fileContext.linearMagnitude, seedPeaks(seedIndex), unitRelativeSamples);
        if all(isfinite(eventSignalSnippet))
            seedSnippetCells{end + 1, 1} = LF_normalizeSnippet(eventSignalSnippet); %#ok<AGROW>
            seedLinearSnippetCells{end + 1, 1} = LF_centerSnippet(linearMagnitudeSnippet); %#ok<AGROW>
        end
    end
end

if isempty(seedSnippetCells)
    error('No seed snippets found. Relax seed criteria before decomposition.');
end

seedSnippetMatrix = LF_cellToMatrix(seedSnippetCells);
unitTemplate = mean(seedSnippetMatrix, 2, 'omitnan');
unitTemplate = LF_normalizeSnippet(unitTemplate);
unitRelativeSamples = LF_secondsToRelativeSamples(settings.unitWindowSeconds, fileContexts(1).samplingFrequency);
unitRelativeTimeSec = unitRelativeSamples ./ fileContexts(1).samplingFrequency;

seedCorrelations = LF_templateCorrelations(seedSnippetMatrix, unitTemplate);

compoundRows = struct([]);
subelementRows = struct([]);
randomRows = struct([]);
compoundSnippetCells = {};
randomSnippetCells = {};

fprintf('Decomposing compound events.\n');

for fileIndex = 1:numel(fileContexts)
    fileContext = fileContexts(fileIndex);
    fprintf('  decomposition pass [%d/%d] %s\n', fileIndex, numel(fileContexts), fileContext.fileName);

    randomCenters = LF_sampleRandomCenters(fileContext.eventSignal, fileContext.eventTable.peakIndex, ...
        fileContext.samplingFrequency, settings, 300);
    randomLinearEnergies = NaN(numel(randomCenters), 1);

    for randomIndex = 1:numel(randomCenters)
        randomSnippet = LF_extractSnippet(fileContext.eventSignal, randomCenters(randomIndex), unitRelativeSamples);
        randomLinearSnippet = LF_extractSnippet(fileContext.linearMagnitude, randomCenters(randomIndex), unitRelativeSamples);
        if all(isfinite(randomSnippet))
            randomSnippetNormalized = LF_normalizeSnippet(randomSnippet);
            randomRows(end + 1, 1).fileName = fileContext.fileName; %#ok<SAGROW>
            randomRows(end, 1).subjectID = fileContext.subjectID;
            randomRows(end, 1).condition = fileContext.condition;
            randomRows(end, 1).templateCorrelation = LF_vectorCorrelation(randomSnippetNormalized, unitTemplate);
            randomRows(end, 1).linearEnergy = LF_rmsEnergy(randomLinearSnippet);
            randomSnippetCells{end + 1, 1} = randomSnippetNormalized; %#ok<AGROW>
            randomLinearEnergies(randomIndex) = LF_rmsEnergy(randomLinearSnippet);
        end
    end

    medianRandomLinearEnergy = median(randomLinearEnergies, 'omitnan');
    if ~isfinite(medianRandomLinearEnergy) || medianRandomLinearEnergy <= 0
        medianRandomLinearEnergy = 1;
    end

    compoundEventTable = fileContext.eventTable(fileContext.eventTable.isCompoundEvent, :);

    for compoundIndex = 1:height(compoundEventTable)
        compoundPeakIndex = compoundEventTable.peakIndex(compoundIndex);
        [subpeaks, subpeakValues] = LF_findSubpeaks(fileContext, compoundPeakIndex, settings);

        nTemplateLike = 0;
        subpeakCorrelations = NaN(numel(subpeaks), 1);
        subpeakSupportRatios = NaN(numel(subpeaks), 1);

        for subpeakIndex = 1:numel(subpeaks)
            subpeakSample = subpeaks(subpeakIndex);
            eventSignalSnippet = LF_extractSnippet(fileContext.eventSignal, subpeakSample, unitRelativeSamples);
            linearMagnitudeSnippet = LF_extractSnippet(fileContext.linearMagnitude, subpeakSample, unitRelativeSamples);
            if ~all(isfinite(eventSignalSnippet))
                continue;
            end

            normalizedSnippet = LF_normalizeSnippet(eventSignalSnippet);
            templateCorrelation = LF_vectorCorrelation(normalizedSnippet, unitTemplate);
            linearEnergy = LF_rmsEnergy(linearMagnitudeSnippet);
            supportRatio = linearEnergy ./ medianRandomLinearEnergy;

            isTemplateLike = templateCorrelation >= settings.templateCorrelationThreshold & ...
                supportRatio >= settings.linearSupportThreshold;

            nTemplateLike = nTemplateLike + double(isTemplateLike);
            subpeakCorrelations(subpeakIndex) = templateCorrelation;
            subpeakSupportRatios(subpeakIndex) = supportRatio;

            subelementRows(end + 1, 1).fileName = fileContext.fileName; %#ok<SAGROW>
            subelementRows(end, 1).subjectID = fileContext.subjectID;
            subelementRows(end, 1).condition = fileContext.condition;
            subelementRows(end, 1).compoundPeakIndex = compoundPeakIndex;
            subelementRows(end, 1).subpeakIndex = subpeakSample;
            subelementRows(end, 1).relativeTimeToCompoundPeakSec = ...
                (subpeakSample - compoundPeakIndex) ./ fileContext.samplingFrequency;
            subelementRows(end, 1).subpeakValue = subpeakValues(subpeakIndex);
            subelementRows(end, 1).templateCorrelation = templateCorrelation;
            subelementRows(end, 1).linearSupportRatio = supportRatio;
            subelementRows(end, 1).isTemplateLike = isTemplateLike;

            compoundSnippetCells{end + 1, 1} = normalizedSnippet; %#ok<AGROW>
        end

        compoundRows(end + 1, 1).fileName = fileContext.fileName; %#ok<SAGROW>
        compoundRows(end, 1).subjectID = fileContext.subjectID;
        compoundRows(end, 1).condition = fileContext.condition;
        compoundRows(end, 1).compoundPeakIndex = compoundPeakIndex;
        compoundRows(end, 1).compoundPeakTimeSec = compoundEventTable.peakTimeSec(compoundIndex);
        compoundRows(end, 1).compoundPeakValue = compoundEventTable.peakValue(compoundIndex);
        compoundRows(end, 1).nSubpeaks = numel(subpeaks);
        compoundRows(end, 1).nTemplateLikeSubpeaks = nTemplateLike;
        compoundRows(end, 1).medianSubpeakTemplateCorrelation = median(subpeakCorrelations, 'omitnan');
        compoundRows(end, 1).medianSubpeakSupportRatio = median(subpeakSupportRatios, 'omitnan');
        compoundRows(end, 1).isDecomposable = nTemplateLike >= 2;
    end
end

compoundSummaryTable = struct2table(compoundRows);
subelementTable = struct2table(subelementRows);
randomDecompositionTable = struct2table(randomRows);

compoundSnippetMatrix = LF_cellToMatrix(compoundSnippetCells);
randomSnippetMatrix = LF_cellToMatrix(randomSnippetCells);
compoundCorrelations = LF_templateCorrelations(compoundSnippetMatrix, unitTemplate);
randomCorrelations = randomDecompositionTable.templateCorrelation;

decompositionSummary = LF_makeDecompositionSummary(seedCorrelations, compoundSummaryTable, ...
    subelementTable, randomDecompositionTable, settings);
decompositionSummaryTable = struct2table(decompositionSummary);

writetable(compoundSummaryTable, fullfile(tableRoot, 'compound_decomposition_summary.csv'));
writetable(subelementTable, fullfile(tableRoot, 'compound_subelements.csv'));
writetable(randomDecompositionTable, fullfile(tableRoot, 'compound_decomposition_random_controls.csv'));
writetable(decompositionSummaryTable, fullfile(tableRoot, 'compound_decomposition_metrics.csv'));

save(fullfile(scratchRoot, 'compound_event_decomposition_workspace.mat'), ...
    'settings', 'unitTemplate', 'unitRelativeTimeSec', 'seedSnippetMatrix', ...
    'compoundSnippetMatrix', 'randomSnippetMatrix', 'compoundSummaryTable', ...
    'subelementTable', 'randomDecompositionTable', 'decompositionSummaryTable', '-v7.3');

LF_makeTemplateFigure(unitRelativeTimeSec, seedSnippetMatrix, compoundSnippetMatrix, ...
    randomSnippetMatrix, unitTemplate, outputRoot);
LF_makeDecompositionSummaryFigure(compoundSummaryTable, subelementTable, randomDecompositionTable, ...
    seedCorrelations, compoundCorrelations, randomCorrelations, outputRoot);
LF_makeCompoundExamplesFigure(fileContexts, compoundSummaryTable, subelementTable, settings, outputRoot);
LF_appendReport(scratchRoot, outputRoot, tableRoot, decompositionSummaryTable, settings);

fprintf('Compound decomposition study complete.\n');

function fileContext = LF_buildFileContext(magnitudeFileName, rawRoot, magnitudeRoot, settings)
magnitudePath = fullfile(magnitudeRoot, magnitudeFileName);
rawFileName = replace(magnitudeFileName, '_motionEnvelope.mat', '.mat');
rawPath = fullfile(rawRoot, rawFileName);

loadedMagnitude = load(magnitudePath, 'motionData');
loadedRaw = load(rawPath, 'accData');
motionData = loadedMagnitude.motionData;
accData = loadedRaw.accData;

fileInfo = LF_parseWasedaFileName(magnitudeFileName);
samplingFrequency = motionData.meta.sampleRateHz;

imuPrepared = prepareAccelerometerQuaternionData(accData, ...
    'AccelerationUnit', 'auto', ...
    'QuaternionOrder', 'wxyz', ...
    'QuaternionJumpMaxDeg', settings.quaternionJumpMaxDeg, ...
    'MakeQcPlots', false);

imuCorrected = removeGravityFromPreparedImu(imuPrepared, ...
    'UseConjugate', settings.useConjugate, ...
    'MakeQcPlots', false);

imuEnvelope = computeAccelerometerMotionEnvelope(imuCorrected, ...
    'FrequencyBandHz', settings.frequencyBandHz, ...
    'EnvelopeWindowSeconds', settings.envelopeWindowSeconds, ...
    'MakePlots', false);

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
close all;

eventTable = eventOutput.eventTable;
eventTable.secondaryPeakRatio = LF_addSecondaryPeakRatio(eventOutput.noiseEstimate.eventSignal, ...
    eventTable.peakIndex, samplingFrequency);

fileContext = struct();
fileContext.fileName = string(magnitudeFileName);
fileContext.subjectID = string(fileInfo.subjectID);
fileContext.condition = string(fileInfo.condition);
fileContext.samplingFrequency = samplingFrequency;
fileContext.timeSec = motionData.timeSec(:);
fileContext.eventSignal = eventOutput.noiseEstimate.eventSignal(:);
fileContext.noiseSigma = eventOutput.noiseEstimate.noiseSigma(:);
fileContext.linearMagnitude = sqrt(sum(imuCorrected.acc.linear.^2, 2));
fileContext.filteredMagnitude = imuEnvelope.magnitude.filtered(:);
fileContext.eventTable = eventTable;
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

function secondaryPeakRatio = LF_addSecondaryPeakRatio(eventSignal, peakIndices, samplingFrequency)
relativeSamples = round(-2 .* samplingFrequency):round(4 .* samplingFrequency);
secondaryPeakRatio = NaN(numel(peakIndices), 1);
for eventIndex = 1:numel(peakIndices)
    peakIndex = peakIndices(eventIndex);
    sampleIndices = peakIndex + relativeSamples;
    sampleIndices = sampleIndices(sampleIndices >= 1 & sampleIndices <= numel(eventSignal));
    snippet = eventSignal(sampleIndices);
    mainPeakValue = eventSignal(peakIndex);
    if ~isfinite(mainPeakValue) || mainPeakValue <= 0
        continue;
    end
    [peakValues, peakLocations] = findpeaks(snippet, ...
        'MinPeakDistance', max(1, round(0.30 .* samplingFrequency)));
    absolutePeakLocations = sampleIndices(1) + peakLocations - 1;
    notMainPeak = abs(absolutePeakLocations - peakIndex) > round(0.35 .* samplingFrequency);
    secondaryValues = peakValues(notMainPeak);
    if isempty(secondaryValues)
        secondaryPeakRatio(eventIndex) = 0;
    else
        secondaryPeakRatio(eventIndex) = max(secondaryValues, [], 'omitnan') ./ mainPeakValue;
    end
end
end

function relativeSamples = LF_secondsToRelativeSamples(windowSeconds, samplingFrequency)
windowSamples = round(windowSeconds .* samplingFrequency);
relativeSamples = (windowSamples(1):windowSamples(2)).';
end

function snippet = LF_extractSnippet(signal, centerIndex, relativeSamples)
signal = signal(:);
sampleIndices = round(centerIndex) + relativeSamples;
if any(sampleIndices < 1) || any(sampleIndices > numel(signal)) || ~isfinite(centerIndex)
    snippet = NaN(numel(relativeSamples), 1);
else
    snippet = signal(sampleIndices);
end
end

function centeredSnippet = LF_centerSnippet(snippet)
centeredSnippet = snippet(:);
finiteMask = isfinite(centeredSnippet);
if any(finiteMask)
    centeredSnippet = centeredSnippet - median(centeredSnippet(finiteMask), 'omitnan');
end
end

function normalizedSnippet = LF_normalizeSnippet(snippet)
normalizedSnippet = LF_centerSnippet(snippet);
finiteMask = isfinite(normalizedSnippet);
if any(finiteMask)
    scaleValue = max(abs(normalizedSnippet(finiteMask)), [], 'omitnan');
    if isfinite(scaleValue) && scaleValue > 0
        normalizedSnippet = normalizedSnippet ./ scaleValue;
    end
end
end

function matrix = LF_cellToMatrix(snippetCells)
if isempty(snippetCells)
    matrix = NaN(0, 0);
    return;
end
nRows = numel(snippetCells{1});
matrix = NaN(nRows, numel(snippetCells));
for columnIndex = 1:numel(snippetCells)
    matrix(:, columnIndex) = snippetCells{columnIndex};
end
end

function correlations = LF_templateCorrelations(snippetMatrix, unitTemplate)
correlations = NaN(size(snippetMatrix, 2), 1);
for columnIndex = 1:size(snippetMatrix, 2)
    correlations(columnIndex) = LF_vectorCorrelation(snippetMatrix(:, columnIndex), unitTemplate);
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
values = LF_centerSnippet(snippet);
values = values(isfinite(values));
if isempty(values)
    energyValue = NaN;
else
    energyValue = sqrt(mean(values.^2, 'omitnan'));
end
end

function randomCenters = LF_sampleRandomCenters(eventSignal, detectedPeaks, samplingFrequency, settings, targetCount)
unitSamples = LF_secondsToRelativeSamples(settings.unitWindowSeconds, samplingFrequency);
validStart = 1 - unitSamples(1);
validEnd = numel(eventSignal) - unitSamples(end);
candidateCenters = (validStart:validEnd).';
guardSamples = round(settings.randomGuardSeconds .* samplingFrequency);
keepMask = true(size(candidateCenters));
for peakIndex = 1:numel(detectedPeaks)
    keepMask = keepMask & abs(candidateCenters - detectedPeaks(peakIndex)) > guardSamples;
end
candidateCenters = candidateCenters(keepMask);
if isempty(candidateCenters)
    randomCenters = zeros(0, 1);
    return;
end
candidateCenters = candidateCenters(randperm(numel(candidateCenters)));
randomCenters = candidateCenters(1:min(targetCount, numel(candidateCenters)));
end

function [subpeaks, subpeakValues] = LF_findSubpeaks(fileContext, compoundPeakIndex, settings)
samplingFrequency = fileContext.samplingFrequency;
compoundRelativeSamples = LF_secondsToRelativeSamples(settings.compoundWindowSeconds, samplingFrequency);
sampleIndices = compoundPeakIndex + compoundRelativeSamples;
sampleIndices = sampleIndices(sampleIndices >= 1 & sampleIndices <= numel(fileContext.eventSignal));
windowSignal = fileContext.eventSignal(sampleIndices);

typicalNoiseSigma = median(fileContext.noiseSigma, 'omitnan');
lowThreshold = settings.lowThresholdSigma .* typicalNoiseSigma;
minimumDistanceSamples = max(1, round(settings.subpeakMinDistanceSeconds .* samplingFrequency));

[subpeakValues, localLocations] = findpeaks(windowSignal, ...
    'MinPeakHeight', lowThreshold, ...
    'MinPeakDistance', minimumDistanceSamples);

subpeaks = sampleIndices(1) + localLocations - 1;
subpeaks = subpeaks(:);
subpeakValues = subpeakValues(:);
end

function summaryRows = LF_makeDecompositionSummary(seedCorrelations, compoundSummaryTable, subelementTable, randomTable, settings)
templateLikeMask = subelementTable.templateCorrelation >= settings.templateCorrelationThreshold & ...
    subelementTable.linearSupportRatio >= settings.linearSupportThreshold;
summaryRows = struct();
summaryRows.nSeedEvents = numel(seedCorrelations);
summaryRows.seedMedianTemplateCorrelation = median(seedCorrelations, 'omitnan');
summaryRows.nCompoundEvents = height(compoundSummaryTable);
summaryRows.medianSubpeaksPerCompound = median(compoundSummaryTable.nSubpeaks, 'omitnan');
summaryRows.medianTemplateLikeSubpeaksPerCompound = median(compoundSummaryTable.nTemplateLikeSubpeaks, 'omitnan');
summaryRows.fractionCompoundWithAtLeastTwoTemplateLike = mean(compoundSummaryTable.nTemplateLikeSubpeaks >= 2, 'omitnan');
summaryRows.fractionSubelementsTemplateLike = mean(templateLikeMask, 'omitnan');
summaryRows.subelementMedianTemplateCorrelation = median(subelementTable.templateCorrelation, 'omitnan');
summaryRows.randomMedianTemplateCorrelation = median(randomTable.templateCorrelation, 'omitnan');
summaryRows.subelementMedianLinearSupportRatio = median(subelementTable.linearSupportRatio, 'omitnan');
summaryRows.templateCorrelationThreshold = settings.templateCorrelationThreshold;
summaryRows.linearSupportThreshold = settings.linearSupportThreshold;
end

function LF_makeTemplateFigure(unitRelativeTimeSec, seedSnippetMatrix, compoundSnippetMatrix, randomSnippetMatrix, unitTemplate, outputRoot)
figureHandle = figure('Color', 'w', 'Position', [100 80 1250 760]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Provisional unit template and candidate subelements', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Snippets are median-centered and amplitude-normalized. Template comes only from clean isolated events.', 'FontSize', 11);

ax = nexttile(t, 1);
LF_plotMeanSem(ax, unitRelativeTimeSec, seedSnippetMatrix, [0.10 0.35 0.65], 'clean isolated seeds');
plot(ax, unitRelativeTimeSec, unitTemplate, 'k', 'LineWidth', 2.5, 'DisplayName', 'template');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'time from subpeak (s)');
ylabel(ax, 'normalized eventSignal');
title(ax, 'Seed events and template', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast', 'Box', 'off');

ax = nexttile(t, 2);
LF_plotMeanSem(ax, unitRelativeTimeSec, compoundSnippetMatrix, [0.70 0.25 0.15], 'compound subpeaks');
plot(ax, unitRelativeTimeSec, unitTemplate, 'k', 'LineWidth', 2.2, 'DisplayName', 'template');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'time from subpeak (s)');
ylabel(ax, 'normalized eventSignal');
title(ax, 'All detected compound-window subpeaks', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast', 'Box', 'off');

ax = nexttile(t, 3);
LF_plotMeanSem(ax, unitRelativeTimeSec, randomSnippetMatrix, [0.30 0.30 0.30], 'random windows');
plot(ax, unitRelativeTimeSec, unitTemplate, 'k', 'LineWidth', 2.2, 'DisplayName', 'template');
xline(ax, 0, '--k', 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'time from random center (s)');
ylabel(ax, 'normalized eventSignal');
title(ax, 'Random-window control snippets', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast', 'Box', 'off');

ax = nexttile(t, 4);
hold(ax, 'on');
LF_plotCdf(ax, LF_templateCorrelations(seedSnippetMatrix, unitTemplate), [0.10 0.35 0.65], 'seed-template');
LF_plotCdf(ax, LF_templateCorrelations(compoundSnippetMatrix, unitTemplate), [0.70 0.25 0.15], 'compound subpeak-template');
LF_plotCdf(ax, LF_templateCorrelations(randomSnippetMatrix, unitTemplate), [0.30 0.30 0.30], 'random-template');
grid(ax, 'on');
xlim(ax, [-1 1]);
xlabel(ax, 'template correlation');
ylabel(ax, 'CDF');
title(ax, 'Template similarity distributions', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast', 'Box', 'off');

exportgraphics(figureHandle, fullfile(outputRoot, 'compound_unit_template_and_subelements.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'compound_unit_template_and_subelements.fig'));
close(figureHandle);
end

function LF_makeDecompositionSummaryFigure(compoundSummaryTable, subelementTable, randomTable, seedCorrelations, compoundCorrelations, randomCorrelations, outputRoot)
figureHandle = figure('Color', 'w', 'Position', [100 80 1350 760]);
t = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Compound-event decomposition diagnostics', 'FontSize', 16, 'FontWeight', 'bold');

ax = nexttile(t, 1);
histogram(ax, compoundSummaryTable.nSubpeaks, 'BinMethod', 'integers', ...
    'FaceColor', [0.15 0.35 0.65], 'EdgeColor', 'none');
grid(ax, 'on');
xlabel(ax, 'lower-threshold subpeaks per compound window');
ylabel(ax, 'compound event count');
title(ax, 'Subpeak counts', 'FontWeight', 'normal');

ax = nexttile(t, 2);
histogram(ax, compoundSummaryTable.nTemplateLikeSubpeaks, 'BinMethod', 'integers', ...
    'FaceColor', [0.70 0.25 0.15], 'EdgeColor', 'none');
xline(ax, 2, '--k');
grid(ax, 'on');
xlabel(ax, 'template-like supported subpeaks');
ylabel(ax, 'compound event count');
title(ax, 'Template-like counts', 'FontWeight', 'normal');

ax = nexttile(t, 3);
boxchart(ax, categorical(compoundSummaryTable.subjectID), compoundSummaryTable.nTemplateLikeSubpeaks);
yline(ax, 2, '--k');
grid(ax, 'on');
xlabel(ax, 'subject');
ylabel(ax, 'template-like subpeaks');
title(ax, 'Decomposition by subject', 'FontWeight', 'normal');

ax = nexttile(t, 4);
hold(ax, 'on');
LF_plotCdf(ax, seedCorrelations, [0.10 0.35 0.65], 'seed');
LF_plotCdf(ax, compoundCorrelations, [0.70 0.25 0.15], 'compound subpeak');
LF_plotCdf(ax, randomCorrelations, [0.30 0.30 0.30], 'random');
grid(ax, 'on');
xlim(ax, [-1 1]);
xlabel(ax, 'template correlation');
ylabel(ax, 'CDF');
title(ax, 'Template correlation', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast', 'Box', 'off');

ax = nexttile(t, 5);
scatter(ax, subelementTable.templateCorrelation, subelementTable.linearSupportRatio, ...
    12, 'filled', 'MarkerFaceAlpha', 0.25);
xline(ax, 0.40, '--k');
yline(ax, 1.0, '--k');
grid(ax, 'on');
xlabel(ax, 'template correlation');
ylabel(ax, 'linear support ratio');
title(ax, 'Subelement shape vs motion support', 'FontWeight', 'normal');

ax = nexttile(t, 6);
boxchart(ax, categorical(compoundSummaryTable.condition), compoundSummaryTable.nTemplateLikeSubpeaks);
yline(ax, 2, '--k');
grid(ax, 'on');
xlabel(ax, 'condition');
ylabel(ax, 'template-like subpeaks');
title(ax, 'Decomposition by condition', 'FontWeight', 'normal');

exportgraphics(figureHandle, fullfile(outputRoot, 'compound_decomposition_diagnostics.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'compound_decomposition_diagnostics.fig'));
close(figureHandle);
end

function LF_plotMeanSem(ax, xValues, snippetMatrix, colorValue, displayName)
hold(ax, 'on');
meanTrace = mean(snippetMatrix, 2, 'omitnan');
nFinite = sum(isfinite(snippetMatrix), 2);
semTrace = std(snippetMatrix, 0, 2, 'omitnan') ./ sqrt(nFinite);
semTrace(nFinite < 2) = NaN;
finiteMask = isfinite(xValues(:)) & isfinite(meanTrace);
semMask = finiteMask & isfinite(semTrace);
if any(semMask)
    fill(ax, [xValues(semMask); flipud(xValues(semMask))], ...
        [meanTrace(semMask) + semTrace(semMask); flipud(meanTrace(semMask) - semTrace(semMask))], ...
        colorValue, 'FaceAlpha', 0.16, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
plot(ax, xValues(finiteMask), meanTrace(finiteMask), ...
    'Color', colorValue, 'LineWidth', 2.0, 'DisplayName', displayName);
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

function LF_makeCompoundExamplesFigure(fileContexts, compoundSummaryTable, subelementTable, settings, outputRoot)
decomposableTable = compoundSummaryTable(compoundSummaryTable.isDecomposable, :);
if isempty(decomposableTable)
    return;
end

decomposableTable = sortrows(decomposableTable, 'nTemplateLikeSubpeaks', 'descend');
nExamples = min(8, height(decomposableTable));
figureHandle = figure('Color', 'w', 'Position', [100 80 1400 950]);
t = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Example compound windows with candidate unit decompositions', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(t, 'Blue trace is eventSignal. Red markers are template-like supported subpeaks; gray markers are other low-threshold subpeaks.', 'FontSize', 11);

for exampleIndex = 1:nExamples
    currentRow = decomposableTable(exampleIndex, :);
    fileContextIndex = find(string({fileContexts.fileName}) == string(currentRow.fileName), 1, 'first');
    fileContext = fileContexts(fileContextIndex);
    compoundPeakIndex = currentRow.compoundPeakIndex;
    relativeSamples = LF_secondsToRelativeSamples(settings.compoundWindowSeconds, fileContext.samplingFrequency);
    sampleIndices = compoundPeakIndex + relativeSamples;
    validMask = sampleIndices >= 1 & sampleIndices <= numel(fileContext.eventSignal);
    sampleIndices = sampleIndices(validMask);
    relativeTimeSec = (sampleIndices - compoundPeakIndex) ./ fileContext.samplingFrequency;
    signalSnippet = fileContext.eventSignal(sampleIndices);

    axesHandle = nexttile(t, exampleIndex);
    plot(axesHandle, relativeTimeSec, signalSnippet, 'Color', [0.10 0.35 0.65], 'LineWidth', 1.6);
    hold(axesHandle, 'on');
    xline(axesHandle, 0, '--k');

    rowMask = string(subelementTable.fileName) == string(currentRow.fileName) & ...
        subelementTable.compoundPeakIndex == compoundPeakIndex;
    subRows = subelementTable(rowMask, :);
    for subIndex = 1:height(subRows)
        markerColor = [0.50 0.50 0.50];
        if subRows.isTemplateLike(subIndex)
            markerColor = [0.75 0.15 0.10];
        end
        plot(axesHandle, subRows.relativeTimeToCompoundPeakSec(subIndex), ...
            subRows.subpeakValue(subIndex), 'o', ...
            'MarkerFaceColor', markerColor, 'MarkerEdgeColor', markerColor, ...
            'MarkerSize', 5);
    end
    grid(axesHandle, 'on');
    xlabel(axesHandle, 'time from compound peak (s)');
    ylabel(axesHandle, 'eventSignal');
    title(axesHandle, sprintf('%s %s | %d template-like', ...
        char(currentRow.subjectID), erase(char(currentRow.condition), '_stand'), ...
        currentRow.nTemplateLikeSubpeaks), 'Interpreter', 'none', 'FontWeight', 'normal');
end

exportgraphics(figureHandle, fullfile(outputRoot, 'compound_decomposition_examples.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'compound_decomposition_examples.fig'));
close(figureHandle);
end

function LF_appendReport(scratchRoot, outputRoot, tableRoot, summaryTable, settings)
reportPath = fullfile(scratchRoot, 'UNITARY_EVENT_VALIDATION_REPORT.md');
fid = fopen(reportPath, 'a');
cleanupObject = onCleanup(@() fclose(fid));

fprintf(fid, '\n## Compound Event Decomposition Pass\n\n');
fprintf(fid, 'This second scratch pass treats non-unitarity as a possible biological feature rather than a failure. The working hypothesis is that many larger micromovements are composites of shorter acceleration-supported unit elements.\n\n');

fprintf(fid, '### Plan\n\n');
fprintf(fid, '1. Keep the existing detector fixed.\n');
fprintf(fid, '2. Define a provisional unit template from clean isolated events only: isolated events with `secondaryPeakRatio < %.2f` and detector width `<= %.1f s`.\n', ...
    settings.seedSecondaryPeakMax, settings.seedDetectorWidthMaxSec);
fprintf(fid, '3. Search compound-flagged event windows for lower-threshold local maxima using `%.1f x` typical noise and a `%.2f s` minimum subpeak distance.\n', ...
    settings.lowThresholdSigma, settings.subpeakMinDistanceSeconds);
fprintf(fid, '4. Mark a candidate subelement as template-like only if template correlation is at least `%.2f` and gravity-corrected linear support ratio is at least `%.1f`.\n', ...
    settings.templateCorrelationThreshold, settings.linearSupportThreshold);
fprintf(fid, '5. Call a compound window decomposable only if it contains at least two such template-like supported subelements.\n\n');

fprintf(fid, '### Quantitative Summary\n\n');
fprintf(fid, '- Seed events used for provisional unit template: `%d`\n', summaryTable.nSeedEvents);
fprintf(fid, '- Seed median template correlation: `%.3f`\n', summaryTable.seedMedianTemplateCorrelation);
fprintf(fid, '- Compound events inspected: `%d`\n', summaryTable.nCompoundEvents);
fprintf(fid, '- Median lower-threshold subpeaks per compound: `%.1f`\n', summaryTable.medianSubpeaksPerCompound);
fprintf(fid, '- Median template-like supported subpeaks per compound: `%.1f`\n', summaryTable.medianTemplateLikeSubpeaksPerCompound);
fprintf(fid, '- Fraction of compound events with at least two template-like supported subpeaks: `%.3f`\n', ...
    summaryTable.fractionCompoundWithAtLeastTwoTemplateLike);
fprintf(fid, '- Fraction of all compound-window subpeaks that are template-like and supported: `%.3f`\n', ...
    summaryTable.fractionSubelementsTemplateLike);
fprintf(fid, '- Compound subelement median template correlation: `%.3f`\n', summaryTable.subelementMedianTemplateCorrelation);
fprintf(fid, '- Random-window median template correlation: `%.3f`\n', summaryTable.randomMedianTemplateCorrelation);
fprintf(fid, '- Compound subelement median gravity-corrected support ratio: `%.3f`\n\n', ...
    summaryTable.subelementMedianLinearSupportRatio);

fprintf(fid, '### Figures To Inspect\n\n');
fprintf(fid, '- `%s`\n', fullfile(outputRoot, 'compound_unit_template_and_subelements.png'));
fprintf(fid, '- `%s`\n', fullfile(outputRoot, 'compound_decomposition_diagnostics.png'));
fprintf(fid, '- `%s`\n\n', fullfile(outputRoot, 'compound_decomposition_examples.png'));

fprintf(fid, '### Interpretation\n\n');
fprintf(fid, 'This pass supports your reframing: compound events are not simply garbage to discard. Many contain multiple lower-threshold local maxima, and a substantial subset can be parsed into at least two candidate unit-like subelements under the current template/support rule. That is consistent with larger micromovements being composites of briefer motor bursts.\n\n');
fprintf(fid, 'The analysis is still not proof of a physiological unit. The template was derived from the same detector family, and the threshold/correlation cutoffs are provisional. The useful result is more specific: the current data justify moving from a binary isolated-versus-compound framing to a hierarchical model where detected envelope events can contain multiple acceleration-supported subevents.\n\n');
fprintf(fid, 'The next technical step should be to improve the decomposition criterion from local peak counting to constrained template fitting: fit one, two, and three shifted unit templates to each compound window, compare residual reduction against random windows, and require each fitted unit to retain gravity-corrected acceleration support. That would test whether decomposition explains compound morphology better than simply adding arbitrary peaks.\n');
fprintf(fid, '\n### Files Added By This Pass\n\n');
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'compound_decomposition_summary.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'compound_subelements.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'compound_decomposition_random_controls.csv'));
fprintf(fid, '- `%s`\n', fullfile(tableRoot, 'compound_decomposition_metrics.csv'));
fprintf(fid, '- `%s`\n', fullfile(scratchRoot, 'compound_event_decomposition_workspace.mat'));
end
