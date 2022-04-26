function path = Vulintus_Set_AppData_Path(program)

%
%Vulintus_Set_AppData_Path.m - Vulintus, Inc.
%
%   This function finds and/or creates the local application data folder
%   for Vulintus functions specified by "program".
%   
%   UPDATE LOG:
%   08/05/2016 - Drew Sloan - Function created to replace within-function
%       calls in multiple programs.
%

local = winqueryreg('HKEY_CURRENT_USER',...
        ['Software\Microsoft\Windows\CurrentVersion\' ...
        'Explorer\Shell Folders'],'Local AppData');                         %Grab the local application data directory.    
path = fullfile(local,'Vulintus','\');                                      %Create the expected directory name for Vulintus data.
if ~exist(path,'dir')                                                       %If the directory doesn't already exist...
    [status, msg, ~] = mkdir(path);                                         %Create the directory.
    if status ~= 1                                                          %If the directory couldn't be created...
        errordlg(sprintf(['Unable to create application data'...
            ' directory\n\n%s\n\nDetails:\n\n%s'],path,msg),...
            'Vulintus Directory Error');                                    %Show an error.
    end
end
path = fullfile(path,program,'\');                                          %Create the expected directory name for MotoTrak data.
if ~exist(path,'dir')                                                       %If the directory doesn't already exist...
    [status, msg, ~] = mkdir(path);                                         %Create the directory.
    if status ~= 1                                                          %If the directory couldn't be created...
        errordlg(sprintf(['Unable to create application data'...
            ' directory\n\n%s\n\nDetails:\n\n%s'],path,msg),...
            [program ' Directory Error']);                                  %Show an error.
    end
end

if strcmpi(program,'mototrak')                                              %If the specified function is MotoTrak.
    oldpath = fullfile(local,'MotoTrak','\');                               %Create the expected name of the previous version appdata directory.
    if exist(oldpath,'dir')                                                 %If the previous version directory exists...
        files = dir(oldpath);                                               %Grab the list of items contained within the previous directory.
        for f = 1:length(files)                                             %Step through each item.
            if ~files(f).isdir                                             	%If the item isn't a directory...
                copyfile([oldpath, files(f).name],path,'f');                %Copy the file to the new directory.
            end
        end
        [status, msg] = rmdir(oldpath,'s');                                 %Delete the previous version appdata directory.
        if status ~= 1                                                      %If the directory couldn't be deleted...
            warning(['Unable to delete application data'...
                ' directory\n\n%s\n\nDetails:\n\n%s'],oldpath,msg);         %Show an warning.
        end
    end
end