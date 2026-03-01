function results = buildSubjectTrialDataBatch(parentFolder, varargin)
% buildSubjectTrialDataBatch - Build trialData for all subject folders in a parent directory.
%
% Usage:
%   results = buildSubjectTrialDataBatch('/path/to/study')
%   results = buildSubjectTrialDataBatch('/path/to/study', 'dryRun', true)
%
% This function scans immediate subfolders of parentFolder (treated as
% subject folders) and calls buildSubjectTrialData() for each one.
%
% Default subject-folder rule:
%   folder contains 'mocap', 'unitylogs', and 'matlab' subfolders
%
% Inputs:
%   parentFolder - directory containing subject folders
%
% Name-value pairs:
%   'subjectFolders'    - explicit cellstr list of subfolder names to process (default {})
%   'includePattern'    - regex pattern for folder names to include (default '')
%   'excludePattern'    - regex pattern for folder names to exclude (default '^\\.')
%   'dryRun'            - list what would be processed without running (default false)
%   'verbose'           - print progress to command window (default true)
%   'continueOnError'   - continue if one subject fails (default true)
%
% Additional name-value pairs are forwarded to buildSubjectTrialData().
%
% Output:
%   results - table with columns:
%       subjectFolder, status, outFile, message

    p = inputParser;
    addRequired(p, 'parentFolder', @(x) ischar(x) || isstring(x));
    addParameter(p, 'subjectFolders', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'includePattern', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'excludePattern', '^\.', @(x) ischar(x) || isstring(x));
    addParameter(p, 'dryRun', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'verbose', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'continueOnError', true, @(x) islogical(x) && isscalar(x));
    parse(p, parentFolder, varargin{:});

    parentFolder = char(string(parentFolder));
    if ~isfolder(parentFolder)
        error('buildSubjectTrialDataBatch:BadParentFolder', ...
            'Parent folder does not exist: %s', parentFolder);
    end

    % Forward unrecognized NV pairs to buildSubjectTrialData.
    passthrough = localPassthroughArgs(varargin, p.Parameters);

    d = dir(parentFolder);
    isDir = [d.isdir];
    names = {d(isDir).name};
    names = names(~ismember(names, {'.', '..'}));

    explicitSubjects = cellstr(string(p.Results.subjectFolders));
    includePattern = char(string(p.Results.includePattern));
    excludePattern = char(string(p.Results.excludePattern));

    candidates = {};
    for i = 1:numel(names)
        name = names{i};
        fullPath = fullfile(parentFolder, name);

        if ~isempty(explicitSubjects) && ~ismember(name, explicitSubjects)
            continue;
        end
        if ~isempty(includePattern) && isempty(regexp(name, includePattern, 'once'))
            continue;
        end
        if ~isempty(excludePattern) && ~isempty(regexp(name, excludePattern, 'once'))
            continue;
        end

        % User-requested convention: treat each immediate folder as a subject folder
        % and require the standard subfolders to exist.
        if ~isfolder(fullfile(fullPath, 'mocap')) || ...
           ~isfolder(fullfile(fullPath, 'unitylogs')) || ...
           ~isfolder(fullfile(fullPath, 'matlab'))
            continue;
        end

        candidates{end+1} = fullPath; %#ok<AGROW>
    end

    % Stable alphabetical order for reproducibility.
    candidates = sort(candidates);

    if p.Results.verbose
        fprintf('buildSubjectTrialDataBatch: found %d candidate folders in %s\n', numel(candidates), parentFolder);
    end

    subjectFolderCol = strings(0,1);
    statusCol = strings(0,1);
    outFileCol = strings(0,1);
    messageCol = strings(0,1);

    for i = 1:numel(candidates)
        subjectFolder = candidates{i};
        [~, subjName] = fileparts(subjectFolder);

        if p.Results.verbose
            fprintf('[%d/%d] %s\n', i, numel(candidates), subjName);
        end

        subjectFolderCol(end+1,1) = string(subjectFolder); %#ok<AGROW>

        if p.Results.dryRun
            statusCol(end+1,1) = "dryrun"; %#ok<AGROW>
            outFileCol(end+1,1) = "";
            messageCol(end+1,1) = "Would call buildSubjectTrialData";
            continue;
        end

        try
            thisArgs = passthrough;
            if ~localHasKey(thisArgs, 'outputFolder')
                thisArgs = [{'outputFolder', fullfile(subjectFolder, 'matlab')}, thisArgs];
            end

            buildSubjectTrialData(subjectFolder, thisArgs{:});

            % Try to infer output path if outputFolder was provided.
            outFileGuess = localGuessOutputFile(subjectFolder, thisArgs);

            statusCol(end+1,1) = "ok"; %#ok<AGROW>
            outFileCol(end+1,1) = string(outFileGuess);
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

    results = table(subjectFolderCol, statusCol, outFileCol, messageCol, ...
        'VariableNames', {'subjectFolder','status','outFile','message'});
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

function outFileGuess = localGuessOutputFile(subjectFolder, passthrough)
    outFileGuess = '';
    outputFolder = '';
    mocapFile = '';

    i = 1;
    while i < numel(passthrough)
        key = lower(char(string(passthrough{i})));
        val = passthrough{i+1};
        switch key
            case 'outputfolder'
                outputFolder = char(string(val));
            case 'mocapfile'
                mocapFile = char(string(val));
        end
        i = i + 2;
    end

    if isempty(outputFolder)
        outputFolder = fullfile(subjectFolder, 'matlab');
    end
    if isempty(mocapFile)
        outFileGuess = outputFolder;
        return;
    end

    [~, subjID] = fileparts(subjectFolder);
    [~, mocapBase, ~] = fileparts(mocapFile);
    cleanName = regexprep(mocapBase, '[^a-zA-Z0-9]', '_');
    outFileGuess = fullfile(outputFolder, sprintf('%s_mocap_%s.mat', subjID, cleanName));
end

function tf = localHasKey(args, keyName)
    tf = false;
    i = 1;
    while i < numel(args)
        if ischar(args{i}) || isstring(args{i})
            if strcmpi(char(string(args{i})), keyName)
                tf = true;
                return;
            end
        end
        i = i + 2;
    end
end
