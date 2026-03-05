function speedArray = getTrajectorySpeed(trajectoryData, FRAMERATE, speedWindow)
    % APPROVAL-REQUIRED COMPUTATION:
    % Changes to this function alter core speed values used across analyses.
    % Do not modify behavior without explicit project-owner approval.
    
    % Compute speed (mm/s) over a sliding window, vectorized for large datasets.
    % trajectoryData: nFrames x 3 positions; FRAMERATE: frames/sec; speedWindow: seconds.

    if ~exist('speedWindow', 'var') || isempty(speedWindow)
        speedWindow = 0.1; % default 0.1 s window
    end


    nFrames = size(trajectoryData, 1);
    speedArray = NaN(nFrames, 1); % preallocate

    windowFrames = max(1, round(speedWindow * FRAMERATE)); % convert window to frame count
    if nFrames <= windowFrames
        return; % not enough frames to compute a windowed speed
    end

    % Displacement over the window (vectorized, O(n))
    deltaPos = trajectoryData(1 + windowFrames:end, :) - trajectoryData(1:end - windowFrames, :);
    deltaDist = sqrt(sum(deltaPos.^2, 2));

    % Speed = distance / time
    windowDuration = windowFrames / FRAMERATE;
    speedCore = deltaDist ./ windowDuration;

    % Align the speed to the starting frame of each window
    speedArray(1 + windowFrames:end) = speedCore;

end
