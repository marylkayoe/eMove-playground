function [startTimeSec, endTimeSec] = getTimesForStimVideo(videoID, unityFolder)
    % Get the start and end frames for the stimulus video within the trial data
    % Inputs:
    %   videoID        - String specifying the video ID to look for.
    %   unityFolder   - Path to the folder containing Unity log files.

     [videoIDs, timeMatrix] = getStimVideoScheduling(unityFolder);

    % Find the index of the specified videoID
    videoIdx = find(strcmp(videoIDs, videoID));
    if isempty(videoIdx)
        warning('Video ID not found in Unity log files: %s', videoID);
        startFrame = NaN;
        endFrame = NaN;
        return;
    end

    % Extract start and end times in seconds since midnight
    startTimeSec = timeMatrix(videoIdx, 1);
    endTimeSec = timeMatrix(videoIdx, 2);
end