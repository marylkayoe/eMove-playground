function [unityTable, meta] = loadUnityEyeLogCSV(filePath, varargin)
% loadUnityEyeLogCSV Parse one Unity eye-log CSV into a clean MATLAB table.
%
% Purpose:
%   Convert one Unity log file to a standard table that is easy to inspect
%   and join with MoCap/physiology timelines. No metric computation is done.
%
% Usage:
%   [unityTable, meta] = loadUnityEyeLogCSV('/path/PNr_xx0000_...csv')
%
% Output columns:
%   frame, captureTime, logTime, systemTime
%   gazeStatus, leftEyeStatus, rightEyeStatus
%   ipdMm, leftPupilDiameterMm, rightPupilDiameterMm
%   focusDistance, focusStability

    p = inputParser;
    addRequired(p, 'filePath', @(x) ischar(x) || isstring(x));
    parse(p, filePath, varargin{:});

    filePath = char(string(filePath));
    if ~isfile(filePath)
        error('loadUnityEyeLogCSV:FileMissing', 'File not found: %s', filePath);
    end

    opts = detectImportOptions(filePath, 'FileType', 'text', 'Delimiter', ';');
    opts.VariableNamingRule = 'preserve';
    opts = setvartype(opts, opts.VariableNames, 'string');
    rawT = readtable(filePath, opts);

    meta = struct();
    meta.filePath = filePath;
    [~, f, e] = fileparts(filePath);
    meta.fileName = [f, e];
    [meta.subjectIDFromFileName, meta.fileStartTime, meta.videoToken] = localParseUnityFileName(meta.fileName);

    unityTable = table();
    unityTable.frame = localGetDouble(rawT, 'Frame');
    unityTable.captureTime = localGetDouble(rawT, 'CaptureTime');
    unityTable.logTime = localGetDouble(rawT, 'LogTime');
    unityTable.systemTime = localParseSystemTime(localGetString(rawT, 'SystemTime'));
    unityTable.gazeStatus = localGetString(rawT, 'GazeStatus');
    unityTable.leftEyeStatus = localGetString(rawT, 'LeftEyeStatus');
    unityTable.rightEyeStatus = localGetString(rawT, 'RightEyeStatus');
    unityTable.ipdMm = localGetDouble(rawT, 'InterPupillaryDistanceInMM');
    unityTable.leftPupilDiameterMm = localGetDouble(rawT, 'LeftPupilDiameterInMM');
    unityTable.rightPupilDiameterMm = localGetDouble(rawT, 'RightPupilDiameterInMM');
    unityTable.focusDistance = localGetDouble(rawT, 'FocusDistance');
    unityTable.focusStability = localGetDouble(rawT, 'FocusStability');
end

function v = localGetString(T, colName)
    if ismember(colName, T.Properties.VariableNames)
        v = string(T.(colName));
    else
        v = strings(height(T), 1);
    end
end

function v = localGetDouble(T, colName)
    if ~ismember(colName, T.Properties.VariableNames)
        v = NaN(height(T), 1);
        return;
    end
    s = string(T.(colName));
    s = strrep(s, ',', '.');
    v = str2double(s);
end

function dt = localParseSystemTime(s)
    dt = NaT(size(s));
    fmts = { ...
        'd.M.yyyy HH.mm.ss', ...
        'dd.MM.yyyy HH.mm.ss', ...
        'd.M.yyyy H.mm.ss', ...
        'dd.MM.yyyy H.mm.ss' ...
        };
    for i = 1:numel(s)
        if s(i) == "" || ismissing(s(i))
            continue;
        end
        for f = 1:numel(fmts)
            try
                dt(i) = datetime(s(i), 'InputFormat', fmts{f});
                if ~isnat(dt(i))
                    break;
                end
            catch
                % try next format
            end
        end
    end
end

function [subj, dt, videoToken] = localParseUnityFileName(fileName)
    subj = 'UNKNOWN';
    dt = NaT;
    videoToken = 'unknown';
    expr = 'PNr_([^_]+)_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\s+(.+)\.csv$';
    tok = regexp(fileName, expr, 'tokens', 'once');
    if isempty(tok)
        return;
    end
    [subj, ~] = normalizeSubjectID(tok{1});
    dt = datetime(tok{2}, 'InputFormat', 'yyyy-MM-dd-HH-mm');
    videoToken = char(string(tok{3}));
end
