function MotoTrak_Disable_Controls_Within_Session(handles)

%
%MotoTrak_Disable_Controls_Within_Session.m - Vulintus, Inc.
%
%   This function disables all of the uicontrol and uimenu objects that 
%   should not be active while MotoTrak is running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added disabling of uimenu objects.
%   10/13/2016 - Drew Sloan - Added disabling of the preferences menu.
%

%Disable the uicontrol objects.
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

%Enable the uimenu objects.
set(handles.menu.stages.h,'enable','off');                                  %Disable the stages menu.
set(handles.menu.pref.h,'enable','off');                                    %Disable the preferences menu.
set(handles.menu.cal.h,'enable','off');                                     %Disable the calibration menu.

drawnow;                                                                    %Immediately update the figure.