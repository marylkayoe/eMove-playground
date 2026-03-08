function app = launchBodypartGroupingHelper(trialDataInput, varargin)
% launchBodypartGroupingHelper Interactive helper to assign markers to bodypart groups.
%
% Usage:
%   launchBodypartGroupingHelper('/path/to/subj.mat')
%   launchBodypartGroupingHelper(trialDataStruct, 'initialCsv', '/path/bodypart_marker_template.csv')
%
% Buttons:
%   - Set Group: assign selected rows to a group name
%   - Clear Group: clear group for selected rows
%   - Save CSV: save marker-level assignment CSV
%   - Export MAT: save groupedMarkerNames/groupedBodypartNames MAT
%
% Output:
%   app - struct with figure handle

    p = inputParser;
    addRequired(p, 'trialDataInput');
    addParameter(p, 'initialCsv', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'outputDir', '', @(x) ischar(x) || isstring(x));
    parse(p, trialDataInput, varargin{:});

    initialCsv = char(string(p.Results.initialCsv));
    outputDir = char(string(p.Results.outputDir));
    if isempty(outputDir)
        outputDir = fullfile(pwd, 'resources', 'templates');
    end

    [markerTbl, ~] = createBodypartGroupingTemplateFromTrialData(trialDataInput);
    markerTbl.markerName = string(markerTbl.markerName);
    markerTbl.groupName = string(markerTbl.groupName);
    markerTbl.suggestedGroup = string(markerTbl.suggestedGroup);
    markerTbl.notes = string(markerTbl.notes);
    markerTbl.include = logical(markerTbl.include);

    if ~isempty(initialCsv) && isfile(initialCsv)
        markerTbl = localMergeInitialCsv(markerTbl, initialCsv);
    end

    state.markerTbl = markerTbl;
    state.viewIdx = (1:height(markerTbl))';
    state.selectedViewRows = [];
    state.filterText = '';

    fig = figure( ...
        'Name', 'Bodypart Grouping Helper', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Units', 'normalized', ...
        'Position', [0.08 0.08 0.84 0.82], ...
        'Color', [0.96 0.96 0.96]);

    uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.02 0.95 0.08 0.03], 'String', 'Filter:', ...
        'HorizontalAlignment', 'left', 'BackgroundColor', get(fig, 'Color'));

    hFilter = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.09 0.95 0.22 0.035], 'String', '');

    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.32 0.95 0.08 0.035], 'String', 'Apply', ...
        'Callback', @onApplyFilter);

    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.41 0.95 0.08 0.035], 'String', 'Reset', ...
        'Callback', @onResetFilter);

    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.54 0.95 0.09 0.035], 'String', 'Set Group', ...
        'Callback', @onSetGroup);

    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.64 0.95 0.09 0.035], 'String', 'Clear Group', ...
        'Callback', @onClearGroup);

    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.76 0.95 0.09 0.035], 'String', 'Save CSV', ...
        'Callback', @onSaveCsv);

    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.86 0.95 0.11 0.035], 'String', 'Export MAT', ...
        'Callback', @onExportMat);

    hStatus = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.02 0.01 0.96 0.03], ...
        'String', '', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', get(fig, 'Color'));

    hTable = uitable(fig, ...
        'Units', 'normalized', ...
        'Position', [0.02 0.08 0.72 0.86], ...
        'ColumnName', {'markerName', 'suggestedGroup', 'groupName', 'include', 'notes'}, ...
        'ColumnEditable', [false false true true true], ...
        'ColumnFormat', {'char', 'char', 'char', 'logical', 'char'}, ...
        'CellSelectionCallback', @onCellSelect, ...
        'CellEditCallback', @onCellEdit);

    hGroupTable = uitable(fig, ...
        'Units', 'normalized', ...
        'Position', [0.76 0.08 0.22 0.84], ...
        'ColumnName', {'groupName', 'markerCount', 'markerList'}, ...
        'ColumnEditable', [false false false], ...
        'ColumnFormat', {'char', 'numeric', 'char'});

    refreshTables();
    setStatus(sprintf('Loaded %d markers.', height(state.markerTbl)));

    app = struct();
    app.figure = fig;

    function refreshTables()
        T = state.markerTbl(state.viewIdx, :);
        tableData = [cellstr(T.markerName), cellstr(T.suggestedGroup), cellstr(T.groupName), ...
            num2cell(T.include), cellstr(T.notes)];
        set(hTable, 'Data', tableData);

        [~, ~, groupTbl] = buildMarkerGroupsFromAssignmentTable(state.markerTbl);
        gData = [cellstr(groupTbl.groupName), num2cell(groupTbl.markerCount), cellstr(groupTbl.markerList)];
        set(hGroupTable, 'Data', gData);
    end

    function setStatus(msg)
        set(hStatus, 'String', msg);
    end

    function onApplyFilter(~, ~)
        state.filterText = strtrim(char(get(hFilter, 'String')));
        if isempty(state.filterText)
            state.viewIdx = (1:height(state.markerTbl))';
        else
            m = contains(upper(state.markerTbl.markerName), upper(state.filterText)) | ...
                contains(upper(state.markerTbl.groupName), upper(state.filterText)) | ...
                contains(upper(state.markerTbl.suggestedGroup), upper(state.filterText));
            state.viewIdx = find(m);
        end
        state.selectedViewRows = [];
        refreshTables();
        setStatus(sprintf('Filter "%s": %d rows', state.filterText, numel(state.viewIdx)));
    end

    function onResetFilter(~, ~)
        set(hFilter, 'String', '');
        state.filterText = '';
        state.viewIdx = (1:height(state.markerTbl))';
        state.selectedViewRows = [];
        refreshTables();
        setStatus('Filter reset.');
    end

    function onCellSelect(~, evt)
        if isempty(evt.Indices)
            state.selectedViewRows = [];
        else
            state.selectedViewRows = unique(evt.Indices(:,1));
        end
        setStatus(sprintf('Selected %d row(s).', numel(state.selectedViewRows)));
    end

    function onCellEdit(src, evt)
        rowView = evt.Indices(1);
        col = evt.Indices(2);
        if rowView < 1 || rowView > numel(state.viewIdx)
            return;
        end
        rowAll = state.viewIdx(rowView);
        newVal = evt.NewData;

        switch col
            case 3
                state.markerTbl.groupName(rowAll) = upper(strtrim(string(newVal)));
            case 4
                state.markerTbl.include(rowAll) = logical(newVal);
            case 5
                state.markerTbl.notes(rowAll) = string(newVal);
        end
        refreshTables();
    end

    function onSetGroup(~, ~)
        if isempty(state.selectedViewRows)
            setStatus('Select rows first.');
            return;
        end
        answer = inputdlg({'Group name (e.g., HEAD, TORSO, HAND_L):'}, ...
            'Set Group', 1, {''});
        if isempty(answer)
            return;
        end
        g = upper(strtrim(string(answer{1})));
        if g == ""
            setStatus('Group name cannot be empty.');
            return;
        end
        rowsAll = state.viewIdx(state.selectedViewRows);
        state.markerTbl.groupName(rowsAll) = g;
        refreshTables();
        setStatus(sprintf('Assigned %d row(s) to %s.', numel(rowsAll), g));
    end

    function onClearGroup(~, ~)
        if isempty(state.selectedViewRows)
            setStatus('Select rows first.');
            return;
        end
        rowsAll = state.viewIdx(state.selectedViewRows);
        state.markerTbl.groupName(rowsAll) = "";
        refreshTables();
        setStatus(sprintf('Cleared group in %d row(s).', numel(rowsAll)));
    end

    function onSaveCsv(~, ~)
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end
        [f, p] = uiputfile('*.csv', 'Save marker grouping CSV', ...
            fullfile(outputDir, 'bodypart_marker_grouping.csv'));
        if isequal(f, 0)
            return;
        end
        outPath = fullfile(p, f);
        writetable(state.markerTbl, outPath);
        setStatus(sprintf('Saved CSV: %s', outPath));
    end

    function onExportMat(~, ~)
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end
        [f, p] = uiputfile('*.mat', 'Export grouped marker MAT', ...
            fullfile(outputDir, 'bodypart_grouping.mat'));
        if isequal(f, 0)
            return;
        end
        outPath = fullfile(p, f);
        [groupedMarkerNames, groupedBodypartNames, groupTbl] = ...
            buildMarkerGroupsFromAssignmentTable(state.markerTbl);
        markerAssignmentTable = state.markerTbl; %#ok<NASGU>
        save(outPath, 'groupedMarkerNames', 'groupedBodypartNames', 'groupTbl', 'markerAssignmentTable');
        setStatus(sprintf('Saved MAT: %s', outPath));
    end
end

function markerTbl = localMergeInitialCsv(markerTblBase, initialCsv)
    opts = detectImportOptions(initialCsv, 'VariableNamingRule', 'preserve');
    wantStr = {'markerName','groupName','notes'};
    present = intersect(wantStr, opts.VariableNames, 'stable');
    if ~isempty(present)
        opts = setvartype(opts, present, 'string');
    end
    T0 = readtable(initialCsv, opts);
    if ~ismember('include', T0.Properties.VariableNames)
        T0.include = true(height(T0), 1);
    end
    T0.markerName = string(T0.markerName);
    T0.groupName = upper(strtrim(string(T0.groupName)));
    T0.include = logical(T0.include);

    markerTbl = markerTblBase;
    [isMember, loc] = ismember(markerTbl.markerName, T0.markerName);
    markerTbl.groupName(isMember) = T0.groupName(loc(isMember));
    markerTbl.include(isMember) = T0.include(loc(isMember));
    if ismember('notes', T0.Properties.VariableNames)
        markerTbl.notes(isMember) = string(T0.notes(loc(isMember)));
    end
end
