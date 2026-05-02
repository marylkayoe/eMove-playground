function out = explore_baseline_lar_exits(varargin)
% explore_baseline_lar_exits
%
% Explore brief exits from the low-animation regime during BASELINE.
%
% Working idea:
%   - define LAR/immobile frames directly from chest-speed thresholding
%   - define an exit as a mobile run bracketed by immobile bouts
%   - retain only brief exits, then inspect their timing across baseline

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
addParameter(p, 'signalMarkerMode', 'uTorso', @(x) any(strcmpi(string(x), ["upperBody","head","uTorso","lTorso"])));
addParameter(p, 'minLongBaselineSec', 300, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'trimStartSec', 10, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'trimEndSec', 5, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'speedWindowSec', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'smoothSec', 0.25, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'immobilityThresholdMmps', 35, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'immobileMinDurSec', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'mobileMinDurSec', 0.15, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'briefExitMaxDurSec', 4.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'mobileMergeGapSec', 0.20, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'minPeakSpeedMmps', 40, @(x) isnumeric(x) && isscalar(x) && x >= 0);
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
    outDir = fullfile(repoRoot, 'outputs', 'figures', ['baseline_lar_exit_' intervalMode '_' analysisStamp suffix]);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

summaryTbl = readtable(timelineSummaryCsv, 'TextType', 'string');
groupingTbl = readtable(groupingCsv, 'TextType', 'string');

markerGroups = localLoadCanonicalMarkerGroups(groupingTbl);
upperBodyMarkers = unique([markerGroups.HEAD; markerGroups.UTORSO; markerGroups.LTORSO], 'stable');

subjectRows = struct( ...
    'subjectID', {}, ...
    'analysisStartSec', {}, ...
    'analysisEndSec', {}, ...
    'analysisDurSec', {}, ...
    'frameRate', {}, ...
    'nImmobileBouts', {}, ...
    'immobileFrac', {}, ...
    'nBriefExits', {}, ...
    'briefExitRatePerMin', {}, ...
    'briefExitRateEarlyPerMin', {}, ...
    'briefExitRateLatePerMin', {}, ...
    'briefExitLateFraction', {}, ...
    'medianExitDurSec', {}, ...
    'medianExitPeakMmps', {}, ...
    'status', {}, ...
    'message', {});

exitRows = struct( ...
    'subjectID', {}, ...
    'exitIndex', {}, ...
    'startSec', {}, ...
    'endSec', {}, ...
    'durationSec', {}, ...
    'peakSec', {}, ...
    'peakTimeNorm', {}, ...
    'peakSpeedMmps', {}, ...
    'meanSpeedMmps', {}, ...
    'preImmobileDurSec', {}, ...
    'postImmobileDurSec', {});

traceCache = struct();

for i = 1:height(summaryTbl)
    subj = upper(string(summaryTbl.subjectID(i)));
    matPath = string(summaryTbl.matPath(i));

    row = struct();
    row.subjectID = subj;
    row.analysisStartSec = NaN;
    row.analysisEndSec = NaN;
    row.analysisDurSec = NaN;
    row.frameRate = NaN;
    row.nImmobileBouts = NaN;
    row.immobileFrac = NaN;
    row.nBriefExits = NaN;
    row.briefExitRatePerMin = NaN;
    row.briefExitRateEarlyPerMin = NaN;
    row.briefExitRateLatePerMin = NaN;
    row.briefExitLateFraction = NaN;
    row.medianExitDurSec = NaN;
    row.medianExitPeakMmps = NaN;
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
        switch intervalMode
            case 'baselineStim'
                intervalStartSec = double(base.startSec(1));
                intervalEndSec = double(base.endSec(1));
            case 'preBaselineGap'
                if baselineRefStartSec < p.Results.minLongBaselineSec
                    row.status = "excluded";
                    row.message = sprintf('Candidate pre-baseline interval %.1f s < %.1f s threshold.', baselineRefStartSec, p.Results.minLongBaselineSec);
                    subjectRows(end+1,1) = row; %#ok<AGROW>
                    continue;
                end
                intervalStartSec = 0;
                intervalEndSec = baselineRefStartSec;
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

        smoothFrames = max(1, round(p.Results.smoothSec * fr));
        if smoothFrames > 1
            signalSpeed = movmedian(signalSpeed, smoothFrames, 'omitnan');
        end
        valid = isfinite(signalSpeed);
        if nnz(valid) < 100
            row.status = "excluded";
            row.message = sprintf('Too few valid frames in %s signal.', signalMarkerMode);
            subjectRows(end+1,1) = row; %#ok<AGROW>
            continue;
        end

        [immobileMask, ~, immobileBouts] = getImmobileFramesFromSpeed(signalSpeed, fr, ...
            'thresholdMmPerSec', p.Results.immobilityThresholdMmps, ...
            'minDurationSec', p.Results.immobileMinDurSec);

        mobileMask = ~immobileMask & isfinite(signalSpeed);
        mobileMask = localCloseBinaryRuns(mobileMask, round(p.Results.mobileMergeGapSec * fr));
        [starts, ends] = localFindRuns(mobileMask);
        minMobileFrames = max(1, round(p.Results.mobileMinDurSec * fr));
        maxMobileFrames = max(1, round(p.Results.briefExitMaxDurSec * fr));

        briefExits = struct( ...
            'startIdx', {}, 'endIdx', {}, 'startSec', {}, 'endSec', {}, 'durationSec', {}, ...
            'peakIdx', {}, 'peakSec', {}, 'peakTimeNorm', {}, 'peakSpeedMmps', {}, 'meanSpeedMmps', {}, ...
            'preImmobileDurSec', {}, 'postImmobileDurSec', {});

        analysisDurSec = analysisEndSec - analysisStartSec;
        for k = 1:numel(starts)
            nFrames = ends(k) - starts(k) + 1;
            if nFrames < minMobileFrames || nFrames > maxMobileFrames
                continue;
            end

            prevBoutIdx = find([immobileBouts.endIdx] < starts(k), 1, 'last');
            nextBoutIdx = find([immobileBouts.startIdx] > ends(k), 1, 'first');
            if isempty(prevBoutIdx) || isempty(nextBoutIdx)
                continue;
            end

            idx = starts(k):ends(k);
            [peakSpeed, peakLocalIdx] = max(signalSpeed(idx), [], 'omitnan');
            if ~isfinite(peakSpeed) || peakSpeed < p.Results.minPeakSpeedMmps
                continue;
            end
            peakIdx = idx(peakLocalIdx);

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
            ev.meanSpeedMmps = mean(signalSpeed(idx), 'omitnan');
            ev.preImmobileDurSec = immobileBouts(prevBoutIdx).durationSec;
            ev.postImmobileDurSec = immobileBouts(nextBoutIdx).durationSec;
            briefExits(end+1) = ev; %#ok<AGROW>
        end

        row.analysisStartSec = analysisStartSec;
        row.analysisEndSec = analysisEndSec;
        row.analysisDurSec = analysisDurSec;
        row.nImmobileBouts = numel(immobileBouts);
        row.immobileFrac = mean(immobileMask, 'omitnan');
        row.nBriefExits = numel(briefExits);
        row.briefExitRatePerMin = numel(briefExits) ./ (analysisDurSec / 60);
        halfSec = analysisStartSec + analysisDurSec / 2;
        row.briefExitRateEarlyPerMin = sum([briefExits.peakSec] < halfSec) ./ ((analysisDurSec / 2) / 60);
        row.briefExitRateLatePerMin = sum([briefExits.peakSec] >= halfSec) ./ ((analysisDurSec / 2) / 60);
        if ~isempty(briefExits)
            row.briefExitLateFraction = mean([briefExits.peakSec] >= halfSec);
            row.medianExitDurSec = median([briefExits.durationSec]);
            row.medianExitPeakMmps = median([briefExits.peakSpeedMmps]);
        end

        for k = 1:numel(briefExits)
            exitRows(end+1,1) = localExitRow(subj, k, briefExits(k)); %#ok<AGROW>
        end

        traceCache.(char(subj)) = struct( ...
            'tSec', tSec, ...
            'signalSpeed', signalSpeed, ...
            'immobileMask', immobileMask, ...
            'immobileThresholdMmps', p.Results.immobilityThresholdMmps, ...
            'analysisStartSec', analysisStartSec, ...
            'analysisEndSec', analysisEndSec, ...
            'analysisDurSec', analysisDurSec, ...
            'signalLabel', signalMarkerMode, ...
            'briefExits', briefExits);
    catch ME
        row.status = "error";
        row.message = sprintf('%s: %s', ME.identifier, ME.message);
    end

    subjectRows(end+1,1) = row; %#ok<AGROW>
end

subjectSummary = struct2table(subjectRows);
if isempty(exitRows)
    exitTable = localEmptyExitTable();
else
    exitTable = struct2table(exitRows);
end

summaryCsv = fullfile(outDir, 'subject_summary.csv');
exitsCsv = fullfile(outDir, 'exit_table.csv');
writetable(subjectSummary, summaryCsv);
writetable(exitTable, exitsCsv);

included = subjectSummary(subjectSummary.status == "ok", :);
repSubject = localPickRepresentativeSubject(included);
if logical(p.Results.exportFigures) && strlength(repSubject) > 0
    repFig = localPlotRepresentativeTrace(repSubject, traceCache.(char(repSubject)), included, intervalMode);
    exportgraphics(repFig, fullfile(outDir, 'representative_trace.png'), 'Resolution', 220);
    exportgraphics(repFig, fullfile(outDir, 'representative_trace.pdf'), 'ContentType', 'vector');
    close(repFig);
end

if logical(p.Results.exportFigures) && ~isempty(included)
    timingFig = localPlotTimingSummary(included, exitTable, intervalMode);
    exportgraphics(timingFig, fullfile(outDir, 'timing_summary.png'), 'Resolution', 220);
    exportgraphics(timingFig, fullfile(outDir, 'timing_summary.pdf'), 'ContentType', 'vector');
    close(timingFig);

    morphFig = localPlotExitSummary(included, exitTable);
    exportgraphics(morphFig, fullfile(outDir, 'exit_summary.png'), 'Resolution', 220);
    exportgraphics(morphFig, fullfile(outDir, 'exit_summary.pdf'), 'ContentType', 'vector');
    close(morphFig);
end

reportPath = fullfile(outDir, 'report.md');
localWriteReport(reportPath, included, subjectSummary, p.Results, intervalMode);

fprintf('Saved outputs to %s\n', outDir);
disp(subjectSummary(:, {'subjectID','analysisDurSec','immobileFrac','nBriefExits','briefExitRateEarlyPerMin','briefExitRateLatePerMin','status'}));

out = struct();
out.outDir = outDir;
out.subjectSummary = subjectSummary;
out.exitTable = exitTable;
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

function row = localExitRow(subj, exitIndex, ev)
    row = struct();
    row.subjectID = subj;
    row.exitIndex = exitIndex;
    row.startSec = ev.startSec;
    row.endSec = ev.endSec;
    row.durationSec = ev.durationSec;
    row.peakSec = ev.peakSec;
    row.peakTimeNorm = ev.peakTimeNorm;
    row.peakSpeedMmps = ev.peakSpeedMmps;
    row.meanSpeedMmps = ev.meanSpeedMmps;
    row.preImmobileDurSec = ev.preImmobileDurSec;
    row.postImmobileDurSec = ev.postImmobileDurSec;
end

function exitTable = localEmptyExitTable()
    exitTable = table( ...
        string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'subjectID','exitIndex','startSec','endSec','durationSec','peakSec', ...
        'peakTimeNorm','peakSpeedMmps','meanSpeedMmps','preImmobileDurSec','postImmobileDurSec'});
end

function repSubject = localPickRepresentativeSubject(included)
    repSubject = "";
    if isempty(included)
        return;
    end
    good = included(included.nBriefExits >= 2, :);
    if isempty(good)
        good = included(included.nBriefExits == max(included.nBriefExits), :);
    end
    if isempty(good)
        return;
    end
    [~, idx] = max(good.nBriefExits);
    repSubject = string(good.subjectID(idx));
end

function fig = localPlotRepresentativeTrace(subj, C, included, intervalMode)
    fig = figure('Color', 'w', 'Position', [100 100 1450 700]);
    tiledlayout(2,1, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile;
    hold(ax1, 'on');
    plot(ax1, C.tSec ./ 60, C.signalSpeed, 'Color', [0.1 0.35 0.85], 'LineWidth', 1.3);
    yline(ax1, C.immobileThresholdMmps, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
    localShadeMask(ax1, C.tSec, C.immobileMask, [0.86 0.90 0.96], 0.55);
    localShadeExits(ax1, C.briefExits, [0.95 0.75 0.2], 0.22);
    localMarkExitPeaks(ax1, C.briefExits, [0.92 0.35 0.10]);
    xline(ax1, (C.analysisStartSec + C.analysisDurSec / 2) / 60, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
    xlabel(ax1, 'Time from mocap start (min)');
    ylabel(ax1, sprintf('%s speed (mm/s)', C.signalLabel));
    title(ax1, sprintf('%s | %s | brief LAR exits=%d | cohort n=%d', subj, intervalMode, numel(C.briefExits), height(included)), ...
        'FontWeight', 'bold');
    grid(ax1, 'on');
    box(ax1, 'off');

    ax2 = nexttile;
    hold(ax2, 'on');
    exitMask = false(size(C.tSec));
    for i = 1:numel(C.briefExits)
        exitMask(C.briefExits(i).startIdx:C.briefExits(i).endIdx) = true;
    end
    stairs(ax2, C.tSec ./ 60, double(C.immobileMask), '-', 'Color', [0.25 0.45 0.25], 'LineWidth', 1.2);
    stairs(ax2, C.tSec ./ 60, double(exitMask) * 0.85, '-', 'Color', [0.90 0.45 0.05], 'LineWidth', 1.2);
    xline(ax2, (C.analysisStartSec + C.analysisDurSec / 2) / 60, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
    set(ax2, 'YTick', [0 0.85 1], 'YTickLabel', {'mobile','brief exit','immobile'});
    ylim(ax2, [-0.05 1.1]);
    xlabel(ax2, 'Time from mocap start (min)');
    ylabel(ax2, 'State');
    title(ax2, 'LAR occupancy and retained exit bouts');
    grid(ax2, 'on');
    box(ax2, 'off');
end

function localShadeMask(ax, tSec, mask, colorVal, alphaVal)
    [starts, ends] = localFindRuns(mask);
    yl = ylim(ax);
    for i = 1:numel(starts)
        x0 = tSec(starts(i)) / 60;
        x1 = tSec(ends(i)) / 60;
        patch(ax, [x0 x1 x1 x0], [yl(1) yl(1) yl(2) yl(2)], colorVal, ...
            'FaceAlpha', alphaVal, 'EdgeColor', 'none');
    end
    uistack(findobj(ax, 'Type', 'Line'), 'top');
end

function localShadeExits(ax, exits, colorVal, alphaVal)
    yl = ylim(ax);
    for i = 1:numel(exits)
        x0 = exits(i).startSec / 60;
        x1 = exits(i).endSec / 60;
        patch(ax, [x0 x1 x1 x0], [yl(1) yl(1) yl(2) yl(2)], colorVal, ...
            'FaceAlpha', alphaVal, 'EdgeColor', 'none');
    end
    uistack(findobj(ax, 'Type', 'Line'), 'top');
end

function localMarkExitPeaks(ax, exits, colorVal)
    if isempty(exits)
        return;
    end
    x = [exits.peakSec] ./ 60;
    y = [exits.peakSpeedMmps];
    scatter(ax, x, y, 28, colorVal, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
end

function fig = localPlotTimingSummary(included, exitTable, intervalMode)
    fig = figure('Color', 'w', 'Position', [120 120 1500 550]);
    tiledlayout(1,3, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile;
    hold(ax1, 'on');
    for i = 1:height(included)
        plot(ax1, [1 2], [included.briefExitRateEarlyPerMin(i) included.briefExitRateLatePerMin(i)], ...
            '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0);
    end
    scatter(ax1, ones(height(included),1), included.briefExitRateEarlyPerMin, 40, [0.2 0.5 0.9], 'filled');
    scatter(ax1, 2 * ones(height(included),1), included.briefExitRateLatePerMin, 40, [0.9 0.4 0.2], 'filled');
    xlim(ax1, [0.6 2.4]);
    set(ax1, 'XTick', [1 2], 'XTickLabel', {'Early half','Late half'});
    ylabel(ax1, 'Brief-exit rate (per min)');
    title(ax1, 'Early vs late exit rate');
    grid(ax1, 'on');
    box(ax1, 'off');

    ax2 = nexttile;
    if ~isempty(exitTable)
        histogram(ax2, exitTable.peakTimeNorm, 'BinEdges', 0:0.1:1, 'FaceColor', [0.25 0.55 0.85], 'EdgeColor', 'w');
    end
    xline(ax2, 0.5, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
    xlabel(ax2, 'Normalized exit-peak time within analyzed baseline');
    ylabel(ax2, 'Brief exits');
    title(ax2, 'Exit peak-time histogram');
    grid(ax2, 'on');
    box(ax2, 'off');

    ax3 = nexttile;
    hold(ax3, 'on');
    sortMat = [included.briefExitLateFraction included.nBriefExits];
    sortMat(isnan(sortMat)) = -Inf;
    [~, order] = sortrows(sortMat, [-1 -2]);
    ordered = included(order, :);
    for i = 1:height(ordered)
        subj = string(ordered.subjectID(i));
        subExits = exitTable(exitTable.subjectID == subj, :);
        if isempty(subExits)
            continue;
        end
        scatter(ax3, subExits.peakTimeNorm, i * ones(height(subExits),1), 34, subExits.peakSpeedMmps, 'filled');
    end
    xline(ax3, 0.5, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.0);
    xlim(ax3, [0 1]);
    ylim(ax3, [0 height(ordered)+1]);
    xlabel(ax3, 'Normalized exit-peak time');
    ylabel(ax3, 'Subjects');
    title(ax3, 'Subject exit raster');
    set(ax3, 'YTick', 1:height(ordered), 'YTickLabel', ordered.subjectID);
    grid(ax3, 'on');
    box(ax3, 'off');
    cb = colorbar(ax3);
    cb.Label.String = 'Peak speed (mm/s)';

    sgtitle(fig, sprintf('%s LAR-exit timing summary | brief exits from chest low-animation regime', intervalMode), ...
        'FontWeight', 'bold', 'FontSize', 16);
end

function fig = localPlotExitSummary(included, exitTable)
    fig = figure('Color', 'w', 'Position', [120 120 1500 550]);
    tiledlayout(1,3, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile;
    if ~isempty(exitTable)
        scatter(ax1, exitTable.durationSec, exitTable.peakSpeedMmps, 42, exitTable.peakTimeNorm, 'filled');
    end
    xlabel(ax1, 'Exit duration (s)');
    ylabel(ax1, 'Exit peak speed (mm/s)');
    title(ax1, 'Exit duration vs peak speed');
    grid(ax1, 'on');
    box(ax1, 'off');
    cb1 = colorbar(ax1);
    cb1.Label.String = 'Peak time norm';

    ax2 = nexttile;
    if ~isempty(exitTable)
        scatter(ax2, exitTable.preImmobileDurSec, exitTable.postImmobileDurSec, 42, exitTable.durationSec, 'filled');
    end
    xlabel(ax2, 'Pre-exit immobile duration (s)');
    ylabel(ax2, 'Post-exit immobile duration (s)');
    title(ax2, 'Immobile bout context');
    grid(ax2, 'on');
    box(ax2, 'off');
    cb2 = colorbar(ax2);
    cb2.Label.String = 'Exit duration (s)';

    ax3 = nexttile;
    scatter(ax3, included.immobileFrac, included.briefExitLateFraction, 54, included.nBriefExits, 'filled');
    xlabel(ax3, 'Immobile fraction');
    ylabel(ax3, 'Late-half exit fraction');
    title(ax3, 'Subject immobility vs exit lateness');
    ylim(ax3, [0 1]);
    grid(ax3, 'on');
    box(ax3, 'off');
    cb3 = colorbar(ax3);
    cb3.Label.String = 'Brief-exit count';

    sgtitle(fig, 'Brief exit summary from low-animation regime', 'FontWeight', 'bold', 'FontSize', 16);
end

function localWriteReport(reportPath, included, subjectSummary, params, intervalMode)
    fid = fopen(reportPath, 'w');
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '# Baseline LAR Exit Pass\n\n');
    fprintf(fid, '## Working definition\n\n');
    if strcmp(intervalMode, 'baselineStim')
        fprintf(fid, '- Interval analyzed: explicit 180 s BASELINE stimulus presentation.\n');
    else
        fprintf(fid, '- Interval analyzed: provisional mocap-start to BASELINE-onset gap.\n');
    end
    fprintf(fid, '- Analysis trims first %.0f s and last %.0f s.\n', params.trimStartSec, params.trimEndSec);
    fprintf(fid, '- Signal: %s marker-group speed.\n', char(string(params.signalMarkerMode)));
    fprintf(fid, '- Speed window: %.2f s.\n', params.speedWindowSec);
    fprintf(fid, '- Optional smoothing: %.2f s.\n', params.smoothSec);
    fprintf(fid, '- LAR threshold: speed < %.1f mm/s.\n', params.immobilityThresholdMmps);
    fprintf(fid, '- Minimum immobile bout duration: %.2f s.\n', params.immobileMinDurSec);
    fprintf(fid, '- Brief-exit duration range: %.2f s to %.2f s.\n', params.mobileMinDurSec, params.briefExitMaxDurSec);
    fprintf(fid, '- Minimum exit peak speed: %.1f mm/s.\n\n', params.minPeakSpeedMmps);

    fprintf(fid, '## Recording availability\n\n');
    fprintf(fid, '- Total subject MATs in timeline summary: %d\n', height(subjectSummary));
    fprintf(fid, '- Included: %d\n', height(included));
    fprintf(fid, '- Excluded as too short / failed: %d\n\n', height(subjectSummary) - height(included));

    if ~isempty(included)
        fprintf(fid, '## Summary\n\n');
        fprintf(fid, '- Median usable analysis duration: %.1f min\n', median(included.analysisDurSec ./ 60));
        fprintf(fid, '- Median immobile fraction: %.2f\n', median(included.immobileFrac, 'omitnan'));
        fprintf(fid, '- Median brief-exit count: %.2f\n', median(included.nBriefExits, 'omitnan'));
        fprintf(fid, '- Median brief-exit rate: %.2f / min\n', median(included.briefExitRatePerMin, 'omitnan'));
        fprintf(fid, '- Median early-half brief-exit rate: %.2f / min\n', median(included.briefExitRateEarlyPerMin, 'omitnan'));
        fprintf(fid, '- Median late-half brief-exit rate: %.2f / min\n', median(included.briefExitRateLatePerMin, 'omitnan'));
        fprintf(fid, '- Median late-half exit fraction: %.2f\n\n', median(included.briefExitLateFraction, 'omitnan'));
    end

    fprintf(fid, '## Interpretation boundary\n\n');
    fprintf(fid, '- This pass asks whether BASELINE contains brief departures from the low-animation regime, not whether it contains intrinsic phasic pulses of a separate event class.\n');
    fprintf(fid, '- It remains exploratory and should be used for timing structure and figure scouting before stronger inferential claims.\n');
end
