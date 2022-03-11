function Deploy_MotoTrak_V1p1

%
%Deploy_MotoTrak_V1p1.m - Vulintus, Inc.
%
%   Deploy_MotoTrak_V1p1 collates all of the *.m file dependencies for the
%   MotoTrak program into a single *.m file and creates time-stamped
%   back-up copies of each file when a file modification is detected. It
%   will offer to compile an executable of the program, and will then
%   bundle the executable with associated deployment files and will
%   automatically upload that zip file to the Vulintus download page.
%
%   UPDATE LOG:
%   01/13/2016 - Drew Sloan - Ensured backup location was always in the
%       same directory as the 'MotoTrak_Startup.m' initialization script.
%   04/28/2016 - Drew Sloan - Renamed MotoTrak 2.0 to MotoTrak 1.1 to limit
%       confusion with new C-code 2.0 version.
%   08/08/2016 - Drew Sloan - Transfered most functionality to the new
%       generalized Vulintus_Collate_Functions.m script.
%   09/09/2016 - Drew Sloan - Added the web installer compiler time to the
%       updates HTML page.
%   09/12/2016 - Drew Sloan - Modified the upload code to allow for
%       versioning of the installer.
%

cur_ver = 1.26;                                                             %Specify the current program version.

start_script = 'MotoTrak_Startup.m';                                        %Set the expected name of the initialization script.
ver_str = num2str(cur_ver,'v%1.2f');                                        %Convert the version number to a string.
ver_str(ver_str == '.') = 'p';                                              %Replace the period in the version string with a lower-case "p".
collated_filename = sprintf('MotoTrak_%s.m',ver_str);                       %Set the name for the collated script.
update_url = ['https://docs.google.com/document/d/17CJ3AGDdGpCCzpn7DSFh'...
    'LbpvM1ILJx9W35F47wnOTDg/pub'];                                         %Specify the URL where program updates will be described.
web_file = 'mototrak_updates.html';                                         %Specify the name of the updates HTML page.

[collated_file, zip_file] = ...
    Vulintus_Collate_Functions(start_script, collated_filename);            %Call the generalized function-collating script.

% Vulintus_Upload_File(collated_file, 'public_html/downloads/');              %Upload the collated file to the Vulintus downloads page.
% Vulintus_Upload_File(zip_file, 'public_html/downloads/');                   %Upload the zipped functions file to the Vulintus downloads page.

installer_dir = which(start_script);                                        %Grab the full path of the initialization script.
installer_dir(end-length(start_script)+1:end) = [];                         %Kick out the filename from the full path.
installer_dir = [installer_dir 'Web Installer\'];                           %Set the expected name of the web installer folder.
compile_time = 'na';                                                        %Assume the web installer compile time can't be determined by default.
if exist(installer_dir,'dir')                                               %If the web installer directory exists...
    file = [installer_dir 'MotoTrak_Installer_' ver_str '_win64.exe'];      %Set the expected file name of the web installer.
    if exist(file,'file')                                                   %If the web installer exists...
        Vulintus_Upload_File(file, 'public_html/downloads/');               %Upload the MotoTrak Analysis Web Installer to the Vulintus downloads page.
        info = dir(file);                                                   %Grab the file information.
        compile_time = info.date;                                           %Grab the last modified date for the web installer.
    else                                                                    %Otherwise...
        warning(['WARNING: Could not find the MotoTrak Installer v%1.2f'...
            ' %s executable.'],cur_ver);                                    %Show a warning.
    end
else                                                                        %Otherwise...
    warning(['WARNING: Could not find the MotoTrak Web Installer '...
        'directory.']);                                                     %Show a warning.
end

% web_file = [tempdir web_file];                                              %Create the updates HTML file in the temporary folder.
% fid = fopen(web_file,'wt');                                                 %Open the updates HTML file for writing as text.
% fprintf(fid,'<HTML><p>MOTOTRAK</p><p>CURRENT VERSION: ');                   %Write the HTML start tag to the file.
% fprintf(fid,'%1.2f</p><p>COMPILE TIME: ',cur_ver);                          %Write the the current program version to the file.
% fprintf(fid,'%s</p><p>UPDATE URL: ',compile_time);                          %Write the the installer compile time to the file.
% fprintf(fid,'%s</p></HTML>',update_url);                                    %Write the the update URL to the file.
% fclose(fid);                                                                %Close the HTML file.
% Vulintus_Upload_File(web_file, 'public_html/updates/');                     %Upload the updates HTML file to the Vulintus updates page.
% delete(web_file);                                                           %Delete the temporary HTML file.