function figHandle = plotSubjectSessionTimeline(timelineTable, varargin)
% plotSubjectSessionTimeline - Plot session structure for one or many subjects.
%
% Purpose:
%   Visualize BASELINE/STIM segments and inter-segment GAP rows to inspect
%   subject-level waiting time and ordering.
%
% Inputs:
%   timelineTable - output table from buildSubjectSessionTimeline.
%                   Can contain one or many subjects.
%
% Name-value pairs:
%   'figureTitle'      - custom title (default auto)
%   'showVideoLabels'  - draw video IDs above segment blocks (default false)
%   'showGapBlocks'    - draw explicit GAP rectangles (default false)
%   'showTimeAxis'     - show x ticks/label (default false)
%   'showLegend'       - show legend (default true)
%   'stimVideoEncoding' - optional stim encoding table/cell/csv path.
%                         If provided, colors are assigned by group.
%                         If empty, colors are assigned by videoID.
%
% Output:
%   figHandle - MATLAB figure handle

    p = inputParser;
    addRequired(p, 'timelineTable', @istable);
    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'showVideoLabels', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'showGapBlocks', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'showTimeAxis', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'showLegend', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'stimVideoEncoding', [], @(x) isempty(x) || istable(x) || iscell(x) || ischar(x) || isstring(x));
    parse(p, timelineTable, varargin{:});

    needed = {'subjectID','rowType','segmentType','videoID','startSec','endSec','durationSec'};
    for i = 1:numel(needed)
        if ~ismember(needed{i}, timelineTable.Properties.VariableNames)
            error('plotSubjectSessionTimeline:MissingColumn', ...
                'timelineTable missing required column "%s".', needed{i});
        end
    end

    if isempty(timelineTable)
        error('plotSubjectSessionTimeline:EmptyInput', 'timelineTable is empty.');
    end

    T = sortrows(timelineTable, {'subjectID','startSec','endSec'});
    subjIDs = string(T.subjectID);
    uniqSubj = unique(subjIDs, 'stable');
    nSubj = numel(uniqSubj);
    subjPos = containers.Map('KeyType','char', 'ValueType','double');
    for s = 1:nSubj
        % Top row is first subject.
        subjPos(char(uniqSubj(s))) = nSubj - s + 1;
    end
    colorSpec = localBuildColorSpec(T, p.Results.stimVideoEncoding);

    figHandle = figure('Color', 'w');
    ax = axes(figHandle);
    hold(ax, 'on');

    barHeight = 0.65;

    for i = 1:height(T)
        x1 = T.startSec(i);
        x2 = T.endSec(i);
        w = x2 - x1;
        if ~isfinite(w) || w <= 0
            continue;
        end

        thisRowType = upper(strtrim(char(string(T.rowType(i)))));
        if strcmp(thisRowType, 'GAP') && ~p.Results.showGapBlocks
            continue;
        end

        yCenter = subjPos(char(string(T.subjectID(i))));
        [c, key] = localResolveColorAndKey(T.segmentType(i), T.rowType(i), T.videoID(i), colorSpec);
        edgeColor = [0.3 0.3 0.3];
        if strcmpi(key, 'X')
            edgeColor = [0 0 0];
        end
        rectangle(ax, 'Position', [x1, yCenter - barHeight/2, w, barHeight], ...
            'FaceColor', c, 'EdgeColor', edgeColor, 'LineWidth', 0.8);

        if p.Results.showVideoLabels && strcmp(thisRowType, 'SEGMENT')
            label = char(string(T.videoID(i)));
            if ~isempty(label)
                text(ax, x1 + w/2, yCenter + (barHeight/2) + 0.1, label, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'bottom', ...
                    'FontSize', 6, ...
                    'Interpreter', 'none');
            end
        end
    end

    xMin = min(T.startSec, [], 'omitnan');
    xMax = max(T.endSec, [], 'omitnan');
    if ~isfinite(xMin) || ~isfinite(xMax)
        xMin = 0;
        xMax = 1;
    end
    if xMin == xMax
        xMax = xMax + 1;
    end

    xlim(ax, [xMin, xMax]);
    ylim(ax, [0.5, nSubj + 0.7]);
    yticks(ax, 1:nSubj);
    yticklabels(ax, cellstr(flipud(uniqSubj(:))));
    ylabel(ax, 'Subject ID');
    if p.Results.showTimeAxis
        xlabel(ax, 'Seconds from mocap start');
        grid(ax, 'on');
    else
        set(ax, 'XTick', []);
        grid(ax, 'off');
    end

    ttl = char(string(p.Results.figureTitle));
    if isempty(strtrim(ttl))
        if nSubj == 1
            ttl = sprintf('Session Structure | %s', char(uniqSubj(1)));
        else
            ttl = 'Session Structure Across Subjects';
        end
    end
    title(ax, ttl, 'Interpreter', 'none');

    if p.Results.showLegend
        localAddLegend(ax, colorSpec, p.Results.showGapBlocks);
    end
    hold(ax, 'off');
end

function [c, key] = localResolveColorAndKey(segmentType, rowType, videoID, colorSpec)
    st = upper(strtrim(char(string(segmentType))));
    rt = upper(strtrim(char(string(rowType))));

    if strcmp(rt, 'GAP') || strcmp(st, 'GAP')
        c = [0.92 0.92 0.92];
        key = 'GAP';
        return;
    end

    if strcmp(st, 'BASELINE')
        c = [0.50 0.50 0.50];
        key = 'BASELINE';
        return;
    end

    vid = localNormalizeVideoID(videoID);
    if strcmp(colorSpec.mode, 'group')
        if isKey(colorSpec.videoToGroup, vid)
            key = colorSpec.videoToGroup(vid);
        else
            key = 'UNMAPPED';
        end
    else
        key = vid;
    end

    if isKey(colorSpec.keyToColor, key)
        c = colorSpec.keyToColor(key);
    else
        c = [0.70 0.70 0.70];
    end
end

function localAddLegend(ax, colorSpec, includeGap)
    hold(ax, 'on');
    handles = gobjects(0);
    labels = {};

    hBase = patch(ax, NaN, NaN, [0.50 0.50 0.50], 'EdgeColor', 'none');
    handles(end+1) = hBase; %#ok<AGROW>
    labels{end+1} = 'BASELINE'; %#ok<AGROW>

    for i = 1:numel(colorSpec.legendKeys)
        key = colorSpec.legendKeys{i};
        h = patch(ax, NaN, NaN, colorSpec.keyToColor(key), 'EdgeColor', 'none');
        handles(end+1) = h; %#ok<AGROW>
        labels{end+1} = key; %#ok<AGROW>
    end

    if includeGap
        hGap = patch(ax, NaN, NaN, [0.92 0.92 0.92], 'EdgeColor', 'none');
        handles(end+1) = hGap; %#ok<AGROW>
        labels{end+1} = 'GAP'; %#ok<AGROW>
    end

    legend(ax, handles, labels, 'Location', 'eastoutside');
    hold(ax, 'off');
end

function colorSpec = localBuildColorSpec(T, stimVideoEncoding)
    colorSpec = struct();
    colorSpec.mode = 'video';
    colorSpec.videoToGroup = containers.Map('KeyType', 'char', 'ValueType', 'char');
    colorSpec.keyToColor = containers.Map('KeyType', 'char', 'ValueType', 'any');
    colorSpec.legendKeys = {};

    if isempty(stimVideoEncoding)
        [keys, cmap] = localUniqueVideoKeys(T);
        colorSpec.mode = 'video';
    else
        [videoToGroup, groupKeys] = localBuildVideoToGroupMap(stimVideoEncoding);
        colorSpec.mode = 'group';
        colorSpec.videoToGroup = videoToGroup;
        keys = groupKeys;
    end

    % Reserve gray for baseline; assign colors to keys for STIM blocks.
    if isempty(keys)
        keys = {'UNMAPPED'};
    end
    cmap = lines(numel(keys));
    for i = 1:numel(keys)
        colorSpec.keyToColor(keys{i}) = cmap(i, :);
    end
    % Convention: unresolved group X is drawn as white.
    if isKey(colorSpec.keyToColor, 'X')
        colorSpec.keyToColor('X') = [1 1 1];
    end
    colorSpec.legendKeys = keys;
end

function [keys, cmap] = localUniqueVideoKeys(T)
    isStimSeg = strcmpi(string(T.rowType), "segment") & strcmpi(string(T.segmentType), "STIM");
    vids = string(T.videoID(isStimSeg));
    vids = upper(strtrim(vids));
    vids = vids(strlength(vids) > 0);
    keys = cellstr(unique(vids, 'stable'));
    cmap = lines(max(1, numel(keys)));
end

function [videoToGroup, groupKeys] = localBuildVideoToGroupMap(stimVideoEncoding)
    videoToGroup = containers.Map('KeyType', 'char', 'ValueType', 'char');
    groupKeys = {};

    Tenc = localLoadStimEncoding(stimVideoEncoding);
    if isempty(Tenc)
        groupKeys = {'UNMAPPED'};
        return;
    end

    vids = string(Tenc.videoID);
    vids = upper(strtrim(vids));
    vids = localPadNumericVideoIDs(vids);

    if ismember('groupCode', Tenc.Properties.VariableNames)
        grp = string(Tenc.groupCode);
    elseif ismember('emotionTag', Tenc.Properties.VariableNames)
        grp = string(Tenc.emotionTag);
    else
        grp = string(Tenc{:, 2});
    end
    grp = upper(strtrim(grp));
    grp(grp == "") = "UNMAPPED";

    for i = 1:height(Tenc)
        v = char(vids(i));
        g = char(grp(i));
        if strcmp(v, 'BASELINE')
            continue;
        end
        if ~isKey(videoToGroup, v)
            videoToGroup(v) = g;
        end
    end

    groupKeys = unique(values(videoToGroup), 'stable');
    if isempty(groupKeys)
        groupKeys = {'UNMAPPED'};
    end
end

function Tenc = localLoadStimEncoding(stimVideoEncoding)
    if istable(stimVideoEncoding)
        Tenc = stimVideoEncoding;
        return;
    end
    if iscell(stimVideoEncoding)
        if size(stimVideoEncoding, 2) < 2
            Tenc = table();
            return;
        end
        Tenc = table(string(stimVideoEncoding(:,1)), string(stimVideoEncoding(:,2)), ...
            'VariableNames', {'videoID','groupCode'});
        return;
    end

    path = char(string(stimVideoEncoding));
    if isempty(path) || ~isfile(path)
        Tenc = table();
        return;
    end
    opts = detectImportOptions(path, 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, 'string');
    Tenc = readtable(path, opts);
end

function v = localNormalizeVideoID(videoID)
    v = upper(strtrim(char(string(videoID))));
    if isempty(v)
        v = 'UNMAPPED';
        return;
    end
    if strcmp(v, 'BASELINE') || contains(lower(v), 'baseline')
        v = 'BASELINE';
        return;
    end
    if ~isempty(regexp(v, '^\d+$', 'once'))
        v = sprintf('%04d', str2double(v));
    end
end

function vids = localPadNumericVideoIDs(vids)
    vids = string(vids);
    for i = 1:numel(vids)
        v = vids(i);
        if v == "BASELINE" || contains(lower(v), "baseline")
            vids(i) = "BASELINE";
            continue;
        end
        if ~isempty(regexp(char(v), '^\d+$', 'once'))
            vids(i) = compose('%04d', str2double(v));
        end
    end
end
