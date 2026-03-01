% to do the full thing


encodingTable = stimVideoEmotionCodingHard;
codingNameBase = 'HARD';

eMoveResultsTESTING = runMotionMetricsBatch(eMoveDataPath, groupedMarkerNames, 'stimVideoEmotionCoding', encodingTable, 'markerGroupNames', groupedBodypartNames);

outbuckets_TESTING = buildNormalizedMetricsBuckets(eMoveResultsTESTING, groupedBodypartNames, 'makePlot', false);

%plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {'1', '2', '3', '4', '5'}, 'useImmobile', false, 'codingName', [codingNameBase '-full-speed']);
plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {'1', '2', '3', '4', '5'}, 'useImmobile', true, 'codingName', [codingNameBase  '-immobile-speed']);




encodingTable = stimVideoEmotionCodingHard_3001to3;
codingNameBase = '3001to3';

eMoveResultsTESTING = runMotionMetricsBatch(eMoveDataPath, groupedMarkerNames, 'stimVideoEmotionCoding', encodingTable, 'markerGroupNames', groupedBodypartNames);

outbuckets_TESTING = buildNormalizedMetricsBuckets(eMoveResultsTESTING, groupedBodypartNames, 'makePlot', false);

%plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {'1', '2', '3', '4', '5'}, 'useImmobile', false, 'codingName', [codingNameBase '-full-speed']);
plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {'1', '2', '3', '4', '5'}, 'useImmobile', true, 'codingName', [codingNameBase  '-immobile-speed']);


encodingTable = stimVideoEmotionCodingHard_6201to3;
codingNameBase = '6201to3';

eMoveResultsTESTING = runMotionMetricsBatch(eMoveDataPath, groupedMarkerNames, 'stimVideoEmotionCoding', encodingTable, 'markerGroupNames', groupedBodypartNames);

outbuckets_TESTING = buildNormalizedMetricsBuckets(eMoveResultsTESTING, groupedBodypartNames, 'makePlot', false);

%plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {'1', '2', '3', '4', '5'}, 'useImmobile', false, 'codingName', [codingNameBase '-full-speed']);
plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {'1', '2', '3', '4', '5'}, 'useImmobile', true, 'codingName', [codingNameBase  '-immobile-speed']);

encodingTable = stimVideoEmotionCodingHard_3001_6201_to3;
codingNameBase = '6201 and 3001 to 3';

eMoveResultsTESTING = runMotionMetricsBatch(eMoveDataPath, groupedMarkerNames, 'stimVideoEmotionCoding', encodingTable, 'markerGroupNames', groupedBodypartNames);

outbuckets_TESTING = buildNormalizedMetricsBuckets(eMoveResultsTESTING, groupedBodypartNames, 'makePlot', false);

%plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {'1', '2', '3', '4', '5'}, 'useImmobile', false, 'codingName', [codingNameBase '-full-speed']);
plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {'1', '2', '3', '4', '5'}, 'useImmobile', true, 'codingName', [codingNameBase  '-immobile-speed']);



encodingTable = stimVideoEmotionCodingSINGLES;
codingNameBase = 'SINGLES';

eMoveResultsTESTING = runMotionMetricsBatch(eMoveDataPath, groupedMarkerNames, 'stimVideoEmotionCoding', encodingTable, 'markerGroupNames', groupedBodypartNames);

outbuckets_TESTING = buildNormalizedMetricsBuckets(eMoveResultsTESTING, groupedBodypartNames, 'makePlot', false);

plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','SAL', 'stimGroups',  { 'AMUSEMENT', 'JOY'}, 'useImmobile', false, 'codingName', [codingNameBase '-full-speed']);
plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','SAL', 'stimGroups',  { 'DISGUST', 'JOY'}, 'useImmobile', false, 'codingName', [codingNameBase  '-full-SAL']);



encodingTable = stimVideoEmotionCodingSINGLES;
codingNameBase = 'SINGLES-lowspeed';

eMoveResultsTESTING = runMotionMetricsBatch(eMoveDataPath, groupedMarkerNames, 'stimVideoEmotionCoding', encodingTable, 'markerGroupNames', groupedBodypartNames, 'immobilityThreshold', 25);

outbuckets_TESTING = buildNormalizedMetricsBuckets(eMoveResultsTESTING, groupedBodypartNames, 'makePlot', false);

%plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','SAL', 'stimGroups',  { 'AMUSEMENT', 'JOY'}, 'useImmobile', false, 'codingName', [codingNameBase '-full-speed']);
plotSpeedCDFByStimGroup(outbuckets_TESTING, encodingTable, 'metric','speed', 'stimGroups',  {  'FEAR', 'DISGUST', 'JOY', 'SAD', 'NEUTRAL'}, 'useImmobile', false, 'codingName', [codingNameBase  '-immobile25-speed']);


