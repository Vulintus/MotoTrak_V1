function MotoTrak_Startup


%% Define program-wide constants.
global run                                                                  %Create the global run variable.
run = 0;                                                                    %Set the run variable to zero.
handles = struct;                                                           %Create a handles structure.
handles.mainpath = Vulintus_Set_AppData_Path('MotoTrak');                   %Grab the expected directory for MotoTrak application data.
handles.version = 1.12;                                                     %Set the MotoTrak program version.


%% Load the current configuration file.
handles = MotoTrak_Default_Config(handles);                                 %Load the default configuration values.
[~, temp] = system('hostname');                                             %Grab the local computer name.
temp(temp < 33) = [];                                                       %Kick out any spaces and carriage returns from the computer name.
handles.host = temp;                                                        %Save the local computer name.
temp = [handles.mainpath '*mototrak.config'];                               %Set the expected filename of the configuration file.
temp = dir(temp);                                                           %Find all matching configuration files in the main program path.
if isempty(temp)                                                            %If no configuration file was found...
    yesno = questdlg(['It looks like this might be your first time '...
        'runing MotoTrak. Do you have a configuration file you''d like '...
        'to load?'],'LOAD CONFIGURATION FILE?','YES','NO','YES');           %Show an OK/Cancel warning that the file will be moved.
    if strcmpi(yesno,'yes')                                                 %If the user clicked "yes"...
        [file, path] = uigetfile('*mototrak.config',...
            'Load MotoTrak Configuration');                                 %Have the user select a configuration file.
        if file(1) ~= 0                                                     %If the user selected a valid file...
            [status, errmsg] = copyfile([path file],handles.mainpath,'f');  %Copy the configuration file to the MotoTrak application data directory.
            if status ~= 1                                                  %If the file couldn't be copied...
                errordlg(sprintf(['Could not copy the configuration '...
                    'file in:\n\n%s\n\nError:\n\n%s'],handles.mainpath,...
                    errmsg),'MotoTrak File Copy Error');                    %Throw an error.
            end
            temp = struct('name',file);                                     %Create a temporary structure holding the configuration file name.
        end
    else                                                                    %Otherwise, if the user didn't load a configuration file.
        MotoTrak_Write_Config('default',handles,[]);                        %Create a default configuration file.
    end
end
if ~isempty(temp)                                                           %If any configuration files were found...
    if length(temp) == 1                                                    %If there's one configuration file in the main program path...
        handles.config_file = [handles.mainpath temp(1).name];              %Set the configuration file path to the single file.
    else                                                                    %Otherwise, if there's multiple configuration files...
        temp = {temp.name};                                                 %Create a cell array of configuration file names.
        i = listdlg('PromptString',...
            'Which configuration file would you like to use?',...
            'name','Multiple Configuration Files',...
            'SelectionMode','single',...
            'listsize',[300 200],...
            'initialvalue',1,...
            'uh',25,...
            'ListString',temp);                                             %Have the user pick a configuration file to use from a list dialog.
        if isempty(i)                                                       %If the user clicked "cancel" or closed the dialog...
            close(handles.mainfig);                                         %Close the GUI.
            clear('run');                                                   %Clear the global run variable from the workspace.
            return                                                          %Skip execution of the rest of the function.
        end
        handles.config_file = [handles.mainpath temp{i}];                   %Set the configuration file path to the single file.
    end
    handles = MotoTrak_Load_Config(handles);                                %Call the function to the load the configuration file.
end
if handles.datapath(end) ~= '\'                                             %If the last character of the data path isn't a forward slash...
    handles.datapath(end+1) = '\';                                          %Add a forward slash to the end.
end
if ~exist(handles.datapath,'dir')                                           %If the primary local data path doesn't already exist...
    mkdir(handles.datapath);                                                %Create the primary local data path.
end


%% Create the main GUI.
handles = MotoTrak_Make_GUI(handles);                                       %Call the subfunction to make the GUI.
set(handles.mainfig,'resize','on',...
    'ResizeFcn',@MotoTrak_Resize);                                          %Set the resize function for the MotoTrak main figure.
MotoTrak_Disable_All_Uicontrols(handles.mainfig);                           %Disable all of the uicontrols until the Arduino is connected.


%% Load the stage information.
handles = MotoTrak_Read_Stages(handles);                                    %Call the function to load the stage information.
if run == -1                                                                %If the user cancelled an operation during stage selection...
    close(handles.mainfig);                                                 %Close the GUI.
    clear('run');                                                           %Clear the global run variable from the workspace.
    return                                                                  %Skip execution of the rest of the function.
end


%% Connect to the Arduino and check the sketch version.
handles.ardy = Connect_MotoTrak('listbox',handles.msgbox);                  %Connect to the Arduino, passing the listbox handle to receive messages.
if isempty(handles.ardy)                                                    %If the user cancelled connection to the Arduino...
    close(handles.mainfig);                                                 %Close the GUI.
    clear('run');                                                           %Clear the global run variable from the workspace.
    return                                                                  %Skip execution of the rest of the function.
end
temp = handles.ardy.check_version();                                        %Grab the version of the MotorBoard sketch the Arduino is running.
if temp < 30                                                                %If the Arduino sketch version is older than version 3.0...
    temp = num2str(temp);                                                   %Convert the version number to a character.
    errordlg(['The MotoTrak sketch on the Arduino is too old '...
        '(version ' temp(1) '.' temp(2) ').  Please upgrade to '...
        'version 3.0 or higher to run this program.']);                     %Show an error message telling the user to update the Arduino sketch.
    delete(handles.ardy.serialcon);                                         %Close the serial connection with the Arduino.
    close(handles.mainfig);                                                 %Close the GUI.
    clear('run');                                                           %Clear the global run variable from the workspace.
    return                                                                  %Skip execution of any further code.
end
Clear_Msg([],[],handles.msgbox);                                            %Clear the original Arduino connection message out of the listbox.
Add_Msg(handles.msgbox,[datestr(now,13) ' - Arduino connected.']);          %Show when the Arduino connection was successful in the messagebox.     
handles.ardy.clear();                                                       %Clear any residual values from the serial line.
handles.booth = handles.ardy.booth();                                       %Grab the booth number from the Arduino board.
set(handles.editport,'string',handles.ardy.port);                           %Show the port on the GUI.
set(handles.editbooth,'string',num2str(handles.booth));                     %Show the booth number on the GUI.

handles.ardy.autopositioner(0);                                             %Send a reset command to the autopositioner.   
handles.delay_autopositioning = 10/86400 + now;                             %Set a duration to delay all following autopositioner commands.

handles.baseline = 0;                                                       %Set the default analog baseline to 0.
handles.slope = 1;                                                          %Set the default calibration slope to 1.
handles.offset_counter = 0;                                                 %Create a counter to count full rotations of potentiometer-based devices.
handles.offset_add = 1023;                                                  %Set the default range of a full rotation of a potentiometer-based device.
handles.offset_max = 512;                                                   %Set the analog value shift that will indicate a full rotation roll-over.
handles.total_range_in_degrees = 0;                                         %Set the default range of the potentiometer, in degrees.
handles.total_range_in_analog_values = 0;                                   %Set the default range of the potentiometer, in analog tick values.


%% Detect the which module is connected.
temp = handles.ardy.device();                                               %Grab the current value of the analog device identifier.
handles.device = MotoTrak_Identify_Device(temp);                            %Call the function to identify the module based on the value of the analog device identifier.
%start debug code.
if isfield(handles,'variant') && strcmpi(handles.variant,'Isaac Cassar')    %If we're debugging Isaac Cassar's behavior...
    handles.device = 'lever';                                               %Set the device to the lever regardless of the identifier.
end
%end debug code.
if strcmpi(handles.device,'pull') && strcmpi(handles.custom,'machado lab')  %If the current device is the pull and this is a custom variant for the Machado lab...
    temp = questdlg(['Would you like to train the rat on the pull '...
        'handle, the touch sensor, or both?'],'Select Sensor',...
        'PULL','TOUCH','BOTH','PULL');                                      %Ask the user which device they'd like to train with.
    if isempty(temp)                                                        %If the user closed the dialog without selecting a sensor...
        delete(handles.ardy.serialcon);                                     %Close the serial connection with the Arduino.
        close(handles.mainfig);                                             %Close the GUI.
        clear('run');                                                       %Clear the global run variable from the workspace.
        return                                                              %Skip execution of any further code.
    end
    handles.device = lower(temp);                                           %Set the current device to that chosen by the user.
end
if strcmpi(handles.device,'lever')                                          %If the current device is the lever...
    handles.baseline = handles.ardy.baseline();                             %Read in the baseline (unpressed) value for the lever.
    handles.total_range_in_degrees = handles.ardy.cal_grams();              %Read in the range of the lever press, in degrees.
    handles.total_range_in_analog_values = handles.ardy.n_per_cal_grams();  %Read in the range of the lever press, in analog tick values.
    handles.slope = -handles.total_range_in_degrees / ...
        handles.total_range_in_analog_values;                               %Calculate the degrees/tick conversion for the lever.    
elseif strcmpi(handles.device,'knob')                                       %If the current device is the knob...
    handles.ardy.knob_toggle(1);                                            %Toggle the knob on.
    handles.ardy.clear();                                                   %Clear any residual data on serial line
    handles.slope = -0.25;                                                  %Set the slope of the calibration.
    handles.baseline = handles.ardy.read_Pull();                            %Set the baseline as the current value on the analog line.
elseif any(strcmpi(handles.device,{'pull','both'}))                          %If the current device is the pull or (pull/touch)....
    handles.baseline = handles.ardy.baseline();                             %Read in the baseline (resting) value for the isometric pull handle loadcell.                
    handles.slope = handles.ardy.cal_grams();                               %Read in the loadcell range, in grams.
    temp = handles.ardy.n_per_cal_grams();                                  %Read in the loadcell range, in analog tick values.
    handles.slope = handles.slope / temp;                                   %Calculate the grams/tick conversion for the isometric pull handle loadcell.
elseif strcmpi(handles.device,'touch')                                      %If the current device is the capacitive touch sensor...
    handles.baseline = 0;                                                   %Set the baseline to zero.
    handles.slope = 1;                                                      %Set the calibration slope to 1.
else                                                                        %Otherwise, if no device was found...
    errordlg(['The Arduino didn''t detect any input devices.  Attach a'...
        ' wheel, lever, pull, or knob module and restart the program.']);   %Show an error message telling the user to attach a device.
    delete(handles.ardy.serialcon);                                         %Close the serial connection with the Arduino.
    close(handles.mainfig);                                                 %Close the GUI.
    clear('run');                                                           %Clear the global run variable from the workspace.
    return                                                                  %Skip execution of any further code. 
end

if strcmpi(handles.device,'both')                                           %If the user selected combined touch-pull...
    p = get(handles.stream_axes,'parent');                                  %Grab the panel parent of the streaming axes.
    temp = get(handles.stream_axes,'position');                             %Grab the streaming axes position.
    temp(4) = 0.49*temp(4);                                                 %Make the axes half of the original height.
    set(handles.stream_axes,'position',temp);                               %Reset the pull streaming axes position.
    temp(2) = temp(2) + (51/49)*temp(4);                                    %Create a new position in the upper half of the original height.          
    handles.touch_axes = axes('parent',p,...
        'units',get(handles.stream_axes,'units'),...
        'position',temp,...
        'box','on',...
        'xtick',[],...
        'ytick',[]);                                                        %Create a new axis to show the touch data.
end

%Populate the device pop-up menu with the device label.
set(handles.popdevice,'string',handles.device);                             

%Populate the stage selection pop-up menu.
a = strcmpi(handles.device, {handles.stage.device});                        %Find all stages that use the currently-connected device.
handles.stage(a == 0) = [];                                                 %Kick out all stages that don't use the currently-connected device.

%Get all the unique threshold types and constraints for the device.
handles.threshtype = unique({handles.stage.threshtype});                    %List all of the unique threshold types for each device.    
handles.constraint = unique({handles.stage.const});                         %List all of the unique constraint numbers for each device.

handles.cur_stage = 1;                                                      %Set the current stage to the first stage in the list.
handles = MotoTrak_Load_Stage(handles);                                     %Load the stage parameters for current stage.

%Set the streaming parameters on the Arduino.
handles.current_ir = 1;                                                     %Stream the signal from the first IR input.
MotoTrak_Set_Stream_Params(handles);                                        %Update the streaming properties on the Arduino.

%Set the callbacks for all the enabled uicontrols.
handles = MotoTrak_Set_Callbacks(handles);                                  %Set the callbacks for all uicontrols and menu options.

MotoTrak_Enable_All_Uicontrols(handles);                                    %Enable all of the uicontrols.

%These specific UI controls need to be disabled until the user has selected a stage.
set(handles.startbutton,'enable','off');                                    %Disable the start/stop button until a new stage is selected.
set(handles.pausebutton,'enable','off');                                    %Disable the pause button.

run = -1;                                                                   %Set the run variable to -1.
guidata(handles.mainfig,handles);                                           %Pin the handles structure to the main figure.
MotoTrak_Idle(handles);                                                     %Start the device-scanning loop.