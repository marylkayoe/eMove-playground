function [eventTimes, eventValues, peakWidths] = detectEnvelopeEvents(eventSignal, noiseSignal, varargin)
    % searching events that qualify as significant peaks in the envelope signal, based on a noise estimate

    % inputs
    %   eventSignal: vector of envelope signal values above baseline
    %   noiseSignal: vector of noise signal values (same length as envelopeSignal), contains 
    %       the noise estimate for each sample in the envelope signal, also the eventSignal (signal above the baseline)
% optional inputs
% thresholdSigma - scalar, number of noise standard deviations above the baseline to consider as an event (default: 3)
% trialID - string to be used in plotting title (default: '')

% parse inputs
P = inputParser;

addParameter(P, 'ThresholdSigma', 3, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);
    addParameter(P, 'SamplingFrequency', 31.25, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

    addParameter(P, 'TrialID', '', ...
    @(value) ischar(value) || isstring(value));
 parse(P, varargin{:}); 

thresholdSigma = P.Results.ThresholdSigma;
samplingFrequency = P.Results.SamplingFrequency;
trialID = P.Results.TrialID;
typicalNoiseSigma = median(noiseSignal, 'omitnan');

minimumPeakHeight = thresholdSigma .* typicalNoiseSigma;
minimumPeakDistanceSeconds = 0.5;
minimumPeakDistanceSamples = round(minimumPeakDistanceSeconds * samplingFrequency);

%% detect peaks in the eventSignal signal using the minimumPeakHeight as the threshold, display the found events
[peakValues, peakSampleIndex, peakWidths, peakProminences]  = findpeaks(eventSignal, 'MinPeakHeight', minimumPeakHeight, 'MinPeakDistance', minimumPeakDistanceSamples);


valleyFraction = 0.2;

keepPeak = LF_keepPeaksSeparatedByValleys(eventSignal,  peakSampleIndex,  peakValues, valleyFraction);
peakValues = peakValues(keepPeak);
peakLocations = peakSampleIndex(keepPeak);
peakWidths = peakWidths(keepPeak);
peakProminences = peakProminences(keepPeak);


eventTimes = peakLocations; % convert from sample indices to time if needed
eventValues = peakValues;
% create a time axis in seconds for plotting
xAx = (0:length(eventSignal)-1) / samplingFrequency;

figure; 
plot(xAx, eventSignal, 'b'); hold on;
% plot event locations as red filed circles, no edge color, with the same size as the default markersize
plot(eventTimes / samplingFrequency, eventValues,  'ro', 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'none', 'MarkerSize', 10);
xlabel('Time(s )');
ylabel('Envelope Signal');
title(trialID);
legend('Envelope Signal', 'Detected Events');
grid on;
end


function keepPeak = LF_keepPeaksSeparatedByValleys(eventSignal, peakSampleIndex, peakValues, valleyFraction)
%KEEPPEAKSSEPARATEDBYVALLEYS Merge nearby peaks unless the signal drops enough between them.
%
% A later peak is considered separate only if the signal between it and the
% previous kept peak drops below:
%
%   valleyFraction * min(previousPeakValue, currentPeakValue)
%
% If the valley is not deep enough, the two peaks are treated as the same
% event and only the larger peak is kept.

keepPeak = true(size(peakSampleIndex));

if numel(peakSampleIndex) <= 1
    return
end

currentKeptIndex = 1;

for peakIndex = 2:numel(peakSampleIndex)

    previousSample = peakSampleIndex(currentKeptIndex);
    currentSample = peakSampleIndex(peakIndex);

    intervalSignal = eventSignal(previousSample:currentSample);
    valleyValue = min(intervalSignal);

    separationThreshold = valleyFraction * min( ...
        peakValues(currentKeptIndex), ...
        peakValues(peakIndex));

    valleyIsDeepEnough = valleyValue < separationThreshold;

    if valleyIsDeepEnough

        currentKeptIndex = peakIndex;

    else

        % Same event. Keep the larger of the two peaks.
        if peakValues(peakIndex) > peakValues(currentKeptIndex)
            keepPeak(currentKeptIndex) = false;
            currentKeptIndex = peakIndex;
        else
            keepPeak(peakIndex) = false;
        end

    end

end

end