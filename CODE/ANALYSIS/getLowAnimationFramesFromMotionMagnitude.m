function [lowMask, lowFrameIdx, bouts, details] = getLowAnimationFramesFromMotionMagnitude(motionVec, timeVec, varargin)
% getLowAnimationFramesFromMotionMagnitude - Classify low-animation frames from a motion trace.
%
% Usage:
%   lowMask = getLowAnimationFramesFromMotionMagnitude(motionVec, timeVec)
%   [lowMask, idx, bouts, details] = getLowAnimationFramesFromMotionMagnitude( ...
%       motionVec, timeVec, 'threshold', 40, ...
%       'minLowDurationSec', 0.5, 'maxHighGapSec', 0.1)
%
% Inputs:
%   motionVec - nSamples x 1 vector of motion magnitude values
%   timeVec   - nSamples x 1 vector of timestamps in seconds
%
% Name-value pairs:
%   'threshold'         - low-animation threshold; default 40
%   'minLowDurationSec' - low runs shorter than this are removed; default 0.5 s
%   'maxHighGapSec'     - high runs shorter than or equal to this are filled
%                         back into the low-animation mask; default 0.1 s
%
% Outputs:
%   lowMask      - logical nSamples x 1 mask of frames in the cleaned low-animation regime
%   lowFrameIdx  - indices where lowMask is true
%   bouts        - struct array with fields startIdx, endIdx, nFrames, durationSec
%   details      - struct with thresholding metadata and intermediate masks

    p = inputParser;
    addRequired(p, 'motionVec', @(x) isnumeric(x) && isvector(x));
    addRequired(p, 'timeVec', @(x) isnumeric(x) && isvector(x));
    addParameter(p, 'threshold', 40, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
    addParameter(p, 'minLowDurationSec', 0.5, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
    addParameter(p, 'maxHighGapSec', 0.1, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
    parse(p, motionVec, timeVec, varargin{:});

    motionVec = motionVec(:);
    timeVec = timeVec(:);
    if numel(motionVec) ~= numel(timeVec)
        error('getLowAnimationFramesFromMotionMagnitude:SizeMismatch', ...
            'motionVec and timeVec must have the same number of samples.');
    end

    lowMask = false(size(motionVec));
    lowFrameIdx = [];
    bouts = struct('startIdx', {}, 'endIdx', {}, 'nFrames', {}, 'durationSec', {});
    details = struct('threshold', p.Results.threshold, ...
        'minLowDurationSec', p.Results.minLowDurationSec, ...
        'maxHighGapSec', p.Results.maxHighGapSec, ...
        'sampleRateHz', NaN, ...
        'rawMask', false(size(motionVec)), ...
        'afterShortHighFillMask', false(size(motionVec)));

    if isempty(motionVec)
        return;
    end

    dt = diff(timeVec);
    dt = dt(isfinite(dt) & dt > 0);
    if isempty(dt)
        return;
    end
    sampleRate = 1 / median(dt, 'omitnan');
    if ~isfinite(sampleRate) || sampleRate <= 0
        return;
    end
    details.sampleRateHz = sampleRate;

    rawMask = motionVec < p.Results.threshold;
    rawMask(~isfinite(motionVec)) = false;
    details.rawMask = rawMask;
    if ~any(rawMask)
        return;
    end

    % Fill brief excursions above threshold so instantaneous spikes do not
    % fragment otherwise low-animation periods.
    maxHighFrames = max(0, round(p.Results.maxHighGapSec * sampleRate));
    gapFilledMask = rawMask;
    if maxHighFrames > 0
        gapFilledMask = localFillShortFalseRuns(rawMask, maxHighFrames);
    end
    details.afterShortHighFillMask = gapFilledMask;

    % Keep only sustained low-animation runs.
    minLowFrames = max(1, round(p.Results.minLowDurationSec * sampleRate));
    lowMask = localKeepLongTrueRuns(gapFilledMask, minLowFrames);

    lowFrameIdx = find(lowMask);
    bouts = localMaskToBouts(lowMask, sampleRate);
end

function outMask = localFillShortFalseRuns(inMask, maxFalseFrames)
    outMask = inMask;
    d = diff([true; inMask(:); true]);
    starts = find(d == -1);
    ends = find(d == 1) - 1;
    for i = 1:numel(starts)
        runLen = ends(i) - starts(i) + 1;
        if runLen <= maxFalseFrames
            outMask(starts(i):ends(i)) = true;
        end
    end
end

function outMask = localKeepLongTrueRuns(inMask, minTrueFrames)
    outMask = false(size(inMask));
    d = diff([false; inMask(:); false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    for i = 1:numel(starts)
        runLen = ends(i) - starts(i) + 1;
        if runLen >= minTrueFrames
            outMask(starts(i):ends(i)) = true;
        end
    end
end

function bouts = localMaskToBouts(mask, sampleRate)
    d = diff([false; mask(:); false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    bouts = repmat(struct('startIdx', [], 'endIdx', [], 'nFrames', [], 'durationSec', []), numel(starts), 1);
    for i = 1:numel(starts)
        nFrames = ends(i) - starts(i) + 1;
        bouts(i).startIdx = starts(i);
        bouts(i).endIdx = ends(i);
        bouts(i).nFrames = nFrames;
        bouts(i).durationSec = nFrames / sampleRate;
    end
end
