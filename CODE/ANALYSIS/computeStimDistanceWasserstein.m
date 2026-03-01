function [D, details] = computeStimDistanceWasserstein(perStimSpeeds, varargin)
% computeStimDistanceWasserstein - Pairwise stimulus distance on speed distributions.
%
%   [D, details] = computeStimDistanceWasserstein(perStimSpeeds, ...)
%
% Inputs:
%   perStimSpeeds - struct from collectSpeedByStimVideo
%
% Optional name-value:
%   'minSamples'          - minimum samples required per bodypart per stimulus (default 10)
%   'bodyparts'           - subset of bodypart names to use (default: all)
%   'combine'             - how to combine bodyparts: 'mean' (default) or 'median'
%   'metric'              - 'wasserstein' (default), 'ks', or 'js'
%   'nBins'               - number of bins for JS distance (default 50)
%   'useImmobileOnly'     - logical, keep only speeds <= immobilityThreshold (default false)
%   'immobilityThreshold' - threshold in mm/s (default 35)
%   'maxSamplesPerDist'   - cap samples per stimulus/bodypart by random subsample (default [])
%   'verbose'             - logical, show progress messages (default false)
%
% Outputs:
%   D            - nVideos x nVideos distance matrix (NaN where insufficient data)
%   details      - struct with fields:
%       .perBodypartDist  nVideos x nVideos x nGroups distances
%       .bodypartNames    cell array of bodypart names
%       .videoIDs         cell array of video IDs
%       .nUsedPerPair     nVideos x nVideos number of bodyparts used per pair

    p = inputParser;
    addParameter(p, 'minSamples', 10, @(x) isscalar(x) && x >= 0);
    addParameter(p, 'bodyparts', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(p, 'combine', 'mean', @(x) ischar(x) || isstring(x));
    addParameter(p, 'metric', 'wasserstein', @(x) ischar(x) || isstring(x));
    addParameter(p, 'nBins', 50, @(x) isscalar(x) && x > 1);
    addParameter(p, 'useImmobileOnly', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'immobilityThreshold', 35, @(x) isscalar(x) && x > 0);
    addParameter(p, 'maxSamplesPerDist', [], @(x) isempty(x) || (isscalar(x) && x > 0));
    addParameter(p, 'verbose', false, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    minSamples = p.Results.minSamples;
    combine = lower(string(p.Results.combine));
    metric = lower(string(p.Results.metric));
    nBins = p.Results.nBins;
    bodyparts = p.Results.bodyparts;
    useImmobileOnly = p.Results.useImmobileOnly;
    immobilityThreshold = p.Results.immobilityThreshold;
    maxSamplesPerDist = p.Results.maxSamplesPerDist;
    verbose = p.Results.verbose;

    videoIDs = perStimSpeeds.videoIDs;
    groupNames = perStimSpeeds.markerGroupNames;
    speedValues = perStimSpeeds.speedValues;

    if ischar(bodyparts) || isstring(bodyparts)
        bodyparts = cellstr(bodyparts);
    end
    if ~isempty(bodyparts)
        useIdx = ismember(groupNames, bodyparts);
        groupNames = groupNames(useIdx);
        speedValues = speedValues(:, useIdx);
    end

    nVideos = numel(videoIDs);
    nGroups = numel(groupNames);

    perBodypartDist = NaN(nVideos, nVideos, nGroups);
    nUsedPerPair = zeros(nVideos, nVideos);

    if verbose
        fprintf('Computing %s distances: %d videos, %d bodyparts...\n', metric, nVideos, nGroups);
    end
    for i = 1:nVideos
        if verbose
            fprintf('  progress: %d/%d videos\n', i, nVideos);
        end
        for j = i+1:nVideos
            dList = NaN(nGroups, 1);
            for g = 1:nGroups
                a = speedValues{i, g};
                b = speedValues{j, g};
                if useImmobileOnly
                    a = a(a <= immobilityThreshold);
                    b = b(b <= immobilityThreshold);
                end
                if ~isempty(maxSamplesPerDist)
                    a = localSubsample(a, maxSamplesPerDist);
                    b = localSubsample(b, maxSamplesPerDist);
                end
                if numel(a) < minSamples || numel(b) < minSamples
                    continue;
                end
                switch metric
                    case "wasserstein"
                        dList(g) = wasserstein1d(a, b);
                    case "ks"
                        dList(g) = ks1d(a, b);
                    case "js"
                        dList(g) = js1d(a, b, nBins);
                    otherwise
                        error('Unknown metric: %s', metric);
                end
            end

            valid = ~isnan(dList);
            nUsed = sum(valid);
            if nUsed > 0
                switch combine
                    case "mean"
                        d = mean(dList(valid));
                    case "median"
                        d = median(dList(valid));
                    otherwise
                        error('Unknown combine option: %s', combine);
                end
                perBodypartDist(i, j, :) = dList;
                perBodypartDist(j, i, :) = dList;
                nUsedPerPair(i, j) = nUsed;
                nUsedPerPair(j, i) = nUsed;
            end
        end
    end

    D = NaN(nVideos, nVideos);
    for i = 1:nVideos
        D(i, i) = 0;
    end
    for i = 1:nVideos
        for j = i+1:nVideos
            dList = squeeze(perBodypartDist(i, j, :));
            valid = ~isnan(dList);
            if any(valid)
                switch combine
                    case "mean"
                        D(i, j) = mean(dList(valid));
                    case "median"
                        D(i, j) = median(dList(valid));
                end
                D(j, i) = D(i, j);
            end
        end
    end

    if verbose
        fprintf('Done.\n');
    end
    details = struct();
    details.perBodypartDist = perBodypartDist;
    details.bodypartNames = groupNames;
    details.videoIDs = videoIDs;
    details.nUsedPerPair = nUsedPerPair;
    details.metric = metric;
end

function x = localSubsample(x, maxN)
    x = x(:);
    n = numel(x);
    if isempty(maxN) || n <= maxN
        return;
    end
    idx = randperm(n, maxN);
    x = x(idx);
end

function d = wasserstein1d(a, b)
    a = a(:); b = b(:);
    a = a(~isnan(a) & isfinite(a));
    b = b(~isnan(b) & isfinite(b));
    if isempty(a) || isempty(b)
        d = NaN;
        return;
    end

    a = sort(a);
    b = sort(b);
    xa = unique(a);
    xb = unique(b);
    x = unique([xa; xb]);

    % empirical CDFs on merged grid
    Fa = arrayfun(@(v) mean(a <= v), x);
    Fb = arrayfun(@(v) mean(b <= v), x);

    dx = diff(x);
    if isempty(dx)
        d = 0;
        return;
    end

    % integrate |Fa - Fb| over x
    d = sum(abs(Fa(1:end-1) - Fb(1:end-1)) .* dx);
end

function d = ks1d(a, b)
    a = a(:); b = b(:);
    a = a(~isnan(a) & isfinite(a));
    b = b(~isnan(b) & isfinite(b));
    if isempty(a) || isempty(b)
        d = NaN;
        return;
    end
    x = unique([a; b]);
    Fa = arrayfun(@(v) mean(a <= v), x);
    Fb = arrayfun(@(v) mean(b <= v), x);
    d = max(abs(Fa - Fb));
end

function d = js1d(a, b, nBins)
    a = a(:); b = b(:);
    a = a(~isnan(a) & isfinite(a));
    b = b(~isnan(b) & isfinite(b));
    if isempty(a) || isempty(b)
        d = NaN;
        return;
    end
    minVal = min([a; b]);
    maxVal = max([a; b]);
    if minVal == maxVal
        d = 0;
        return;
    end
    edges = linspace(minVal, maxVal, nBins + 1);
    pa = histcounts(a, edges, 'Normalization', 'probability');
    pb = histcounts(b, edges, 'Normalization', 'probability');
    m = 0.5 * (pa + pb);
    d = sqrt(0.5 * klDiv(pa, m) + 0.5 * klDiv(pb, m));
end

function k = klDiv(p, q)
    epsVal = 1e-12;
    p = p + epsVal;
    q = q + epsVal;
    k = sum(p .* log2(p ./ q));
end
