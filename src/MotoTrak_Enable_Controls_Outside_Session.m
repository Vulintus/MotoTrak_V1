function MotoTrak_Enable_Controls_Outside_Session(handles)

%
%MotoTrak_Enable_Controls_Outside_Session.m - Vulintus, Inc.
%
%   This function enables all of the uicontrol and uimenu objects that 
%   should be active when MotoTrak is not running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added enabling of uimenu objects.
%   10/13/2016 - Drew Sloan - Added disabling of the preferences menu.
%

%Enable the uicontrol objects.
set(handles.editrat,'enable','on');                                         %Enable the rat name editbox.
set(handles.editbooth,'enable','on');                                       %Enable the booth number editbox.
set(handles.editport,'enable','inactive');                                  %Make the port editbox inactive.
set(handles.popdevice,'enable','on');                                       %Enable the device pop-up menu.
set(handles.popvns,'enable','on');                                          %Enable the VNS pop-up menu.
set(handles.popstage,'enable','on');                                        %Enable the stage pop-up menu.
set(handles.editpos,'enable','on');                                         %Enable the position editbox.

%Enable the uimenu objects.
set(handles.menu.stages.h,'enable','on');                                   %Enable the stages menu.
set(handles.menu.pref.h,'enable','on');                                     %Enable the preferences menu.
set(handles.menu.cal.h,'enable','on');                                      %Enable the calibration menu.