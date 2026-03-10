% plot_session_timeline_batch.m
%
% Build and visualize per-subject session timelines from trialData MAT files.
% Outputs:
%   - one PNG timeline per subject
%   - one summary CSV with gap/session statistics
%
% This script is visualization/QC only and does not compute motion metrics.

clearvars;
clc;

%% User Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
matRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest';
outDir = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/session_timeline';
keepLatestMatPerSubject = true;
stimEncodingCsv = '/Users/yoe/Documents/REPOS/eMove-playground/resources/stim_video_encoding_SINGLES.csv'; % Set '' for per-video coloring

%% Path Setup
if ~isfolder(repoRoot)
    error('Repo root does not exist: %s', repoRoot);
end
if ~isfolder(matRoot)
    error('MAT root does not exist: %s', matRoot);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
addpath(genpath(fullfile(repoRoot, 'CODE')));

fprintf('\n=== Session Timeline Batch ===\n');
fprintf('MAT root: %s\n', matRoot);
fprintf('Output : %s\n', outDir);
if ~isempty(stimEncodingCsv)
    fprintf('Color mode: GROUP (from stim encoding table)\n');
else
    fprintf('Color mode: VIDEO (no stim encoding table provided)\n');
end

%% Discover MAT files
matFiles = dir(fullfile(matRoot, '*', '*.mat'));
if isempty(matFiles)
    error('No MAT files found under %s', matRoot);
end
fprintf('MAT files found (raw): %d\n', numel(matFiles));

if keepLatestMatPerSubject
    matFiles = localSelectLatestMatPerSubject(matFiles);
    fprintf('MAT files used (latest per subject): %d\n', numel(matFiles));
else
    fprintf('MAT files used: %d\n', numel(matFiles));
end

summaryRows = struct('subjectID', {}, 'status', {}, 'message', {}, ...
    'nSegments', {}, 'nStimSegments', {}, 'nBaselineSegments', {}, ...
    'nGapRows', {}, 'totalGapSec', {}, 'maxGapSec', {}, ...
    'totalOverlapSec', {}, 'nOverlapTransitions', {}, ...
    'sessionStartSec', {}, 'sessionEndSec', {}, 'sessionSpanSec', {}, ...
    'matPath', {}, 'figurePath', {});
timelineAll = table();

%% Build/plot per subject
for i = 1:numel(matFiles)
    matPath = fullfile(matFiles(i).folder, matFiles(i).name);
    fprintf('[%d/%d] %s\n', i, numel(matFiles), matPath);

    row = struct();
    row.subjectID = "UNKNOWN";
    row.status = "ok";
    row.message = "";
    row.nSegments = NaN;
    row.nStimSegments = NaN;
    row.nBaselineSegments = NaN;
    row.nGapRows = NaN;
    row.totalGapSec = NaN;
    row.maxGapSec = NaN;
    row.totalOverlapSec = NaN;
    row.nOverlapTransitions = NaN;
    row.sessionStartSec = NaN;
    row.sessionEndSec = NaN;
    row.sessionSpanSec = NaN;
    row.matPath = string(matPath);
    row.figurePath = "";

    try
        S = load(matPath);
        if ~isfield(S, 'trialData')
            error('MAT missing trialData: %s', matPath);
        end
        td = S.trialData;

        [timelineTable, summary] = buildSubjectSessionTimeline(td);
        row.subjectID = string(summary.subjectID);
        row.nSegments = summary.nSegments;
        row.nStimSegments = summary.nStimSegments;
        row.nBaselineSegments = summary.nBaselineSegments;
        row.nGapRows = summary.nGapRows;
        row.totalGapSec = summary.totalGapSec;
        row.maxGapSec = summary.maxGapSec;
        row.totalOverlapSec = summary.totalOverlapSec;
        row.nOverlapTransitions = summary.nOverlapTransitions;
        row.sessionStartSec = summary.sessionStartSec;
        row.sessionEndSec = summary.sessionEndSec;
        row.sessionSpanSec = summary.sessionSpanSec;

        row.figurePath = "";

        timelineCsvPath = fullfile(outDir, sprintf('%s_session_timeline.csv', summary.subjectID));
        writetable(timelineTable, timelineCsvPath);
        timelineAll = [timelineAll; timelineTable]; %#ok<AGROW>
    catch ME
        row.status = "error";
        row.message = string(sprintf('%s: %s', ME.identifier, ME.message));
        fprintf('  ERROR: %s\n', row.message);
    end

    summaryRows(end+1,1) = row; %#ok<AGROW>
end

summaryTable = struct2table(summaryRows);
summaryCsvPath = fullfile(outDir, 'session_timeline_summary.csv');
writetable(summaryTable, summaryCsvPath);

% Combined multi-subject visualization (one row per subject).
if ~isempty(timelineAll)
    timelineAll = sortrows(timelineAll, {'subjectID','startSec','endSec'});
    if isempty(stimEncodingCsv)
        stimEncodingArg = [];
    else
        stimEncodingArg = stimEncodingCsv;
    end
    figHandle = plotSubjectSessionTimeline(timelineAll, ...
        'figureTitle', 'Session Structure Across Subjects', ...
        'showVideoLabels', false, ...
        'showGapBlocks', false, ...
        'showTimeAxis', true, ...
        'showLegend', true, ...
        'stimVideoEncoding', stimEncodingArg);
    combinedFigPath = fullfile(outDir, 'session_timeline_all_subjects.png');
    exportgraphics(figHandle, combinedFigPath, 'Resolution', 180);
    combinedPdfPath = fullfile(outDir, 'session_timeline_all_subjects.pdf');
    exportgraphics(figHandle, combinedPdfPath, 'ContentType', 'vector');
    combinedSvgPath = fullfile(outDir, 'session_timeline_all_subjects.svg');
    try
        print(figHandle, combinedSvgPath, '-dsvg');
        svgSaved = true;
    catch
        svgSaved = false;
    end
    close(figHandle);
    fprintf('Saved combined figure: %s\n', combinedFigPath);
    fprintf('Saved combined vector: %s\n', combinedPdfPath);
    if svgSaved
        fprintf('Saved combined vector: %s\n', combinedSvgPath);
    else
        fprintf('SVG export skipped (not supported in this MATLAB graphics backend).\n');
    end
end

fprintf('\nSaved summary: %s\n', summaryCsvPath);
fprintf('Subjects OK: %d\n', nnz(summaryTable.status == "ok"));
fprintf('Subjects ERROR: %d\n', nnz(summaryTable.status == "error"));
fprintf('Done.\n');

%% Local helpers
function out = localSelectLatestMatPerSubject(matFiles)
    subj = strings(numel(matFiles),1);
    ts = NaT(numel(matFiles),1);

    for i = 1:numel(matFiles)
        [~, subjFolder] = fileparts(matFiles(i).folder);
        subj(i) = upper(string(subjFolder));
        ts(i) = localParseTakeTimestampFromMatName(matFiles(i).name);
    end

    uniqSubj = unique(subj, 'stable');
    keepIdx = zeros(numel(uniqSubj),1);
    for s = 1:numel(uniqSubj)
        idx = find(subj == uniqSubj(s));
        thisTs = ts(idx);
        if any(~isnat(thisTs))
            tmp = thisTs;
            tmp(isnat(tmp)) = datetime(1,1,1);
            [~, rel] = max(tmp);
        else
            dn = [matFiles(idx).datenum];
            [~, rel] = max(dn);
        end
        keepIdx(s) = idx(rel);
    end
    out = matFiles(keepIdx);
end

function dt = localParseTakeTimestampFromMatName(fname)
    dt = NaT;
    tok = regexp(fname, 'Take_(\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}_[AP]M)\.mat$', ...
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
