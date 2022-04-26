function MotoTrak_Feed_Button_Press(hObject,~)

%
%MotoTrak_Feed_Button_Press.m - Vulintus, Inc.
%
%   This function causes a pellet or liquid reward to be dispensed when an
%   user presses the "FEED" button on the MotoTrak window.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added in the option to feed during idle mode.
%

global run                                                                  %Create the global run variable.

h = guidata(hObject);                                                       %Grab the handles structure from the GUI.
if run > 0                                                                  %If a session is currently running...
    run = 3;                                                                %Set the run variable to 3 to initiate a manual feeding. 
else                                                                        %Otherwise, if the program is currently idling...
    h.ardy.trigger_feeder(1);                                               %Trigger feeding on the Arduino.
end