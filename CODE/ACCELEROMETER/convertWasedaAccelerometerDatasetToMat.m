function conversionSummary = convertWasedaAccelerometerDatasetToMat(rawRoot, varargin)
%CONVERTWASEDAACCELEROMETERDATASETTOMAT Convert Waseda WTAcc CSV files to MAT files.
%
% Purpose
%   Convert raw Waseda WTAcc CSV files into MATLAB MAT files. When
%   requested, CSV chunks from the same recording are concatenated before
%   saving.
%
% Inputs
%   rawRoot   - Root folder of the Waseda accelerometer dataset.
%
% Name-value options
%   outputRoot         - Folder where converted MAT files will be written.
%                        Default is fullfile(rawRoot, 'MATLAB-CONVERTED').
%   concatenateChunks  - If true, consecutive chunk files from the same
%                        recording are concatenated into one MAT file.
%                        Default is false.
%
% Output
%   conversionSummary  - Table with one row per written MAT file. Columns:
%                        matPath, nSamples, sampleRateHz, nSourceCsvFiles
%
% Side effects
%   Writes MAT files and README.md directly into the output folder.
%
% Important assumptions
%   WTAcc chunk files use stems ending in `_0`, `_1`, `_2`, ... for pieces
%   of the same recording.

%% Parse inputs
p = inputParser;
p.addRequired('rawRoot', @(x) ischar(x) || isstring(x));
p.addParameter('outputRoot', "", @(x) ischar(x) || isstring(x));
p.addParameter('concatenateChunks', false, @(x) islogical(x) || isnumeric(x));
p.parse(rawRoot, varargin{:});

rawRoot = char(string(p.Results.rawRoot));
outputRoot = char(string(p.Results.outputRoot));
concatenateChunks = logical(p.Results.concatenateChunks);

if ~isfolder(rawRoot)
    error('convertWasedaAccelerometerDatasetToMat:MissingRawRoot', ...
        'Raw root folder not found: %s', rawRoot);
end

if isempty(outputRoot)
    outputRoot = fullfile(rawRoot, 'MATLAB-CONVERTED');
end

if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

%% Find source CSV files
csvListing = dir(fullfile(rawRoot, '**', '*.csv'));
if isempty(csvListing)
    error('convertWasedaAccelerometerDatasetToMat:NoCsvFiles', ...
        'No CSV files found under: %s', rawRoot);
end

isConvertedFolder = startsWith(string({csvListing.folder}), string(outputRoot));
csvListing = csvListing(~isConvertedFolder);

if isempty(csvListing)
    error('convertWasedaAccelerometerDatasetToMat:OnlyConvertedFilesFound', ...
        'CSV search found no raw source files outside the output folder.');
end

csvPaths = fullfile({csvListing.folder}, {csvListing.name});
csvPaths = sort(csvPaths);

%% Convert files
matPathColumn = strings(0, 1);
nSamplesColumn = zeros(0, 1);
sampleRateHzColumn = nan(0, 1);
nSourceCsvFilesColumn = zeros(0, 1);
usedOutputStems = strings(0, 1);
fileIndex = 1;

while fileIndex <= numel(csvPaths)
    currentCsvPath = csvPaths{fileIndex};
    [currentFolder, currentStem] = fileparts(currentCsvPath);

    currentChunkToken = regexp(currentStem, '^(.*)_(\d+)$', 'tokens', 'once');
    if isempty(currentChunkToken)
        currentRecordingStem = string(currentStem);
        currentChunkNumber = NaN;
    else
        currentRecordingStem = string(currentChunkToken{1});
        currentChunkNumber = str2double(currentChunkToken{2});
    end

    sourceCsvPaths = string(currentCsvPath);
    chunkNumbers = currentChunkNumber;
    outputStem = string(currentStem);
    nextFileIndex = fileIndex + 1;

    if concatenateChunks
        outputStem = currentRecordingStem;

        while nextFileIndex <= numel(csvPaths)
            nextCsvPath = csvPaths{nextFileIndex};
            [nextFolder, nextStem] = fileparts(nextCsvPath);

            nextChunkToken = regexp(nextStem, '^(.*)_(\d+)$', 'tokens', 'once');
            if isempty(nextChunkToken)
                nextRecordingStem = string(nextStem);
                nextChunkNumber = NaN;
            else
                nextRecordingStem = string(nextChunkToken{1});
                nextChunkNumber = str2double(nextChunkToken{2});
            end

            if ~strcmp(nextFolder, currentFolder)
                break;
            end
            if nextRecordingStem ~= currentRecordingStem
                break;
            end

            sourceCsvPaths(end + 1, 1) = string(nextCsvPath); %#ok<AGROW>
            chunkNumbers(end + 1, 1) = nextChunkNumber; %#ok<AGROW>
            nextFileIndex = nextFileIndex + 1;
        end
    end

    if any(usedOutputStems == outputStem)
        relativeFolderLabel = erase(string(currentFolder), string(rawRoot) + filesep);
        relativeFolderLabel = replace(relativeFolderLabel, filesep, '__');
        outputStem = relativeFolderLabel + '__' + outputStem;
    end
    usedOutputStems(end + 1, 1) = outputStem; %#ok<AGROW>

    outputMatPath = fullfile(outputRoot, char(outputStem) + ".mat");
    outputMatPath = char(outputMatPath);

    accData = importWasedaAccelerometerCsv(sourceCsvPaths(1));
    firstChunkData = accData;

    if numel(sourceCsvPaths) > 1
        sampleStepSec = 1 / firstChunkData.meta.sampleRateHz;
        lastChunkData = firstChunkData;

        for sourceIndex = 2:numel(sourceCsvPaths)
            currentChunkData = importWasedaAccelerometerCsv(sourceCsvPaths(sourceIndex));
            currentChunkTimeSec = accData.timeSec(end) + sampleStepSec + currentChunkData.timeSec;
            accData.acc = [accData.acc; currentChunkData.acc]; %#ok<AGROW>
            accData.quat = [accData.quat; currentChunkData.quat]; %#ok<AGROW>
            accData.timeSec = [accData.timeSec; currentChunkTimeSec]; %#ok<AGROW>
            lastChunkData = currentChunkData;
        end

        accData.meta.nSamples = size(accData.acc, 1);
        accData.meta.accelerationMatrixShape = sprintf('%d x %d', size(accData.acc, 1), size(accData.acc, 2));
        accData.meta.quaternionMatrixShape = sprintf('%d x %d', size(accData.quat, 1), size(accData.quat, 2));
        accData.meta.sampleRateHz = firstChunkData.meta.sampleRateHz;
        accData.meta.sourceCsvPath = "";
        accData.meta.sourceCsvPaths = sourceCsvPaths;
        accData.meta.nSourceCsvFiles = numel(sourceCsvPaths);
        accData.meta.concatenatedChunks = true;
        accData.meta.chunkNumbers = chunkNumbers;
        accData.meta.concatenationMethod = "Append chunk files in numeric suffix order.";
        accData.meta.timeReference = "relative to first sample in first chunk";
        accData.meta.timeStartText = firstChunkData.meta.timeStartText;
        accData.meta.timeEndText = lastChunkData.meta.timeEndText;
        accData.meta.chipTimeStart = firstChunkData.meta.chipTimeStart;
        accData.meta.chipTimeEnd = lastChunkData.meta.chipTimeEnd;
    else
        accData.meta.nSourceCsvFiles = 1;
        accData.meta.sourceCsvPaths = sourceCsvPaths;
        accData.meta.concatenatedChunks = false;
        accData.meta.chunkNumbers = chunkNumbers;
    end

    accData.meta.outputMatPath = string(outputMatPath);
    save(outputMatPath, 'accData');

    matPathColumn(end + 1, 1) = string(outputMatPath); %#ok<AGROW>
    nSamplesColumn(end + 1, 1) = accData.meta.nSamples; %#ok<AGROW>
    sampleRateHzColumn(end + 1, 1) = accData.meta.sampleRateHz; %#ok<AGROW>
    nSourceCsvFilesColumn(end + 1, 1) = accData.meta.nSourceCsvFiles; %#ok<AGROW>

    fileIndex = nextFileIndex;
end

conversionSummary = table(matPathColumn, nSamplesColumn, sampleRateHzColumn, nSourceCsvFilesColumn, ...
    'VariableNames', {'matPath', 'nSamples', 'sampleRateHz', 'nSourceCsvFiles'});

%% Write README
readmePath = fullfile(outputRoot, 'README.md');
fid = fopen(readmePath, 'w', 'n', 'UTF-8');
if fid < 0
    error('convertWasedaAccelerometerDatasetToMat:ReadmeWriteFailed', ...
        'Could not write README file: %s', readmePath);
end
readmeCleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Waseda Accelerometer MATLAB-Converted Files\n\n');
fprintf(fid, 'This folder contains MATLAB `.mat` versions of the raw WTAcc CSV files from the Waseda standing accelerometer dataset.\n\n');
fprintf(fid, '## What The Data Is\n\n');
fprintf(fid, '- Source root: `%s`\n', rawRoot);
fprintf(fid, '- Converted folder: `%s`\n', outputRoot);
fprintf(fid, '- Source files: raw WTAcc CSV files from the original dataset\n');
fprintf(fid, '- Sensors in the raw dataset include chest and left forearm placements, depending on session and file naming\n');
fprintf(fid, '- These converted files preserve the raw accelerometer signal in MATLAB-native form\n');
fprintf(fid, '- Files are written into one flat folder; when sensor stems would collide, source-folder context is added to the MAT filename\n\n');

fprintf(fid, '## About Chunked Files\n\n');
fprintf(fid, '- The WTAcc sensor can split one longer recording into multiple CSV files when the recording is too long\n');
fprintf(fid, '- Files with trailing names such as `_0`, `_1`, `_2`, or `_3` should be interpreted as chunks from the same recording stream\n');
if concatenateChunks
    fprintf(fid, '- This conversion run used `concatenateChunks = true`, so matching chunk files were concatenated into one MAT file per recording stream\n\n');
else
    fprintf(fid, '- This conversion run used `concatenateChunks = false`, so each CSV chunk was converted into its own MAT file\n\n');
end

fprintf(fid, '## How The Files Were Created\n\n');
fprintf(fid, '- Conversion function: `convertWasedaAccelerometerDatasetToMat`\n');
fprintf(fid, '- Single-file importer used for each CSV: `importWasedaAccelerometerCsv`\n');
fprintf(fid, '- Output structure saved in each MAT file: `accData`\n');
fprintf(fid, '- `accData.acc` is an `nSamples x 3` matrix with acceleration columns `[X Y Z]`\n');
fprintf(fid, '- `accData.quat` is an `nSamples x 4` matrix with quaternion columns `[q0 q1 q2 q3]`\n');
fprintf(fid, '- `accData.timeSec` is time in seconds relative to the first sample in the output file\n');
fprintf(fid, '- `accData.meta` stores source paths, sample-rate estimates, units, column names, and basic timing metadata\n\n');

fprintf(fid, '## Important Scope Note\n\n');
if concatenateChunks
    fprintf(fid, '- This conversion step concatenated chunk files only when they were consecutive, in the same folder, and had the same filename stem before the trailing chunk number\n');
else
    fprintf(fid, '- This conversion step did not concatenate chunks across CSV files\n');
end
fprintf(fid, '- This conversion step does not preprocess, filter, or reinterpret the signals\n');
fprintf(fid, '- The purpose is only to make the raw accelerometer signals easier to load and reuse in MATLAB while keeping the original structure explicit\n\n');

fprintf(fid, '## File Count\n\n');
fprintf(fid, '- Source CSV files processed: %d\n', numel(csvPaths));
fprintf(fid, '- Output MAT files written: %d\n', height(conversionSummary));
end
