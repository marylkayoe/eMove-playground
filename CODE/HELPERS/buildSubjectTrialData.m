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
    addParameter(p, 'MarkerLabelRow', 4, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'TrajTypeRow', 7, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'HeaderRows', 8, @(x) isnumeric(x) && isscalar(x));
    parse(p, subjectFolder, varargin{:});

    subjectFolder = char(subjectFolder);
    subjID = extractSubjectID(subjectFolder);
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
        elseif numel(files) > 1
            warning('Multiple mocap files found, using first: %s', files(1).name);
            mocapFile = files(1).name;
        else
            mocapFile = files(1).name;
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
    trialData.metaData.modalityFileInventory = getSubjectModalityFileInventory(subjectFolder);

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
