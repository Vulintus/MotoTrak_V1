function MotoTrak_Edit_Rat(hObject,~)           

%This function executes when the user enters a rat's name in the editbox

handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
temp = get(hObject,'string');                                               %Grab the string from the rat name editbox.
for c = '/\?%*:|"<>. '                                                      %Step through all reserved characters.
    temp(temp == c) = [];                                                   %Kick out any reserved characters from the rat name.
end
if ~strcmpi(temp,handles.ratname)                                           %If the rat's name was changed.
    handles.ratname = upper(temp);                                          %Save the new rat name in the handles structure.
    Add_Msg(handles.msgbox,[datestr(now,13) ...
        ' - Current rat is ' handles.ratname '.']);                         %Show in the messagebox that the rat name was changed.
    guidata(handles.mainfig,handles);                                       %Pin the handles structure to the main figure.
end
set(handles.editrat,'string',handles.ratname);                              %Reset the rat name in the rat name editbox.
if handles.must_select_stage == 0 && ~isempty(handles.ratname)              %If the user's already selected a stage...
    set(handles.startbutton,'enable','on');                                 %Enable the start button.
end
guidata(handles.mainfig,handles);                                           %Pin the handles structure to the main figure.