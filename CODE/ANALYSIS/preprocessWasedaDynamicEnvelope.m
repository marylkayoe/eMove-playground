function [envAnalysis, envDisplay, artifactMask] = preprocessWasedaDynamicEnvelope(timesSec, envIn, varargin)
%PREPROCESSWASEDADYNAMICENVELOPE Remove clear envelope outliers for analysis and plotting.
%
% envDisplay is blanked at artifact samples so figures show gaps.
% envAnalysis linearly interpolates across those gaps for stable-band estimation
% and event detection.

p = inputParser;
p.addParameter('artifactThreshold', 0.5, @isscalar);
p.parse(varargin{:});
opts = p.Results;

artifactMask = envIn >= opts.artifactThreshold;
envDisplay = envIn;
envDisplay(artifactMask) = NaN;

envAnalysis = envDisplay;
validMask = ~artifactMask & ~isnan(envIn);
if all(validMask)
    envAnalysis = envIn;
    return;
end

validTimes = timesSec(validMask);
validValues = envIn(validMask);
if numel(validValues) >= 2
    [validTimes, uniqueIdx] = unique(validTimes, 'stable');
    validValues = validValues(uniqueIdx);
    if numel(validValues) >= 2
        envAnalysis = interp1(validTimes, validValues, timesSec, 'linear', 'extrap');
    else
        envAnalysis = repmat(validValues(1), size(envIn));
    end
elseif numel(validValues) == 1
    envAnalysis = repmat(validValues, size(envIn));
else
    envAnalysis = zeros(size(envIn));
end
end
