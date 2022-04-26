function MotoTrak_Select_Stage(hObject,~)

global run                                                                  %Create the global run variable.

handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
i = get(hObject,'value');                                                   %Grab the value of the pop-up menu.
handles.must_select_stage = 0;                                              %Set a flag indicating that the user has properly selected a stage.
set(handles.pausebutton,'enable','on');                                     %Enable the pause button.
set(handles.feedbutton,'enable','on');                                      %Enable the manual feeding button.
if i ~= handles.cur_stage && i <= length(handles.stage)                     %If the selected stage is different from the current stage.
    handles.cur_stage = i;                                                  %Set the current stage to the selected stage.
    handles = MotoTrak_Load_Stage(handles);                                 %Load the new stage parameters.
    run = -2;                                                               %Set the run variable to -2.
    MotoTrak_Enable_All_Uicontrols(handles);                                %Update all of the uicontrols.
    guidata(handles.mainfig,handles);                                       %Pin the handles structure to the main figure.
end
if ~isempty(handles.ratname)                                                %If the user's already selected a stage...
    set(handles.startbutton,'enable','on');                                 %Enable the start button.
end