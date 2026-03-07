function assignments = buildDatasetAssignments(sourceRoot, destRoot, varargin)
% buildDatasetAssignments Create a lookup table mapping raw files to subjects based on timestamps.
%
% Pipeline stage:
%   RAW file organization only (no signal-level computation).
%
% Typical use:
%   1) Run once to inspect assignment quality.
%   2) Review rows with non-empty "note".
%   3) Re-run with 'doCopy', true after verification.
%
% assignments = buildDatasetAssignments(sourceRoot, destRoot, 'doCopy', false)
% - sourceRoot: path to HUMANMOCAP (containing MoCap_Data, Unity_Logs, etc.)
% - destRoot:   path to reorganized dataset (used only for destination paths; no copies by default)
% - Optional name-value:
%       'doCopy' (false)  : copy files into destRoot following the per-subject layout
%       'sharedStimPath'  : path for shared stim videos (default: fullfile(destRoot,'stimvideos'))
%
% Output table columns:
%   sourcePath       - full path of the raw file
%   modality         - 'mocap' | 'unity' | 'hr' | 'eda'
%   parsedTimestamp  - datetime parsed from filename/metadata (used for matching)
%   assignedSubject  - subject ID inferred for the file
%   destPath         - suggested destination path under destRoot
%   note             - warnings or hints about the assignment
%
% Logic:
%   - Mocap files define session anchors (one session per subject).
%   - Unity logs within a mocap interval carry the subject ID; that ID is assigned to the mocap session.
%   - HR/EDA files are assigned to the mocap interval whose start is closest prior on the same date.

    p = inputParser;
    addRequired(p, 'sourceRoot', @(x) ischar(x) || isstring(x));
    addRequired(p, 'destRoot', @(x) ischar(x) || isstring(x));
    addParameter(p, 'doCopy', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'sharedStimPath', '', @(x) ischar(x) || isstring(x));
    parse(p, sourceRoot, destRoot, varargin{:});

    doCopy = p.Results.doCopy;
    sourceRoot = char(sourceRoot);
    destRoot = char(destRoot);
    sharedStimPath = char(p.Results.sharedStimPath);
    if isempty(sharedStimPath)
        sharedStimPath = fullfile(destRoot, 'stimvideos');
    end

    rows = [];
    skipped = struct('unity', 0, 'unityPreBaseline', 0, 'mocap', 0, 'hr', 0, 'eda', 0);

    % 1) Mocap anchors
    mocapDir = fullfile(sourceRoot, 'MoCap_Data');
    mocapFiles = dir(fullfile(mocapDir, '*.csv'));
    mocapEntries = [];
    for k = 1:numel(mocapFiles)
        f = mocapFiles(k);
        dt = parseMocapTime(f.name);
        if isnat(dt)
            continue;
        end
        mocapEntries(end+1).start = dt; %#ok<AGROW>
        mocapEntries(end).path = fullfile(f.folder, f.name);
        mocapEntries(end).subject = ''; % will be filled from unity logs
        mocapEntries(end).isExcluded = false;
    end
    if isempty(mocapEntries)
        warning('No mocap files found under %s', mocapDir);
        assignments = table();
        return;
    end
    % sort by start time
    [~, order] = sort([mocapEntries.start]);
    mocapEntries = mocapEntries(order);
    % set interval ends
    for i = 1:numel(mocapEntries)
        if i < numel(mocapEntries)
            mocapEntries(i).end = mocapEntries(i+1).start;
        else
            mocapEntries(i).end = datetime('9999-12-31');
        end
    end

    % 2) Unity logs (carry subject IDs)
    unityDir = fullfile(sourceRoot, 'Unity_Logs', 'Logs');
    if ~isfolder(unityDir)
        unityDir = fullfile(sourceRoot, 'Unity_Logs');
    end
    unityFiles = dir(fullfile(unityDir, '*.csv'));

    % Determine per-subject last baseline time so pre-baseline recordings can be ignored.
    unitySubj = strings(numel(unityFiles), 1);
    unityDt = NaT(numel(unityFiles), 1);
    unityIsBaseline = false(numel(unityFiles), 1);
    for k = 1:numel(unityFiles)
        [subjK, dtK, videoIDK] = parseUnityFile(unityFiles(k).name);
        unitySubj(k) = string(subjK);
        unityDt(k) = dtK;
        unityIsBaseline(k) = strcmpi(videoIDK, 'BASELINE');
    end

    for k = 1:numel(unityFiles)
        f = unityFiles(k);
        [subj, dt, videoID] = parseUnityFile(f.name); %#ok<ASGLU>

        lastBaseline = getLastBaselineForSubject(subj, unitySubj, unityDt, unityIsBaseline);
        if ~isnat(dt) && ~isnat(lastBaseline) && dt < lastBaseline
            skipped.unityPreBaseline = skipped.unityPreBaseline + 1;
            continue;
        end

        [isExcludedHardwired, subjNorm] = isHardwiredExcludedSubjectID(subj);
        assignedSubj = subjNorm;

        if isExcludedHardwired
            if ~isnat(dt)
                idx = findInterval(dt, mocapEntries);
                if ~isempty(idx)
                    mocapEntries(idx).subject = subjNorm;
                    mocapEntries(idx).isExcluded = true;
                end
            end
            skipped.unity = skipped.unity + 1;
            continue;
        end

        if isnat(dt)
            note = 'Could not parse datetime';
        else
            idx = findInterval(dt, mocapEntries);
            note = '';
            if isempty(idx)
                note = 'No matching mocap interval';
            end
            if ~isempty(idx)
                mocapEntries(idx).subject = subjNorm; % set subject for that session
            end
        end
        destPath = fullfile(destRoot, subjOrUnknown(assignedSubj), 'unitylogs', ...
            sprintf('%s_unitylog_%s', subjOrUnknown(assignedSubj), f.name));
        rows = addRow(rows, fullfile(f.folder, f.name), 'unity', dt, assignedSubj, destPath, note);
    end

    % 3) Finalize mocap subjects (fill unknowns)
    for i = 1:numel(mocapEntries)
        if mocapEntries(i).isExcluded
            skipped.mocap = skipped.mocap + 1;
            continue;
        end

        subj = mocapEntries(i).subject;
        if isempty(subj)
            subj = 'UNKNOWN';
        end
        [~, mocapBase, mocapExt] = fileparts(mocapEntries(i).path);
        destPath = fullfile(destRoot, subj, 'mocap', sprintf('%s_mocap_%s%s', subj, mocapBase, mocapExt));
        rows = addRow(rows, mocapEntries(i).path, 'mocap', mocapEntries(i).start, subj, destPath, '');
        mocapEntries(i).subject = subj;
    end

    % 4) HR (Movesense)
    hrDir = fullfile(sourceRoot, 'Movesense_Data');
    hrFiles = dir(fullfile(hrDir, 'MovesenseECG-*.csv'));
    for k = 1:numel(hrFiles)
        f = hrFiles(k);
        dt = parseMovesenseTime(f.name);
        [assignedSubj, note] = assignToInterval(dt, mocapEntries);
        if strcmp(assignedSubj, 'EXCLUDED')
            skipped.hr = skipped.hr + 1;
            continue;
        end
        destPath = fullfile(destRoot, subjOrUnknown(assignedSubj), 'hr', ...
            sprintf('%s_hr_%s', subjOrUnknown(assignedSubj), f.name));
        rows = addRow(rows, fullfile(f.folder, f.name), 'hr', dt, assignedSubj, destPath, note);
    end

    % 5) EDA (Shimmer)
    edaDir = fullfile(sourceRoot, 'Shimmer_Data');
    edaFiles = dir(fullfile(edaDir, '*.csv'));
    for k = 1:numel(edaFiles)
        f = edaFiles(k);
        dt = parseShimmerTimestamp(fullfile(f.folder, f.name));
        [assignedSubj, note] = assignToInterval(dt, mocapEntries);
        if strcmp(assignedSubj, 'EXCLUDED')
            skipped.eda = skipped.eda + 1;
            continue;
        end
        destPath = fullfile(destRoot, subjOrUnknown(assignedSubj), 'eda', ...
            sprintf('%s_eda_%s', subjOrUnknown(assignedSubj), f.name));
        rows = addRow(rows, fullfile(f.folder, f.name), 'eda', dt, assignedSubj, destPath, note);
    end

    % 6) Shared stim videos: no reassignment, just map to shared folder
    stimDir = fullfile(sourceRoot, 'STIMVIDEOS');
    stimFiles = dir(fullfile(stimDir, '*'));
    stimFiles = stimFiles(~[stimFiles.isdir]);
    for k = 1:numel(stimFiles)
        f = stimFiles(k);
        destPath = fullfile(sharedStimPath, f.name);
        rows = addRow(rows, fullfile(f.folder, f.name), 'stim', NaT, 'SHARED', destPath, '');
    end

    if isempty(rows)
        assignments = table();
    else
        assignments = struct2table(rows);
    end

    if doCopy
        copyAssignments(assignments);
    end

    nSkipped = skipped.unity + skipped.unityPreBaseline + skipped.mocap + skipped.hr + skipped.eda;
    if nSkipped > 0
        warning('buildDatasetAssignments:FilesSkippedByRules', ...
            ['Applied dataset rules: hardwired excluded subjects and pre-baseline trimming. ', ...
             'Skipped: unityExcluded=%d, unityPreBaseline=%d, mocapExcluded=%d, hrExcluded=%d, edaExcluded=%d.'], ...
            skipped.unity, skipped.unityPreBaseline, skipped.mocap, skipped.hr, skipped.eda);
    end
end

% Helpers
function dt = parseMocapTime(fname)
    % Expecting: Take 2025-08-15 01.36.32 PM.csv
    expr = 'Take\s+(\d{4}-\d{2}-\d{2}\s+\d{2}\.\d{2}\.\d{2}\s+[AP]M)\.csv$';
    tok = regexp(fname, expr, 'tokens', 'once');
    if isempty(tok)
        dt = NaT;
        return;
    end
    dt = datetime(tok{1}, 'InputFormat', 'yyyy-MM-dd hh.mm.ss a');
end

function [subj, dt, videoID] = parseUnityFile(fname)
    % Example: PNr_xb0202_2025-08-15-13-54 x_0806.csv  or ... Baseline Log.csv
    subj = 'UNKNOWN';
    dt = NaT;
    videoID = 'unknown';
    expr = 'PNr_([^_]+)_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\s+(.+)\.csv$';
    tok = regexp(fname, expr, 'tokens', 'once');
    if isempty(tok)
        return;
    end
    [subj, ~] = normalizeSubjectID(tok{1});
    dt = datetime(tok{2}, 'InputFormat', 'yyyy-MM-dd-HH-mm');
    tail = char(string(tok{3}));
    if contains(lower(tail), 'baseline')
        videoID = 'BASELINE';
    else
        videoID = regexprep(tail, '\s+', '_');
    end
end

function dt = parseMovesenseTime(fname)
    % Example: MovesenseECG-2025-07-11T10_33_34.760356Z.csv
    expr = 'MovesenseECG-(\d{4}-\d{2}-\d{2}T\d{2}_\d{2}_\d{2}(?:\.\d+)?Z)\.csv$';
    tok = regexp(fname, expr, 'tokens', 'once');
    if isempty(tok)
        dt = NaT;
        return;
    end
    timestr = strrep(tok{1}, '_', ':');
    dt = datetime(timestr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSSSS''Z''', 'TimeZone', 'UTC');
    dt.TimeZone = ''; % make naive for comparison
end

function dt = parseShimmerTimestamp(fullPath)
    % Shimmer files: use the timestamp inside the CSV (first column, third row).
    dt = NaT;
    try
        row = readSingleCSVRow(fullPath, 4);
        if isempty(row)
            return;
        end
        tsStr = strtrim(row{1});
        if isempty(tsStr)
            return;
        end
        % Try common Shimmer datetime formats (adjustable)
        fmts = { ...
            'yyyy/MM/dd HH:mm:ss.SSS', ... % e.g., 2025/07/24 14:54:35.242
            'MM/dd/yyyy HH:mm:ss.SSS', ...
            'yyyy-MM-dd HH:mm:ss.SSS', ...
            'dd.MM.yyyy HH:mm:ss.SSS', ...
            'MM/dd/yyyy HH:mm:ss' ...
            };
        for i = 1:numel(fmts)
            try
                dt = datetime(tsStr, 'InputFormat', fmts{i});
                if ~isnat(dt)
                    break;
                end
            catch
                % try next
            end
        end
    catch
        dt = NaT;
    end
end

function idx = findInterval(dt, intervals)
    idx = [];
    if isnat(dt)
        return;
    end
    for i = 1:numel(intervals)
        if dt >= intervals(i).start && dt < intervals(i).end
            idx = i;
            return;
        end
    end
end

function [subj, note] = assignToInterval(dt, intervals)
    subj = 'UNKNOWN';
    note = '';
    if isnat(dt)
        note = 'No timestamp parsed';
        return;
    end
    idx = findInterval(dt, intervals);
    if isempty(idx)
        note = 'No matching mocap interval';
        return;
    end
    if isfield(intervals, 'isExcluded') && intervals(idx).isExcluded
        subj = 'EXCLUDED';
        note = 'Hardwired excluded subject interval';
        return;
    end
    subj = intervals(idx).subject;
    if strcmp(subj, 'UNKNOWN')
        note = 'Interval has unknown subject';
    end
end

function s = subjOrUnknown(s)
    if isempty(s)
        s = 'UNKNOWN';
    end
end

function rows = addRow(rows, sourcePath, modality, dt, subj, destPath, note)
    row.sourcePath = sourcePath;
    row.modality = modality;
    row.parsedTimestamp = dt;
    row.assignedSubject = subjOrUnknown(subj);
    row.destPath = destPath;
    row.note = note;
    rows = [rows; row];
end

function copyAssignments(tbl)
    % Side effect: writes files into destination folders.
    for i = 1:height(tbl)
        src = tbl.sourcePath{i};
        dst = tbl.destPath{i};
        if any(strcmp(tbl.modality{i}, {'stim'}))
            % shared stim copied once; if exists, skip
            if exist(dst, 'file')
                continue;
            end
        end
        dstDir = fileparts(dst);
        if ~exist(dstDir, 'dir')
            mkdir(dstDir);
        end
        copyfile(src, dst);
    end
end

function lastBaseline = getLastBaselineForSubject(subj, subjList, dtList, isBaselineList)
% Return last baseline datetime for one subject, or NaT if absent.
    lastBaseline = NaT;
    mask = strcmpi(cellstr(subjList), subj) & isBaselineList & ~isnat(dtList);
    if ~any(mask)
        return;
    end
    baselineTimes = dtList(mask);
    lastBaseline = max(baselineTimes);
end
