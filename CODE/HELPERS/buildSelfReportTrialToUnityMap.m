function mapTable = buildSelfReportTrialToUnityMap(unityFolder, varargin)
% buildSelfReportTrialToUnityMap - Map self-report trial keys (G1..Gn) to Unity presentation order.
%
% Scope:
%   Creates an explicit lookup table only.
%   Does not compute motion or physiological metrics.
%
% Usage:
%   mapTable = buildSelfReportTrialToUnityMap('/subject/unitylogs')
%   mapTable = buildSelfReportTrialToUnityMap(..., 'nStimTrials', 15)
%
% Name-value pairs:
%   'trialPrefix'            - default 'G'
%   'nStimTrials'            - number of self-report stim blocks to map (default 15)
%   'anchorVideoID'          - anchor event in Unity logs (default 'BASELINE')
%   'anchorOccurrence'       - which anchor to use if repeated: 'last' (default) or 'first'
%   'mapOnlyAfterAnchor'     - if true, map only logs after anchor (default true)
%   'excludeBaselineEntries' - remove baseline entries from mapped candidates (default true)
%   'deduplicateVideoIDs'    - if true, keep first occurrence of repeated video IDs (default true)
%
% Output columns:
%   trialKey, presentationIndex, videoID, unityLogFileName, startSec, endSec

    p = inputParser;
    addRequired(p, 'unityFolder', @(x) ischar(x) || isstring(x));
    addParameter(p, 'trialPrefix', 'G', @(x) ischar(x) || isstring(x));
    addParameter(p, 'nStimTrials', 15, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'anchorVideoID', 'BASELINE', @(x) ischar(x) || isstring(x));
    addParameter(p, 'anchorOccurrence', 'last', @(x) any(strcmpi(string(x), ["first","last"])));
    addParameter(p, 'mapOnlyAfterAnchor', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'excludeBaselineEntries', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'deduplicateVideoIDs', true, @(x) islogical(x) && isscalar(x));
    parse(p, unityFolder, varargin{:});

    unityFolder = char(string(p.Results.unityFolder));
    trialPrefix = char(string(p.Results.trialPrefix));
    nStimTrials = p.Results.nStimTrials;
    anchorVideoID = char(string(p.Results.anchorVideoID));
    anchorOccurrence = lower(char(string(p.Results.anchorOccurrence)));

    [videoIDs, timeMatrix, logFileNames] = getStimVideoScheduling(unityFolder);

    keepMask = true(numel(videoIDs), 1);

    if p.Results.mapOnlyAfterAnchor
        anchorIdxAll = find(strcmpi(videoIDs, anchorVideoID));
        if isempty(anchorIdxAll)
            warning('buildSelfReportTrialToUnityMap:AnchorMissing', ...
                'Anchor videoID "%s" not found. Using full ordered log list.', anchorVideoID);
        else
            if strcmp(anchorOccurrence, 'first')
                anchorIdx = anchorIdxAll(1);
            else
                % Default: use the last baseline/demo anchor and ignore earlier blocks.
                anchorIdx = anchorIdxAll(end);
            end
            keepMask(1:anchorIdx) = false;
        end
    end

    if p.Results.excludeBaselineEntries
        isBaseline = strcmpi(videoIDs, 'BASELINE') | contains(lower(videoIDs), 'baseline');
        keepMask = keepMask & ~isBaseline;
    end

    candidateVideoIDs = videoIDs(keepMask);
    candidateTimes = timeMatrix(keepMask, :);
    candidateLogFiles = logFileNames(keepMask);

    if p.Results.deduplicateVideoIDs
        normVideoIDs = lower(string(candidateVideoIDs));
        [~, firstOccurrenceIdx] = unique(normVideoIDs, 'stable');
        dedupMask = false(numel(candidateVideoIDs), 1);
        dedupMask(firstOccurrenceIdx) = true;

        nRemoved = sum(~dedupMask);
        if nRemoved > 0
            warning('buildSelfReportTrialToUnityMap:DuplicateVideoIDs', ...
                ['Removed %d duplicate post-anchor Unity logs by videoID ', ...
                 '(kept first occurrence in chronological order).'], nRemoved);
        end

        candidateVideoIDs = candidateVideoIDs(dedupMask);
        candidateTimes = candidateTimes(dedupMask, :);
        candidateLogFiles = candidateLogFiles(dedupMask);
    end

    nAvailable = numel(candidateVideoIDs);
    nMap = min(nStimTrials, nAvailable);

    trialKey = strings(nMap, 1);
    presentationIndex = (1:nMap)';
    for i = 1:nMap
        trialKey(i) = sprintf('%s%d', trialPrefix, i);
    end

    mapTable = table( ...
        trialKey, ...
        presentationIndex, ...
        string(candidateVideoIDs(1:nMap)), ...
        string(candidateLogFiles(1:nMap)), ...
        candidateTimes(1:nMap, 1), ...
        candidateTimes(1:nMap, 2), ...
        'VariableNames', {'trialKey','presentationIndex','videoID','unityLogFileName','startSec','endSec'});

    if nAvailable ~= nStimTrials
        warning('buildSelfReportTrialToUnityMap:CountMismatch', ...
            ['Requested %d stim trials but found %d non-baseline Unity logs in %s. ', ...
             'Returned min(%d,%d) rows.'], ...
            nStimTrials, nAvailable, unityFolder, nStimTrials, nAvailable);
    end
end
