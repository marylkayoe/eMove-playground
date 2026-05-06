function accData = importWasedaAccelerometerCsv(csvPath)
%IMPORTWASEDAACCELEROMETERCSV Import one Waseda WTAcc CSV file.
%
% Purpose
%   Read one raw Waseda WTAcc CSV file and return its acceleration signal
%   and metadata in a MATLAB structure.
%
% Inputs
%   csvPath   - Path to one WTAcc CSV file.
%
% Output
%   accData   - Structure with fields:
%               acc      : nSamples x 3 acceleration matrix [X Y Z] in g
%               quat     : nSamples x 4 quaternion matrix [q0 q1 q2 q3]
%               timeSec  : nSamples x 1 time vector in seconds, relative to
%                          the first sample in the file
%               meta     : metadata structure for the imported file
%
% Important assumptions
%   The CSV contains the WTAcc columns:
%   `Time`, `Device name`, `Chip Time()`, `Acceleration X(g)`,
%   `Acceleration Y(g)`, `Acceleration Z(g)`, `Quaternions 0()`,
%   `Quaternions 1()`, `Quaternions 2()`, and `Quaternions 3()`.
%
% Notes
%   This function only imports one CSV file. It does not save a MAT file,
%   concatenate chunks, or preprocess the signal.

%% Check input
if ~(ischar(csvPath) || isstring(csvPath))
    error('importWasedaAccelerometerCsv:BadInputType', ...
        'csvPath must be a character vector or string scalar.');
end

csvPath = char(string(csvPath));
if ~isfile(csvPath)
    error('importWasedaAccelerometerCsv:MissingFile', ...
        'CSV file not found: %s', csvPath);
end

%% Read CSV text
fid = fopen(csvPath, 'r', 'n', 'UTF-8');
if fid < 0
    error('importWasedaAccelerometerCsv:OpenFailed', ...
        'Could not open CSV file: %s', csvPath);
end
fileCleanup = onCleanup(@() fclose(fid));

headerLine = fgetl(fid);
headerLine = erase(string(headerLine), char(65279));
headerNames = strtrim(split(headerLine, ','));
headerNames = reshape(headerNames, 1, []);

requiredColumns = [ ...
    "Time", ...
    "Device name", ...
    "Chip Time()", ...
    "Acceleration X(g)", ...
    "Acceleration Y(g)", ...
    "Acceleration Z(g)", ...
    "Quaternions 0()", ...
    "Quaternions 1()", ...
    "Quaternions 2()", ...
    "Quaternions 3()"];

missingColumns = requiredColumns(~ismember(requiredColumns, headerNames));
if ~isempty(missingColumns)
    error('importWasedaAccelerometerCsv:MissingColumns', ...
        'CSV is missing required columns: %s', strjoin(cellstr(missingColumns), ', '));
end

columnCount = numel(headerNames);
formatSpec = repmat('%s', 1, columnCount);
rawColumns = textscan(fid, formatSpec, ...
    'Delimiter', ',', ...
    'TextType', 'string', ...
    'CollectOutput', false, ...
    'ReturnOnError', false);

%% Extract signal columns
timeColumn = find(headerNames == "Time", 1, 'first');
deviceColumn = find(headerNames == "Device name", 1, 'first');
chipTimeColumn = find(headerNames == "Chip Time()", 1, 'first');
accXColumn = find(headerNames == "Acceleration X(g)", 1, 'first');
accYColumn = find(headerNames == "Acceleration Y(g)", 1, 'first');
accZColumn = find(headerNames == "Acceleration Z(g)", 1, 'first');
quat0Column = find(headerNames == "Quaternions 0()", 1, 'first');
quat1Column = find(headerNames == "Quaternions 1()", 1, 'first');
quat2Column = find(headerNames == "Quaternions 2()", 1, 'first');
quat3Column = find(headerNames == "Quaternions 3()", 1, 'first');

timeText = strtrim(rawColumns{timeColumn});
deviceName = strtrim(rawColumns{deviceColumn});
chipTimeText = strtrim(rawColumns{chipTimeColumn});

accX = str2double(strtrim(rawColumns{accXColumn}));
accY = str2double(strtrim(rawColumns{accYColumn}));
accZ = str2double(strtrim(rawColumns{accZColumn}));
acc = [accX, accY, accZ];

quat0 = str2double(strtrim(rawColumns{quat0Column}));
quat1 = str2double(strtrim(rawColumns{quat1Column}));
quat2 = str2double(strtrim(rawColumns{quat2Column}));
quat3 = str2double(strtrim(rawColumns{quat3Column}));
quat = [quat0, quat1, quat2, quat3];

%% Build time vector
timeParts = split(timeText, ':');
if size(timeParts, 2) ~= 3
    error('importWasedaAccelerometerCsv:BadTimeFormat', ...
        'Could not parse Time column in file: %s', csvPath);
end

hourValue = str2double(timeParts(:, 1));
minuteValue = str2double(timeParts(:, 2));
secondValue = str2double(timeParts(:, 3));

timeSecAbsolute = 3600 .* hourValue + 60 .* minuteValue + secondValue;
timeSec = timeSecAbsolute - timeSecAbsolute(1);

%% Build metadata
meta = parseAccMetadata(csvPath, acc, quat, timeSec, headerNames, timeText, deviceName, chipTimeText);

%% Assemble output
accData = struct();
accData.acc = acc;
accData.quat = quat;
accData.timeSec = timeSec;
accData.meta = meta;
end
