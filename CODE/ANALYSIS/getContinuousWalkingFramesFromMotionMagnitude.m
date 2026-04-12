function [walkMask, walkFrameIdx, bouts, details] = getContinuousWalkingFramesFromMotionMagnitude(motionVec, timeVec, varargin)
% getContinuousWalkingFramesFromMotionMagnitude - Classify sustained walking frames from a motion trace.
%
% Usage:
%   walkMask = getContinuousWalkingFramesFromMotionMagnitude(motionVec, timeVec)
%   [walkMask, idx, bouts, details] = getContinuousWalkingFramesFromMotionMagnitude( ...
%       motionVec, timeVec, 'threshold', 100, ...
%       'minWalkDurationSec', 1.0, 'maxLowGapSec', 0.25)
%
% Inputs:
%   motionVec - nSamples x 1 vector of motion magnitude values
%   timeVec   - nSamples x 1 vector of timestamps in seconds
%
% Name-value pairs:
%   'threshold'          - walking threshold; default 100
%   'minWalkDurationSec' - high-motion runs shorter than this are removed; default 1.0 s
%   'maxLowGapSec'       - low-motion interruptions shorter than or equal
%                          to this are filled back into the walking mask; default 0.25 s
%
% Outputs:
%   walkMask      - logical nSamples x 1 mask of frames in cleaned walking bouts
%   walkFrameIdx  - indices where walkMask is true
%   bouts         - struct array with fields startIdx, endIdx, nFrames, durationSec
%   details       - struct with metadata and intermediate masks

    p = inputParser;
    addRequired(p, 'motionVec', @(x) isnumeric(x) && isvector(x));
    addRequired(p, 'timeVec', @(x) isnumeric(x) && isvector(x));
    addParameter(p, 'threshold', 100, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
    addParameter(p, 'minWalkDurationSec', 1.0, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
    addParameter(p, 'maxLowGapSec', 0.25, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
    parse(p, motionVec, timeVec, varargin{:});

    motionVec = motionVec(:);
    timeVec = timeVec(:);
    if numel(motionVec) ~= numel(timeVec)
        error('getContinuousWalkingFramesFromMotionMagnitude:SizeMismatch', ...
            'motionVec and timeVec must have the same number of samples.');
    end

    walkMask = false(size(motionVec));
    walkFrameIdx = [];
    bouts = struct('startIdx', {}, 'endIdx', {}, 'nFrames', {}, 'durationSec', {});
    details = struct('threshold', p.Results.threshold, ...
        'minWalkDurationSec', p.Results.minWalkDurationSec, ...
        'maxLowGapSec', p.Results.maxLowGapSec, ...
        'sampleRateHz', NaN, ...
        'rawMask', false(size(motionVec)), ...
        'afterShortLowFillMask', false(size(motionVec)));

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

    rawMask = motionVec > p.Results.threshold;
    rawMask(~isfinite(motionVec)) = false;
    details.rawMask = rawMask;
    if ~any(rawMask)
        return;
    end

    maxLowFrames = max(0, round(p.Results.maxLowGapSec * sampleRate));
    gapFilledMask = rawMask;
    if maxLowFrames > 0
        gapFilledMask = localFillShortFalseRuns(rawMask, maxLowFrames);
    end
    details.afterShortLowFillMask = gapFilledMask;

    minWalkFrames = max(1, round(p.Results.minWalkDurationSec * sampleRate));
    walkMask = localKeepLongTrueRuns(gapFilledMask, minWalkFrames);

    walkFrameIdx = find(walkMask);
    bouts = localMaskToBouts(walkMask, sampleRate);
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
