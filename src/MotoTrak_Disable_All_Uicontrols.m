function MotoTrak_Disable_All_Uicontrols(fig)

%
%MotoTrak_Disable_All_Uicontrols.m - Vulintus, Inc.
%
%   MotoTrak_Disable_All_Uicontrols dsiables all of the uicontrol and
%   uimenu objects that should be inactive while MotoTrak is running a
%   behavioral session.
%   
%   UPDATE LOG:
%   10/27/2016 - Drew Sloan - Added code to ignore uitabgroup and uitab
%       objects.
%

objs = get(fig,'children');                                                 %Grab all children of the figure.
i = strcmpi(get(objs,'type'),'uipanel') | ...
    strcmpi(get(objs,'type'),'uitabgroup');                                 %Find all uipanel and uitabgroup handles.
while any(i == 1)                                                           %Loop until we've checked all of the uipanels.
    temp = get(objs(i),'children');                                         %Grab all of the children of the uipanels.
    objs(i) = [];                                                           %Kick out all previous uipanel handles from the object list.
    objs = vertcat(objs,temp{:});                                           %Add the panel's objects to the object list.
    i = strcmpi(get(objs,'type'),'uipanel') | ...
        strcmpi(get(objs,'type'),'uitabgroup');                             %Find any new uipanel or uitabgroup handles.
end
i = strcmpi(get(objs,'type'),'axes') | ...
    strcmpi(get(objs,'type'),'uitabgroup') | ... 
    strcmpi(get(objs,'type'),'uitab');                                      %Find all axes, uitabgroup, and uitab objects.
objs(i) = [];                                                               %Kick out all axes and uitabgroup objects.
i = ~strcmpi(get(objs,'enable'),'inactive');                                %Find all objects that aren't currently inactive.
set(objs(i),'enable','off');                                                %Disable all active objects.