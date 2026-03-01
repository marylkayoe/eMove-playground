function out = collectSpeedByStimVideo(resultsCell, markerGroupNames, varargin)
% collectSpeedByStimVideo - Collect per-stimulus speed/immobility data across subjects.
%
%   out = collectSpeedByStimVideo(resultsCell, markerGroupNames, ...)
%
% Inputs:
%   resultsCell       - cell array from runMotionMetricsBatch (each entry has .results)
%   markerGroupNames  - cell array of marker group names (uses all if empty)
%
% Optional name-value:
%   'normalizeToBaseline' - logical (default true) normalize speeds per subject/marker
%                           by that subject's baseline median speed
%   'outlierQuantile'      - upper quantile cutoff for speed values (default 0.99; [] to disable)
%   'maxSpeed'             - discard speeds above this (default [] to disable)
%   'includeBaseline'      - include baseline video IDs in output (default true)
%
% Output struct fields:
%   .videoIDs           - ordered list of video IDs (baseline first if present)
%   .markerGroupNames   - marker group names (column cell)
%   .speedValues        - nVideos x nGroups cell array of pooled speed samples
%   .immobileFrac       - nVideos x nGroups cell array of percent immobile samples
%   .immobileMedian     - nVideos x nGroups cell array of median speed while immobile (normalized if enabled)
%   .mobileMean         - nVideos x nGroups cell array of mean speed while mobile (normalized if enabled)
%   .countsSpeed        - nVideos x nGroups array with sample counts for speedValues
%
% Notes:
%   - Uses perMarkerMetrics.speedArray, percentImmobile, medianSpeedImmobile, avgSpeedMobile.
%   - If normalizeToBaseline is true, speeds are divided by the subject's baseline median speed
%     for the same marker.

    p = inputParser;
    addParameter(p, 'normalizeToBaseline', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'outlierQuantile', 0.99, @(x) isempty(x) || (isscalar(x) && x>0 && x<1));
    addParameter(p, 'maxSpeed', [], @(x) isempty(x) || (isscalar(x) && x>0));
    addParameter(p, 'includeBaseline', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    normalizeToBaseline = p.Results.normalizeToBaseline;
    outlierQuantile = p.Results.outlierQuantile;
    maxSpeed = p.Results.maxSpeed;
    includeBaseline = p.Results.includeBaseline;

    if nargin < 2 || isempty(markerGroupNames)
        markerGroupNames = {};
        for i = 1:numel(resultsCell)
            rc = resultsCell{i};
            if isfield(rc, 'results') && ~isempty(rc.results)
                markerGroupNames = unique({rc.results.markerGroupName}, 'stable');
                break;
            end
        end
    end
    if ischar(markerGroupNames) || isstring(markerGroupNames)
        markerGroupNames = cellstr(markerGroupNames);
    end
    if isrow(markerGroupNames); markerGroupNames = markerGroupNames(:); end

    % Collect all video IDs
    allVideoIDs = {};
    for subjIdx = 1:numel(resultsCell)
        rc = resultsCell{subjIdx};
        if ~isfield(rc, 'results'), continue; end
        resArr = rc.results;
        allVideoIDs = [allVideoIDs; {resArr.videoID}']; %#ok<AGROW>
    end
    allVideoIDs = unique(allVideoIDs);
    isBaseline = contains(lower(allVideoIDs), 'baseline') | strcmp(allVideoIDs, 'BASELINE') | strcmp(allVideoIDs, '0');
    baselineIDs = allVideoIDs(isBaseline);
    otherIDs = sort(allVideoIDs(~isBaseline));
    videoIDs = [baselineIDs; otherIDs];
    if ~includeBaseline
        videoIDs = videoIDs(~isBaseline);
    end

    nVideos = numel(videoIDs);
    nGroups = numel(markerGroupNames);

    speedValues = cell(nVideos, nGroups);
    immobileFrac = cell(nVideos, nGroups);
    immobileMedian = cell(nVideos, nGroups);
    mobileMean = cell(nVideos, nGroups);

    % Build baseline map: subjID -> markerName -> baseline median speed
    baselineMap = containers.Map;
    if normalizeToBaseline
        for subjIdx = 1:numel(resultsCell)
            rc = resultsCell{subjIdx};
            subjID = '';
            if isfield(rc, 'subjectID'), subjID = char(rc.subjectID); end
            if isempty(subjID), subjID = sprintf('subj%d', subjIdx); end
            if ~isfield(rc, 'results'), continue; end
            resArr = rc.results;
            baseStruct = struct();
            for r = 1:numel(resArr)
                if ~isBaselineVideo(resArr(r).videoID), continue; end
                if ~isfield(resArr(r), 'perMarkerMetrics'), continue; end
                pm = resArr(r).perMarkerMetrics;
                for k = 1:numel(pm)
                    if ~isfield(pm{k}, 'markerName'), continue; end
                    if ~isfield(pm{k}, 'medianSpeed') || isnan(pm{k}.medianSpeed), continue; end
                    markerKey = matlab.lang.makeValidName(pm{k}.markerName);
                    baseStruct.(markerKey) = pm{k}.medianSpeed;
                end
            end
            if ~isempty(fieldnames(baseStruct))
                baselineMap(subjID) = baseStruct;
            end
        end
    end

    % Collect values per video / group
    for subjIdx = 1:numel(resultsCell)
        rc = resultsCell{subjIdx};
        subjID = '';
        if isfield(rc, 'subjectID'), subjID = char(rc.subjectID); end
        if isempty(subjID), subjID = sprintf('subj%d', subjIdx); end
        if ~isfield(rc, 'results'), continue; end
        resArr = rc.results;

        for r = 1:numel(resArr)
            grpIdx = find(strcmp(markerGroupNames, resArr(r).markerGroupName), 1);
            if isempty(grpIdx), continue; end
            vid = resArr(r).videoID;
            vidIdx = find(strcmp(videoIDs, vid), 1);
            if isempty(vidIdx), continue; end
            if ~isfield(resArr(r), 'perMarkerMetrics'), continue; end

            pm = resArr(r).perMarkerMetrics;
            for k = 1:numel(pm)
                if ~isfield(pm{k}, 'markerName'), continue; end
                markerKey = matlab.lang.makeValidName(pm{k}.markerName);

                scale = 1;
                if normalizeToBaseline
                    if ~isKey(baselineMap, subjID), continue; end
                    baseStruct = baselineMap(subjID);
                    if ~isfield(baseStruct, markerKey), continue; end
                    scale = baseStruct.(markerKey);
                    if isempty(scale) || isnan(scale) || scale == 0, continue; end
                end

                if isfield(pm{k}, 'speedArray') && ~isempty(pm{k}.speedArray)
                    vals = pm{k}.speedArray(:) / scale;
                    speedValues{vidIdx, grpIdx} = [speedValues{vidIdx, grpIdx}; vals]; %#ok<AGROW>
                end
                if isfield(pm{k}, 'percentImmobile') && ~isnan(pm{k}.percentImmobile)
                    immobileFrac{vidIdx, grpIdx} = [immobileFrac{vidIdx, grpIdx}; pm{k}.percentImmobile]; %#ok<AGROW>
                end
                if isfield(pm{k}, 'medianSpeedImmobile') && ~isnan(pm{k}.medianSpeedImmobile)
                    immobileMedian{vidIdx, grpIdx} = [immobileMedian{vidIdx, grpIdx}; pm{k}.medianSpeedImmobile / scale]; %#ok<AGROW>
                end
                if isfield(pm{k}, 'avgSpeedMobile') && ~isnan(pm{k}.avgSpeedMobile)
                    mobileMean{vidIdx, grpIdx} = [mobileMean{vidIdx, grpIdx}; pm{k}.avgSpeedMobile / scale]; %#ok<AGROW>
                end
            end
        end
    end

    % Clean and apply filters
    for v = 1:nVideos
        for g = 1:nGroups
            speedValues{v,g} = localFilterVals(speedValues{v,g}, outlierQuantile, maxSpeed);
            immobileMedian{v,g} = localFilterVals(immobileMedian{v,g}, outlierQuantile, maxSpeed);
            mobileMean{v,g} = localFilterVals(mobileMean{v,g}, outlierQuantile, maxSpeed);
        end
    end

    countsSpeed = cellfun(@numel, speedValues);

    out = struct();
    out.videoIDs = videoIDs;
    out.markerGroupNames = markerGroupNames;
    out.speedValues = speedValues;
    out.immobileFrac = immobileFrac;
    out.immobileMedian = immobileMedian;
    out.mobileMean = mobileMean;
    out.countsSpeed = countsSpeed;
end

function tf = isBaselineVideo(vid)
    tf = contains(lower(vid), 'baseline') || strcmp(vid, 'BASELINE') || strcmp(vid, '0');
end

function vals = localFilterVals(vals, outlierQuantile, maxSpeed)
    if isempty(vals)
        return;
    end
    vals = vals(~isnan(vals) & isfinite(vals));
    if ~isempty(maxSpeed)
        vals = vals(vals <= maxSpeed);
    end
    if ~isempty(outlierQuantile) && ~isempty(vals)
        cutoff = quantile(vals, outlierQuantile);
        vals(vals > cutoff) = [];
    end
end
