function markerTrajectories = getMarkerTrajectory(trialData, requestedMarkers, varargin)
%getMarkerTrajectory Extracts the trajectory data for a specific marker from trial data.
% the trial data is a matlab structure, not the original VICON CSV
% Trial data structure contains the following fields:
%   - markerNames: Cell array of marker names.
%   - metaData: Struct containing metadata information.
%   - trajectoryData: 3D array of size (nFrames x 3 x nMarkers) containing the trajectory data.
% Inputs:
%   trialData  - Struct containing trial data with fields as described above.
%   markerName - String specifying the name of the marker to extract.
%  varargin   - Optional parameters:
% 'frameRange' - array of frames, e.g. [322:599] to extract only a subset of frames.
% 'videoID' - string specifying the video ID to extract frames for (overrides frameRange).
%.  NOTE: if provided, also need to provide the mocapMetaData structure with stimScheduling info.
% Outputs:
% markerTrajectory - a 2D matrix of size (nFrames x 3) containing the trajectory data for the specified marker (X, y, Z).
% if more than one marker was asked, returns a 3D matrix of size (nFrames x 3 x nMarkers).
%
%

% parse optional inputs
p = inputParser;
addParameter(p, 'frameRange', [], @(x) isnumeric(x) && isvector(x) );
addParameter(p, 'videoID', '', @ischar);
addParameter(p, 'mocapMetaData', struct(), @isstruct);
addParameter(p, 'CLIPSEC', 5, @(x) isnumeric(x) && isscalar(x) && x >= 0); % how much to clip from beginning of trajectory

parse(p, varargin{:});
frameRange = p.Results.frameRange;
videoID = p.Results.videoID;
mocapMetaData = trialData.metaData;
CLIPFRAMES = round(p.Results.CLIPSEC * mocapMetaData.captureFrameRate);
% if videoID is provided, get the frame range from mocapMetaData
if ~isempty(videoID)
    if isfield(mocapMetaData, 'stimScheduling') && isfield(mocapMetaData, 'videoIDs')
        [startFrame, endFrame] = getFramesForStimVideo(mocapMetaData, videoID);
        frameRange = startFrame:endFrame;
    else
        warning('mocapMetaData does not contain stimScheduling or videoIDs fields. Cannot get frame range for videoID: %s', videoID);
    end
end


if ischar(requestedMarkers)
    requestedMarkers = {requestedMarkers};
end
nRequestedMarkers = length(requestedMarkers);

% initialize output matrix to the correct size for nRequestedMarkers and frameRange
if isempty(frameRange)
    nFrames = size(trialData.trajectoryData, 1);
    frameRange = 1:nFrames;
else
    nFrames = length(frameRange);
end
markerTrajectories = NaN(nFrames, 3, nRequestedMarkers);

for m = 1:nRequestedMarkers
    thisRequestedMarker = requestedMarkers{m};
    % find the index of the specified marker
    markerIdx = find(strcmp(trialData.markerNames, thisRequestedMarker));
    if isempty(markerIdx)
        warning('Marker name not found: %s', markerName);
        markerTrajectory = [];
    else
        markerTrajectory = squeeze(trialData.trajectoryData(frameRange, :, markerIdx));
    end
    markerTrajectories(:, :, m) = markerTrajectory;

end

% clip initial frames as specified
if CLIPFRAMES > 0
    if nFrames > CLIPFRAMES
        markerTrajectories = markerTrajectories((CLIPFRAMES+1):end, :, :);
    else
        markerTrajectories = [];
    end
end 

end


