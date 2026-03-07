function [figHandle, mapStack, meta] = plotSelfReportBodyMapsByVideo(selfReportInput, subjectID, varargin)
% plotSelfReportBodyMapsByVideo - Visualize self-report body maps, one panel per stimulus video.
%
% Scope:
%   Visualization utility only. No motion/physiology metrics are computed.
%
% Inputs:
%   selfReportInput - either:
%       1) table from parseSelfReportBodyCSV(...).trialTable
%       2) struct output from parseSelfReportBodyCSV(...)
%   subjectID       - subject ID (case-insensitive). If empty and only one
%                     subject exists in input, that subject is used.
%
% Name-value pairs:
%   'mapMode'       - 'signed' (default), 'activation', or 'deactivation'
%   'gridSize'      - [nRows nCols] raster size (default [520 170])
%   'smoothSigma'   - Gaussian smoothing sigma in pixels (default 2)
%   'colorLimits'   - [] auto, or [min max]
%   'showColorbar'  - true/false (default true)
%   'figureTitle'   - custom title (default auto)
%   'maxPanels'     - max number of panels to draw (default Inf)
%
% Outputs:
%   figHandle - figure handle
%   mapStack  - nRows x nCols x nTrials numeric map cube
%   meta      - struct with trial keys and plotting metadata
%
% Example:
%   sr = parseSelfReportBodyCSV('/path/Self-report-body.csv', 'includeBlockTypes', {'stim'});
%   plotSelfReportBodyMapsByVideo(sr, 'ij1701', 'mapMode', 'signed');

    if nargin < 2
        subjectID = '';
    end

    p = inputParser;
    addRequired(p, 'selfReportInput');
    addOptional(p, 'subjectID', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'mapMode', 'signed', @(x) any(strcmpi(string(x), ["signed","activation","deactivation"])));
    addParameter(p, 'gridSize', [520 170], @(x) isnumeric(x) && numel(x) == 2 && all(x > 0));
    addParameter(p, 'smoothSigma', 2, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'colorLimits', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    addParameter(p, 'showColorbar', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'figureTitle', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'maxPanels', Inf, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    parse(p, selfReportInput, subjectID, varargin{:});

    trialTable = localResolveTrialTable(selfReportInput);
    if isempty(trialTable) || ~istable(trialTable)
        error('plotSelfReportBodyMapsByVideo:BadInput', 'Could not resolve trialTable from selfReportInput.');
    end

    needed = {'subjectID','blockKey','blockType','blockOrder','bodyActRaw','bodyDeactRaw'};
    for i = 1:numel(needed)
        if ~ismember(needed{i}, trialTable.Properties.VariableNames)
            error('plotSelfReportBodyMapsByVideo:MissingColumn', 'trialTable is missing column "%s".', needed{i});
        end
    end

    % Keep stimulus rows only for this visualization.
    isStim = strcmpi(string(trialTable.blockType), "stim");
    T = trialTable(isStim, :);

    if isempty(T)
        error('plotSelfReportBodyMapsByVideo:NoStimRows', 'No stimulus rows (blockType=stim) found.');
    end

    requestedID = char(string(p.Results.subjectID));
    requestedID = strtrim(requestedID);

    subjIDs = string(T.subjectID);
    if isempty(requestedID)
        uniq = unique(subjIDs, 'stable');
        if numel(uniq) ~= 1
            error('plotSelfReportBodyMapsByVideo:NeedSubjectID', ...
                'Multiple subjects found in table. Please provide subjectID.');
        end
        subjectIDNorm = char(uniq(1));
    else
        [subjectIDNorm, ~] = normalizeSubjectID(requestedID);
    end

    T = T(strcmpi(string(T.subjectID), string(subjectIDNorm)), :);
    if isempty(T)
        error('plotSelfReportBodyMapsByVideo:SubjectNotFound', ...
            'Subject "%s" not found in trialTable.', subjectIDNorm);
    end

    % Sort by declared block order (G1..G15).
    T = sortrows(T, {'blockOrder','blockKey'});

    nTrials = min(height(T), p.Results.maxPanels);
    T = T(1:nTrials, :);

    actPts = cell(nTrials, 1);
    deactPts = cell(nTrials, 1);
    allPts = zeros(0, 2);

    for i = 1:nTrials
        actPts{i} = localParseBodyMapPoints(T.bodyActRaw(i));
        deactPts{i} = localParseBodyMapPoints(T.bodyDeactRaw(i));
        allPts = [allPts; actPts{i}; deactPts{i}]; %#ok<AGROW>
    end

    bounds = localGetBounds(allPts);
    gridSize = round(p.Results.gridSize(:)');

    mapStack = zeros(gridSize(1), gridSize(2), nTrials);
    for i = 1:nTrials
        actMap = localRasterizePoints(actPts{i}, bounds, gridSize);
        deMap = localRasterizePoints(deactPts{i}, bounds, gridSize);

        switch lower(char(string(p.Results.mapMode)))
            case 'activation'
                M = actMap;
            case 'deactivation'
                M = deMap;
            otherwise
                M = actMap - deMap;
        end

        M = localSmoothMap(M, p.Results.smoothSigma);
        mapStack(:, :, i) = M;
    end

    cLim = p.Results.colorLimits;
    if isempty(cLim)
        cLim = localAutoCLim(mapStack, p.Results.mapMode);
    end

    figHandle = figure('Color', 'w');
    nCols = ceil(sqrt(nTrials));
    nRows = ceil(nTrials / nCols);

    cmap = localResolveColormap(p.Results.mapMode);

    for i = 1:nTrials
        subplot(nRows, nCols, i);
        imagesc(mapStack(:, :, i), cLim);
        axis image off;
        colormap(gca, cmap);
        title(char(string(T.blockKey(i))), 'Interpreter', 'none', 'FontSize', 10);
    end

    if p.Results.showColorbar
        cb = colorbar('eastoutside');
        switch lower(char(string(p.Results.mapMode)))
            case 'activation'
                cb.Label.String = 'Activation density';
            case 'deactivation'
                cb.Label.String = 'Deactivation density';
            otherwise
                cb.Label.String = 'Signed density (activation - deactivation)';
        end
    end

    titleStr = char(string(p.Results.figureTitle));
    if isempty(strtrim(titleStr))
        titleStr = sprintf('Self-report body maps | %s | mode=%s', ...
            subjectIDNorm, lower(char(string(p.Results.mapMode))));
    end
    sgtitle(titleStr, 'Interpreter', 'none');

    meta = struct();
    meta.subjectID = subjectIDNorm;
    meta.trialKeys = cellstr(string(T.blockKey));
    meta.blockOrder = T.blockOrder;
    meta.mapMode = lower(char(string(p.Results.mapMode)));
    meta.gridSize = gridSize;
    meta.bounds = bounds;
    meta.colorLimits = cLim;
end

function trialTable = localResolveTrialTable(selfReportInput)
    if istable(selfReportInput)
        trialTable = selfReportInput;
        return;
    end

    if isstruct(selfReportInput)
        if isfield(selfReportInput, 'trialTable') && istable(selfReportInput.trialTable)
            trialTable = selfReportInput.trialTable;
            return;
        end
    end

    trialTable = [];
end

function pts = localParseBodyMapPoints(rawValue)
    s = strtrim(char(string(rawValue)));
    s = regexprep(s, '^"|"$', '');

    if isempty(s) || strcmp(s, '[]')
        pts = zeros(0, 2);
        return;
    end

    % CSV escaped quotes in this dataset use doubled double-quotes.
    s = strrep(s, '""', '"');

    pts = localParseViaJsonDecode(s);
    if isempty(pts)
        pts = localParseViaRegex(s);
    end

    if isempty(pts)
        pts = zeros(0, 2);
    end
end

function pts = localParseViaJsonDecode(s)
    pts = [];
    try
        obj = jsondecode(s);
    catch
        return;
    end

    if isstruct(obj) && isfield(obj, 'x') && isfield(obj, 'y')
        x = [obj.x]';
        y = [obj.y]';
        pts = [double(x), double(y)];
    end
end

function pts = localParseViaRegex(s)
    xTok = regexp(s, '"x"\s*:\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)', 'tokens');
    yTok = regexp(s, '"y"\s*:\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)', 'tokens');

    n = min(numel(xTok), numel(yTok));
    if n == 0
        pts = [];
        return;
    end

    x = zeros(n, 1);
    y = zeros(n, 1);
    for i = 1:n
        x(i) = str2double(xTok{i}{1});
        y(i) = str2double(yTok{i}{1});
    end

    pts = [x, y];
    pts = pts(all(isfinite(pts), 2), :);
end

function bounds = localGetBounds(allPts)
    if isempty(allPts)
        bounds = [0 1 0 1];
        return;
    end

    xmin = min(allPts(:,1));
    xmax = max(allPts(:,1));
    ymin = min(allPts(:,2));
    ymax = max(allPts(:,2));

    if xmin == xmax
        xmax = xmin + 1;
    end
    if ymin == ymax
        ymax = ymin + 1;
    end

    % Small padding around extrema.
    xPad = 0.02 * (xmax - xmin);
    yPad = 0.02 * (ymax - ymin);
    bounds = [xmin - xPad, xmax + xPad, ymin - yPad, ymax + yPad];
end

function M = localRasterizePoints(pts, bounds, gridSize)
    nRows = gridSize(1);
    nCols = gridSize(2);
    M = zeros(nRows, nCols);

    if isempty(pts)
        return;
    end

    xmin = bounds(1); xmax = bounds(2);
    ymin = bounds(3); ymax = bounds(4);

    x = pts(:,1);
    y = pts(:,2);

    ix = 1 + round((x - xmin) ./ max(eps, (xmax - xmin)) * (nCols - 1));
    iy = 1 + round((y - ymin) ./ max(eps, (ymax - ymin)) * (nRows - 1));

    ix = min(max(ix, 1), nCols);
    iy = min(max(iy, 1), nRows);

    lin = sub2ind([nRows, nCols], iy, ix);
    counts = accumarray(lin, 1, [nRows * nCols, 1], @sum, 0);
    M(:) = counts;
end

function M = localSmoothMap(M, sigma)
    if sigma <= 0
        return;
    end

    if exist('imgaussfilt', 'file') == 2
        M = imgaussfilt(M, sigma);
        return;
    end

    radius = max(1, ceil(3 * sigma));
    x = -radius:radius;
    k = exp(-(x.^2) / (2 * sigma^2));
    k = k / sum(k);

    M = conv2(conv2(M, k, 'same'), k', 'same');
end

function cLim = localAutoCLim(mapStack, mapMode)
    vals = mapStack(:);
    vals = vals(isfinite(vals));

    if isempty(vals)
        cLim = [0 1];
        return;
    end

    if strcmpi(char(string(mapMode)), 'signed')
        m = max(abs(vals));
        if m == 0
            m = 1;
        end
        cLim = [-m m];
    else
        m = max(vals);
        if m == 0
            m = 1;
        end
        cLim = [0 m];
    end
end

function cmap = localResolveColormap(mapMode)
    if strcmpi(char(string(mapMode)), 'signed')
        cmap = localBlueWhiteRed(256);
    else
        cmap = hot(256);
    end
end

function cmap = localBlueWhiteRed(n)
    if nargin < 1
        n = 256;
    end

    n1 = floor(n / 2);
    n2 = n - n1;

    blue = [0.15 0.35 0.85];
    white = [1 1 1];
    red = [0.85 0.20 0.20];

    t1 = linspace(0, 1, n1)';
    t2 = linspace(0, 1, n2)';

    c1 = blue .* (1 - t1) + white .* t1;
    c2 = white .* (1 - t2) + red .* t2;

    cmap = [c1; c2];
end
