function MotoTrak_Enable_All_Uicontrols(handles)

%
%MotoTrak_Enable_All_Uicontrols.m - Vulintus, Inc.
%
%   MotoTrak_Enable_All_Uicontrols enables all of the uicontrol and uimenu
%   objects that should  be active while MotoTrak is idling between
%   behavioral sessions.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added enabling of the stages top menu.
%   10/13/2016 - Drew Sloan - Added enabling of the stages top menu.
%

% objs = get(fig,'children');                                                 %Grab all children of the figure.
% i = strcmpi(get(objs,'type'),'uipanel');                                    %Find all uipanel handles.
% while any(i == 1)                                                           %Loop until we've checked all of the uipanels.
%     temp = get(objs(i),'children');                                         %Grab all of the children of the uipanels.
%     objs(i) = [];                                                           %Kick out all previous uipanel handles from the object list.
%     objs = vertcat(objs,temp{:});                                           %Add the panel's objects to the object list.
%     i = strcmpi(get(objs,'type'),'uipanel');                                %Find any new uipanel handles.
% end
% objs(strcmpi(get(objs,'type'),'axes')) = [];                                %Kick out all axes objects.
% i = ~strcmpi(get(objs,'enable'),'inactive');                                %Find all objects that aren't currently inactive.
% set(objs(i),'enable','on');                                                 %Enable all active objects.

set(handles.editrat,'enable','on');                                         %Enable the rat name editbox.
set(handles.editbooth,'enable','on');                                       %Enable booth number setting.
set(handles.editport,'enable','inactive');                                  %Make the port editbox inactive.
set(handles.popdevice,'enable','on');                                       %Enable the device pop-up menu.
% set(handles.popvns,'enable','on');                                          %Enable the VNS pop-up menu.
set(handles.popstage,'enable','on');                                        %Enable the stage pop-up menu.
set(handles.editpos,'enable','on');                                         %Enable the position editbox.
% set(handles.popconst,'enable','on');                                        %Enable the constraint pop-up menu.
% set(handles.edithitwin,'enable','on');                                      %Enable the hit window editbox.
% set(handles.editthresh,'enable','on');                                      %Enable the threshold edit box.
% set(handles.popunits,'enable','on');                                        %Enable the threshold units pop-up menu.
% set(handles.editinit,'enable','on');                                        %Enable the time-out editbox.
set(handles.startbutton,'enable','on');                                     %Enable the start/stop button.
set(handles.pausebutton,'enable','on');                                     %Enable the pause button.
set(handles.feedbutton,'enable','on');                                      %Enable the manual feeding button.
temp = [0 0 0];                                                             %Set temp to a default color
if strcmpi(handles.device,'knob')
    temp = [0.9 0.7 0.9];                                                   %Set the label color to a light red.
elseif strcmpi(handles.device,'pull')                                       %If the current input device is a pull...
    temp = [0.7 0.9 0.7];                                                   %Set the label color to a light green.
elseif strcmpi(handles.device,'lever')                                      %If the current input device is a lever...
    temp = [0.7 0.7 0.9];                                                   %Set the label color to a light red.
elseif strcmpi(handles.device,'wheel')                                      %If the current input device is a wheel...
    temp = [0.9 0.9 0.7];                                                   %Set the label color to a light yellow.
elseif strcmpi(handles.device,'touch')                                      %If the current input device is a capacitive touch sensor...
    temp = [0.9 0.7 0.9];                                                   %Set the label color to a light magenta.
elseif strcmpi(handles.device,'both')                                       %If the current input device is a capacitive touch sensor...
    temp = [0.7 0.9 0.9];                                                   %Set the label color to a light cyan.
end
set(handles.label,'backgroundcolor',temp);                                  %Set the background color of all label editboxes.    
if handles.vns == 1                                                         %If VNS is turned on...
    set(handles.popvns,'foregroundcolor',[1 0 0]);                          %Make the "ON" text red.
elseif handles.vns == 2                                                     %Otherwise, if VNS is randomly presented...
    set(handles.popvns,'foregroundcolor',[0 0 1]);                          %Make the "RANDOM" text blue.
else                                                                        %Otherwise, if VNS is turned OFF...
    set(handles.popvns,'foregroundcolor','k');                              %Make the "ON" text black.
end

%Enable the top menu options.
set(handles.menu.stages.h,'enable','on');                                   %Enable the stages menu.
set(handles.menu.stages.view_spreadsheet,'enable','on');                    %Enable the "Open Spreadsheet" menu option.
set(handles.menu.stages.set_load_option,'enable','on');                     %Enable the stage-loading selection.
set(handles.menu.pref.h,'enable','on');                                     %Enable the preferences menu.