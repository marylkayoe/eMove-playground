function S = extractMarkerTrajectoryForVideo(trialData, markerNames, videoID, varargin)
% extractMarkerTrajectoryForVideo - Extract marker trajectories and time axis for one stimulus video.
%
% Usage:
%   S = extractMarkerTrajectoryForVideo(trialData, {'LFHD','RFHD'}, 'vid01')
%
% Inputs:
%   trialData   - struct with fields markerNames, trajectoryData, optionally metaData
%   markerNames - char/string/cellstr marker names
%   videoID     - stimulus/video identifier found in metadata.videoIDs
%
% Name-value pairs:
%   'mocapMetaData' - metadata struct (default trialData.metaData if present)
%   'clipSec'       - seconds to clip from start of extracted segment (default 0)
%   'preStimSec'    - seconds of context to include before stimulus onset (default 0)
%   'postStimSec'   - seconds of context to include after stimulus end (default 0)
%
% Output struct S fields:
%   trajectories - nFrames x 3 x nMarkers
%   markerNames  - cellstr of requested markers
%   frameRange   - source frame indices used (after clipping)
%   timeSec      - nFrames x 1 time vector (seconds, starts at 0)
%   frameRate    - scalar frame rate if available, else []
%   videoID      - requested videoID
%   stimStartFrame - stimulus onset frame index in the source recording
%   stimEndFrame   - stimulus end frame index in the source recording
%   stimStartIdx   - stimulus onset index within the extracted segment
%   stimEndIdx     - stimulus end index within the extracted segment
%   stimStartOffsetSec - stimulus onset time within the extracted segment
%   stimEndOffsetSec   - stimulus end time within the extracted segment

    p = inputParser;
    addRequired(p, 'trialData', @isstruct);
    addRequired(p, 'markerNames', @(x) ischar(x) || isstring(x) || iscell(x));
    addRequired(p, 'videoID', @(x) ischar(x) || isstring(x));
    addParameter(p, 'mocapMetaData', struct(), @isstruct);
    addParameter(p, 'clipSec', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'preStimSec', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'postStimSec', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    parse(p, trialData, markerNames, videoID, varargin{:});

    if ischar(markerNames) || isstring(markerNames)
        markerNames = cellstr(string(markerNames));
    end
    videoID = char(string(videoID));

    % Prefer explicitly provided metadata; otherwise use trialData.metaData when available.
    metaData = p.Results.mocapMetaData;
    if isempty(fieldnames(metaData))
        if isfield(trialData, 'metaData') && isstruct(trialData.metaData)
            metaData = trialData.metaData;
        else
            error('extractMarkerTrajectoryForVideo:MissingMetaData', ...
                'Metadata is required (provide ''mocapMetaData'' or trialData.metaData).');
        end
    end

    neededMeta = {'videoIDs', 'stimScheduling'};
    for k = 1:numel(neededMeta)
        if ~isfield(metaData, neededMeta{k})
            error('extractMarkerTrajectoryForVideo:MissingMetaField', ...
                'Metadata missing required field "%s".', neededMeta{k});
        end
    end

    if ~isfield(trialData, 'markerNames') || ~isfield(trialData, 'trajectoryData')
        error('extractMarkerTrajectoryForVideo:BadTrialData', ...
            'trialData must contain markerNames and trajectoryData.');
    end

    [startFrame, endFrame] = getFramesForStimVideo(metaData, videoID);
    if isempty(startFrame) || isempty(endFrame)
        error('extractMarkerTrajectoryForVideo:VideoNotFound', ...
            'Could not resolve frame range for videoID "%s".', videoID);
    end

    nTotalFrames = size(trialData.trajectoryData, 1);
    startFrame = max(1, round(startFrame));
    endFrame = min(nTotalFrames, round(endFrame));
    if endFrame < startFrame
        error('extractMarkerTrajectoryForVideo:InvalidFrameRange', ...
            'Resolved frame range is invalid for videoID "%s".', videoID);
    end

    frameRate = localGetFrameRate(metaData);
    preFrames = 0;
    postFrames = 0;
    if ~isempty(frameRate)
        preFrames = round(p.Results.preStimSec * frameRate);
        postFrames = round(p.Results.postStimSec * frameRate);
    end

    extractStartFrame = max(1, startFrame - preFrames);
    extractEndFrame = min(nTotalFrames, endFrame + postFrames);
    frameRange = extractStartFrame:extractEndFrame;

    if isempty(frameRate)
        clipFrames = 0;
    else
        clipFrames = round(p.Results.clipSec * frameRate);
    end
    if clipFrames > 0
        if numel(frameRange) <= clipFrames
            error('extractMarkerTrajectoryForVideo:ClipTooLarge', ...
                'clipSec removes the entire segment for videoID "%s".', videoID);
        end
        frameRange = frameRange((clipFrames + 1):end);
    end

    nMarkers = numel(markerNames);
    trajectories = nan(numel(frameRange), 3, nMarkers);
    missingMarkers = {};

    for m = 1:nMarkers
        idx = find(strcmp(trialData.markerNames, markerNames{m}), 1, 'first');
        if isempty(idx)
            missingMarkers{end+1} = markerNames{m}; %#ok<AGROW>
            continue;
        end
        trajectories(:, :, m) = trialData.trajectoryData(frameRange, :, idx);
    end

    if ~isempty(missingMarkers)
        warning('extractMarkerTrajectoryForVideo:MissingMarkers', ...
            'Markers not found: %s', strjoin(missingMarkers, ', '));
    end

    if isempty(frameRate)
        timeSec = (0:(numel(frameRange)-1))';
    else
        timeSec = (0:(numel(frameRange)-1))' ./ frameRate;
    end

    S = struct();
    S.trajectories = trajectories;
    S.markerNames = markerNames;
    S.frameRange = frameRange(:);
    S.timeSec = timeSec;
    S.frameRate = frameRate;
    S.videoID = videoID;
    S.stimStartFrame = startFrame;
    S.stimEndFrame = endFrame;
    S.stimStartIdx = find(frameRange == startFrame, 1, 'first');
    S.stimEndIdx = find(frameRange == endFrame, 1, 'last');
    if isempty(S.stimStartIdx), S.stimStartIdx = 1; end
    if isempty(S.stimEndIdx), S.stimEndIdx = numel(frameRange); end
    if isempty(frameRate)
        S.stimStartOffsetSec = S.stimStartIdx - 1;
        S.stimEndOffsetSec = S.stimEndIdx - 1;
    else
        S.stimStartOffsetSec = (S.stimStartIdx - 1) ./ frameRate;
        S.stimEndOffsetSec = (S.stimEndIdx - 1) ./ frameRate;
    end
end

function frameRate = localGetFrameRate(metaData)
    frameRate = [];
    candidateFields = {'captureFrameRate', 'frameRate', 'samplingRate', 'fps'};
    for i = 1:numel(candidateFields)
        f = candidateFields{i};
        if isfield(metaData, f)
            v = metaData.(f);
            if isnumeric(v) && isscalar(v) && isfinite(v) && v > 0
                frameRate = double(v);
                return;
            end
        end
    end
end
