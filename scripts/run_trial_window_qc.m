% run_trial_window_qc.m
%
% QC summary of manifest-based trial window slicing.

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
matRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest';
outDir = fullfile(repoRoot, 'outputs', 'qc', ['trial_windows_' char(string(datetime('now','Format','yyyyMMdd_HHmmss')))]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

subjDirs = dir(matRoot);
rows = struct('subjectID', {}, 'matFile', {}, 'segmentIdx', {}, 'videoID', {}, ...
    'startFrame', {}, 'endFrame', {}, 'durationFrames', {}, 'durationSec', {}, ...
    'isBaseline', {}, 'gapPrevFrames', {}, 'gapPrevSec', {});

for i = 1:numel(subjDirs)
    if ~subjDirs(i).isdir, continue; end
    subj = subjDirs(i).name;
    if any(strcmp(subj, {'.','..'})), continue; end
    if isempty(regexp(subj, '^[A-Z]{2}\d{4}$', 'once')), continue; end

    mfiles = dir(fullfile(matRoot, subj, '*.mat'));
    if isempty(mfiles), continue; end
    pick = localPickLatest(mfiles);
    mpath = fullfile(mfiles(pick).folder, mfiles(pick).name);

    S = load(mpath, 'trialData');
    if ~isfield(S, 'trialData') || ~isfield(S.trialData, 'metaData')
        continue;
    end
    td = S.trialData;
    if ~isfield(td.metaData, 'stimScheduling') || ~isfield(td.metaData, 'videoIDs')
        continue;
    end

    ss = td.metaData.stimScheduling;
    vids = td.metaData.videoIDs;
    if isnumeric(vids), vids = cellstr(string(vids)); end
    if isstring(vids), vids = cellstr(vids); end
    if size(ss,1) ~= numel(vids)
        n = min(size(ss,1), numel(vids));
        ss = ss(1:n,:);
        vids = vids(1:n);
    end

    fr = 120;
    if isfield(td.metaData, 'captureFrameRate') && ~isempty(td.metaData.captureFrameRate)
        fr = td.metaData.captureFrameRate;
    end

    for k = 1:size(ss,1)
        st = ss(k,1);
        en = ss(k,2);
        dur = en - st;
        gap = NaN;
        if k > 1
            gap = st - ss(k-1,2);
        end

        r.subjectID = subj;
        r.matFile = mfiles(pick).name;
        r.segmentIdx = k;
        r.videoID = char(string(vids{k}));
        r.startFrame = st;
        r.endFrame = en;
        r.durationFrames = dur;
        r.durationSec = dur / fr;
        r.isBaseline = strcmpi(r.videoID, 'BASELINE') || strcmp(r.videoID, '0');
        r.gapPrevFrames = gap;
        r.gapPrevSec = gap / fr;
        rows(end+1) = r; %#ok<AGROW>
    end
end

if isempty(rows)
    error('No trial window rows collected.');
end

T = struct2table(rows);
writetable(T, fullfile(outDir, 'trial_windows_by_segment.csv'));

% Summary by videoID (excluding baseline)
nonBase = T(~T.isBaseline, :);
[g, vid] = findgroups(string(nonBase.videoID));
durMed = splitapply(@(x) median(x,'omitnan'), nonBase.durationFrames, g);
durMin = splitapply(@(x) min(x), nonBase.durationFrames, g);
durMax = splitapply(@(x) max(x), nonBase.durationFrames, g);
nRows = splitapply(@numel, nonBase.durationFrames, g);
Svid = table(vid, nRows, durMed, durMin, durMax, ...
    'VariableNames', {'videoID','nSegments','medianFrames','minFrames','maxFrames'});
writetable(Svid, fullfile(outDir, 'trial_windows_by_video_summary.csv'));

% Subject-level checks
[gs, subj] = findgroups(string(T.subjectID));
nSeg = splitapply(@numel, T.segmentIdx, gs);
nBase = splitapply(@(x) sum(x), T.isBaseline, gs);
durNonBaseMed = splitapply(@(x,b) median(x(~b),'omitnan'), T.durationFrames, T.isBaseline, gs);
Sqc = table(subj, nSeg, nBase, durNonBaseMed, ...
    'VariableNames', {'subjectID','nSegments','nBaselineSegments','medianNonBaselineFrames'});
writetable(Sqc, fullfile(outDir, 'trial_windows_subject_qc.csv'));

fprintf('QC done: %s\n', outDir);
fprintf('Subjects: %d\n', numel(unique(T.subjectID)));
fprintf('Rows: %d\n', height(T));
fprintf('Median non-baseline frames: %.1f\n', median(nonBase.durationFrames,'omitnan'));

function idx = localPickLatest(mfiles)
    t = NaT(numel(mfiles),1);
    for i = 1:numel(mfiles)
        tok = regexp(mfiles(i).name, 'Take_(\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}_[AP]M)\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            s = strrep(tok{1}, '_', ' ');
            try
                t(i) = datetime(s, 'InputFormat', 'yyyy MM dd hh mm ss a');
            catch
                t(i) = NaT;
            end
        end
    end
    if any(~isnat(t))
        tt = t;
        tt(isnat(tt)) = datetime(1,1,1);
        [~, idx] = max(tt);
    else
        [~, idx] = max([mfiles.datenum]);
    end
end
