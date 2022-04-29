function MotoTrak_Upload_Controller_Sketch(port,ver,msgbox)

%
%MotoTrak_Upload_Controller_Sketch.m - Vulintus, Inc.
%
%   This function calls uploads a new sketch to the MotoTrak controller
%   using the avrdude.exe program.
%
%   UPDATE LOG:
%   04/27/2018 - Drew Sloan - First function implementation.
%   04/29/2022 - Drew Sloan - Updated the expected path for *.hex files and
%       added build dates to the file convention.
%

if isdeployed                                                               %If this is deployed code...
    prog_path = 'C:\Program Files\Vulintus\MotoTrak\application';           %Set the expected path of the controller hex file program.
else                                                                        %Otherwise, if the code isn't deployed...
    [prog_path,~,~] = ...
        fileparts(which('MotoTrak_Upload_Controller_Sketch.m'));            %Grab the location of the current sketch.    
    if isempty(prog_path)                                                   %If no location was found for the current m-file...
        temp = sprintf('%1.2f',ver);                                        %Convert the version number to a string.
        temp(temp == '.') = 'p';                                            %Change the period to a "p";
        temp = sprintf('MotoTrak_v%s.m',temp);                              %Construct the expected filename.
        [prog_path,~,~] = fileparts(which(temp));                           %Check for the location of the collated MotoTrak m-file.
        if exist(fullfile(prog_path,'resources'),'dir')                     %If there's a "resources" folder in this folder...
            prog_path = fullfile(prog_path,'resources');                    %Set the expected path of the controller hex file program.
        end
    elseif endsWith(prog_path,'src')                                        %If the path ends in "src"...
        [temp,~,~] = fileparts(prog_path);                                  %Drop down one folder level.  
        if exist(fullfile(temp,'resources'),'dir')                          %If there's a "resources" folder in this folder...
            prog_path = fullfile(temp,'resources');                         %Set the expected path of the controller hex file program.
        end
    end    
end

if ~exist([prog_path '\avrdude.exe'],'file') || ...
        ~exist([prog_path '\avrdude.conf'],'file')                          %If avrdude.exe or it's configuration file aren't found...
        warning([upper(mfilename) ':AvrdudeNotFound'],['The '...
            '"avrdude.exe" program isn''t in the current directory!']);     %Show a warning.
    return                                                                  %Skip execution of the function.
end

hex_files = dir([prog_path '\MotoTrak_Controller_V*.hex']);                 %Find all hex files in the path.
if isempty(hex_files)                                                       %If no matching hex files were found...
    warning([upper(mfilename) ':NoHexFilesFound'],['No MotoTrak '...
        '*.hex files files were found in the current directory!']);         %Show a warning.
    return                                                                  %Skip execution of the function.
end

for i = 1:length(hex_files)                                                 %Step through each hex file.
    a = strfind(hex_files(i).name,'.hex');                                  %Find the start of the file extension.        
    str = hex_files(i).name(22:a-10);                                       %Pull the version number out of the filename.
    str(str == '_') = '.';                                                  %Replace all underscores with periods.
    hex_files(i).ver = str2double(str);                                     %Convert the string to a number.
    str = hex_files(i).name(a-8:a-1);                                       %Pull the build date out of the filename.
    hex_files(i).build_date = datenum(str,'yyyymmdd');                      %Convert the string to a serial date number.
end
i = vertcat(hex_files.ver) == max(vertcat(hex_files.ver));                  %Identify the highest version.
hex_files = hex_files(i);                                                   %Keep only the highest version.
if numel(hex_files) > 1                                                     %If there's more than one build of the highest version....
    [~,i] = max(vertcat(hex_files.build_date));                             %Find the newest build.
    hex_files = hex_files(i);                                               %Keep only the highest version.
end

str = sprintf('Updating controller microcode to V%1.1f (%s)...',...
    hex_files(1).ver,datestr(hex_files(1).build_date,'yyyy-mm-dd'));        %Create a message showing the new microcode version.
Add_Msg(msgbox,str);                                                        %Show an "updating..." message in the messagebox.    

%Build the command line call.
cmd = ['"' prog_path '\avrdude" '...                                        %avrdude.exe location
    '-C"' prog_path '\avrdude.conf" '...                                    %avrdude.conf location
    '-patmega328p '...                                                      %microcontroller type
    '-carduino '...                                                         %arduino programmer
    '-P' port ' '...                                                        %port
    '-b115200 '...                                                          %baud rate
    '-D '...                                                                %disable erasing the chip
    '-Uflash:w:"' prog_path '\' hex_files(1).name '":i'];                   %hex file name                             

clc;                                                                        %Clear the command line.
cprintf('*blue','\n%s\n',cmd);                                              %Print the command in bold green.
[status, ~] = dos(cmd,'-echo');                                             %Execute the command in a dos prompt, showing the results.

if status == 0                                                              %If the command was successful...
    Add_Msg(msgbox,'Controller microcode successfully updated!');           %Show a success message in the messagebox.    
else                                                                        %Otherwise...
    Add_Msg(msgbox,'Controller microcode update failed!');                  %Show a failure message in the messagebox.    
    Add_Msg(msgbox,'Reverting to existing controller microcode.');          %Show that we're reverting to the previous microcode.
end

pause(1);                                                                   %Pause for 1 second.