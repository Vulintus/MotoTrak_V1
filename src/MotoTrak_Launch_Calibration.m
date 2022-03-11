function MotoTrak_Launch_Calibration(device,ardy)

%
%MotoTrak_Launch_Pull_Calibration.m - Vulintus, Inc.
%
%   MotoTrak_Launch_Pull_Calibration closes the main MotoTrak figure and
%   launches the GUI for calibrating the MotoTrak Isometric Pull Module.
%   
%   UPDATE LOG:
%   01/09/2017 - Drew Sloan - Removed the global run variable and removed
%       the input arguments for use as a uicontrol-initiated function.
%

switch device                                                               %Switch between the available MotoTrak devices...
    case 'pull'                                                             %If the current device is the pull...
        MotoTrak_Pull_Calibration(ardy);                                    %Call the isometric pull calibration, passing the Arduino control structure.
    case 'knob'                                                             %If the current device is the knob...
    case 'lever'                                                            %If the current device is the lever...
        MotoTrak_Lever_Calibration(ardy);                                   %Call the lever calibration, passing the arduino control structure.
end               

% MotoTrak_Startup(handles);                                                  %Relaunch the MotoTrak startup script.