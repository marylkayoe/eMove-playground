% Run a scratch validation study for Waseda primitive envelope events.
%
% Goal
%   Test whether the current "unitary" envelope events have independent
%   raw-motion support, or whether the detector/envelope pipeline can impose
%   similar-looking events on matched or surrogate signals.
%
% Outputs are exploratory and written only under this scratch folder.

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
settings.eventWindowSeconds = [-5 5];
settings.coreWindowSeconds = [-2 4];
settings.randomCandidateStepSeconds = 0.50;
settings.randomGuardSeconds = 5.0;
settings.baselineWindowSeconds = 15;
settings.noiseWindowSeconds = 30;
settings.thresholdSigma = 4;
settings.quaternionJumpMaxDeg = 60;
settings.useConjugate = false;
settings.frequencyBandHz = [0.2 10];
settings.envelopeWindowSeconds = 1.0;
settings.nSurrogatesPerType = 1;
settings.randomSeed = 20260508;

rng(settings.randomSeed);

magnitudeFiles = dir(fullfile(magnitudeRoot, '*_acc1_chest_motionEnvelope.mat'));
if isempty(magnitudeFiles)
    error('No magnitude files found in %s.', magnitudeRoot);
end

allFileResults = struct([]);
allEventRows = struct([]);
allSurrogateRows = struct([]);

realSnippetStore = struct();
realSnippetStore.eventSignal = {};
realSnippetStore.randomEventSignal = {};
realSnippetStore.linearMagnitude = {};
realSnippetStore.randomLinearMagnitude = {};
realSnippetStore.filteredMagnitude = {};
realSnippetStore.randomFilteredMagnitude = {};

realLayerAccumulator = LF_emptyLayerAccumulator();
randomLayerAccumulator = LF_emptyLayerAccumulator();

fprintf('Running unitary-event validation on %d Waseda chest files.\n', numel(magnitudeFiles));

for fileIndex = 1:numel(magnitudeFiles)
    magnitudeFileName = magnitudeFiles(fileIndex).name;
    magnitudePath = fullfile(magnitudeFiles(fileIndex).folder, magnitudeFileName);
    rawFileName = replace(magnitudeFileName, '_motionEnvelope.mat', '.mat');
    rawPath = fullfile(rawRoot, rawFileName);

    if ~isfile(rawPath)
        error('Missing raw concatenated MAT file for %s: %s', magnitudeFileName, rawPath);
    end

    fprintf('  [%d/%d] %s\n', fileIndex, numel(magnitudeFiles), magnitudeFileName);

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
    if isempty(eventTable)
        selectedEventTable = eventTable;
    else
        selectedEventTable = eventTable(eventTable.isIsolatedEvent, :);
    end

    selectedPeakIndices = selectedEventTable.peakIndex;
    allDetectedPeakIndices = eventOutput.peakLocations(:);
    randomPeakIndices = LF_sampleMatchedRandomWindows( ...
        eventOutput.noiseEstimate.baseline, ...
        eventOutput.noiseEstimate.eventSignal, ...
        selectedPeakIndices, ...
        allDetectedPeakIndices, ...
        samplingFrequency, ...
        settings);

    signalLayers = LF_buildSignalLayers(accData, imuPrepared, imuCorrected, imuEnvelope, motionData, eventOutput);

    fileLayerSummary = LF_summarizeFileLayers(signalLayers, selectedPeakIndices, randomPeakIndices, samplingFrequency, settings);
    realLayerAccumulator = LF_accumulateLayers(realLayerAccumulator, fileLayerSummary.event);
    randomLayerAccumulator = LF_accumulateLayers(randomLayerAccumulator, fileLayerSummary.random);

    [eventRows, realSnippetStore] = LF_buildEventRowsAndStoreSnippets( ...
        magnitudeFileName, fileInfo, selectedEventTable, randomPeakIndices, signalLayers, ...
        samplingFrequency, settings, realSnippetStore);

    if isempty(allEventRows)
        allEventRows = eventRows;
    elseif ~isempty(eventRows)
        allEventRows(end + 1:end + numel(eventRows), 1) = eventRows; %#ok<SAGROW>
    end

    fileResult = struct();
    fileResult.fileName = string(magnitudeFileName);
    fileResult.subjectID = string(fileInfo.subjectID);
    fileResult.condition = string(fileInfo.condition);
    fileResult.nDetected = numel(allDetectedPeakIndices);
    fileResult.nIsolated = height(selectedEventTable);
    fileResult.nRandom = numel(randomPeakIndices);
    fileResult.sampleRateHz = samplingFrequency;
    fileResult.durationSec = motionData.timeSec(end) - motionData.timeSec(1);
    fileResult.preparedBadSampleFraction = imuPrepared.qc.summary.fractionBadSamplesPadded;
    fileResult.envelopeBadArtefactFraction = imuEnvelope.qc.fractionBadArtefact;
    fileResult.medianDetectorAmplitude = median(selectedEventTable.peakValue, 'omitnan');
    fileResult.medianContaminationRatio = median([eventRows.secondaryPeakRatio], 'omitnan');

    if isempty(allFileResults)
        allFileResults = fileResult;
    else
        allFileResults(end + 1, 1) = fileResult; %#ok<SAGROW>
    end

    surrogateRows = LF_runSurrogateControls( ...
        magnitudeFileName, fileInfo, motionData.motionEnvelope, motionData.timeSec, ...
        samplingFrequency, settings);

    if isempty(allSurrogateRows)
        allSurrogateRows = surrogateRows;
    elseif ~isempty(surrogateRows)
        allSurrogateRows(end + 1:end + numel(surrogateRows), 1) = surrogateRows; %#ok<SAGROW>
    end
end

fileSummaryTable = struct2table(allFileResults);
eventValidationTable = struct2table(allEventRows);
surrogateSummaryTable = struct2table(allSurrogateRows);

similaritySummary = LF_buildSimilaritySummary(realSnippetStore);
similaritySummaryTable = struct2table(similaritySummary);

writetable(fileSummaryTable, fullfile(tableRoot, 'file_summary.csv'));
writetable(eventValidationTable, fullfile(tableRoot, 'event_validation_table.csv'));
writetable(surrogateSummaryTable, fullfile(tableRoot, 'surrogate_summary.csv'));
writetable(similaritySummaryTable, fullfile(tableRoot, 'similarity_summary.csv'));

save(fullfile(scratchRoot, 'unitary_event_validation_workspace.mat'), ...
    'settings', 'fileSummaryTable', 'eventValidationTable', 'surrogateSummaryTable', ...
    'similaritySummaryTable', 'realLayerAccumulator', 'randomLayerAccumulator', ...
    'realSnippetStore', '-v7.3');

LF_makeEventTriggeredLayerFigure(realLayerAccumulator, randomLayerAccumulator, outputRoot);
LF_makeSignalSupportFigure(eventValidationTable, outputRoot);
LF_makeSimilarityFigure(realSnippetStore, similaritySummaryTable, outputRoot);
LF_makeSurrogateFigure(surrogateSummaryTable, outputRoot);
LF_makeTimingAndContaminationFigure(eventValidationTable, fileSummaryTable, outputRoot);
LF_writeReport(scratchRoot, outputRoot, tableRoot, fileSummaryTable, eventValidationTable, ...
    surrogateSummaryTable, similaritySummaryTable);

fprintf('Validation study complete.\n');
fprintf('Report: %s\n', fullfile(scratchRoot, 'UNITARY_EVENT_VALIDATION_REPORT.md'));

function accumulator = LF_emptyLayerAccumulator()
layerNames = ["rawMagnitude", "preparedMagnitude", "linearMagnitude", ...
    "filteredMagnitude", "motionEnvelope", "eventSignal"];
for layerIndex = 1:numel(layerNames)
    accumulator.(layerNames(layerIndex)) = [];
end
accumulator.relativeTimeSec = [];
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

function signalLayers = LF_buildSignalLayers(accData, imuPrepared, imuCorrected, imuEnvelope, motionData, eventOutput)
signalLayers = struct();
signalLayers.rawX = accData.acc(:, 1);
signalLayers.rawY = accData.acc(:, 2);
signalLayers.rawZ = accData.acc(:, 3);
signalLayers.rawMagnitude = sqrt(sum(double(accData.acc).^2, 2));
signalLayers.preparedMagnitude = sqrt(sum(imuPrepared.prepared.acc.^2, 2));
signalLayers.linearMagnitude = sqrt(sum(imuCorrected.acc.linear.^2, 2));
signalLayers.filteredMagnitude = imuEnvelope.magnitude.filtered;
signalLayers.motionEnvelope = motionData.motionEnvelope(:);
signalLayers.eventSignal = eventOutput.noiseEstimate.eventSignal(:);
signalLayers.linearX = imuCorrected.acc.linear(:, 1);
signalLayers.linearY = imuCorrected.acc.linear(:, 2);
signalLayers.linearZ = imuCorrected.acc.linear(:, 3);
end

function randomPeakIndices = LF_sampleMatchedRandomWindows(baseline, eventSignal, selectedPeakIndices, allDetectedPeakIndices, samplingFrequency, settings)
targetCount = numel(selectedPeakIndices);
if targetCount == 0
    randomPeakIndices = zeros(0, 1);
    return;
end

nSamples = numel(eventSignal);
windowSamples = round(settings.eventWindowSeconds .* samplingFrequency);
guardSamples = round(settings.randomGuardSeconds .* samplingFrequency);
candidateStepSamples = max(1, round(settings.randomCandidateStepSeconds .* samplingFrequency));

validStart = 1 - windowSamples(1);
validEnd = nSamples - windowSamples(2);
candidateIndices = (validStart:candidateStepSamples:validEnd).';

keepCandidate = true(size(candidateIndices));
for peakIndex = 1:numel(allDetectedPeakIndices)
    keepCandidate = keepCandidate & abs(candidateIndices - allDetectedPeakIndices(peakIndex)) > guardSamples;
end
candidateIndices = candidateIndices(keepCandidate);

if isempty(candidateIndices)
    randomPeakIndices = zeros(0, 1);
    return;
end

eventFeatures = LF_windowFeatures(baseline, eventSignal, selectedPeakIndices, samplingFrequency);
candidateFeatures = LF_windowFeatures(baseline, eventSignal, candidateIndices, samplingFrequency);

featureCenter = median(candidateFeatures, 1, 'omitnan');
featureScale = mad(candidateFeatures, 1, 1);
featureScale(featureScale <= 0 | ~isfinite(featureScale)) = 1;

eventFeaturesZ = (eventFeatures - featureCenter) ./ featureScale;
candidateFeaturesZ = (candidateFeatures - featureCenter) ./ featureScale;

randomPeakIndices = NaN(targetCount, 1);
available = true(numel(candidateIndices), 1);
eventOrder = randperm(targetCount);

for orderIndex = 1:numel(eventOrder)
    eventIndex = eventOrder(orderIndex);
    differences = candidateFeaturesZ - eventFeaturesZ(eventIndex, :);
    distances = sqrt(sum(differences.^2, 2, 'omitnan'));
    distances(~available) = Inf;
    [~, bestCandidateIndex] = min(distances);
    if isfinite(distances(bestCandidateIndex))
        randomPeakIndices(eventIndex) = candidateIndices(bestCandidateIndex);
        available(bestCandidateIndex) = false;
    end
end

randomPeakIndices = randomPeakIndices(isfinite(randomPeakIndices));
randomPeakIndices = round(randomPeakIndices(:));
end

function features = LF_windowFeatures(baseline, eventSignal, centerIndices, samplingFrequency)
halfWindowSamples = max(1, round(5 .* samplingFrequency));
features = NaN(numel(centerIndices), 3);
for centerIndex = 1:numel(centerIndices)
    currentIndex = centerIndices(centerIndex);
    windowIndex = max(1, currentIndex - halfWindowSamples):min(numel(eventSignal), currentIndex + halfWindowSamples);
    features(centerIndex, 1) = median(baseline(windowIndex), 'omitnan');
    features(centerIndex, 2) = median(eventSignal(windowIndex), 'omitnan');
    features(centerIndex, 3) = mad(eventSignal(windowIndex), 1);
end
end

function fileLayerSummary = LF_summarizeFileLayers(signalLayers, eventPeakIndices, randomPeakIndices, samplingFrequency, settings)
layerNames = ["rawMagnitude", "preparedMagnitude", "linearMagnitude", ...
    "filteredMagnitude", "motionEnvelope", "eventSignal"];
windowSamples = round(settings.eventWindowSeconds .* samplingFrequency);
relativeSamples = (windowSamples(1):windowSamples(2)).';
relativeTimeSec = relativeSamples ./ samplingFrequency;

fileLayerSummary = struct();
fileLayerSummary.event = struct();
fileLayerSummary.random = struct();
fileLayerSummary.event.relativeTimeSec = relativeTimeSec;
fileLayerSummary.random.relativeTimeSec = relativeTimeSec;

for layerIndex = 1:numel(layerNames)
    layerName = layerNames(layerIndex);
    fileLayerSummary.event.(layerName) = LF_extractSnippetMatrix(signalLayers.(layerName), eventPeakIndices, relativeSamples);
    fileLayerSummary.random.(layerName) = LF_extractSnippetMatrix(signalLayers.(layerName), randomPeakIndices, relativeSamples);
end
end

function accumulator = LF_accumulateLayers(accumulator, layerSummary)
layerNames = ["rawMagnitude", "preparedMagnitude", "linearMagnitude", ...
    "filteredMagnitude", "motionEnvelope", "eventSignal"];
if isempty(accumulator.relativeTimeSec)
    accumulator.relativeTimeSec = layerSummary.relativeTimeSec;
end
for layerIndex = 1:numel(layerNames)
    layerName = layerNames(layerIndex);
    accumulator.(layerName) = [accumulator.(layerName), layerSummary.(layerName)]; %#ok<AGROW>
end
end

function [eventRows, snippetStore] = LF_buildEventRowsAndStoreSnippets(fileName, fileInfo, selectedEventTable, randomPeakIndices, signalLayers, samplingFrequency, settings, snippetStore)
if isempty(selectedEventTable)
    eventRows = struct([]);
    return;
end

windowSamples = round(settings.eventWindowSeconds .* samplingFrequency);
relativeSamples = (windowSamples(1):windowSamples(2)).';

coreSamples = round(settings.coreWindowSeconds .* samplingFrequency);
coreRelativeSamples = (coreSamples(1):coreSamples(2)).';

nEvents = height(selectedEventTable);
eventRows = repmat(struct( ...
    'fileName', "", ...
    'subjectID', "", ...
    'condition', "", ...
    'peakIndex', NaN, ...
    'peakTimeSec', NaN, ...
    'detectorAmplitude', NaN, ...
    'detectorWidthSec', NaN, ...
    'secondaryPeakRatio', NaN, ...
    'linearMagnitudeEventEnergy', NaN, ...
    'linearMagnitudeRandomEnergy', NaN, ...
    'filteredMagnitudeEventEnergy', NaN, ...
    'filteredMagnitudeRandomEnergy', NaN, ...
    'eventSignalEventEnergy', NaN, ...
    'eventSignalRandomEnergy', NaN, ...
    'rawMagnitudeEventEnergy', NaN, ...
    'rawMagnitudeRandomEnergy', NaN), nEvents, 1);

for eventIndex = 1:nEvents
    peakIndex = selectedEventTable.peakIndex(eventIndex);
    if eventIndex <= numel(randomPeakIndices)
        randomPeakIndex = randomPeakIndices(eventIndex);
    else
        randomPeakIndex = NaN;
    end

    eventSignalSnippet = LF_extractSnippetMatrix(signalLayers.eventSignal, peakIndex, relativeSamples);
    randomEventSignalSnippet = LF_extractSnippetMatrix(signalLayers.eventSignal, randomPeakIndex, relativeSamples);
    linearMagnitudeSnippet = LF_extractSnippetMatrix(signalLayers.linearMagnitude, peakIndex, relativeSamples);
    randomLinearMagnitudeSnippet = LF_extractSnippetMatrix(signalLayers.linearMagnitude, randomPeakIndex, relativeSamples);
    filteredMagnitudeSnippet = LF_extractSnippetMatrix(signalLayers.filteredMagnitude, peakIndex, relativeSamples);
    randomFilteredMagnitudeSnippet = LF_extractSnippetMatrix(signalLayers.filteredMagnitude, randomPeakIndex, relativeSamples);

    snippetStore.eventSignal{end + 1, 1} = LF_normalizeSnippet(eventSignalSnippet); %#ok<AGROW>
    snippetStore.randomEventSignal{end + 1, 1} = LF_normalizeSnippet(randomEventSignalSnippet); %#ok<AGROW>
    snippetStore.linearMagnitude{end + 1, 1} = LF_normalizeSnippet(linearMagnitudeSnippet); %#ok<AGROW>
    snippetStore.randomLinearMagnitude{end + 1, 1} = LF_normalizeSnippet(randomLinearMagnitudeSnippet); %#ok<AGROW>
    snippetStore.filteredMagnitude{end + 1, 1} = LF_normalizeSnippet(filteredMagnitudeSnippet); %#ok<AGROW>
    snippetStore.randomFilteredMagnitude{end + 1, 1} = LF_normalizeSnippet(randomFilteredMagnitudeSnippet); %#ok<AGROW>

    eventRows(eventIndex).fileName = string(fileName);
    eventRows(eventIndex).subjectID = string(fileInfo.subjectID);
    eventRows(eventIndex).condition = string(fileInfo.condition);
    eventRows(eventIndex).peakIndex = peakIndex;
    eventRows(eventIndex).peakTimeSec = selectedEventTable.peakTimeSec(eventIndex);
    eventRows(eventIndex).detectorAmplitude = selectedEventTable.peakValue(eventIndex);
    eventRows(eventIndex).detectorWidthSec = selectedEventTable.peakWidthSec(eventIndex);
    eventRows(eventIndex).secondaryPeakRatio = LF_secondaryPeakRatio(signalLayers.eventSignal, peakIndex, coreRelativeSamples, samplingFrequency);
    eventRows(eventIndex).linearMagnitudeEventEnergy = LF_snippetEnergy(linearMagnitudeSnippet);
    eventRows(eventIndex).linearMagnitudeRandomEnergy = LF_snippetEnergy(randomLinearMagnitudeSnippet);
    eventRows(eventIndex).filteredMagnitudeEventEnergy = LF_snippetEnergy(filteredMagnitudeSnippet);
    eventRows(eventIndex).filteredMagnitudeRandomEnergy = LF_snippetEnergy(randomFilteredMagnitudeSnippet);
    eventRows(eventIndex).eventSignalEventEnergy = LF_snippetEnergy(eventSignalSnippet);
    eventRows(eventIndex).eventSignalRandomEnergy = LF_snippetEnergy(randomEventSignalSnippet);
    eventRows(eventIndex).rawMagnitudeEventEnergy = LF_snippetEnergy(LF_extractSnippetMatrix(signalLayers.rawMagnitude, peakIndex, relativeSamples));
    eventRows(eventIndex).rawMagnitudeRandomEnergy = LF_snippetEnergy(LF_extractSnippetMatrix(signalLayers.rawMagnitude, randomPeakIndex, relativeSamples));
end
end

function snippetMatrix = LF_extractSnippetMatrix(signal, centerIndices, relativeSamples)
signal = signal(:);
centerIndices = round(centerIndices(:));
snippetMatrix = NaN(numel(relativeSamples), numel(centerIndices));
for centerIndex = 1:numel(centerIndices)
    currentCenter = centerIndices(centerIndex);
    if ~isfinite(currentCenter)
        continue;
    end
    sampleIndices = currentCenter + relativeSamples;
    if any(sampleIndices < 1) || any(sampleIndices > numel(signal))
        continue;
    end
    snippetMatrix(:, centerIndex) = signal(sampleIndices);
end
end

function normalizedSnippet = LF_normalizeSnippet(snippet)
normalizedSnippet = snippet(:);
finiteMask = isfinite(normalizedSnippet);
if ~any(finiteMask)
    return;
end
normalizedSnippet = normalizedSnippet - median(normalizedSnippet(finiteMask), 'omitnan');
scaleValue = max(abs(normalizedSnippet(finiteMask)), [], 'omitnan');
if isfinite(scaleValue) && scaleValue > 0
    normalizedSnippet = normalizedSnippet ./ scaleValue;
end
end

function energyValue = LF_snippetEnergy(snippet)
values = snippet(isfinite(snippet));
if isempty(values)
    energyValue = NaN;
else
    values = values - median(values, 'omitnan');
    energyValue = sqrt(mean(values.^2, 'omitnan'));
end
end

function ratioValue = LF_secondaryPeakRatio(eventSignal, peakIndex, relativeSamples, samplingFrequency)
sampleIndices = peakIndex + relativeSamples;
sampleIndices = sampleIndices(sampleIndices >= 1 & sampleIndices <= numel(eventSignal));
snippet = eventSignal(sampleIndices);
mainPeakValue = eventSignal(peakIndex);
if ~isfinite(mainPeakValue) || mainPeakValue <= 0
    ratioValue = NaN;
    return;
end

[peakValues, peakLocations] = findpeaks(snippet, 'MinPeakDistance', max(1, round(0.30 .* samplingFrequency)));
absolutePeakLocations = sampleIndices(1) + peakLocations - 1;
notMainPeak = abs(absolutePeakLocations - peakIndex) > round(0.35 .* samplingFrequency);
secondaryPeakValues = peakValues(notMainPeak);
if isempty(secondaryPeakValues)
    ratioValue = 0;
else
    ratioValue = max(secondaryPeakValues, [], 'omitnan') ./ mainPeakValue;
end
end

function surrogateRows = LF_runSurrogateControls(fileName, fileInfo, signal, timeSec, samplingFrequency, settings)
surrogateTypes = ["phaseRandomized", "chunkShuffled"];
surrogateRows = struct([]);
rowCounter = 0;
for surrogateTypeIndex = 1:numel(surrogateTypes)
    surrogateType = surrogateTypes(surrogateTypeIndex);
    for repeatIndex = 1:settings.nSurrogatesPerType
        if surrogateType == "phaseRandomized"
            surrogateSignal = LF_phaseRandomizeSignal(signal);
        else
            surrogateSignal = LF_chunkShuffleSignal(signal, samplingFrequency, 5);
        end

        surrogateOutput = extractEnvelopeEvents( ...
            surrogateSignal, ...
            samplingFrequency, ...
            'TimeSec', timeSec, ...
            'BaselineWindowSeconds', settings.baselineWindowSeconds, ...
            'NoiseWindowSeconds', settings.noiseWindowSeconds, ...
            'RectifyResidual', true, ...
            'ThresholdSigma', settings.thresholdSigma, ...
            'MakeWaveformFigure', false, ...
            'MakeSummaryFigure', false);
        close all;

        surrogateEventTable = surrogateOutput.eventTable;
        if isempty(surrogateEventTable)
            isolatedMask = false(0, 1);
        else
            isolatedMask = surrogateEventTable.isIsolatedEvent;
        end
        isolatedPeaks = surrogateEventTable.peakIndex(isolatedMask);
        medianSimilarity = LF_medianSnippetSimilarity( ...
            surrogateOutput.noiseEstimate.eventSignal, isolatedPeaks, samplingFrequency, settings);

        rowCounter = rowCounter + 1;
        surrogateRows(rowCounter, 1).fileName = string(fileName); %#ok<AGROW>
        surrogateRows(rowCounter, 1).subjectID = string(fileInfo.subjectID);
        surrogateRows(rowCounter, 1).condition = string(fileInfo.condition);
        surrogateRows(rowCounter, 1).surrogateType = string(surrogateType);
        surrogateRows(rowCounter, 1).repeatIndex = repeatIndex;
        surrogateRows(rowCounter, 1).nDetected = numel(surrogateOutput.peakLocations);
        surrogateRows(rowCounter, 1).nIsolated = numel(isolatedPeaks);
        surrogateRows(rowCounter, 1).medianEventSignalSimilarity = medianSimilarity;
    end
end
end

function surrogateSignal = LF_phaseRandomizeSignal(signal)
signal = signal(:);
finiteMask = isfinite(signal);
filledSignal = signal;
filledSignal(~finiteMask) = median(signal(finiteMask), 'omitnan');
centeredSignal = filledSignal - mean(filledSignal, 'omitnan');
nSamples = numel(centeredSignal);
fourierValues = fft(centeredSignal);
amplitudeValues = abs(fourierValues);
randomPhase = 2 .* pi .* rand(nSamples, 1);
randomFourier = amplitudeValues .* exp(1i .* randomPhase);
randomFourier(1) = fourierValues(1);
if mod(nSamples, 2) == 0
    randomFourier(nSamples / 2 + 1) = fourierValues(nSamples / 2 + 1);
end
for frequencyIndex = 2:floor(nSamples / 2)
    randomFourier(nSamples - frequencyIndex + 2) = conj(randomFourier(frequencyIndex));
end
surrogateSignal = real(ifft(randomFourier)) + mean(filledSignal, 'omitnan');
end

function surrogateSignal = LF_chunkShuffleSignal(signal, samplingFrequency, chunkSeconds)
signal = signal(:);
nSamples = numel(signal);
chunkSamples = max(1, round(chunkSeconds .* samplingFrequency));
nChunks = ceil(nSamples ./ chunkSamples);
chunkCell = cell(nChunks, 1);
for chunkIndex = 1:nChunks
    startIndex = (chunkIndex - 1) .* chunkSamples + 1;
    endIndex = min(nSamples, chunkIndex .* chunkSamples);
    chunkCell{chunkIndex} = signal(startIndex:endIndex);
end
chunkOrder = randperm(nChunks);
surrogateSignal = vertcat(chunkCell{chunkOrder});
surrogateSignal = surrogateSignal(1:nSamples);
end

function medianSimilarity = LF_medianSnippetSimilarity(signal, peakIndices, samplingFrequency, settings)
if numel(peakIndices) < 2
    medianSimilarity = NaN;
    return;
end
windowSamples = round(settings.eventWindowSeconds .* samplingFrequency);
relativeSamples = (windowSamples(1):windowSamples(2)).';
snippetMatrix = LF_extractSnippetMatrix(signal, peakIndices, relativeSamples);
snippetMatrix = LF_normalizeSnippetMatrix(snippetMatrix);
similarities = LF_upperTriangleCorrelations(snippetMatrix);
medianSimilarity = median(similarities, 'omitnan');
end

function normalizedMatrix = LF_normalizeSnippetMatrix(snippetMatrix)
normalizedMatrix = NaN(size(snippetMatrix));
for columnIndex = 1:size(snippetMatrix, 2)
    normalizedMatrix(:, columnIndex) = LF_normalizeSnippet(snippetMatrix(:, columnIndex));
end
end

function similaritySummary = LF_buildSimilaritySummary(snippetStore)
definitions = { ...
    'eventSignal', 'randomEventSignal'; ...
    'linearMagnitude', 'randomLinearMagnitude'; ...
    'filteredMagnitude', 'randomFilteredMagnitude'};
similaritySummary = repmat(struct( ...
    'signalName', "", ...
    'eventEventMedianSimilarity', NaN, ...
    'randomRandomMedianSimilarity', NaN, ...
    'eventRandomMedianSimilarity', NaN, ...
    'nEventSnippets', NaN, ...
    'nRandomSnippets', NaN), size(definitions, 1), 1);

for definitionIndex = 1:size(definitions, 1)
    eventMatrix = LF_cellSnippetsToMatrix(snippetStore.(definitions{definitionIndex, 1}));
    randomMatrix = LF_cellSnippetsToMatrix(snippetStore.(definitions{definitionIndex, 2}));
    eventEventValues = LF_upperTriangleCorrelations(eventMatrix);
    randomRandomValues = LF_upperTriangleCorrelations(randomMatrix);
    eventRandomValues = LF_crossCorrelations(eventMatrix, randomMatrix);

    similaritySummary(definitionIndex).signalName = string(definitions{definitionIndex, 1});
    similaritySummary(definitionIndex).eventEventMedianSimilarity = median(eventEventValues, 'omitnan');
    similaritySummary(definitionIndex).randomRandomMedianSimilarity = median(randomRandomValues, 'omitnan');
    similaritySummary(definitionIndex).eventRandomMedianSimilarity = median(eventRandomValues, 'omitnan');
    similaritySummary(definitionIndex).nEventSnippets = size(eventMatrix, 2);
    similaritySummary(definitionIndex).nRandomSnippets = size(randomMatrix, 2);
end
end

function matrix = LF_cellSnippetsToMatrix(snippetCell)
if isempty(snippetCell)
    matrix = NaN(0, 0);
    return;
end
nRows = numel(snippetCell{1});
matrix = NaN(nRows, numel(snippetCell));
for columnIndex = 1:numel(snippetCell)
    matrix(:, columnIndex) = snippetCell{columnIndex};
end
end

function values = LF_upperTriangleCorrelations(snippetMatrix)
if size(snippetMatrix, 2) < 2
    values = NaN(0, 1);
    return;
end
correlationMatrix = corr(snippetMatrix, 'Rows', 'pairwise');
upperMask = triu(true(size(correlationMatrix)), 1);
values = correlationMatrix(upperMask);
values = values(isfinite(values));
end

function values = LF_crossCorrelations(eventMatrix, randomMatrix)
if isempty(eventMatrix) || isempty(randomMatrix)
    values = NaN(0, 1);
    return;
end
correlationMatrix = corr(eventMatrix, randomMatrix, 'Rows', 'pairwise');
values = correlationMatrix(:);
values = values(isfinite(values));
end

function LF_makeEventTriggeredLayerFigure(realAccumulator, randomAccumulator, outputRoot)
layerNames = ["rawMagnitude", "preparedMagnitude", "linearMagnitude", ...
    "filteredMagnitude", "motionEnvelope", "eventSignal"];
layerLabels = ["raw magnitude", "prepared magnitude", "linear magnitude", ...
    "filtered magnitude", "motion envelope", "eventSignal"];
figureHandle = figure('Color', 'w', 'Position', [100 80 1350 900]);
tiledLayoutHandle = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tiledLayoutHandle, 'Event-triggered signal layers: current events vs matched random windows', ...
    'FontSize', 16, 'FontWeight', 'bold');
subtitle(tiledLayoutHandle, 'Traces are median-centered per snippet before averaging; shaded bands are SEM.', 'FontSize', 11);

for layerIndex = 1:numel(layerNames)
    axesHandle = nexttile(tiledLayoutHandle, layerIndex);
    LF_plotMeanSem(axesHandle, realAccumulator.relativeTimeSec, ...
        LF_centerSnippetColumns(realAccumulator.(layerNames(layerIndex))), [0.10 0.25 0.65], 'events');
    LF_plotMeanSem(axesHandle, randomAccumulator.relativeTimeSec, ...
        LF_centerSnippetColumns(randomAccumulator.(layerNames(layerIndex))), [0.65 0.20 0.15], 'matched random');
    xline(axesHandle, 0, '--k', 'HandleVisibility', 'off');
    grid(axesHandle, 'on');
    xlabel(axesHandle, 'time from detected peak (s)');
    ylabel(axesHandle, 'centered amplitude');
    title(axesHandle, layerLabels(layerIndex), 'FontWeight', 'normal');
    if layerIndex == 1
        legend(axesHandle, 'Location', 'northeast', 'Box', 'off');
    end
end

exportgraphics(figureHandle, fullfile(outputRoot, 'event_triggered_signal_layers.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'event_triggered_signal_layers.fig'));
close(figureHandle);
end

function centeredMatrix = LF_centerSnippetColumns(snippetMatrix)
centeredMatrix = snippetMatrix;
for columnIndex = 1:size(snippetMatrix, 2)
    values = snippetMatrix(:, columnIndex);
    centeredMatrix(:, columnIndex) = values - median(values, 'omitnan');
end
end

function LF_plotMeanSem(axesHandle, xValues, snippetMatrix, colorValue, displayName)
meanTrace = mean(snippetMatrix, 2, 'omitnan');
nFinite = sum(isfinite(snippetMatrix), 2);
semTrace = std(snippetMatrix, 0, 2, 'omitnan') ./ sqrt(nFinite);
semTrace(nFinite < 2) = NaN;
finiteMask = isfinite(xValues) & isfinite(meanTrace);
semMask = finiteMask & isfinite(semTrace);
hold(axesHandle, 'on');
if any(semMask)
    fill(axesHandle, [xValues(semMask); flipud(xValues(semMask))], ...
        [meanTrace(semMask) + semTrace(semMask); flipud(meanTrace(semMask) - semTrace(semMask))], ...
        colorValue, 'FaceAlpha', 0.16, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
plot(axesHandle, xValues(finiteMask), meanTrace(finiteMask), ...
    'LineWidth', 2.0, 'Color', colorValue, 'DisplayName', displayName);
end

function LF_makeSignalSupportFigure(eventTable, outputRoot)
figureHandle = figure('Color', 'w', 'Position', [100 80 1300 760]);
tiledLayoutHandle = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tiledLayoutHandle, 'Independent motion support for detected events', ...
    'FontSize', 16, 'FontWeight', 'bold');
subtitle(tiledLayoutHandle, 'Each point is one isolated event paired with one matched random window from the same file.', 'FontSize', 11);

definitions = { ...
    'rawMagnitudeEventEnergy', 'rawMagnitudeRandomEnergy', 'raw magnitude RMS'; ...
    'linearMagnitudeEventEnergy', 'linearMagnitudeRandomEnergy', 'gravity-corrected magnitude RMS'; ...
    'filteredMagnitudeEventEnergy', 'filteredMagnitudeRandomEnergy', 'filtered magnitude RMS'; ...
    'eventSignalEventEnergy', 'eventSignalRandomEnergy', 'eventSignal RMS'};

for definitionIndex = 1:size(definitions, 1)
    axesHandle = nexttile(tiledLayoutHandle, definitionIndex);
    eventValues = eventTable.(definitions{definitionIndex, 1});
    randomValues = eventTable.(definitions{definitionIndex, 2});
    scatter(axesHandle, randomValues, eventValues, 14, 'filled', ...
        'MarkerFaceColor', [0.15 0.35 0.65], 'MarkerFaceAlpha', 0.30);
    hold(axesHandle, 'on');
    maxValue = max([eventValues; randomValues], [], 'omitnan');
    plot(axesHandle, [0 maxValue], [0 maxValue], '--', 'Color', [0.30 0.30 0.30]);
    grid(axesHandle, 'on');
    xlabel(axesHandle, 'matched random');
    ylabel(axesHandle, 'event');
    title(axesHandle, definitions{definitionIndex, 3}, 'FontWeight', 'normal');
end

axesHandle = nexttile(tiledLayoutHandle, 5);
ratioValues = eventTable.linearMagnitudeEventEnergy ./ eventTable.linearMagnitudeRandomEnergy;
histogram(axesHandle, ratioValues(isfinite(ratioValues)), 30, ...
    'FaceColor', [0.15 0.35 0.65], 'EdgeColor', 'none');
xline(axesHandle, 1, '--k');
grid(axesHandle, 'on');
xlabel(axesHandle, 'event / matched-random energy ratio');
ylabel(axesHandle, 'event count');
title(axesHandle, 'Gravity-corrected support ratio', 'FontWeight', 'normal');

axesHandle = nexttile(tiledLayoutHandle, 6);
boxchart(axesHandle, categorical(eventTable.subjectID), ...
    eventTable.linearMagnitudeEventEnergy ./ eventTable.linearMagnitudeRandomEnergy);
yline(axesHandle, 1, '--k');
grid(axesHandle, 'on');
xlabel(axesHandle, 'subject');
ylabel(axesHandle, 'event / random ratio');
title(axesHandle, 'Support ratio by subject', 'FontWeight', 'normal');

exportgraphics(figureHandle, fullfile(outputRoot, 'event_vs_random_motion_support.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'event_vs_random_motion_support.fig'));
close(figureHandle);
end

function LF_makeSimilarityFigure(snippetStore, similaritySummaryTable, outputRoot)
figureHandle = figure('Color', 'w', 'Position', [100 80 1300 760]);
tiledLayoutHandle = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tiledLayoutHandle, 'Normalized snippet similarity controls', ...
    'FontSize', 16, 'FontWeight', 'bold');
subtitle(tiledLayoutHandle, 'Similarity is Pearson correlation after per-snippet median-centering and amplitude normalization.', 'FontSize', 11);

definitions = { ...
    'eventSignal', 'randomEventSignal', 'eventSignal'; ...
    'linearMagnitude', 'randomLinearMagnitude', 'linear magnitude'; ...
    'filteredMagnitude', 'randomFilteredMagnitude', 'filtered magnitude'};

for definitionIndex = 1:size(definitions, 1)
    axesHandle = nexttile(tiledLayoutHandle, definitionIndex);
    eventMatrix = LF_cellSnippetsToMatrix(snippetStore.(definitions{definitionIndex, 1}));
    randomMatrix = LF_cellSnippetsToMatrix(snippetStore.(definitions{definitionIndex, 2}));
    eventEventValues = LF_upperTriangleCorrelations(eventMatrix);
    randomRandomValues = LF_upperTriangleCorrelations(randomMatrix);
    eventRandomValues = LF_crossCorrelations(eventMatrix, randomMatrix);
    hold(axesHandle, 'on');
    LF_plotCdf(axesHandle, eventEventValues, [0.10 0.25 0.65], 'event-event');
    LF_plotCdf(axesHandle, randomRandomValues, [0.65 0.20 0.15], 'random-random');
    LF_plotCdf(axesHandle, eventRandomValues, [0.25 0.25 0.25], 'event-random');
    grid(axesHandle, 'on');
    xlim(axesHandle, [-1 1]);
    xlabel(axesHandle, 'snippet similarity');
    ylabel(axesHandle, 'CDF');
    title(axesHandle, definitions{definitionIndex, 3}, 'FontWeight', 'normal');
    if definitionIndex == 1
        legend(axesHandle, 'Location', 'southeast', 'Box', 'off');
    end
end

axesHandle = nexttile(tiledLayoutHandle, 4);
barData = [similaritySummaryTable.eventEventMedianSimilarity, ...
    similaritySummaryTable.randomRandomMedianSimilarity, ...
    similaritySummaryTable.eventRandomMedianSimilarity];
bar(axesHandle, barData);
axesHandle.XTickLabel = similaritySummaryTable.signalName;
axesHandle.XTickLabelRotation = 20;
legend(axesHandle, {'event-event', 'random-random', 'event-random'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
grid(axesHandle, 'on');
ylabel(axesHandle, 'median similarity');
title(axesHandle, 'Median similarity summary', 'FontWeight', 'normal');

exportgraphics(figureHandle, fullfile(outputRoot, 'normalized_similarity_controls.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'normalized_similarity_controls.fig'));
close(figureHandle);
end

function LF_plotCdf(axesHandle, values, colorValue, displayName)
values = values(isfinite(values));
if isempty(values)
    return;
end
values = sort(values(:));
yValues = (1:numel(values)) ./ numel(values);
plot(axesHandle, values, yValues, 'LineWidth', 2.0, 'Color', colorValue, 'DisplayName', displayName);
end

function LF_makeSurrogateFigure(surrogateSummaryTable, outputRoot)
figureHandle = figure('Color', 'w', 'Position', [100 80 1250 620]);
tiledLayoutHandle = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tiledLayoutHandle, 'Surrogate detector controls', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(tiledLayoutHandle, 'Surrogates preserve parts of the envelope distribution or spectrum but should not preserve true event timing.', 'FontSize', 11);

axesHandle = nexttile(tiledLayoutHandle, 1);
boxchart(axesHandle, categorical(surrogateSummaryTable.surrogateType), surrogateSummaryTable.nDetected);
grid(axesHandle, 'on');
ylabel(axesHandle, 'detected peaks');
title(axesHandle, 'Detected peaks in surrogates', 'FontWeight', 'normal');

axesHandle = nexttile(tiledLayoutHandle, 2);
boxchart(axesHandle, categorical(surrogateSummaryTable.surrogateType), surrogateSummaryTable.nIsolated);
grid(axesHandle, 'on');
ylabel(axesHandle, 'isolated peaks');
title(axesHandle, 'Isolated peaks in surrogates', 'FontWeight', 'normal');

axesHandle = nexttile(tiledLayoutHandle, 3);
boxchart(axesHandle, categorical(surrogateSummaryTable.surrogateType), surrogateSummaryTable.medianEventSignalSimilarity);
grid(axesHandle, 'on');
ylabel(axesHandle, 'median normalized similarity');
title(axesHandle, 'Surrogate event-shape similarity', 'FontWeight', 'normal');

exportgraphics(figureHandle, fullfile(outputRoot, 'surrogate_detector_controls.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'surrogate_detector_controls.fig'));
close(figureHandle);
end

function LF_makeTimingAndContaminationFigure(eventTable, fileSummaryTable, outputRoot)
figureHandle = figure('Color', 'w', 'Position', [100 80 1350 760]);
tiledLayoutHandle = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tiledLayoutHandle, 'Timing and contamination checks', 'FontSize', 16, 'FontWeight', 'bold');

axesHandle = nexttile(tiledLayoutHandle, 1);
histogram(axesHandle, mod(eventTable.peakTimeSec, 1.0), 20, ...
    'FaceColor', [0.25 0.25 0.25], 'EdgeColor', 'none');
grid(axesHandle, 'on');
xlabel(axesHandle, 'peak time modulo 1 s');
ylabel(axesHandle, 'event count');
title(axesHandle, 'RMS-window phase check', 'FontWeight', 'normal');

axesHandle = nexttile(tiledLayoutHandle, 2);
histogram(axesHandle, eventTable.secondaryPeakRatio, 30, ...
    'FaceColor', [0.15 0.35 0.65], 'EdgeColor', 'none');
xline(axesHandle, 0.5, '--k');
grid(axesHandle, 'on');
xlabel(axesHandle, 'largest secondary peak / main peak');
ylabel(axesHandle, 'event count');
title(axesHandle, 'Subthreshold-neighbor contamination score', 'FontWeight', 'normal');

axesHandle = nexttile(tiledLayoutHandle, 3);
scatter(axesHandle, eventTable.secondaryPeakRatio, ...
    eventTable.linearMagnitudeEventEnergy ./ eventTable.linearMagnitudeRandomEnergy, ...
    18, 'filled', 'MarkerFaceAlpha', 0.35);
yline(axesHandle, 1, '--k');
grid(axesHandle, 'on');
xlabel(axesHandle, 'secondary peak ratio');
ylabel(axesHandle, 'linear event/random support');
title(axesHandle, 'Contamination vs raw support', 'FontWeight', 'normal');

axesHandle = nexttile(tiledLayoutHandle, 4);
bar(axesHandle, categorical(fileSummaryTable.subjectID + "_" + erase(fileSummaryTable.condition, "_stand")), ...
    fileSummaryTable.nIsolated);
axesHandle.XTickLabelRotation = 45;
grid(axesHandle, 'on');
ylabel(axesHandle, 'isolated events');
title(axesHandle, 'Isolated event counts', 'FontWeight', 'normal');

axesHandle = nexttile(tiledLayoutHandle, 5);
boxchart(axesHandle, categorical(eventTable.subjectID), eventTable.secondaryPeakRatio);
yline(axesHandle, 0.5, '--k');
grid(axesHandle, 'on');
xlabel(axesHandle, 'subject');
ylabel(axesHandle, 'secondary peak ratio');
title(axesHandle, 'Contamination by subject', 'FontWeight', 'normal');

axesHandle = nexttile(tiledLayoutHandle, 6);
boxchart(axesHandle, categorical(eventTable.condition), eventTable.secondaryPeakRatio);
yline(axesHandle, 0.5, '--k');
grid(axesHandle, 'on');
xlabel(axesHandle, 'condition');
ylabel(axesHandle, 'secondary peak ratio');
title(axesHandle, 'Contamination by condition', 'FontWeight', 'normal');

exportgraphics(figureHandle, fullfile(outputRoot, 'timing_and_contamination_checks.png'), 'Resolution', 180);
savefig(figureHandle, fullfile(outputRoot, 'timing_and_contamination_checks.fig'));
close(figureHandle);
end

function LF_writeReport(scratchRoot, outputRoot, tableRoot, fileSummaryTable, eventTable, surrogateTable, similarityTable)
reportPath = fullfile(scratchRoot, 'UNITARY_EVENT_VALIDATION_REPORT.md');
eventRandomRatio = eventTable.linearMagnitudeEventEnergy ./ eventTable.linearMagnitudeRandomEnergy;
filteredRandomRatio = eventTable.filteredMagnitudeEventEnergy ./ eventTable.filteredMagnitudeRandomEnergy;
eventSignalRandomRatio = eventTable.eventSignalEventEnergy ./ eventTable.eventSignalRandomEnergy;
highContaminationMask = eventTable.secondaryPeakRatio >= 0.5;

fid = fopen(reportPath, 'w');
cleanupObject = onCleanup(@() fclose(fid));

fprintf(fid, '# Unitary Event Validation Study (2026-05-08)\n\n');
fprintf(fid, 'This scratch study freezes the current Waseda chest-envelope detector and asks whether the accepted isolated events have independent raw-motion support beyond the scalar envelope/eventSignal layer.\n\n');
fprintf(fid, '## Files\n\n');
fprintf(fid, '- Figures: `%s`\n', outputRoot);
fprintf(fid, '- Tables: `%s`\n', tableRoot);
fprintf(fid, '- MATLAB workspace: `%s`\n\n', fullfile(scratchRoot, 'unitary_event_validation_workspace.mat'));

fprintf(fid, '## Current Detector Sample\n\n');
fprintf(fid, '- Files analyzed: `%d`\n', height(fileSummaryTable));
fprintf(fid, '- Total detected peaks: `%d`\n', sum(fileSummaryTable.nDetected));
fprintf(fid, '- Total isolated events: `%d`\n', sum(fileSummaryTable.nIsolated));
fprintf(fid, '- Median isolated events per file: `%.1f`\n', median(fileSummaryTable.nIsolated, 'omitnan'));
fprintf(fid, '- Median prepared bad-sample fraction: `%.4f`\n', median(fileSummaryTable.preparedBadSampleFraction, 'omitnan'));
fprintf(fid, '- Median envelope artefact fraction: `%.4f`\n\n', median(fileSummaryTable.envelopeBadArtefactFraction, 'omitnan'));

fprintf(fid, '## Raw-Motion Support\n\n');
fprintf(fid, '- Median gravity-corrected magnitude event/random RMS ratio: `%.3f`\n', median(eventRandomRatio, 'omitnan'));
fprintf(fid, '- Median filtered magnitude event/random RMS ratio: `%.3f`\n', median(filteredRandomRatio, 'omitnan'));
fprintf(fid, '- Median eventSignal event/random RMS ratio: `%.3f`\n', median(eventSignalRandomRatio, 'omitnan'));
fprintf(fid, '- Fraction of events with gravity-corrected event/random ratio > 1: `%.3f`\n\n', mean(eventRandomRatio > 1, 'omitnan'));

fprintf(fid, 'Interpretation: if the first two ratios are clearly above 1, the detector is not only finding a mathematical peak in the rectified eventSignal; the same times also carry stronger raw or gravity-corrected acceleration structure than matched random windows from the same recordings.\n\n');

fprintf(fid, '## Normalized Similarity Controls\n\n');
for rowIndex = 1:height(similarityTable)
    fprintf(fid, '- `%s`: event-event median `%.3f`, random-random median `%.3f`, event-random median `%.3f`\n', ...
        similarityTable.signalName(rowIndex), ...
        similarityTable.eventEventMedianSimilarity(rowIndex), ...
        similarityTable.randomRandomMedianSimilarity(rowIndex), ...
        similarityTable.eventRandomMedianSimilarity(rowIndex));
end
fprintf(fid, '\nInterpretation: a credible event class should be more self-similar than matched random windows, especially outside the eventSignal layer. Similarity restricted to eventSignal alone is weaker evidence because the detector is defined on that signal.\n\n');

fprintf(fid, '## Surrogate Controls\n\n');
surrogateTypes = unique(string(surrogateTable.surrogateType), 'stable');
for surrogateTypeIndex = 1:numel(surrogateTypes)
    currentType = surrogateTypes(surrogateTypeIndex);
    mask = string(surrogateTable.surrogateType) == currentType;
    fprintf(fid, '- `%s`: median detected `%0.1f`, median isolated `%0.1f`, median shape similarity `%.3f`\n', ...
        currentType, ...
        median(surrogateTable.nDetected(mask), 'omitnan'), ...
        median(surrogateTable.nIsolated(mask), 'omitnan'), ...
        median(surrogateTable.medianEventSignalSimilarity(mask), 'omitnan'));
end
fprintf(fid, '\nInterpretation: surrogates producing many isolated events, or producing eventSignal similarity close to the real eventSignal similarity, weaken a strong unitary-event claim. They indicate that the envelope spectrum, chunk structure, detector threshold, or boundary rules can manufacture plausible-looking event shapes.\n\n');

fprintf(fid, '## Contamination / Compound-Event Risk\n\n');
fprintf(fid, '- Median secondary-peak ratio: `%.3f`\n', median(eventTable.secondaryPeakRatio, 'omitnan'));
fprintf(fid, '- Fraction with secondary-peak ratio >= 0.5: `%.3f`\n', mean(highContaminationMask, 'omitnan'));
fprintf(fid, '- Median gravity-corrected support ratio for lower-contamination events: `%.3f`\n', median(eventRandomRatio(~highContaminationMask), 'omitnan'));
fprintf(fid, '- Median gravity-corrected support ratio for high-contamination events: `%.3f`\n\n', median(eventRandomRatio(highContaminationMask), 'omitnan'));

fprintf(fid, 'Interpretation: the current isolated-event flag only excludes nearby detected peaks. The secondary-peak score checks for subthreshold neighbors inside the aligned window. High values mean the event may be a fragment or compound local movement rather than one clean primitive unit.\n\n');

fprintf(fid, '## Figures To Inspect\n\n');
fprintf(fid, '- `event_triggered_signal_layers.png`: whether the event times have visible support in raw/prepared/linear/filtered signals, not only eventSignal.\n');
fprintf(fid, '- `event_vs_random_motion_support.png`: event-vs-random energy scatter and support ratios.\n');
fprintf(fid, '- `normalized_similarity_controls.png`: event-event, random-random, and event-random morphology similarity.\n');
fprintf(fid, '- `surrogate_detector_controls.png`: how easily the same detector finds isolated events in surrogate signals.\n');
fprintf(fid, '- `timing_and_contamination_checks.png`: RMS-window phase, event counts, and subthreshold-neighbor contamination.\n\n');

fprintf(fid, '## Current Read\n\n');
fprintf(fid, 'The strictest interpretation should combine all controls. Real-motion support above matched random windows argues against a pure scalar-envelope artifact. However, if surrogate signals still produce many isolated and self-similar events, then the current detector is also partially shape-imposing. In that case the right next step is not to claim a final unitary event, but to stratify by contamination score and rerun morphology summaries on the cleanest subset while reporting surrogate sensitivity.\n');
end
