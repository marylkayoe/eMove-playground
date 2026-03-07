function out = parseSelfReportBodyCSV(csvPath, varargin)
% parseSelfReportBodyCSV - Convert wide self-report body-map CSV into compact trial-level rows.
%
% Scope:
%   This parser restructures metadata and self-report entries only.
%   It does not compute comparison metrics.
%
% Expected input format (current dataset):
%   semicolon-separated CSV with repeated block structure per trial:
%   20x GEW + activation map + deactivation map + text
%
% Usage:
%   out = parseSelfReportBodyCSV('/path/Self-report-body.csv')
%   out = parseSelfReportBodyCSV(..., 'saveMatPath', '/tmp/selfReportCompact.mat')
%
% Name-value pairs:
%   'saveMatPath'          - optional .mat output path
%   'dropRowsWithoutID'    - default true
%   'keepWideTable'        - include source wide table in output (default false)
%   'includeBlockTypes'    - default {'stim'}; examples: {'stim','baseline','demo'}
%
% Output struct fields:
%   .meta
%   .trialTable            one row per subject x block (D1, D2, bl, G1..)
%   .blockCatalog          detected block definitions
%   .wideTable             optional original wide table

    p = inputParser;
    addRequired(p, 'csvPath', @(x) ischar(x) || isstring(x));
    addParameter(p, 'saveMatPath', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'dropRowsWithoutID', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'keepWideTable', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'includeBlockTypes', {'stim'}, @(x) iscell(x) || isstring(x) || ischar(x));
    parse(p, csvPath, varargin{:});

    csvPath = char(string(p.Results.csvPath));
    if ~isfile(csvPath)
        error('parseSelfReportBodyCSV:MissingFile', 'CSV not found: %s', csvPath);
    end

    opts = detectImportOptions(csvPath, 'Delimiter', ';');
    opts.VariableNamingRule = 'preserve';
    opts = setvartype(opts, 'char');
    T = readtable(csvPath, opts);

    rawVarNames = string(T.Properties.VariableNames);
    cleanVarNames = localCleanVarNames(rawVarNames);

    idCol = localFindColumnIndex(cleanVarNames, "ID");
    if isnan(idCol)
        error('parseSelfReportBodyCSV:MissingID', 'Could not find ID column.');
    end

    if p.Results.dropRowsWithoutID
        hasID = cellfun(@(x) ~isempty(strtrim(char(string(x)))), T{:, idCol});
        T = T(hasID, :);
    end

    blockCatalog = localBuildBlockCatalog(cleanVarNames);
    trialTable = localBuildTrialTable(T, cleanVarNames, idCol, blockCatalog);

    includeBlockTypes = lower(string(p.Results.includeBlockTypes));
    if isempty(includeBlockTypes)
        includeBlockTypes = "stim";
    end

    blockCatalog = blockCatalog(ismember(lower(blockCatalog.blockType), includeBlockTypes), :);
    trialTable = trialTable(ismember(lower(trialTable.blockType), includeBlockTypes), :);

    out = struct();
    out.meta = struct();
    out.meta.sourceCsvPath = csvPath;
    out.meta.nWideRows = height(T);
    out.meta.nBlocksDetected = height(blockCatalog);
    out.meta.nTrialRows = height(trialTable);
    out.meta.includedBlockTypes = cellstr(includeBlockTypes(:));
    out.meta.createdAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    out.blockCatalog = blockCatalog;
    out.trialTable = trialTable;

    if p.Results.keepWideTable
        out.wideTable = T;
    end

    saveMatPath = char(string(p.Results.saveMatPath));
    if ~isempty(saveMatPath)
        save(saveMatPath, 'out');
    end
end

function cleanNames = localCleanVarNames(rawNames)
    cleanNames = erase(rawNames, char(65279)); % BOM on first header cell
    cleanNames = regexprep(cleanNames, '^"|"$', '');
    cleanNames = string(strtrim(cleanNames));
end

function idx = localFindColumnIndex(cleanNames, targetName)
    idx = find(strcmpi(cleanNames, string(targetName)), 1, 'first');
    if isempty(idx)
        idx = NaN;
    end
end

function blockCatalog = localBuildBlockCatalog(cleanNames)
    % Detect GEW-bearing prefixes and map them to canonical block keys.
    prefixes = strings(0,1);
    firstIdx = zeros(0,1);

    for i = 1:numel(cleanNames)
        name = cleanNames(i);
        tok = regexp(char(name), '^(.*)\[GEW\d+\]$', 'tokens', 'once');
        if isempty(tok)
            continue;
        end
        rawPrefix = string(tok{1});
        if ~any(prefixes == rawPrefix)
            prefixes(end+1,1) = rawPrefix; %#ok<AGROW>
            firstIdx(end+1,1) = i; %#ok<AGROW>
        end
    end

    if isempty(prefixes)
        error('parseSelfReportBodyCSV:NoBlocks', 'No GEW block prefixes found in header.');
    end

    blockKey = strings(size(prefixes));
    blockType = strings(size(prefixes));
    actCol = zeros(size(prefixes));
    deactCol = zeros(size(prefixes));
    textCol = zeros(size(prefixes));

    for k = 1:numel(prefixes)
        [bk, btype] = localPrefixToBlockKey(prefixes(k));
        blockKey(k) = bk;
        blockType(k) = btype;

        % Current dataset conventions.
        actCandidates = [bk + "Q00002", bk + "demo2", bk + "2"];
        deactCandidates = [bk + "Q00003", bk + "demo3", bk + "3"];
        textCandidates = bk + "text";

        actCol(k) = localFindFirstIndex(cleanNames, actCandidates);
        deactCol(k) = localFindFirstIndex(cleanNames, deactCandidates);
        textCol(k) = localFindFirstIndex(cleanNames, textCandidates);
    end

    [~, order] = sort(firstIdx);
    blockCatalog = table( ...
        blockKey(order), prefixes(order), blockType(order), firstIdx(order), ...
        actCol(order), deactCol(order), textCol(order), ...
        'VariableNames', {'blockKey','rawGEWPrefix','blockType','firstHeaderIndex', ...
                          'actColumnIndex','deactColumnIndex','textColumnIndex'});

    % Keep one entry per canonical block key, preserving first appearance.
    [~, keep] = unique(blockCatalog.blockKey, 'stable');
    blockCatalog = blockCatalog(keep, :);

    % Add block order inside type.
    blockCatalog.blockOrder = zeros(height(blockCatalog),1);
    stimMask = blockCatalog.blockType == "stim";
    blockCatalog.blockOrder(stimMask) = localExtractStimNumber(blockCatalog.blockKey(stimMask));
    otherMask = ~stimMask;
    blockCatalog.blockOrder(otherMask) = 1:sum(otherMask);
end

function idx = localFindFirstIndex(cleanNames, candidates)
    idx = NaN;
    for c = 1:numel(candidates)
        hit = find(strcmpi(cleanNames, candidates(c)), 1, 'first');
        if ~isempty(hit)
            idx = hit;
            return;
        end
    end
end

function [blockKey, blockType] = localPrefixToBlockKey(rawPrefix)
    rp = string(rawPrefix);

    if endsWith(lower(rp), "demo1")
        blockKey = extractBefore(rp, strlength(rp) - strlength("demo1") + 1);
        blockType = "demo";
        return;
    end

    if endsWith(rp, "Q1")
        blockKey = regexprep(rp, 'Q1$', '');
        blockType = "stim";
        return;
    end

    if endsWith(lower(rp), "1")
        blockKey = extractBefore(rp, strlength(rp));
        if strcmpi(blockKey, "bl")
            blockType = "baseline";
        else
            blockType = "other";
        end
        return;
    end

    blockKey = rp;
    blockType = "other";
end

function nums = localExtractStimNumber(blockKeys)
    nums = nan(numel(blockKeys),1);
    for i = 1:numel(blockKeys)
        tok = regexp(char(blockKeys(i)), '^G(\d+)$', 'tokens', 'once');
        if ~isempty(tok)
            nums(i) = str2double(tok{1});
        end
    end
end

function trialTable = localBuildTrialTable(T, cleanNames, idCol, blockCatalog)
    nSubjects = height(T);
    nBlocks = height(blockCatalog);

    nOut = nSubjects * nBlocks;

    subjectIDRaw = strings(nOut,1);
    subjectID = strings(nOut,1);
    isValidSubjectID = false(nOut,1);
    blockKey = strings(nOut,1);
    blockType = strings(nOut,1);
    blockOrder = zeros(nOut,1);
    sourceRow = zeros(nOut,1);

    gew = nan(nOut, 20);
    bodyActRaw = strings(nOut,1);
    bodyDeactRaw = strings(nOut,1);
    textRaw = strings(nOut,1);

    hasBodyAct = false(nOut,1);
    hasBodyDeact = false(nOut,1);

    outRow = 1;
    for r = 1:nSubjects
        rawID = string(T{r, idCol});
        [normID, validID] = normalizeSubjectID(rawID);

        for b = 1:nBlocks
            bk = blockCatalog.blockKey(b);

            subjectIDRaw(outRow) = string(strtrim(char(rawID)));
            subjectID(outRow) = string(normID);
            isValidSubjectID(outRow) = validID;
            blockKey(outRow) = bk;
            blockType(outRow) = blockCatalog.blockType(b);
            blockOrder(outRow) = blockCatalog.blockOrder(b);
            sourceRow(outRow) = r;

            % GEW scores for this block.
            for g = 1:20
                colName = localResolveGEWColumnName(cleanNames, bk, g);
                colIdx = localFindColumnIndex(cleanNames, colName);
                if ~isnan(colIdx)
                    gew(outRow, g) = str2double(strtrim(char(string(T{r, colIdx}))));
                end
            end

            if ~isnan(blockCatalog.actColumnIndex(b))
                v = string(T{r, blockCatalog.actColumnIndex(b)});
                bodyActRaw(outRow) = v;
                hasBodyAct(outRow) = localHasBodyMapPayload(v);
            end

            if ~isnan(blockCatalog.deactColumnIndex(b))
                v = string(T{r, blockCatalog.deactColumnIndex(b)});
                bodyDeactRaw(outRow) = v;
                hasBodyDeact(outRow) = localHasBodyMapPayload(v);
            end

            if ~isnan(blockCatalog.textColumnIndex(b))
                textRaw(outRow) = string(T{r, blockCatalog.textColumnIndex(b)});
            end

            outRow = outRow + 1;
        end
    end

    trialTable = table(subjectIDRaw, subjectID, isValidSubjectID, sourceRow, ...
        blockKey, blockType, blockOrder, ...
        bodyActRaw, bodyDeactRaw, textRaw, hasBodyAct, hasBodyDeact, ...
        'VariableNames', {'subjectIDRaw','subjectID','isValidSubjectID','sourceWideRow', ...
                          'blockKey','blockType','blockOrder', ...
                          'bodyActRaw','bodyDeactRaw','textRaw','hasBodyAct','hasBodyDeact'});

    for g = 1:20
        vname = sprintf('gew%02d', g);
        trialTable.(vname) = gew(:, g);
    end

    % Convenience quality flags.
    trialTable.hasAnyGEW = any(~isnan(gew), 2);
    trialTable.hasAnyBodyMap = trialTable.hasBodyAct | trialTable.hasBodyDeact;
end

function colName = localResolveGEWColumnName(cleanNames, blockKey, gewIdx)
    candidateA = sprintf('%sQ1[GEW%02d]', char(blockKey), gewIdx);
    candidateB = sprintf('%sdemo1[GEW%02d]', char(blockKey), gewIdx);
    candidateC = sprintf('%s1[GEW%02d]', char(blockKey), gewIdx);

    if any(strcmpi(cleanNames, string(candidateA)))
        colName = string(candidateA);
        return;
    end
    if any(strcmpi(cleanNames, string(candidateB)))
        colName = string(candidateB);
        return;
    end
    colName = string(candidateC);
end

function tf = localHasBodyMapPayload(v)
    s = strtrim(char(string(v)));
    s = regexprep(s, '^"|"$', '');
    if isempty(s)
        tf = false;
        return;
    end
    if strcmp(s, '[]')
        tf = false;
        return;
    end
    tf = startsWith(s, '[');
end
