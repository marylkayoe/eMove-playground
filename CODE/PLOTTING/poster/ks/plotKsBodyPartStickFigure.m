function R = plotKsBodyPartStickFigure(ksTbl, emotionPair, varargin)
% plotKsBodyPartStickFigure - Visualize KS discriminability by body part on a stick figure.
%
% Usage:
%   plotKsBodyPartStickFigure(ksTbl, {'FEAR','JOY'})
%   plotKsBodyPartStickFigure(ksTbl, {'FEAR','JOY'}, 'annotateDelta', true)
%
% Inputs:
%   ksTbl       - table with columns including subjectID, markerGroup, emotionA, emotionB, ksD
%   emotionPair - 1x2 cell/string pair, e.g. {'FEAR','JOY'} (order-insensitive)
%
% Name-value pairs:
%   'aggFcn'         - 'median' (default) or 'mean'
%   'minSubjects'    - minimum subjects per markerGroup (default 1)
%   'valueField'     - field to color by (default 'ksD')
%   'annotateDelta'  - annotate deltaMedian_sorted if present (default false)
%   'annotateField'  - annotation field (default 'deltaMedian_sorted')
%   'showColorbar'   - logical (default true)
%   'showValues'     - show D values in body-part labels (default true)
%   'titleText'      - custom title
%   'plotWhere'      - axes handle (default new figure)
%   'cLim'           - 1x2 color limits (default auto from values)
%   'colormapName'   - colormap function/name (default 'turbo')
%
% Output:
%   R struct with fields: figure, axes, summaryTable, handles

    p = inputParser;
    addRequired(p, 'ksTbl', @istable);
    addRequired(p, 'emotionPair', @(x) iscell(x) || isstring(x));
    addParameter(p, 'aggFcn', 'median', @(x) ischar(x) || isstring(x));
    addParameter(p, 'minSubjects', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'valueField', 'ksD', @(x) ischar(x) || isstring(x));
    addParameter(p, 'annotateDelta', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'annotateField', 'deltaMedian_sorted', @(x) ischar(x) || isstring(x));
    addParameter(p, 'showColorbar', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'showValues', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'showGroupLabels', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'titleText', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'plotWhere', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'cLim', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    addParameter(p, 'colormapName', 'turbo');
    parse(p, ksTbl, emotionPair, varargin{:});

    pair = cellstr(string(emotionPair));
    if numel(pair) ~= 2
        error('plotKsBodyPartStickFigure:BadEmotionPair', 'emotionPair must have exactly 2 labels.');
    end
    pair = sort(string(pair(:)));
    pairLabel = char(pair(1) + "-" + pair(2));

    S = localAggregatePair(ksTbl, pairLabel, ...
        char(string(p.Results.valueField)), char(string(p.Results.aggFcn)), p.Results.minSubjects, ...
        p.Results.annotateDelta, char(string(p.Results.annotateField)));

    ax = p.Results.plotWhere;
    if isempty(ax)
        fig = figure('Color', 'w');
        ax = axes('Parent', fig);
    else
        fig = ancestor(ax, 'figure');
    end
    cla(ax);
    hold(ax, 'on');
    axis(ax, 'equal');
    axis(ax, 'off');

    [segments, markerNodes] = localStickLayout();
    [cmap, cfun] = localResolveColormap(p.Results.colormapName);

    vals = S.value;
    finiteVals = vals(isfinite(vals));
    if isempty(p.Results.cLim)
        if isempty(finiteVals)
            cLim = [0 1];
        elseif numel(unique(finiteVals)) == 1
            v = finiteVals(1);
            cLim = [max(0, v-0.05), v+0.05];
        else
            cLim = [min(finiteVals), max(finiteVals)];
        end
    else
        cLim = p.Results.cLim(:)';
    end

    hSeg = gobjects(0);
    hText = gobjects(0);
    hNode = gobjects(0);

    % Draw low-emphasis skeleton base.
    for i = 1:size(segments, 1)
        a = segments{i,1}; b = segments{i,2};
        p1 = markerNodes.(a); p2 = markerNodes.(b);
        hSeg(end+1,1) = plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', ... %#ok<AGROW>
            'Color', [0.85 0.85 0.85], 'LineWidth', 8, 'HandleVisibility', 'off');
    end

    % Overlay grouped body-part highlights.
    def = localBodyPartGlyphs();
    hGroup = gobjects(height(def), 1);
    for i = 1:height(def)
        grp = def.markerGroup{i};
        idx = find(strcmp(S.markerGroup, grp), 1, 'first');
        if isempty(idx) || ~isfinite(S.value(idx))
            color = [0.15 0.15 0.15];
            alpha = 0.18;
            lw = def.lineWidth(i);
        else
            color = cfun(S.value(idx), cLim, cmap);
            alpha = 1.0;
            lw = def.lineWidth(i);
        end
        drawColor = localBlendWithWhite(color, alpha);

        switch def.glyphType{i}
            case 'segment'
                p1 = markerNodes.(def.nodeA{i});
                p2 = markerNodes.(def.nodeB{i});
                hGroup(i) = plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', ...
                    'Color', drawColor, 'LineWidth', lw, 'DisplayName', grp);
            case 'polyline'
                pts = localPolylinePoints(markerNodes, def.nodeList{i});
                hGroup(i) = plot(ax, pts(:,1), pts(:,2), '-', ...
                    'Color', drawColor, 'LineWidth', lw, 'DisplayName', grp);
            case 'circle'
                ctr = markerNodes.(def.nodeA{i});
                r = def.radius(i);
                hGroup(i) = rectangle(ax, 'Position', [ctr(1)-r, ctr(2)-r, 2*r, 2*r], ...
                    'Curvature', [1 1], 'EdgeColor', drawColor, 'LineWidth', lw, ...
                    'FaceColor', localBlendWithWhite(color, 0.92));
            otherwise
                error('Unknown glyphType: %s', def.glyphType{i});
        end

        % labels / value annotations near body part
        pTxt = [def.labelX(i), def.labelY(i)];
        labelLines = {};
        if p.Results.showGroupLabels
            labelLines{end+1} = def.displayLabel{i}; %#ok<AGROW>
        end
        if p.Results.showValues && ~isempty(idx) && isfinite(S.value(idx))
            valStr = sprintf('D=%.2f', S.value(idx));
            if p.Results.annotateDelta
                if isfinite(S.annotation(idx))
                    valStr = sprintf('%s\n%+.2f', valStr, S.annotation(idx));
                else
                    valStr = sprintf('%s\n--', valStr);
                end
            end
            labelLines{end+1} = valStr; %#ok<AGROW>
        end
        if ~isempty(labelLines)
            hText(end+1,1) = text(ax, pTxt(1), pTxt(2), strjoin(labelLines, newline), ... %#ok<AGROW>
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 9, 'Color', [0.1 0.1 0.1], 'Interpreter', 'none');
        end
    end

    % Body joints for readability.
    nodeNames = fieldnames(markerNodes);
    XY = zeros(numel(nodeNames), 2);
    for i = 1:numel(nodeNames)
        XY(i,:) = markerNodes.(nodeNames{i});
    end
    hNode = plot(ax, XY(:,1), XY(:,2), 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 4);
    uistack(hNode, 'top');

    xlim(ax, [-1.3 1.3]);
    ylim(ax, [-2.2 1.5]);

    titleText = char(string(p.Results.titleText));
    if isempty(strtrim(titleText))
        titleText = sprintf('Body-part discriminability | %s', pairLabel);
    end
    title(ax, titleText, 'Interpreter', 'none', 'FontWeight', 'bold', 'FontSize', 13);

    if p.Results.showColorbar
        colormap(ax, cmap);
        caxis(ax, cLim);
        cb = colorbar(ax);
        cb.Label.String = char(string(p.Results.valueField));
        cb.FontSize = 10;
    else
        cb = [];
    end

    R = struct();
    R.figure = fig;
    R.axes = ax;
    R.summaryTable = S;
    R.handles = struct('group', hGroup, 'labels', hText, 'nodes', hNode, 'colorbar', cb);
    R.pairLabel = pairLabel;
end

function S = localAggregatePair(ksTbl, pairLabel, valueField, aggFcnName, minSubjects, doAnnotate, annotateField)
    needed = {'subjectID','markerGroup','emotionA','emotionB',valueField};
    for i = 1:numel(needed)
        if ~ismember(needed{i}, ksTbl.Properties.VariableNames)
            error('plotKsBodyPartStickFigure:MissingVar', 'ksTbl missing "%s".', needed{i});
        end
    end

    emoA = string(ksTbl.emotionA);
    emoB = string(ksTbl.emotionB);
    pr = sort([emoA emoB], 2);
    labels = pr(:,1) + "-" + pr(:,2);
    T = ksTbl(labels == string(pairLabel), :);
    if isempty(T)
        error('plotKsBodyPartStickFigure:PairNotFound', 'No rows for pair %s.', pairLabel);
    end

    switch lower(aggFcnName)
        case 'median'
            agg = @(x) median(x, 'omitnan');
        case 'mean'
            agg = @(x) mean(x, 'omitnan');
        otherwise
            error('plotKsBodyPartStickFigure:BadAgg', 'aggFcn must be median or mean.');
    end

    allGroups = localCanonicalBodyPartGroups();
    n = numel(allGroups);
    value = nan(n,1);
    nSubjects = zeros(n,1);
    annotation = nan(n,1);

    T.markerGroup = cellstr(localNormalizeMarkerGroupNames(T.markerGroup));

    hasAnnot = doAnnotate && ismember(annotateField, T.Properties.VariableNames);
    for i = 1:n
        g = allGroups{i};
        Tg = T(strcmp(T.markerGroup, g), :);
        if isempty(Tg), continue; end
        subj = unique(Tg.subjectID, 'stable');
        subjVals = nan(numel(subj),1);
        subjAnn = nan(numel(subj),1);
        for s = 1:numel(subj)
            m = strcmp(Tg.subjectID, subj{s});
            subjVals(s) = agg(Tg.(valueField)(m));
            if hasAnnot
                subjAnn(s) = agg(Tg.(annotateField)(m));
            end
        end
        nSubjects(i) = sum(~isnan(subjVals));
        if nSubjects(i) >= minSubjects
            value(i) = agg(subjVals);
            if hasAnnot
                annotation(i) = agg(subjAnn);
            end
        end
    end

    S = table(allGroups(:), value, nSubjects, annotation, ...
        'VariableNames', {'markerGroup','value','nSubjects','annotation'});
end

function groups = localCanonicalBodyPartGroups()
    groups = {'HEAD','UTORSO','LTORSO','UPPER_LIMB_L','UPPER_LIMB_R', ...
        'WRIST_L','WRIST_R','LOWER_LIMB_L','LOWER_LIMB_R'};
end

function [segments, nodes] = localStickLayout()
    % 2D schematic coordinates in arbitrary units
    nodes = struct();
    nodes.headTop = [0, 1.10];
    nodes.neck = [0, 0.65];
    nodes.shoulderL = [-0.55, 0.55];
    nodes.shoulderR = [0.55, 0.55];
    nodes.elbowL = [-0.85, 0.10];
    nodes.elbowR = [0.85, 0.10];
    nodes.wristL = [-1.02, -0.35];
    nodes.wristR = [1.02, -0.35];
    nodes.chest = [0, 0.20];
    nodes.waist = [0, -0.35];
    nodes.hipL = [-0.30, -0.45];
    nodes.hipR = [0.30, -0.45];
    nodes.kneeL = [-0.42, -1.10];
    nodes.kneeR = [0.42, -1.10];
    nodes.ankleL = [-0.48, -1.85];
    nodes.ankleR = [0.48, -1.85];

    segments = {
        'headTop','neck';
        'shoulderL','neck';
        'shoulderR','neck';
        'neck','chest';
        'chest','waist';
        'shoulderL','elbowL';
        'elbowL','wristL';
        'shoulderR','elbowR';
        'elbowR','wristR';
        'waist','hipL';
        'waist','hipR';
        'hipL','kneeL';
        'kneeL','ankleL';
        'hipR','kneeR';
        'kneeR','ankleR'};
end

function def = localBodyPartGlyphs()
    def = table();
    def.markerGroup = { ...
        'HEAD'; 'UTORSO'; 'LTORSO'; 'UPPER_LIMB_L'; 'UPPER_LIMB_R'; ...
        'WRIST_L'; 'WRIST_R'; 'LOWER_LIMB_L'; 'LOWER_LIMB_R'};
    def.displayLabel = { ...
        'head'; 'upper torso'; 'waist'; 'L-arm'; 'R-arm'; ...
        'L-wrist'; 'R-wrist'; 'L-leg'; 'R-leg'};
    def.glyphType = { ...
        'circle'; 'polyline'; 'segment'; 'polyline'; 'polyline'; 'circle'; 'circle'; 'polyline'; 'polyline'};
    def.nodeA = { ...
        'headTop'; ''; 'hipL'; ''; ''; 'wristL'; 'wristR'; ''; ''};
    def.nodeB = { ...
        ''; ''; 'hipR'; ''; ''; ''; ''; ''; ''};
    def.nodeList = { ...
        {}; {'shoulderL','neck','shoulderR','chest','waist'}; {}; ...
        {'shoulderL','elbowL','wristL'}; {'shoulderR','elbowR','wristR'}; ...
        {}; {}; ...
        {'hipL','kneeL','ankleL'}; {'hipR','kneeR','ankleR'}};
    def.lineWidth = [4; 6; 6; 5; 5; 6; 6; 5; 5];
    def.radius = [0.28; 0; 0; 0; 0; 0.12; 0.12; 0; 0];
    def.labelX = [0; 0; 0; -1.18; 1.18; -1.15; 1.15; -0.85; 0.85];
    def.labelY = [1.05; 0.10; -0.62; 0.05; 0.05; -0.52; -0.52; -1.45; -1.45];
end

function out = localNormalizeMarkerGroupNames(in)
    s = upper(strtrim(string(in)));
    s = replace(s, "-", "_");
    s = replace(s, " ", "_");

    out = s;
    out(startsWith(s, "HEAD")) = "HEAD";
    out(ismember(s, ["UPPERTORSO","UPPER_TORSO","UTORSO","TORSO_U","UPPER_TORSO_CENTER"])) = "UTORSO";
    out(ismember(s, ["WAIST","LTORSO","LOWERTORSO","LOWER_TORSO","TORSO_L"])) = "LTORSO";

    out(ismember(s, ["L_ARM","LEFT_ARM","UPPER_LIMB_L","UPPERLIMB_L"])) = "UPPER_LIMB_L";
    out(ismember(s, ["R_ARM","RIGHT_ARM","UPPER_LIMB_R","UPPERLIMB_R"])) = "UPPER_LIMB_R";

    out(ismember(s, ["L_WRIST","WRIST_L","LEFT_WRIST"])) = "WRIST_L";
    out(ismember(s, ["R_WRIST","WRIST_R","RIGHT_WRIST"])) = "WRIST_R";

    out(ismember(s, ["L_LEG","LEFT_LEG","LOWER_LIMB_L","LOWERLIMB_L"])) = "LOWER_LIMB_L";
    out(ismember(s, ["R_LEG","RIGHT_LEG","LOWER_LIMB_R","LOWERLIMB_R"])) = "LOWER_LIMB_R";
end

function pts = localPolylinePoints(nodes, nodeList)
    pts = nan(numel(nodeList), 2);
    for i = 1:numel(nodeList)
        pts(i,:) = nodes.(nodeList{i});
    end
end

function [cmap, cfun] = localResolveColormap(cmapIn)
    if ischar(cmapIn) || isstring(cmapIn)
        name = char(string(cmapIn));
        switch lower(name)
            case 'turbo'
                cmap = turbo(256);
            case 'parula'
                cmap = parula(256);
            case 'hot'
                cmap = hot(256);
            otherwise
                cmap = parula(256);
        end
    elseif isnumeric(cmapIn) && size(cmapIn,2) == 3
        cmap = cmapIn;
    else
        cmap = parula(256);
    end
    cfun = @localMapColor;
end

function c = localMapColor(v, cLim, cmap)
    if ~isfinite(v)
        c = [0.7 0.7 0.7];
        return;
    end
    if cLim(2) <= cLim(1)
        idx = round(size(cmap,1)/2);
    else
        t = (v - cLim(1)) / (cLim(2) - cLim(1));
        t = min(max(t, 0), 1);
        idx = 1 + round(t * (size(cmap,1)-1));
    end
    c = cmap(idx, :);
end

function c = localBlendWithWhite(color, alpha)
    alpha = min(max(alpha, 0), 1);
    c = alpha .* color + (1-alpha) .* [1 1 1];
end
