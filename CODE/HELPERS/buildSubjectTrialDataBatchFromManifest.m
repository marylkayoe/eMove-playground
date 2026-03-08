function results = buildSubjectTrialDataBatchFromManifest(manifestInput, varargin)
% buildSubjectTrialDataBatchFromManifest - Batch-build trialData MAT files from manifest CSV/table.
%
% Purpose:
%   Build per-subject trialData directly from master file list
%   without copying raw files into per-subject folders.
%
% Usage:
%   results = buildSubjectTrialDataBatchFromManifest('/path/master_file_list_preview.csv')
%   results = buildSubjectTrialDataBatchFromManifest(assignmentsTbl, 'dryRun', true)
%
% Name-value pairs:
%   'subjects'         - explicit subject include list (default {})
%   'outputRoot'       - output root for MAT files (default: <manifestDir>/matlab_from_manifest)
%   'dryRun'           - list actions only (default false)
%   'verbose'          - print progress (default true)
%   'continueOnError'  - continue if one subject fails (default true)
%
% Additional name-value pairs are forwarded to buildSubjectTrialDataFromManifest.

    p = inputParser;
    p.KeepUnmatched = true;
    addRequired(p, 'manifestInput', @(x) istable(x) || ischar(x) || isstring(x));
    addParameter(p, 'subjects', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'outputRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'dryRun', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'verbose', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'continueOnError', true, @(x) islogical(x) && isscalar(x));
    parse(p, manifestInput, varargin{:});

    [manifestTbl, manifestDir] = localLoadManifest(p.Results.manifestInput);
    passthrough = localPassthroughArgs(varargin, p.Parameters);

    outputRoot = char(string(p.Results.outputRoot));
    if isempty(outputRoot)
        outputRoot = fullfile(manifestDir, 'matlab_from_manifest');
    end

    subjects = localCollectSubjects(manifestTbl);

    explicitSubjects = cellstr(string(p.Results.subjects));
    if ~isempty(explicitSubjects)
        keep = ismember(subjects, upper(string(explicitSubjects)));
        subjects = subjects(keep);
    end

    if p.Results.verbose
        fprintf('buildSubjectTrialDataBatchFromManifest: %d subjects to process\n', numel(subjects));
    end

    subjectCol = strings(0,1);
    statusCol = strings(0,1);
    outFileCol = strings(0,1);
    messageCol = strings(0,1);

    for i = 1:numel(subjects)
        subj = char(subjects(i));
        subjectCol(end+1,1) = string(subj); %#ok<AGROW>

        if p.Results.verbose
            fprintf('[%d/%d] %s\n', i, numel(subjects), subj);
        end

        if p.Results.dryRun
            statusCol(end+1,1) = "dryrun"; %#ok<AGROW>
            outFileCol(end+1,1) = "";
            messageCol(end+1,1) = "Would call buildSubjectTrialDataFromManifest";
            continue;
        end

        try
            thisArgs = [{'outputRoot', outputRoot}, passthrough];
            [~, outFile] = buildSubjectTrialDataFromManifest(manifestTbl, subj, thisArgs{:});
            statusCol(end+1,1) = "ok"; %#ok<AGROW>
            outFileCol(end+1,1) = string(outFile);
            messageCol(end+1,1) = "";
        catch ME
            statusCol(end+1,1) = "error"; %#ok<AGROW>
            outFileCol(end+1,1) = "";
            messageCol(end+1,1) = string(ME.message);

            if p.Results.verbose
                fprintf('  ERROR: %s\n', ME.message);
            end
            if ~p.Results.continueOnError
                break;
            end
        end
    end

    results = table(subjectCol, statusCol, outFileCol, messageCol, ...
        'VariableNames', {'subjectID','status','outFile','message'});
end

function [T, manifestDir] = localLoadManifest(manifestInput)
    if istable(manifestInput)
        T = manifestInput;
        manifestDir = pwd;
        return;
    end

    manifestPath = char(string(manifestInput));
    if ~isfile(manifestPath)
        error('buildSubjectTrialDataBatchFromManifest:ManifestMissing', ...
            'Manifest file not found: %s', manifestPath);
    end
    opts = detectImportOptions(manifestPath);
    opts = setvartype(opts, 'char');
    T = readtable(manifestPath, opts);
    manifestDir = fileparts(manifestPath);
end

function subjects = localCollectSubjects(T)
    if ~ismember('assignedSubject', T.Properties.VariableNames) || ...
       ~ismember('modality', T.Properties.VariableNames)
        error('buildSubjectTrialDataBatchFromManifest:BadManifest', ...
            'Manifest must contain assignedSubject and modality columns.');
    end

    subj = upper(string(T.assignedSubject));
    mod = lower(string(T.modality));
    mocapSubj = unique(subj(mod == "mocap"), 'stable');

    maskKnown = mocapSubj ~= "UNKNOWN" & mocapSubj ~= "SHARED" & strlength(mocapSubj) > 0;
    mocapSubj = mocapSubj(maskKnown);

    keep = false(size(mocapSubj));
    for i = 1:numel(mocapSubj)
        [isExcluded, ~] = isHardwiredExcludedSubjectID(char(mocapSubj(i)));
        keep(i) = ~isExcluded;
    end

    subjects = mocapSubj(keep);
    subjects = sort(subjects);
end

function passthrough = localPassthroughArgs(allArgs, knownBatchParams)
    passthrough = {};
    i = 1;
    while i <= numel(allArgs)
        if ~(ischar(allArgs{i}) || isstring(allArgs{i}))
            i = i + 1;
            continue;
        end
        key = char(string(allArgs{i}));
        if i == numel(allArgs)
            break;
        end
        val = allArgs{i+1};
        if ~ismember(lower(key), lower(knownBatchParams))
            passthrough(end+1:end+2) = {key, val}; %#ok<AGROW>
        end
        i = i + 2;
    end
end
