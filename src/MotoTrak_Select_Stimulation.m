function MotoTrak_Select_Stimulation(hObject,~)           

%This function executes when the user sets VNS to ON or OFF in the
%stimulation pop-up menu.

handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
temp = 2 - get(hObject,'value');                                            %Grab the selected VNS value.
if handles.stim ~= temp                                                     %If the user changed the VNS on/off status...
    handles.stim = temp;                                                    %Save the new VNS on/off status value.
    if handles.stim == 1                                                    %If VNS is now turned on...
        Add_Msg(handles.msgbox,[datestr(now,13) ' - VNS is now ON.']);      %Show the user that VNS is now turned on.
    else                                                                    %Otherwise...
        Add_Msg(handles.msgbox,[datestr(now,13) ' - VNS is now OFF.']);     %Show the user that VNS is now turned off.
    end
end
Enable_All(handles);                                                        %Update all of the uicontrols.
guidata(handles.mainfig,handles);                                           %Pin the handles structure to the main figure.