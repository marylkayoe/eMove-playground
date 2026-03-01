function assignments = assignFilesBasedOnMasterList(fileTable, masterList)
    % assignFilesBasedOnMasterList - Assigns files to participants based on a master list of start/stop times.
    %
    % Inputs:
    %   fileTable  - Table with columns: 'filePath', 'parsedTimestamp'.
    %   masterList - Table with columns: 'ParticipantID', 'StartTime', 'EndTime'.
    %
    % Outputs:
    %   assignments - Table with columns: 'filePath', 'parsedTimestamp', 'assignedParticipant'.

    % Validate inputs
    if ~istable(fileTable) || ~ismember('filePath', fileTable.Properties.VariableNames) || ~ismember('parsedTimestamp', fileTable.Properties.VariableNames)
        error('fileTable must be a table with columns "filePath" and "parsedTimestamp".');
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
    assignedParticipants = repmat({''}, height(fileTable), 1);

    % Assign files based on timestamps
    for i = 1:height(fileTable)
        fileTimestamp = timeofday(fileTable.parsedTimestamp(i)); % Extract time of day
        if isnat(fileTimestamp)
            continue; % Skip files with invalid timestamps
        end

        % Find matching participant
        for j = 1:height(masterList)
            if fileTimestamp >= masterList.StartTime(j) && fileTimestamp <= masterList.EndTime(j)
                assignedParticipants{i} = masterList.ParticipantID{j};
                break;
            end
        end
    end

    % Create assignments table
    assignments = fileTable;
    assignments.assignedParticipant = assignedParticipants;
end