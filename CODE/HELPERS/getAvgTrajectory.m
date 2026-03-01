function averageTrajectory = getAvgTrajectory(trajectories)
  % calculate the mean position of markers at each frame throughout the trial
  % trjectories is 3D matrix of size (nFrames x 3 x nMarkers)
  % averageTrajectory is 2D matrix of size (nFrames x 3)
    averageTrajectory = squeeze(nanmean(trajectories, 3));
end

