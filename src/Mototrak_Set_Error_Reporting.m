function Mototrak_Set_Error_Reporting(hObject,~)

%
%Mototrak_Set_Error_Reporting.m - Vulintus, Inc.
%
%   Mototrak_Set_Error_Reporting is called whenever the user selects "On"
%   or "Off" for the Automatic Error Reporting feature under the MotoTrak
%   GUI Preferences menu.
%   
%   UPDATE LOG:
%   10/13/2016 - Drew Sloan - First function implementation.
%

handles = guidata(gcbf);                                                    %Grab the handles structure from the main figure.
str = get(hObject,'label');                                                 %Grab the string property from the selected menu option.
if strcmpi(str,'on')                                                        %If the user selected to turn error reporting on...
    handles.enable_error_reporting = 1;                                     %Enable error-reporting.
    set(handles.menu.pref.err_report_on,'checked','on');                    %Check the "On" option.
    set(handles.menu.pref.err_report_off,'checked','off');                  %Uncheck the "Off" option.
else                                                                        %Otherwise, if the user selected to turn error reporting off...
    handles.enable_error_reporting = 0;                                     %Disable error-reporting.
    set(handles.menu.pref.err_report_on,'checked','off');                   %Uncheck the "On" option.
    set(handles.menu.pref.err_report_off,'checked','on');                   %Check the "Off" option.
end
guidata(gcbf,handles);                                                      %Pin the handles structure back to the main figure.

