function handles = MotoTrak_Set_Callbacks(handles)

%
%MotoTrak_Set_Callbacks.m - Vulintus, Inc.
%
%   This function sets the callbacks for all user interface objects that
%   are active during idle mode.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added disabling of uinmenu objects.
%   01/09/2017 - Drew Sloan - Updated global run variable values.
%   02/21/2017 - Drew Sloan - Added a callback for opening the error report
%       directory from the preferences menu.
%


%Set the uicontrol callbacks.
set(handles.editrat,'callback',@MotoTrak_Edit_Rat,'string',[]);             %Set the callback for the rat name editbox.
set(handles.editbooth,'callback',@MotoTrak_Edit_Booth);                     %Set the callback for the booth number editbox.
set(handles.popstage,'callback','global run; run = 1.1;');                  %Set the callback for the stage pop-up menu.
set(handles.pausebutton,'callback','global run; run = 2.2;')                %Set the callback for the Pause button.

%Set the figure callbacks.
set(handles.mainfig,'CloseRequestFcn','global run; run = 0;');              %Set the callback for when the user tries to close the GUI.

%Set the uimenu callbacks.
set(handles.menu.stages.view_spreadsheet,...
    'callback',{@MotoTrak_Open_Google_Spreadsheet,handles.stage_url});      %Set the callback for the "Open Spreadsheet" submenu option.
set(handles.menu.pref.set_datapath,...
    'callback',@MotoTrak_Set_Datapath);                                     %Set the callback for the "Set Datapath" submenu option.
set([handles.menu.pref.err_report_on,handles.menu.pref.err_report_off],...
    'callback',@Mototrak_Set_Error_Reporting);                              %Set the callback for turning off/on automatic error reporting.
set(handles.menu.pref.error_reports,...
    'callback',@Mototrak_Open_Error_Reports);                               %Set the callback for opening the error reports directory.
set(handles.menu.pref.config_dir,...
    'callback',@Mototrak_Open_Configuration_Directory);                     %Set the callback for opening the configuration directory.
set(handles.menu.cal.open_calibration,'callback','global run; run = 3;');   %Set the callback for the the "Open Calibration" option.
set(handles.menu.cal.reset_baseline,'callback','global run; run = 1.4;');   %Set the callback for the "Reset Baseline" option.