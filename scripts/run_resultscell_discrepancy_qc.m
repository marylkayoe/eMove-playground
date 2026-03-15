% run_resultscell_discrepancy_qc.m
%
% Compare saved legacy resultsCellSingles against regenerated resultsCellSingles
% after applying the centralized subject exclusion list.

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
legacyMat = fullfile(repoRoot, 'legacy_resultCellSingles.mat');
dataRoot = '/Users/yoe/Documents/DATA/eMOVE-matlab-new';
groupCsv = fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv');
stimCsv = fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv');
exclCsv = fullfile(repoRoot, 'resources', 'project', 'subject_exclusions.csv');

runStamp = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
outDir = fullfile(repoRoot, 'outputs', 'qc', ['resultscell_discrepancy_' runStamp]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

% Shared coding table for emotion mapping.
coding = localLoadStimCoding(stimCsv);
vidToEmotion = containers.Map(cellstr(coding.videoID), cellstr(coding.groupCode));

% Load legacy saved resultsCellSingles.
m = matfile(legacyMat);
rcLegacy = m.resultsCellSingles;
[rcLegacy, excludedIDs] = filterResultsCellBySubjectExclusion(rcLegacy);

% Regenerate current resultsCellSingles with requested settings.
[groupedMarkerNames, groupedBodypartNames] = loadBodypartGroupingCSV(groupCsv);
rcCurrent = runMotionMetricsBatch(dataRoot, groupedMarkerNames, ...
    'markerGroupNames', groupedBodypartNames, ...
    'immobilityThreshold', 25, ...
    'stimVideoEmotionCoding', coding);
rcCurrent = filterResultsCellBySubjectExclusion(rcCurrent, 'excludedIDs', excludedIDs);

% Flatten both into comparable row tables.
flatLegacy = localFlattenResultsCell(rcLegacy, vidToEmotion, 'legacy');
flatCurrent = localFlattenResultsCell(rcCurrent, vidToEmotion, 'current');
writetable(flatLegacy, fullfile(outDir, 'flat_legacy.csv'));
writetable(flatCurrent, fullfile(outDir, 'flat_current.csv'));

% Row-level discrepancy by subject x marker x video.
K = {'subjectID','markerGroupCanon','videoID'};
cmp = outerjoin(flatLegacy, flatCurrent, 'Keys', K, 'MergeKeys', true, 'Type', 'full');
v = string(cmp.Properties.VariableNames);
nImmL = localFindJoinedVar(v, "nImm", "legacy");
nImmC = localFindJoinedVar(v, "nImm", "current");
medImmL = localFindJoinedVar(v, "medImm", "legacy");
medImmC = localFindJoinedVar(v, "medImm", "current");
nFullL = localFindJoinedVar(v, "nFull", "legacy");
nFullC = localFindJoinedVar(v, "nFull", "current");
medFullL = localFindJoinedVar(v, "medFull", "legacy");
medFullC = localFindJoinedVar(v, "medFull", "current");
mgRawL = localFindJoinedVar(v, "markerGroupRaw", "legacy");
mgRawC = localFindJoinedVar(v, "markerGroupRaw", "current");

cmp.d_nImm = cmp.(nImmC) - cmp.(nImmL);
cmp.d_medImm = cmp.(medImmC) - cmp.(medImmL);
cmp.d_nFull = cmp.(nFullC) - cmp.(nFullL);
cmp.d_medFull = cmp.(medFullC) - cmp.(medFullL);
cmp.rowStatus = repmat("matched", height(cmp), 1);
cmp.rowStatus(ismissing(string(cmp.(mgRawL))) | string(cmp.(mgRawL)) == "") = "only_current";
cmp.rowStatus(ismissing(string(cmp.(mgRawC))) | string(cmp.(mgRawC)) == "") = "only_legacy";
neqMask = cmp.rowStatus == "matched" & ...
    (cmp.d_nImm ~= 0 | abs(cmp.d_medImm) > 1e-9 | cmp.d_nFull ~= 0 | abs(cmp.d_medFull) > 1e-9);
cmp.rowStatus(neqMask) = "changed";
writetable(cmp, fullfile(outDir, 'row_level_discrepancy.csv'));

% Subject-level summary.
[G, sid] = findgroups(string(cmp.subjectID));
nOnlyLegacy = splitapply(@(x) sum(x=="only_legacy"), cmp.rowStatus, G);
nOnlyCurrent = splitapply(@(x) sum(x=="only_current"), cmp.rowStatus, G);
nChanged = splitapply(@(x) sum(x=="changed"), cmp.rowStatus, G);
nMatched = splitapply(@(x) sum(x=="matched"), cmp.rowStatus, G);
subjSummary = table(cellstr(sid), nOnlyLegacy, nOnlyCurrent, nChanged, nMatched, ...
    'VariableNames', {'subjectID','nOnlyLegacy','nOnlyCurrent','nChanged','nMatched'});
subjSummary = sortrows(subjSummary, {'nChanged','nOnlyLegacy','nOnlyCurrent'}, {'descend','descend','descend'});
writetable(subjSummary, fullfile(outDir, 'subject_discrepancy_summary.csv'));

% FEAR/JOY per-subject counts and KS comparison for key markers.
pairTblLegacy = localPerSubjectPairTable(rcLegacy, vidToEmotion);
pairTblCurrent = localPerSubjectPairTable(rcCurrent, vidToEmotion);
pairCmp = outerjoin(pairTblLegacy, pairTblCurrent, ...
    'Keys', {'subjectID','markerGroupCanon','pairLabel'}, ...
    'MergeKeys', true, 'Type', 'full');
pv = string(pairCmp.Properties.VariableNames);
nAL = localFindJoinedVar(pv, "nA", "legacy");
nAC = localFindJoinedVar(pv, "nA", "current");
nBL = localFindJoinedVar(pv, "nB", "legacy");
nBC = localFindJoinedVar(pv, "nB", "current");
ksL = localFindJoinedVar(pv, "ksD", "legacy");
ksC = localFindJoinedVar(pv, "ksD", "current");
dL = localFindJoinedVar(pv, "delta", "legacy");
dC = localFindJoinedVar(pv, "delta", "current");
pairCmp.d_nFear = pairCmp.(nAC) - pairCmp.(nAL);
pairCmp.d_nJoy = pairCmp.(nBC) - pairCmp.(nBL);
pairCmp.d_ksD = pairCmp.(ksC) - pairCmp.(ksL);
pairCmp.d_delta = pairCmp.(dC) - pairCmp.(dL);
writetable(pairCmp, fullfile(outDir, 'pair_level_discrepancy.csv'));

% Focus summary for FEAR-JOY and selected marker groups.
focusMask = strcmp(string(pairCmp.pairLabel), 'FEAR-JOY') & ...
    ismember(string(pairCmp.markerGroupCanon), ["HEAD","WRIST_L","WRIST_R","L_WRIST","R_WRIST","HEAD_LOWER"]);
focus = pairCmp(focusMask, :);
writetable(focus, fullfile(outDir, 'focus_fearjoy_discrepancy.csv'));

% Metadata
meta = table(string(exclCsv), string(join(string(excludedIDs), ';')), ...
    height(flatLegacy), height(flatCurrent), height(cmp), ...
    'VariableNames', {'exclusionCsv','excludedIDs','nFlatLegacy','nFlatCurrent','nJoinedRows'});
writetable(meta, fullfile(outDir, 'run_meta.csv'));

disp('Top subject discrepancies:');
disp(subjSummary(1:min(10,height(subjSummary)), :));
fprintf('Saved discrepancy outputs to:\n%s\n', outDir);

%% Local helpers
function coding = localLoadStimCoding(stimCsv)
    opts = detectImportOptions(stimCsv, 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, intersect({'videoID','emotionTag','groupCode'}, opts.VariableNames, 'stable'), 'string');
    T = readtable(stimCsv, opts);
    include = localToLogical(T.include);
    vid = upper(strtrim(string(T.videoID)));
    isNum = ~cellfun('isempty', regexp(cellstr(vid), '^\d+$'));
    vid(isNum) = compose('%04d', str2double(vid(isNum)));
    if ismember('groupCode', T.Properties.VariableNames)
        emo = upper(strtrim(string(T.groupCode)));
    else
        emo = upper(strtrim(string(T.emotionTag)));
    end
    keep = include & vid ~= "" & emo ~= "";
    coding = table(vid(keep), emo(keep), 'VariableNames', {'videoID','groupCode'});
end

function out = localToLogical(v)
    if islogical(v), out = v; return; end
    if isnumeric(v), out = v ~= 0; return; end
    s = upper(strtrim(string(v)));
    out = (s == "1" | s == "TRUE" | s == "T" | s == "YES" | s == "Y");
end

function T = localFlattenResultsCell(resultsCell, vidToEmotion, tag)
    rows = [];
    for i = 1:numel(resultsCell)
        rc = resultsCell{i};
        if ~isfield(rc, 'subjectID') || ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
            continue;
        end
        sid = upper(strtrim(string(rc.subjectID)));
        st = rc.summaryTable;
        needed = {'markerGroup','videoID','speedArrayImmobile','speedArray'};
        if ~all(ismember(needed, st.Properties.VariableNames))
            continue;
        end
        for r = 1:height(st)
            mgRaw = string(st.markerGroup{r});
            vid = upper(strtrim(string(st.videoID{r})));
            emo = "";
            if isKey(vidToEmotion, char(vid))
                emo = string(vidToEmotion(char(vid)));
            end
            imm = st.speedArrayImmobile{r};
            full = st.speedArray{r};
            imm = imm(~isnan(imm));
            full = full(~isnan(full));

            row.subjectID = char(sid);
            row.markerGroupRaw = char(mgRaw);
            row.markerGroupCanon = char(localCanonMarkerGroup(mgRaw));
            row.videoID = char(vid);
            row.emotion = char(emo);
            row.nImm = numel(imm);
            row.medImm = median(imm, 'omitnan');
            row.nFull = numel(full);
            row.medFull = median(full, 'omitnan');
            row.sourceTag = tag;
            rows = [rows; row]; %#ok<AGROW>
        end
    end
    T = struct2table(rows);
end

function T = localPerSubjectPairTable(resultsCell, vidToEmotion)
    rows = [];
    for i = 1:numel(resultsCell)
        rc = resultsCell{i};
        if ~isfield(rc, 'subjectID') || ~isfield(rc, 'summaryTable') || isempty(rc.summaryTable)
            continue;
        end
        sid = upper(strtrim(string(rc.subjectID)));
        st = rc.summaryTable;
        if ~all(ismember({'markerGroup','videoID','speedArrayImmobile'}, st.Properties.VariableNames))
            continue;
        end
        mgList = unique(string(st.markerGroup), 'stable');
        for g = 1:numel(mgList)
            mg = mgList(g);
            mask = string(st.markerGroup) == mg;
            vids = upper(strtrim(string(st.videoID(mask))));
            cellVals = st.speedArrayImmobile(mask);
            fear = [];
            joy = [];
            for k = 1:numel(vids)
                v = vids(k);
                emo = "";
                if isKey(vidToEmotion, char(v))
                    emo = upper(strtrim(string(vidToEmotion(char(v)))));
                end
                if emo == "FEAR"
                    fear = [fear; cellVals{k}(:)]; %#ok<AGROW>
                elseif emo == "JOY"
                    joy = [joy; cellVals{k}(:)]; %#ok<AGROW>
                end
            end
            fear = fear(~isnan(fear));
            joy = joy(~isnan(joy));
            row.subjectID = char(sid);
            row.markerGroupCanon = char(localCanonMarkerGroup(mg));
            row.pairLabel = 'FEAR-JOY';
            row.nA = numel(fear);
            row.nB = numel(joy);
            row.medA = median(fear, 'omitnan');
            row.medB = median(joy, 'omitnan');
            row.delta = row.medB - row.medA;
            if row.nA >= 200 && row.nB >= 200
                [~, ~, d] = kstest2(fear, joy);
                row.ksD = d;
            else
                row.ksD = NaN;
            end
            rows = [rows; row]; %#ok<AGROW>
        end
    end
    T = struct2table(rows);
end

function mg = localCanonMarkerGroup(raw)
    mg = upper(strtrim(string(raw)));
    mg = replace(mg, "-", "_");
    mg = replace(mg, " ", "_");
    mg = replace(mg, "__", "_");
    % Alias legacy group names to current taxonomy for apples-to-apples comparison.
    if mg == "L_ARM", mg = "UPPER_LIMB_L"; end
    if mg == "R_ARM", mg = "UPPER_LIMB_R"; end
    if mg == "L_LEG", mg = "LOWER_LIMB_L"; end
    if mg == "R_LEG", mg = "LOWER_LIMB_R"; end
    if mg == "L_WRIST", mg = "WRIST_L"; end
    if mg == "R_WRIST", mg = "WRIST_R"; end
    if mg == "UPPERTORSO", mg = "UTORSO"; end
    if mg == "WAIST", mg = "LTORSO"; end
end

function name = localFindJoinedVar(varNames, baseName, sideTag)
    % Accept either base_sideTag or base_tableSuffix style names.
    q1 = baseName + "_" + sideTag;
    idx = find(varNames == q1, 1, 'first');
    if ~isempty(idx)
        name = char(varNames(idx));
        return;
    end
    idx = find(startsWith(varNames, baseName + "_"), 1, 'first');
    if isempty(idx)
        name = char(baseName);
    else
        % Prefer the one containing sideTag if present.
        cand = varNames(startsWith(varNames, baseName + "_"));
        pick = find(contains(lower(cand), lower(sideTag)), 1, 'first');
        if isempty(pick)
            name = char(cand(1));
        else
            name = char(cand(pick));
        end
    end
end
