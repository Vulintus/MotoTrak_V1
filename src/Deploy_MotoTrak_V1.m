function Deploy_MotoTrak_V1

%
%Deploy_MotoTrak_V1.m - Vulintus, Inc.
%
%   DEPLOY_MOTOTRAK_V1 collates all of the *.m file dependencies for the
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
%   04/26/2022 - Drew Sloan - Renamed function to "Deploy_MotoTrak_V1" to 
%       better match the MotoTrak repositories convention.
%

cur_ver = 1.27;                                                             %Specify the current program version.

start_script = 'MotoTrak_Startup.m';                                        %Set the expected name of the initialization script.
ver_str = num2str(cur_ver,'v%1.2f');                                        %Convert the version number to a string.
ver_str(ver_str == '.') = '_';                                              %Replace the period in the version string with an underscore.
collated_filename = sprintf('MotoTrak_%s.m',ver_str);                       %Set the name for the collated script.

[mainpath, cur_dir, ~] = fileparts(which('Deploy_MotoTrak_V1.m'));          %Strip out the filename from the path to this m-file.
while ~strcmpi(cur_dir,'MotoTrak V1') && ~isempty(cur_dir)                  %Loop until we get to the "MotoTrak V1" folder.
    [mainpath, cur_dir, ~] = fileparts(mainpath);                           %Strip out the filename from the path.
end
mainpath = fullfile(mainpath,'MotoTrak V1');                                %Add the "MotoTrak V1" directory back to the path.

[collated_file, ~] = Vulintus_Collate_Functions(start_script,...
    fullfile(mainpath,'collated m-files',collated_filename),...
    'depfunfolder','on');                                                   %Call the generalized function-collating script.

copyfile(collated_file, mainpath, 'f');                                     %Copy the collated file to the main path.

[release_path, file, ext] = fileparts(collated_file);                       %Grab the path from the collated filename.
file = [file '_' datestr(now, 'yyyymmdd_HHMMSS') ext];                      %Create a timestamped filename.
file = fullfile(release_path, file);                                        %Add the path back to the file.
copyfile(collated_file, file, 'f');                                         %Create a timestamped copy of the collated file.
delete(collated_file);                                                      %Delete the original collated file.