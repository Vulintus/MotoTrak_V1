function MotoTrak_Close(fig)

%
%MotoTrak_Close.m - Vulintus, Inc.
%
%   MotoTrak_Close executes after the main loop terminates, usually because
%   the user closes the figure window.
%   
%   UPDATE LOG:
%   04/28/2021 - Drew Sloan - Switched to the structure-integrated 
%       .close_serialcon() function for 
%   
%

handles = guidata(fig);                                                     %Grab the handles structure from the main GUI.

handles.ardy.stream_enable(0);                                              %Double-check that streaming on the Arduino is disabled.
handles.ardy.close_serialcon();                                             %Call the function to close the serial connection.
delete(handles.mainfig);                                                    %Delete the main figure.