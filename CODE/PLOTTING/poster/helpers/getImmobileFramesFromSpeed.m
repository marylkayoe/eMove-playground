function [immobileMask, immobileFrameIdx, bouts] = getImmobileFramesFromSpeed(speedVec, frameRate, varargin)
% getImmobileFramesFromSpeed - Classify immobile frames from instantaneous speed.
%
% Usage:
%   immobileMask = getImmobileFramesFromSpeed(speedVec, frameRate)
%   [immobileMask, idx, bouts] = getImmobileFramesFromSpeed(speedVec, frameRate, ...
%       'thresholdMmPerSec', 25, 'minDurationSec', 1)
%
% Inputs:
%   speedVec   - nFrames x 1 vector of instantaneous speeds (mm/s)
%   frameRate  - frames per second
%
% Name-value pairs:
%   'thresholdMmPerSec' - immobility threshold (default 25)
%   'minDurationSec'    - minimum duration for an immobility bout to count (default 1)
%
% Outputs:
%   immobileMask     - logical nFrames x 1 mask of frames in valid immobile bouts
%   immobileFrameIdx - frame indices where immobileMask is true
%   bouts            - struct array with fields startIdx, endIdx, nFrames, durationSec

    p = inputParser;
    addRequired(p, 'speedVec', @(x) isnumeric(x) && isvector(x));
    addRequired(p, 'frameRate', @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
    addParameter(p, 'thresholdMmPerSec', 25, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'minDurationSec', 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    parse(p, speedVec, frameRate, varargin{:});

    speedVec = speedVec(:);
    immobileMask = false(size(speedVec));
    immobileFrameIdx = [];
    bouts = struct('startIdx', {}, 'endIdx', {}, 'nFrames', {}, 'durationSec', {});

    if isempty(speedVec)
        return;
    end

    rawMask = speedVec < p.Results.thresholdMmPerSec;
    rawMask(isnan(speedVec)) = false;

    if ~any(rawMask)
        return;
    end

    minFrames = max(1, round(p.Results.minDurationSec * frameRate));

    d = diff([false; rawMask; false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;

    keep = false(numel(starts), 1);
    for i = 1:numel(starts)
        nFrames = ends(i) - starts(i) + 1;
        if nFrames >= minFrames
            keep(i) = true;
            immobileMask(starts(i):ends(i)) = true;
        end
    end

    immobileFrameIdx = find(immobileMask);

    keptStarts = starts(keep);
    keptEnds = ends(keep);
    bouts = repmat(struct('startIdx', [], 'endIdx', [], 'nFrames', [], 'durationSec', []), numel(keptStarts), 1);
    for i = 1:numel(keptStarts)
        nFrames = keptEnds(i) - keptStarts(i) + 1;
        bouts(i).startIdx = keptStarts(i);
        bouts(i).endIdx = keptEnds(i);
        bouts(i).nFrames = nFrames;
        bouts(i).durationSec = nFrames / frameRate;
    end
end
