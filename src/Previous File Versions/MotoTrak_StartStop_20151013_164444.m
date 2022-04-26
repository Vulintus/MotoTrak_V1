function MotoTrak_StartStop(hObject,~)

%This function is called when an user hits the Start/Stop button on
%MotoTrak.

global run                                                                  %Create the global run variable.

handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
if run > 0                                                                  %If a session is currently running...
    run = -2;                                                               %Set the run variable to -2 to stop the session.    
    set(handles.startbutton,'enable','off');                                %Disable the start/stop button until a new stage is selected.
    set(handles.pausebutton,'enable','off');                                %Disable the pause button.
    set(handles.feedbutton,'enable','off');                                 %Disable the manual feeding button.    
else                                                                        %Otherwise, if the program is currently idling...
    set(handles.startbutton,'string','STOP','foregroundcolor',[0.5 0 0]);   %Change the string on the Start/Stop button to make it say 'STOP'.
    MotoTrak_Disable_Controls_Within_Session(handles);
    MotoTrak_Behavior_Loop(handles);                                        %Start the main behavior loop.
end