function assignments = assignFilesBasedOnFolders(sourceRoot, masterList)
    % assignFilesBasedOnFolders - Assigns files to participants based on folder structure and a master list.
    %
    % Inputs:
    %   sourceRoot - Root directory containing the data files.
    %   masterList - Table with columns: 'ParticipantID', 'StartTime', 'EndTime'.
    %
    % Outputs:
    %   assignments - Table with columns: 'filePath', 'parsedTimestamp', 'assignedParticipant'.

    % Validate inputs
    if ~isfolder(sourceRoot)
        error('Source root directory does not exist: %s', sourceRoot);
    end
    if ~istable(masterList) || ~ismember('ParticipantID', masterList.Properties.VariableNames) || ...
            ~ismember('StartTime', masterList.Properties.VariableNames) || ~ismember('EndTime', masterList.Properties.VariableNames)
        error('masterList must be a table with columns "ParticipantID", "StartTime", and "EndTime".');
    end

    % Ensure StartTime and EndTime are durations
    if ~isduration(masterList.StartTime)
        masterList.StartTime = duration(masterList.StartTime);
    end
    if ~isduration(masterList.EndTime)
        masterList.EndTime = duration(masterList.EndTime);
    end

    % Initialize assignments
    rows = [];

    % Recursively find all files in the source root
    allFiles = dir(fullfile(sourceRoot, '**', '*.*'));
    allFiles = allFiles(~[allFiles.isdir]); % Exclude directories

    for i = 1:numel(allFiles)
        filePath = fullfile(allFiles(i).folder, allFiles(i).name);

        % Attempt to parse timestamp from the file name
        parsedTimestamp = NaT;
        try
            parsedTimestamp = parseTimestampFromFileName(allFiles(i).name);
        catch
            % Skip files with unparseable timestamps
            continue;
        end

        % Assign participant based on the master list
        assignedParticipant = 'UNKNOWN';
        fileTime = timeofday(parsedTimestamp);
        for j = 1:height(masterList)
            if fileTime >= masterList.StartTime(j) && fileTime <= masterList.EndTime(j)
                assignedParticipant = masterList.ParticipantID{j};
                break;
            end
        end

        % Add to assignments
        rows = [rows; struct('filePath', filePath, 'parsedTimestamp', parsedTimestamp, 'assignedParticipant', assignedParticipant)]; %#ok<AGROW>
    end

    % Convert to table
    assignments = struct2table(rows);
end

function parsedTimestamp = parseTimestampFromFileName(fileName)
    % parseTimestampFromFileName - Extracts a timestamp from a file name.
    %
    % Inputs:
    %   fileName - Name of the file to parse.
    %
    % Outputs:
    %   parsedTimestamp - Datetime object representing the parsed timestamp.

    % Define patterns for common timestamp formats
    patterns = {
        'Take (\\d{4}-\\d{2}-\\d{2} \\d{2}\\.\\d{2}\\.\\d{2})', 'yyyy-MM-dd HH.mm.ss';
        '(\\d{4}-\\d{2}-\\d{2}T\\d{2}_\\d{2}_\\d{2})', 'yyyy-MM-dd''T''HH_mm_ss';
        '(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})', 'yyyy-MM-dd HH:mm:ss'
    };

    parsedTimestamp = NaT;
    for i = 1:size(patterns, 1)
        tokens = regexp(fileName, patterns{i, 1}, 'tokens', 'once');
        if ~isempty(tokens)
            parsedTimestamp = datetime(tokens{1}, 'InputFormat', patterns{i, 2});
            break;
        end
    end
end