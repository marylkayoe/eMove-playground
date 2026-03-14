function H = launchMicromovementExplorerApp(varargin)
% launchMicromovementExplorerApp - Deployment-aware entrypoint for the micromovement browser.
%
% Usage:
%   launchMicromovementExplorerApp()
%   launchMicromovementExplorerApp('matRoot', '/path/to/matlab_from_manifest')
%
% Resolution order:
%   1) explicit name-value inputs
%   2) bundled app data/resources relative to app root / ctfroot
%   3) user-selected external processed-data folder

    p = inputParser;
    addParameter(p, 'repoRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'matRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'groupCsv', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'stimCsv', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'promptForExternalData', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});

    paths = localResolvePaths( ...
        char(string(p.Results.repoRoot)), ...
        char(string(p.Results.matRoot)), ...
        char(string(p.Results.groupCsv)), ...
        char(string(p.Results.stimCsv)), ...
        p.Results.promptForExternalData);

    H = launchMicromovementExampleBrowser( ...
        'repoRoot', paths.repoRoot, ...
        'matRoot', paths.matRoot, ...
        'groupCsv', paths.groupCsv, ...
        'stimCsv', paths.stimCsv);
end

function paths = localResolvePaths(repoRootIn, matRootIn, groupCsvIn, stimCsvIn, promptForExternalData)
    appRoot = localAppRoot();
    repoRoot = repoRootIn;
    if isempty(strtrim(repoRoot))
        repoRoot = localFirstExistingDir({ ...
            appRoot, ...
            fullfile(appRoot, 'eMove-playground'), ...
            fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))});
    end

    groupCsv = groupCsvIn;
    if isempty(strtrim(groupCsv))
        groupCsv = localFirstExistingFile({ ...
            fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv'), ...
            fullfile(appRoot, 'resources', 'bodypart_marker_grouping.csv')});
    end

    stimCsv = stimCsvIn;
    if isempty(strtrim(stimCsv))
        stimCsv = localFirstExistingFile({ ...
            fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv'), ...
            fullfile(appRoot, 'resources', 'stim_video_encoding_SINGLES.csv')});
    end

    matRoot = matRootIn;
    if isempty(strtrim(matRoot))
        matRoot = localFirstExistingDir({ ...
            fullfile(repoRoot, 'data', 'matlab_from_manifest'), ...
            fullfile(appRoot, 'data', 'matlab_from_manifest'), ...
            '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest'});
    end

    if isempty(matRoot) && promptForExternalData
        chosen = uigetdir(pwd, 'Select matlab_from_manifest folder');
        if ischar(chosen) && ~isequal(chosen, 0)
            matRoot = chosen;
        end
    end

    if isempty(repoRoot)
        repoRoot = appRoot;
    end
    if isempty(groupCsv)
        error('launchMicromovementExplorerApp:MissingGroupingCsv', ...
            'Could not resolve bodypart grouping CSV.');
    end
    if isempty(stimCsv)
        error('launchMicromovementExplorerApp:MissingStimCsv', ...
            'Could not resolve stimulus coding CSV.');
    end
    if isempty(matRoot)
        error('launchMicromovementExplorerApp:MissingMatRoot', ...
            'Could not resolve a matlab_from_manifest dataset folder.');
    end

    paths = struct( ...
        'repoRoot', repoRoot, ...
        'matRoot', matRoot, ...
        'groupCsv', groupCsv, ...
        'stimCsv', stimCsv);
end

function appRoot = localAppRoot()
    if isdeployed
        appRoot = ctfroot;
    else
        appRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    end
end

function out = localFirstExistingDir(candidates)
    out = '';
    for i = 1:numel(candidates)
        c = char(string(candidates{i}));
        if ~isempty(strtrim(c)) && isfolder(c)
            out = c;
            return;
        end
    end
end

function out = localFirstExistingFile(candidates)
    out = '';
    for i = 1:numel(candidates)
        c = char(string(candidates{i}));
        if ~isempty(strtrim(c)) && isfile(c)
            out = c;
            return;
        end
    end
end
