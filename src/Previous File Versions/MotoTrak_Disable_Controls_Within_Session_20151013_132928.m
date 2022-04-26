function MotoTrak_Disable_Controls_Within_Session(handles)

%This function disables all of the uicontrols that should not be messed 
%with while a session is running

set(handles.editrat,'enable','off');                                        %Disable the rat name editbox.
set(handles.editbooth,'enable','off');                                      %Disable the booth number editbox.
set(handles.editport,'enable','off');                                       %Disable the port editbox.
set(handles.popdevice,'enable','off');                                      %Disable the device pop-up menu.
set(handles.popvns,'enable','off');                                         %Disable the VNS pop-up menu.
set(handles.popstage,'enable','off');                                       %Disable the stage pop-up menu.
set(handles.editpos,'enable','off');                                        %Disable the position editbox.
set(handles.popconst,'enable','off');                                       %Disable the constraint pop-up menu.
set(handles.edithitwin,'enable','off');                                     %Disable the hit window editbox.
set(handles.popunits,'enable','off');                                       %Disable the threshold units pop-up menu.
set(handles.editinit,'enable','off');                                       %Disable the time-out editbox.