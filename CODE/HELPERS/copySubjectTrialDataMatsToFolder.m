function results = copySubjectTrialDataMatsToFolder(parentFolder, destinationFolder, varargin)
% copySubjectTrialDataMatsToFolder - Copy per-subject trialData MAT files into one flat folder.
%
% Usage:
%   results = copySubjectTrialDataMatsToFolder(parentFolder, destinationFolder)
%   results = copySubjectTrialDataMatsToFolder(parentFolder, destinationFolder, 'dryRun', true)
%
% Assumes each immediate subject folder under parentFolder contains a
% 'matlab' subfolder with one trialData MAT file to copy.
%
% Inputs:
%   parentFolder      - folder containing subject subfolders
%   destinationFolder - flat folder to receive copied MAT files
%
% Name-value pairs:
%   'subjectFolders'   - explicit list of subject folder names to include (default {})
%   'includePattern'   - regex include filter on subject folder names (default '')
%   'excludePattern'   - regex exclude filter on subject folder names (default '^\\.')
%   'filePattern'      - file glob inside each subject matlab folder (default '*.mat')
%   'requireSingleFile'- require exactly one match in each matlab folder (default true)
%   'overwrite'        - overwrite existing files in destination (default false)
%   'dryRun'           - report what would be copied without copying (default false)
%   'verbose'          - print progress (default true)
%   'continueOnError'  - continue after copy error (default true)
%
% Output:
%   results - table with columns:
%       subjectFolder, sourceFile, destinationFile, status, message

    p = inputParser;
    addRequired(p, 'parentFolder', @(x) ischar(x) || isstring(x));
    addRequired(p, 'destinationFolder', @(x) ischar(x) || isstring(x));
    addParameter(p, 'subjectFolders', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'includePattern', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'excludePattern', '^\.', @(x) ischar(x) || isstring(x));
    addParameter(p, 'filePattern', '*.mat', @(x) ischar(x) || isstring(x));
    addParameter(p, 'requireSingleFile', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'overwrite', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'dryRun', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'verbose', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'continueOnError', true, @(x) islogical(x) && isscalar(x));
    parse(p, parentFolder, destinationFolder, varargin{:});

    parentFolder = char(string(parentFolder));
    destinationFolder = char(string(destinationFolder));
    if ~isfolder(parentFolder)
        error('copySubjectTrialDataMatsToFolder:BadParent', 'Parent folder not found: %s', parentFolder);
    end

    if ~p.Results.dryRun && ~exist(destinationFolder, 'dir')
        mkdir(destinationFolder);
    end

    d = dir(parentFolder);
    d = d([d.isdir]);
    names = {d.name};
    names = names(~ismember(names, {'.','..'}));

    explicitSubjects = cellstr(string(p.Results.subjectFolders));
    includePattern = char(string(p.Results.includePattern));
    excludePattern = char(string(p.Results.excludePattern));
    filePattern = char(string(p.Results.filePattern));

    rows = struct('subjectFolder', {}, 'sourceFile', {}, 'destinationFile', {}, 'status', {}, 'message', {});

    for i = 1:numel(names)
        subjName = names{i};
        subjPath = fullfile(parentFolder, subjName);

        if ~isempty(explicitSubjects) && ~ismember(subjName, explicitSubjects)
            continue;
        end
        if ~isempty(includePattern) && isempty(regexp(subjName, includePattern, 'once'))
            continue;
        end
        if ~isempty(excludePattern) && ~isempty(regexp(subjName, excludePattern, 'once'))
            continue;
        end

        matlabFolder = fullfile(subjPath, 'matlab');
        if ~isfolder(matlabFolder)
            rows(end+1) = localRow(subjPath, '', '', 'skip', 'Missing matlab folder'); %#ok<AGROW>
            continue;
        end

        files = dir(fullfile(matlabFolder, filePattern));
        files = files(~[files.isdir]);
        if isempty(files)
            rows(end+1) = localRow(subjPath, '', '', 'skip', sprintf('No files matching %s', filePattern)); %#ok<AGROW>
            continue;
        end

        if p.Results.requireSingleFile && numel(files) ~= 1
            rows(end+1) = localRow(subjPath, '', '', 'skip', ...
                sprintf('Expected exactly 1 file in matlab folder, found %d', numel(files))); %#ok<AGROW>
            continue;
        end

        % Sort by date (newest first) for deterministic handling if multiple files exist.
        [~, ord] = sort([files.datenum], 'descend');
        files = files(ord);

        for f = 1:numel(files)
            src = fullfile(matlabFolder, files(f).name);
            dst = fullfile(destinationFolder, files(f).name);

            if exist(dst, 'file') && ~p.Results.overwrite
                rows(end+1) = localRow(subjPath, src, dst, 'exists', 'Destination exists (overwrite=false)'); %#ok<AGROW>
                continue;
            end

            if p.Results.dryRun
                rows(end+1) = localRow(subjPath, src, dst, 'dryrun', 'Would copy'); %#ok<AGROW>
                continue;
            end

            try
                copyfile(src, dst, 'f');
                rows(end+1) = localRow(subjPath, src, dst, 'ok', ''); %#ok<AGROW>
                if p.Results.verbose
                    fprintf('Copied %s -> %s\n', src, dst);
                end
            catch ME
                rows(end+1) = localRow(subjPath, src, dst, 'error', ME.message); %#ok<AGROW>
                if p.Results.verbose
                    fprintf('ERROR copying %s: %s\n', src, ME.message);
                end
                if ~p.Results.continueOnError
                    results = struct2table(rows);
                    return;
                end
            end
        end
    end

    if isempty(rows)
        results = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
            'VariableNames', {'subjectFolder','sourceFile','destinationFile','status','message'});
    else
        results = struct2table(rows);
    end
end

function r = localRow(subjectFolder, sourceFile, destinationFile, status, message)
    r = struct( ...
        'subjectFolder', string(subjectFolder), ...
        'sourceFile', string(sourceFile), ...
        'destinationFile', string(destinationFile), ...
        'status', string(status), ...
        'message', string(message));
end
