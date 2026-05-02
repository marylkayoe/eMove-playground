function out = explore_baseline_instability(varargin)
% explore_baseline_instability
%
% Ask whether BASELINE becomes less locally stable over time.
%
% Current working metrics on a rolling window:
%   - speedStdMmps: local SD of chest speed
%   - speedMadMmps: local MAD of chest speed
%   - speedDiffMadMmps: local MAD of frame-to-frame speed change
%   - posLocalMadMm: local MAD of centroid displacement around window median
%   - posDriftMm: drift of window-median centroid from early-trial reference

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
addParameter(p, 'windowSec', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'stepSec', 2, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'earlyRefSec', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
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
    outDir = fullfile(repoRoot, 'outputs', 'figures', ['baseline_instability_' intervalMode '_' analysisStamp suffix]);
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
    'analysisDurSec', {}, ...
    'nWindows', {}, ...
    'speedStdEarly', {}, 'speedStdLate', {}, 'speedStdLateMinusEarly', {}, ...
    'speedMadEarly', {}, 'speedMadLate', {}, 'speedMadLateMinusEarly', {}, ...
    'speedDiffMadEarly', {}, 'speedDiffMadLate', {}, 'speedDiffMadLateMinusEarly', {}, ...
    'posLocalMadEarly', {}, 'posLocalMadLate', {}, 'posLocalMadLateMinusEarly', {}, ...
    'posDriftEarly', {}, 'posDriftLate', {}, 'posDriftLateMinusEarly', {}, ...
    'status', {}, ...
    'message', {});

windowRows = struct( ...
    'subjectID', {}, ...
    'windowIndex', {}, ...
    'centerSec', {}, ...
    'timeNorm', {}, ...
    'speedStdMmps', {}, ...
    'speedMadMmps', {}, ...
    'speedDiffMadMmps', {}, ...
    'posLocalMadMm', {}, ...
    'posDriftMm', {});

traceCache = struct();

for i = 1:height(summaryTbl)
    subj = upper(string(summaryTbl.subjectID(i)));
    matPath = string(summaryTbl.matPath(i));

    row = struct();
    row.subjectID = subj;
    row.analysisDurSec = NaN;
    row.nWindows = NaN;
    row.speedStdEarly = NaN; row.speedStdLate = NaN; row.speedStdLateMinusEarly = NaN;
    row.speedMadEarly = NaN; row.speedMadLate = NaN; row.speedMadLateMinusEarly = NaN;
    row.speedDiffMadEarly = NaN; row.speedDiffMadLate = NaN; row.speedDiffMadLateMinusEarly = NaN;
    row.posLocalMadEarly = NaN; row.posLocalMadLate = NaN; row.posLocalMadLateMinusEarly = NaN;
    row.posDriftEarly = NaN; row.posDriftLate = NaN; row.posDriftLateMinusEarly = NaN;
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
        analysisDurSec = analysisEndSec - analysisStartSec;
        if analysisDurSec <= max(20, p.Results.windowSec + 5)
            row.status = "excluded";
            row.message = sprintf('Usable interval %.1f s too short after trimming.', analysisDurSec);
            subjectRows(end+1,1) = row; %#ok<AGROW>
            continue;
        end

        frameRange = max(1, floor(analysisStartSec * fr) + 1) : min(size(td.trajectoryData, 1), floor(analysisEndSec * fr));
        tSec = (frameRange(:) - 1) ./ fr;

        signalMarkers = localResolveSignalMarkers(markerGroups, signalMarkerMode, upperBodyMarkers);
        [centroidXYZ, signalSpeed] = localComputeCentroidAndSpeed(td, signalMarkers, frameRange, fr, p.Results.speedWindowSec);
        valid = all(isfinite(centroidXYZ), 2) & isfinite(signalSpeed);
        if nnz(valid) < max(100, round(p.Results.windowSec * fr))
            row.status = "excluded";
            row.message = sprintf('Too few valid frames in %s signal.', signalMarkerMode);
            subjectRows(end+1,1) = row; %#ok<AGROW>
            continue;
        end

        earlyRefEndSec = min(analysisStartSec + p.Results.earlyRefSec, analysisEndSec);
        earlyRefMask = tSec >= analysisStartSec & tSec < earlyRefEndSec & all(isfinite(centroidXYZ), 2);
        if nnz(earlyRefMask) < 20
            error('Early reference segment too small.');
        end
        earlyRefCentroid = median(centroidXYZ(earlyRefMask, :), 1, 'omitnan');

        winFrames = max(10, round(p.Results.windowSec * fr));
        stepFrames = max(1, round(p.Results.stepSec * fr));
        startIdx = 1:stepFrames:(numel(tSec) - winFrames + 1);
        nW = numel(startIdx);
        metricMat = NaN(nW, 5);
        centerSec = NaN(nW, 1);
        timeNorm = NaN(nW, 1);

        for w = 1:nW
            idx = startIdx(w):(startIdx(w) + winFrames - 1);
            sp = signalSpeed(idx);
            xyz = centroidXYZ(idx, :);
            good = isfinite(sp) & all(isfinite(xyz), 2);
            if nnz(good) < round(0.7 * winFrames)
                continue;
            end
            sp = sp(good);
            xyz = xyz(good, :);

            metricMat(w, 1) = std(sp, 0, 'omitnan');
            metricMat(w, 2) = mad(sp, 1);
            if numel(sp) >= 3
                metricMat(w, 3) = mad(diff(sp), 1);
            end
            winMedian = median(xyz, 1, 'omitnan');
            radial = sqrt(sum((xyz - winMedian).^2, 2));
            metricMat(w, 4) = mad(radial, 1);
            metricMat(w, 5) = norm(winMedian - earlyRefCentroid);

            cSec = mean(tSec(idx([1 end])));
            centerSec(w) = cSec;
            timeNorm(w) = (cSec - analysisStartSec) / analysisDurSec;

            wr = struct();
            wr.subjectID = subj;
            wr.windowIndex = w;
            wr.centerSec = cSec;
            wr.timeNorm = timeNorm(w);
            wr.speedStdMmps = metricMat(w, 1);
            wr.speedMadMmps = metricMat(w, 2);
            wr.speedDiffMadMmps = metricMat(w, 3);
            wr.posLocalMadMm = metricMat(w, 4);
            wr.posDriftMm = metricMat(w, 5);
            windowRows(end+1,1) = wr; %#ok<AGROW>
        end

        earlyMask = timeNorm < 0.5;
        lateMask = timeNorm >= 0.5;
        names = {'speedStd','speedMad','speedDiffMad','posLocalMad','posDrift'};
        for m = 1:numel(names)
            v = metricMat(:, m);
            e = median(v(earlyMask), 'omitnan');
            l = median(v(lateMask), 'omitnan');
            row.([names{m} 'Early']) = e;
            row.([names{m} 'Late']) = l;
            row.([names{m} 'LateMinusEarly']) = l - e;
        end
        row.analysisDurSec = analysisDurSec;
        row.nWindows = nW;

        traceCache.(char(subj)) = struct( ...
            'tSec', tSec, ...
            'signalSpeed', signalSpeed, ...
            'centroidZ', centroidXYZ(:, 3), ...
            'centerSec', centerSec, ...
            'timeNorm', timeNorm, ...
            'metricMat', metricMat, ...
            'analysisStartSec', analysisStartSec, ...
            'analysisEndSec', analysisEndSec, ...
            'analysisDurSec', analysisDurSec, ...
            'signalLabel', signalMarkerMode);
    catch ME
        row.status = "error";
        row.message = sprintf('%s: %s', ME.identifier, ME.message);
    end

    subjectRows(end+1,1) = row; %#ok<AGROW>
end

subjectSummary = struct2table(subjectRows);
if isempty(windowRows)
    windowTable = localEmptyWindowTable();
else
    windowTable = struct2table(windowRows);
end

writetable(subjectSummary, fullfile(outDir, 'subject_summary.csv'));
writetable(windowTable, fullfile(outDir, 'window_table.csv'));

included = subjectSummary(subjectSummary.status == "ok", :);
repSubject = localPickRepresentativeSubject(included);
if logical(p.Results.exportFigures) && strlength(repSubject) > 0
    repFig = localPlotRepresentative(repSubject, traceCache.(char(repSubject)));
    exportgraphics(repFig, fullfile(outDir, 'representative_instability.png'), 'Resolution', 220);
    exportgraphics(repFig, fullfile(outDir, 'representative_instability.pdf'), 'ContentType', 'vector');
    close(repFig);
end

if logical(p.Results.exportFigures) && ~isempty(included)
    cohortFig = localPlotCohortCurves(windowTable);
    exportgraphics(cohortFig, fullfile(outDir, 'cohort_instability_curves.png'), 'Resolution', 220);
    exportgraphics(cohortFig, fullfile(outDir, 'cohort_instability_curves.pdf'), 'ContentType', 'vector');
    close(cohortFig);

    pairedFig = localPlotEarlyLate(included);
    exportgraphics(pairedFig, fullfile(outDir, 'early_late_summary.png'), 'Resolution', 220);
    exportgraphics(pairedFig, fullfile(outDir, 'early_late_summary.pdf'), 'ContentType', 'vector');
    close(pairedFig);
end

reportPath = fullfile(outDir, 'report.md');
localWriteReport(reportPath, included, p.Results);

fprintf('Saved outputs to %s\n', outDir);
disp(included(:, {'subjectID','speedStdLateMinusEarly','speedDiffMadLateMinusEarly','posLocalMadLateMinusEarly','posDriftLateMinusEarly'}));

out = struct();
out.outDir = outDir;
out.subjectSummary = subjectSummary;
out.windowTable = windowTable;
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

function [centroidXYZ, avgSpeed] = localComputeCentroidAndSpeed(td, markerNames, frameRange, fr, speedWindowSec)
    markerNames = cellstr(string(markerNames(:)));
    nFrames = numel(frameRange);
    nMarkers = numel(markerNames);
    xyzStack = NaN(nFrames, 3, nMarkers);
    markerSpeeds = NaN(nFrames, nMarkers);
    for i = 1:nMarkers
        idx = find(strcmp(td.markerNames, markerNames{i}), 1);
        if isempty(idx)
            continue;
        end
        xyz = squeeze(td.trajectoryData(frameRange, :, idx));
        xyzStack(:, :, i) = xyz;
        markerSpeeds(:, i) = getTrajectorySpeed(xyz, fr, speedWindowSec);
    end
    centroidXYZ = mean(xyzStack, 3, 'omitnan');
    avgSpeed = mean(markerSpeeds, 2, 'omitnan');
end

function tbl = localEmptyWindowTable()
    tbl = table( ...
        string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'subjectID','windowIndex','centerSec','timeNorm','speedStdMmps', ...
        'speedMadMmps','speedDiffMadMmps','posLocalMadMm','posDriftMm'});
end

function repSubject = localPickRepresentativeSubject(included)
    repSubject = "";
    if isempty(included)
        return;
    end
    score = included.speedDiffMadLateMinusEarly + included.posDriftLateMinusEarly;
    score(~isfinite(score)) = -Inf;
    [~, idx] = max(score);
    repSubject = string(included.subjectID(idx));
end

function fig = localPlotRepresentative(subj, C)
    metricNames = {'speedStdMmps','speedDiffMadMmps','posLocalMadMm','posDriftMm'};
    metricLabels = {'Speed SD','Speed-diff MAD','Local position MAD','Position drift'};
    cols = [0.15 0.45 0.85; 0.85 0.35 0.10; 0.20 0.65 0.35; 0.55 0.25 0.75];

    fig = figure('Color', 'w', 'Position', [100 100 1450 760]);
    tiledlayout(3,1, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile;
    hold(ax1, 'on');
    plot(ax1, C.tSec ./ 60, C.centroidZ, 'Color', [0.15 0.55 0.85], 'LineWidth', 1.2);
    xline(ax1, (C.analysisStartSec + C.analysisDurSec / 2) / 60, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.0);
    ylabel(ax1, 'Centroid Z (mm)');
    title(ax1, sprintf('%s | centroid position', subj), 'FontWeight', 'bold');
    grid(ax1, 'on'); box(ax1, 'off');

    ax2 = nexttile;
    hold(ax2, 'on');
    plot(ax2, C.tSec ./ 60, C.signalSpeed, 'Color', [0.05 0.35 0.80], 'LineWidth', 1.2);
    xline(ax2, (C.analysisStartSec + C.analysisDurSec / 2) / 60, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.0);
    ylabel(ax2, 'Speed (mm/s)');
    title(ax2, sprintf('%s | chest speed', C.signalLabel), 'FontWeight', 'bold');
    grid(ax2, 'on'); box(ax2, 'off');

    ax3 = nexttile;
    hold(ax3, 'on');
    for m = 1:numel(metricNames)
        v = C.metricMat(:, m);
        z = (v - median(v, 'omitnan')) ./ max(eps, mad(v, 1));
        plot(ax3, C.centerSec ./ 60, z, '-', 'Color', cols(m, :), 'LineWidth', 1.8, 'DisplayName', metricLabels{m});
    end
    xline(ax3, (C.analysisStartSec + C.analysisDurSec / 2) / 60, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.0);
    xlabel(ax3, 'Time from mocap start (min)');
    ylabel(ax3, 'Within-subject robust z');
    title(ax3, 'Rolling instability metrics');
    legend(ax3, 'Location', 'eastoutside');
    grid(ax3, 'on'); box(ax3, 'off');
end

function fig = localPlotCohortCurves(windowTable)
    metricVars = {'speedStdMmps','speedMadMmps','speedDiffMadMmps','posLocalMadMm','posDriftMm'};
    titles = {'Speed SD','Speed MAD','Speed-diff MAD','Local position MAD','Position drift'};
    fig = figure('Color', 'w', 'Position', [120 120 1500 900]);
    tiledlayout(3,2, 'TileSpacing', 'compact', 'Padding', 'compact');

    binEdges = 0:0.05:1;
    binCenters = 0.5 * (binEdges(1:end-1) + binEdges(2:end));
    subs = unique(string(windowTable.subjectID), 'stable');

    for m = 1:numel(metricVars)
        ax = nexttile;
        hold(ax, 'on');
        cohortMat = NaN(numel(subs), numel(binCenters));
        for s = 1:numel(subs)
            Tsub = windowTable(string(windowTable.subjectID) == subs(s), :);
            for b = 1:numel(binCenters)
                if b < numel(binCenters)
                    mask = Tsub.timeNorm >= binEdges(b) & Tsub.timeNorm < binEdges(b+1);
                else
                    mask = Tsub.timeNorm >= binEdges(b) & Tsub.timeNorm <= binEdges(b+1);
                end
                cohortMat(s, b) = median(Tsub.(metricVars{m})(mask), 'omitnan');
            end
            plot(ax, binCenters, cohortMat(s, :), '-', 'Color', [0.82 0.82 0.82], 'LineWidth', 0.8);
        end
        medCurve = median(cohortMat, 1, 'omitnan');
        lo = prctile(cohortMat, 25, 1);
        hi = prctile(cohortMat, 75, 1);
        fill(ax, [binCenters fliplr(binCenters)], [lo fliplr(hi)], [0.78 0.88 1.0], ...
            'FaceAlpha', 0.7, 'EdgeColor', 'none');
        plot(ax, binCenters, medCurve, '-', 'Color', [0.05 0.30 0.75], 'LineWidth', 2.2);
        xlabel(ax, 'Normalized time within baseline');
        ylabel(ax, titles{m});
        title(ax, titles{m});
        grid(ax, 'on'); box(ax, 'off');
    end
    sgtitle(fig, 'Rolling baseline instability across subjects', 'FontWeight', 'bold', 'FontSize', 16);
end

function fig = localPlotEarlyLate(included)
    pairs = { ...
        'speedStdEarly','speedStdLate','Speed SD'; ...
        'speedDiffMadEarly','speedDiffMadLate','Speed-diff MAD'; ...
        'posLocalMadEarly','posLocalMadLate','Local position MAD'; ...
        'posDriftEarly','posDriftLate','Position drift'};
    fig = figure('Color', 'w', 'Position', [120 120 1400 750]);
    tiledlayout(2,2, 'TileSpacing', 'compact', 'Padding', 'compact');
    for i = 1:size(pairs, 1)
        ax = nexttile;
        e = included.(pairs{i,1});
        l = included.(pairs{i,2});
        hold(ax, 'on');
        for k = 1:height(included)
            plot(ax, [1 2], [e(k) l(k)], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0);
        end
        scatter(ax, ones(height(included),1), e, 36, [0.2 0.5 0.9], 'filled');
        scatter(ax, 2 * ones(height(included),1), l, 36, [0.9 0.4 0.2], 'filled');
        xlim(ax, [0.6 2.4]);
        set(ax, 'XTick', [1 2], 'XTickLabel', {'Early','Late'});
        ylabel(ax, pairs{i,3});
        title(ax, sprintf('%s | median late-early = %.2f', pairs{i,3}, median(l - e, 'omitnan')));
        grid(ax, 'on'); box(ax, 'off');
    end
    sgtitle(fig, 'Early vs late rolling instability', 'FontWeight', 'bold', 'FontSize', 16);
end

function localWriteReport(reportPath, included, params)
    fid = fopen(reportPath, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Baseline Instability Pass\n\n');
    fprintf(fid, '## Working definition\n\n');
    fprintf(fid, '- Signal: %s chest marker group\n', char(string(params.signalMarkerMode)));
    fprintf(fid, '- Analysis trims first %.0f s and last %.0f s.\n', params.trimStartSec, params.trimEndSec);
    fprintf(fid, '- Speed window: %.2f s.\n', params.speedWindowSec);
    fprintf(fid, '- Rolling window: %.1f s with %.1f s step.\n', params.windowSec, params.stepSec);
    fprintf(fid, '- Early reference duration for drift: %.1f s.\n\n', params.earlyRefSec);

    if ~isempty(included)
        fprintf(fid, '## Median late-minus-early changes\n\n');
        fprintf(fid, '- Speed SD: %.3f\n', median(included.speedStdLateMinusEarly, 'omitnan'));
        fprintf(fid, '- Speed MAD: %.3f\n', median(included.speedMadLateMinusEarly, 'omitnan'));
        fprintf(fid, '- Speed-diff MAD: %.3f\n', median(included.speedDiffMadLateMinusEarly, 'omitnan'));
        fprintf(fid, '- Local position MAD: %.3f\n', median(included.posLocalMadLateMinusEarly, 'omitnan'));
        fprintf(fid, '- Position drift: %.3f\n\n', median(included.posDriftLateMinusEarly, 'omitnan'));
    end

    fprintf(fid, '## Interpretation boundary\n\n');
    fprintf(fid, '- Positive late-minus-early values indicate more local instability later in BASELINE.\n');
    fprintf(fid, '- These metrics target nonstationarity / loss of local stability, not discrete event counts.\n');
end
