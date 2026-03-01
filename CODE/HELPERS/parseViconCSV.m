function trialData = parseViconCSV(dataFolder, fileName, varargin)
% parseViconCSV - Parse a Vicon CSV file into a trialData struct (positions only).
%
% Inputs:
%   dataFolder - folder containing the CSV
%   fileName   - CSV file name
%   Optional name-value:
%       'MarkerLabelRow' (default 4)
%       'TrajTypeRow'    (default 7)
%       'HeaderRows'     (default 8)
%
% Output:
%   trialData struct with fields:
%       markerNames
%       metaData
%       trajectoryData (positions only)

    % Input parsing
    p = inputParser;
    addParameter(p, 'MarkerLabelRow', 4, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'TrajTypeRow', 7, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'HeaderRows', 8, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'UnityFolder', '', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});

    MARKERLABELROW = p.Results.MarkerLabelRow; % Row number where marker labels are located
    TRAJTYPEROW = p.Results.TrajTypeRow;    % Row number where trajectory types (position or rotation) are located
    NHEADERROWS = p.Results.HeaderRows;    % Total number of header rows before data starts from row 9
    unityFolder = char(p.Results.UnityFolder);

    % Full path to the input CSV file
    fullFilePath = fullfile(dataFolder, fileName);

    % Read metadata and marker information
    rawHeader = readSingleCSVRow(fullFilePath, TRAJTYPEROW);
    positionIdx = find(contains(rawHeader, 'position', 'IgnoreCase', true));
    rawNames = readSingleCSVRow(fullFilePath, MARKERLABELROW);
    unlabeledIdx = find(contains(rawNames, 'Unlabeled', 'IgnoreCase', true));
    positionIdx = setdiff(positionIdx, unlabeledIdx); % Exclude unlabeled indices
    markerLabels = getMarkerNamesFromViconCSV(dataFolder, fileName);
    metaData = getMetadataFromViconCSV(dataFolder, fileName, unityFolder);

    % Initialize variables
    nFrames = metaData.totalFramesInTake;
    nMarkers = length(markerLabels);
    nDIMS = 3; % X, Y, Z
    trajectoryData = NaN(nFrames - NHEADERROWS, nDIMS, nMarkers);

    % Determine the row and column ranges
    startRow = NHEADERROWS + 1; % Start after the header rows
    endRow = nFrames; % Read all rows until the end of the file
    startCol = 3; % Start from column 2
    endCol = unlabeledIdx(1) - 1; % End at the first unlabeled column

    % Read the data using readmatrix with row and column ranges
    rawData = readmatrix(fullFilePath, 'Range', [startRow, startCol, endRow, endCol]);

    % positionIdx indices come from the full CSV row, but rawData starts at startCol.
    % Rebase indices so they correctly address columns in rawData.
    positionIdxInRaw = positionIdx - (startCol - 1);

    if any(positionIdxInRaw < 1) || any(positionIdxInRaw > size(rawData, 2))
        error('parseViconCSV:PositionIndexOutOfRange', ...
            'Rebased position indices are out of range. Check CSV header parsing / startCol.');
    end

    % Process the data for each marker
    for n = 1:nMarkers
        x = rawData(:, positionIdxInRaw((n-1)*3 + 1));
        y = rawData(:, positionIdxInRaw((n-1)*3 + 2));
        z = rawData(:, positionIdxInRaw((n-1)*3 + 3));
        trajectoryData(:, :, n) = [x, y, z];
    end

    trialData = struct();
    % reuse parsed labels and metadata
    trialData.markerNames = markerLabels;
    trialData.metaData = metaData;
    trialData.trajectoryData = trajectoryData;
end
