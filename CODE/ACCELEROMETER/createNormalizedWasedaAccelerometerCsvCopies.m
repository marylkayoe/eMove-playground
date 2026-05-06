function exportSummary = createNormalizedWasedaAccelerometerCsvCopies(varargin)
%CREATENORMALIZEDWASEDAACCELEROMETERCSVCOPIES Export normalized WTAcc CSV copies.
%
% exportSummary = createNormalizedWasedaAccelerometerCsvCopies()
%
% Purpose
%   Create a derived CSV folder with condition-specific filenames and
%   chunk numbering. April 17 files are copied whole by condition folder.
%   April 21 files are split by the collection-note time windows.
%
% Output naming
%   YYYYMMDD_subX_condition_accY_sensor_chunkZ.csv

%% Parse inputs

inputParserObject = inputParser;

defaultRawRoot = '/Users/yoe/Documents/DATA/Waseda-ACC';
defaultOutputRoot = fullfile(defaultRawRoot, 'NORMALIZED-CSV');

addParameter(inputParserObject, 'RawRoot', defaultRawRoot, ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'OutputRoot', defaultOutputRoot, ...
    @(value) ischar(value) || isstring(value));

parse(inputParserObject, varargin{:});

rawRoot = char(string(inputParserObject.Results.RawRoot));
outputRoot = char(string(inputParserObject.Results.OutputRoot));

if ~isfolder(rawRoot)
    error('createNormalizedWasedaAccelerometerCsvCopies:MissingRawRoot', ...
        'Raw root not found: %s', rawRoot);
end

if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

summaryRows = struct( ...
    'outputCsvPath', {}, ...
    'sourceCsvPath', {}, ...
    'sessionId', {}, ...
    'subjectId', {}, ...
    'condition', {}, ...
    'deviceLabel', {}, ...
    'sensorLabel', {}, ...
    'chunkIndex', {}, ...
    'copyMode', {}, ...
    'sourceStartTime', {}, ...
    'sourceEndTime', {}, ...
    'exportStartTime', {}, ...
    'exportEndTime', {}, ...
    'nExportedRows', {});

summaryIndex = 0;

%% 2026-04-17

sessionId = '20260417';
subjectId = 'sub1';
sessionRoot = fullfile(rawRoot, '260417');
conditionFolders = {'work', 'videos'};
conditionNames = {'desk_work_stand', 'watching_videos_stand'};
deviceLabels = {'acc1', 'acc2'};
sensorLabels = {'chest', 'forearm_left'};

for conditionIndex = 1:numel(conditionFolders)

    folderPath = fullfile(sessionRoot, conditionFolders{conditionIndex});

    for deviceIndex = 1:2

        csvFiles = dir(fullfile(folderPath, sprintf('*WTAcc %d*.csv', deviceIndex)));
        csvPaths = fullfile({csvFiles.folder}, {csvFiles.name});
        chunkNumbers = nan(numel(csvPaths), 1);

        for fileIndex = 1:numel(csvPaths)
            [~, stem] = fileparts(csvPaths{fileIndex});
            token = regexp(stem, '_(\d+)$', 'tokens', 'once');
            if ~isempty(token)
                chunkNumbers(fileIndex) = str2double(token{1});
            end
        end

        [~, sortIndex] = sort(chunkNumbers);
        csvPaths = csvPaths(sortIndex);

        for chunkIndex = 1:numel(csvPaths)

            sourceCsvPath = csvPaths{chunkIndex};
            exportCsvName = sprintf('%s_%s_%s_%s_%s_chunk%d.csv', ...
                sessionId, subjectId, conditionNames{conditionIndex}, ...
                deviceLabels{deviceIndex}, sensorLabels{deviceIndex}, chunkIndex - 1);
            outputCsvPath = fullfile(outputRoot, exportCsvName);

            copyfile(sourceCsvPath, outputCsvPath);

            imported = importWasedaAccelerometerCsv(sourceCsvPath);

            summaryIndex = summaryIndex + 1;
            summaryRows(summaryIndex).outputCsvPath = string(outputCsvPath);
            summaryRows(summaryIndex).sourceCsvPath = string(sourceCsvPath);
            summaryRows(summaryIndex).sessionId = string(sessionId);
            summaryRows(summaryIndex).subjectId = string(subjectId);
            summaryRows(summaryIndex).condition = string(conditionNames{conditionIndex});
            summaryRows(summaryIndex).deviceLabel = string(deviceLabels{deviceIndex});
            summaryRows(summaryIndex).sensorLabel = string(sensorLabels{deviceIndex});
            summaryRows(summaryIndex).chunkIndex = chunkIndex - 1;
            summaryRows(summaryIndex).copyMode = "whole_file_copy";
            summaryRows(summaryIndex).sourceStartTime = string(imported.meta.timeStartText);
            summaryRows(summaryIndex).sourceEndTime = string(imported.meta.timeEndText);
            summaryRows(summaryIndex).exportStartTime = string(imported.meta.timeStartText);
            summaryRows(summaryIndex).exportEndTime = string(imported.meta.timeEndText);
            summaryRows(summaryIndex).nExportedRows = imported.meta.nSamples;

        end

    end

end

%% 2026-04-21

sessionId = '20260421';
sessionRoot = fullfile(rawRoot, '260421');
subjectIds = {'sub2', 'sub3', 'sub4'};
subjectWindows = { ...
    {'desk_work_stand', '16:00', '16:10'; 'watching_videos_stand', '16:19', '16:29'}, ...
    {'watching_videos_stand', '16:41', '16:51'; 'desk_work_stand', '16:52', '17:02'}, ...
    {'watching_videos_stand', '17:07', '17:17'; 'desk_work_stand', '17:20', '17:30'}};

for subjectIndex = 1:numel(subjectIds)

    subjectId = subjectIds{subjectIndex};
    subjectRoot = fullfile(sessionRoot, subjectId);
    windows = subjectWindows{subjectIndex};

    for deviceIndex = 1:2

        csvFiles = dir(fullfile(subjectRoot, sprintf('*WTAcc %d*.csv', deviceIndex)));
        csvPaths = fullfile({csvFiles.folder}, {csvFiles.name});
        chunkNumbers = nan(numel(csvPaths), 1);

        for fileIndex = 1:numel(csvPaths)
            [~, stem] = fileparts(csvPaths{fileIndex});
            token = regexp(stem, '_(\d+)$', 'tokens', 'once');
            if ~isempty(token)
                chunkNumbers(fileIndex) = str2double(token{1});
            end
        end

        [~, sortIndex] = sort(chunkNumbers);
        csvPaths = csvPaths(sortIndex);
        exportedChunkCounts = zeros(size(windows, 1), 1);

        for fileIndex = 1:numel(csvPaths)

            sourceCsvPath = csvPaths{fileIndex};
            fileLines = readlines(sourceCsvPath);
            if fileLines(end) == ""
                fileLines(end) = [];
            end

            headerLine = fileLines(1);
            dataLines = fileLines(2:end);
            timeText = strtrim(extractBefore(dataLines, ","));
            timeSec = zeros(numel(timeText), 1);

            for rowIndex = 1:numel(timeText)
                timeSec(rowIndex) = LF_parseClockTimeToSeconds(timeText(rowIndex));
            end

            sourceStartTime = timeText(1);
            sourceEndTime = timeText(end);

            for windowIndex = 1:size(windows, 1)

                conditionName = windows{windowIndex, 1};
                windowStartTime = windows{windowIndex, 2};
                windowEndTime = windows{windowIndex, 3};
                windowStartSec = LF_parseClockTimeToSeconds(windowStartTime);
                windowEndSec = LF_parseClockTimeToSeconds(windowEndTime);
                keepRows = timeSec >= windowStartSec & timeSec <= windowEndSec;

                if ~any(keepRows)
                    continue
                end

                chunkIndex = exportedChunkCounts(windowIndex);
                exportCsvName = sprintf('%s_%s_%s_%s_%s_chunk%d.csv', ...
                    sessionId, subjectId, conditionName, ...
                    deviceLabels{deviceIndex}, sensorLabels{deviceIndex}, chunkIndex);
                outputCsvPath = fullfile(outputRoot, exportCsvName);

                fid = fopen(outputCsvPath, 'w', 'n', 'UTF-8');
                if fid < 0
                    error('createNormalizedWasedaAccelerometerCsvCopies:WriteFailed', ...
                        'Could not write CSV: %s', outputCsvPath);
                end
                cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

                fprintf(fid, '%s\n', headerLine);
                keptLines = dataLines(keepRows);
                for keptIndex = 1:numel(keptLines)
                    fprintf(fid, '%s\n', keptLines(keptIndex));
                end
                clear cleanupObject

                exportedChunkCounts(windowIndex) = exportedChunkCounts(windowIndex) + 1;

                summaryIndex = summaryIndex + 1;
                summaryRows(summaryIndex).outputCsvPath = string(outputCsvPath);
                summaryRows(summaryIndex).sourceCsvPath = string(sourceCsvPath);
                summaryRows(summaryIndex).sessionId = string(sessionId);
                summaryRows(summaryIndex).subjectId = string(subjectId);
                summaryRows(summaryIndex).condition = string(conditionName);
                summaryRows(summaryIndex).deviceLabel = string(deviceLabels{deviceIndex});
                summaryRows(summaryIndex).sensorLabel = string(sensorLabels{deviceIndex});
                summaryRows(summaryIndex).chunkIndex = chunkIndex;
                summaryRows(summaryIndex).copyMode = "time_window_split";
                summaryRows(summaryIndex).sourceStartTime = string(sourceStartTime);
                summaryRows(summaryIndex).sourceEndTime = string(sourceEndTime);
                summaryRows(summaryIndex).exportStartTime = string(timeText(find(keepRows, 1, 'first')));
                summaryRows(summaryIndex).exportEndTime = string(timeText(find(keepRows, 1, 'last')));
                summaryRows(summaryIndex).nExportedRows = sum(keepRows);

            end

        end

    end

end

exportSummary = struct2table(summaryRows);
save(fullfile(outputRoot, 'exportSummary.mat'), 'exportSummary');
writetable(exportSummary, fullfile(outputRoot, 'exportSummary.tsv'), 'FileType', 'text', 'Delimiter', '\t');

readmePath = fullfile(outputRoot, 'README.md');
fid = fopen(readmePath, 'w', 'n', 'UTF-8');
if fid < 0
    error('createNormalizedWasedaAccelerometerCsvCopies:ReadmeWriteFailed', ...
        'Could not write README: %s', readmePath);
end
cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Normalized Waseda Accelerometer CSV Copies\n\n');
fprintf(fid, '- Source root: `%s`\n', rawRoot);
fprintf(fid, '- Output root: `%s`\n', outputRoot);
fprintf(fid, '- Device map:\n');
fprintf(fid, '  - `acc1` = `chest`\n');
fprintf(fid, '  - `acc2` = `forearm_left`\n');
fprintf(fid, '- April 17 export rule: whole-file copies grouped by source folder (`work`, `videos`)\n');
fprintf(fid, '- April 21 export rule: CSV rows split by collection-note time windows\n');
fprintf(fid, '- Naming scheme: `YYYYMMDD_subX_condition_accY_sensor_chunkZ.csv`\n\n');
fprintf(fid, '## Files\n\n');
fprintf(fid, '- Export summary table: `exportSummary.tsv`\n');
fprintf(fid, '- Export summary MAT: `exportSummary.mat`\n');
fprintf(fid, '- Total exported CSV files: %d\n', height(exportSummary));

end

function secondsValue = LF_parseClockTimeToSeconds(clockText)
%LF_PARSECLOCKTIMETOSECONDS Convert HH:MM or HH:MM:SS(.sss) to seconds.

clockParts = split(string(strtrim(clockText)), ':');

if numel(clockParts) == 2
    secondsValue = 3600 * str2double(clockParts(1)) + 60 * str2double(clockParts(2));
elseif numel(clockParts) == 3
    secondsValue = 3600 * str2double(clockParts(1)) + ...
        60 * str2double(clockParts(2)) + str2double(clockParts(3));
else
    error('createNormalizedWasedaAccelerometerCsvCopies:BadClockText', ...
        'Could not parse clock time: %s', char(string(clockText)));
end

end
