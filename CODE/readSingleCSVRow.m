function rowContent = readSingleCSVRow(fullFilePath, rowIdx)
% readSingleCSVRow - Reads a specific row from a CSV file.
%
%   rowContent = readSingleCSVRow(fullFilePath, rowIdx)
%       Reads the content of the specified row (rowIdx) from the CSV file
%       located at fullFilePath.
%
%   Inputs:
%       fullFilePath - Full path to the CSV file (string or char).
%       rowIdx       - Row number to read (positive integer).
%
%   Outputs:
%       rowContent   - A cell array containing the content of the specified row.

    % Open the file
    fid = fopen(fullFilePath, 'r');
    if fid < 0
        error('Cannot open file: %s', fullFilePath);
    end

    % Read up to the specified row
    line = '';
    for k = 1:rowIdx
        line = fgetl(fid);
        if ~ischar(line)
            fclose(fid);
            error('File ended before reaching row %d.', rowIdx);
        end
    end
    fclose(fid);

    % Split the row content into a cell array
    rowContent = strsplit(line, ',', 'CollapseDelimiters', false);  % keep empty columns
end