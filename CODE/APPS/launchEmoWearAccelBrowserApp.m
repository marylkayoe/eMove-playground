function H = launchEmoWearAccelBrowserApp(varargin)
% launchEmoWearAccelBrowserApp - Deployment-aware entrypoint for EmoWear browsing.
%
% Usage:
%   launchEmoWearAccelBrowserApp()
%   launchEmoWearAccelBrowserApp('dataRoot', '/path/to/EmoWear_zenodo_10407279')

    p = inputParser;
    addParameter(p, 'repoRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'dataRoot', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'promptForExternalData', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'visible', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});

    paths = localResolvePaths( ...
        char(string(p.Results.repoRoot)), ...
        char(string(p.Results.dataRoot)), ...
        p.Results.promptForExternalData);

    H = launchEmoWearAccelBrowser( ...
        'repoRoot', paths.repoRoot, ...
        'dataRoot', paths.dataRoot, ...
        'visible', p.Results.visible);
end

function paths = localResolvePaths(repoRootIn, dataRootIn, promptForExternalData)
    appRoot = localAppRoot();

    repoRoot = repoRootIn;
    if isempty(strtrim(repoRoot))
        repoRoot = localFirstExistingDir({ ...
            appRoot, ...
            fullfile(appRoot, 'eMove-playground'), ...
            fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))});
    end

    dataRoot = dataRootIn;
    if isempty(strtrim(dataRoot))
        dataRoot = localFirstExistingDir({ ...
            fullfile(repoRoot, 'data', 'EmoWear_zenodo_10407279'), ...
            fullfile(appRoot, 'data', 'EmoWear_zenodo_10407279'), ...
            '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279'});
    end

    if isempty(dataRoot) && promptForExternalData
        chosen = uigetdir(pwd, 'Select EmoWear_zenodo_10407279 folder');
        if ischar(chosen) && ~isequal(chosen, 0)
            dataRoot = chosen;
        end
    end

    if isempty(repoRoot)
        repoRoot = appRoot;
    end
    if isempty(dataRoot)
        error('launchEmoWearAccelBrowserApp:MissingDataRoot', ...
            'Could not resolve an EmoWear dataset folder.');
    end

    paths = struct('repoRoot', repoRoot, 'dataRoot', dataRoot);
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
