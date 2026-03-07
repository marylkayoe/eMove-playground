function metaData = getMetadataFromViconCSV(dataFolder, fileName, unityFolder)
% the metadata is on the first row of the CSV file, read it and parse by columns
% input: fileName - string, path to the Vicon CSV file, comma separated
% output: metaData - struct, with fields corresponding to metadata columns
%
% Notes:
%   - Parses Vicon capture start timestamp into both time-of-day and seconds.
%   - If a Unity folder is provided, computes per-video stim frame windows
%     relative to Vicon capture start time.

if ~exist('unityFolder', 'var')
    unityFolder = '';
end

% check the file exists in the specified folder
fullFileName = fullfile(dataFolder, fileName);
if ~isfile(fullFileName)
    warning('File does not exist: %s', fullFileName);
    metaData = struct();
    return;
end

% check it is CSV file
[~, ~, ext] = fileparts(fullFileName);
if ~strcmpi(ext, '.csv')
    warning('File is not a CSV file: %s', fullFileName);
    metaData = struct();
    return;
end

% open the file and read the first line
fid = fopen(fullFileName, 'r');
if fid == -1
    warning('Could not open file: %s', fullFileName);
    metaData = struct();
    return;
end
firstLine = fgetl(fid);
fclose(fid);

% split the first line by commas
columns = strsplit(firstLine, ',', 'CollapseDelimiters', false );
% create a struct with field names from the odd-numbered columns and values from the even-numbered columns
metaData = struct();
for i = 1:2:length(columns)-1
    fieldName = strtrim(columns{i});
    fieldValue = strtrim(columns{i+1});
    % replace spaces and special characters in field names with underscores
    fieldName = regexprep(fieldName, '[^a-zA-Z0-9]', '_');
    metaData.(fieldName) = fieldValue;
end
% clean metadata field names to lowerCamelCase
for f = fieldnames(metaData)'
    cleanName = regexprep(f{1}, '_([a-zA-Z])', '${upper($1)}');
    cleanName(1) = lower(cleanName(1));   % ensure lowerCamelCase
    if ~strcmp(cleanName, f{1})
        metaData.(cleanName) = metaData.(f{1});
        metaData = rmfield(metaData, f{1});
    end
end

% convert numeric fields to numbers
for f = fieldnames(metaData)'
    numValue = str2double(metaData.(f{1}));
    if ~isnan(numValue)
        metaData.(f{1}) = numValue;
    end

end

ts = strtrim(metaData.captureStartTime);   % '2025-08-15 01.36.32.940 IP.'
ts = regexprep(ts, '\.$', '');             % drop trailing dot

% Normalize markers without \b
ts = regexprep(ts, '(?i)\s*AP\s*$', 'AM');
ts = regexprep(ts, '(?i)\s*IP\s*$', 'PM');
ts = regexprep(ts, '(?i)\s*AM\s*$', 'AM'); %
ts = regexprep(ts, '(?i)\s*PM\s*$', 'PM');

% strip milliseconds for parsing
ts = regexprep(ts, '\.(\d{3})', '');

dt = datetime(ts, 'InputFormat', 'yyyy-MM-dd hh.mm.ssa');  % 12h parse
t24 = timeofday(dt);
tSeconds = seconds(t24);


% Separate into captureDate and captureStartTime fields
metaData.captureDate =datestr(dt, 'yyyy-mm-dd');        % e.g., '2025-08-15'
metaData.captureStartTime = t24;        % Extract the time
metaData.captureStartSeconds = tSeconds; % seconds since midnight

% get stimulus scheduling and videoID info from unity log folder

if ~isempty(unityFolder) && isfolder(unityFolder)
    [videoIDs, timeMatrix, unityLogFileNames] = getStimVideoScheduling(unityFolder);
    relativeVideoTimes = timeMatrix - metaData.captureStartSeconds;
    % use metaData.captureFrameRate to convert seconds to frames
    stimStartEndFrames = round(relativeVideoTimes * metaData.captureFrameRate);
    metaData.stimScheduling = stimStartEndFrames;
    metaData.videoIDs = videoIDs;
    metaData.unityLogFileNames = unityLogFileNames;
else
    metaData.stimScheduling = [];
    metaData.videoIDs = {};
    metaData.unityLogFileNames = {};
end

metaData.markerNames = getMarkerNamesFromViconCSV(dataFolder, fileName);

end
