function resultsCell = runMotionMetricsBatchFromManifest(manifestInput, matRoot, markerLists, varargin)
% runMotionMetricsBatchFromManifest - Run motion metrics in manifest subject order.
%
% Pipeline stage:
%   Batch orchestrator for metric computation with manifest-driven subject ordering.
%   Computation details are delegated to getMotionMetricsAcrossStims().
%
% Usage:
%   resultsCell = runMotionMetricsBatchFromManifest(manifestCsv, matRoot, markerLists)
%
% Inputs:
%   manifestInput - manifest table or CSV path (from buildDatasetAssignments)
%   matRoot       - folder containing per-subject MAT files (e.g., matlab_from_manifest)
%   markerLists   - cell array of marker name lists (passed to getMotionMetricsAcrossStims)
%
% Optional name-value pairs:
%   'keepLatestMatPerSubject' - logical, pick latest MAT when multiple exist (default true)
%   'continueOnError'         - logical, keep processing after subject-level errors (default true)
%   'verbose'                 - logical, print progress (default true)
%
%   The remaining options are forwarded to getMotionMetricsAcrossStims:
%   'markerGroupNames', 'videoIDs', 'FRAMERATE', 'speedWindow',
%   'computeFrequencyMetrics', 'freqBands', 'freqMakePlot',
%   'makePlot', 'plotBands', 'stimVideoEmotionCoding', 'immobilityThreshold'
%
% Output:
%   resultsCell - cell array in manifest subject order, one entry per subject.
%                 Each entry contains:
%                   subjectID, fileName, filePath, results, summaryTable, errorMessage

    p = inputParser;
    addRequired(p, 'manifestInput', @(x) istable(x) || ischar(x) || isstring(x));
    addRequired(p, 'matRoot', @(x) ischar(x) || isstring(x));
    addRequired(p, 'markerLists', @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'keepLatestMatPerSubject', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'continueOnError', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'verbose', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'markerGroupNames', {});
    addParameter(p, 'videoIDs', {});
    addParameter(p, 'FRAMERATE', 120);
    addParameter(p, 'speedWindow', 0.1);
    addParameter(p, 'computeFrequencyMetrics', false);
    defaultBands = struct('tremor', [6 12], 'low', [0.5 3], 'mid', [3 6], 'high', [12 20]);
    addParameter(p, 'freqBands', defaultBands, @isstruct);
    addParameter(p, 'freqMakePlot', false);
    addParameter(p, 'makePlot', false);
    addParameter(p, 'plotBands', {'mid','tremor','high'});
    addParameter(p, 'stimVideoEmotionCoding', {});
    addParameter(p, 'immobilityThreshold', 35);
    parse(p, manifestInput, matRoot, markerLists, varargin{:});

    matRoot = char(string(p.Results.matRoot));
    if ~isfolder(matRoot)
        error('runMotionMetricsBatchFromManifest:BadMatRoot', 'MAT root does not exist: %s', matRoot);
    end

    manifestTbl = localLoadManifestTable(p.Results.manifestInput);
    subjects = localCollectSubjectsFromManifest(manifestTbl);
    if isempty(subjects)
        warning('runMotionMetricsBatchFromManifest:NoSubjects', ...
            'No subjects found in manifest. Returning empty resultsCell.');
        resultsCell = {};
        return;
    end

    nSubj = numel(subjects);
    resultsCell = cell(nSubj, 1);
    for i = 1:nSubj
        subjID = subjects{i};
        try
            matInfo = localResolveSubjectMatFile(matRoot, subjID, p.Results.keepLatestMatPerSubject);
            S = load(matInfo.fullPath);
            td = localExtractTrialData(S);

            if isfield(td, 'subjectID') && ~isempty(td.subjectID)
                subjID = char(string(td.subjectID));
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
                'fileName', matInfo.fileName, ...
                'filePath', matInfo.fullPath, ...
                'results', res, ...
                'summaryTable', sumTbl, ...
                'errorMessage', "");

            if p.Results.verbose
                fprintf('[%d/%d] OK %s -> %s\n', i, nSubj, subjID, matInfo.fileName);
            end
        catch ME
            if p.Results.continueOnError
                warning('runMotionMetricsBatchFromManifest:SubjectFailed', ...
                    '[%d/%d] Subject %s failed: %s', i, nSubj, subjID, ME.message);
                resultsCell{i} = struct( ...
                    'subjectID', subjID, ...
                    'fileName', "", ...
                    'filePath', "", ...
                    'results', [], ...
                    'summaryTable', table(), ...
                    'errorMessage', string(ME.message));
            else
                rethrow(ME);
            end
        end
    end
end

function T = localLoadManifestTable(manifestInput)
    if istable(manifestInput)
        T = manifestInput;
        return;
    end

    manifestPath = char(string(manifestInput));
    if ~isfile(manifestPath)
        error('runMotionMetricsBatchFromManifest:ManifestMissing', ...
            'Manifest file not found: %s', manifestPath);
    end
    opts = detectImportOptions(manifestPath, 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, intersect({'modality','assignedSubject'}, opts.VariableNames, 'stable'), 'string');
    T = readtable(manifestPath, opts);
end

function subjects = localCollectSubjectsFromManifest(T)
    if ~ismember('assignedSubject', T.Properties.VariableNames)
        error('runMotionMetricsBatchFromManifest:BadManifest', ...
            'Manifest is missing required column "assignedSubject".');
    end

    subj = upper(strtrim(string(T.assignedSubject)));
    subj(subj == "" | subj == "UNASSIGNED" | subj == "JANNE") = missing;
    subj = subj(~ismissing(subj));
    isValid = ~cellfun('isempty', regexp(cellstr(subj), '^[A-Z]{2}\d{4}$', 'once'));
    subj = subj(isValid);
    subjects = cellstr(unique(subj, 'stable'));
end

function matInfo = localResolveSubjectMatFile(matRoot, subjID, keepLatest)
    subjDir = fullfile(matRoot, subjID);
    if ~isfolder(subjDir)
        error('runMotionMetricsBatchFromManifest:SubjectFolderMissing', ...
            'Subject folder missing: %s', subjDir);
    end

    files = dir(fullfile(subjDir, '*.mat'));
    if isempty(files)
        error('runMotionMetricsBatchFromManifest:SubjectMatMissing', ...
            'No MAT files found under %s', subjDir);
    end

    pickIdx = 1;
    if keepLatest
        timestamps = NaT(numel(files),1);
        for i = 1:numel(files)
            timestamps(i) = localParseTakeTimestamp(files(i).name);
        end
        if any(~isnat(timestamps))
            ts = timestamps;
            ts(isnat(ts)) = datetime(1,1,1);
            [~, pickIdx] = max(ts);
        else
            [~, pickIdx] = max([files.datenum]);
        end
    end

    matInfo = struct();
    matInfo.fileName = files(pickIdx).name;
    matInfo.fullPath = fullfile(files(pickIdx).folder, files(pickIdx).name);
end

function dt = localParseTakeTimestamp(fileName)
% Parse names like "...Take_2025_08_25_05_19_25_PM.mat".
    dt = NaT;
    tok = regexp(fileName, 'Take_(\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}_[AP]M)\.mat$', ...
        'tokens', 'once');
    if isempty(tok)
        return;
    end
    s = strrep(tok{1}, '_', ' ');
    try
        dt = datetime(s, 'InputFormat', 'yyyy MM dd hh mm ss a');
    catch
        dt = NaT;
    end
end

function td = localExtractTrialData(S)
    if isfield(S, 'trialData')
        td = S.trialData;
        return;
    end

    f = fieldnames(S);
    for i = 1:numel(f)
        if isstruct(S.(f{i}))
            td = S.(f{i});
            return;
        end
    end

    error('runMotionMetricsBatchFromManifest:TrialDataMissing', ...
        'No trialData struct found in MAT file.');
end
