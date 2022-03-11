function MotoTrak_Resize(hObject,~)

%
%MotoTrak_Resize.m - Vulintus, Inc.
%
%   MotoTrak_Resize resizes the children and plots on the main figure when
%   it's resized.
%
%   UPDATE LOG:
%   10/28/2016 - Drew Sloan - Added the ability to handle tab groups.
%

orig_h = 12;                                                                %List the initial GUI height, in centimeters.     

set(hObject,'units','centimeters');                                         %Set the figure units to centimeters.
h = get(hObject,'position');                                                %Grab the current figure position.
h = h(4);                                                                   %Keep only the current system height.

objs = get(hObject,'children');                                             %Grab all children of the parent object.
objs(strcmpi(get(objs,'type'),'uimenu')) = [];                              %Kick out all uimenu objects.

obj_type = get(objs,'type');                                                %Grab each object's type.
i = strcmpi('uipanel',obj_type) | ...
    strcmpi('uitabgroup',obj_type) ;                                        %Find all objects that are panels or tab groups.
temp = get(objs(i),'children');                                             %Grab all children of the panels and tab groups.
if iscell(temp)                                                             %If a cell array of children was returned...
    temp = vertcat(temp{:});                                                %Vertically concatenate the children object handles from the panels or tab groups.
end
objs = [objs; temp];                                                        %Add the panel and tab group children to the object handle list.

obj_type = get(objs,'type');                                                %Grab each object's type.
i = strcmpi('uitab',obj_type);                                              %Find all objects that are tabs.
temp = get(objs(i),'children');                                             %Grab all children of the tabs.
if iscell(temp)                                                             %If a cell array of children was returned...
    temp = vertcat(temp{:});                                                %Vertically concatenate the children object handles from the tabs.
end
objs = [objs; temp];                                                        %Add the tab children to the object handle list.

set(objs,'units','normalized');                                             %Make all units normalized.

obj_type = get(objs,'type');                                                %Grab each object's type.
i = strcmpi(obj_type,'uitabgroup') | strcmpi(obj_type,'uitab');             %Find all tab groups and tabs.
objs(i) = [];                                                               %Kick out the tab groups and tabs.
if isempty(get(objs(1),'userdata'))                                         %If none of the objects yet have an userdata field...
    for i = 1:length(objs)                                                  %Step through all of the objects.
        set(objs(i),'userdata',get(objs(i),'fontsize'));                    %Save the original font size for each object.
    end
end
    
fontsizes = get(objs,'userdata');                                           %Grab the current font sizes for all objects.
fontsizes = vertcat(fontsizes{:});                                          %Vertically concatenate the font size.
fontsizes = (h/orig_h)*fontsizes;                                           %Scale all of the fontsizes according to the ratio to the original height.

for i = 1:length(objs)                                                      %Step through all of the objects.
    try                                                                     %Attempt to scale the font...
        set(objs(i),'fontsize',fontsizes(i));                               %Save the original font size for each object.
    catch err                                                               %If the font size couldn't be set...
        warning(err.message);                                               %Show the error message.
    end
end