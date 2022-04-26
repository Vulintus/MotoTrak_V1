function handles = MotoTrak_Set_Callbacks(handles)

%
%MotoTrak_Disable_Controls_Within_Session.m - Vulintus, Inc.
%
%   This function disables all of the uicontrol and uimenu objects that 
%   should not be active while MotoTrak is running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added disabling of uinmenu objects.
%   01/09/2017 - Drew Sloan - Updated global run variable values.
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
set(handles.menu.cal.open_calibration,'callback','global run; run = 3;');   %Set the callback for the the "Open Calibration" option.
set(handles.menu.cal.reset_baseline,'callback','global run; run = 1.4;');   %Set the callback for the the "Reset Baseline" option to Pull Calibration.