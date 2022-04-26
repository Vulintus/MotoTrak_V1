function Disable_All_Uicontrols(fig)

objs = get(fig,'children');                                                 %Grab all children of the figure.
i = strcmpi(get(objs,'type'),'uipanel');                                    %Find all uipanel handles.
while any(i == 1)                                                           %Loop until we've checked all of the uipanels.
    temp = get(objs(i),'children');                                         %Grab all of the children of the uipanels.
    objs(i) = [];                                                           %Kick out all previous uipanel handles from the object list.
    objs = vertcat(objs,temp{:});                                           %Add the panel's objects to the object list.
    i = strcmpi(get(objs,'type'),'uipanel');                                %Find any new uipanel handles.
end
objs(strcmpi(get(objs,'type'),'axes')) = [];                                %Kick out all axes objects.
i = ~strcmpi(get(objs,'enable'),'inactive');                                %Find all objects that aren't currently inactive.
set(objs(i),'enable','off');                                                %Disable all active objects.