function out = gatherInstantSpeeds(resultsCell, markerGroupNames, varargin)
% gatherInstantSpeeds - Pool instantaneous marker speeds across subjects/videos, per marker group.
%
%   out = gatherInstantSpeeds(resultsCell, markerGroupNames, ...)
%
% Inputs:
%   resultsCell       - cell array from runMotionMetricsBatch (must include perMarkerMetrics with freqSignal)
%   markerGroupNames  - cell array of marker group names to include (uses all by default)
%
% Optional name-value pairs:
%   'outlierQuantile'          - upper quantile cutoff to drop outliers (default 0.99, [] to disable)
%   'maxSpeed'                 - discard speeds above this (default 100; [] to disable)
%   'makePlot'                 - logical (default false) to show histograms per group
%   'fitThreshold'             - logical (default true) fit 2-component mixture on log-speeds and
%                                return intersection as suggested immobility threshold
%   'computePerSubjectThresh'  - logical (default false) also compute thresholds per subject
%
% Output:
%   out               - struct array with fields:
%       .groupName      marker group name
%       .speeds         pooled instantaneous speeds (mm/s) across all subjects/videos/markers in the group
%
% Notes:
%   - Uses perMarkerMetrics.freqSignal from getMotionMetricsFromTrajectory. Ensure you ran
%     runMotionMetricsBatch/getMotionMetricsAcrossStims with computeFrequencyMetrics=true.

    p = inputParser;
    addParameter(p, 'outlierQuantile', 0.99, @(x) isempty(x) || (isscalar(x) && x>0 && x<1));
    addParameter(p, 'maxSpeed', 100, @(x) isempty(x) || (isscalar(x) && x>0));
    addParameter(p, 'makePlot', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'fitThreshold', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'computePerSubjectThresh', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    outlierQuantile = p.Results.outlierQuantile;
    maxSpeed = p.Results.maxSpeed;

    if nargin < 2 || isempty(markerGroupNames)
        % infer from first results entry
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

    out = repmat(struct('groupName', '', 'speeds', [], 'threshold', NaN, 'mixModel', [], ...
                        'subjectThresholds', [], 'videoThresholds', []), numel(markerGroupNames), 1);

    for g = 1:numel(markerGroupNames)
        grpName = markerGroupNames{g};
        pooled = [];
        for i = 1:numel(resultsCell)
            rc = resultsCell{i};
            if ~isfield(rc, 'results'), continue; end
            resArr = rc.results;
            for r = 1:numel(resArr)
                if ~strcmp(resArr(r).markerGroupName, grpName)
                    continue;
                end
                if ~isfield(resArr(r), 'perMarkerMetrics')
                    continue; 
                end
                pm = resArr(r).perMarkerMetrics;
                for k = 1:numel(pm)
                    if isfield(pm{k}, 'freqSignal') && ~isempty(pm{k}.freqSignal)
                        pooled = [pooled; pm{k}.freqSignal(:)]; %#ok<AGROW>
                    end
                end
            end
        end
        pooled = pooled(~isnan(pooled) & isfinite(pooled));
        if ~isempty(maxSpeed)
            pooled = pooled(pooled <= maxSpeed);
        end
        if ~isempty(outlierQuantile) && ~isempty(pooled)
            cutoff = quantile(pooled, outlierQuantile);
            pooled(pooled > cutoff) = [];
        end
        out(g).groupName = grpName;
        out(g).speeds = pooled;

        % Fit overall threshold
        if p.Results.fitThreshold && ~isempty(pooled)
            [thr, model] = computeMixtureThreshold(pooled);
            out(g).threshold = thr;
            out(g).mixModel = model;
        end

        % Optional per-subject thresholds
        if p.Results.computePerSubjectThresh
            subjList = {};
            subjThr = [];
            for i = 1:numel(resultsCell)
                rc = resultsCell{i};
                subjID = '';
                if isfield(rc, 'subjectID'), subjID = char(rc.subjectID); end
                if isempty(subjID), subjID = sprintf('subj%d', i); end
                if ~isfield(rc, 'results'), continue; end
                resArr = rc.results;
                speedsSubj = [];
                for r = 1:numel(resArr)
                    if ~strcmp(resArr(r).markerGroupName, grpName), continue; end
                    if ~isfield(resArr(r), 'perMarkerMetrics'), continue; end
                    pm = resArr(r).perMarkerMetrics;
                    for k = 1:numel(pm)
                        if isfield(pm{k}, 'freqSignal') && ~isempty(pm{k}.freqSignal)
                            speedsSubj = [speedsSubj; pm{k}.freqSignal(:)]; %#ok<AGROW>
                        end
                    end
                end
                speedsSubj = speedsSubj(~isnan(speedsSubj) & isfinite(speedsSubj));
                if ~isempty(maxSpeed)
                    speedsSubj = speedsSubj(speedsSubj <= maxSpeed);
                end
                if ~isempty(outlierQuantile) && ~isempty(speedsSubj)
                    cutoff = quantile(speedsSubj, outlierQuantile);
                    speedsSubj(speedsSubj > cutoff) = [];
                end
                if isempty(speedsSubj)
                    continue;
                end
                [thrS, ~] = computeMixtureThreshold(speedsSubj);
                subjList{end+1,1} = subjID; %#ok<AGROW>
                subjThr(end+1,1) = thrS; %#ok<AGROW>
            end
            out(g).subjectThresholds = table(subjList, subjThr, 'VariableNames', {'subjectID','threshold'});
        end

        % Per-video thresholds
        vidList = {};
        vidThr = [];
        vidKeys = {};
        vidMap = containers.Map;
        for i = 1:numel(resultsCell)
            rc = resultsCell{i};
            if ~isfield(rc, 'results'), continue; end
            resArr = rc.results;
            for r = 1:numel(resArr)
                if ~strcmp(resArr(r).markerGroupName, grpName), continue; end
                vid = resArr(r).videoID;
                if ~isfield(resArr(r), 'perMarkerMetrics'), continue; end
                pm = resArr(r).perMarkerMetrics;
                for k = 1:numel(pm)
                    if isfield(pm{k}, 'freqSignal') && ~isempty(pm{k}.freqSignal)
                        if ~isKey(vidMap, vid); vidMap(vid) = []; vidKeys{end+1} = vid; end %#ok<AGROW>
                        vidMap(vid) = [vidMap(vid); pm{k}.freqSignal(:)]; %#ok<AGROW>
                    end
                end
            end
        end
        for v = 1:numel(vidKeys)
            vid = vidKeys{v};
            vals = vidMap(vid);
            vals = vals(~isnan(vals) & isfinite(vals));
            if ~isempty(maxSpeed)
                vals = vals(vals <= maxSpeed);
            end
            if ~isempty(outlierQuantile) && ~isempty(vals)
                cutoff = quantile(vals, outlierQuantile);
                vals(vals > cutoff) = [];
            end
            if isempty(vals)
                vidList{end+1,1} = vid; %#ok<AGROW>
                vidThr(end+1,1) = NaN; %#ok<AGROW>
            else
                vidList{end+1,1} = vid; %#ok<AGROW>
                vidThr(end+1,1) = computeMixtureThreshold(vals); %#ok<AGROW>
            end
        end
        if ~isempty(vidList)
            out(g).videoThresholds = table(vidList, vidThr, 'VariableNames', {'videoID','threshold'});
        end
    end

    if p.Results.makePlot
        makePlot(out);
        makeThresholdViolinPlot(out);
    end
end

function makePlot(out)
    nGroups = numel(out);
    nCols = min(3, nGroups);
    nRows = ceil(nGroups / nCols);
    figure;
    tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
    for g = 1:nGroups
        nexttile; hold on;
        vals = out(g).speeds;
        if isempty(vals)
            title(out(g).groupName);
            text(0.5,0.5,'No data','HorizontalAlignment','center');
            continue;
        end
        histogram(vals, 'Normalization','probability');
        xlabel('Instantaneous speed (mm/s)');
        ylabel('Probability');
        set(gca, 'YScale', 'log');
        grid on;
        title(sprintf('%s (n=%d, med=%.2f)', out(g).groupName, numel(vals), median(vals,'omitnan')));
    end
end

function makeThresholdViolinPlot(out)
    % Figure with two subplots:
    % 1) violins: thresholds per bodypart (points = subject-level thresholds)
    % 2) violins: thresholds per stim video (points = bodypart-level thresholds)

    % Collect bodypart/subject thresholds
    bodypartNames = {out.groupName};
    bpData = cell(numel(out),1);
    for i = 1:numel(out)
        if istable(out(i).subjectThresholds) && any(~isnan(out(i).subjectThresholds.threshold))
            bpData{i} = out(i).subjectThresholds.threshold(~isnan(out(i).subjectThresholds.threshold));
        else
            bpData{i} = [];
        end
    end

    % Collect video thresholds pooled across bodyparts
    vidMap = containers.Map;
    vidOrder = {};
    for i = 1:numel(out)
        vt = out(i).videoThresholds;
        if istable(vt) && ~isempty(vt)
            for r = 1:height(vt)
                vid = vt.videoID{r};
                thr = vt.threshold(r);
                if isnan(thr), continue; end
                if ~isKey(vidMap, vid)
                    vidMap(vid) = [];
                    vidOrder{end+1} = vid; %#ok<AGROW>
                end
                vidMap(vid) = [vidMap(vid); thr]; %#ok<AGROW>
            end
        end
    end

    figure;
    tiledlayout(1,2, 'Padding','compact', 'TileSpacing','compact');

    % Left: bodypart violins (subject thresholds)
    nexttile; hold on;
    simpleViolin(bpData, bodypartNames);
    ylabel('Threshold (mm/s)');
    title('Subject thresholds by bodypart');
    xtickangle(30);
    grid on;

    % Right: stim video violins (bodypart thresholds)
    nexttile; hold on;
    vidData = cell(numel(vidOrder),1);
    for i = 1:numel(vidOrder)
        vidData{i} = vidMap(vidOrder{i});
    end
    simpleViolin(vidData, vidOrder);
    ylabel('Threshold (mm/s)');
    title('Thresholds by stim video');
    xtickangle(45);
    grid on;
end

function simpleViolin(dataCell, xLabels)
    % Draw simple violins using ksdensity for each cell array entry
    outlineColor = [0 0 0];
    for i = 1:numel(dataCell)
        vals = dataCell{i};
        if isempty(vals), continue; end
        [dens, xi] = ksdensity(vals);
        dens = 0.35 * dens / max(dens);
        fill(i + [ -dens, fliplr(dens) ], [xi, fliplr(xi)], [0.7 0.85 1], ...
            'EdgeColor', outlineColor, 'FaceAlpha', 0.6, 'LineWidth', 1);
        medVal = median(vals,'omitnan');
        plot([i-0.25 i+0.25], [medVal medVal], 'Color', outlineColor, 'LineWidth', 1.5);
        scatter(i*ones(size(vals)), vals, 8, outlineColor, 'filled', 'MarkerFaceAlpha', 0.3, 'MarkerEdgeAlpha',0.3);
    end
    xlim([0.5 numel(dataCell)+0.5]);
    set(gca, 'XTick', 1:numel(dataCell), 'XTickLabel', xLabels);
end

function [thr, model] = computeMixtureThreshold(vals)
    thr = NaN;
    model = [];
    vals = vals(vals > 0); % log-domain requires positive
    if numel(vals) < 50
        return;
    end
    logVals = log(vals);
    try
        model = fitgmdist(logVals, 2, 'RegularizationValue', 1e-6, 'Options', statset('MaxIter',500));
        % Order components by mean (low to high)
        mu = model.mu(:);
        sig = sqrt(reshape(model.Sigma, [], 1));
        [mu, order] = sort(mu);
        sig = sig(order);
        w = model.ComponentProportion(order);
        % Evaluate between means to find intersection
        xs = linspace(mu(1), mu(2), 400);
        pdf1 = w(1) * normpdf(xs, mu(1), sig(1));
        pdf2 = w(2) * normpdf(xs, mu(2), sig(2));
        diffPdf = pdf1 - pdf2;
        [~, idx] = min(abs(diffPdf));
        thr = exp(xs(idx));
    catch
        thr = NaN;
        model = [];
    end
end
