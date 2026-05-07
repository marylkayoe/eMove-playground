function boundaryOutput = estimateEnvelopeEventDerivativeBoundaries(signal, peakLocations, samplingFrequency, varargin)
%ESTIMATEENVELOPEEVENTDERIVATIVEBOUNDARIES Estimate event limits from derivative notches.
%
% boundaryOutput = estimateEnvelopeEventDerivativeBoundaries(signal, peakLocations, samplingFrequency)
%
% Purpose
%   Provide an alternative event-limit estimate without redetecting peaks.
%   The method searches for strong positive second-derivative points on the
%   rising and falling flanks of each already-detected event peak. These
%   flank curvature points are candidate "notches" where the event enters
%   or exits its steep central phase.
%
% Important assumption
%   This function does not decide whether an event exists. It only proposes
%   alternative boundaries for peak locations supplied by the existing
%   detector.
%
% Inputs
%   signal
%       Baseline-relative event signal or comparable 1D envelope signal.
%   peakLocations
%       Sample indices from the existing detector.
%   samplingFrequency
%       Sampling frequency in Hz.
%
% Optional name-value inputs
%   'TimeSec'                    default []
%   'PreWindowSeconds'           default 2.0
%   'PostWindowSeconds'          default 2.0
%   'SmoothingWindowSeconds'     default 0.20
%   'MaxStartFractionOfPeak'     default 0.70
%   'MaxEndFractionOfPeak'       default 0.85
%   'MinDerivativeFraction'      default 0.05
%
% Output
%   boundaryOutput.boundaryTable
%   boundaryOutput.smoothedSignal
%   boundaryOutput.firstDerivative
%   boundaryOutput.secondDerivative
%   boundaryOutput.options

inputParserObject = inputParser;

addRequired(inputParserObject, 'signal', @(value) isnumeric(value) && isvector(value));
addRequired(inputParserObject, 'peakLocations', @(value) isnumeric(value) && isvector(value));
addRequired(inputParserObject, 'samplingFrequency', ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'TimeSec', [], ...
    @(value) isempty(value) || (isnumeric(value) && isvector(value)));
addParameter(inputParserObject, 'PreWindowSeconds', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);
addParameter(inputParserObject, 'PostWindowSeconds', 2.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);
addParameter(inputParserObject, 'SmoothingWindowSeconds', 0.20, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);
addParameter(inputParserObject, 'MaxStartFractionOfPeak', 0.70, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0 && value <= 1);
addParameter(inputParserObject, 'MaxEndFractionOfPeak', 0.85, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0 && value <= 1);
addParameter(inputParserObject, 'MinDerivativeFraction', 0.05, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0 && value <= 1);

parse(inputParserObject, signal, peakLocations, samplingFrequency, varargin{:});

signal = inputParserObject.Results.signal(:);
peakLocations = round(inputParserObject.Results.peakLocations(:));
samplingFrequency = inputParserObject.Results.samplingFrequency;
timeSec = inputParserObject.Results.TimeSec;

if ~isempty(timeSec)
    timeSec = timeSec(:);
    if numel(timeSec) ~= numel(signal)
        error('estimateEnvelopeEventDerivativeBoundaries:TimeLengthMismatch', ...
            'TimeSec must have the same number of samples as signal.');
    end
end

nSamples = numel(signal);
peakLocations = peakLocations(isfinite(peakLocations));
peakLocations = peakLocations(peakLocations >= 1 & peakLocations <= nSamples);
peakLocations = unique(peakLocations, 'stable');

preWindowSamples = max(1, round(inputParserObject.Results.PreWindowSeconds .* samplingFrequency));
postWindowSamples = max(1, round(inputParserObject.Results.PostWindowSeconds .* samplingFrequency));
smoothingSamples = max(3, round(inputParserObject.Results.SmoothingWindowSeconds .* samplingFrequency));
if mod(smoothingSamples, 2) == 0
    smoothingSamples = smoothingSamples + 1;
end

smoothedSignal = smoothdata(signal, 'movmean', smoothingSamples, 'omitnan');
firstDerivative = gradient(smoothedSignal) .* samplingFrequency;
secondDerivative = gradient(firstDerivative) .* samplingFrequency;

nEvents = numel(peakLocations);
boundaryRows = repmat(struct( ...
    'peakIndex', NaN, ...
    'startIndexDerivative', NaN, ...
    'endIndexDerivative', NaN, ...
    'peakValue', NaN, ...
    'startValueDerivative', NaN, ...
    'endValueDerivative', NaN, ...
    'startTimeSecDerivative', NaN, ...
    'endTimeSecDerivative', NaN, ...
    'durationSamplesDerivative', NaN, ...
    'durationSecDerivative', NaN, ...
    'startSecondDerivative', NaN, ...
    'endSecondDerivative', NaN, ...
    'startBoundaryQuality', NaN, ...
    'endBoundaryQuality', NaN), nEvents, 1);

for eventIndex = 1:nEvents
    peakIndex = peakLocations(eventIndex);
    peakValue = smoothedSignal(peakIndex);

    startIndex = localFindDerivativeBoundary( ...
        smoothedSignal, firstDerivative, secondDerivative, peakIndex, ...
        max(1, peakIndex - preWindowSamples), peakIndex, ...
        peakValue, inputParserObject.Results.MaxStartFractionOfPeak, ...
        inputParserObject.Results.MinDerivativeFraction, "start");

    endIndex = localFindDerivativeBoundary( ...
        smoothedSignal, firstDerivative, secondDerivative, peakIndex, ...
        peakIndex, min(nSamples, peakIndex + postWindowSamples), ...
        peakValue, inputParserObject.Results.MaxEndFractionOfPeak, ...
        inputParserObject.Results.MinDerivativeFraction, "end");

    boundaryRows(eventIndex).peakIndex = peakIndex;
    boundaryRows(eventIndex).startIndexDerivative = startIndex;
    boundaryRows(eventIndex).endIndexDerivative = endIndex;
    boundaryRows(eventIndex).peakValue = signal(peakIndex);
    boundaryRows(eventIndex).startValueDerivative = signal(startIndex);
    boundaryRows(eventIndex).endValueDerivative = signal(endIndex);
    boundaryRows(eventIndex).durationSamplesDerivative = endIndex - startIndex + 1;
    boundaryRows(eventIndex).startSecondDerivative = secondDerivative(startIndex);
    boundaryRows(eventIndex).endSecondDerivative = secondDerivative(endIndex);
    boundaryRows(eventIndex).startBoundaryQuality = localBoundaryQuality(secondDerivative, startIndex, max(1, peakIndex - preWindowSamples), peakIndex);
    boundaryRows(eventIndex).endBoundaryQuality = localBoundaryQuality(secondDerivative, endIndex, peakIndex, min(nSamples, peakIndex + postWindowSamples));

    if ~isempty(timeSec)
        boundaryRows(eventIndex).startTimeSecDerivative = timeSec(startIndex);
        boundaryRows(eventIndex).endTimeSecDerivative = timeSec(endIndex);
        boundaryRows(eventIndex).durationSecDerivative = timeSec(endIndex) - timeSec(startIndex);
    else
        boundaryRows(eventIndex).durationSecDerivative = ...
            boundaryRows(eventIndex).durationSamplesDerivative ./ samplingFrequency;
    end
end

boundaryOutput = struct();
boundaryOutput.boundaryTable = struct2table(boundaryRows);
boundaryOutput.smoothedSignal = smoothedSignal;
boundaryOutput.firstDerivative = firstDerivative;
boundaryOutput.secondDerivative = secondDerivative;
boundaryOutput.options = inputParserObject.Results;

end

function boundaryIndex = localFindDerivativeBoundary(smoothedSignal, firstDerivative, secondDerivative, peakIndex, searchStartIndex, searchEndIndex, peakValue, maxFractionOfPeak, minDerivativeFraction, side)
searchIndices = (searchStartIndex:searchEndIndex).';
if isempty(searchIndices)
    boundaryIndex = peakIndex;
    return;
end

if ~isfinite(peakValue) || peakValue <= 0
    peakValue = max(smoothedSignal(searchIndices), [], 'omitnan');
end

signalFraction = smoothedSignal(searchIndices) ./ max(peakValue, eps);
candidateMask = signalFraction <= maxFractionOfPeak;

if side == "start"
    candidateMask = candidateMask & firstDerivative(searchIndices) >= 0;
else
    candidateMask = candidateMask & firstDerivative(searchIndices) <= 0;
end

positiveCurvature = secondDerivative(searchIndices);
positiveCurvature(~isfinite(positiveCurvature)) = -Inf;
maximumCurvature = max(positiveCurvature(candidateMask), [], 'omitnan');

if isempty(maximumCurvature) || ~isfinite(maximumCurvature)
    candidateMask = true(size(searchIndices));
    maximumCurvature = max(positiveCurvature, [], 'omitnan');
end

curvatureThreshold = minDerivativeFraction .* maximumCurvature;
candidateMask = candidateMask & positiveCurvature >= curvatureThreshold;

if ~any(candidateMask)
    candidateMask = true(size(searchIndices));
end

candidateIndices = searchIndices(candidateMask);
[~, maximumOffset] = max(secondDerivative(candidateIndices));
boundaryIndex = candidateIndices(maximumOffset);
end

function qualityValue = localBoundaryQuality(secondDerivative, boundaryIndex, searchStartIndex, searchEndIndex)
searchIndices = searchStartIndex:searchEndIndex;
searchValues = secondDerivative(searchIndices);
searchValues = searchValues(isfinite(searchValues));

if isempty(searchValues)
    qualityValue = NaN;
    return;
end

scaleValue = max(abs(searchValues), [], 'omitnan');
if ~isfinite(scaleValue) || scaleValue <= 0
    qualityValue = NaN;
else
    qualityValue = secondDerivative(boundaryIndex) ./ scaleValue;
end
end
