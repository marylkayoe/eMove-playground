function unityMetaData = getMetadataFromUnityLog(dataFolder, logFileName)
    % input: dataFolder - string, path to the folder containing the Unity log file
    %        logFileName - string, name of the Unity log file
    % output: unityMetaData - struct, with fields corresponding to metadata entries

    % Check the file exists in the specified folder
    logFilePath = fullfile(dataFolder, logFileName);
    if ~isfile(logFilePath)
        warning('File does not exist: %s', logFilePath);
        unityMetaData = struct();
        return;
    end

    % Check that it is a CSV or TXT file
    [~, ~, ext] = fileparts(logFilePath);
    if ~strcmpi(ext, '.csv') && ~strcmpi(ext, '.txt')
        warning('File is not a log or txt file: %s', logFilePath);
        unityMetaData = struct();
        return;
    end

    unityMetaData = struct();

    [~, baseName] = fileparts(logFileName);  % Drop extension
    % If filename mentions baseline anywhere, treat as BASELINE
    if contains(lower(baseName), 'baseline')
        videoID = 'BASELINE';
    else
        % Last token after an underscore is the video ID (e.g., x_0806)
        tokens = regexp(baseName, '_(\w+)$', 'tokens');
        if isempty(tokens)
            videoID = '';
        else
            videoID = tokens{1}{1};
        end
    end

    opts = detectImportOptions(logFilePath, 'Delimiter', ';');  % Set delimiter if not comma
    T = readtable(logFilePath, opts);

    % Parse timestamp column (assumes last column has the dot-separated date/time)
    rawTs = strtrim(string(T{:, end}));
    % Date and time when Unity recording started
    ts = datetime(rawTs, 'InputFormat', 'dd.M.yyyy HH.mm.ss');

    % Separate captureDate and unityStartTime
    captureDate = datestr(ts(1), 'yyyy-mm-dd'); % Extract the date
    unityStartTime = timeofday(ts(1));         % Extract the time of day

    % Time of day when Unity recording ended
    unityEndTime = timeofday(ts(end));

    % Duration of the recording in seconds
    recordingDuration = seconds(unityEndTime - unityStartTime);
    nFrames = height(T);

    captureTimeNS = T{:, 2};  % This column is in nanoseconds
    dt = diff(captureTimeNS);
    sampleRate = round(1 / median(dt) * 1e9);

    % Populate the metadata struct
    unityMetaData.captureDate = captureDate;
    unityMetaData.unityStartTime = unityStartTime;
    unityMetaData.unityEndTime = unityEndTime;
    unityMetaData.recordingDuration = recordingDuration;
    unityMetaData.nFrames = nFrames;
    unityMetaData.FRAMERATE = sampleRate;
    unityMetaData.videoID = videoID;
end





