function resultsCell = runMotionMetricsBatch(folderPath, markerLists, varargin)
% runMotionMetricsBatch - Run motion metrics across all MAT trial files in a folder.
%
% Pipeline stage:
%   Batch orchestrator for metric computation.
%   Computation details are delegated to getMotionMetricsAcrossStims()
%   and lower-level metric functions.
%
%   resultsCell = runMotionMetricsBatch(folderPath, markerLists, ...)
%
% Inputs:
%   folderPath   - path containing *.mat files (one subject trialData per file)
%   markerLists  - cell array of marker name lists (passed to getMotionMetricsAcrossStims)
%
% Optional name-value pairs (forwarded where applicable):
%   'markerGroupNames'        - cell array of names for markerLists
%   'videoIDs'                - override list of video IDs
%   'FRAMERATE'               - frames per second
%   'speedWindow'             - speed window (s)
%   'computeFrequencyMetrics' - logical
%   'freqBands'               - struct of bands
%   'freqMakePlot'            - logical
%   'makePlot'                - logical
%   'plotBands'               - bands to plot
%   'stimVideoEmotionCoding'  - coding table for grouping colors
%   'immobilityThreshold'     - speed threshold for immobility metrics (mm/s)
%
% Output:
%   resultsCell - cell array; one entry per MAT file with fields:
%                   subjectID, fileName, results, summaryTable
%
% Notes:
%   - Expects each MAT file to contain a variable named trialData. If not,
%     the first struct found will be used as trialData.
%   - Subject ID is derived from the file name prefix before the first
%     underscore, and overridden by trialData.subjectID if present.

    p = inputParser;
    addRequired(p, 'folderPath', @(x) ischar(x) || isstring(x));
    addRequired(p, 'markerLists', @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'markerGroupNames', {});
    addParameter(p, 'videoIDs', {});
    addParameter(p, 'FRAMERATE', 120);
    addParameter(p, 'speedWindow', 0.1);
    addParameter(p, 'computeFrequencyMetrics', false);
       defaultBands = struct( ...
        'tremor', [6 12], ...
        'low',    [0.5 3], ...
        'mid',    [3 6], ...
        'high',   [12 20]);
    addParameter(p, 'freqBands', defaultBands, @isstruct);
    addParameter(p, 'freqMakePlot', false);
    addParameter(p, 'makePlot', false);
    addParameter(p, 'plotBands', {'mid','tremor','high'});
    addParameter(p, 'stimVideoEmotionCoding', {});
    addParameter(p, 'immobilityThreshold', 35);
    parse(p, folderPath, markerLists, varargin{:});

    folderPath = char(folderPath);
    files = dir(fullfile(folderPath, '*.mat'));
    resultsCell = cell(numel(files), 1);

    for i = 1:numel(files)
        fileName = files(i).name;
        matPath = fullfile(folderPath, fileName);
        data = load(matPath);

        if isfield(data, 'trialData')
            td = data.trialData;
        else
            % fallback: first struct in the file
            structNames = fieldnames(data);
            td = data.(structNames{1});
        end

        % derive subject ID from filename prefix, override with td.subjectID if present
        subjID = '';
        tok = regexp(fileName, '^([^_]+)_', 'tokens', 'once');
        if ~isempty(tok)
            subjID = tok{1};
        end
        if isfield(td, 'subjectID') && ~isempty(td.subjectID)
            subjID = char(td.subjectID);
        end

        [res, sumTbl] = getMotionMetricsAcrossStims(td, markerLists, ...
            'markerGroupNames', p.Results.markerGroupNames, ...
            'videoIDs', p.Results.videoIDs, ...
            'FRAMERATE', p.Results.FRAMERATE, ...
            'speedWindow', p.Results.speedWindow, ...
            'computeFrequencyMetrics', p.Results.computeFrequencyMetrics, ...
            'freqBands', p.Results.freqBands, ...
            'freqMakePlot', p.Results.freqMakePlot, ...
            'makePlot', p.Results.makePlot, ...
            'plotBands', p.Results.plotBands, ...
            'stimVideoEmotionCoding', p.Results.stimVideoEmotionCoding, ...
            'immobilityThreshold', p.Results.immobilityThreshold, ...
            'subjectID', subjID);

        resultsCell{i} = struct( ...
            'subjectID', subjID, ...
            'fileName', fileName, ...
            'results', res, ...
            'summaryTable', sumTbl);
    end
end
