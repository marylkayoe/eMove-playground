function trialData = buildSubjectTrialData(subjectFolder, varargin)
% buildSubjectTrialData - Build and save trialData for a subject folder.
%
% Pipeline stage:
%   Subject-level ingestion from raw CSV to one MATLAB struct ("trialData").
%
% subjectFolder: path containing subfolders 'mocap' and 'unitylogs'.
% Optional name-value:
%   'outputFolder'   - where to save .mat (default: subjectFolder/matlab)
%   'mocapFile'      - specific mocap CSV name if multiple exist
%   'loadModalitySignals' - parse Unity/EDA/HR CSV into trialData.modalityData (default false)
%   'modalitiesToLoad' - subset of {'unity','eda','hr'} (default all three)
%   'MarkerLabelRow' - override label row (default 4)
%   'TrajTypeRow'    - override traj type row (default 7)
%   'HeaderRows'     - override header rows (default 8)
%
% Returns:
%   trialData struct in memory.
%
% Side effects:
%   Saves <subjectID>_mocap_<original>.mat to outputFolder.

    p = inputParser;
    addRequired(p, 'subjectFolder', @(x) ischar(x) || isstring(x));
    addParameter(p, 'outputFolder', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'mocapFile', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'loadModalitySignals', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'modalitiesToLoad', {'unity','eda','hr'}, @(x) iscell(x) || isstring(x));
    addParameter(p, 'MarkerLabelRow', 4, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'TrajTypeRow', 7, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'HeaderRows', 8, @(x) isnumeric(x) && isscalar(x));
    parse(p, subjectFolder, varargin{:});

    subjectFolder = char(subjectFolder);
    subjID = extractSubjectID(subjectFolder);
    [isExcludedHardwired, subjID] = isHardwiredExcludedSubjectID(subjID);
    if isExcludedHardwired
        error('buildSubjectTrialData:ExcludedSubject', ...
            'Subject %s is hardwired excluded for the current dataset.', subjID);
    end

    outputFolder = char(p.Results.outputFolder);
    if isempty(outputFolder)
        outputFolder = fullfile(subjectFolder, 'matlab');
    end

    mocapDir = fullfile(subjectFolder, 'mocap');
    unityDir = fullfile(subjectFolder, 'unitylogs');

    mocapFile = char(p.Results.mocapFile);
    if isempty(mocapFile)
        files = dir(fullfile(mocapDir, '*.csv'));
        if isempty(files)
            error('No mocap CSV found in %s', mocapDir);
        else
            [mocapFile, selectedIdx] = selectLatestMocapFile(files);
            if numel(files) > 1
                warning('Multiple mocap files found, using latest: %s', files(selectedIdx).name);
            end
        end
    end

    % Parse Vicon CSV with Unity folder for stim scheduling
    trialData = parseViconCSV(mocapDir, mocapFile, ...
        'MarkerLabelRow', p.Results.MarkerLabelRow, ...
        'TrajTypeRow', p.Results.TrajTypeRow, ...
        'HeaderRows', p.Results.HeaderRows, ...
        'UnityFolder', unityDir);

    % Add subject ID for traceability
    trialData.subjectID = subjID;

    % Keep an inventory of source modality files (handles split HR/EDA files).
    fileInventory = getSubjectModalityFileInventory(subjectFolder);
    trialData.metaData.modalityFileInventory = fileInventory;
    trialData.metaData.modalitySignalsLoaded = false;
    if p.Results.loadModalitySignals
        trialData.modalityData = loadModalitySignalsFromInventory(fileInventory, ...
            'modalities', p.Results.modalitiesToLoad);
        trialData.metaData.modalitySignalsLoaded = true;
    end

    % Save to output
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    [~, mocapBase, ~] = fileparts(mocapFile);
    cleanName = regexprep(mocapBase, '[^a-zA-Z0-9]', '_');
    outFile = fullfile(outputFolder, sprintf('%s_mocap_%s.mat', subjID, cleanName));
    save(outFile, 'trialData');
end

function subj = extractSubjectID(subjectFolder)
    [~, subj] = fileparts(subjectFolder);
    if isempty(subj)
        subj = 'UNKNOWN';
        return;
    end

    [subjNorm, isValid] = normalizeSubjectID(subj);
    if isValid
        subj = subjNorm;
    else
        subj = upper(char(string(subj)));
    end
end

function [mocapFile, selectedIdx] = selectLatestMocapFile(files)
% Pick latest mocap file by parsed take timestamp; fallback to file modified time.
    n = numel(files);
    parsedTs = NaT(n, 1);
    for i = 1:n
        parsedTs(i) = parseMocapTimeFromName(files(i).name);
    end

    if any(~isnat(parsedTs))
        temp = parsedTs;
        temp(isnat(temp)) = datetime(1, 1, 1);
        [~, selectedIdx] = max(temp);
    else
        [~, selectedIdx] = max([files.datenum]);
    end
    mocapFile = files(selectedIdx).name;
end

function dt = parseMocapTimeFromName(fname)
% Expected pattern: Take 2025-08-15 01.36.32 PM.csv
    expr = 'Take\s+(\d{4}-\d{2}-\d{2}\s+\d{2}\.\d{2}\.\d{2}\s+[AP]M)\.csv$';
    tok = regexp(fname, expr, 'tokens', 'once');
    if isempty(tok)
        dt = NaT;
        return;
    end
    dt = datetime(tok{1}, 'InputFormat', 'yyyy-MM-dd hh.mm.ss a');
end
