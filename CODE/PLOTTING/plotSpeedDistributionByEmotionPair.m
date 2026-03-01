function plotSpeedDistributionByEmotionPair(resultsCell, codingTable, markerGroup, emotionPair, varargin)
% plotSpeedDistributionByEmotionPair
%
% Visualize distribution shapes underlying KS distances.
%
% Inputs
%   resultsCell   - output of runMotionMetricsBatch
%   codingTable   - {videoID, emotionLabel} mapping
%   markerGroup   - e.g. 'L-Wrist'
%   emotionPair   - cell {'DISGUST','SAD'} (order insensitive)
%
% Optional name-value
%   'speedField'     - 'speedArrayImmobile' (default) or 'speedArray'
%   'minSamples'     - minimum pooled samples per emotion (default 500)
%   'plotType'       - 'cdf' (default), 'pdf', or 'both'
%   'bySubject'      - true/false (default false)
%
% YU / 2026

p = inputParser;
addParameter(p,'speedField','speedArrayImmobile',@ischar);
addParameter(p,'minSamples',500,@isscalar);
addParameter(p,'plotType','cdf',@ischar);
addParameter(p,'bySubject',false,@islogical);
parse(p,varargin{:});

speedField = p.Results.speedField;
minSamples = p.Results.minSamples;
plotType   = lower(p.Results.plotType);
bySubject  = p.Results.bySubject;

emoA = emotionPair{1};
emoB = emotionPair{2};

% video → emotion map
vidToEmotion = containers.Map(codingTable(:, 1), codingTable(:, 2));

allA = [];
allB = [];

figure; hold on;

for s = 1:numel(resultsCell)
    rc = resultsCell{s};
    if ~isfield(rc,'summaryTable'), continue; end
    st = rc.summaryTable;

    rows = strcmp(st.markerGroup, markerGroup);

    valsA = [];
    valsB = [];

    for r = find(rows)'
        vid = st.videoID{r};
        if ~isKey(vidToEmotion, vid), continue; end
        emo = vidToEmotion(vid);

        if strcmp(emo, emoA)
            valsA = [valsA; st.(speedField){r}(:)];
        elseif strcmp(emo, emoB)
            valsB = [valsB; st.(speedField){r}(:)];
        end
    end

    if numel(valsA) < minSamples || numel(valsB) < minSamples
        continue;
    end

    if bySubject
        plotOne(valsA, valsB, plotType, true);
    end

    allA = [allA; valsA];
    allB = [allB; valsB];
end

if ~bySubject
    plotOne(allA, allB, plotType, false);
end

title(sprintf('%s – %s | %s | %s', emoA, emoB, markerGroup, speedField), ...
      'Interpreter','none');
legend({emoA, emoB}, 'Location','best');
xlabel('Speed (mm/s)');
ylabel('Probability');

end

%% helper
function plotOne(valsA, valsB, plotType, faint)
    lw = 2;
    alpha = faint * 0.25 + ~faint * 1.0;

    switch plotType
        case 'cdf'
            [fA,xA] = ecdf(valsA);
            [fB,xB] = ecdf(valsB);
            plot(xA,fA,'LineWidth',lw,'Color',[0 0.45 0.74 alpha]);
            plot(xB,fB,'LineWidth',lw,'Color',[0.85 0.33 0.10 alpha]);

        case 'pdf'
            histogram(valsA,'Normalization','pdf','DisplayStyle','stairs');
            histogram(valsB,'Normalization','pdf','DisplayStyle','stairs');

        case 'both'
            subplot(1,2,1);
            plotOne(valsA, valsB, 'cdf', faint);
            subplot(1,2,2);
            plotOne(valsA, valsB, 'pdf', faint);
    end
end
