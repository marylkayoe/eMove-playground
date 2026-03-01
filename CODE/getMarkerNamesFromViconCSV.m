function markerNames = getMarkerNamesFromViconCSV(varargin)
    % getMarkerNamesFromViconCSV Extracts marker names from a Vicon CSV file.
    %
    %   markerNames = getMarkerNamesFromViconCSV(dataPath, fileName)
    %       Extracts marker names from the 4th row of the specified CSV file.
    %
    %   markerNames = getMarkerNamesFromViconCSV(dataPath, fileName, rowNum)
    %       Extracts marker names from the specified row (rowNum) of the CSV file.
    %
    %   Inputs:
    %       dataPath - Path to the directory containing the CSV file (string or char).
    %       fileName - Name of the CSV file (string or char).
    %       rowNum   - (Optional) Row number to extract marker names from. Default is 4.
    %
    %   Outputs:
    %       markerNames - A column cell array of unique, labeled marker names.
    %
    %   Notes:
    %       - Markers labeled as "Unlabeled" are excluded.
    %       - The first two markers (e.g., "name") are removed from the result.
    %       - Any prefix before a colon (e.g., "Skeleton 001:") is stripped.

    % Input parsing
    p = inputParser;
    addRequired(p, 'dataPath', @(x) ischar(x) || isstring(x));
    addRequired(p, 'fileName', @(x) ischar(x) || isstring(x));
    addOptional(p, 'rowNum', 4, @(x) isnumeric(x) && x > 0);
    parse(p, varargin{:});

    dataPath = p.Results.dataPath;
    fileName = p.Results.fileName;
    rowNum = p.Results.rowNum;

    % 1. Read the specified row (default is 4th row)
    fullFilePath = fullfile(dataPath, fileName);

    fid = fopen(fullFilePath, 'r');
    if fid < 0, error('Cannot open file'); end
    line = '';
    for k = 1:rowNum  % get the specified row
        line = fgetl(fid);
        if ~ischar(line)
            fclose(fid);
            error('File ended before the specified row was reached.');
        end
    end
    fclose(fid);
    rawNames = strsplit(line, ',', 'CollapseDelimiters', false);  % keep empty columns

    % 2. Remove non-string cells (NaN/Empty) and where the content is "unlabeled"
    validIdx = cellfun(@ischar, rawNames);
    unlabeledMarkerIdx = cellfun(@(x) ischar(x) && contains(x, 'Unlabeled', 'IgnoreCase', true), rawNames);
    validIdx = validIdx & ~unlabeledMarkerIdx;

    cleanCells = rawNames(validIdx);

    % 3. Strip the "Skeleton 001:" prefix
    % This regex looks for anything followed by a colon and removes it.
    cleanCells = regexprep(cleanCells, '^.*:', '');

    % 4. Unique and Stable
    markerNames = unique(cleanCells, 'stable');

    % Filter out markers containing 'Unlabeled'
    isLabeled = ~contains(markerNames, 'Unlabeled', 'IgnoreCase', true);
    markerNames = markerNames(isLabeled);

    % Remove the first two markers (e.g., "name" and other irrelevant entries)
    if numel(markerNames) > 2
        markerNames(1:2) = [];
    end

    % Result: Only your skeletal markers (Head, Hand, etc.) remain
    % make it a column cell array
    markerNames = markerNames(:);
end