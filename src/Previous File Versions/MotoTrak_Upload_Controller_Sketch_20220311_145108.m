function MotoTrak_Upload_Controller_Sketch(port,ver,msgbox)

%
%MotoTrak_Upload_Controller_Sketch.m - Vulintus, Inc.
%
%   This function calls uploads a new sketch to the MotoTrak controller
%   using the avrdude.exe program.
%
%   UPDATE LOG:
%   04/27/2018 - Drew Sloan - First function implementation.
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
    end
end

if ~exist([prog_path '\avrdude.exe'],'file') || ...
        ~exist([prog_path '\avrdude.conf'],'file')                          %If avrdude.exe or it's configuration file aren't found...
        warning([upper(mfilename) ':AvrdudeNotFound'],['The '...
            '"avrdude.exe" program isn''t in the current directory!']);     %Show a warning.
    return                                                                  %Skip execution of the function.
end

hex_files = dir([prog_path '\MotoTrak_Controller_V*.ino.hex']);             %Find all hex files in the path.
if isempty(hex_files)                                                       %If no matching hex files were found...
    warning([upper(mfilename) ':NoHexFilesFound'],['No MotoTrak '...
        '*.ino.hex files files were found in the current directory!']);     %Show a warning.
    return                                                                  %Skip execution of the function.
end

for i = 1:length(hex_files)                                                 %Step through each hex file.
    a = find(hex_files(i).name == 'V',1,'last');                            %Find the last "V" in the filename.
    b = strfind(hex_files(i).name,'.ino.hex');                              %Find the start of the file extension.        
    str = hex_files(i).name(a+1:b-1);                                       %Pull the version number out of the filename.
    str(str == '_') = '.';                                                  %Replace all underscores with periods.
    hex_files(i).ver = str2double(str);                                     %Convert the string to a number.
end
i = vertcat(hex_files.ver) == max(vertcat(hex_files.ver));                  %Identify the most recent file.
hex_files = hex_files(i);                                                   %Keep only the most recent file.

str = sprintf('Updating controller microcode to V%1.1f...',...
    hex_files(1).ver);                                                      %Create a message showing the new microcode version.
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