function MotoTrak_Edit_Booth(hObject,~)

%This function executes when the user changes the booth number in the
%booth number editbox.

handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
temp = get(hObject,'string');                                               %Grab the string from the booth number editbox.
temp = str2double(temp);                                                    %Convert the string to a number.
if temp > 0 && mod(temp,1) == 0 && temp < 65535                             %If the entered booth number is positive and a whole number...
    handles.booth = temp;                                                   %Save the booth number in the handles structure.
    handles.ardy.set_booth(handles.booth);                                  %Save the booth number on the Arduino.
    Add_Msg(handles.msgbox,[datestr(now,13) ...
        ' - The booth number is now set to ' num2str(temp) '.']);           %Show in the messagebox that the booth number was changed.
end
set(handles.editbooth,'string',num2str(handles.booth));                     %Reset the string in the booth number editbox to the current booth number.
guidata(handles.mainfig,handles);                                           %Pin the handles structure to the main figure.