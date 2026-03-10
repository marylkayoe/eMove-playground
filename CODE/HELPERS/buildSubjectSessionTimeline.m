function [timelineTable, summary] = buildSubjectSessionTimeline(trialData, varargin)
% buildSubjectSessionTimeline - Build a per-subject session timeline from trialData metadata.
%
% Purpose:
%   Represent the subject-level experiment structure on a common time axis
%   (seconds from mocap start), including explicit GAP rows.
%
% Inputs:
%   trialData - struct with:
%       trialData.metaData.videoIDs
%       trialData.metaData.stimScheduling (start/end frames)
%       trialData.metaData.captureFrameRate (preferred)
%
% Name-value pairs:
%   'frameRate'           - override frame rate (default: trialData.metaData.captureFrameRate or 120)
%   'baselineVideoID'     - baseline label (default 'BASELINE')
%   'includePreFirstGap'  - include gap from t=0 to first segment start (default true)
%   'includeInterGaps'    - include gaps between consecutive segments (default true)
%
% Outputs:
%   timelineTable - tidy table with columns:
%       subjectID, rowType, segmentType, segmentOrder, videoID,
%       startSec, endSec, durationSec, gapBeforeSec, overlapBeforeSec
%   summary - struct with session summary statistics
%
% Notes:
%   This utility does not compute motion metrics.

    p = inputParser;
    addRequired(p, 'trialData', @isstruct);
    addParameter(p, 'frameRate', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    addParameter(p, 'baselineVideoID', 'BASELINE', @(x) ischar(x) || isstring(x));
    addParameter(p, 'includePreFirstGap', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'includeInterGaps', true, @(x) islogical(x) && isscalar(x));
    parse(p, trialData, varargin{:});

    [metaData, subjectID] = localValidateInput(trialData);
    frameRate = localResolveFrameRate(metaData, p.Results.frameRate);
    baselineVideoID = upper(strtrim(char(string(p.Results.baselineVideoID))));

    rawVideoIDs = string(metaData.videoIDs(:));
    stimFrames = double(metaData.stimScheduling);

    startSec = stimFrames(:, 1) ./ frameRate;
    endSec = stimFrames(:, 2) ./ frameRate;

    % Ensure chronological order even if upstream ordering changed.
    baseTbl = table(rawVideoIDs, startSec, endSec, ...
        'VariableNames', {'videoID','startSec','endSec'});
    baseTbl = sortrows(baseTbl, {'startSec','endSec'});
    baseTbl.videoID = upper(strtrim(baseTbl.videoID));

    segType = repmat("STIM", height(baseTbl), 1);
    isBaseline = strcmpi(baseTbl.videoID, baselineVideoID) | contains(lower(baseTbl.videoID), 'baseline');
    segType(isBaseline) = "BASELINE";
    baseTbl.segmentType = segType;
    baseTbl.durationSec = baseTbl.endSec - baseTbl.startSec;

    rows = struct( ...
        'subjectID', {}, ...
        'rowType', {}, ...
        'segmentType', {}, ...
        'segmentOrder', {}, ...
        'videoID', {}, ...
        'startSec', {}, ...
        'endSec', {}, ...
        'durationSec', {}, ...
        'gapBeforeSec', {}, ...
        'overlapBeforeSec', {});

    carryEndSec = 0;
    segmentOrder = 0;

    for i = 1:height(baseTbl)
        thisStart = baseTbl.startSec(i);
        thisEnd = baseTbl.endSec(i);

        if i == 1
            gapBefore = thisStart;
            overlapBefore = 0;
            if p.Results.includePreFirstGap && gapBefore > 0
                rows(end+1,1) = localMakeRow(subjectID, "gap", "GAP", 0, "GAP_PRE", ...
                    0, thisStart, gapBefore, NaN, 0); %#ok<AGROW>
            end
        else
            gapDelta = thisStart - carryEndSec;
            if gapDelta >= 0
                gapBefore = gapDelta;
                overlapBefore = 0;
                if p.Results.includeInterGaps && gapDelta > 0
                    rows(end+1,1) = localMakeRow(subjectID, "gap", "GAP", segmentOrder, "GAP", ...
                        carryEndSec, thisStart, gapDelta, gapDelta, 0); %#ok<AGROW>
                end
            else
                gapBefore = 0;
                overlapBefore = abs(gapDelta);
            end
        end

        segmentOrder = segmentOrder + 1;
        rows(end+1,1) = localMakeRow(subjectID, "segment", baseTbl.segmentType(i), segmentOrder, ...
            baseTbl.videoID(i), thisStart, thisEnd, baseTbl.durationSec(i), gapBefore, overlapBefore); %#ok<AGROW>

        carryEndSec = max(carryEndSec, thisEnd);
    end

    if isempty(rows)
        timelineTable = table();
    else
        timelineTable = struct2table(rows);
    end

    summary = localBuildSummary(timelineTable, subjectID);
end

function [metaData, subjectID] = localValidateInput(trialData)
    if ~isfield(trialData, 'metaData') || ~isstruct(trialData.metaData)
        error('buildSubjectSessionTimeline:MissingMetaData', ...
            'trialData.metaData is required.');
    end
    metaData = trialData.metaData;

    needed = {'videoIDs','stimScheduling'};
    for i = 1:numel(needed)
        if ~isfield(metaData, needed{i})
            error('buildSubjectSessionTimeline:MissingMetaField', ...
                'trialData.metaData.%s is required.', needed{i});
        end
    end

    if isempty(metaData.videoIDs) || isempty(metaData.stimScheduling)
        error('buildSubjectSessionTimeline:EmptyScheduling', ...
            'videoIDs/stimScheduling is empty.');
    end

    if size(metaData.stimScheduling, 2) ~= 2
        error('buildSubjectSessionTimeline:BadSchedulingShape', ...
            'stimScheduling must be N x 2 [startFrame, endFrame].');
    end

    if numel(metaData.videoIDs) ~= size(metaData.stimScheduling, 1)
        error('buildSubjectSessionTimeline:CountMismatch', ...
            'videoIDs count (%d) does not match stimScheduling rows (%d).', ...
            numel(metaData.videoIDs), size(metaData.stimScheduling, 1));
    end

    subjectID = "UNKNOWN";
    if isfield(trialData, 'subjectID') && ~isempty(trialData.subjectID)
        subjectID = upper(string(trialData.subjectID));
    end
end

function frameRate = localResolveFrameRate(metaData, overrideFrameRate)
    if ~isempty(overrideFrameRate)
        frameRate = overrideFrameRate;
        return;
    end

    frameRate = [];
    if isfield(metaData, 'captureFrameRate') && ~isempty(metaData.captureFrameRate)
        frameRate = double(metaData.captureFrameRate);
    end
    if isempty(frameRate) || ~isfinite(frameRate) || frameRate <= 0
        frameRate = 120;
    end
end

function row = localMakeRow(subjectID, rowType, segmentType, segmentOrder, videoID, ...
    startSec, endSec, durationSec, gapBeforeSec, overlapBeforeSec)

    row = struct();
    row.subjectID = string(subjectID);
    row.rowType = string(rowType);
    row.segmentType = string(segmentType);
    row.segmentOrder = double(segmentOrder);
    row.videoID = string(videoID);
    row.startSec = double(startSec);
    row.endSec = double(endSec);
    row.durationSec = double(durationSec);
    row.gapBeforeSec = double(gapBeforeSec);
    row.overlapBeforeSec = double(overlapBeforeSec);
end

function summary = localBuildSummary(timelineTable, subjectID)
    summary = struct();
    summary.subjectID = char(subjectID);

    if isempty(timelineTable)
        summary.nSegments = 0;
        summary.nStimSegments = 0;
        summary.nBaselineSegments = 0;
        summary.nGapRows = 0;
        summary.totalGapSec = 0;
        summary.maxGapSec = 0;
        summary.totalOverlapSec = 0;
        summary.nOverlapTransitions = 0;
        summary.sessionStartSec = NaN;
        summary.sessionEndSec = NaN;
        summary.sessionSpanSec = NaN;
        return;
    end

    isSegment = timelineTable.rowType == "segment";
    isGap = timelineTable.rowType == "gap";
    isBaseline = timelineTable.segmentType == "BASELINE";
    isStim = timelineTable.segmentType == "STIM";

    summary.nSegments = sum(isSegment);
    summary.nStimSegments = sum(isSegment & isStim);
    summary.nBaselineSegments = sum(isSegment & isBaseline);
    summary.nGapRows = sum(isGap);
    summary.totalGapSec = sum(timelineTable.durationSec(isGap), 'omitnan');
    summary.maxGapSec = max([0; timelineTable.durationSec(isGap)]);
    summary.totalOverlapSec = sum(timelineTable.overlapBeforeSec(isSegment), 'omitnan');
    summary.nOverlapTransitions = sum(timelineTable.overlapBeforeSec(isSegment) > 0);
    summary.sessionStartSec = min(timelineTable.startSec, [], 'omitnan');
    summary.sessionEndSec = max(timelineTable.endSec, [], 'omitnan');
    summary.sessionSpanSec = summary.sessionEndSec - summary.sessionStartSec;
end
