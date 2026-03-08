function encodingTbl = createStimEncodingTemplateFromManifest(manifestInput, varargin)
% createStimEncodingTemplateFromManifest Build a starter stim-encoding table.
%
% Purpose:
%   Create an editable CSV/table for stimulus video coding from Unity files
%   listed in a manifest (`master_file_list_preview.csv`).
%
% Usage:
%   T = createStimEncodingTemplateFromManifest('/path/master_file_list_preview.csv')
%   T = createStimEncodingTemplateFromManifest(tbl, 'outCsv', '/tmp/stim_encoding_template.csv')
%
% Output columns:
%   videoID, emotionTag, emotionCategory, valenceLabel, arousalLabel,
%   isBaseline, include, notes

    p = inputParser;
    addRequired(p, 'manifestInput', @(x) istable(x) || ischar(x) || isstring(x));
    addParameter(p, 'outCsv', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'includeBaseline', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'includeDemo', false, @(x) islogical(x) && isscalar(x));
    parse(p, manifestInput, varargin{:});

    manifestTbl = localLoadManifest(p.Results.manifestInput);
    needed = {'modality', 'sourcePath', 'assignedSubject'};
    if ~all(ismember(needed, manifestTbl.Properties.VariableNames))
        error('createStimEncodingTemplateFromManifest:BadManifest', ...
            'Manifest must contain columns: modality, sourcePath, assignedSubject');
    end

    modCol = lower(string(manifestTbl.modality));
    subjCol = upper(string(manifestTbl.assignedSubject));
    srcCol = string(manifestTbl.sourcePath);

    isUnity = (modCol == "unity" | modCol == "unitylogs");
    isKnownSubj = subjCol ~= "UNKNOWN" & subjCol ~= "SHARED" & strlength(subjCol) > 0;
    rows = find(isUnity & isKnownSubj);

    videoIDs = strings(0, 1);
    for i = 1:numel(rows)
        v = localVideoIDFromUnityPath(char(srcCol(rows(i))));
        if strlength(v) == 0
            continue;
        end
        if ~p.Results.includeDemo && localIsDemoVideoID(v)
            continue;
        end
        if ~p.Results.includeBaseline && strcmpi(v, 'BASELINE')
            continue;
        end
        videoIDs(end+1, 1) = string(v); %#ok<AGROW>
    end

    if isempty(videoIDs)
        warning('createStimEncodingTemplateFromManifest:NoVideoIDs', ...
            'No video IDs found from Unity rows in manifest.');
        encodingTbl = table();
        return;
    end

    [~, ia] = unique(lower(videoIDs), 'stable');
    videoIDs = videoIDs(sort(ia));

    isBaseline = strcmpi(videoIDs, 'BASELINE');
    baselineIDs = videoIDs(isBaseline);
    otherIDs = sort(videoIDs(~isBaseline));
    videoIDsOrdered = [baselineIDs; otherIDs];
    isBaselineOrdered = strcmpi(videoIDsOrdered, 'BASELINE');

    n = numel(videoIDsOrdered);
    emotionTag = repmat("", n, 1);
    emotionCategory = repmat("", n, 1);
    valenceLabel = repmat("", n, 1);
    arousalLabel = repmat("", n, 1);
    notes = repmat("", n, 1);
    include = true(n, 1);

    emotionTag(isBaselineOrdered) = "BASELINE";
    notes(isBaselineOrdered) = "No self-report expected for baseline";

    encodingTbl = table(videoIDsOrdered, emotionTag, emotionCategory, ...
        valenceLabel, arousalLabel, isBaselineOrdered, include, notes, ...
        'VariableNames', {'videoID', 'emotionTag', 'emotionCategory', ...
        'valenceLabel', 'arousalLabel', 'isBaseline', 'include', 'notes'});

    outCsv = char(string(p.Results.outCsv));
    if ~isempty(outCsv)
        outDir = fileparts(outCsv);
        if ~isempty(outDir) && ~exist(outDir, 'dir')
            mkdir(outDir);
        end
        writetable(encodingTbl, outCsv);
    end
end

function T = localLoadManifest(manifestInput)
    if istable(manifestInput)
        T = manifestInput;
        return;
    end
    manifestPath = char(string(manifestInput));
    if ~isfile(manifestPath)
        error('createStimEncodingTemplateFromManifest:ManifestMissing', ...
            'Manifest file not found: %s', manifestPath);
    end
    opts = detectImportOptions(manifestPath);
    opts = setvartype(opts, 'char');
    T = readtable(manifestPath, opts);
end

function videoID = localVideoIDFromUnityPath(unityPath)
    [~, baseName] = fileparts(unityPath);
    if contains(lower(baseName), 'baseline')
        videoID = 'BASELINE';
        return;
    end
    tok = regexp(baseName, '_(\w+)$', 'tokens', 'once');
    if isempty(tok)
        videoID = '';
    else
        videoID = tok{1};
    end
end

function tf = localIsDemoVideoID(videoID)
    v = lower(char(string(videoID)));
    tf = contains(v, 'demo') || ~isempty(regexp(v, '^d\d', 'once'));
end
