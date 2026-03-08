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
%       'reassignUnknownToNextKnown' (true) : remap short UNKNOWN pre-session anchors
%       'maxUnknownLeadMinutes' (90) : max lead time for UNKNOWN->next known remap
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
%   - Optional cleanup: short same-day UNKNOWN intervals immediately before a known mocap start
%     are reassigned to that known subject (typical stop/restart recording pattern).

    p = inputParser;
    addRequired(p, 'sourceRoot', @(x) ischar(x) || isstring(x));
    addRequired(p, 'destRoot', @(x) ischar(x) || isstring(x));
    addParameter(p, 'doCopy', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'sharedStimPath', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'reassignUnknownToNextKnown', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'maxUnknownLeadMinutes', 90, @(x) isnumeric(x) && isscalar(x) && x > 0);
    parse(p, sourceRoot, destRoot, varargin{:});

    doCopy = p.Results.doCopy;
    sourceRoot = char(sourceRoot);
    destRoot = char(destRoot);
    sharedStimPath = char(p.Results.sharedStimPath);
    reassignUnknownToNextKnown = p.Results.reassignUnknownToNextKnown;
    maxUnknownLeadMinutes = double(p.Results.maxUnknownLeadMinutes);
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
        if reassignUnknownToNextKnown
            [assignments, nUnknownReassigned] = reassignUnknownRowsToNextKnownMocap(assignments, maxUnknownLeadMinutes);
            if nUnknownReassigned > 0
                warning('buildDatasetAssignments:UnknownReassigned', ...
                    ['Reassigned %d UNKNOWN rows to next known mocap subject ', ...
                     '(same day, <= %.0f min lead).'], ...
                    nUnknownReassigned, maxUnknownLeadMinutes);
            end
        end
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

function [tbl, nChanged] = reassignUnknownRowsToNextKnownMocap(tbl, maxLeadMinutes)
% Reassign UNKNOWN rows when they are short pre-session anchors before known mocap.
    nChanged = 0;
    if isempty(tbl)
        return;
    end
    needed = {'modality', 'parsedTimestamp', 'assignedSubject', 'note'};
    if ~all(ismember(needed, tbl.Properties.VariableNames))
        return;
    end

    modality = string(tbl.modality);
    subj = upper(string(tbl.assignedSubject));
    note = string(tbl.note);
    ts = tbl.parsedTimestamp;

    mocapMask = modality == "mocap" & ~isnat(ts);
    if ~any(mocapMask)
        return;
    end

    mocapIdx = find(mocapMask);
    [~, order] = sort(ts(mocapMask));
    mocapIdx = mocapIdx(order);

    mapStart = NaT(0, 1);
    mapEnd = NaT(0, 1);
    mapSubject = strings(0, 1);
    for ii = 1:(numel(mocapIdx)-1)
        i = mocapIdx(ii);
        if subj(i) ~= "UNKNOWN"
            continue;
        end

        nextKnown = NaN;
        for jj = (ii+1):numel(mocapIdx)
            j = mocapIdx(jj);
            if subj(j) ~= "UNKNOWN" && subj(j) ~= "SHARED" && strlength(subj(j)) > 0
                nextKnown = j;
                break;
            end
        end
        if isnan(nextKnown)
            continue;
        end

        t0 = ts(i);
        t1 = ts(nextKnown);
        if isnat(t0) || isnat(t1) || t1 <= t0
            continue;
        end
        sameDay = dateshift(t0, 'start', 'day') == dateshift(t1, 'start', 'day');
        if ~sameDay
            continue;
        end
        if minutes(t1 - t0) > maxLeadMinutes
            continue;
        end

        mapStart(end+1, 1) = t0; %#ok<AGROW>
        mapEnd(end+1, 1) = t1; %#ok<AGROW>
        mapSubject(end+1, 1) = subj(nextKnown); %#ok<AGROW>
    end

    if isempty(mapStart)
        return;
    end

    changedMask = false(height(tbl), 1);
    for r = 1:height(tbl)
        if subj(r) ~= "UNKNOWN" || isnat(ts(r))
            continue;
        end
        for m = 1:numel(mapStart)
            if ts(r) >= mapStart(m) && ts(r) < mapEnd(m)
                subj(r) = mapSubject(m);
                note(r) = appendNote(note(r), sprintf( ...
                    'Reassigned from UNKNOWN to %s (pre-session restart window).', ...
                    mapSubject(m)));
                changedMask(r) = true;
                break;
            end
        end
    end

    if any(changedMask)
        if iscell(tbl.assignedSubject)
            tbl.assignedSubject = cellstr(subj);
        else
            tbl.assignedSubject = subj;
        end
        if iscell(tbl.note)
            tbl.note = cellstr(note);
        else
            tbl.note = note;
        end
        nChanged = nnz(changedMask);
    end
end

function out = appendNote(existing, extra)
    existing = strtrim(char(string(existing)));
    extra = strtrim(char(string(extra)));
    if isempty(existing)
        out = string(extra);
    else
        out = string(sprintf('%s | %s', existing, extra));
    end
end
