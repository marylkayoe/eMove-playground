function [trialData, outFile] = buildSubjectTrialDataFromManifest(manifestInput, subjectID, varargin)
% buildSubjectTrialDataFromManifest - Build trialData for one subject from a manifest table/CSV.
%
% Purpose:
%   Build trialData without reorganizing or copying raw files.
%   Uses source paths listed in master_file_list CSV.
%
% Usage:
%   [trialData, outFile] = buildSubjectTrialDataFromManifest(manifestCsv, 'AB1502')
%   [trialData, outFile] = buildSubjectTrialDataFromManifest(assignmentsTbl, 'AB1502', 'saveMat', false)
%
% Inputs:
%   manifestInput - table or path to manifest CSV (from buildDatasetAssignments).
%   subjectID     - subject identifier (case-insensitive; normalized uppercase).
%
% Name-value pairs:
%   'outputRoot'      - output root folder for MAT files (default: <manifestDir>/matlab_from_manifest)
%   'saveMat'         - save MAT file (default true)
%   'loadModalitySignals' - parse Unity/EDA/HR CSV into trialData.modalityData (default false)
%   'modalitiesToLoad' - subset of {'unity','eda','hr'} (default all three)
%   'MarkerLabelRow'  - forwarded to parseViconCSV (default 4)
%   'TrajTypeRow'     - forwarded to parseViconCSV (default 7)
%   'HeaderRows'      - forwarded to parseViconCSV (default 8)
%
% Outputs:
%   trialData - parsed trialData struct
%   outFile   - MAT output path if saved, else ''

    p = inputParser;
    addRequired(p, 'manifestInput', @(x) istable(x) || ischar(x) || isstring(x));
    addRequired(p, 'subjectID', @(x) ischar(x) || isstring(x));
    addParameter(p, 'outputRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'saveMat', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'loadModalitySignals', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'modalitiesToLoad', {'unity','eda','hr'}, @(x) iscell(x) || isstring(x));
    addParameter(p, 'MarkerLabelRow', 4, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'TrajTypeRow', 7, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'HeaderRows', 8, @(x) isnumeric(x) && isscalar(x));
    parse(p, manifestInput, subjectID, varargin{:});

    [manifestTbl, manifestDir] = localLoadManifest(p.Results.manifestInput);

    [subjectIDNorm, ~] = normalizeSubjectID(p.Results.subjectID);
    [isExcludedHardwired, subjectIDNorm] = isHardwiredExcludedSubjectID(subjectIDNorm);
    if isExcludedHardwired
        error('buildSubjectTrialDataFromManifest:ExcludedSubject', ...
            'Subject %s is hardwired excluded for the current dataset.', subjectIDNorm);
    end

    subjMask = strcmpi(string(manifestTbl.assignedSubject), string(subjectIDNorm));
    subjTbl = manifestTbl(subjMask, :);
    if isempty(subjTbl)
        error('buildSubjectTrialDataFromManifest:SubjectMissing', ...
            'No manifest rows found for subject %s.', subjectIDNorm);
    end

    mod = lower(string(subjTbl.modality));
    mocapTbl = subjTbl(mod == "mocap", :);
    unityTbl = subjTbl(mod == "unity", :);

    if isempty(mocapTbl)
        error('buildSubjectTrialDataFromManifest:NoMocap', ...
            'No mocap row found for subject %s.', subjectIDNorm);
    end

    mocapTbl = localSortByParsedTimestamp(mocapTbl);
    mocapDT = localToDatetime(mocapTbl.parsedTimestamp);
    if height(mocapTbl) > 1
        warning('buildSubjectTrialDataFromManifest:MultipleMocapRows', ...
            ['Subject %s has %d mocap rows in manifest. ', ...
             'Using latest timestamp row (restart-safe default).'], ...
            subjectIDNorm, height(mocapTbl));
    end
    selectedIdx = height(mocapTbl);
    validDT = ~isnat(mocapDT);
    if any(validDT)
        idxValid = find(validDT);
        [~, rel] = max(mocapDT(validDT));
        selectedIdx = idxValid(rel);
    end
    mocapPath = char(string(mocapTbl.sourcePath(selectedIdx)));
    if ~isfile(mocapPath)
        error('buildSubjectTrialDataFromManifest:MocapFileMissing', ...
            'Mocap file not found: %s', mocapPath);
    end
    [mocapDir, mocapName, mocapExt] = fileparts(mocapPath);
    mocapFile = [mocapName, mocapExt];

    unityLogPaths = cellstr(string(unityTbl.sourcePath));
    unityLogPaths = unityLogPaths(~cellfun(@isempty, unityLogPaths));
    unityFolder = '';
    if ~isempty(unityLogPaths)
        unityFolder = fileparts(unityLogPaths{1});
    end

    trialData = parseViconCSV(mocapDir, mocapFile, ...
        'MarkerLabelRow', p.Results.MarkerLabelRow, ...
        'TrajTypeRow', p.Results.TrajTypeRow, ...
        'HeaderRows', p.Results.HeaderRows, ...
        'UnityFolder', unityFolder, ...
        'UnityLogFilePaths', unityLogPaths);

    trialData.subjectID = subjectIDNorm;
    fileInventory = localBuildInventoryFromManifest(subjTbl, subjectIDNorm);
    trialData.metaData.modalityFileInventory = fileInventory;
    trialData.metaData.modalitySignalsLoaded = false;
    if p.Results.loadModalitySignals
        trialData.modalityData = loadModalitySignalsFromInventory(fileInventory, ...
            'modalities', p.Results.modalitiesToLoad);
        trialData.metaData.modalitySignalsLoaded = true;
    end
    trialData.metaData.sourceManifestPath = localManifestPathString(p.Results.manifestInput);

    outFile = '';
    if p.Results.saveMat
        outputRoot = char(string(p.Results.outputRoot));
        if isempty(outputRoot)
            outputRoot = fullfile(manifestDir, 'matlab_from_manifest');
        end
        outDir = fullfile(outputRoot, subjectIDNorm);
        if ~exist(outDir, 'dir')
            mkdir(outDir);
        end

        cleanName = regexprep(mocapName, '[^a-zA-Z0-9]', '_');
        outFile = fullfile(outDir, sprintf('%s_mocap_%s.mat', subjectIDNorm, cleanName));
        save(outFile, 'trialData');
    end
end

function [T, manifestDir] = localLoadManifest(manifestInput)
    if istable(manifestInput)
        T = manifestInput;
        manifestDir = pwd;
        return;
    end

    manifestPath = char(string(manifestInput));
    if ~isfile(manifestPath)
        error('buildSubjectTrialDataFromManifest:ManifestMissing', ...
            'Manifest file not found: %s', manifestPath);
    end
    opts = detectImportOptions(manifestPath);
    opts = setvartype(opts, 'char');
    T = readtable(manifestPath, opts);
    manifestDir = fileparts(manifestPath);
end

function out = localSortByParsedTimestamp(T)
    if ~ismember('parsedTimestamp', T.Properties.VariableNames)
        out = T;
        return;
    end
    dt = localToDatetime(T.parsedTimestamp);
    [~, ord] = sort(dt);
    out = T(ord, :);
end

function dt = localToDatetime(v)
    if isdatetime(v)
        dt = v;
        return;
    end
    s = string(v);
    dt = NaT(size(s));
    % Match format seen in writetable output: 14-Aug-2025 11:35:00
    try
        dt = datetime(s, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    catch
        for i = 1:numel(s)
            try
                dt(i) = datetime(s(i));
            catch
                dt(i) = NaT;
            end
        end
    end
end

function fileInventory = localBuildInventoryFromManifest(subjTbl, subjectID)
    rows = struct('subjectID', {}, 'modality', {}, 'fileName', {}, 'filePath', {}, ...
        'fileBytes', {}, 'fileModified', {}, 'startTimeHint', {}, 'endTimeHint', {});

    parsedDT = localToDatetime(subjTbl.parsedTimestamp);

    for i = 1:height(subjTbl)
        filePath = char(string(subjTbl.sourcePath(i)));
        [~, fileName, fileExt] = fileparts(filePath);
        fileName = [fileName, fileExt];

        fileBytes = NaN;
        fileModified = NaT;
        if isfile(filePath)
            d = dir(filePath);
            fileBytes = d.bytes;
            fileModified = datetime(d.datenum, 'ConvertFrom', 'datenum');
        end

        row = struct();
        row.subjectID = subjectID;
        row.modality = char(string(subjTbl.modality(i)));
        row.fileName = fileName;
        row.filePath = filePath;
        row.fileBytes = fileBytes;
        row.fileModified = fileModified;
        row.startTimeHint = parsedDT(i);
        row.endTimeHint = parsedDT(i);
        rows(end+1,1) = row; %#ok<AGROW>
    end

    if isempty(rows)
        fileInventory = table();
        return;
    end

    fileInventory = struct2table(rows);
    fileInventory.orderInModality = zeros(height(fileInventory), 1);

    mods = unique(fileInventory.modality, 'stable');
    for m = 1:numel(mods)
        idx = strcmp(fileInventory.modality, mods{m});
        Tm = fileInventory(idx, :);
        [~, ord] = sortrows([datenum(Tm.startTimeHint), datenum(Tm.fileModified)]);
        localOrder = zeros(height(Tm),1);
        localOrder(ord) = 1:height(Tm);
        fileInventory.orderInModality(idx) = localOrder;
    end

    fileInventory = sortrows(fileInventory, {'modality','orderInModality','fileName'});
end

function s = localManifestPathString(manifestInput)
    if istable(manifestInput)
        s = '[table_in_memory]';
    else
        s = char(string(manifestInput));
    end
end
