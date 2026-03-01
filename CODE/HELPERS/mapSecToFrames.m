function frameIndex = mapSecToFrames(timeSec, refSec , frameRate)
    % Map time in seconds to frame number based on frame rate
    % Inputs:
    %   timeSec  - Time in seconds to be mapped to frame number
    %   refSec   - Reference time in seconds (e.g., start time of mocap recording)
    %   frameRate - Frame rate in frames per second
    % Output:
    %   frameIndex - Corresponding frame number (1-based index)

    elapsedTime = timeSec - refSec;  % Time elapsed since reference time
    frameIndex = round(elapsedTime * frameRate) + 1;  % Convert to frame index (1-based)

    

end