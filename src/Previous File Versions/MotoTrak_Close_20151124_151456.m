function MotoTrak_Close(~,~,handles)

%This function is called when the user attempts to close the GUI.

global run                                                                  %Create the global run variable.

if run ~= 0                                                                 %If any program is currently running...
    run = 0;                                                                %Set the run variable to 0.
    pause(0.5);                                                             %Pause for 500 milliseconds to give any loops a chance to wrap up.
end
handles.ardy.stream_enable(0);                                              %Double-check that streaming on the Arduino is disabled.
handles.ardy.clear();                                                       %Clear any leftover stream output.
fclose(handles.ardy.serialcon);                                             %Delete the serial connection to the Arduino.
delete(handles.mainfig);                                                    %Delete the main figure.