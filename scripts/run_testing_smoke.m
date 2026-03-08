% run_testing_smoke.m
%
% Smoke test for current eMove ingestion/config assets.
% This script performs I/O and consistency checks only.
% It does NOT run motion/physiology metric computations.

clearvars;
clc;

%% Paths (edit if needed)
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
stimCsv = '/Users/yoe/Documents/REPOS/eMove-playground/resources/stim_video_encoding_SINGLES.csv';
groupCsv = '/Users/yoe/Documents/REPOS/eMove-playground/resources/bodypart_marker_grouping.csv';
matRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest';
keepLatestMatPerSubject = true;

addpath(genpath(fullfile(repoRoot, 'CODE')));

fprintf('\n=== eMove Smoke Test (No Computation) ===\n');

%% 1) File presence
mustExist = {stimCsv, groupCsv, matRoot};
for i = 1:numel(mustExist)
    p = mustExist{i};
    if isfolder(p) || isfile(p)
        fprintf('OK   exists: %s\n', p);
    else
        error('Missing required path: %s', p);
    end
end

%% 2) Stim encoding table checks
fprintf('\n[Stim Encoding]\n');
opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
strCols = {'videoID','emotionTag','emotionCategory','valenceLabel','arousalLabel','notes'};
strCols = intersect(strCols, opts.VariableNames, 'stable');
if ~isempty(strCols)
    opts = setvartype(opts, strCols, 'string');
end
Tstim = readtable(stimCsv, opts);

requiredStimCols = {'videoID','emotionTag','isBaseline','include'};
assert(all(ismember(requiredStimCols, Tstim.Properties.VariableNames)), ...
    'Stim encoding CSV missing required columns.');

Tstim.videoID = normalizeVideoID(Tstim.videoID, Tstim.isBaseline);
Tstim.emotionTag = upper(strtrim(string(Tstim.emotionTag)));
Tstim.include = toLogicalColumn(Tstim.include);

Tincluded = Tstim(Tstim.include, :);
fprintf('Rows total=%d | included=%d\n', height(Tstim), height(Tincluded));

[uVid, ~, idxVid] = unique(Tincluded.videoID, 'stable');
countsVid = accumarray(idxVid, 1);
dupMask = countsVid > 1;
if any(dupMask)
    fprintf('WARN duplicate included video IDs: %s\n', strjoin(cellstr(uVid(dupMask)), ', '));
else
    fprintf('OK   no duplicate included video IDs.\n');
end

baselineRows = Tincluded(strcmpi(Tincluded.videoID, 'BASELINE'), :);
if isempty(baselineRows)
    fprintf('WARN BASELINE missing from included stim table.\n');
else
    fprintf('OK   BASELINE present in included stim table.\n');
end

nUnknownTag = nnz(Tincluded.emotionTag == "X" | Tincluded.emotionTag == "");
if nUnknownTag > 0
    fprintf('INFO included rows with unresolved emotionTag (X/empty): %d\n', nUnknownTag);
end

codingTable = table(Tincluded.videoID, Tincluded.emotionTag, ...
    'VariableNames', {'videoID','groupCode'});

%% 3) Bodypart grouping checks
fprintf('\n[Bodypart Grouping]\n');
[groupedMarkerNames, groupedBodypartNames, markerTbl, groupTbl] = loadBodypartGroupingCSV(groupCsv);
fprintf('Rows total=%d | included=%d | groups=%d\n', ...
    height(markerTbl), nnz(markerTbl.include), numel(groupedBodypartNames));

if isempty(groupedBodypartNames)
    error('No included bodypart groups found.');
end

allGroupedMarkers = string(vertcat(groupedMarkerNames{:}));
if isempty(allGroupedMarkers)
    error('No included markers found in bodypart grouping.');
end
fprintf('Included markers across groups: %d\n', numel(allGroupedMarkers));

%% 4) MAT consistency checks
fprintf('\n[MAT Consistency]\n');
matFiles = dir(fullfile(matRoot, '*', '*.mat'));
if isempty(matFiles)
    error('No MAT files found under %s', matRoot);
end
fprintf('MAT files found (raw): %d\n', numel(matFiles));
if keepLatestMatPerSubject
    matFiles = selectLatestMatPerSubject(matFiles);
    fprintf('MAT files used (latest per subject): %d\n', numel(matFiles));
else
    fprintf('MAT files used: %d\n', numel(matFiles));
end

subjectCol = strings(numel(matFiles),1);
nVideoCol = zeros(numel(matFiles),1);
nMissingCodingCol = zeros(numel(matFiles),1);
missingCodingCol = strings(numel(matFiles),1);
nMissingMarkerCol = zeros(numel(matFiles),1);
modalityErrCol = zeros(numel(matFiles),1);

for i = 1:numel(matFiles)
    matPath = fullfile(matFiles(i).folder, matFiles(i).name);
    S = load(matPath);
    assert(isfield(S, 'trialData'), 'MAT missing trialData: %s', matPath);
    td = S.trialData;

    subj = "UNKNOWN";
    if isfield(td, 'subjectID') && ~isempty(td.subjectID)
        subj = upper(string(td.subjectID));
    end
    subjectCol(i) = subj;

    assert(isfield(td, 'markerNames') && ~isempty(td.markerNames), ...
        'trialData.markerNames missing/empty: %s', matPath);
    tdMarkers = upper(strtrim(string(td.markerNames)));
    missingMarkers = setdiff(upper(strtrim(allGroupedMarkers)), tdMarkers);
    nMissingMarkerCol(i) = numel(missingMarkers);

    assert(isfield(td, 'metaData') && isfield(td.metaData, 'videoIDs'), ...
        'trialData.metaData.videoIDs missing: %s', matPath);
    tdVid = normalizeVideoID(td.metaData.videoIDs, []);
    nVideoCol(i) = numel(tdVid);
    missingCoding = setdiff(tdVid, codingTable.videoID);
    nMissingCodingCol(i) = numel(missingCoding);
    if ~isempty(missingCoding)
        missingCodingCol(i) = strjoin(cellstr(missingCoding), ';');
    else
        missingCodingCol(i) = "";
    end

    modalityErrCol(i) = countModalityLoadErrors(td);
end

summaryTbl = table(subjectCol, nVideoCol, nMissingCodingCol, nMissingMarkerCol, modalityErrCol, missingCodingCol, ...
    'VariableNames', {'subjectID','nVideos','nMissingCoding','nMissingMarkers','nModalityLoadErrors','missingCodingIDs'});

fprintf('Subjects with missing coding IDs: %d\n', nnz(summaryTbl.nMissingCoding > 0));
fprintf('Subjects with missing grouped markers: %d\n', nnz(summaryTbl.nMissingMarkers > 0));
fprintf('Subjects with modality load errors: %d\n', nnz(summaryTbl.nModalityLoadErrors > 0));

disp(summaryTbl(summaryTbl.nMissingCoding > 0 | summaryTbl.nMissingMarkers > 0 | summaryTbl.nModalityLoadErrors > 0, :));

fprintf('\nSmoke test complete.\n');

%% Local functions
function vid = normalizeVideoID(rawVid, isBaseline)
    vid = upper(strtrim(string(rawVid)));
    if nargin >= 2 && ~isempty(isBaseline)
        ib = logical(isBaseline);
        ib = ib(:);
        if numel(ib) == numel(vid)
            vid(ib) = "BASELINE";
        end
    end
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));
end

function nErr = countModalityLoadErrors(td)
    nErr = 0;
    if ~isfield(td, 'modalityData')
        return;
    end
    mods = {'unity','eda','hr'};
    for m = 1:numel(mods)
        if ~isfield(td.modalityData, mods{m})
            continue;
        end
        arr = td.modalityData.(mods{m});
        for k = 1:numel(arr)
            if isfield(arr(k), 'loadError') && ~isempty(arr(k).loadError)
                nErr = nErr + 1;
            end
        end
    end
end

function out = toLogicalColumn(v)
    if islogical(v)
        out = v;
        return;
    end
    if isnumeric(v)
        out = v ~= 0;
        return;
    end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end

function out = selectLatestMatPerSubject(matFiles)
    if isempty(matFiles)
        out = matFiles;
        return;
    end

    subj = strings(numel(matFiles),1);
    tstamp = NaT(numel(matFiles),1);
    for i = 1:numel(matFiles)
        [~, subjName] = fileparts(matFiles(i).folder);
        subj(i) = upper(string(subjName));
        tstamp(i) = parseTakeTimestampFromMatName(matFiles(i).name);
    end

    uniqSubj = unique(subj, 'stable');
    keepIdx = zeros(numel(uniqSubj),1);
    for s = 1:numel(uniqSubj)
        idx = find(subj == uniqSubj(s));
        ts = tstamp(idx);
        if any(~isnat(ts))
            ts2 = ts;
            ts2(isnat(ts2)) = datetime(1,1,1);
            [~, rel] = max(ts2);
        else
            dn = [matFiles(idx).datenum];
            [~, rel] = max(dn);
        end
        keepIdx(s) = idx(rel);
    end
    out = matFiles(keepIdx);
end

function dt = parseTakeTimestampFromMatName(fname)
% Parse "...Take_2025_08_25_05_19_25_PM.mat" style names.
    dt = NaT;
    tok = regexp(fname, 'Take_(\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}_[AP]M)\.mat$', ...
        'tokens', 'once');
    if isempty(tok)
        return;
    end
    s = strrep(tok{1}, '_', ' ');
    % 2025 08 25 05 19 25 PM
    try
        dt = datetime(s, 'InputFormat', 'yyyy MM dd hh mm ss a');
    catch
        dt = NaT;
    end
end
