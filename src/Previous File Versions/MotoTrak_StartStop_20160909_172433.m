function MotoTrak_StartStop(hObject,~)

%
%MotoTrak_StartStop.m - Vulintus, Inc.
%
%   This function starts or stops a MotoTrak Behavioral session when the
%   user presses the "START"/"STOP" button on the MotoTrak GUI.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Removed automatic disabling of the feed
%       button when stopping a session.
%

global run                                                                  %Create the global run variable.

handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
if run > 0                                                                  %If a session is currently running...
    run = -2;                                                               %Set the run variable to -2 to stop the session.    
    set(handles.startbutton,'enable','off');                                %Disable the start/stop button until a new stage is selected.
    set(handles.pausebutton,'enable','off');                                %Disable the pause button.   
else                                                                        %Otherwise, if the program is currently idling...
    set(handles.startbutton,'string','STOP','foregroundcolor',[0.5 0 0]);   %Change the string on the Start/Stop button to make it say 'STOP'.
    MotoTrak_Disable_Controls_Within_Session(handles);                      %Disable all of the uicontrols and uimenus during the session.
    MotoTrak_Behavior_Loop(handles);                                        %Start the main behavior loop.
end