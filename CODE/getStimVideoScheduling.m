function [videoIDs, timeMatrix, logFileNames] = getStimVideoScheduling(folderName, varargin)
    % getStimVideoScheduling - Extract per-log stimulus timing from Unity logs.
    %
    % Inputs:
    %   folderName - Path to the folder containing Unity log files.
    %
    % Name-value pairs:
    %   'trimPreBaseline'  - if true (default), drop logs before anchor baseline.
    %   'anchorVideoID'    - anchor event in Unity logs (default 'BASELINE').
    %   'anchorOccurrence' - 'last' (default) or 'first' if anchor repeats.
    %
    % Outputs:
    %   videoIDs     - Nx1 cell array of video IDs.
    %   timeMatrix   - Nx2 matrix of [startSec, endSec] (seconds since midnight).
    %   logFileNames - Nx1 cell array of Unity log file names (ordered to match outputs).
    %
    % Ordering policy:
    %   Logs are ordered by parsed Unity start datetime when available.
    %   This is safer for presentation-order use than plain alphabetical sort.

    p = inputParser;
    addRequired(p, 'folderName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'trimPreBaseline', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'anchorVideoID', 'BASELINE', @(x) ischar(x) || isstring(x));
    addParameter(p, 'anchorOccurrence', 'last', @(x) any(strcmpi(string(x), ["first","last"])));
    parse(p, folderName, varargin{:});

    folderName = char(string(p.Results.folderName));
    anchorVideoID = char(string(p.Results.anchorVideoID));
    anchorOccurrence = lower(char(string(p.Results.anchorOccurrence)));

    if ~isfolder(folderName)
        warning('Folder does not exist: %s', folderName);
        videoIDs = {};
        timeMatrix = [];
        logFileNames = {};
        return;
    end

    files = dir(fullfile(folderName, '*.csv'));
    if isempty(files)
        warning('No Unity log files found in folder: %s', folderName);
        videoIDs = {};
        timeMatrix = [];
        logFileNames = {};
        return;
    end

    n = numel(files);
    rows = struct('videoID', {}, 'startSec', {}, 'endSec', {}, ...
        'startAbs', {}, 'fileName', {});

    for i = 1:n
        logFileName = files(i).name;
        unityMetaData = getMetadataFromUnityLog(folderName, logFileName);

        row = struct();
        row.videoID = '';
        row.startSec = NaN;
        row.endSec = NaN;
        row.startAbs = NaT;
        row.fileName = logFileName;

        if isfield(unityMetaData, 'videoID')
            row.videoID = unityMetaData.videoID;
        end
        if isfield(unityMetaData, 'unityStartTime') && ~isempty(unityMetaData.unityStartTime)
            row.startSec = seconds(unityMetaData.unityStartTime);
        end
        if isfield(unityMetaData, 'unityEndTime') && ~isempty(unityMetaData.unityEndTime)
            row.endSec = seconds(unityMetaData.unityEndTime);
        end

        if isfield(unityMetaData, 'captureDate') && isfield(unityMetaData, 'unityStartTime')
            try
                d = datetime(unityMetaData.captureDate, 'InputFormat', 'yyyy-MM-dd');
                row.startAbs = d + unityMetaData.unityStartTime;
            catch
                row.startAbs = NaT;
            end
        end

        if isnat(row.startAbs)
            row.startAbs = localParseStartFromFileName(logFileName);
        end

        rows(i,1) = row; %#ok<AGROW>
    end

    T = struct2table(rows);
    hasAbs = ~isnat(T.startAbs);
    fallbackAbs = NaT(height(T),1);
    fallbackAbs(~hasAbs) = datetime(files(~hasAbs).datenum, 'ConvertFrom', 'datenum');
    T.sortAbs = T.startAbs;
    T.sortAbs(~hasAbs) = fallbackAbs(~hasAbs);
    T = sortrows(T, {'sortAbs','fileName'});

    if p.Results.trimPreBaseline && ~isempty(T)
        isAnchor = strcmpi(T.videoID, anchorVideoID) | contains(lower(string(T.videoID)), 'baseline');
        anchorIdxAll = find(isAnchor);
        if ~isempty(anchorIdxAll)
            if strcmp(anchorOccurrence, 'first')
                anchorIdx = anchorIdxAll(1);
            else
                anchorIdx = anchorIdxAll(end);
            end
            T = T(anchorIdx:end, :);
        end
    end

    videoIDs = T.videoID;
    timeMatrix = [T.startSec, T.endSec];
    logFileNames = T.fileName;

    videoIDs = videoIDs(:);
    logFileNames = logFileNames(:);
end

function dt = localParseStartFromFileName(fileName)
    % Example token in file name: 2025-08-14-12-29
    tok = regexp(fileName, '(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})', 'tokens', 'once');
    if isempty(tok)
        dt = NaT;
        return;
    end

    try
        dt = datetime(tok{1}, 'InputFormat', 'yyyy-MM-dd-HH-mm');
    catch
        dt = NaT;
    end
end
