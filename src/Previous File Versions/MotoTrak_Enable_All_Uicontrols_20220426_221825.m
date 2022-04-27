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
%   10/28/2016 - Drew Sloan - Changed if statements to switch-case.
%

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

switch handles.device                                                       %Switch between the recognized devices.
    case 'knob'                                                             %If the current input device is a knob...
        temp = [0.9 0.7 0.9];                                               %Set the label color to a light red.
    case 'pull'                                                             %If the current input device is a pull...
        temp = [0.7 0.9 0.7];                                               %Set the label color to a light green.
    case 'lever'                                                            %If the current input device is a lever...
        temp = [0.7 0.7 0.9];                                               %Set the label color to a light red.
    case 'wheel'                                                            %If the current input device is a wheel...
        temp = [0.9 0.9 0.7];                                               %Set the label color to a light yellow.
    case 'touch'                                                            %If the current input device is a capacitive touch sensor...
        temp = [0.9 0.7 0.9];                                               %Set the label color to a light magenta.
    case 'both'                                                             %If the current input device is a capacitive touch sensor...
        temp = [0.7 0.9 0.9];                                               %Set the label color to a light cyan.
    otherwise                                                               %Otherwise, for any unrecognized device...
        temp = [0.7 0.7 0.7];                                               %Set the label color to a neutral gray.
end
set(handles.label,'backgroundcolor',temp);                                  %Set the background color of all label editboxes.    
if handles.stim == 1                                                        %If stimulation is turned on...
    set(handles.popvns,'foregroundcolor',[1 0 0]);                          %Make the "ON" text red.
elseif handles.stim == 2                                                    %Otherwise, if stimulation is randomly presented...
    set(handles.popvns,'foregroundcolor',[0 0 1]);                          %Make the "RANDOM" text blue.
else                                                                        %Otherwise, if VNS is turned OFF...
    set(handles.popvns,'foregroundcolor','k');                              %Make the "ON" text black.
end

%Enable the top menu options.
set(handles.menu.stages.h,'enable','on');                                   %Enable the stages menu.
set(handles.menu.stages.view_spreadsheet,'enable','on');                    %Enable the "Open Spreadsheet" menu option.
set(handles.menu.stages.set_load_option,'enable','on');                     %Enable the stage-loading selection.

set(handles.menu.cal.h,'enable','on');                                      %Enable the calibration menu.
switch handles.device                                                       %Switch between the available MotoTrak devices...
    case {'pull','both','touch'}                                            %If the current device is the pull...
        set(handles.menu.cal.open_calibration,'enable','on');               %Enable "Open Calibration" selection.
        set(handles.menu.cal.reset_baseline,'enable','on');                 %Enable "Reset Baseline" selection.
    case 'knob'                                                             %If the current device is the knob...
        set(handles.menu.cal.reset_baseline,'enable','on');                 %Enable "Reset Baseline" selection.
    case 'lever'                                                            %If the current device is the lever...
        set(handles.menu.cal.open_calibration,'enable','on');               %Enable "Open Calibration" selection.
end

set(handles.menu.pref.h,'enable','on');                                     %Enable the preferences menu.

set(handles.menu.io.h,'enable','on');                                       %Enable the i/o menu.
set(handles.menu.io.dio_trig_out,'enable','off');                           %Disable the trigger output type submenu.
set(handles.menu.io.dio_trig_dur,'enable','off');                           %Disable the trigger duration menu option.
set(handles.menu.io.dio_trig_ipp,'enable','off');                           %Disable the random trigger interval menu option.
if all(isfield(handles.ardy,{'set_trig_index','get_trig_dur'}))             %If the controller function structure has an option to grab the trigger duration...
    handles.ardy.set_trig_index(1);                                         %Set the trigger index to 1.
    trig_dur = handles.ardy.get_trig_dur();                                 %Grab the trigger duration.
    str = sprintf('Trigger Duration: %1.0f ms',trig_dur);                   %Create a string showing the trigger duration.
    set(handles.menu.io.dio_trig_dur,'Text',str);                           %Update the text on the trigger duration menu option.
end