function runSummary = createWasedaChestMagnitudeEnvelopeFiles(varargin)
%CREATEWASEDACHESTMAGNITUDEENVELOPEFILES Build chest ACC envelope MAT files.
%
% runSummary = createWasedaChestMagnitudeEnvelopeFiles()
%
% Purpose
%   Load concatenated chest WTAcc MAT files, run the current IMU pipeline,
%   and save one motion-envelope MAT file per input file.
%
% Notes
%   - Only chest files are processed, identified by `WTAcc 1` in the MAT
%     filename.
%   - Existing concatenated MAT files are used directly.
%   - `WTAcc 2` files are skipped entirely.

%% Parse inputs

inputParserObject = inputParser;

defaultDataRoot = '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED';

addParameter(inputParserObject, 'InputRoot', fullfile(defaultDataRoot, 'CONCATENATED'), ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'OutputRoot', fullfile(defaultDataRoot, 'MAGNITUDES'), ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'FrequencyBandHz', [0.2 10], ...
    @(value) isnumeric(value) && numel(value) == 2 && value(1) > 0 && value(2) > value(1));

addParameter(inputParserObject, 'EnvelopeWindowSeconds', 1.0, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'QuaternionJumpMaxDeg', 60, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'UseConjugate', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'MakeQcPlots', false, ...
    @(value) islogical(value) || isnumeric(value));

parse(inputParserObject, varargin{:});

options = inputParserObject.Results;
inputRoot = char(string(options.InputRoot));
outputRoot = char(string(options.OutputRoot));

if ~isfolder(inputRoot)
    error('createWasedaChestMagnitudeEnvelopeFiles:MissingInputRoot', ...
        'Input folder not found: %s', inputRoot);
end

if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

%% Find chest MAT files

matFiles = [ ...
    dir(fullfile(inputRoot, '*acc1_chest.mat')); ...
    dir(fullfile(inputRoot, '*WTAcc 1*.mat'))];

if isempty(matFiles)
    error('createWasedaChestMagnitudeEnvelopeFiles:NoChestFiles', ...
        'No chest MAT files found in: %s', inputRoot);
end

summaryRows = repmat(struct( ...
    'inputMatPath', "", ...
    'outputMatPath', "", ...
    'nSamples', NaN, ...
    'sampleRateHz', NaN), numel(matFiles), 1);

%% Process each chest MAT file

for fileIndex = 1:numel(matFiles)

    inputMatPath = fullfile(matFiles(fileIndex).folder, matFiles(fileIndex).name);
    loadedData = load(inputMatPath, 'accData');

    if ~isfield(loadedData, 'accData')
        error('createWasedaChestMagnitudeEnvelopeFiles:MissingAccData', ...
            'MAT file does not contain accData: %s', inputMatPath);
    end

    accData = loadedData.accData;

    imuPrepared = prepareAccelerometerQuaternionData(accData, ...
        'AccelerationUnit', 'auto', ...
        'QuaternionOrder', 'wxyz', ...
        'QuaternionJumpMaxDeg', options.QuaternionJumpMaxDeg, ...
        'MakeQcPlots', logical(options.MakeQcPlots));

    imuCorrected = removeGravityFromPreparedImu(imuPrepared, ...
        'UseConjugate', logical(options.UseConjugate), ...
        'MakeQcPlots', logical(options.MakeQcPlots));

    imuEnvelope = computeAccelerometerMotionEnvelope(imuCorrected, ...
        'FrequencyBandHz', options.FrequencyBandHz, ...
        'EnvelopeWindowSeconds', options.EnvelopeWindowSeconds, ...
        'MakePlots', logical(options.MakeQcPlots));

    motionData = struct();
    motionData.timeSec = imuEnvelope.timeSec;
    motionData.motionEnvelope = imuEnvelope.envelope.rms;
    motionData.gravityCorrectedAcc = imuCorrected.acc.linear;
    motionData.meta = struct();
    motionData.meta.sourceMatPath = string(inputMatPath);
    motionData.meta.sourceFileName = string(matFiles(fileIndex).name);
    motionData.meta.sampleRateHz = imuEnvelope.samplingFrequency;
    motionData.meta.frequencyBandHz = options.FrequencyBandHz;
    motionData.meta.envelopeWindowSeconds = options.EnvelopeWindowSeconds;
    motionData.meta.quaternionJumpMaxDeg = options.QuaternionJumpMaxDeg;
    motionData.meta.useConjugate = logical(options.UseConjugate);
    motionData.meta.accelerationUnit = 'g';
    motionData.meta.outputCreatedBy = mfilename;
    if isfield(accData, 'meta')
        motionData.meta.sourceMeta = accData.meta;
    end

    outputName = replace(string(matFiles(fileIndex).name), ".mat", "_motionEnvelope.mat");
    outputMatPath = fullfile(outputRoot, char(outputName));
    save(outputMatPath, 'motionData');

    summaryRows(fileIndex).inputMatPath = string(inputMatPath);
    summaryRows(fileIndex).outputMatPath = string(outputMatPath);
    summaryRows(fileIndex).nSamples = numel(imuEnvelope.timeSec);
    summaryRows(fileIndex).sampleRateHz = imuEnvelope.samplingFrequency;

end

runSummary = struct2table(summaryRows);
save(fullfile(outputRoot, 'runSummary.mat'), 'runSummary');

end
