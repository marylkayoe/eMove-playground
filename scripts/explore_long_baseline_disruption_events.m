function out = explore_long_baseline_disruption_events(varargin)
% explore_long_baseline_disruption_events
%
% First-pass exploratory analysis for spontaneous low-animation disruption
% events in baseline-like portions of the mocap recordings.
%
% Interval modes:
%   'baselineStim'    - the explicit 180 s BASELINE stimulus presentation
%   'preBaselineGap'  - provisional interval from mocap start up to
%                       BASELINE onset (secondary exploratory mode)
%
% Outputs:
%   - subject-level summary CSV
%   - event table CSV
%   - representative trace figure
%   - cohort summary figure
%   - small markdown report

clearvars -except varargin
clc;

p = inputParser;
addParameter(p, 'repoRoot', '/Users/yoe/Documents/REPOS/eMove-playground', @(x) ischar(x) || isstring(x));
addParameter(p, 'dataRoot', '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject', @(x) ischar(x) || isstring(x));
addParameter(p, 'timelineSummaryCsv', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'groupingCsv', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'outDir', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'runLabel', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'intervalMode', 'baselineStim', @(x) any(strcmpi(string(x), ["baselineStim","preBaselineGap"])));
addParameter(p, 'minLongBaselineSec', 300, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'trimStartSec', 30, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'trimEndSec', 10, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'speedWindowSec', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'smoothSec', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'stableQuantile', 0.60, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'signalMarkerMode', 'uTorso', @(x) any(strcmpi(string(x), ["upperBody","head","uTorso","lTorso"])));
addParameter(p, 'eventZThreshold', 4.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'peakZThreshold', 6.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'minPeakProminenceZ', 2.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'grossZThreshold', 8.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'mergeGapSec', 0.35, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'minEventDurSec', 0.40, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'quietWindowSec', 0.0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'quietWindowMaxZ', 3.0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'refractorySec', 0.75, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'exportFigures', true, @(x) islogical(x) || (isnumeric(x) && isscalar(x)));
parse(p, varargin{:});

repoRoot = char(p.Results.repoRoot);
dataRoot = char(p.Results.dataRoot);
if isempty(p.Results.timelineSummaryCsv)
    timelineSummaryCsv = fullfile(dataRoot, 'derived', 'session_timeline', 'session_timeline_summary.csv');
else
    timelineSummaryCsv = char(p.Results.timelineSummaryCsv);
end
if isempty(p.Results.groupingCsv)
    groupingCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');
else
    groupingCsv = char(p.Results.groupingCsv);
end

intervalMode = char(string(p.Results.intervalMode));
signalMarkerMode = char(string(p.Results.signalMarkerMode));
if strlength(string(p.Results.outDir)) > 0
    outDir = char(string(p.Results.outDir));
else
    analysisStamp = datestr(now, 'yyyymmdd_HHMMSSFFF');
    if strlength(string(p.Results.runLabel)) > 0
        suffix = ['_' char(string(p.Results.runLabel))];
    else
        suffix = '';
    end
    outDir = fullfile(repoRoot, 'outputs', 'figures', ['long_baseline_disruption_' intervalMode '_' analysisStamp suffix]);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

summaryTbl = readtable(timelineSummaryCsv, 'TextType', 'string');
groupingTbl = readtable(groupingCsv, 'TextType', 'string');

markerGroups = localLoadCanonicalMarkerGroups(groupingTbl);
upperBodyMarkers = unique([markerGroups.HEAD; markerGroups.UTORSO; markerGroups.LTORSO], 'stable');
allIncludedMarkers = unique(groupingTbl.markerName(groupingTbl.include == 1), 'stable');

subjectRows = struct( ...
    'subjectID', {}, ...
    'matPath', {}, ...
    'baselineRefStartSec', {}, ...
    'analysisStartSec', {}, ...
    'analysisEndSec', {}, ...
    'analysisDurSec', {}, ...
    'frameRate', {}, ...
    'stableCenterMmps', {}, ...
    'stableScaleMmps', {}, ...
    'eventThresholdMmps', {}, ...
    'grossThresholdMmps', {}, ...
    'nCandidateEvents', {}, ...
    'nGrossEvents', {}, ...
    'candidateEventRatePerMin', {}, ...
    'grossEventRatePerMin', {}, ...
    'candidateMedianDurSec', {}, ...
    'candidateMedianPeakMmps', {}, ...
    'candidateMedianPeakZ', {}, ...
    'candidateMedianPeakProminenceZ', {}, ...
    'candidateRateEarlyPerMin', {}, ...
    'candidateRateLatePerMin', {}, ...
    'candidateLateFraction', {}, ...
    'status', {}, ...
    'message', {});

eventRows = struct( ...
    'subjectID', {}, ...
    'eventClass', {}, ...
    'eventIndex', {}, ...
    'startSec', {}, ...
    'endSec', {}, ...
    'durationSec', {}, ...
    'peakSec', {}, ...
    'peakTimeNorm', {}, ...
    'peakSpeedMmps', {}, ...
    'peakZ', {}, ...
    'peakProminenceZ', {}, ...
    'passesQuietPre', {}, ...
    'passesQuietPost', {}, ...
    'passesRefractory', {}, ...
    'acceptedStructural', {});

traceCache = struct();

for i = 1:height(summaryTbl)
    subj = upper(string(summaryTbl.subjectID(i)));
    matPath = string(summaryTbl.matPath(i));

    row = struct();
    row.subjectID = subj;
    row.matPath = matPath;
    row.baselineRefStartSec = NaN;
    row.analysisStartSec = NaN;
    row.analysisEndSec = NaN;
    row.analysisDurSec = NaN;
    row.frameRate = NaN;
    row.stableCenterMmps = NaN;
    row.stableScaleMmps = NaN;
    row.eventThresholdMmps = NaN;
    row.grossThresholdMmps = NaN;
    row.nCandidateEvents = NaN;
    row.nGrossEvents = NaN;
    row.candidateEventRatePerMin = NaN;
    row.grossEventRatePerMin = NaN;
    row.candidateMedianDurSec = NaN;
    row.candidateMedianPeakMmps = NaN;
    row.candidateMedianPeakZ = NaN;
    row.candidateMedianPeakProminenceZ = NaN;
    row.candidateRateEarlyPerMin = NaN;
    row.candidateRateLatePerMin = NaN;
    row.candidateLateFraction = NaN;
    row.status = "ok";
    row.message = "";

    try
        timelineCsv = fullfile(dataRoot, 'derived', 'session_timeline', sprintf('%s_session_timeline.csv', subj));
        timelineTbl = readtable(timelineCsv, 'TextType', 'string');
        seg = timelineTbl(timelineTbl.rowType == "segment", :);
        base = seg(seg.segmentType == "BASELINE", :);
        if isempty(base)
            error('No BASELINE segment found in timeline table.');
        end
        S = load(matPath, 'trialData');
        td = S.trialData;
        fr = localResolveFrameRate(td);
        row.frameRate = fr;

        baselineRefStartSec = double(base.startSec(1));
        row.baselineRefStartSec = baselineRefStartSec;

        switch intervalMode
            case 'baselineStim'
                intervalStartSec = double(base.startSec(1));
                intervalEndSec = double(base.endSec(1));
            case 'preBaselineGap'
                if baselineRefStartSec < p.Results.minLongBaselineSec
                    row.status = "excluded";
                    row.message = sprintf('Candidate pre-baseline interval %.1f s < %.1f s threshold.', ...
                        baselineRefStartSec, p.Results.minLongBaselineSec);
                    subjectRows(end+1,1) = row; %#ok<AGROW>
                    continue;
                end
                intervalStartSec = 0;
                intervalEndSec = baselineRefStartSec;
            otherwise
                error('Unknown intervalMode: %s', intervalMode);
        end

        analysisStartSec = intervalStartSec + p.Results.trimStartSec;
        analysisEndSec = intervalEndSec - p.Results.trimEndSec;
        if analysisEndSec <= analysisStartSec + 10
            row.status = "excluded";
            row.message = sprintf('Usable interval %.1f s too short after trimming.', analysisEndSec - analysisStartSec);
            subjectRows(end+1,1) = row; %#ok<AGROW>
            continue;
        end

        frameRange = max(1, floor(analysisStartSec * fr) + 1) : min(size(td.trajectoryData, 1), floor(analysisEndSec * fr));
        tSec = (frameRange(:) - 1) ./ fr;

        signalMarkers = localResolveSignalMarkers(markerGroups, signalMarkerMode, upperBodyMarkers);
        signalSpeed = localComputeAverageSpeed(td, signalMarkers, frameRange, fr, p.Results.speedWindowSec);
        allBodySpeed = localComputeAverageSpeed(td, allIncludedMarkers, frameRange, fr, p.Results.speedWindowSec);

        smoothFrames = max(3, round(p.Results.smoothSec * fr));
        signalSmooth = movmedian(signalSpeed, smoothFrames, 'omitnan');
        allBodySmooth = movmedian(allBodySpeed, smoothFrames, 'omitnan');

        valid = isfinite(signalSmooth);
        if nnz(valid) < 100
            row.status = "excluded";
            row.message = sprintf('Too few valid frames in %s signal.', signalMarkerMode);
            subjectRows(end+1,1) = row; %#ok<AGROW>
            continue;
        end

        quietCut = quantile(signalSmooth(valid), p.Results.stableQuantile);
        quietVals = signalSmooth(valid & signalSmooth <= quietCut);
        stableCenter = median(quietVals, 'omitnan');
        stableScale = 1.4826 * mad(quietVals, 1);
        if ~isfinite(stableScale) || stableScale <= 0
            stableScale = 1.4826 * mad(signalSmooth(valid), 1);
        end
        if ~isfinite(stableScale) || stableScale <= 0
            stableScale = std(signalSmooth(valid), 0, 'omitnan');
        end
        if ~isfinite(stableScale) || stableScale <= 0
            error('Stable scale collapsed to zero.');
        end

        eventThr = stableCenter + p.Results.eventZThreshold * stableScale;
        grossThr = stableCenter + p.Results.grossZThreshold * stableScale;
        analysisDurSec = analysisEndSec - analysisStartSec;

        isCandidate = signalSmooth > eventThr;
        isCandidate = localCloseBinaryRuns(isCandidate, round(p.Results.mergeGapSec * fr));
        [starts, ends] = localFindRuns(isCandidate);

        candidateEvents = struct('startIdx', {}, 'endIdx', {}, 'startSec', {}, 'endSec', {}, ...
            'durationSec', {}, 'peakIdx', {}, 'peakSec', {}, 'peakTimeNorm', {}, ...
            'peakSpeedMmps', {}, 'peakZ', {}, 'peakProminenceZ', {}, ...
            'passesQuietPre', {}, 'passesQuietPost', {}, 'passesRefractory', {}, ...
            'acceptedStructural', {}, 'isGross', {});
        grossEvents = candidateEvents;

        minFrames = max(1, round(p.Results.minEventDurSec * fr));
        quietFrames = round(p.Results.quietWindowSec * fr);
        lastAcceptedPeakIdx = -Inf;
        for k = 1:numel(starts)
            if ends(k) - starts(k) + 1 < minFrames
                continue;
            end
            idx = starts(k):ends(k);
            runSignal = signalSmooth(idx);
            [peakSpeed, localPeakOffset] = max(runSignal, [], 'omitnan');
            if ~isfinite(peakSpeed)
                continue;
            end
            peakIdx = idx(localPeakOffset);
            peakZ = (peakSpeed - stableCenter) ./ stableScale;
            peakPromZ = localEstimatePeakProminenceZ(signalSmooth, idx, peakIdx, stableCenter, stableScale);
            passesPeak = peakZ >= p.Results.peakZThreshold;
            passesProm = peakPromZ >= p.Results.minPeakProminenceZ;
            passesQuietPre = localCheckQuietWindow(signalSmooth, peakIdx, quietFrames, p.Results.quietWindowMaxZ, stableCenter, stableScale, 'pre');
            passesQuietPost = localCheckQuietWindow(signalSmooth, peakIdx, quietFrames, p.Results.quietWindowMaxZ, stableCenter, stableScale, 'post');
            passesRefractory = (peakIdx - lastAcceptedPeakIdx) >= max(1, round(p.Results.refractorySec * fr));
            acceptedStructural = passesPeak && passesProm && passesQuietPre && passesQuietPost && passesRefractory;
            if ~acceptedStructural
                continue;
            end
            isGrossEvent = peakSpeed > grossThr;
            ev = struct();
            ev.startIdx = starts(k);
            ev.endIdx = ends(k);
            ev.startSec = tSec(starts(k));
            ev.endSec = tSec(ends(k));
            ev.durationSec = ev.endSec - ev.startSec;
            ev.peakIdx = peakIdx;
            ev.peakSec = tSec(peakIdx);
            ev.peakTimeNorm = (ev.peakSec - analysisStartSec) ./ analysisDurSec;
            ev.peakSpeedMmps = peakSpeed;
            ev.peakZ = peakZ;
            ev.peakProminenceZ = peakPromZ;
            ev.passesQuietPre = passesQuietPre;
            ev.passesQuietPost = passesQuietPost;
            ev.passesRefractory = passesRefractory;
            ev.acceptedStructural = acceptedStructural;
            ev.isGross = isGrossEvent;
            lastAcceptedPeakIdx = peakIdx;
            if isGrossEvent
                grossEvents(end+1) = ev; %#ok<AGROW>
            else
                candidateEvents(end+1) = ev; %#ok<AGROW>
            end
        end

        row.analysisStartSec = analysisStartSec;
        row.analysisEndSec = analysisEndSec;
        row.analysisDurSec = analysisDurSec;
        row.stableCenterMmps = stableCenter;
        row.stableScaleMmps = stableScale;
        row.eventThresholdMmps = eventThr;
        row.grossThresholdMmps = grossThr;
        row.nCandidateEvents = numel(candidateEvents);
        row.nGrossEvents = numel(grossEvents);
        row.candidateEventRatePerMin = numel(candidateEvents) ./ (analysisDurSec / 60);
        row.grossEventRatePerMin = numel(grossEvents) ./ (analysisDurSec / 60);
        if ~isempty(candidateEvents)
            row.candidateMedianDurSec = median([candidateEvents.durationSec]);
            row.candidateMedianPeakMmps = median([candidateEvents.peakSpeedMmps]);
            row.candidateMedianPeakZ = median([candidateEvents.peakZ]);
            row.candidateMedianPeakProminenceZ = median([candidateEvents.peakProminenceZ]);
        end

        halfSec = analysisStartSec + analysisDurSec / 2;
        row.candidateRateEarlyPerMin = sum([candidateEvents.peakSec] < halfSec) ./ ((analysisDurSec / 2) / 60);
        row.candidateRateLatePerMin = sum([candidateEvents.peakSec] >= halfSec) ./ ((analysisDurSec / 2) / 60);
        if ~isempty(candidateEvents)
            row.candidateLateFraction = mean([candidateEvents.peakSec] >= halfSec);
        end

        for k = 1:numel(candidateEvents)
            eventRows(end+1,1) = localEventRow(subj, "candidate", k, candidateEvents(k)); %#ok<AGROW>
        end
        for k = 1:numel(grossEvents)
            eventRows(end+1,1) = localEventRow(subj, "gross", k, grossEvents(k)); %#ok<AGROW>
        end

        traceCache.(char(subj)) = struct( ...
            'tSec', tSec, ...
            'signalSmooth', signalSmooth, ...
            'allBodySmooth', allBodySmooth, ...
            'stableCenter', stableCenter, ...
            'stableScale', stableScale, ...
            'eventThr', eventThr, ...
            'grossThr', grossThr, ...
            'analysisStartSec', analysisStartSec, ...
            'analysisEndSec', analysisEndSec, ...
            'analysisDurSec', analysisDurSec, ...
            'signalLabel', signalMarkerMode, ...
            'candidateEvents', candidateEvents, ...
            'grossEvents', grossEvents);
    catch ME
        row.status = "error";
        row.message = sprintf('%s: %s', ME.identifier, ME.message);
    end

    subjectRows(end+1,1) = row; %#ok<AGROW>
end

subjectSummary = struct2table(subjectRows);
if isempty(eventRows)
    eventTable = localEmptyEventTable();
else
    eventTable = struct2table(eventRows);
end

summaryCsv = fullfile(outDir, 'subject_summary.csv');
eventsCsv = fullfile(outDir, 'event_table.csv');
writetable(subjectSummary, summaryCsv);
writetable(eventTable, eventsCsv);

included = subjectSummary(subjectSummary.status == "ok", :);
repSubject = localPickRepresentativeSubject(included);
if logical(p.Results.exportFigures) && strlength(repSubject) > 0
    repFig = localPlotRepresentativeTrace(repSubject, traceCache.(char(repSubject)), included, intervalMode);
    exportgraphics(repFig, fullfile(outDir, 'representative_trace.png'), 'Resolution', 220);
    exportgraphics(repFig, fullfile(outDir, 'representative_trace.pdf'), 'ContentType', 'vector');
    close(repFig);
end

if logical(p.Results.exportFigures) && ~isempty(included)
    cohortFig = localPlotCohortSummary(included, intervalMode);
    exportgraphics(cohortFig, fullfile(outDir, 'cohort_summary.png'), 'Resolution', 220);
    exportgraphics(cohortFig, fullfile(outDir, 'cohort_summary.pdf'), 'ContentType', 'vector');
    close(cohortFig);

    timingFig = localPlotTimingSummary(included, eventTable, intervalMode);
    exportgraphics(timingFig, fullfile(outDir, 'timing_summary.png'), 'Resolution', 220);
    exportgraphics(timingFig, fullfile(outDir, 'timing_summary.pdf'), 'ContentType', 'vector');
    close(timingFig);

    morphFig = localPlotEventMorphology(included, eventTable, traceCache);
    exportgraphics(morphFig, fullfile(outDir, 'event_morphology_summary.png'), 'Resolution', 220);
    exportgraphics(morphFig, fullfile(outDir, 'event_morphology_summary.pdf'), 'ContentType', 'vector');
    close(morphFig);
end

reportPath = fullfile(outDir, 'first_pass_report.md');
localWriteReport(reportPath, included, subjectSummary, p.Results, intervalMode);

fprintf('Saved outputs to %s\n', outDir);
disp(subjectSummary(:, {'subjectID','baselineRefStartSec','analysisDurSec','nCandidateEvents','nGrossEvents','candidateEventRatePerMin','candidateRateEarlyPerMin','candidateRateLatePerMin','status'}));

out = struct();
out.outDir = outDir;
out.subjectSummary = subjectSummary;
out.eventTable = eventTable;
out.reportPath = reportPath;
end

function markerGroups = localLoadCanonicalMarkerGroups(tbl)
    want = ["HEAD","UTORSO","LTORSO","LOWER_LIMB_L","LOWER_LIMB_R"];
    markerGroups = struct();
    for i = 1:numel(want)
        g = want(i);
        mask = tbl.include == 1 & upper(tbl.groupName) == g;
        markerGroups.(char(g)) = unique(tbl.markerName(mask), 'stable');
    end
end

function fr = localResolveFrameRate(td)
    fr = 120;
    if isfield(td, 'metaData') && isfield(td.metaData, 'captureFrameRate') && ~isempty(td.metaData.captureFrameRate)
        fr = double(td.metaData.captureFrameRate);
    end
end

function avgSpeed = localComputeAverageSpeed(td, markerNames, frameRange, fr, speedWindowSec)
    markerNames = cellstr(string(markerNames(:)));
    nFrames = numel(frameRange);
    nMarkers = numel(markerNames);
    markerSpeeds = NaN(nFrames, nMarkers);
    for i = 1:nMarkers
        idx = find(strcmp(td.markerNames, markerNames{i}), 1);
        if isempty(idx)
            continue;
        end
        xyz = squeeze(td.trajectoryData(frameRange, :, idx));
        markerSpeeds(:, i) = getTrajectorySpeed(xyz, fr, speedWindowSec);
    end
    avgSpeed = mean(markerSpeeds, 2, 'omitnan');
end

function signalMarkers = localResolveSignalMarkers(markerGroups, signalMarkerMode, upperBodyMarkers)
    switch lower(signalMarkerMode)
        case 'upperbody'
            signalMarkers = upperBodyMarkers;
        case 'head'
            signalMarkers = markerGroups.HEAD;
        case 'utorso'
            signalMarkers = markerGroups.UTORSO;
        case 'ltorso'
            signalMarkers = markerGroups.LTORSO;
        otherwise
            error('Unknown signalMarkerMode: %s', signalMarkerMode);
    end
end

function x = localCloseBinaryRuns(x, maxGapFrames)
    if maxGapFrames <= 0
        return;
    end
    x = logical(x(:));
    [starts, ends] = localFindRuns(~x);
    for i = 1:numel(starts)
        gapLen = ends(i) - starts(i) + 1;
        if gapLen <= maxGapFrames && starts(i) > 1 && ends(i) < numel(x)
            if x(starts(i)-1) && x(ends(i)+1)
                x(starts(i):ends(i)) = true;
            end
        end
    end
end

function [starts, ends] = localFindRuns(x)
    x = logical(x(:));
    dx = diff([false; x; false]);
    starts = find(dx == 1);
    ends = find(dx == -1) - 1;
end

function row = localEventRow(subj, eventClass, eventIndex, ev)
    row = struct();
    row.subjectID = subj;
    row.eventClass = string(eventClass);
    row.eventIndex = eventIndex;
    row.startSec = ev.startSec;
    row.endSec = ev.endSec;
    row.durationSec = ev.durationSec;
    row.peakSec = ev.peakSec;
    row.peakTimeNorm = ev.peakTimeNorm;
    row.peakSpeedMmps = ev.peakSpeedMmps;
    row.peakZ = ev.peakZ;
    row.peakProminenceZ = ev.peakProminenceZ;
    row.passesQuietPre = ev.passesQuietPre;
    row.passesQuietPost = ev.passesQuietPost;
    row.passesRefractory = ev.passesRefractory;
    row.acceptedStructural = ev.acceptedStructural;
end

function repSubject = localPickRepresentativeSubject(included)
    repSubject = "";
    if isempty(included)
        return;
    end
    good = included(included.nCandidateEvents >= 3 & included.nCandidateEvents <= 20, :);
    if isempty(good)
        good = included(included.nCandidateEvents == max(included.nCandidateEvents), :);
    end
    [~, idx] = max(good.analysisDurSec);
    repSubject = string(good.subjectID(idx));
end

function fig = localPlotRepresentativeTrace(subj, C, included, intervalMode)
    fig = figure('Color', 'w', 'Position', [100 100 1400 700]);
    tiledlayout(2,1, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile;
    hold(ax1, 'on');
    plot(ax1, C.tSec ./ 60, C.signalSmooth, 'Color', [0.1 0.3 0.8], 'LineWidth', 1.2);
    localShadeWindow(ax1, C.analysisStartSec, C.analysisEndSec, [0.93 0.96 1.00], 0.45);
    yline(ax1, C.stableCenter, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
    yline(ax1, C.eventThr, '--', 'Color', [0.85 0.2 0.2], 'LineWidth', 1.2);
    yline(ax1, C.grossThr, ':', 'Color', [0.55 0 0], 'LineWidth', 1.2);
    localShadeEvents(ax1, C.candidateEvents, [0.95 0.75 0.2], 0.25);
    localShadeEvents(ax1, C.grossEvents, [0.85 0.2 0.2], 0.18);
    localMarkEventPeaks(ax1, C.candidateEvents, [0.95 0.55 0.1]);
    localMarkEventPeaks(ax1, C.grossEvents, [0.75 0.05 0.05]);
    xlabel(ax1, 'Time from mocap start (min)');
    ylabel(ax1, sprintf('%s speed (mm/s)', C.signalLabel));
    title(ax1, sprintf('%s | %s trace', subj, intervalMode), 'FontWeight', 'bold');
    grid(ax1, 'on');
    box(ax1, 'off');

    ax2 = nexttile;
    hold(ax2, 'on');
    plot(ax2, C.tSec ./ 60, C.allBodySmooth, 'Color', [0.2 0.2 0.2], 'LineWidth', 1.1);
    localShadeWindow(ax2, C.analysisStartSec, C.analysisEndSec, [0.96 0.96 0.96], 0.65);
    localShadeEvents(ax2, C.candidateEvents, [0.95 0.75 0.2], 0.25);
    localShadeEvents(ax2, C.grossEvents, [0.85 0.2 0.2], 0.18);
    xline(ax2, (C.analysisStartSec + C.analysisDurSec / 2) / 60, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.0);
    xlabel(ax2, 'Time from mocap start (min)');
    ylabel(ax2, 'Whole-body speed (mm/s)');
    title(ax2, 'Whole-body reference envelope');
    grid(ax2, 'on');
    box(ax2, 'off');

    sgtitle(fig, sprintf('%s | %s | candidate events=%d | gross events=%d | cohort n=%d', ...
        subj, intervalMode, numel(C.candidateEvents), numel(C.grossEvents), height(included)), ...
        'FontWeight', 'bold', 'FontSize', 16);
end

function localShadeEvents(ax, events, colorVal, alphaVal)
    yl = ylim(ax);
    for i = 1:numel(events)
        x0 = events(i).startSec / 60;
        x1 = events(i).endSec / 60;
        patch(ax, [x0 x1 x1 x0], [yl(1) yl(1) yl(2) yl(2)], colorVal, ...
            'FaceAlpha', alphaVal, 'EdgeColor', 'none');
    end
    uistack(findobj(ax, 'Type', 'Line'), 'top');
end

function localShadeWindow(ax, startSec, endSec, colorVal, alphaVal)
    yl = ylim(ax);
    patch(ax, [startSec endSec endSec startSec] ./ 60, [yl(1) yl(1) yl(2) yl(2)], colorVal, ...
        'FaceAlpha', alphaVal, 'EdgeColor', 'none');
end

function localMarkEventPeaks(ax, events, colorVal)
    if isempty(events)
        return;
    end
    x = [events.peakSec] ./ 60;
    y = [events.peakSpeedMmps];
    scatter(ax, x, y, 28, colorVal, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
end

function fig = localPlotCohortSummary(included, intervalMode)
    fig = figure('Color', 'w', 'Position', [120 120 1400 500]);
    tiledlayout(1,3, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile;
    early = included.candidateRateEarlyPerMin;
    late = included.candidateRateLatePerMin;
    hold(ax1, 'on');
    for i = 1:height(included)
        plot(ax1, [1 2], [early(i) late(i)], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.0);
        scatter(ax1, 1, early(i), 36, [0.2 0.5 0.9], 'filled');
        scatter(ax1, 2, late(i), 36, [0.9 0.4 0.2], 'filled');
    end
    xlim(ax1, [0.6 2.4]);
    set(ax1, 'XTick', [1 2], 'XTickLabel', {'Early half','Late half'});
    ylabel(ax1, 'Candidate event rate (per min)');
    title(ax1, 'Event-rate drift');
    grid(ax1, 'on');
    box(ax1, 'off');

    ax2 = nexttile;
    scatter(ax2, included.analysisDurSec ./ 60, included.candidateEventRatePerMin, 64, included.nGrossEvents, 'filled');
    xlabel(ax2, 'Usable interval duration (min)');
    ylabel(ax2, 'Candidate event rate (per min)');
    title(ax2, 'Rate vs duration');
    grid(ax2, 'on');
    box(ax2, 'off');
    cb = colorbar(ax2);
    cb.Label.String = 'Gross-event count';

    ax3 = nexttile;
    histogram(ax3, included.candidateMedianPeakProminenceZ, 'FaceColor', [0.3 0.7 0.3], 'EdgeColor', 'none');
    xlabel(ax3, 'Median candidate peak prominence z');
    ylabel(ax3, 'Subjects');
    title(ax3, 'Candidate event morphology strength');
    grid(ax3, 'on');
    box(ax3, 'off');

    sgtitle(fig, sprintf('%s disruption structural assay | included subjects=%d', intervalMode, height(included)), ...
        'FontWeight', 'bold', 'FontSize', 16);
end

function fig = localPlotTimingSummary(included, eventTable, intervalMode)
    fig = figure('Color', 'w', 'Position', [120 120 1500 550]);
    tiledlayout(1,3, 'TileSpacing', 'compact', 'Padding', 'compact');

    cand = eventTable(eventTable.eventClass == "candidate", :);

    ax1 = nexttile;
    hold(ax1, 'on');
    for i = 1:height(included)
        plot(ax1, [1 2], [included.candidateRateEarlyPerMin(i) included.candidateRateLatePerMin(i)], ...
            '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0);
    end
    scatter(ax1, ones(height(included),1), included.candidateRateEarlyPerMin, 40, [0.2 0.5 0.9], 'filled');
    scatter(ax1, 2 * ones(height(included),1), included.candidateRateLatePerMin, 40, [0.9 0.4 0.2], 'filled');
    xlim(ax1, [0.6 2.4]);
    set(ax1, 'XTick', [1 2], 'XTickLabel', {'Early half','Late half'});
    ylabel(ax1, 'Candidate event rate (per min)');
    title(ax1, 'Early vs late rate');
    grid(ax1, 'on');
    box(ax1, 'off');

    ax2 = nexttile;
    if ~isempty(cand)
        histogram(ax2, cand.peakTimeNorm, 'BinEdges', 0:0.1:1, 'FaceColor', [0.25 0.55 0.85], 'EdgeColor', 'w');
    end
    xline(ax2, 0.5, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
    xlabel(ax2, 'Normalized event peak time within analyzed baseline');
    ylabel(ax2, 'Candidate events');
    title(ax2, 'Peak-time histogram');
    grid(ax2, 'on');
    box(ax2, 'off');

    ax3 = nexttile;
    hold(ax3, 'on');
    sortMat = [included.candidateLateFraction included.nCandidateEvents];
    [~, order] = sortrows(sortMat, [-1 -2]);
    ordered = included(order, :);
    for i = 1:height(ordered)
        subj = string(ordered.subjectID(i));
        subEvents = cand(cand.subjectID == subj, :);
        if isempty(subEvents)
            continue;
        end
        scatter(ax3, subEvents.peakTimeNorm, i * ones(height(subEvents),1), 34, subEvents.peakZ, 'filled');
    end
    xline(ax3, 0.5, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.0);
    xlim(ax3, [0 1]);
    ylim(ax3, [0 height(ordered)+1]);
    xlabel(ax3, 'Normalized event peak time');
    ylabel(ax3, 'Subjects');
    title(ax3, 'Subject timing raster');
    set(ax3, 'YTick', 1:height(ordered), 'YTickLabel', ordered.subjectID);
    grid(ax3, 'on');
    box(ax3, 'off');
    cb = colorbar(ax3);
    cb.Label.String = 'Peak z';

    sgtitle(fig, sprintf('%s timing summary | structural chest-speed candidates', intervalMode), ...
        'FontWeight', 'bold', 'FontSize', 16);
end

function fig = localPlotEventMorphology(included, eventTable, traceCache)
    fig = figure('Color', 'w', 'Position', [120 120 1500 550]);
    tiledlayout(1,3, 'TileSpacing', 'compact', 'Padding', 'compact');

    cand = eventTable(eventTable.eventClass == "candidate", :);
    winSec = 2.0;
    alignT = [];
    alignZ = [];
    for i = 1:height(cand)
        subj = char(cand.subjectID(i));
        if ~isfield(traceCache, subj)
            continue;
        end
        C = traceCache.(subj);
        if numel(C.tSec) < 3
            continue;
        end
        dt = median(diff(C.tSec));
        if ~isfinite(dt) || dt <= 0
            continue;
        end
        relT = -winSec:dt:winSec;
        peakSec = cand.peakSec(i);
        sampleSec = peakSec + relT;
        zTrace = (C.signalSmooth - C.stableCenter) ./ C.stableScale;
        zInterp = interp1(C.tSec, zTrace, sampleSec, 'linear', NaN);
        if isempty(alignT)
            alignT = relT;
        end
        if numel(zInterp) == numel(alignT)
            alignZ(end+1,:) = zInterp; %#ok<AGROW>
        end
    end

    ax1 = nexttile;
    hold(ax1, 'on');
    if ~isempty(alignZ)
        plot(ax1, alignT, alignZ', 'Color', [0.8 0.8 0.8 0.45], 'LineWidth', 0.6);
        medTrace = median(alignZ, 1, 'omitnan');
        loTrace = prctile(alignZ, 25, 1);
        hiTrace = prctile(alignZ, 75, 1);
        fill(ax1, [alignT fliplr(alignT)], [loTrace fliplr(hiTrace)], [0.75 0.88 1.0], ...
            'FaceAlpha', 0.55, 'EdgeColor', 'none');
        plot(ax1, alignT, medTrace, 'Color', [0.05 0.25 0.7], 'LineWidth', 2.2);
    end
    xline(ax1, 0, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
    yline(ax1, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
    xlabel(ax1, 'Time from event peak (s)');
    ylabel(ax1, 'Chest-speed z');
    title(ax1, 'Aligned chest-speed traces');
    grid(ax1, 'on');
    box(ax1, 'off');

    ax2 = nexttile;
    if ~isempty(cand)
        scatter(ax2, cand.peakProminenceZ, cand.durationSec, 42, cand.peakTimeNorm, 'filled');
    end
    xlabel(ax2, 'Peak prominence z');
    ylabel(ax2, 'Event duration (s)');
    title(ax2, 'Duration vs prominence');
    grid(ax2, 'on');
    box(ax2, 'off');
    cb = colorbar(ax2);
    cb.Label.String = 'Peak time norm';

    ax3 = nexttile;
    scatter(ax3, included.candidateMedianPeakProminenceZ, included.candidateLateFraction, 54, included.nCandidateEvents, 'filled');
    xlabel(ax3, 'Median subject peak prominence z');
    ylabel(ax3, 'Late-half fraction');
    title(ax3, 'Subject morphology vs lateness');
    ylim(ax3, [0 1]);
    grid(ax3, 'on');
    box(ax3, 'off');
    cb2 = colorbar(ax3);
    cb2.Label.String = 'Candidate count';

    sgtitle(fig, 'Structural candidate morphology summary', 'FontWeight', 'bold', 'FontSize', 16);
end

function peakPromZ = localEstimatePeakProminenceZ(signalSmooth, idx, peakIdx, stableCenter, stableScale)
    runVals = signalSmooth(idx);
    peakVal = signalSmooth(peakIdx);
    leftBase = min(runVals(1:(peakIdx - idx(1) + 1)), [], 'omitnan');
    rightBase = min(runVals((peakIdx - idx(1) + 1):end), [], 'omitnan');
    baseVal = max([leftBase rightBase stableCenter]);
    peakPromZ = (peakVal - baseVal) ./ stableScale;
end

function eventTable = localEmptyEventTable()
    eventTable = table( ...
        string.empty(0,1), string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), false(0,1), false(0,1), false(0,1), false(0,1), ...
        'VariableNames', {'subjectID','eventClass','eventIndex','startSec','endSec','durationSec', ...
        'peakSec','peakTimeNorm','peakSpeedMmps','peakZ','peakProminenceZ', ...
        'passesQuietPre','passesQuietPost','passesRefractory','acceptedStructural'});
end

function tf = localCheckQuietWindow(signalSmooth, peakIdx, quietFrames, quietWindowMaxZ, stableCenter, stableScale, mode)
    if quietFrames <= 0
        tf = true;
        return;
    end
    switch mode
        case 'pre'
            idx = max(1, peakIdx - quietFrames):max(1, peakIdx - 1);
        case 'post'
            idx = min(numel(signalSmooth), peakIdx + 1):min(numel(signalSmooth), peakIdx + quietFrames);
        otherwise
            error('Unknown quiet-window mode: %s', mode);
    end
    if isempty(idx)
        tf = false;
        return;
    end
    zVals = (signalSmooth(idx) - stableCenter) ./ stableScale;
    tf = all(zVals <= quietWindowMaxZ | ~isfinite(zVals));
end

function localWriteReport(reportPath, included, subjectSummary, params, intervalMode)
    fid = fopen(reportPath, 'w');
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '# Baseline Disruption Structural Pass\n\n');
    fprintf(fid, '## Working definition\n\n');
    if strcmp(intervalMode, 'baselineStim')
        fprintf(fid, '- Interval analyzed: explicit 180 s BASELINE stimulus presentation.\n');
    else
        fprintf(fid, '- Interval analyzed: provisional mocap-start to BASELINE-onset gap.\n');
        fprintf(fid, '- Subjects with candidate interval < %.0f s were excluded.\n', params.minLongBaselineSec);
    end
    fprintf(fid, '- Analysis trims first %.0f s and last %.0f s of the candidate interval.\n', params.trimStartSec, params.trimEndSec);
    fprintf(fid, '- Signal: smoothed %s marker-group speed.\n', char(string(params.signalMarkerMode)));
    fprintf(fid, '- Stable band estimated from the lower %.0f%% of that signal.\n', params.stableQuantile * 100);
    fprintf(fid, '- Candidate threshold: center + %.1f * MAD-scale.\n', params.eventZThreshold);
    fprintf(fid, '- Peak threshold: center + %.1f * MAD-scale.\n', params.peakZThreshold);
    fprintf(fid, '- Min peak prominence: %.1f z.\n', params.minPeakProminenceZ);
    fprintf(fid, '- Quiet-window requirement: %.1f s pre/post each with z <= %.1f.\n', params.quietWindowSec, params.quietWindowMaxZ);
    fprintf(fid, '- Refractory interval between accepted peaks: %.1f s.\n', params.refractorySec);
    fprintf(fid, '- Gross threshold: center + %.1f * MAD-scale.\n\n', params.grossZThreshold);

    fprintf(fid, '## Recording availability\n\n');
    fprintf(fid, '- Total subject MATs in timeline summary: %d\n', height(subjectSummary));
    fprintf(fid, '- Included in first pass: %d\n', height(included));
    fprintf(fid, '- Excluded as too short / failed: %d\n\n', height(subjectSummary) - height(included));

    if ~isempty(included)
        fprintf(fid, '## Structural-pass summary\n\n');
        fprintf(fid, '- Median usable analysis duration: %.1f min\n', median(included.analysisDurSec ./ 60));
        fprintf(fid, '- Median candidate event rate: %.2f events/min\n', median(included.candidateEventRatePerMin));
        fprintf(fid, '- Median gross event rate: %.2f events/min\n', median(included.grossEventRatePerMin));
        fprintf(fid, '- Median early-half candidate rate: %.2f events/min\n', median(included.candidateRateEarlyPerMin));
        fprintf(fid, '- Median late-half candidate rate: %.2f events/min\n', median(included.candidateRateLatePerMin));
        fprintf(fid, '- Median late-half candidate fraction: %.2f\n', median(included.candidateLateFraction, 'omitnan'));
        fprintf(fid, '- Median candidate peak-prominence z: %.2f\n\n', median(included.candidateMedianPeakProminenceZ, 'omitnan'));
    end

    fprintf(fid, '## Caveats\n\n');
    if strcmp(intervalMode, 'preBaselineGap')
        fprintf(fid, '- The analyzed interval is inferred from timeline gaps, not from an independently confirmed protocol label.\n');
    end
    fprintf(fid, '- This structural pass is still exploratory and should be treated as assay reconnaissance, not a grant-ready inferential result.\n');
    fprintf(fid, '- Event counts still depend on the structural criteria and threshold choices.\n');
end
