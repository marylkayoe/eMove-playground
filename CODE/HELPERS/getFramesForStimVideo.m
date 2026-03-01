function [startFrame, endFrame] = getFramesForStimVideo(trialMetaData, videoID)
    % getFramesForStimVideo - Retrieves the start and end frames for a given stimulus video ID from trial metadata.
    %
    % Inputs:
    %   trialMetaData - Struct containing trial metadata, including video scheduling information.
    %   videoID       - String representing the video ID to search for.
    %
    % Outputs:
    %   startFrame    - The starting frame number for the specified video ID.
    %   endFrame      - The ending frame number for the specified video ID.

    % Initialize output variables
    startFrame = [];
    endFrame = [];

    % find index of the videoID in the trialMetaData.videoIDs
    videoIdx = find(strcmp(trialMetaData.videoIDs, videoID));
    if isempty(videoIdx)
        warning('Video ID not found in trial metadata: %s', videoID);
        return;
    end

    % get the start and end frames from trialMetaData.stimStartEndFrames
    startFrame = trialMetaData.stimScheduling(videoIdx, 1);
    endFrame = trialMetaData.stimScheduling(videoIdx, 2);
    
end