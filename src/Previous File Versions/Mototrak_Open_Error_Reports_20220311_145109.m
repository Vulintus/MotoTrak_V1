function Mototrak_Open_Error_Reports(~,~)

%
%Mototrak_Open_Error_Reports.m - Vulintus, Inc.
%
%   Mototrak_Open_Error_Reports is called whenever the user selects "View
%   Error Reports" from the MotoTrak GUI Preferences menu and opens the
%   local AppData folder containing all archived error reports.
%
%   UPDATE LOG:
%   02/21/2017 - Drew Sloan - First function implementation.
%

handles = guidata(gcbf);                                                    %Grab the handles structure from the main figure.
err_path = [handles.mainpath 'Error Reports\'];                             %Create the expected directory name for the error reports.
if ~exist(err_path,'dir')                                                   %If the error report directory doesn't exist...
    mkdir(err_path);                                                        %Create the error report directory.
end
system(['explorer ' err_path]);                                             %Open the error report directory in Windows Explorer.