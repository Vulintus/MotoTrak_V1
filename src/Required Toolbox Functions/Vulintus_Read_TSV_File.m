function data = Vulintus_Read_TSV_File(file)

%
%Vulintus_Read_TSV_File.m - Vulintus, Inc.
%
%   Vulintus_Read_TSV_File reads in data from a spreadsheet-formated TSV
%   file.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Moved the TSV-reading code from
%       Vulintus_Read_Stages.m to this function.
%   09/13/2016 - Drew Sloan - Generalized the MotoTrak TSV-reading program
%       to also work with OmniTrak and future behavior programs.
%   04/26/2022 - Drew sloan - Replaced "sprintf('\n')" with MATLAB's
%       built-in "newline" function.
%

[fid, errmsg] = fopen(file,'rt');                                           %Open the stage configuration file saved previously for reading as text.
if fid == -1                                                                %If the file could not be opened...
    warndlg(sprintf(['Could not open the stage file '...
        'in:\n\n%s\n\nError:\n\n%s'],file,...
        errmsg),'Vulintus File Read Error');                                %Show a warning.
    close(fid);                                                             %Close the file.
    data = [];                                                              %Set the output data variable to empty brackets.
    return                                                                  %Return to the calling function.
end
txt = fread(fid,'*char')';                                                  %Read in the file data as text.
fclose(fid);                                                                %Close the configuration file.
tab = sprintf('\t');                                                        %Make a tab string for finding delimiters.
a = find(txt == tab | txt == newline);                                      %Find all delimiters in the string.
a = [0, a, length(txt)+1];                                                  %Add indices for the first and last elements of the string.
txt = [txt, newline];                                                       %Add a new line to the end of the string to avoid confusing the spreadsheet-reading loop.
column = 1;                                                                 %Count across columns.
row = 1;                                                                    %Count down rows.
data = {};                                                                  %Make a cell array to hold the spreadsheet-formated data.
for i = 2:length(a)                                                         %Step through each entry in the string.
    if a(i) == a(i-1)+1                                                     %If there is no entry for this cell...
        data{row,column} = [];                                              %...assign an empty matrix.
    else                                                                    %Otherwise...
        data{row,column} = txt((a(i-1)+1):(a(i)-1));                        %...read one entry from the string.
    end
    if txt(a(i)) == tab                                                     %If the delimiter was a tab or a comma...
        column = column + 1;                                                %...advance the column count.
    else                                                                    %Otherwise, if the delimiter was a new-line...
        column = 1;                                                         %...reset the column count to 1...
        row = row + 1;                                                      %...and add one to the row count.
    end
end