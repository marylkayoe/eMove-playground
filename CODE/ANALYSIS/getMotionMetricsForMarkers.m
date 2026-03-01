function metricsCell = getMotionMetricsForMarkers(trialData, markerList, videoID, varargin)
% getMotionMetricsForMarkers - Compute motion metrics per marker for a given videoID.
%
%   metricsCell = getMotionMetricsForMarkers(trialData, markerList, videoID, ...)
%
% Inputs:
%   trialData  - struct with trajectoryData, markerNames, metaData (with stimScheduling/videoIDs)
%   markerList - cell/char/string of marker names
%   videoID    - stimulus ID to extract frames for
%
% Optional name-value pairs (passed to getMotionMetricsFromTrajectory):
%   'FRAMERATE'               - frames per second (default: trialData.metaData.captureFrameRate or 120)
%   'speedWindow'             - speed window in seconds (default: 0.1)
%   'computeFrequencyMetrics' - logical (default: false)
%   'freqBands'               - struct of bands
%   'freqMakePlot'            - logical
%
% Output:
%   metricsCell - cell array, one entry per marker, each a metrics struct

    p = inputParser;
    addRequired(p, 'trialData');
    addRequired(p, 'markerList', @(x) iscell(x) || ischar(x) || isstring(x));
    addRequired(p, 'videoID', @(x) ischar(x) || isstring(x));
    addParameter(p, 'FRAMERATE', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'speedWindow', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'computeFrequencyMetrics', true, @(x) islogical(x) && isscalar(x));
         defaultBands = struct( ...
        'tremor', [6 12], ...
        'low',    [0.5 3], ...
        'mid',    [3 6], ...
        'high',   [12 20]);
    addParameter(p, 'freqBands', defaultBands, @isstruct);
    addParameter(p, 'freqMakePlot', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'makePlot', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'immobilityThreshold', 35, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    parse(p, trialData, markerList, videoID, varargin{:});

    % normalize marker list
    if ischar(markerList) || isstring(markerList)
        markerList = cellstr(markerList);
    end

    metaData = struct();
    if isfield(trialData, 'metaData')
        metaData = trialData.metaData;
    end
    frameRate = p.Results.FRAMERATE;
    if isempty(frameRate)
        if isfield(metaData, 'captureFrameRate')
            frameRate = metaData.captureFrameRate;
        else
            frameRate = 120; % fallback
        end
    end

    % extract trajectories for all markers in one call
    trajAll = getMarkerTrajectory(trialData, markerList, 'videoID', videoID, 'mocapMetaData', metaData);

    nMarkers = numel(markerList);
    metricsCell = cell(nMarkers, 1);
    numericFields = {};

    for m = 1:nMarkers
        thisTraj = squeeze(trajAll(:, :, m));
        metricsCell{m} = getMotionMetricsFromTrajectory(thisTraj, ...
            'FRAMERATE', frameRate, ...
            'speedWindow', p.Results.speedWindow, ...
            'computeFrequencyMetrics', p.Results.computeFrequencyMetrics, ...
            'freqBands', p.Results.freqBands, ...
            'freqMakePlot', p.Results.freqMakePlot, ...
            'immobilityThreshold', p.Results.immobilityThreshold);
        metricsCell{m}.markerName = markerList{m};
        metricsCell{m}.videoID = videoID;

        if isempty(numericFields)
            fns = fieldnames(metricsCell{m});
            numericFields = fns(structfun(@(v) isnumeric(v) && isscalar(v), metricsCell{m}));
        end
    end

    % summary of numeric scalar fields across markers
    summary = struct();
    for k = 1:numel(numericFields)
        fn = numericFields{k};
        vals = cellfun(@(s) localGetScalarField(s, fn), metricsCell);
        summary.(fn) = mean(vals, 'omitnan');
    end
    summary.markerName = 'SUMMARY';
    summary.videoID = videoID;
    metricsCell{end+1} = summary;

    if p.Results.makePlot
        plotMetricsSummary(metricsCell, videoID);
    end
end

function v = localGetScalarField(s, fn)
    persistent warnedFields
    if isempty(warnedFields)
        warnedFields = containers.Map;
    end

    if isfield(s, fn) && isnumeric(s.(fn))
        if isscalar(s.(fn))
            v = s.(fn);
            return;
        end
        if ~isKey(warnedFields, fn)
            mName = '';
            if isfield(s, 'markerName'), mName = s.markerName; end
            vID = '';
            if isfield(s, 'videoID'), vID = s.videoID; end
            warning('getMotionMetricsForMarkers:NonScalarField', ...
                'Field "%s" is non-scalar (marker=%s, video=%s). Using NaN in summary.', fn, mName, vID);
            warnedFields(fn) = true;
        end
    end
    v = NaN;
end

function plotMetricsSummary(metricsCell, videoID)
    % Separate individual markers and summary
    markerNames = cellfun(@(s) s.markerName, metricsCell, 'UniformOutput', false);
    isSummary = strcmp(markerNames, 'SUMMARY');
    idxMarkers = find(~isSummary);
    names = markerNames(idxMarkers);

    % Collect metrics
    avgSpeed = cellfun(@(s) s.averageSpeed, metricsCell(idxMarkers));
    mad3d = cellfun(@(s) s.mad3d, metricsCell(idxMarkers));

    % Figure layout
    figure;
    tl = tiledlayout(2,2, 'Padding','compact', 'TileSpacing','compact');

    nexttile;
    bar(categorical(names), avgSpeed);
    ylabel('Average speed (mm/s)');
    title('Average speed');
    grid on;

    nexttile;
    bar(categorical(names), mad3d);
    ylabel('MAD radius (mm)');
    title('Spatial spread');
    grid on;

    % PSD overlay (if available)
    nexttile;
    hold on;
    hasPSD = false;
    for idx = 1:numel(idxMarkers)
        i = idxMarkers(idx);
        if isfield(metricsCell{i}, 'freqMetrics') && isfield(metricsCell{i}.freqMetrics, 'freq') ...
                && ~isempty(metricsCell{i}.freqMetrics.freq)
            fm = metricsCell{i}.freqMetrics;
            semilogy(fm.freq, fm.psd, 'DisplayName', metricsCell{i}.markerName);
            hasPSD = true;
        end
    end
    xlabel('Frequency (Hz)');
    ylabel('PSD');
    set(gca, 'YScale', 'log');
    title('Frequency spectra (speed)');
    grid on;
    if hasPSD
        legend('show');
    else
        text(0.5,0.5,'No PSD data','HorizontalAlignment','center');
    end

    % Band power ratios
    nexttile;
    hasBand = false;
    allBands = {};
    bandMat = [];
    for idx = 1:numel(idxMarkers)
        i = idxMarkers(idx);
        if isfield(metricsCell{i}, 'freqMetrics') && isfield(metricsCell{i}.freqMetrics, 'bands') ...
                && ~isempty(metricsCell{i}.freqMetrics.bands)
            tbl = metricsCell{i}.freqMetrics.bands;
            if isempty(allBands)
                % keep only mid/tremor/high if present
                allBands = cellstr(tbl.band);
                keepMask = ismember(allBands, {'mid','tremor','high'});
                allBands = allBands(keepMask);
                bandMat = NaN(numel(idxMarkers), numel(allBands));
            end
            for b = 1:numel(allBands)
                row = strcmp(tbl.band, allBands{b});
                if any(row)
                    bandMat(idx, b) = tbl.powerRatio(row);
                    hasBand = true;
                end
            end
        end
    end
    if hasBand
        bar(categorical(names), bandMat, 'stacked');
        ylabel('Power ratio');
        legend(allBands, 'Location', 'eastoutside');
        title('Band power ratios');
        grid on;
    else
        text(0.5,0.5,'No band power data','HorizontalAlignment','center');
    end

    sgtitle(sprintf('Motion metrics for %s', videoID));
end
