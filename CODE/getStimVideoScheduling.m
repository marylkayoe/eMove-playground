function [videoIDs, timeMatrix] = getStimVideoScheduling(folderName)
    % getStimVideoScheduling - Processes Unity log files in a folder to extract video scheduling metadata.
    %
    % Inputs:
    %   folderName - Path to the folder containing Unity log files.
    %
    % Outputs:
    %   videoIDs   - Cell array of videoID strings for each log file.
    %   timeMatrix - 2D matrix with unityStartTimes and unityEndTimes for each log file.

    % Validate the folder
    if ~isfolder(folderName)
        warning('Folder does not exist: %s', folderName);
        videoIDs = {};
        timeMatrix = [];
        return;
    end

    % Get a list of Unity log files in the folder (alphabetically sorted)
    logFiles = dir(fullfile(folderName, '*.csv')); % Assuming log files are CSV
    if isempty(logFiles)
        warninf('No Unity log files found in folder: %s', folderName);
        videoIDs = {};
        timeMatrix = [];
        return;
    end
    logFiles = sort({logFiles.name}); % Alphabetical sorting

    % Initialize outputs
    videoIDs = cell(1, numel(logFiles));
    timeMatrix = zeros(numel(logFiles), 2); % Start and end times for each log file

    % Process each log file
    for i = 1:numel(logFiles)
        logFileName = logFiles{i};
        logFilePath = fullfile(folderName, logFileName);

        % Get metadata from the Unity log file
        unityMetaData = getMetadataFromUnityLog(folderName, logFileName);

        % Store videoID
        videoIDs{i} = unityMetaData.videoID;

        % Store start and end times as seconds since midnight
        timeMatrix(i, 1) = seconds(unityMetaData.unityStartTime);
        timeMatrix(i, 2) = seconds(unityMetaData.unityEndTime);
    end
    videoIDs = videoIDs(:);
end