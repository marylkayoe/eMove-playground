function fileInventory = getSubjectModalityFileInventory(subjectFolder, varargin)
% getSubjectModalityFileInventory - Build ordered per-modality file inventory for one subject.
%
% Scope:
%   Discovery and ordering only. No signal computation.
%   Useful when HR/EDA recordings are split across multiple files.
%
% Usage:
%   inv = getSubjectModalityFileInventory('/study/AB1502')
%
% Output table columns:
%   subjectID, modality, orderInModality, fileName, filePath,
%   fileBytes, fileModified, startTimeHint, endTimeHint

    p = inputParser;
    addRequired(p, 'subjectFolder', @(x) ischar(x) || isstring(x));
    addParameter(p, 'modalities', {'mocap','unitylogs','hr','eda'}, @(x) iscell(x) || isstring(x));
    parse(p, subjectFolder, varargin{:});

    subjectFolder = char(string(p.Results.subjectFolder));
    [~, folderName] = fileparts(subjectFolder);
    [subjectID, ~] = normalizeSubjectID(folderName);

    modalities = cellstr(string(p.Results.modalities));

    rows = struct('subjectID', {}, 'modality', {}, 'fileName', {}, 'filePath', {}, ...
        'fileBytes', {}, 'fileModified', {}, 'startTimeHint', {}, 'endTimeHint', {});

    for m = 1:numel(modalities)
        modality = char(modalities{m});
        modDir = fullfile(subjectFolder, modality);
        if ~isfolder(modDir)
            continue;
        end

        files = dir(fullfile(modDir, '*.csv'));
        for k = 1:numel(files)
            f = files(k);
            filePath = fullfile(f.folder, f.name);
            [startHint, endHint] = localTimestampHints(modality, f.name, f.datenum);

            row = struct();
            row.subjectID = subjectID;
            row.modality = modality;
            row.fileName = f.name;
            row.filePath = filePath;
            row.fileBytes = f.bytes;
            row.fileModified = datetime(f.datenum, 'ConvertFrom', 'datenum');
            row.startTimeHint = startHint;
            row.endTimeHint = endHint;
            rows(end+1,1) = row; %#ok<AGROW>
        end
    end

    if isempty(rows)
        fileInventory = table();
        return;
    end

    fileInventory = struct2table(rows);

    % Sorting priority per modality:
    % 1) parsed start time hint when available, 2) file modified time, 3) file name.
    orderInModality = zeros(height(fileInventory), 1);

    modList = unique(fileInventory.modality, 'stable');
    for i = 1:numel(modList)
        mod = modList{i};
        idx = strcmp(fileInventory.modality, mod);

        Tm = fileInventory(idx, :);
        hasStart = ~isnat(Tm.startTimeHint);

        if any(hasStart)
            [~, ord] = sortrows([datenum(Tm.startTimeHint), datenum(Tm.fileModified)]);
        else
            [~, ord] = sortrows([datenum(Tm.fileModified), (1:height(Tm))']);
        end

        localOrder = zeros(height(Tm),1);
        localOrder(ord) = 1:height(Tm);

        orderInModality(idx) = localOrder;
    end

    fileInventory.orderInModality = orderInModality;
    fileInventory = sortrows(fileInventory, {'modality','orderInModality','fileName'});
end

function [startHint, endHint] = localTimestampHints(modality, fileName, fileDatenum)
    startHint = NaT;
    endHint = NaT;

    switch lower(modality)
        case 'unitylogs'
            % Example: AB1502_unitylog_PNr_AB1502_2025-08-14-12-29 x_3502.csv
            tok = regexp(fileName, '(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})', 'tokens', 'once');
            if ~isempty(tok)
                startHint = datetime(tok{1}, 'InputFormat', 'yyyy-MM-dd-HH-mm');
            end

        case 'hr'
            % Example: MovesenseECG-2025-08-25T13_38_04.861101Z.csv
            tok = regexp(fileName, '(\d{4}-\d{2}-\d{2}T\d{2}_\d{2}_\d{2}(?:\.\d+)?Z)', 'tokens', 'once');
            if ~isempty(tok)
                ts = strrep(tok{1}, '_', ':');
                ts = regexprep(ts, 'Z$', '');
                try
                    startHint = datetime(ts, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSSSS', 'TimeZone', 'UTC');
                catch
                    try
                        startHint = datetime(ts, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss', 'TimeZone', 'UTC');
                    catch
                        startHint = NaT;
                    end
                end
            end

        case 'eda'
            % Shimmer exports may not encode timestamp in filename.
            % Keep NaT and rely on file modified as ordering fallback.
    end

    if isnat(startHint)
        startHint = datetime(fileDatenum, 'ConvertFrom', 'datenum');
    end
    endHint = startHint;
end
