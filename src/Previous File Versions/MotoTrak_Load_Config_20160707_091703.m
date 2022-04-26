function handles = MotoTrak_Load_Config(handles)

abbrev_fields = {'SESSION DURATION','session_dur';...
    'MAIN DATA LOCATION','datapath'};                                       %List the parameter names that have corresponding abbreviations.

placeholder = [handles.mainpath 'temp_config.temp'];                        %Set the filename for the temporary placeholder file.

if exist(placeholder,'file')                                                %If the placeholder file exists...
    temp = dir(placeholder);                                                %Grab the file information for the placeholder file.
    while exist(placeholder,'file') && now - temp.datenum < 1/86400         %Loop until the placeholder is deleted or until 1 second has passed.
        pause(0.1);                                                         %Pause for 100 milliseconds.
    end
    if exist(placeholder,'file')                                            %If the placeholder still exists...
        delete(placeholder);                                                %Delete the placeholder file.
    end
end

[fid, errmsg] = fopen(placeholder,'wt');                                    %Create a temporary placeholder file.
if fid == -1                                                                %If a file could not be created...
    warndlg(sprintf(['Could not create a placeholder file '...
        'in:\n\n%s\n\nError:\n\n%s'],placeholder,...
        errmsg),'MotoTrak File Write Error');                               %Show a warning.
end
fprintf(fid,'Placeholder Created: %s\n',datestr(now,0));                    %Write the file creation time to the placeholder file.
fclose(fid);                                                                %Close the placeholder file.

[fid, errmsg] = fopen(handles.config_file,'r');                             %Open the configuration file for reading as text.
if fid == -1                                                                %If the file could not be opened...
    warndlg(sprintf(['Could not open the configuration file '...
        'in:\n\n%s\n\nError:\n\n%s'],handles.config_file,...
        errmsg),'MotoTrak File Read Error');                                %Show a warning.
end
txt = fread(fid,'*char');                                                   %Read in the data as characters.
fclose(fid);                                                                %Close the text file.

a = [0; find(txt == 10)];                                                   %Find all carriage returns in the txt data.

for i = 1:length(a) - 1                                                     %Step through all lines in the data.
    ln = txt(a(i)+1:a(i+1)-1)';                                             %Grab the line of text.
    ln(ln == 0) = [];                                                       %Kick out all null characters.
    j = find(ln == ':',1,'first');                                          %Find the first colon separating the parameter name from the value.
    if ~isempty(j) && j > 1                                                 %If a parameter was found for this line.
        field = ln(1:j-1);                                                  %Grab the parameter name.
        val = ln(j+2:end);                                                  %Grab the parameter value.
        j = strcmpi(field,abbrev_fields(:,1));                              %Check to see if the parameter name has a corresponding abbreviations.
        if any(j)                                                           %If the parameter name has a corresponding abbreviation...
            field = abbrev_fields{j,2};                                     %Use the abbreviation as the field name.
        else                                                                %Otherwise...
            field = lower(field);                                           %Convert the field name to all lower-case.
            field(field < 'a' | field > 'z') = 95;                          %Set all non-text characters to underscores.
        end
        j = find(val > 32,1,'first') - 1;                                   %Find the first non-special character in the parameter value.
        if j > 0                                                            %If there were any preceding special characters...
            val(1:j) = [];                                                  %Kick out the leading special characters.
        end
        j = find(val > 32,1,'last') + 1;                                    %Find the last non-special character in the parameter value.
        if j <= length(val)                                                 %If there were any following special characters...
            val(j:end) = [];                                                %Kick out the trailing special characters.
        end
        if all(val >= 45 & val <= 58)                                       %If all of the value characters are numeric characters...
            val = str2double(val);                                          %Convert the value string to a number.
        else                                                                %Otherwise...
            temp = setdiff(val,[32,39,44:59,91,93]);                        %Find all characters that wouldn't work with an eval command.
            if isempty(temp)                                                %If there are no non-evaluatable characters...
                eval(['val = ' val ';']);                                   %Set the field value by evaluating the string.
            end
        end
        handles.(field) = val;                                              %Save the header value to a field with the parameter name.
    end
end