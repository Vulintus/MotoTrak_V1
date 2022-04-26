function MotoTrak_Close(fig)

%
%MotoTrak_Close.m - Vulintus, Inc.
%
%   MotoTrak_Close executes after the main loop terminates, usually because
%   the user closes the figure window.
%   
%   UPDATE LOG:
%

handles = guidata(fig);                                                     %Grab the handles structure from the main GUI.

handles.ardy.stream_enable(0);                                              %Double-check that streaming on the Arduino is disabled.
handles.ardy.clear();                                                       %Clear any leftover stream output.
fclose(handles.ardy.serialcon);                                             %Delete the serial connection to the Arduino.
delete(handles.mainfig);                                                    %Delete the main figure.