function Mototrak_Open_Configuration_Directory(~,~)

%
%Mototrak_Open_Configuration_Directory.m - Vulintus, Inc.
%
%   Mototrak_Open_Configuration_Directory is called whenever the user 
%   selects "Configuration Files..." from the MotoTrak GUI Preferences
%   menu. The function opens the local AppData folder containing the 
%   MotoTrak configuration files.
%
%   UPDATE LOG:
%   08/17/2018 - Drew Sloan - First function implementation, adapted from 
%       "Mototrak_Open_Error_Reports.m".
%

handles = guidata(gcbf);                                                    %Grab the handles structure from the main figure.
system(['explorer ' handles.mainpath]);                                     %Open the configuration directory in Windows Explorer.