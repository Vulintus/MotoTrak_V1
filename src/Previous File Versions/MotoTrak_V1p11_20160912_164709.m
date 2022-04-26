function MotoTrak_V1p11

%Compiled: 09/12/2016, 16:47:08


%% Define program-wide constants.
global run                                                                  %Create the global run variable.
run = 0;                                                                    %Set the run variable to zero.
handles = struct;                                                           %Create a handles structure.
handles.mainpath = Vulintus_Set_AppData_Path('MotoTrak');                   %Grab the expected directory for MotoTrak application data.


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
Disable_All_Uicontrols(handles.mainfig);                                    %Disable all of the uicontrols until the Arduino is connected.


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

Enable_All_Uicontrols(handles);                                             %Enable all of the uicontrols.

%These specific UI controls need to be disabled until the user has selected a stage.
set(handles.startbutton,'enable','off');                                    %Disable the start/stop button until a new stage is selected.
set(handles.pausebutton,'enable','off');                                    %Disable the pause button.

run = -1;                                                                   %Set the run variable to -1.
guidata(handles.mainfig,handles);                                           %Pin the handles structure to the main figure.
MotoTrak_Idle(handles);                                                     %Start the device-scanning loop.


function ardy = Connect_MotoTrak(varargin)

%Connect_MotoTrak.m - Vulintus, Inc., 2016
%
%   Connect_MotoTrak establishes the serial connection between the computer
%   and the MotoTrak controller, and sets the communications functions used
%   for streaming data.
%
%   UPDATE LOG:
%   05/09/2016 - Drew Sloan - Separated serial functions from the
%       Connect_MotoTrak function to allow for loading different functions
%       for different controller sketch versions.


if isdeployed                                                               %If this is deployed code...
    temp = winqueryreg('HKEY_CURRENT_USER',...
            ['Software\Microsoft\Windows\CurrentVersion\' ...
            'Explorer\Shell Folders'],'Local AppData');                     %Grab the local application data directory.
    temp = fullfile(temp,'MotoTrak','\');                                   %Create the expected directory name for MotoTrak data.
    if ~exist(temp,'dir')                                                   %If the directory doesn't already exist...
        [status, msg, ~] = mkdir(temp);                                     %Create the directory.
        if status ~= 1                                                      %If the directory couldn't be created...
            error('MOTOTRAK:MKDIR',['Unable to create application data'...
                ' directory\n%s\nDetails: %s'],temp, msg);                  %Show an error.
        end
    end
else                                                                        %Otherwise, if this isn't deployed code...
    temp = mfilename('fullpath');                                           %Grab the full path and filename of the current *.m file.
    temp(find(temp == '\' | temp == '/',1,'last'):end) = [];                %Kick out the filename to capture just the path.
end
port_matching_file = [temp '\mototrak_port_booth_pairings.txt'];            %Set the expected name of the pairing file.

port = [];                                                                  %Create a variable to hold the serial port.
listbox = [];                                                               %Create a matrix to hold a listbox handle.
ax = [];                                                                    %Create a matrix to hold an axes handle.

%Step through the optional input arguments and set any user-specified parameters.
str = {'port','listbox','axes'};                                            %List the optional input arguments.
for i = 1:2:length(varargin)                                                %Step through the optional input arguments
	if ~ischar(varargin{i}) || ~any(strcmpi(str,varargin{i}))               %If the first optional input argument isn't one of the expected property names...
        cprintf('err',['ERROR IN ' upper(mfilename) ':  Property name '...
            'not recognized! Optional input properties are:\n']);           %Show an error.
        for j = 1:length(str)                                               %Step through each optional input argument name.
            cprintf('err',['\t''' str{j} '''\n']);                          %Print the optional input argument name.
        end
        beep;                                                               %Beep to alert the user to an error.
        ardy = [];                                                          %Set the function output to empty.
        return                                                              %Skip execution of the rest of the function.
    else                                                                    %Otherwise...
        temp = varargin{i};                                                 %Grab the parameter name.
        switch lower(temp)                                                  %Switch among possible parameter names.
            case 'port'                                                     %If the parameter name was "port"...
                port = varargin{i+1};                                       %Use the specified serial port.
            case 'listbox'                                                  %If the parameter name was "listbox"...
                listbox = varargin{i+1};                                    %Save the listbox handle to write messages to.
                if ~ishandle(listbox) && ...
                        ~strcmpi(get(listbox,'type'),'listbox')             %If the specified handle is not a listbox...
                    error(['ERROR IN ' upper(mfilename) ': The '...
                        'specified ListBox handle is invalid.']);           %Show an error.
                end 
            case 'axes'                                                     %If the parameter name was "axes"...
            	ax = varargin{i+1};                                         %Save the axes handle to write messages to.
                if ~ishandle(ax) && ~strcmpi(get(ax,'type'),'axes')         %If the specified handle is not a listbox...
                    error(['ERROR IN ' upper(mfilename) ': The '...
                        'specified axes handle is invalid.']);              %Show an error.
                end
        end
    end
end

[~, local] = system('hostname');                                            %Grab the local computer name.
local(local < 33) = [];                                                     %Kick out any spaces and carriage returns from the computer name.
if isempty(port)                                                            %If no port was specified...
    if exist(port_matching_file,'file')                                     %If an existing booth-port pairing file is found...
        booth_pairings = Get_Port_Assignments(port_matching_file);          %Call the subfunction to get the booth-port pairings.
        i = strcmpi(booth_pairings(:,1),local);                             %Find all rows that match the local computer.
        booth_pairings = booth_pairings(i,2:3);                             %Return only the pairings for the local computer.
        keepers = ones(size(booth_pairings,1),1);                           %Create a matrix to mark booth-port pairings for inclusion.
        for i = 2:length(keepers)                                           %Step through each entry.
            if keepers(i) == 1 && any(strcmpi(booth_pairings(1:(i-1),1),...
                    booth_pairings{i,1}))                                   %If the port for this entry matches any previous entry...
                keepers(i) = 0;                                             %Mark the entry for exclusion.
            end
        end
        booth_pairings(keepers == 0,:) = [];                                %Kick out all pairings marked for exclusion.        
    else                                                                    %Otherwise...
        booth_pairings = {};                                                %Create an empty cell array to hold booth pairings.
    end
    [port, booth_pairings] = MotoTrak_Select_Serial_Port(booth_pairings);   %Call the port selection function.
else                                                                        %Otherwise...
    temp = instrfind('port',port);                                          %Check to see if the specified port is busy...
    if ~isempty(temp)                                                       %If an existing serial connection was found for this port...
        i = questdlg(['Serial port ''' port ''' is busy. Reset and use '...
            'this port?'],['Reset ''' port '''?'],...
            'Reset','Cancel','Reset');                                      %Ask the user if they want to reset the busy port.
        if strcmpi(i,'Cancel')                                              %If the user selected "Cancel"...
            port = [];                                                      %...set the selected port to empty.
        else                                                                %Otherwise, if the user pressed "Reset"...
            fclose(temp);                                                   %Close the busy serial connection.
            delete(temp);                                                   %Delete the existing serial connection.
        end
    end
end

if isempty(port)                                                            %If no port was selected.
    warning('Connect_MotoTrak:NoPortChosen',['No serial port chosen '...
        'for Connect_MotoTrak. Connection to the Arduino was aborted.']);   %Show a warning.
    ardy = [];                                                              %Set the function output to empty.
    return;                                                                 %Exit the ArdyMotorBoard function.
end

if ~isempty(listbox) && ~isempty(ax)                                        %If both a listbox and an axes are specified...
    ax = [];                                                                %Clear the axes handle.
    warning(['WARNING IN CONNECT_MOTOTRAK: Both a listbox and an axes '...
        'handle were specified. The axes handle will be ignored.']);        %Show a warning.
end

message = 'Connecting to MotoTrak controller...';                           %Create the beginning of message to show the user.
t = 0;                                                                      %Create a dummy handle for a text label.
if ~isempty(listbox)                                                        %If the user specified a listbox...    
    set(listbox,'string',message,'value',1);                                %Show the Arduino connection status in the listbox.
elseif ~isempty(ax)                                                         %If the user specified an axes...
    t = text(mean(xlim(ax)),mean(ylim(ax)),message,...
        'horizontalalignment','center',...
        'verticalalignment','middle',...
        'fontweight','bold',...
        'margin',5,...
        'edgecolor','k',...
        'backgroundcolor','w',...
        'parent',ax);                                                       %Create a text object on the axes.
    temp = get(t,'extent');                                                 %Grab the extent of the text object.
    temp = temp(3)/range(xlim(ax));                                         %Find the ratio of the text length to the axes width.
    set(t,'fontsize',0.6*get(t,'fontsize')/temp);                           %Scale the fontsize of the text object to fit the axes.
else                                                                        %Otherwise...
    waitbar = big_waitbar('title','Connecting to MotoTrak',...
        'string',['Connecting to ' port '...'],...
        'value',0.25);                                                      %Create a waitbar figure.
    temp = 0.05;                                                            %Create an initial waitbar value.
end

serialcon = serial(port,'baudrate',115200);                                 %Set up the serial connection on the specified port.
try                                                                         %Try to open the serial port for communication.
    fopen(serialcon);                                                       %Open the serial port.
catch                                                                       %If no connection could be made to the serial port...
    delete(serialcon);                                                      %Delete the serial object.
    error(['ERROR IN CONNECT_MOTOTRAK: Could not open a serial '...
        'connection on port ''' port '''.']);                               %Show an error.
end

timeout = now + 10/86400;                                                   %Set a time-out point for the following loop.
while now < timeout                                                         %Loop for 10 seconds or until the Arduino initializes.
    if serialcon.BytesAvailable > 0                                         %If there's bytes available on the serial line...
        break                                                               %Break out of the waiting loop.
    else                                                                    %Otherwise...
        message(end+1) = '.';                                               %Add a period to the end of the message.
        if ~isempty(ax) && ishandle(t)                                      %If progress is being shown in text on an axes...
            set(t,'string',message);                                        %Update the message in the text label on the figure.
        elseif ~isempty(listbox)                                            %If progress is being shown in a listbox...
            set(listbox,'string',message,'value',[]);                       %Update the message in the listbox.
        else                                                                %Otherwise, if progress is being shown in a waitbar...
            temp = 1 - 0.9*(1-temp);                                        %Increment the waitbar values.
            waitbar.value(temp);                                            %Update the waitbar value.
        end
        pause(0.5);                                                         %Pause for 500 milliseconds.
    end
end

if serialcon.BytesAvailable > 0                                             %if there's a reply on the serial line.
    temp = fscanf(serialcon,'%c',serialcon.BytesAvailable);                 %Read the reply into a temporary matrix.
end

timeout = now + 10/86400;                                                   %Set a time-out point for the following loop.
while now < timeout                                                         %Loop for 10 seconds or until a reply is noted.
    fwrite(serialcon,'A','uchar');                                          %Send the check status code to the Arduino board.
    if serialcon.BytesAvailable > 0                                         %If there's bytes available on the serial line...
        message = 'Controller Connected!';                                  %Add to the message to show that the connection was successful.
        if ~isempty(ax) && ishandle(t)                                      %If progress is being shown in text on an axes...
            set(t,'string',message);                                        %Update the message in the text label on the figure.
        elseif ~isempty(listbox)                                            %If progress is being shown in a listbox...
            set(listbox,'string',message,'value',[]);                       %Update the message in the listbox.
        else                                                                %Otherwise, if progress is being shown in a waitbar...
            waitbar.value(1);                                               %Update the waitbar value.
            waitbar.string(message);                                        %Update the message in the waitbar.
        end
        break                                                               %Break out of the waiting loop.
    else                                                                    %Otherwise...
        message(end+1) = '.';                                               %Add a period to the end of the message.
        if ~isempty(ax) && ishandle(t)                                      %If progress is being shown in text on an axes...
            set(t,'string',message);                                        %Update the message in the text label on the figure.
        elseif ~isempty(listbox)                                            %If progress is being shown in a listbox...
            set(listbox,'string',message,'value',[]);                       %Update the message in the listbox.
        else                                                                %Otherwise, if progress is being shown in a waitbar...
            temp = 1 - 0.9*(1-temp);                                        %Increment the waitbar values.
            waitbar.value(temp);                                            %Update the waitbar value.
        end
        pause(0.5);                                                         %Pause for 500 milliseconds.
    end    
end

while serialcon.BytesAvailable > 0                                          %Loop through the replies on the serial line.
    pause(0.01);                                                            %Pause for 50 milliseconds.
    temp = fscanf(serialcon,'%d');                                          %Read each reply, replacing the last.
    if temp == 111                                                          %If the reply is the "111" expected from controller sketch V1.4...
        version = 1.4;                                                      %Set the sketch version to 1.4.
    elseif temp == 123                                                      %Otherwise, if the reply is the "123" expected from controller sketches 2.0+...
        version = 2.0;                                                      %Set the version to 2.0.
    end
end

if isempty(temp) || ~any(temp == [111, 123])                                %If no status reply was received...
    delete(serialcon);                                                      %...delete the serial object and show an error.
    error(['ERROR IN CONNECT_MOTOTRAK: Could not connect to the '...
        'controller. Check to make sure the controller is connected to '...
        port ' and that it is running the correct MotoTrak sketch.']);      %Show an error.
else                                                                        %Otherwise...
    fprintf(1,'%s\n',['The MotoTrak controller is connected and the '...
        'MotoTrak sketch '...
        'is detected as running.']);                                        %Show that the connection was successful.
end       

ardy = struct('port',port,'serialcon',serialcon);                           %Create the output structure for the serial communication.
if version == 1.4                                                           %If the controller Arduino sketch version is 1.4...
    ardy = MotoTrak_Controller_V1p4_Serial_Functions(ardy);                 %Load the V1.4 serial communication functions.
elseif version == 2.0                                                       %If the controller Arduino sketch version is 2.0...
    fwrite(serialcon,'B','uchar');                                          %Send the check sketch version code to the Arduino board.
    version = fscanf(serialcon,'%d');                                       %Check the serial line for a reply.
    version = version/100;                                                  %Divide by 10 to find the version number.
    switch version                                                          %Switch between the possible controller sketch versions...
        case 2.0                                                            %If the controller sketch is V2.0...
            ardy = MotoTrak_Controller_V2p0_Serial_Functions(ardy);         %Load the V2.0 serial communication functions.
    end
end

pause(1);                                                                   %Pause for one second.
if ~isempty(ax) && ishandle(t)                                              %If progress is being shown in text on an axes...
    delete(t);                                                              %Delete the text object.
elseif isempty(listbox)                                                     %If progress is being shown in a waitbar...
    waitbar.close();                                                        %Close the waitbar.
end

while serialcon.BytesAvailable > 0                                          %If there's any junk leftover on the serial line...
    fscanf(serialcon,'%d',serialcon.BytesAvailable);                        %Remove all of the replies from the serial line.
end

% if nargin == 0 || ~any(varargin(1:2:end),'port')                            %If the user didn't specify a port...
%     booth = ardy.booth();                                                   %Read in the booth number from the controller.
%     if version == 1.4                                                       %If the controller Arduino sketch version is 1.4...
%         booth = num2str(booth,'%1.0f');                                     %Convert the booth number to a string.
%     end
%     i = strcmpi(booth_pairings(:,1),port);                                  %Find the row for the currently-connected booth.
%     if any(i)                                                               %If a matching row is found.
%         booth_pairings{i,2} = booth;                                        %Update the booth number for this booth.
%     else                                                                    %Otherwise...
%         booth_pairings(end+1,:) = {port, booth};                            %Update the pairings with both the port and the booth number.
%     end
%     temp = Get_Port_Assignments(port_matching_file);                        %Call the subfunction to read in the booth-port pairings.
%     if ~isempty(temp)                                                       %If there were any existing port-booth pairings...
%         i = strcmpi(temp(:,1),local);                                       %Find all rows that match the local computer.
%         temp(i,:) = [];                                                     %Kick out all rows that match the local computer.
%     end
%     for i = 1:size(booth_pairings,1)                                        %Step through the updated booth pairings.
%         temp(end+1,1:3) = {local, booth_pairings{i,:}};                     %Add each port-booth pairing from this computer to the list.
%     end
%     Set_Port_Assignments(port_matching_file,temp);                          %Save the updated port-to-booth pairings for the next start-up.
% end


%% This function reads in the port-booth assignment file.
function booth_pairings = Get_Port_Assignments(port_matching_file)
try                                                                         %Attempt to open and read the pairing file.
    [fid, errmsg] = fopen(port_matching_file,'rt');                         %Open the pairing file for reading.
    if fid == -1                                                            %If a file could not be opened...
        warndlg(sprintf(['Could not open the port matching file '...
            'in:\n\n%s\n\nError:\n\n%s'],port_matching_file,...
            errmsg),'MotoTrak File Read Error');                            %Show a warning.
    end
    temp = textscan(fid,'%s');                                              %Read in the booth-port pairings.
    fclose(fid);                                                            %Close the pairing file.
    if mod(length(temp{1}),3) ~= 0                                          %If the data in the file isn't formated into 3 columns...
        booth_pairings = {};                                                %Set the pairing cell array to be an empty cell.
    else                                                                    %Otherwise...
        booth_pairings = cell(3,length(temp{1})/3-1);                       %Create a 3-column cell array to hold the booth-to-port assignments.
        for i = 4:length(temp{1})                                           %Step through the elements of the text.
            booth_pairings(i-3) = temp{1}(i);                               %Match each entry to it's correct row and column.
        end
        booth_pairings = booth_pairings';                                   %Transpose the pairing cell array.
    end
catch err                                                                   %If any error occured while reading the pairing file.
    booth_pairings = {};                                                    %Set the pairing cell array to be an empty cell.
    warning([upper(mfilename) ':PairingFileReadError'],['The '...
        'booth-to-port pairing file was unreadable! ' err.identifier]);     %Show that the pairing file couldn't be read.
end


%% This function writes the port-booth assignment file.
function Set_Port_Assignments(port_matching_file,booth_pairings)
[fid, errmsg] = fopen(port_matching_file,'wt');                             %Open a new text file to write the booth-to-port pairing to.
if fid == -1                                                                %If a file could not be created...
    warndlg(sprintf(['Could not create the port matching file '...
        'in:\n\n%s\n\nError:\n\n%s'],port_matching_file,...
        errmsg),'MotoTrak File Write Error');                               %Show a warning.
end
fprintf(fid,'%s\t','COMPUTER:');                                            %Write the computer column heading to the file.
fprintf(fid,'%s\t','PORT:');                                                %Write the port column heading to the file.
fprintf(fid,'%s\n','BOOTH:');                                               %Write the booth column heading to the file.
for i = 1:size(booth_pairings,1)                                            %Step through the listed booth-to-port pairings.
    fprintf(fid,'%s\t',booth_pairings{i,1});                                %Write the computer name to the file.
    fprintf(fid,'%s\t',booth_pairings{i,2});                                %Write the port to the file.
    fprintf(fid,'%s\n',booth_pairings{i,3});                                %Write the booth number to the file.
end
fclose(fid);                                                                %Close the pairing file.


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


function Enable_All_Uicontrols(handles)

% objs = get(fig,'children');                                                 %Grab all children of the figure.
% i = strcmpi(get(objs,'type'),'uipanel');                                    %Find all uipanel handles.
% while any(i == 1)                                                           %Loop until we've checked all of the uipanels.
%     temp = get(objs(i),'children');                                         %Grab all of the children of the uipanels.
%     objs(i) = [];                                                           %Kick out all previous uipanel handles from the object list.
%     objs = vertcat(objs,temp{:});                                           %Add the panel's objects to the object list.
%     i = strcmpi(get(objs,'type'),'uipanel');                                %Find any new uipanel handles.
% end
% objs(strcmpi(get(objs,'type'),'axes')) = [];                                %Kick out all axes objects.
% i = ~strcmpi(get(objs,'enable'),'inactive');                                %Find all objects that aren't currently inactive.
% set(objs(i),'enable','on');                                                 %Enable all active objects.

set(handles.editrat,'enable','on');                                         %Enable the rat name editbox.
set(handles.editbooth,'enable','on');                                       %Enable booth number setting.
set(handles.editport,'enable','inactive');                                  %Make the port editbox inactive.
set(handles.popdevice,'enable','on');                                       %Enable the device pop-up menu.
% set(handles.popvns,'enable','on');                                          %Enable the VNS pop-up menu.
set(handles.popstage,'enable','on');                                        %Enable the stage pop-up menu.
set(handles.editpos,'enable','on');                                         %Enable the position editbox.
% set(handles.popconst,'enable','on');                                        %Enable the constraint pop-up menu.
% set(handles.edithitwin,'enable','on');                                      %Enable the hit window editbox.
% set(handles.editthresh,'enable','on');                                      %Enable the threshold edit box.
% set(handles.popunits,'enable','on');                                        %Enable the threshold units pop-up menu.
% set(handles.editinit,'enable','on');                                        %Enable the time-out editbox.
set(handles.startbutton,'enable','on');                                     %Enable the start/stop button.
set(handles.pausebutton,'enable','on');                                     %Enable the pause button.
set(handles.feedbutton,'enable','on');                                      %Enable the manual feeding button.
temp = [0 0 0];                                                             %Set temp to a default color
if strcmpi(handles.device,'knob')
    temp = [0.9 0.7 0.9];                                                   %Set the label color to a light red.
elseif strcmpi(handles.device,'pull')                                       %If the current input device is a pull...
    temp = [0.7 0.9 0.7];                                                   %Set the label color to a light green.
elseif strcmpi(handles.device,'lever')                                      %If the current input device is a lever...
    temp = [0.7 0.7 0.9];                                                   %Set the label color to a light red.
elseif strcmpi(handles.device,'wheel')                                      %If the current input device is a wheel...
    temp = [0.9 0.9 0.7];                                                   %Set the label color to a light yellow.
elseif strcmpi(handles.device,'touch')                                      %If the current input device is a capacitive touch sensor...
    temp = [0.9 0.7 0.9];                                                   %Set the label color to a light magenta.
elseif strcmpi(handles.device,'both')                                       %If the current input device is a capacitive touch sensor...
    temp = [0.7 0.9 0.9];                                                   %Set the label color to a light cyan.
end
set(handles.label,'backgroundcolor',temp);                                  %Set the background color of all label editboxes.    
if handles.vns == 1                                                         %If VNS is turned on...
    set(handles.popvns,'foregroundcolor',[1 0 0]);                          %Make the "ON" text red.
elseif handles.vns == 2                                                     %Otherwise, if VNS is randomly presented...
    set(handles.popvns,'foregroundcolor',[0 0 1]);                          %Make the "RANDOM" text blue.
else                                                                        %Otherwise, if VNS is turned OFF...
    set(handles.popvns,'foregroundcolor','k');                              %Make the "ON" text black.
end

%Enable the top menu options.
set(handles.menu.stages.h,'enable','on');                                   %Enable the stages menu.
set(handles.menu.stages.view_spreadsheet,'enable','on');                    %Enable the "Open Spreadsheet" menu option.
set(handles.menu.stages.set_load_option,'enable','on');                     %Enable the stage-loading selection.


function MotoTrak_Behavior_Loop(h)

%
%MotoTrak_Behavior_Loop.m - Vulintus, Inc.
%
%   This function is the main behavioral loop for the MotoTrak program.
%   
%   UPDATE LOG:
%   07/06/2016 - Drew Sloan - Added in IR signal trial initiation
%       capability.
%

global run                                                                  %Create the global run variable.

Clear_Msg([],[],h.msgbox);                                                  %Clear the original Arduino connection message out of the listbox.

run = 1;                                                                    %Set the run variable to 1.
pause_text = 0;                                                             %Create a variable to hold a text handle for a pause label.
start_time = now;                                                           %Set the session start time.
endtime = start_time + h.session_dur/1440;                                  %Set a suggested session end time.
trial = 0;                                                                  %Make a counter to count trials.
feedings = 0;                                                               %Make a counter to count feedings.
cal(1) = h.slope;                                                           %Set the calibration slope for the device.
cal(2) = h.baseline;                                                        %Set the calibration baseline for the device.
minmax_ir = [1023,0,0];                                                     %Keep track of the minimum and maximum IR values.

fid = MotoTrak_Write_File_Header(h);                                        %Use the WriteFileHeader subfunction to write the file header.

%Create the variables for buffering the signal from the device.
pre_samples = round(1000*h.pre_trial_sampling/h.period);                    %Calculate how many samples are in the pre-trial sample period.
post_samples = round(1000*h.post_trial_sampling/h.period);                  %Calculate how many samples are in the post-trial sample period.
hit_samples = round(1000*h.hitwin/h.period);                                %Find the number of samples in the hit window.
hitwin = (pre_samples+1):(pre_samples+hit_samples);                         %Save the samples within the hit window.
buffsize = pre_samples + hit_samples + post_samples;                        %Specify the size of the data buffer, in samples.
minpkdist = round(100/h.period);                                            %Find the number of samples in a 100 ms window for finding peaks.

%Set the min peak height depending on the device connected
minpkheight = 0;
lever_return_point = 0;
if (strcmpi(h.device,{'lever'}) == 1)           
    minpkheight = h.total_range_in_degrees * 0.75;                          %A "press" must be at least 3/4 of the range of motion of the lever              
    %Set the point at which the lever must return to before a new press can be
    %initiated
    lever_return_point = h.total_range_in_degrees * 0.5;                    %Lever must return to the 50% point in its range before a new press begins
elseif (strcmpi(h.device,{'knob'}) == 1)           
    minpkheight = 3;
end

offset = ceil(minpkdist/2);                                                 %Calculate the number of samples to offset when grabbing the smoothed signal.
data = zeros(buffsize,3);                                                   %Create a matrix to buffer the stream data.
trial_data = zeros(buffsize,3);                                             %Create a matrix to hold the trial stream data.
mon_signal = zeros(buffsize,1);                                             %Create a matrix to hold the monitored signal.
trial_signal = zeros(buffsize,1);                                           %Create a matrix to hold the trial signal.
if strcmpi(h.device,'both')                                           %If this is a combined touch-pull stage...
    touch_signal = zeros(buffsize,1);                                       %Zero out the trial signal.
end
do_once = 1;                                                                %Create a one-shot checker to keep from counting transient signals on the first stream read.
vns_time = [];                                                              %Create a buffer matrix to hold VNS times.
maxthresh = 0;
sustained_pull_grams_threshold = 35;                                        %Hit threshold with respect to grams for sustained pull.

burst_stim_num = 0;                                                         %Create a variable to hold the number of times burst stimulation has happened (for burst stim mode only)
burst_stim_time = start_time;                                               %Create a variable to hold the time of the first burst stim (for burst stim mode only)

hold(h.trial_axes, 'off');                                            %Release the plot hold for the trial axes.
cla(h.trial_axes);                                                    %Clear any plots off the trial axes.

%For random stimulation modes, set the random stimulation times.
if h.vns == 2                                                         %If random stimulation is enabled...
    if strcmpi(h.stage(h.cur_stage).number,'P11')               %If the current stage is P11...
        num_stim = 180;                                                     %Set the desired total number of VNS events.
        isi = 5;                                                            %Set the fixed ISI between all events, VNS or catch trials.
        catch_trial_prob = 0.5;                                             %Set the catch trial probability.
        N = ceil(num_stim/(1-catch_trial_prob));                            %Calculate the required total number of events to meet the catch trial probability.
        temp = randperm(N);                                                 %Create random permutation of the events.
        temp = sort(temp(1:num_stim));                                      %Grab the indices for only the VNS events.
        rand_vns_times = isi*temp/86400;                                    %Set times for the random VNS events, in units of serial date number.
        rand_vns_times = rand_vns_times + now;                              %Adjust the times relative to the session start.
    elseif strcmpi(h.stage(h.cur_stage).number,'P15')           %If the current stage is P15...
        num_stim = 900;                                                     %Set the desired total number of VNS events.
        rand_vns_times = ones(1,num_stim);                                  %Create a matrix of 1-second inter-VNS intervals.
        rand_vns_times(1:round(num_stim/2)) = 3;                            %Set half of the inter-VNS intervals to 3 seconds.
        rand_vns_times = rand_vns_times(randperm(num_stim));                %Randomize the inter-VNS intervals.
        for i = num_stim:-1:2                                               %Step backward through the inter-VNS intervals.
            rand_vns_times(i) = sum(rand_vns_times(1:i));                   %Set each stimulation time as the sum of all precedingin inter-VNS intervals.
        end
        rand_vns_times = now + rand_vns_times/86400;                        %Convert the intervals to stimulation times, in units of serial date number.
    end
elseif h.vns == 3                                                     %If burst stimulation is enabled
    
    %Set the stimulus duration to 30 seconds for burst mode
    %We set this to a conservatice 29550 instead of 30000 so that we don't
    %accidentally trigger an extra pulse train at the end of 30 seconds of
    %stimulation.
    h.ardy.set_stim_dur(29550);
    
end

%Set the initiation threshold for static or adaptive thresholding.
curthresh = h.threshmin;                                              %Set the current hit threshold to the minimum hit threshold.
if strcmpi(h.threshadapt,'median')                                    %If this stage has a median-adapting threshold...
    max_tracker = nan(h.threshincr,1);                                %Create a matrix to track the maximum device reading within the hit window across trials.
end
if strcmpi(h.device,'touch')                                          %If the current device is the touch sensor...
    h.init = 0.5;                                                     %Set the initiation threshold to 0.5.
end

%Set the Arduino parameters for this session.
h.ardy.stream_enable(0);                                              %Disable streaming on the Arduino.
pause(0.2);                                                                 %Pause for 200 milliseconds to make sure idle scanning has stopped.
h.ardy.clear();                                                       %Clear any residual values from the serial line.
if h.vns == 1 && strcmpi(h.custom,'machado lab') && ...
        strcmpi(h.curthreshtype,'milliseconds/grams')                 %If stimulation is on and this is a the Machado lab variant...
    temp = round(1000*h.hitwin);                                      %Find the length of the hit window in milliseconds.
    h.ardy.set_stim_dur(temp);                                        %Set the default stimulation duration to the entire hit window.
    stim_time_out = round(1000*h.stim_time_out/...
        h.stage(h.cur_stage).period) - 1;                       %Calculate the number of samples in the stimulation time-out duration.
end
MotoTrak_Set_Stream_Params(h);                                        %Set the streaming properties on the Arduino.
h.ardy.stream_enable(1);                                              %Enable periodic streaming on the Arduino.


Total_Degrees_Turned = nan(500,1);

while run > 0                                                               %Loop until the user cancels the session.
                                                             
    trial = trial + 1;                                                      %Increment the trial counter.
    mon_signal(:) = 0;                                                      %Zero out the monitor signal.
    trial_signal(:) = 0;                                                    %Zero out the trial signal.
    if strcmpi(h.device,'both')                                       %If this is a combined touch-pull stage...
        touch_signal(:) = 0;                                                %Zero out the trial signal.
    end
    trial_data(:) = 0;                                                      %Zero out the trial data.
    base_value = 0;
    ir_initiate = 0;                                                        %Create a variable for triggering trial initiation with the IR signal.
    trial_buffsize = buffsize;                                              %Set the trial buffsize to be the entire buffer size.
    
    cla(h.stream_axes);                                               %Clear the streaming axes.
    p = zeros(1,3);                                                         %Pre-allocate a matrix to hold plot handles.
    p(1) = area(1:buffsize,mon_signal,...
        'linewidth',2,...
        'facecolor',[0.5 0.5 1],...
        'parent',h.stream_axes);                                      %Make an initiation areaseries plot.    
    set(h.stream_axes,'xtick',[],'ytick',[]);                         %Get rid of the x- y-axis ticks.
    max_y = [-0.1,1.3]*h.init;                                        %Calculate y-axis limits based on the trial initiation threshold.
    ylim(h.stream_axes,max_y);                                        %Set the new y-axis limits.
    xlim(h.stream_axes,[1,buffsize]);                                 %Set the x-axis limits according to the buffersize.
    ir_text = text(0.02*buffsize,max_y(2)-0.03*range(max_y),'IR',...
        'horizontalalignment','left',...
        'verticalalignment','top',...
        'margin',2,...
        'edgecolor','k',...
        'backgroundcolor','w',...
        'fontsize',10,...
        'fontweight','bold',...
        'parent',h.stream_axes);                                      %Create text to show the state of the IR signal.
    clock_text = text(0.97*buffsize,max_y(2)-0.03*range(max_y),...
        ['Session Time: ' datestr(now-start_time,13)],...
        'horizontalalignment','right',...
        'verticalalignment','top',...
        'margin',2,...
        'edgecolor','k',...
        'backgroundcolor','w',...
        'fontsize',10,...
        'fontweight','bold',...
        'parent',h.stream_axes);                                      %Create text to show a session timer.
    if strcmpi(h.device,'both')                                       %If the user selected combined touch-pull...
        p(3) = area(1:buffsize,mon_signal,...
            'linewidth',2,...
            'facecolor',[0.5 1 0.5],...
            'parent',h.touch_axes);                                   %Make an initiation areaseries plot.
        line([1,buffsize],h.init*[1,1],...
            'color','k',...
            'linestyle',':',...
            'parent',h.touch_axes);                                   %Plot a dotted line to show the threshold.
        text(1,h.init,' Initiation Threshold',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'parent',h.touch_axes);                                   %Create text to label the the threshold line.
        set(h.touch_axes,'xtick',[],'ytick',[]);                      %Get rid of the x- y-axis ticks.
        max_y = [-1.3,1.3]*h.init;                                    %Calculate y-axis limits based on the trial initiation threshold.
        ylim(h.touch_axes,max_y);                                     %Set the new y-axis limits.
        xlim(h.touch_axes,[1,buffsize]);                              %Set the x-axis limits according to the buffersize.
    else                                                                    %Otherwise, if this isn't a combined touch-pull stage...
        line([1,buffsize],h.init*[1,1],...
            'color','k',...
            'linestyle',':',...
            'parent',h.stream_axes);                                  %Plot a dotted line to show the threshold.
        text(1,1,' Initiation Threshold',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'parent',h.stream_axes);                                  %Create text to label the the threshold line.
    end
    
    while (max(mon_signal) < h.init && ...
            ir_initiate == 0 && ...
            any(run == 1:2))                                                %Loop until the the initiation threshold is broken or the session is stopped.
    	temp = h.ardy.read_stream();                                  %Read in any new stream output.
        a = size(temp,1);                                                   %Find the number of new samples.
        if a > 0                                                            %If there was any new data in the stream.
            temp(:,2) = cal(1)*(temp(:,2) - cal(2));                        %Apply the calibration constants to the data signal.
            
            data(1:end-a,:) = data(a+1:end,:);                              %Shift the existing buffer samples to make room for the new samples.
            data(end-a+1:end,:) = temp;                                     %Add the new samples to the buffer.
            if do_once == 1                                                 %If this was the first stream read...
                data(1:buffsize-a,2) = data(buffsize-a+1,2);                %Set all of the preceding signal data points equal to the first point.           
                data(1:buffsize-a,3) = data(buffsize-a+1,3);                %Set all of the preceding IR data points equal to the first point.    
                do_once = 0;                                                %Set the checker variable to 1.
            end
            mon_signal(1:end-a,:) = mon_signal(a+1:end);                    %Shift the existing samples in the monitored to make room for the new samples.
            
            if (any(strcmpi(h.curthreshtype,{'degrees (total)'})))
                
                if h.cur_stage == 1
                    for i = buffsize-a+1:buffsize                                   %Step through each new sample in the monitored signal.
                        mon_signal(i) = data(i,2) - data(i-hit_samples+1,2);            %Find the change in the degrees integrated over the hit window.
                    end
                else
                    for i = buffsize-a+1:buffsize                                   %Step through each new sample in the monitored signal.
                        mon_signal(i) = data(i,2);                                      %Find the change in the degrees integrated over the hit window
                    end
                end
                
            elseif any(strcmpi(h.curthreshtype,{'bidirectional'}))       %If the current threshold type is the total number of degrees...
                for i = buffsize-a+1:buffsize                               %Step through each new sample in the monitored signal.
                    mon_signal(i) = abs(data(i,2));                         %Find the change in the degrees integrated over the hit window.
                end
            elseif any(strcmpi(h.curthreshtype,{'presses', 'fullpresses'}))                %If the current threshold type is presses (for LeverHD)
                if (strcmpi(h.device, {'knob'}) == 1)
                     for i = buffsize-a+1:buffsize                          %Step through each new sample in the monitored signal.
                          mon_signal(i) = abs(data(i,2) - data(i-hit_samples+1,2));
                     end
                else
                    %If the device is a lever, then run the proper code to
                    %decide if any "presses" are in the signal
                    presses_signal = data(:, 2) - minpkheight;
                    negative_bound = 0 - (minpkheight - lever_return_point);

                    presses_signal(presses_signal > 0) = 1;
                    presses_signal((presses_signal <= 0) & (presses_signal >= negative_bound)) = 0;
                    presses_signal(presses_signal < negative_bound) = -1;

                    original_indices = find(presses_signal ~= 0);
                    modified_presses_signal = presses_signal(presses_signal ~= 0);
                    modified_presses_signal(modified_presses_signal < 0) = 0;

                    diff_presses_signal = [0; diff(modified_presses_signal)];
                
                    mon_signal(1:end) = 0;
                    mon_signal(original_indices(diff_presses_signal == 1)) = 1;
                    mon_signal(1:(buffsize-a)) = 0;
                end
            elseif any(strcmpi(h.curthreshtype,{'grams (peak)', 'grams (sustained)'}))           %If the current threshold type is the peak pull force.
                if strcmpi(h.stage(h.cur_stage).number,'PASCI1')               %If the current stage is PASCI1...
                    mon_signal(buffsize-a+1:buffsize) = ...
                        abs(data(buffsize-a+1:buffsize,2));                          %Show the pull force at each point.
                else
                    mon_signal(buffsize-a+1:buffsize) = ...
                        data(buffsize-a+1:buffsize,2);                          %Show the pull force at each point.
                end
            elseif strcmpi(h.curthreshtype,'milliseconds (hold)')     %If the current threshold type is a sustained hold...
                mon_signal(buffsize-a+1:buffsize) = ...
                        (data(buffsize-a+1:buffsize,3) > 511.5);            %Digitize the threshold.
            elseif strcmpi(h.curthreshtype,'milliseconds/grams')      %If the current threshold type is a combined hold/pull...
                for i = buffsize-a+1:buffsize                               %Step through each new sample...
                    if data(i,3) > 511.5                                    %If the sample is a logical high...
                        mon_signal(i) = mon_signal(i-1) - 10;               %Add 10 milliseconds to the running count for this sample.
                    else                                                    %Otherwise...
                        if abs(mon_signal(i-1)) > h.init && ...
                                data(i,3) < 511.5                           %If the rat just released the sensor after holding for the appropriate time.
                            mon_signal(i) = h.init;                   %Set the monitor signal current sample to the initiation threshold.
                        else                                                %Otherwise...
                            mon_signal(i) = 0;                              %Reset the count.
                        end
                    end
                end
            end
            
            if h.ir == 1 && any(data(end-a+1:end,3) < minmax_ir(3))         %If IR-initiation is enabled and the IR beam is blocked...
                ir_initiate = 1;                                            %Initiate a trial.
            end
            
            if strcmpi(h.device,'both')                               %If this is a combined touch-pull session...
                set(p(1),'ydata',data(:,2));                                %Update the force area plot.
                max_y = [min([1.1*min(data(:,2)), -0.1*curthresh]),...
                    max([1.1*max(data(:,2)), 1.3*curthresh])];              %Calculate new y-axis limits.
                ylim(h.stream_axes,max_y);                            %Set the new y-axis limits.
                set(p(3),'ydata',mon_signal);                               %Update the touch area plot.
                max_y = [min([1.1*min(mon_signal), -1.1*h.init]),...
                    max([1.1*max(mon_signal), 1.1*h.init])];          %Calculate new y-axis limits.
                ylim(h.touch_axes,max_y);                             %Set the new y-axis limits.
            else                                                            %Otherwise...
                set(p(1),'ydata',mon_signal);                               %Update the area plot.
                max_y = [min([1.1*min(mon_signal), -0.1*curthresh]),...
                    max([1.1*max(mon_signal), 1.3*curthresh])];             %Calculate new y-axis limits.
                ylim(h.stream_axes,max_y);                            %Set the new y-axis limits.
            end
            ir_pos = [0.02*buffsize, max_y(2)-0.03*range(max_y)];           %Update the x-y position of the IR text object.
            minmax_ir(1) = min([minmax_ir(1); data(:,3)]);                  %Calculate a new minimum IR value.
            minmax_ir(2) = max([minmax_ir(2); data(:,3)]);                  %Calculate a new maximum IR value.
            if minmax_ir(2) - minmax_ir(1) >= 25                            %If the IR value range is less than 25...
                minmax_ir(3) = h.ir_initiation_threshold*(minmax_ir(2) -...
                    minmax_ir(1)) + minmax_ir(1);                           %Set the IR threshold to the specified relative threshold.
            elseif minmax_ir(1) == minmax_ir(2)                             %If there is no range in the IR values.
                minmax_ir(1) = minmax_ir(1) - 1;                            %Set the IR minimum to one less than the current value.
            end
            c = (data(end,3) - minmax_ir(1))/(minmax_ir(2) - minmax_ir(1)); %Calculate the color of the IR indicator.
            set(ir_text,'backgroundcolor',[1 c c],...
                'position',ir_pos);                                         %Color the IR indicator text according to the signal..
        end
        if run == 2 && pause_text == 0                                      %If the user has paused the session...
            pause_text = text(mean(xlim),mean(ylim),'PAUSED',...
                'horizontalalignment','center',...
                'verticalalignment','middle',...
                'margin',2,...
                'edgecolor','k',...
                'backgroundcolor','y',...
                'fontsize',14,...
                'fontweight','bold',...
                'parent',h.stream_axes);                              %Create text to show that the session is paused.
            fwrite(fid,0,'uint32');                                         %Write a trial number of zero.
            fwrite(fid,now,'float64');                                      %Write the pause time.
            fwrite(fid,'P','uint8');                                        %Write an 'P' (70) to indicate the session was paused.
        elseif pause_text ~= 0 && run ~= 2                                  %If the session is unpaused and a pause label still exists...
            delete(pause_text);                                             %Delete the pause label.
            pause_text = 0;                                                 %Set the pause label handle variable to zero.
            fwrite(fid,now,'float64');                                      %Write the unpause time.
        elseif pause_text ~= 0                                              %If the session is still paused and the pause label exists...
            set(pause_text,'position',[mean(xlim),mean(ylim)]);             %Update the pause label position to center it on the plot.
        end
        set(clock_text,...
            'position',[0.97*buffsize, max_y(2)-0.03*range(max_y)],...
            'string',['Session Time: ' datestr(now-start_time,13)]);        %Update the session timer text object.
        if now > endtime                                                    %If the suggested session time has passed...
            set(clock_text,'backgroundcolor','r');                          %Color the session timer text object red.
            endtime = Inf;                                                  %Set the new suggested end time to infinite.
        end
        if h.vns == 2                                                 %If random VNS is enabled...
            a = find(rand_vns_times > 0,1,'first');                         %Find the next random VNS time.
            if ~isempty(a) && now > rand_vns_times(a)                       %If the clock has reached the next random stimulation time.
                h.ardy.stim();                               %Trigger VNS through the Arduino.
                vns_time(end+1) = now;                                      %Save the current time as a VNS time.
                rand_vns_times(a) = 0;                                      %Mark this stimulation time as completed.
            end
        end
        pause(0.01);                                                        %Pause for 10 milliseconds to keep from overwhelming the processor.
        drawnow;                                                            %Update the figure and flush the event queue.
    end
    
    if run == 1                                                             %If the session is running and not paused or set for a manual feeding...
        if ir_initiate == 0                                                 %If the trial wasn't initiated by the IR detector...
            a = find(mon_signal >= h.init,1,'first') - 1;             %Find the timepoint where the trial initiation threshold was first crossed.
        else                                                                %Otherwise...
            a = buffsize;                                                   %Set initiation sample to the current sample.
        end
        cur_sample = buffsize - a + pre_samples;                            %Find the number of samples to copy from the pre-trail monitoring.
        a = a - pre_samples + 1;                                            %Find the start of the pre-trial period.
        try
            trial_data(1:cur_sample,:) = data(a:buffsize,:);                %Copy the pre-trial period to the trial data.
        catch err
            err
        end
        trial_start = [now, data(a,1)];                                     %Save the trial start times (computer and Arduino clocks).
        if any(strcmpi(h.curthreshtype,{'degrees (total)', ...
                'bidirectional'}))                                          %If the current threshold type is the total number of degrees...
            if h.cur_stage == 1
                base_value = min(data(end-200,2));                                    %Set the base value to the degrees value right at the initiation threshold crossing.
                trial_signal(1:cur_sample) = data(a:buffsize,2) - base_value;   %Copy the pre-trial wheel position minus the base value.
            else
                base_value = 0;                                                 %Set the base value to the degrees value right at the initiation threshold crossing.
                trial_signal(1:cur_sample) = data(a:buffsize,2);                %Copy the pre-trial wheel position minus the base value.    
            end
        elseif any(strcmpi(h.curthreshtype,...
                {'degrees/s','# of spins'}))                                %If the current threshold type is the number of spins or spin velocity.
            base_value = 0;                                                 %Set the base value to zero spin velocity.
            temp = diff(data(:,2));                                         %Find the wheel velocity at each point in the buffer.
            temp = boxsmooth(temp,minpkdist);                               %Boxsmooth the wheel velocity with a 100 ms smooth.
            trial_signal(1:cur_sample) = temp(a-1:buffsize-1);              %Grab the pre-trial spin velocity.
        elseif any(strcmpi(h.curthreshtype,{'grams (peak)', 'grams (sustained)'}))               %If the current threshold type is the peak pull force.
            base_value = 0;                                                 %Set the base value to zero force.
            if strcmpi(h.stage(h.cur_stage).number,'PASCI1')               %If the current stage is PASCI1...
                trial_signal(1:cur_sample) = abs(data(a:buffsize,2));                %Copy the pre-trial force values.
            else
                trial_signal(1:cur_sample) = data(a:buffsize,2);                %Copy the pre-trial force values.
            end
        elseif any(strcmpi(h.curthreshtype,{'presses', 'fullpresses'}))
            
            if (strcmpi(h.device,{'knob'}) == 1)
                base_value = data(a,2);
                trial_signal(1:cur_sample) = data(a:buffsize,2) - base_value;   %Copy the pre-trial wheel position minus the base value.
            else
                base_value = 0;
                trial_signal(1:cur_sample) = data(a:buffsize,2);
            end
        elseif strcmpi(h.curthreshtype,'milliseconds (hold)')         %If the current threshold type is a hold...
            base_value = cur_sample;                                        %Set the base value to the starting sample.
            trial_signal(cur_sample) = 10;                                  %Set the first sensor value to 10.
        elseif strcmpi(h.curthreshtype,'milliseconds/grams')          %If the current threshold type is a hold...
            h.ardy.play_hitsound(1);                                  %Play the hit sound.
            base_value = 0;                                                 %Set the base value to zero force.
            trial_signal(1:cur_sample) = data(a:buffsize,2);                %Copy the pre-trial force values.
%             touch_signal(1:cur_sample) = 1023 - data(a:buffsize,3);         %Copy the pre-trial touch values.
            touch_signal(1:cur_sample) = data(a:buffsize,3);                %Copy the pre-trial touch values.
            if h.vns == 1                                             %If stimulation is on...
                h.ardy.stim();                                        %Turn on stimulation.
            end
        end

        
        cla(h.stream_axes);                                           %Clear the current axes.
        p(1) = area(1:buffsize,trial_signal,...
            'linewidth',2,...
            'facecolor',[0.5 0.5 1],...
            'parent',h.stream_axes);                                  %Make an areaseries plot to show the trial signal.
        hold(h.stream_axes,'on');                                     %Hold the axes for multiple plots.
        
        if strcmpi(h.curthreshtype,'# of spins') ...
            || strcmpi(h.curthreshtype,'presses')
            p(2) = plot(-1,-1,'*r','parent',h.stream_axes);           %Mark the peaks with red asterixes.
        end
        
        hold(h.stream_axes,'off');                                    %Release the plot hold.
        if ~strcmpi(h.curthreshtype,'# of spins')                    %If the threshold type isn't number of spins...
            line([pre_samples,pre_samples + hit_samples],...
                curthresh*[1,1],...
                'color','k',...
                'linestyle',':',...
                'parent',h.stream_axes);                              %Plot a dotted line to show the threshold.
        end
        text(pre_samples,curthresh,'Hit Threshold',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'visible','off',...
            'parent',h.stream_axes);                                  %Create text to label the the threshold line.
        set(h.stream_axes,'xtick',[],'ytick',[]);                     %Get rid of the x- y-axis ticks.
        max_y = [min([1.1*min(trial_signal), -0.1*curthresh]),...
            1.3*max([trial_signal; curthresh])];                            %Calculate y-axis limits based on the hit threshold.
        ylim(h.stream_axes,max_y);                                    %Set the new y-axis limits.
        xlim(h.stream_axes,[1,buffsize]);                             %Set the x-axis limits according to the buffersize.
        ln = line(pre_samples*[1,1],max_y,...
            'color','k',...
            'parent',h.stream_axes);                                  %Plot a line to show the start of the hit window.
        ln(2) = line((pre_samples+hit_samples)*[1,1],max_y,...
            'color','k',...
            'parent',h.stream_axes);                                  %Plot a line to show the end of the hit window.
        ir_text = text(0.02*buffsize,max_y(2)-0.03*range(max_y),'IR',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'margin',2,...
            'edgecolor','k',...
            'backgroundcolor','w',...
            'fontsize',10,...
            'fontweight','bold',...
            'parent',h.stream_axes);                                  %Create text to show the state of the IR signal.
        clock_text = text(0.97*buffsize,max_y(2)-0.03*range(max_y),...
            ['Session Time: ' datestr(now-start_time,13)],...
            'horizontalalignment','right',...
            'verticalalignment','top',...
            'margin',2,...
            'edgecolor','k',...
            'backgroundcolor','w',...
            'fontsize',10,...
            'fontweight','bold',...
            'parent',h.stream_axes);                                  %Create text to show a session timer.
        peak_text = [];                                                     %Create a matrix to hold handles to peak labels.
        hit_time = 0;                                                       %Start off assuming an outcome of a miss.
        vns_time = 0;                                                       %Start off assuming VNS will not be delivered.
        
        if strcmpi(h.device,'both')                                   %If the user selected combined touch-pull...
            cla(h.touch_axes);                                        %Clear the touch axes.
            p(3) = area(1:buffsize,touch_signal,...
                'linewidth',2,...
                'facecolor',[0.5 1 0.5],...
                'parent',h.touch_axes);                               %Make an areaseries plot to show the trial signal.
            set(h.touch_axes,'xtick',[],'ytick',[]);                  %Get rid of the x- y-axis ticks.
            ylim(h.touch_axes,[0 1100]);                              %Set the new y-axis limits.
            xlim(h.touch_axes,[1,buffsize]);                          %Set the x-axis limits according to the buffersize.
        end   
        
    end
    
    first_sound = 0;
    second_sound = 0;
    
    while run == 1 && cur_sample < trial_buffsize                           %Loop until the end of the trial or the user stops the session/pauses/manual feeds.
        temp = h.ardy.read_stream();                                  %Read in any new stream output.
        a = size(temp,1);                                                   %Find the number of new samples.
        if a > 0                                                            %If there was any new data in the stream.
            temp(:,2) = cal(1)*(temp(:,2) - cal(2));                          %Apply the calibration constants to the data signal.
            
            data(1:end-a,:) = data(a+1:end,:);                              %Shift the existing buffer samples to make room for the new samples.
            data(end-a+1:end,:) = temp;                                     %Add the new samples to the buffer.
            if cur_sample + a > buffsize                                    %If more samples were read than we'll record for the trial...
                b = buffsize - cur_sample;                                  %Pare down the read samples to only those needed.
            else                                                            %Otherwise...
                b = a;                                                      %Grab all of the samples returned.
            end
            

            trial_data(cur_sample+(1:b),:) = temp(1:b,:);                   %Add the new samples to the trial data.            
            if any(strcmpi(h.curthreshtype,...
                    {'grams (peak)', 'grams (sustained)', 'degrees (total)', 'presses', ...
                    'fullpresses', 'bidirectional'}))                       %If the current threshold type is the total number of degrees or peak force...
                if strcmpi(h.curthreshtype, 'bidirectional')
                    trial_signal(cur_sample+(1:b)) = ...
                        abs(trial_data(cur_sample+(1:b),2) - base_value);
                    
                elseif strcmpi(h.stage(h.cur_stage).number,'PASCI1')               %If the current stage is PASCI1...
                    trial_signal(cur_sample+(1:b)) = ...
                        abs(trial_data(cur_sample+(1:b),2) - base_value);            %Save the new section of the wheel position signal, subtracting the trial base value. 
                else
                    trial_signal(cur_sample+(1:b)) = ...
                        trial_data(cur_sample+(1:b),2) - base_value;        %Save the new section of the wheel position signal, subtracting the trial base value. 
                end
            elseif any(strcmpi(h.curthreshtype,...
                {'degrees/s','# of spins'}))                                %If the current threshold type is the number of spins or spin velocity.
                temp = diff(data(:,2));                                     %Find the wheel velocity at each point in the buffer.
                temp = boxsmooth(temp,minpkdist);                           %Boxsmooth the wheel velocity with a 100 ms smooth.
                trial_signal(cur_sample+(-offset:b)) = ...
                        temp(buffsize-a-1-offset:buffsize-a+b-1);           %Find the wheel velocity thus far in the trial.
            elseif strcmpi(h.curthreshtype,'milliseconds (hold)')     %If the current threshold type is a hold...
            	trial_signal(cur_sample + (1:b)) = ...
                    10*(trial_data(cur_sample +(1:b),3) > 511.5);           %Digitize and save the new section of signal.
                for i = cur_sample + (1:b)                                  %Step through each new signa.
                    if trial_signal(i) > 0                                  %If the touch sensor is held for this sample...
                        trial_signal(i) = ...
                            trial_signal(i) + trial_signal(i-1);            %Add the sample time to all of the preceding non-zero sample times.
                    end
                end
            elseif strcmpi(h.curthreshtype,'milliseconds/grams')      %If the current threshold type is a hold...
                trial_signal(cur_sample+(1:b)) = ...
                        trial_data(cur_sample+(1:b),2) - base_value;        %Save the new section of the wheel position signal, subtracting the trial base value.
%                 touch_signal(cur_sample+(1:b)) = ...
%                     1023 - trial_data(cur_sample+(1:b),3);                  %Save the new section of the wheel position signal, subtracting the trial base value.
                touch_signal(cur_sample+(1:b)) = ...
                    trial_data(cur_sample+(1:b),3);                         %Save the new section of the wheel position signal, subtracting the trial base value.
                temp = cur_sample + b;                                      %Grab the current sample.
                if hit_time == 0 && ...
                        any(touch_signal(cur_sample+(1:b)) > 511.5)         %If the rat went back to the touch sensor...
                    trial_buffsize = cur_sample + b;                        %Set the new buffer timeout.
                    hit_time = -1;                                          %Set the hit time to -1 to indicate an abort.
                elseif h.vns == 1 && ...
                        any(trial_signal >= 5) && ...
                        all(trial_signal(temp-stim_time_out:temp) < 5)      %If stimulation is on and the rat hasn't pull the handle in half a second...
                    h.ardy.stim_off();                                %Immediately turn off stimulation.
                    vns_time = now;                                         %Save the current time as the hit time.                    
                end
                set(p(3),'ydata',touch_signal);                             %Update the area plot.
            end            
            
            if strcmpi(h.curthreshtype, 'degrees (total)') && ...      %If this is a knob and we are currently in hit window
                    any(cur_sample == hitwin) && hit_time == 0 && ...
                    any(h.cur_stage == h.sound_stages)
                if max(temp(:,2)) >= curthresh/3 && first_sound == 0        %If we have gone above 1/3 of our threshold, and have not played a sound
                    h.ardy.sound_1000(1);                             %Play the 1KHz sound
                    first_sound = 1;                                        %Set our first sound variable to 1 to indicate we have already played sound
                end

                if max(temp(:,2)) >= curthresh/2 && second_sound == 0   	%If we have gone above 2/3 of our threshold, and have not played this sound
                    h.ardy.sound_1100(1);                             %Play the 1.1KHz sound
                    second_sound = 1;                                       %Set our second sound varaible to 1 to indiacte we have played this sound
                end

                if any(temp(:,2) < 5)                                       %If we have any elements less than 5 (This constitutes as a "reset")
                    first_sound = 0;                                        %Set our sounds back to 0
                    second_sound = 0;                                       %Set our sounds back to 0
                end
            end
            
            set(p(1),'ydata',trial_signal);                                 %Update the area plot.

            if (any(strcmpi(h.curthreshtype, {'presses', 'fullpresses'})))
                
                %Find all the presses of the lever
                presses_signal = trial_signal(1:cur_sample+b) - minpkheight;
                negative_bound = 0 - (minpkheight - lever_return_point);
                
                presses_signal(presses_signal > 0) = 1;
                presses_signal((presses_signal <= 0) & (presses_signal >= negative_bound)) = 0;
                presses_signal(presses_signal < negative_bound) = -1;
                
                original_indices = find(presses_signal ~= 0);
                modified_presses_signal = presses_signal(presses_signal ~= 0);
                modified_presses_signal(modified_presses_signal < 0) = 0;
                
                diff_presses_signal = [0; diff(modified_presses_signal)];
                
                %Find the position/time of each press
                temp = original_indices(find(diff_presses_signal == 1))';
                
                %Find the position/time of each release
                release_points = original_indices(find(diff_presses_signal == -1))';
                
                %Set the magnitude of each press (this is constant.  it is
                %just the threshold, which is minpkheight).
                pks = [];
                pks(1:length(temp)) = minpkheight;
                
                rpks = [];
                rpks(1:length(release_points)) = lever_return_point;
                
            elseif (strcmpi(h.curthreshtype, 'grams (sustained)'))    % If the current threshold type is "sustained pull"
                
                release_points = [];
                rpks = [];
                pks = [];
                temp = [];
                
                %Here we will do something very similar to what we do for
                %lever presses.  The goal is to get the signal into a form
                %where we can analyze when the animal exceeded the hit
                %threshold, and then how long it stayed above the hit
                %threshold.
                
                %Zero the signal at the hit threshold
                sustained_signal = trial_signal(1:cur_sample+b) - sustained_pull_grams_threshold;
                
                %Make everything above the hit threshold a 1, and
                %everything below the hit threshold a 0.
                sustained_signal(sustained_signal > 0) = 1;
                sustained_signal(sustained_signal <= 0) = 0;
                
                %Now, in theory, if we see a string of 1's that is at least
                %as long as our "sustained" threshold, and as long as that
                %string of 1's starts and ends in the hit window, the
                %animal gets a hit.
            else
            
                %If the threshold type is presses (with the rotary encoder
                %lever), and the threshold is greater than 1 (we are not on a
                %shaping stage, then find peaks above a specific height
                [pks,temp] = PeakFinder(trial_signal,minpkdist);  
                release_points = [];
                rpks = [];
            
            end
            
            %Kick out all peaks that don't reach the minpkheight criterion
            try
                temp = temp(pks >= minpkheight);
                pks = pks(pks >= minpkheight);
            catch err
                err
            end
            
            try
                b = find(temp >= pre_samples & pks >= 1 &...
                    temp < pre_samples + hit_samples & ...
                    temp <= cur_sample + a - offset );                          %Find all of the of peaks in the hit window.
                br = find(release_points >= pre_samples & rpks >= 1 & ...
                    release_points < pre_samples + hit_samples & ...
                    release_points <= cur_sample + a - offset );

                rpks = rpks(br);
                release_points = release_points(br);
            catch err
                err
            end
            pks = pks(b);                                                   %Kick out all of the peaks outside of the hit window.
            temp = temp(b);                                                 %Kick out all of the peak times outside of the hit window.

            if hit_time == 0                                                %If the rat hasn't gotten a hit yet.
                if (any(strcmpi(h.curthreshtype,{'grams (peak)', ...
                        'degrees (total)','degrees/s','bidirectional',...
                        'milliseconds (hold)','milliseconds/grams'})) && ...
                        max(trial_signal(hitwin)) > curthresh) ||...
                        (strcmpi(h.curthreshtype,'# of spins') &&...
                        length(pks) >= curthresh)                           %If the trial threshold was exceeded within the hit window...
                    hit_time = now;                                         %Save the current time as the hit time.
                    h.ardy.trigger_feeder(1);                         %Trigger feeding on the Arduino.
                    if isfield(h,'variant') && ....
                            strcmpi(h.variant,'hollis')               %If this is a custom variant...
                    end
                    feedings = feedings + 1;                                %Add one to the feedings counter.
                    if strcmpi(h.custom,'machado lab')                %If this is the custom stage for Machado lab...
                        trial_buffsize = cur_sample + a + post_samples;     %Set the new buffer timeout.
                    end
                    
					%If this is not the regular pull task, play a sound when the animal gets a hit
					%Currently we don't want to play a sound for the
					%regular pull task, except for shaping stage
					%(handles.cur_stage == 1)
                    if ~strcmpi(h.device,'both')  
                        h.ardy.play_hitsound(1);                     	%Play the hit sound.
                    end
                    
                    if (~strcmpi(h.curthreshtype,{'grams (peak)'}) ... 
                            || h.cur_stage == 1)
						h.ardy.play_hitsound(1);                          %Play the hit sound.
                    end
					
					if h.vns == 1                                     %If VNS is enabled...
                        if ~strcmpi(h.curthreshtype,'milliseconds/grams')    %If this is the touch/pull variant for the Machado lab...
%                             handles.ardy.stim_off();                        %Immediately turn off stimulation.
%                             vns_time = now;                                 %Save the current time as the hit time.
%                         else                                                %Otherwise...
                            h.ardy.stim();                            %Trigger VNS through the Arduino.
                            vns_time = now;                                 %Save the current time as the hit time.
                        end
                    elseif h.vns == 3                                 %If we are in burst stim mode
                        %Check to see if 5 minutes has elapsed since the
                        %start of the session
                        elapsed_time = etime(datevec(now), datevec(burst_stim_time));
                        if (elapsed_time >= 300)
                            %If 5 min has elapsed, then we can pair this
                            %hit with a stim
                            if (burst_stim_num < 3)
                                %Record the first stim time as now
                                burst_stim_time = now;
                                burst_stim_num = burst_stim_num + 1;
                                
                                %Trigger the stimulator
                                h.ardy.stim();
                                
                                %Save the vns stim time so that it can be
                                %written out to the data file
                                vns_time = burst_stim_time;
                            end
                            
                        end
                        
                    end
                    if strcmpi(h.curthreshtype,'# of spins')         %If the threshold type was the number of spins...
                        ln(3) = line(temp(curthresh)*[1,1],max_y,...
                            'color',[0.5 0 0],...
                            'linewidth',2,...
                            'parent',h.stream_axes);               %Plot a line to show where the hit occurred at the current sample.
                    else                                                    %Otherwise...
                        ln(3) = line(cur_sample*[1,1],max_y,...
                            'color',[0.5 0 0],...,
                            'linewidth',2,...
                            'parent',h.stream_axes);                  %Plot a line to show where the hit occurred at the current sample.
                    end
                elseif (strcmpi(h.curthreshtype, 'presses'))

                    %Are there enough of these peaks?  If so, it is a
                    %hit.
                    if (length(pks) >= curthresh)
        
                        hit_time = now;                                         %Save the current time as the hit time.
                        
                        h.ardy.trigger_feeder(1);                         %Trigger feeding on the Arduino.
                        feedings = feedings + 1;                                %Add one to the feedings counter.
                        h.ardy.play_hitsound(1);                         %Play hit sound 
                        ln(3) = line(cur_sample*[1,1],max_y,...
                            'color',[0.5 0 0],...
                            'linewidth',2,...
                            'parent',h.stream_axes);                  %Plot a line to show where the hit occurred at the current sample.

                    end
                elseif (strcmpi(h.curthreshtype, 'fullpresses'))
                    
                    if (length(pks) >= curthresh && length(release_points) >= curthresh)
                        hit_time = now;
                        
                        h.ardy.trigger_feeder(1);                         %Trigger feeding on the Arduino.
                        feedings = feedings + 1;                                %Add one to the feedings counter.
                        h.ardy.play_hitsound(1);                         %Play hit sound 
                        ln(3) = line(cur_sample*[1,1],max_y,...
                            'color',[0.5 0 0],...
                            'linewidth',2,...
                            'parent',h.stream_axes);                  %Plot a line to show where the hit occurred at the current sample.
                    end
                    
                elseif (strcmpi(h.curthreshtype, 'grams (sustained)'))
                    
                    %Here we analyze the "sustained signal" to see if the
                    %animal has achieved a hit.  In order to achieve a hit,
                    %the animal must reach two criterion:
                    %(1) The sustained signal must have a string of 1's
                    %that lasts the duration of our "sustained threshold",
                    %which we are currently hardcoding to be 500ms, or 50
                    %samples.
                    %(2) The start of this string of 1's must be in the hit
                    %window.  The end of of the string of 1's may be
                    %outside the hit window.
                    
                    sustained_signal = sustained_signal';
                    sustained_pull = ones(1, curthresh);
                    indices_of_pulls = findstr(sustained_signal, sustained_pull);
                    
                    if (any(ismember(indices_of_pulls, hitwin)))
                        
                        hit_time = now;                                         %Save the current time as the hit time.
                        h.ardy.trigger_feeder(1);                         %Trigger feeding on the Arduino.
                        feedings = feedings + 1;                                %Add one to the feedings counter.
                        h.ardy.play_hitsound(1);                         %Play hit sound 
                        ln(3) = line(cur_sample*[1,1],max_y,...
                            'color',[0.5 0 0],...
                            'linewidth',2,...
                            'parent',h.stream_axes);               %Plot a line to show where the hit occurred at the current sample.
                        
                    end
                    
                end
            end
            
            set(p(1),'ydata',trial_signal);                                 %Update the area plot.
            
            if strcmpi(h.curthreshtype,'# of spins') ...
                    || strcmpi(h.curthreshtype,'presses')
                set(p(2),'xdata',temp-1,'ydata',pks);                       %Update the peak markers.
            
                for i = 1:length(pks)                                       %Step through each of the peaks.
                    if i > length(peak_text)                                %If this is a new peak since the last data read...
                        peak_text(i) = text(temp(i)-1,pks(i),num2str(i),...
                            'horizontalalignment','left',...
                            'verticalalignment','bottom',...
                            'fontsize',8,...
                            'fontweight','bold',...
                            'parent',h.stream_axes);                  %Create text to mark each peak in the hit window.
                    else                                                    %Otherwise, if this isn't a new peak...
                        set(peak_text(i),'position',[temp(i)-1,pks(i)]);        %Update the position of the peak label.
                    end
                end
            
            end
            
            max_y = [min([1.1*min(trial_signal), -0.1*curthresh]),...
                max([1.3*max(trial_signal), 1.3*curthresh])];               %Calculate new y-axis limits.
            ylim(h.stream_axes,max_y);                                %Set the new y-axis limits.
            set(ln,'ydata',max_y);                                          %Update the lines marking the hit window bounds.
            ir_pos = [0.02*buffsize, max_y(2)-0.03*range(max_y)];           %Update the x-y position of the IR text object.
            minmax_ir(1) = min([minmax_ir(1); data(:,3)]);                  %Calculate a new minimum IR value.
            minmax_ir(2) = max([minmax_ir(2); data(:,3)]);                  %Calculate a new maximum IR value.
            if minmax_ir(2) - minmax_ir(1) >= 25                            %If the IR value range is less than 25...
                minmax_ir(3) = h.ir_initiation_threshold*(minmax_ir(2) -...
                    minmax_ir(1)) + minmax_ir(1);                           %Set the IR threshold to the specified relative threshold.
            elseif minmax_ir(1) == minmax_ir(2)                             %If there is no range in the IR values.
                minmax_ir(1) = minmax_ir(1) - 1;                            %Set the IR minimum to one less than the current value.
            end
            c = (data(end,3) - minmax_ir(1))/(minmax_ir(2) - minmax_ir(1)); %Calculate the color of the IR indicator.
            set(ir_text,'backgroundcolor',[1 c c],...
                'position',ir_pos);                                         %Color the IR indicator text according to the signal..
            cur_sample = cur_sample + a;                                    %Add the number of new samples to the current sample counter.
        end
        set(clock_text,...
            'position',[0.97*buffsize, max_y(2)-0.03*range(max_y)],...
            'string',['Session Time: ' datestr(now-start_time,13)]);        %Update the session timer text object.
        if now > endtime                                                    %If the suggested session time has passed...
            set(clock_text,'backgroundcolor','r');                          %Color the session timer text object red.
            endtime = Inf;                                                  %Set the new suggested end time to infinite.
        end
        if h.vns == 2                                                 %If random VNS is enabled...
            a = find(rand_vns_times > 0,1,'first');                         %Find the next random VNS time.
            if ~isempty(a) && now > rand_vns_times(a)                       %If the clock has reached the next random stimulation time.
                h.ardy.stim();                                        %Trigger VNS through the Arduino.
                vns_time(end+1) = now;                                      %Save the current time as a VNS time.
                rand_vns_times(a) = 0;                                      %Mark this stimulation time as completed.
            end
        end
        pause(0.01);                                                        %Pause for 10 milliseconds to keep from overwhelming the processor.
        drawnow;                                                            %Update the figure and flush the event queue.
    end
    
    if h.vns == 1 && (~isempty(vns_time) && vns_time == 0) && ...
            strcmpi(h.curthreshtype,'milliseconds/grams')             %If stimulation is turned on and this is a combined touch/pull stage...
        h.ardy.stim_off();                                            %Immediately turn off stimulation.
        vns_time = now;                                                     %Save the current time as the hit time.
    end
                    
    if run == 1                                                             %If the session is still running...
        
        Total_Degrees_Turned(trial) = nanmax(trial_signal(hitwin));
        %Create a temporary variable for the y-axis data of this trial on
        %the trials plot
        y_data = 1;
        
        %Check to see if this trial was a hit or a miss
        if hit_time > 0                                                     %If the trial resulted in a hit...
            temp = 'HIT';                                                   %Show the user it was a hit.
        elseif hit_time < 0                                                 %If the trial resulted in an abort...
            temp = 'ABORT';                                                 %Show the user it was an abort.
            hit_time = 0;                                                   %Set the hit time to zero.
        else                                                                %Otherwise, if the trial resulted in a miss...
            temp = 'MISS';                                                  %Show the user it was a miss.
        end
        
        %Check the threshold type to display pertinent data to the user.
        %If the threshold type was number of presses
        if (any(strcmpi(h.curthreshtype, {'presses', 'fullpresses'})))
            %Then show the user the number of presses that occurred within 
            %the hit window.
            Add_Msg(h.msgbox,[datestr(now,13) ' - Trial ' ...
                num2str(trial) ' - ' temp ': ' num2str(length(pks))...
                ' presses.']);   
            
            %Save the number of peaks as the y-axis data for the trials
            %plot
            y_data = length(pks);
        elseif (strcmpi(h.curthreshtype, 'grams (peak)'))
            %Then show the user the peak force used by the rat within the
            %trial
            Add_Msg(h.msgbox,[datestr(now,13) ' - Trial ' ...
                num2str(trial) ' - ' temp ': ' num2str(round(max(pks)))...
                ' grams.']);   
            
            %Save the number of peaks as the y-axis data for the trials
            %plot
            y_data = round(max(pks));
        else
            Add_Msg(h.msgbox,[datestr(now,13) ' - Trial ' ...
                num2str(trial) ' - ' temp]);                                                %Show the user the trial results.
        end
        trial_data(:,1) = trial_data(:,1) - trial_start(2);                 %Subtract the start time from the sample times.
        
        fwrite(fid,trial,'uint32');                                         %Write the trial number.
        fwrite(fid,trial_start(1),'float64');                               %Write the start time of the trial.
        fwrite(fid,temp(1),'uint8');                                        %Write the first letter of 'HIT' or 'MISS' as the outcome.
        fwrite(fid,h.hitwin,'float32');                               %Write the hit window for this trial.
        fwrite(fid,h.init,'float32');                                 %Write the trial initiation threshold for reward for this trial.
        fwrite(fid,curthresh,'float32');                                    %Write the hit threshold for reward for this trial.
        fwrite(fid,length(hit_time),'uint8');                               %Write the number of hits in this trial.
        for i = 1:length(hit_time)                                          %Step through each of the hit/reward times.
            fwrite(fid,hit_time(i),'float64');                              %Write each hit/reward time.
        end
        fwrite(fid,length(vns_time),'uint8');                               %Write the number of VNS events in this trial.
        for i = 1:length(vns_time)                                          %Step through each of the VNS event times.
            fwrite(fid,vns_time(i),'float64');                              %Write each VNS event time.
        end
        vns_time = [];                                                      %Clear out the VNS times buffer.                    
        fwrite(fid,trial_buffsize,'uint32');                                %Write the number of samples in the trial data signal.
        fwrite(fid,trial_data(1:trial_buffsize,1)/1000,'int16');            %Write the millisecond timestamps for all datapoints.
        fwrite(fid,trial_data(1:trial_buffsize,2),'float32');               %Write all device signal datapoints.
        fwrite(fid,trial_data(1:trial_buffsize,3),'int16');                 %Write all IR signal datapoints.
        
        %Plot the trial on the trial axes
        %First we need to select the proper y-data for the new point
        trial_color = [0 0.7 0];                                            %Select the proper color for the new point
        if strcmpi(temp, 'miss')                                            %If the trial ended in a miss...
            trial_color = [0.7 0 0];                                        %Color the marker red.
        elseif strcmpi(temp, 'abort')                                       %If the trial ended in an abort...
            trial_color = [0.5 0.5 0];                                      %Color the marker yellow.
        end
        hold(h.trial_axes, 'on');                                     %Hold the trials axis
        
        try
            plot(h.trial_axes, trial, y_data, '*', 'Color', trial_color); %Plot the new trial on the trials axis
        catch e
            disp('Error while plotting to the trial results axis');
            disp(['Error message: ' e.message]);
        end
        
        if strcmpi(h.threshadapt,'median')                            %If this stage has a median-adapting threshold...
            max_tracker(1:end-1) = max_tracker(2:end);                      %Shift the previous maximum hit window values one spot, overwriting the oldest.             
            if any(strcmpi(h.curthreshtype,{'grams (peak)',...
                        'degrees (total)','degrees/s','bidirectional',...
                        'milliseconds/grams'}))                             %If the threshold was an analog reading...
                max_tracker(end) = max(trial_signal(hitwin));               %Add the last trial's maximum value to the maximum value tracking matrix.
            else                                                            %Otherwise, if the threshold was some kind of peak count...
                max_tracker(end) = length(pks);                             %Add the last trial's number of presses to the maximum value tracking matrix.
            end
            
            if ~any(isnan(max_tracker))                                     %If there's no NaN values in the maximum value tracking matrix...
                curthresh = median(max_tracker);                            %Set the current threshold to the median of the preceding trials.
                if curthresh > maxthresh
                        maxthresh = curthresh;
                end
                if strcmpi(h.curthreshtype, 'degrees (total)')
                    if curthresh < (0.7*maxthresh)
                        curthresh = 0.7*maxthresh;
                    end
                end
            end
            
        elseif strcmpi(h.threshadapt,'linear') && hit_time(1) ~= 0    %If this stage has a linear-adapting threshold and the last trial was scored as a hit.
        	curthresh = curthresh + h.threshincr;                     %Increment the hit threshold by the specified increment.
        elseif strcmpi(h.threshadapt, 'static')
            maxthresh = curthresh;
        end
        curthresh = min([curthresh, h.threshmax]);                    %Don't allow the hit threshold to exceed the specified maximum.
        curthresh = max([curthresh, h.threshmin]);                    %Don't allow the hit threshold to go below the specified minim.
        set(h.editthresh,'string',num2str(curthresh));                %Show the current threshold in the hit threshold editbox.

    elseif h.vns == 2 && run <= 0 && ~isempty(vns_time)               %If the user's stopped the session and random stimulation is enabled and there's VNS times to write...
        fwrite(fid,trial,'uint32');                                         %Write the trial number.
        fwrite(fid,now,'float64');                                          %Write the start time of the trial.
        fwrite(fid,'V','uint8');                                            %Write the letter "V" to indicate this is a dummy trial.
        fwrite(fid,0,'float32');                                            %Write a hit window of 0 for this trial.
        fwrite(fid,0,'float32');                                            %Write a trial initiation threshold of 0 for this trial.
        fwrite(fid,0,'float32');                                            %Write a hit threshold of 0 for this trial.
        fwrite(fid,0,'uint8');                                              %Write the number of hits in this trial.
        fwrite(fid,length(vns_time),'uint8');                               %Write the number of VNS events in this trial.
        for i = 1:length(vns_time)                                          %Step through each of the VNS event times.
            fwrite(fid,vns_time(i),'float64');                              %Write each VNS event time.
        end
        vns_time = [];                                                      %Clear out the VNS times buffer.
        fwrite(fid,0,'uint32');                                             %Write a buffer size of 0 for this trial.
    elseif run == 3                                                         %Otherwise if the user manually fed the rat...
        h.ardy.trigger_feeder(1);                                     %Trigger feeding on the Arduino.
        trial = trial - 1;                                                  %Subtract one from the trial counter.
        fwrite(fid,0,'uint32');                                             %Write a trial of zero.
        fwrite(fid,now,'float64');                                          %Write the current time.
        fwrite(fid,'F','uint8');                                            %Write an 'F' (70) to indicate a manual feeding.
        Add_Msg(h.msgbox,[datestr(now,13) ' - Manual Feeding.']);     %Show the user that the session has ended.
        run = 1;                                                            %Reset the run variable to 1.
    end
end

fclose(fid);                                                                %Close the session data file.

%Copy the session data file to the secondary path
try
    filename = [h.datapath h.ratname '\'];
    filename = [filename h.ratname '-' 'Stage' ...
        h.stage(h.cur_stage).number '\']; 
    mkdir(h.serverpath);                                              %Make the back-up data folder if it doesn't already exist.
    mkdir([h.serverpath h.ratname '\']);                        %Make a folder for this rat's data if it doesn't already exist.
    temp = [h.serverpath h.ratname '\' h.ratname '-' ... 
        'Stage' h.stage(h.cur_stage).number '\'];               %Create a folder name containing the rat name and stage number.
    mkdir(temp);                                                            %Make a folder for this stage's data if it doesn't already exist.
    copyfile(filename, temp);                                               %Copy saved datafile onto the Z drive
catch e
    disp(e.message);
    disp('There was an error while trying to save the data to the secondary datapath.');
end

try                                                                         %Attempt to clear the serial line.
    h.ardy.stream_enable(0);                                                %Disable streaming on the Arduino.
    h.ardy.clear();                                                         %Clear any residual values from the serial line.
catch err                                                                   %If an error occured while disabling streaming...
    warning(err.message);                                                   %Show the error message as a warning.
end

Max_Degrees_Turned = nanmax(Total_Degrees_Turned);
Mean_Degrees_Turned = nanmean(Total_Degrees_Turned);

set(h.startbutton,'string','START','foregroundcolor',[0 0.5 0]);            %Change the string on the Start/Stop button to make it say 'START'.
Add_Msg(h.msgbox,[datestr(now,13) ' - Session ended.']);                    %Show the user that the session has ended.

finalSessionOutput = ['Pellets fed: ' num2str(feedings) ', Max Threshold: ' ... 
    num2str(maxthresh) ', Thresholding Type: ' h.threshadapt ', Mean Degrees Turned: ' num2str(Mean_Degrees_Turned) ];
Add_Msg(h.msgbox, finalSessionOutput);

MotoTrak_Enable_Controls_Outside_Session(h);                      

MotoTrak_Idle(h);                                                           %Start the device-scanning loop.


function MotoTrak_Close(~,~,handles)

%This function is called when the user attempts to close the GUI.

global run                                                                  %Create the global run variable.

if run ~= 0                                                                 %If any program is currently running...
    run = 0;                                                                %Set the run variable to 0.
    pause(0.5);                                                             %Pause for 500 milliseconds to give any loops a chance to wrap up.
end
handles.ardy.stream_enable(0);                                              %Double-check that streaming on the Arduino is disabled.
handles.ardy.clear();                                                       %Clear any leftover stream output.
fclose(handles.ardy.serialcon);                                             %Delete the serial connection to the Arduino.
delete(handles.mainfig);                                                    %Delete the main figure.


function ardy = MotoTrak_Controller_V1p4_Serial_Functions(ardy)

%MotoTrak_Controller_V1p4_Serial_Functions.m - Vulintus, Inc., 2015
%
%   MotoTrak_Controller_V1p4_Serial_Functions defines and adds the Arduino
%   serial communication functions to the "ardy" structure. These functions
%   are for sketch version 1.4 and earlier, and may not work with newer
%   version (2.0+).
%
%   UPDATE LOG:
%   05/09/2016 - Drew Sloan - Separated V1.4 serial functions from the
%       Connect_MotoTrak function to allow for loading V2.0 functions.

%Basic status functions.
serialcon = ardy.serialcon;                                                 %Grab the handle for the serial connection.
ardy.check_serial = @()check_serial(serialcon);                             %Set the function for checking the serial connection.
ardy.check_sketch = @()check_sketch(serialcon);                             %Set the function for checking that the Ardyardy sketch is running.
ardy.check_version = @()simple_return(serialcon,'Z',[]);                    %Set the function for returning the version of the MotoTrak sketch running on the Arduino.
ardy.booth = @()simple_return(serialcon,'BA',1);                            %Set the function for returning the booth number saved on the Arduino.
ardy.set_booth = @(int)long_command(serialcon,'Cnn',[],int);                %Set the function for setting the booth number saved on the Arduino.


%Motor manipulandi functions.
ardy.device = @(i)simple_return(serialcon,'DA',1);                          %Set the function for checking which device is connected to an input.
ardy.baseline = @(i)simple_return(serialcon,'NA',1);                        %Set the function for reading the loadcell baseline value.
ardy.cal_grams = @(i)simple_return(serialcon,'PA',1);                       %Set the function for reading the number of grams a loadcell was calibrated to.
ardy.n_per_cal_grams = @(i)simple_return(serialcon,'RA',1);                 %Set the function for reading the counts-per-calibrated-grams for a loadcell.
ardy.read_Pull = @(i)simple_return(serialcon,'MA',1);                       %Set the function for reading the value on a loadcell.
ardy.set_baseline = ...
    @(int)long_command(serialcon,'Onn',[],int);                             %Set the function for setting the loadcell baseline value.
ardy.set_cal_grams = ...
    @(int)long_command(serialcon,'Qnn',[],int);                             %Set the function for setting the number of grams a loadcell was calibrated to.
ardy.set_n_per_cal_grams = ...
    @(int)long_command(serialcon,'Snn',[],int);                             %Set the function for setting the counts-per-newton for a loadcell.
ardy.trigger_feeder = @(i)simple_command(serialcon,'WA',1);                 %Set the function for sending a trigger to a feeder.
ardy.trigger_stim = @(i)simple_command(serialcon,'XA',1);                   %Set the function for sending a trigger to a stimulator.
ardy.stream_enable = @(i)simple_command(serialcon,'gi',i);                  %Set the function for enabling or disabling the stream.
ardy.set_stream_period = @(int)long_command(serialcon,'enn',[],int);        %Set the function for setting the stream period.
ardy.stream_period = @()simple_return(serialcon,'f',[]);                    %Set the function for checking the current stream period.
ardy.set_stream_ir = @(i)simple_command(serialcon,'ci',i);                  %Set the function for setting which IR input is read out in the stream.
ardy.stream_ir = @()simple_return(serialcon,'d',[]);                        %Set the function for checking the current stream IR input.
ardy.read_stream = @()read_stream(serialcon);                               %Set the function for reading values from the stream.
ardy.clear = @()clear_stream(serialcon);                                    %Set the function for clearing the serial line prior to streaming.
ardy.knob_toggle = @(i)simple_command(serialcon, 'Ei', i);                  %Set the function for enabling/disabling knob analog input.
ardy.sound_1000 = @(i)simple_command(serialcon, '1', []);
ardy.sound_1100 = @(i)simple_command(serialcon, '2', []);


%Behavioral control functions.
ardy.play_hitsound = @(i)simple_command(serialcon,'J', 1);                  %Set the function for playing a hit sound on the Arduino
% ardy.digital_ir = @(i)simple_return(serialcon,'1i',i);                      %Set the function for checking the digital state of the behavioral IR inputs on the Arduino.
% ardy.analog_ir = @(i)simple_return(serialcon,'2i',i);                       %Set the function for checking the analog reading on the behavioral IR inputs on the Arduino.
ardy.feed = @(i)simple_command(serialcon,'3A',1);                           %Set the function for triggering food/water delivery.
ardy.feed_dur = @()simple_return(serialcon,'4',[]);                         %Set the function for checking the current feeding/water trigger duration on the Arduino.
ardy.set_feed_dur = @(int)long_command(serialcon,'5nn',[],int);             %Set the function for setting the feeding/water trigger duration on the Arduino.
ardy.stim = @()simple_command(serialcon,'6',[]);                            %Set the function for sending a trigger to the stimulation trigger output.
ardy.stim_off = @()simple_command(serialcon,'h',[]);                            %Set the function for immediately shutting off the stimulation output.
ardy.stim_dur = @()simple_return(serialcon,'7',[]);                         %Set the function for checking the current stimulation trigger duration on the Arduino.
ardy.set_stim_dur = @(int)long_command(serialcon,'8nn',[],int);             %Set the function for setting the stimulation trigger duration on the Arduino.
ardy.lights = @(i)simple_command(serialcon,'9i',i);                         %Set the function for turn the overhead cage lights on/off.
ardy.autopositioner = @(int)long_command(serialcon,'0nn',[],int);             %Set the function for setting the stimulation trigger duration on the Arduino.


%Behavioral control functions.
ardy.play_hitsound = @(i)simple_command(serialcon,'J', 1);                  %Set the function for playing a hit sound on the Arduino
% ardy.digital_ir = @(i)simple_return(serialcon,'1i',i);                      %Set the function for checking the digital state of the behavioral IR inputs on the Arduino.
% ardy.analog_ir = @(i)simple_return(serialcon,'2i',i);                       %Set the function for checking the analog reading on the behavioral IR inputs on the Arduino.
ardy.feed = @(i)simple_command(serialcon,'3A',1);                           %Set the function for triggering food/water delivery.
ardy.feed_dur = @()simple_return(serialcon,'4',[]);                         %Set the function for checking the current feeding/water trigger duration on the Arduino.
ardy.set_feed_dur = @(int)long_command(serialcon,'5nn',[],int);             %Set the function for setting the feeding/water trigger duration on the Arduino.
ardy.stim = @()simple_command(serialcon,'6',[]);                            %Set the function for sending a trigger to the stimulation trigger output.
ardy.stim_off = @()simple_command(serialcon,'h',[]);                            %Set the function for immediately shutting off the stimulation output.
ardy.stim_dur = @()simple_return(serialcon,'7',[]);                         %Set the function for checking the current stimulation trigger duration on the Arduino.
ardy.set_stim_dur = @(int)long_command(serialcon,'8nn',[],int);             %Set the function for setting the stimulation trigger duration on the Arduino.
ardy.lights = @(i)simple_command(serialcon,'9i',i);                         %Set the function for turn the overhead cage lights on/off.
ardy.autopositioner = @(int)long_command(serialcon,'0nn',[],int);             %Set the function for setting the stimulation trigger duration on the Arduino.


%% This function checks the status of the serial connection.
function output = check_serial(serialcon)
if isa(serialcon,'serial') && isvalid(serialcon) && ...
        strcmpi(get(serialcon,'status'),'open')                             %Check the serial connection...
    output = 1;                                                             %Return an output of one.
    disp(['Serial port ''' serialcon.Port ''' is connected and open.']);    %Show that everything checks out on the command line.
else                                                                        %If the serial connection isn't valid or open.
    output = 0;                                                             %Return an output of zero.
    warning('CONNECT_MOTOTRAK:NonresponsivePort',...
        'The serial port is not responding to status checks!');             %Show a warning.
end


%% This function checks to see if the MotoTrak_V3_0.pde sketch is current running on the Arduino.
function output = check_sketch(serialcon)
fwrite(serialcon,'A','uchar');                                              %Send the check status code to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if output == 111                                                            %If the Arduino returned the number 111...
    output = 1;                                                             %...show that the Arduino connection is good.
else                                                                        %Otherwise...
    output = 0;                                                             %...show that the Arduino connection is bad.
end


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function simple_command(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function output = simple_return(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.


%% This function sends commands with 16-bit integers broken up into 2 characters encoding each byte.
function long_command(serialcon,command,i,int)     
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
i = dec2bin(int16(int),16);                                                 %Convert the 16-bit integer to a 16-bit binary string.
byteA = bin2dec(i(1:8));                                                    %Find the character that codes for the first byte.
byteB = bin2dec(i(9:16));                                                   %Find the character that codes for the second byte.
i = strfind(command,'nn');                                                  %Find the spot for the 16-bit integer bytes in the command.
command(i:i+1) = char([byteA, byteB]);                                      %Insert the byte characters into the command.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function reads in the values from the data stream when streaming is enabled.
function output = read_stream(serialcon)
timeout = now + 0.05*86400;                                                 %Set the following loop to timeout after 50 milliseconds.
while serialcon.BytesAvailable == 0 && now < timeout                        %Loop until there's a reply on the serial line or there's 
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
output = [];                                                                %Create an empty matrix to hold the serial line reply.
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    try
        streamdata = fscanf(serialcon,'%d')';
        output(end+1,:) = streamdata(1:3);                                  %Read each byte and save it to the output matrix.
    catch err                                                               %If there was a stream read error...
        warning('MOTOTRAK:StreamingError',['MOTOTRAKSTREAM READ '...
            'WARNING: ' err.identifier]);                                   %Show that a stream read error occured.
    end
end


%% This function clears any residual streaming data from the serial line prior to streaming.
function clear_stream(serialcon)
tic;                                                                        %Start a timer.
while serialcon.BytesAvailable == 0 && toc < 0.05                           %Loop for 50 milliseconds or until there's a reply on the serial line.
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    fscanf(serialcon,'%d');                                                 %Read each byte and discard it.
end


function ardy = MotoTrak_Controller_V2p0_Serial_Functions(ardy)

%MotoTrak_Controller_V2p0_Serial_Functions.m - Vulintus, Inc., 2016
%
%   MotoTrak_Controller_V2p0_Serial_Functions defines and adds the Arduino
%   serial communication functions to the "ardy" structure. These functions
%   are for sketch versions 2.0+ and may not work with older versions.
%
%   UPDATE LOG:
%   05/12/2016 - Drew Sloan - Created the basic sketch status functions.


serialcon = ardy.serialcon;                                                 %Grab the handle for the serial connection.

%Basic status functions.
ardy.check_serial = @()check_serial(serialcon);                             %Set the function for checking the status of the serial connection.
ardy.check_sketch = @()check_sketch(serialcon);                             %Set the function for checking the version of the CONNECT_MOTOTRAK sketch.
ardy.check_version = @()check_version(serialcon);                           %Set the function for returning the Arduino sketch version number.
ardy.set_serial_number = @(int)set_int32(serialcon,'C%%%%',int);            %Set the function for saving the controller serial number in the EEPROM.
ardy.get_serial_number = @()get_int32(serialcon,'D####');                   %Set the function for reading the controller serial number from the EEPROM.

% ardy.set_booth = @(int)long_cmd(serialcon,'B%%',[],int);                    %Set the function for setting the booth number saved on the Arduino.
% ardy.get_booth = @()simple_return(serialcon,'C#',1);                        %Set the function for returning the booth number saved on the Arduino.
% ardy.device = @(i)simple_return(serialcon,'D',1);                           %Set the function for checking which device is connected to the primary input.
% ardy.set_byte = @(int,i)long_cmd(serialcon,'E%%*',i,int);                   %Set the function for saving a byte in the EEPROM.
% ardy.get_byte = @(int)long_return(serialcon,'F%%#',[],int);                 %Set the function for returning a byte from the EEPROM.
% ardy.clear = @()clear_stream(serialcon);                                    %Set the function for clearing the serial line prior to streaming.
% 
% %Calibration functions.
% ardy.set_baseline = @(int)long_cmd(serialcon,'G%%',[],int);                 %Set the function for setting the primary device baseline value in the EEPROM.
% ardy.get_baseline = @()simple_return(serialcon,'H#',[]);                    %Set the function for reading the primary device baseline value from the EEPROM.
% ardy.set_slope = @(float)set_float(serialcon,'I%%%%',float);                %Set the function for setting the primary device slope in the EEPROM.
% ardy.get_slope = @()get_float(serialcon,'J####');                           %Set the function for reading the primary device slope from the EEPROM.
% ardy.set_range = @(float)set_float(serialcon,'K%%%%',float);                %Set the function for setting the primary device range in the EEPROM.
% ardy.get_range = @()get_float(serialcon,'L####');                           %Set the function for reading the primary device range from the EEPROM.
% 
% %Feeder functions.
% ardy.set_feed_trig_dur = @(int)long_cmd(serialcon,'M%%',[],int);            %Set the function for setting the feeding trigger duration on the Arduino.
% ardy.get_feed_trig_dur = @()simple_return(serialcon,'N',[]);                %Set the function for checking the current feeding trigger duration on the Arduino.
% ardy.set_feed_led_dur = @(int)long_cmd(serialcon,'O%%',[],int);             %Set the function for setting the feeder indicator LED duration on the Arduino.
% ardy.get_feed_led_dur = @()simple_return(serialcon,'P',[]);                 %Set the function for checking the current feeder indicator LED duration on the Arduino.
% ardy.feed = @()simple_cmd(serialcon,'Q',[]);                                %Set the function for triggering the feeder.
% 
% %Cage light functions.
% ardy.cage_lights = @(i)set_cage_lights(serialcon,'R*',i);                   %Set the function for setting the intensity (0-1) of the cage lights.
% 
% %One-shot input commands.
% ardy.get_val = @(i)simple_return(serialcon,'S*',i);                         %Set the function for checking the current value of any input.
% ardy.reset_rotary_encoder = @()simple_cmd(serialcon,'Z',[]);                %Set the function for resetting the current rotary encoder count.
% 
% %Streaming commands.
% ardy.set_stream_input = @(int,i)long_cmd(serialcon,'T%%*',i,int);           %Set the function for enabling/disabling the streaming states of the inputs.
% ardy.get_stream_input = @()simple_return(serialcon,'U',[]);                 %Returning the current streaming states of all the inputs.
% ardy.set_stream_period = @(int)long_cmd(serialcon,'V%%',[],int);            %Set the function for setting the stream period.
% ardy.get_stream_period = @()simple_return(serialcon,'W',[]);                %Set the function for checking the current stream period.
% ardy.stream_enable = @(i)simple_cmd(serialcon,'X*',i);                      %Set the function for enabling or disabling the stream.
% ardy.stream_trig_input = @(i)simple_cmd(serialcon,'Y*',i);                  %Set the function for setting the input to monitor for event-triggered streaming.
% ardy.read_stream = @()read_stream(serialcon);                               %Set the function for reading values from the stream.
% ardy.clear = @()clear_stream(serialcon);                                    %Set the function for clearing the serial line prior to streaming.
% 
% %Tone commands.
% ardy.set_tone_chan = @(i)simple_cmd(serialcon,'a*',i);                      %Set the function for setting the channel to play tones out of.
% ardy.set_tone_freq = @(i,int)long_cmd(serialcon,'b*%%',i,int);              %Set the function for setting the frequency of a tone.
% ardy.get_tone_freq = @(i)simple_return(serialcon,'g*',i);                   %Set the function for checking the current frequency of a tone.
% ardy.set_tone_dur = @(i,int)long_cmd(serialcon,'c*%%',i,int);               %Set the function for setting the duration of a tone.
% ardy.get_tone_dur = @(i)simple_return(serialcon,'h*',i);                    %Set the function for checking the current duration of a tone.
% ardy.set_tone_mon_input = @(i,int)long_cmd(serialcon,'d*%%',i,int);         %Set the function for setting the monitored input for triggering a tone.
% ardy.get_tone_mon_input = @(i)simple_return(serialcon,'i*',i);              %Set the function for checking the current monitored input for triggering a tone.
% ardy.set_tone_trig_type = @(i,int)long_cmd(serialcon,'e*%%',i,int);         %Set the function for setting the trigger type for a tone.
% ardy.get_tone_trig_type = @(i)simple_return(serialcon,'j*',i);              %Set the function for checking the current trigger type for a tone.
% ardy.set_tone_trig_thresh  = @(i,int)long_cmd(serialcon,'f*%%',i,int);      %Set the function for setting the trigger threshold for a tone.
% ardy.get_tone_trig_thresh = @(i)simple_return(serialcon,'k*',i);            %Set the function for checking the current trigger threshold for a tone.
% ardy.play_tone = @(i)simple_cmd(serialcon,'l*',i);                          %Set the function for immediate triggering of a tone.
% ardy.silence_tones = @()simple_cmd(serialcon,'m',[]);                       %Set the function for immediately silencing all tones.


%% This function checks the status of the serial connection.
function output = check_serial(serialcon)
if isa(serialcon,'serial') && isvalid(serialcon) && ...
        strcmpi(get(serialcon,'status'),'open')                             %Check the serial connection...
    output = 1;                                                             %Return an output of one.
    disp(['Serial port ''' serialcon.Port ''' is connected and open.']);    %Show that everything checks out on the command line.
else                                                                        %If the serial connection isn't valid or open.
    output = 0;                                                             %Return an output of zero.
    warning('CONNECT_MOTOTRAK:NonresponsivePort',...
        'The serial port is not responding to status checks!');             %Show a warning.
end


%% This function checks to see if the MotoTrak_Controller_V2_0 sketch is current running on the Arduino.
function output = check_sketch(serialcon)
fwrite(serialcon,'A','uchar');                                              %Send the check sketch code to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if output == 123                                                            %If the Arduino returned the number 123...
    output = 1;                                                             %...show that the Arduino connection is good.
else                                                                        %Otherwise...
    output = 0;                                                             %...show that the Arduino connection is bad.
end


%% This function checks the version of the Arduino sketch.
function output = check_version(serialcon)
fwrite(serialcon,'B','uchar');                                              %Send the check sketch code to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
output = output/100;                                                        %Divide the returned value by 100 to find the version number.


%% This function sends commands with a 32-bit integer number into 4 characters encoding each byte.
function set_int32(serialcon,command,int)     
i = strfind(command,'%%%%');                                                %Find the place in the command to insert the 32-bit floating-point bytes.
int = int32(int);                                                           %Make sure the input value is a 32-bit floating-point number.
bytes = typecast(int,'uint8');                                              %Convert the 32-bit floating-point number to 4 unsigned 8-bit integers.
for j = 0:3                                                                 %Step through the 4 bytes of the 32-bit binary string.
    command(i+j) = bytes(j+1);                                              %Add each byte of the 32-bit string to the command.
end
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function sends queries expected to return a 32-bit integer broken into 4 characters encoding each byte.
function output = get_int32(serialcon,command)     
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
tic;                                                                        %Start a timer.
output = [];                                                                %Create an empty matrix to hold the serial line reply.
while numel(output) < 4 && toc < 0.05                                       %Loop until the output matrix is full or 50 milliseconds passes.
    if serialcon.BytesAvailable > 0                                         %If there's bytes available on the serial line...
        output(end+1) = fscanf(serialcon,'%d');                             %Collect all replies in one matrix.
        tic;                                                                %Restart the timer.
    end
end
if numel(output) < 4                                                        %If there's less than 4 replies...
    warning('CONNECT_MOTOTRAK:UnexpectedReply',['The Arduino sketch '...
        'did not return 4 bytes for a 32-bit integer query.']);             %Show a warning and return the reply, whatever it is, to the user.
else                                                                        %Otherwise...
    output = typecast(uint8(output(1:4)),'int32');                          %Convert the 4 received unsigned integers to a 32-bit integer.
end


function handles = MotoTrak_Default_Config(handles)

handles.custom = 'none';                                                    %Set the customization field to 'none' by default.
handles.stage_mode = 2;                                                     %Set the default stage selection mode to 2 (1 = local TSV file, 2 = Google Spreadsheet).
handles.stage_url = ['https://docs.google.com/spreadsheets/d/1Iii9Z'...
    'pXjJIm3z1xA1R9iSh3Vkjp00erUD8g6KPU_0Uk/pub?output=tsv'];               %Set the google spreadsheet address.
handles.vns = 0;                                                            %Disable VNS by default.
handles.pre_trial_sampling = 1;                                             %Set the pre-trial sampling period, in seconds.
handles.post_trial_sampling = 2;                                            %Set the post-trial sampling period, in seconds.
handles.must_select_stage = 1;                                              %Set a flag saying the user must select a stage before starting.
handles.positioner_offset = 48;                                             %Set the zero position offset of the autopositioner, in millimeters.
handles.datapath = 'C:\MotoTrak\';                                          %Set the primary local data path for saving data files.
handles.ratname = [];                                                       %Create a field to hold the rat's name.
handles.sound_stages = [];                                                  %Create a field for marking stages with beeps.


function MotoTrak_Disable_Controls_Within_Session(handles)

%
%MotoTrak_Disable_Controls_Within_Session.m - Vulintus, Inc.
%
%   This function disables all of the uicontrol and uimenu objects that 
%   should not be active while MotoTrak is running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added disabling of uinmenu objects.
%

%Disable the uicontrol objects.
set(handles.editrat,'enable','off');                                        %Disable the rat name editbox.
set(handles.editbooth,'enable','off');                                      %Disable the booth number editbox.
set(handles.editport,'enable','off');                                       %Disable the port editbox.
set(handles.popdevice,'enable','off');                                      %Disable the device pop-up menu.
set(handles.popvns,'enable','off');                                         %Disable the VNS pop-up menu.
set(handles.popstage,'enable','off');                                       %Disable the stage pop-up menu.
set(handles.editpos,'enable','off');                                        %Disable the position editbox.
set(handles.popconst,'enable','off');                                       %Disable the constraint pop-up menu.
set(handles.edithitwin,'enable','off');                                     %Disable the hit window editbox.
set(handles.popunits,'enable','off');                                       %Disable the threshold units pop-up menu.
set(handles.editinit,'enable','off');                                       %Disable the time-out editbox.

%Enable the uimenu objects.
set(handles.menu.stages.h,'enable','off');                                  %Enable the stages menu.


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


function MotoTrak_Enable_Controls_Outside_Session(handles)

%
%MotoTrak_Enable_Controls_Outside_Session.m - Vulintus, Inc.
%
%   This function enables all of the uicontrol and uimenu objects that 
%   should be active when MotoTrak is not running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added enabling of uimenu objects.
%

%Enable the uicontrol objects.
set(handles.editrat,'enable','on');                                         %Enable the rat name editbox.
set(handles.editbooth,'enable','on');                                       %Enable the booth number editbox.
set(handles.editport,'enable','inactive');                                  %Make the port editbox inactive.
set(handles.popdevice,'enable','on');                                       %Enable the device pop-up menu.
set(handles.popvns,'enable','on');                                          %Enable the VNS pop-up menu.
set(handles.popstage,'enable','on');                                        %Enable the stage pop-up menu.
set(handles.editpos,'enable','on');                                         %Enable the position editbox.

%Enable the uimenu objects.
set(handles.menu.stages.h,'enable','on');                                   %Enable the stages menu.


function MotoTrak_Feed_Button_Press(hObject,~)

%
%MotoTrak_Feed_Button_Press.m - Vulintus, Inc.
%
%   This function causes a pellet or liquid reward to be dispensed when an
%   user presses the "FEED" button on the MotoTrak window.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added in the option to feed during idle mode.
%

global run                                                                  %Create the global run variable.

h = guidata(hObject);                                                       %Grab the handles structure from the GUI.
if run > 0                                                                  %If a session is currently running...
    run = 3;                                                                %Set the run variable to 3 to initiate a manual feeding. 
else                                                                        %Otherwise, if the program is currently idling...
    h.ardy.trigger_feeder(1);                                               %Trigger feeding on the Arduino.
end


function device = MotoTrak_Identify_Device(val)

if val < 20                                                                 %If the device-identifier value is less than ~0.1V...
    device = 'none';                                                        %There is no device connected.
elseif val >= 20 && val < 100                                               %If the device-identifier value is between ~0.1V and ~0.5V...
    device = 'lever';                                                       %The device is the lever (1.5 MOhm resistor).
elseif val >= 100 && val < 200                                              %If the device-identifier value is between ~0.5V and ~1.0V...
    device = 'knob';                                                        %The device is the knob (560 kOhm resistor).
elseif val >= 200 && val < 300                                              %If the device-identifier value is between ~1.0V and ~1.5V...
    device = 'knob';                                                        %The device is the knob (270 kOhm resistor).
elseif val >= 300 && val < 400                                              %If the device-identifier value is between ~1.5V and ~2.0V...
    device = 'knob';                                                        %The device is the knob (200 kOhm resistor).
elseif val >= 400 && val < 500                                              %If the device-identifier value is between ~2.0V and ~2.5V...
    device = 'pull';                                                        %The device is the pull (130 kOhm resistor).
elseif val >= 500 && val < 600                                              %If the device-identifier value is between ~2.5V and ~3.0V...
    device = 'pull';                                                        %The device is the pull (85 kOhm resistor).
elseif val >= 600 && val < 700                                              %If the device-identifier value is between ~3.0V and ~3.5V...
    device = 'pull';                                                        %The device is the pull (57 kOhm resistor).
elseif val >= 700 && val < 800                                              %If the device-identifier value is between ~3.5V and ~4.0V...
    device = 'pull';                                                        %The device is the pull (36 kOhm resistor).
elseif val >= 800 && val < 900                                              %If the device-identifier value is between ~4.0V and ~4.5V...
    device = 'lever';                                                       %The device is the lever (20 kOhm resistor).
elseif val >= 900 && val < 1000                                             %If the device-identifier value is between ~4.5V and ~5.0V...
    device = 'knob';                                                        %The device is the knob (8 kOhm resistor).
elseif val >= 1000                                                          %If the device-identifier value is greather than ~5.0V...
    device = 'knob';                                                        %The device is the knob (wire jumper).
end


function MotoTrak_Idle(handles)

%
%MotoTrak_Idle.m - Vulintus, Inc.
%
%   This function runs in the background to display the streaming input
%   signals from MotoTrak while a session is not running.
%   
%   UPDATE LOG:
%   07/06/2016 - Drew Sloan - Added in IR signal trial initiation
%       capability.
%   09/12/2016 - Drew Sloan - Replaced the warning in the catch statement
%       at the end with fprintf to suppress the warning noise.
%

global run                                                                  %Create the global run variable.

p = area(1,1,...
    'linewidth',2,...
    'facecolor',[0.5 0.5 1],...
    'parent',handles.stream_axes);                                          %Plot some dummy data to be overwritten as an areaseries plot.
l = line([1,1],[1,1],...
    'color','k',...
    'linestyle',':',...
    'visible','off',...
    'parent',handles.stream_axes);                                          %Plot a dotted line to show the threshold.
thresh_text = text(1,1,'Threshold',...
    'horizontalalignment','left',...
    'verticalalignment','top',...
    'fontsize',8,...
    'fontweight','bold',...
    'visible','off',...
    'parent',handles.stream_axes);                                          %Create text to label the the threshold line.
set(handles.stream_axes,'xtick',[],'ytick',[]);                             %Get rid of the x- y-axis ticks.
ir_text = text(1,1,'IR',...
    'horizontalalignment','left',...
    'verticalalignment','top',...
    'margin',2,...
    'edgecolor','k',...
    'backgroundcolor','w',...
    'fontsize',10,...
    'fontweight','bold',...
    'visible','off',...
    'parent',handles.stream_axes);                                          %Create text to show the state of the IR signal.
if strcmpi(handles.device,'both')                                           %If the user selected combined touch-pull...
    p2 = area(1,1,...
        'linewidth',2,...
        'facecolor',[0.5 1 0.5],...
        'parent',handles.touch_axes);                                       %Plot some dummy data to be overwritten as an areaseries plot.
    l2 = line([1,1],511.5*[1,1],...
        'color','k',...
        'linestyle',':',...
        'parent',handles.touch_axes);                                       %Plot a dotted line to show the threshold.
    text(1,511.5,'Threshold',...
        'horizontalalignment','left',...
        'verticalalignment','top',...
        'fontsize',8,...
        'fontweight','bold',...
        'parent',handles.touch_axes);                                       %Create text to label the the threshold line.
    set(handles.touch_axes,'xtick',[],'ytick',[],'ylim',[0,1100]);          %Get rid of the x- y-axis ticks.
end
run = -2;                                                                   %Initially set the run variable to -2.
handles.ardy.clear();                                                       %Clear any residual values from the serial line.
do_once = 0;                                                                %Make a checker variable to see if a stream read is the first stream read.

while run < 0                                                               %Loop until the user starts a session.
    if run == -2                                                            %If the user has changed some streaming parameter...
        handles.ardy.stream_enable(0);                                      %Disable streaming on the Arduino.
        handles = guidata(handles.mainfig);                                 %Grab the handles structure from the main figure.
        buffsize = round(5000*handles.hitwin/handles.period);               %Specify the size of the data buffer, in samples.        
        hit_samples = round(1000*handles.hitwin/handles.period);            %Find the number of samples in the hit window.
        if strcmpi(handles.device,'both')                                   %If the current device is the combined touch-pull sensor...
            if buffsize > 1000                                              %If there's more than 1000 samples in the buffer...
                buffsize = 1000;                                            %Set the buffer size to 1000.
                hit_samples = 200;                                          %Set the hit samples to 200.
            end
        end
        minpkdist = round(100/handles.period);                              %Find the number of samples in a 100 ms window for finding peaks.
        data = zeros(buffsize,3);                                           %Create a matrix to buffer the stream data.
        MotoTrak_Set_Stream_Params(handles);                                %Update the streaming properties on the Arduino.
        handles.ardy.clear();                                               %Clear any residual values from the serial line.
        signal = zeros(buffsize,1);                                         %Create a matrix to hold the monitored signal.
        set(p,'xdata',(1:buffsize)','ydata',signal);                        %Zero the previous area plot.
        if strcmpi(handles.device,'touch')                                  %If the current device is the touch sensor...
            handles.threshmin = 511.5;                                      %Set the minimum threshold to half of the analog range.
        elseif strcmpi(handles.device,'both')                               %If the current device is the combined touch-pull sensor...
            touch_signal = zeros(buffsize,1);                               %Create a matrix to hold the monitored touch signal.
            set(p,'xdata',(1:buffsize)','ydata',touch_signal);              %Create a matrix to hold the monitored touch signal.
            set(l2,'xdata',[1,buffsize]);                                   %Update the threshold line.
            xlim(handles.touch_axes,[1,buffsize]);                          %Set the x-axis limits according to the buffersize.
        end
        set(l,'ydata',handles.threshmin*[1,1],'xdata',[1,buffsize],...
            'visible','on');                                                %Update the threshold-marking line.
        max_y = [-0.1,1.3]*handles.threshmin;                               %Set the initial y-axis limits according to the threshold value
        ylim(handles.stream_axes,max_y);                                    %Set the y-axis limits.
        xlim(handles.stream_axes,[1,buffsize]);                             %Set the x-axis limits according to the buffersize.
        set(thresh_text,'position',[0.01*buffsize, handles.threshmin],...
            'visible','on');                                                %Update the position of the threshold label.
%        ir_pos = [0.05*buffsize, max_y(2)-0.05*range(max_y)];               %Update the x-y position of the IR text object.
%        set(ir_text,'position',ir_pos,'visible','on');                      %Update the position of the IR input label.
        cal(1) = handles.slope;                                             %Set the calibration slope for the device.
        cal(2) = handles.baseline;                                          %Set the calibration baseline for the device.
        handles.ardy.stream_enable(1);                                      %Re-enable periodic streaming on the Arduino.
        run = -1;                                                           %Set the run variable back to -1.
        do_once = 0;                                                        %Reset the checker variable to zero out the signal before the first stream read.
    end
    if strcmpi(handles.ardy.serialcon.Status,'closed')                      %If the serial connection has been closed...
        run = 0;                                                            %Set the run variable to zero.
        break                                                               %Break out of the while loop.
    end
    temp = handles.ardy.read_stream();                                      %Read in any new stream output.
          
    a = size(temp,1);                                                       %Find the number of new samples.
    if a > 0                                                                %If there was any new data in the stream.
        
        temp(:,2) = cal(1)*(temp(:,2) - cal(2));                            %Apply the calibration constants to the data signal.
        
        data(1:end-a,:) = data(a+1:end,:);                                  %Shift the existing buffer samples to make room for the new samples.
        data(end-a+1:end,:) = temp;                                         %Add the new samples to the buffer.
        
        signal(1:end-a,:) = signal(a+1:end);                                %Shift the existing samples in the monitored to make room for the new samples.
        if strcmpi(handles.curthreshtype,'milliseconds/grams')              %If the current threshold type is the combined touch-pull...
            touch_signal(1:end-a,:) = touch_signal(a+1:end);                %Shift the existing samples in the monitored to make room for the new samples.
        end
        if do_once == 0                                                     %If this was the first stream read...                     
            data(1:buffsize-a,2) = data(buffsize-a+1,2);                    %Set all of the preceding data points equal to the first point.
            do_once = 1;                                                    %Set the checker variable to 1.
        end
        
        if strcmpi(handles.curthreshtype,'degrees (total)')
            for i = buffsize-a+1:buffsize                                   %Step through each new sample in the monitored signal.
                signal(i) = data(i,2);                                      %Find the change in the degrees integrated over the hit window.
            end
        elseif any(strcmpi(handles.curthreshtype,{'presses', 'fullpresses'}))
            if (strcmpi(handles.device,{'knob'}) == 1)
                for i = buffsize-a+1:buffsize                                   %Step through each new sample in the monitored signal.
                    signal(i) = data(i,2) - data(i-hit_samples+1,2);            %Find the change in the degrees integrated over the hit window.
                end
            else
                for i = 1:buffsize
                    signal(i) = data(i,2);            
                end
            end
        elseif any(strcmpi(handles.curthreshtype,{'grams (peak)', 'grams (sustained)'}))               %If the current threshold type is the peak pull force.
            
            if strcmpi(handles.stage(handles.cur_stage).number,'PASCI1')               %If the current stage is PASCI1...
                signal(buffsize-a+1:buffsize) = abs(data(buffsize-a+1:buffsize,2));  %Show the pull force at each point.
            else
                signal(buffsize-a+1:buffsize) = data(buffsize-a+1:buffsize,2);  %Show the pull force at each point.
            end
        elseif strcmpi(handles.curthreshtype,'milliseconds (hold)')         %If the current threshold time is a hold...
%             signal(buffsize-a+1:buffsize) = ...
%                 1023 - data(buffsize-a+1:buffsize,3);                       %Read in the signal coming from the touch sensor.
            signal(buffsize-a+1:buffsize) = ...
                data(buffsize-a+1:buffsize,3);                              %Read in the signal coming from the touch sensor.
        elseif strcmpi(handles.curthreshtype,'milliseconds/grams')          %If the current threshold type is the combined touch-pull...
            signal(buffsize-a+1:buffsize) = data(buffsize-a+1:buffsize,2);  %Show the pull force at each point.
%             touch_signal(buffsize-a+1:buffsize) = ...
%                 1023 - data(buffsize-a+1:buffsize,3);                       %Read in the signal coming from the touch sensor.
            touch_signal(buffsize-a+1:buffsize) = ...
            	data(buffsize-a+1:buffsize,3);                              %Read in the signal coming from the touch sensor.
            set(p2,'ydata',touch_signal);                                   %Update the touch area plot.
        end
        
        set(p,'ydata',signal);                                              %Update the area plot.
        if max(signal(end-hit_samples+1:end),1) > handles.threshmin         %If the signal exceeded the threshold in the last hit window...
            set(thresh_text,'color','r');                                   %Color the threshold text label red.
        else                                                                %Otherwise...
            set(thresh_text,'color','k');                                   %Color the threshold text label black.
        end
        max_y = [min([1.1*min(signal), -0.1*handles.threshmin]),...
            max([1.1*max(signal), 1.3*handles.threshmin])];                 %Calculate new y-axis limits.
        ylim(handles.stream_axes,max_y);                                    %Set the new y-axis limits.
        ir_pos = [0.05*buffsize, max_y(2)-0.05*range(max_y)];               %Update the x-y position of the IR text object.
        if data(end,3) == 1                                                 %If the nosepoke is blocked...
            set(ir_text,'backgroundcolor','r','position',ir_pos);           %Color the IR indicator text red.
        else                                                                %Otherwise, if the nosepoke isn't blocked.
            set(ir_text,'backgroundcolor','w','position',ir_pos);           %Color the IR indicator text white.
        end
    end
    if (handles.delay_autopositioning ~= 0 && ...
            now > handles.delay_autopositioning)                            %If an autopositioning delay is currently in force, but has now lapsed.
        temp = round(10*(handles.positioner_offset - 10*handles.position)); %Calculate the absolute position to send to the autopositioner.
        handles.ardy.autopositioner(temp);                                  %Set the specified position value.
        handles.delay_autopositioning = 0;                                  %Reset the autopositioning delay value to zero.
    end
    if ishandle(handles.mainfig)                                            %If the main GUI's still open...
        pause(0.01);                                                        %Pause for 10 milliseconds to keep from overwhelming the processor.
        drawnow;                                                            %Update the figure and flush the event queue.
    else                                                                    %Otherwise, if the main GUI was closed....
        run = 0;                                                            %Set the run variable to zero.
    end
end

try                                                                         %Attempt to close the serial connection.
    if strcmpi(handles.ardy.serialcon.Status,'closed') || ...
            ~ishandle(handles.mainfig)                                      %If the serial connection or the main GUI has been closed...
        delete(handles.ardy.serialcon);                                     %Delete the serial object connecting to the Arduino.
    else                                                                    %Otherwise, if the serial connection is still open...
        handles.ardy.stream_enable(0);                                      %Disable streaming on the Arduino.
        handles.ardy.clear();                                               %Clear any residual values from the serial line.
        Add_Msg(handles.msgbox,[datestr(now,13) ' - Idle mode stopped.']);  %Show the user that the session has ended.
    end
    handles.ardy.clear();                                                   %Clear any residual values from the serial line.
catch err                                                                   %If an error occured while closing the serial line...
    cprintf([1,0.5,0],'WARNING: %s\n',err.message);                         %Show the error message as a warning.
    str = ['\t<a href="matlab:opentoline(''%s'',%1.0f)">%s '...
        '(line %1.0f)</a>\n'];                                              %Create a string for making a hyperlink to the error-causing line in each function of the stack.
    for i = 2:numel(err.stack)                                              %Step through each script in the stack.
        cprintf([1,0.5,0],str,err.stack(i).file,err.stack(i).line,...
            err.stack(i).name, err.stack(i).line);                          %Display a jump-to-line link for each error-throwing function in the stack.
    end
end


function handles = MotoTrak_Load_Config(handles)

%
%MotoTrak_Load_Config.m - Vulintus, Inc.
%
%   MotoTrak_Load_Config loads the entries of a custom MotoTrak
%   configuration file and overwrites any existing default values.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Added an extra index to the carriage return
%       list to prevent skipping of final entries.
%

abbrev_fields = {'SESSION DURATION','session_dur';...
    'MAIN DATA LOCATION','datapath'};                                       %List the parameter names that have corresponding abbreviations.

placeholder = [handles.mainpath 'temp_config.temp'];                        %Set the filename for the temporary placeholder file.

if exist(placeholder,'file')                                                %If the placeholder file exists...
    temp = dir(placeholder);                                                %Grab the file information for the placeholder file.
    while exist(placeholder,'file') && now - temp.datenum < 1/86400         %Loop until the placeholder is deleted or until 1 second has passed.
        pause(0.1);                                                         %Pause for 100 milliseconds.
    end
    if exist(placeholder,'file')                                            %If the placeholder still exists...
        delete(placeholder);                                                %Delete the placeholder file.
    end
end

[fid, errmsg] = fopen(placeholder,'wt');                                    %Create a temporary placeholder file.
if fid == -1                                                                %If a file could not be created...
    warndlg(sprintf(['Could not create a placeholder file '...
        'in:\n\n%s\n\nError:\n\n%s'],placeholder,...
        errmsg),'MotoTrak File Write Error');                               %Show a warning.
end
fprintf(fid,'Placeholder Created: %s\n',datestr(now,0));                    %Write the file creation time to the placeholder file.
fclose(fid);                                                                %Close the placeholder file.

[fid, errmsg] = fopen(handles.config_file,'r');                             %Open the configuration file for reading as text.
if fid == -1                                                                %If the file could not be opened...
    warndlg(sprintf(['Could not open the configuration file '...
        'in:\n\n%s\n\nError:\n\n%s'],handles.config_file,...
        errmsg),'MotoTrak File Read Error');                                %Show a warning.
end
txt = fread(fid,'*char');                                                   %Read in the data as characters.
fclose(fid);                                                                %Close the text file.

a = [0; find(txt == 10); length(txt) + 1];                                  %Find all carriage returns in the txt data.

for i = 1:length(a) - 1                                                     %Step through all lines in the data.
    ln = txt(a(i)+1:a(i+1)-1)';                                             %Grab the line of text.
    ln(ln == 0) = [];                                                       %Kick out all null characters.
    j = find(ln == ':',1,'first');                                          %Find the first colon separating the parameter name from the value.
    if ~isempty(j) && j > 1                                                 %If a parameter was found for this line.
        field = ln(1:j-1);                                                  %Grab the parameter name.
        val = ln(j+2:end);                                                  %Grab the parameter value.
        j = strcmpi(field,abbrev_fields(:,1));                              %Check to see if the parameter name has a corresponding abbreviations.
        if any(j)                                                           %If the parameter name has a corresponding abbreviation...
            field = abbrev_fields{j,2};                                     %Use the abbreviation as the field name.
        else                                                                %Otherwise...
            field = lower(field);                                           %Convert the field name to all lower-case.
            field(field < 'a' | field > 'z') = 95;                          %Set all non-text characters to underscores.
        end
        j = find(val > 32,1,'first') - 1;                                   %Find the first non-special character in the parameter value.
        if j > 0                                                            %If there were any preceding special characters...
            val(1:j) = [];                                                  %Kick out the leading special characters.
        end
        j = find(val > 32,1,'last') + 1;                                    %Find the last non-special character in the parameter value.
        if j <= length(val)                                                 %If there were any following special characters...
            val(j:end) = [];                                                %Kick out the trailing special characters.
        end
        if all(val >= 45 & val <= 58)                                       %If all of the value characters are numeric characters...
            val = str2double(val);                                          %Convert the value string to a number.
        else                                                                %Otherwise...
            temp = setdiff(val,[32,39,44:59,91,93]);                        %Find all characters that wouldn't work with an eval command.
            if isempty(temp)                                                %If there are no non-evaluatable characters...
                eval(['val = ' val ';']);                                   %Set the field value by evaluating the string.
            end
        end
        handles.(field) = val;                                              %Save the header value to a field with the parameter name.
    end
end


function h = MotoTrak_Load_Stage(h)

%
%MotoTrak_Load_Stage.m - Vulintus, Inc.
%
%   MotoTrak_Load_Stage loads in the parameters for a single MotoTrak
%   training/testing stage, displays the stage information on the GUI, and
%   adjusts the plotting to reflect the updated threshold values.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Added session duration as a stage parameter.
%

Add_Msg(h.msgbox,[datestr(now,13) ' - Current stage is '...
    h.stage(h.cur_stage).description '.']);                                 %Show the user what new stage was selected is.
d = h.stage(h.cur_stage).device;                                            %Grab the required device for the current stage.
Add_Msg(h.msgbox,[datestr(now,13) ...
    ' - Current device is the ' d '.']);                                    %Show the user what the new current device is.

h.threshmax = h.stage(h.cur_stage).threshmax;                               %Set the maximum hit threshold.
h.curthreshtype = h.stage(h.cur_stage).threshtype;                          %Set the current threshold type.
set(h.popunits,'string',h.threshtype);                                      %Set the string and value of the threshold type pop-up menu.    
if strcmpi(h.stage(h.cur_stage).threshadapt, 'dynamic')                     %This code sets the minimum threshold if the dynamic threshold type is chosen   
    if ~isempty(h.ratname)                                                  %If a rat name was entered
        h.threshmin = Adaptive_Calc(h.ratname,h.vns, ... 
            h.stage(h.cur_stage).number, h.datapath, h.threshmax);
        h.threshadapt = 'median'; 
%         if h.threshmin >= h.threshmax
%            h.threshadapt = 'static';                                  %Set threshadapt to static if we have reached max threshold
%         else
%             h.threshadapt = 'median';                                 %Set threshadapt to median if we have not reached max threshold
%         end
    else    
        h.threshmin = 1;                                                    %If no rat was selected yet set threshmin equal to 1 to indicate no rat
        h.threshadapt = 'median';
    end

    switch h.threshmin;
        case 0
            errordlg('No previous sessions detected.  Defaulting to minimum threshold of 15 degrees.');
        case 1
            errordlg('No rat name entered. Defaulting to minimum threshold of 15 degrees.');
        otherwise
            if isnan(h.threshmin)
                errordlg('No sessions detected greater than 50 trials.  Defaulting to minimum threshold of 15 degrees.');
            end
    end
    %If our threshold is below our minimum
    if h.threshmin < h.stage(h.cur_stage).threshmin || isnan(h.threshmin)
        h.threshmin = h.stage(h.cur_stage).threshmin;                       %Default the previous cases to 15 degrees
    end
else                                                                        %Else if dynamic thresh type is not selected in the spreadsheet
    h.threshmin = h.stage(h.cur_stage).threshmin;                           %Set the minimum hit threshold to this number if we aren't on a dynamic threshold type
    h.threshadapt = h.stage(h.cur_stage).threshadapt;
end
set(h.editthresh,'string',num2str(h.threshmin));                            %Show the minimum hit threshold in the hit threshold editbox.
h.threshincr = h.stage(h.cur_stage).threshincr;                             %Set the adaptive hit threshold increment.    

h.threshmax = h.stage(h.cur_stage).threshmax;                               %Set the pull maximum hit threshold.     
h.threshmin = h.stage(h.cur_stage).threshmin;                               %Set the pull minimum hit threshold to this number if we aren't on a dynamic threshold type
h.threshadapt = h.stage(h.cur_stage).threshadapt;                           %Set the pull threshold adaptation type.
h.threshincr = h.stage(h.cur_stage).threshincr;                             %Set the pull adaptive hit threshold increment.
    
h.curthreshtype = h.stage(h.cur_stage).threshtype;                          %Set the pull current threshold type.
set(h.popunits,'string',h.threshtype);                                      %Set the string and value of the threshold type pop-up menu.
h.init = h.stage(h.cur_stage).init;                                         %Set the trial initiation threshold.
set(h.editinit,'string',num2str(h.init));                                   %Show the trial initiation threshold in the initiation threshold editbox.    
set(h.lblinit,'string',h.curthreshtype);                                    %Set the initiation threshold units label to the current threshold type.

% handles.stage(handles.cur_stage).threshmin
h.period = h.stage(h.cur_stage).period;                                     %Set the streaming sampling period.
h.position = h.stage(h.cur_stage).pos;                                      %Set the device position.
if (h.delay_autopositioning == 0)                                           %If there's no autopositioning delay currently in force.
    temp = round(10*(h.positioner_offset - 10*h.position));                 %Calculate the absolute position to send to the autopositioner.
    h.ardy.autopositioner(temp);                                            %Set the specified position value.
    h.delay_autopositioning = (10 + temp)/86400000;                         %Don't allow another autopositioning trigger until the current one is complete.
end
set(h.editpos,'string',num2str(h.position));                                %Show the device position in the device position editbox.
h.cur_const = h.stage(h.cur_stage).const;                                   %Set the current constraint.
set(h.popconst,'string',h.constraint);                                      %Set the string and value of the constraint type pop-up menu.
h.hitwin = h.stage(h.cur_stage).hitwin;                                     %Set the hit window.
set(h.edithitwin,'string',num2str(h.hitwin));                               %Show the hit window in the hit window editbox.

h.session_dur = h.stage(h.cur_stage).session_dur;                           %Set the session duration.

if isfield(h,'ir_trial_initiation') && strcmpi(h.ir_trial_initiation,'on')  %If IR signal trial initiation is enabled...
    h.ir = h.stage(h.cur_stage).ir;                                         %Set the IR swipe-initiation variable.
else                                                                        %Otherwise...
    h.ir = 0;                                                               %Set the IR swipe-initiation variable to zero.
end

if ~isfield(h,'ir_initiation_threshold')                                    %If no IR signal initiation threshold is set...
    h.ir_initiation_threshold = 0.5;                                        %Set the IR swipe-initiation variable.
end

temp = {h.stage.description};                                               %Make a cell array holding the stage descriptions.
set(h.popstage,'string',temp,'value',h.cur_stage);                          %Populate the stage selection listbox and set its value.

if strcmpi(h.stage(h.cur_stage).vns,'ON')                                   %If VNS is enabled by default for this stage...
    h.vns = 1;                                                              %Set the VNS field to 1.
    set(h.popvns,'value',1);                                                %Show that VNS is enabled in the VNS pop-up menu.
    set(h.popvns,'foregroundcolor',[1 0 0]);                                %Make the VNS pop-up menu "ON" text red.
elseif strcmpi(h.stage(h.cur_stage).vns,'RANDOM')                           %Otherwise, if VNS is randomly-presented by default for this stage...
    h.vns = 2;                                                              %Set the VNS field to 0.
    set(h.popvns,'value',3);                                                %Show that VNS is randomly-presented in the VNS pop-up menu.
    set(h.popvns,'foregroundcolor',[0 0 1]);                                %Make the VNS pop-up menu "RANDOM" text blue.
elseif strcmpi(h.stage(h.cur_stage).vns,'BURST')                            %Otherwise, if VNS is burst mode
    h.vns = 3;                                                              %Set the VNS field to 3
    set(h.popvns,'value',4);                                                %Show that the VNS is in burst mode in the VNS pop-up menu.
    set(h.popvns,'foregroundcolor',[0 1 0]);                                %Make the VNS pop-up menu "BURST" text green.
else                                                                        %Otherwise, if VNS is disabled by default for this stage...
    h.vns = 0;                                                              %Set the VNS field to 0.
    set(h.popvns,'value',2);                                                %Show that VNS is enabled in the VNS pop-up menu.
    set(h.popvns,'foregroundcolor','k');                                    %Make the VNS pop-up menu "OFF" text black.
end


function handles = MotoTrak_Make_GUI(handles)

%
%MotoTrak_Make_GUI.m - Vulintus, Inc.
%
%   This function starts or stops a MotoTrak Behavioral session when the
%   user presses the "START"/"STOP" button on the MotoTrak GUI.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Created a menubar across the top of the
%       figure to display stage definition, calibration,
%       preference-setting, and help functions.
%

%% Set the common properties of subsequent uicontrols.
fontsize = 12;                                                              %Set the fontsize for all uicontrols.
uheight = 0.75;                                                             %Set the height of all editboxes and listboxes, in centimeters
label_color = [0.7 0.7 0.9];                                                %Set the color for all labels.

%% Create the main figure.
set(0,'units','centimeters');                                               %Set the system units to centimeters.
pos = get(0,'ScreenSize');                                                  %Grab the system screen size.
w = 15;                                                                     %Set the initial GUI width, in centimeters.
h = 12;                                                                     %Set the initial GUI height, in centimeters.                 
handles.mainfig = figure('units','centimeter',...
    'Position',[pos(3)/2-w/2, pos(4)/2-h/2, w, h],...
    'MenuBar','none',...
    'numbertitle','off',...
    'resize','off',...
    'name','MotoTrak 1.0');                                                 %Create the main figure.
if isfield(handles,'variant')                                               %If this is a custom variant...
    set(handles.mainfig,'name',['MotoTrak 1.0 (' handles.variant ')']);     %Show the custom variant in the figure name.
end

%% Create a stages menu at the top of the figure.
handles.menu.stages.h = uimenu(handles.mainfig,'label','Stages');           %Create a stages menu at the top of the MotoTrak figure.
handles.menu.stages.set_load_option = uimenu(handles.menu.stages.h,...
    'label','Load Stages from...',...
    'enable','off');                                                        %Create a submenu option for setting the preferred stage-loading option.
handles.menu.stages.google = uimenu(handles.menu.stages.set_load_option,...
    'label','Google Spreadsheet',...
    'checked','on');                                                        %Create a submenu option for loading from a Google Spreadsheet.
handles.menu.stages.tsv = uimenu(handles.menu.stages.set_load_option,...
    'label','Local TSV File',...
    'checked','off',...
    'Enable','off');                                                        %Create a submenu option for loading from a Local TSV file.
handles.menu.stages.view_spreadsheet = uimenu(handles.menu.stages.h,...
    'label','View Spreadsheet in Browser...',...
    'enable','off',...
    'separator','on');                                                      %Create a submenu option for opening the stages spreadsheet.
handles.menu.stages.set_spreadsheet = uimenu(handles.menu.stages.h,...
    'label','Set Spreadsheet URL...',...
    'enable','off');                                                        %Create a submenu option for setting the stages spreadsheet URL.
handles.menu.stages.reload_spreadsheet = uimenu(handles.menu.stages.h,...
    'label','Reload Spreadsheet',...
    'enable','off');                                                        %Create a submenu option for setting the stages spreadsheet URL.
handles.menu.stages.set_tsv = uimenu(handles.menu.stages.h,...
    'label','Set Local TSV File...',...
    'enable','off',...
    'separator','on');                                                      %Create a submenu option for setting the local TSV file.

%% Create a calibration menu at the top of the figure.
handles.menu.cal.h = uimenu(handles.mainfig,'label','Calibration');         %Create a calibration menu at the top of the MotoTrak figure.
handles.menu.cal.reset_baseline = uimenu(handles.menu.cal.h,...
    'label','Reset Baseline',...
    'enable','off');                                                        %Create a submenu option for resetting the baseline.
handles.menu.cal.open_calibration = uimenu(handles.menu.cal.h,...
    'label','Open Calibration Window...',...
    'enable','off');                                                        %Create a submenu option for opening the calibration window.

%% Create a preferences menu at the top of the figure.
handles.menu.preferences.h = uimenu(handles.mainfig,'label','Preferences'); %Create a preferences menu at the top of the MotoTrak figure.
handles.menu.preferences.set_datapath = ...
    uimenu(handles.menu.preferences.h,'label','Data Directory',...
    'enable','off');                                                        %Create a submenu option for setting the target data directory.

%% Create a help menu at the top of the figure.
handles.menu.help.h = uimenu(handles.mainfig,'label','Help');               %Create a preferences menu at the top of the MotoTrak figure.
handles.menu.help.setup_guide = uimenu(handles.menu.help.h,...
    'label','Hardware Setup Guide',...
    'enable','off');                                                        %Create a submenu option for setting the target data directory.
handles.menu.help.calibration_guide = uimenu(handles.menu.help.h,...
    'label','Calibration Guide',...
    'enable','off');                                                        %Create a submenu option for opening the calibration window.
        
%% Create a panel housing all of the session information uicontrols.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',[0.1, 7.75, 14.8, 4.15],...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create the panel to hold the session information uicontrols.
h = fliplr({'editrat','editport','editbooth','popdevice','popvns'});        %Create the uicontrol handles field names for session information uicontrols
l = fliplr({'Subject:','Port:','Booth:','Device:','Stim.:'});               %Create the labels for the uicontrols' string property.
for i = 1:5                                                                 %Step through the uicontrols.
    handles.label(i) = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',l{i},...
        'units','centimeters',...
        'position',[0.05, 0.05*i+uheight*(i-1), 2, uheight],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','right',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
    temp = uicontrol(p,'style','edit',...
        'units','centimeters',...
        'string','-',...
        'position',[2.05, 0.05*i+uheight*(i-1), 3, uheight],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','center',...
        'backgroundcolor','w');                                             %Create an editbox for entering in each parameter.
    handles.(h{i}) = temp;                                                  %Save the uicontrol handle to the specified field in the handles structure.
end
set(handles.editport,'enable','inactive');                                  %Disable the port editbox.
set(handles.popdevice,'style','popup');                                     %Make the device uicontrol a popup menu.
set(handles.popvns,'style','popup',...
    'string',{'ON','OFF'},...
    'value',2);                                                             %Make the VNS uicontrol a popup menu.
h = fliplr({'popconst','popstage','editpos','edithitwin','editthresh',...
    'editinit'});                                                           %Create the uicontrol handles field names for session information uicontrols
l = fliplr({'Constraint:','Stage:','Position:','Hit Window:',...
    'Hit Thresh.:','Init. Thresh.:'});                                      %Create the labels for the uicontrols' string property.
u = fliplr({'cm','seconds','units','units'});                               %Create the labels for the units uicontrols' string property.
a = zeros(1,3);                                                             %Make a matrix to hold the uicontrol handles for the units uicontrols.
for i = 1:6                                                                 %Step through the uicontrols.
    temp = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',l{i},...
        'units','centimeters',...
        'position',[5.15, 0.05*i+uheight*(i-1), 2.75, uheight],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','right',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
    if i == 4                                                               %If the label is the the position uicontrol label...
        set(temp,'position',[5.15,0.05*i+uheight*(i-1),2,uheight]);         %Shorten the position uicontrol label.
    elseif i == 5                                                           %If the label is the the stage uicontrol label...
        set(temp,'position',[5.15,0.05*i+uheight*(i-1),1.5,uheight]);       %Shorten the stage uicontrol label.
    elseif i == 6                                                           %If the label is the the constraint uicontrol label...
        set(temp,'position',[9.5,0.05*(i-2)+uheight*(i-3),2.5,uheight]);    %Shorten the constraint uicontrol label.
    end
    handles.label(end+1) = temp;                                            %Save the label uicontrol handle.
    temp = uicontrol(p,'style','edit',...
        'units','centimeters',...
        'string','-',...
        'position',[7.9, 0.05*i+uheight*(i-1), 3, uheight],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','center',...
        'backgroundcolor','w');                                             %Create an editbox for entering in each parameter.
    handles.(h{i}) = temp;                                                  %Save the uicontrol handle to the specified field in the handles structure.
    if i == 5                                                               %If the label is the the stage uicontrol label...
        set(temp,'style','popup',...
            'position',[6.65, 0.05*i+uheight*(i-1), 8, uheight]);           %Make the stage uicontrol a popup menu and resize it.
    elseif i == 6                                                           %If the label is the the constraint uicontrol label...
        set(temp,'style','popup',...
            'position',[12, 0.05*(i-2)+uheight*(i-3), 2.65, uheight]);      %Make the stage uicontrol a popup menu and resize it.
    else                                                                    %Otherwise...
        a(i) = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',u{i},...
        'units','centimeters',...
        'position',[10.9, 0.05*i+uheight*(i-1), 3.75, uheight],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','left',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
        handles.label(end+1) = a(i);                                        %Save the label uicontrol handle.
        if i == 4                                                           %If the units label for the position was just created.
        	set(temp,'position',[7.15,0.05*i+uheight*(i-1),1.5,uheight]);   %Resize the position editbox.
            set(handles.label(end),'position',...
                [8.65, 0.05*i+uheight*(i-1), 0.75, uheight]);               %Resize the position editbox.
        end
    end
end
handles.lblinit = a(1);                                                     %Save the handle for the initiation threshold units uicontrol.
handles.popunits = a(2);                                                    %Save the handle for the hit threshold units uicontrol.
set(handles.popunits,'style','popup','enable','on');                        %Make the threshold units uicontrol a popup menu and enable it.

%% Create a panel housing two axes for displaying streaming data and trial results.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',[0.1, 2.65, 14.8, 5],...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create the panel to hold two sets of axes.
handles.stream_axes = axes('parent',p,...
    'units','centimeters',...
    'position',[0.05,0.05,8.95,4.8],...
    'box','on',...
    'xtick',[],...
    'ytick',[]);                                                            %Create the streaming data axes.
handles.trial_axes = axes('parent',p,...
    'units','centimeters',...
    'position',[9.05,0.05,5.6,4.8],...
    'box','on',...
    'xtick',[],...
    'ytick',[],...
    'yaxislocation','right');                                                %Create the trial results axes.

%% Create pushbuttons for starting, stopping, pausing, and manually triggering feedings.
handles.feedbutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','FEED',...
    'units','centimeters',...
    'position',[0.1, 0.1, 3, 0.8],...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'horizontalalignment','right',...
    'foregroundcolor','k',...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a manual feeding pushbutton.
handles.pausebutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','PAUSE',...
    'units','centimeters',...
    'position',[0.1, 0.925, 3, 0.8],...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'horizontalalignment','right',...
    'foregroundcolor',[0 0 0.5],...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a pause pushbutton.
handles.startbutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','START',...
    'units','centimeters',...
    'position',[0.1, 1.75, 3, 0.8],...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'horizontalalignment','right',...
    'foregroundcolor',[0 0.5 0],...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a start/stop pushbutton.
    
%% Create a message box to show the user messages about odor presentation.
handles.msgbox = uicontrol(handles.mainfig,'style','listbox',...
    'enable','inactive',...
    'string',{},...
    'units','centimeters',...
    'position',[3.2, 0.1, 11.6, 2.45],...
    'fontweight','bold',...
    'fontsize',10,...
    'min',0,...
    'max',2,...
    'value',[],...
    'backgroundcolor','w');                                                 %Make a listbox for displaying messages to the user.


function MotoTrak_Open_Google_Spreadsheet(~,~,url)

if strncmpi(url,'https://docs.google.com/spreadsheet/pub',39)               %If the URL is in the old-style format...
    i = strfind(url,'key=') + 4;                                            %Find the start of the spreadsheet key.
    key = url(i:i+43);                                                      %Grab the 44-character spreadsheet key.
else                                                                        %Otherwise...
    i = strfind(url,'/d/') + 3;                                             %Find the start of the spreadsheet key.
    key = url(i:i+43);                                                      %Grab the 44-character spreadsheet key.
end
str = sprintf('https://docs.google.com/spreadsheets/d/%s/',key);            %Create the Google spreadsheet general URL from the spreadsheet key.
web(str,'-browser');                                                        %Open the Google spreadsheet in the default system browser.


function data = MotoTrak_Read_Stage_TSV_File(file)

%
%MotoTrak_Read_Stage_TSV_File.m - Vulintus, Inc.
%
%   MotoTrak_Read_Stage_TSV_File reads in the MotoTrak stage data from a 
%   local TSV file.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Moved the TSV-reading code from
%       MotoTrak_Read_Stages.m to this function.
%

[fid, errmsg] = fopen(file,'rt');                                           %Open the stage configuration file saved previously for reading as text.
if fid == -1                                                                %If the file could not be opened...
    warndlg(sprintf(['Could not open the stage file '...
        'in:\n\n%s\n\nError:\n\n%s'],stage_file,...
        errmsg),'MotoTrak File Read Error');                                %Show a warning.
end
txt = fread(fid,'*char')';                                                  %Read in the file data as text.
fclose(fid);                                                                %Close the configuration file.
tab = sprintf('\t');                                                        %Make a tab string for finding delimiters.
newline = sprintf('\n');                                                    %Make a new-line string for finding new lines.
a = find(txt == tab | txt == newline);                                      %Find all delimiters in the string.
a = [0, a, length(txt)+1];                                                  %Add indices for the first and last elements of the string.
txt = [txt, newline];                                                       %Add a new line to the end of the string to avoid confusing the spreadsheet-reading loop.
column = 1;                                                                 %Count across columns.
row = 1;                                                                    %Count down rows.
data = {};                                                                  %Make a cell array to hold the spreadsheet-formated data.
for i = 2:length(a)                                                         %Step through each entry in the string.
    if a(i) == a(i-1)+1                                                     %If there is no entry for this cell...
        data{row,column} = [];                                              %...assign an empty matrix.
    else                                                                    %Otherwise...
        data{row,column} = txt((a(i-1)+1):(a(i)-1));                        %...read one entry from the string.
    end
    if txt(a(i)) == tab                                                     %If the delimiter was a tab or a comma...
        column = column + 1;                                                %...advance the column count.
    else                                                                    %Otherwise, if the delimiter was a new-line...
        column = 1;                                                         %...reset the column count to 1...
        row = row + 1;                                                      %...and add one to the row count.
    end
end


function handles = MotoTrak_Read_Stages(handles)

%
%MotoTrak_Read_Stages.m - Vulintus, Inc.
%
%   MotoTrak_Read_Stages reads in the stage information for the format
%   (Google Spreadsheet, TSV, or Excel file) specified by the user.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Added default values for optional stage
%       parameters to simplify stage definitions.
%

global run                                                                  %Create a global run variable.

%List the available column headings with stage structure fieldnames and default values.
params = {  'stage number',                             'number',               'required',         [];...
            'description',                              'description',          'required',         [];...
            'input device',                             'device',               'required',         [];...
            'primary input device',                     'device',               'required',         [];...
            'position',                                 'pos',                  'required',         [];...
            'constraint',                               'const',                'optional',         0;...            
            'hit threshold - type',                     'threshadapt',          'optional',         'static';...
            'hit threshold - minimum',                  'threshmin',            'required',         [];...
            'hit threshold - maximum',                  'threshmax',            'optional',         Inf;...
            'hit threshold - increment',                'threshincr',           'optional',         'special case';...
            'hit threshold - ceiling',                  'ceiling',              'optional',         Inf;... 
            'trial initiation threshold',               'init',                 'required',         [];...
            'threshold units',                          'threshtype',           'optional',         'special case';...
            'ir trial initiation',                      'ir',                   'optional',         'NO';...
            'hit window (s)',                           'hitwin',               'optional',         2;...
            'pre-trial sampling time',                  'pre_trial_sampling',   'optional',         1;...
            'post-trial sampling time',                 'post_trial_sampling',  'optional',         2;...
            'sample period (ms)',                       'period',               'optional',         10;...
            'stimulation',                              'vns',                  'optional',         'OFF';...
            'vns default',                              'vns',                  'optional',         'OFF';...
            'session duration',                         'session_dur',          'optional',         Inf;...
            'force stop',                               'force_stop',           'optional',         'NO'};                                             

switch handles.stage_mode                                                   %Switch among the stage selection modes.
    case 1                                                                  %If stages are being loaded from a local TSV file.
        stage_file = 'MotoTrak_Stages.tsv';                                 %Set the default stage file name.
        file = [handles.mainpath stage_file];                               %Assume the stage file exists in the main program path.
        if ~exist(file,'file');                                             %If the stage file doesn't exist in the main program path...
            file = which(stage_file);                                       %Look through the entire search path for the stage file.    
        end
        if isempty(file)                                                    %If the stage file wasn't found...
            h = warndlg(['The program couldn''t find the stage '...
                'definition file "MotoTrak_Stages.tsv". Press "OK" to '...
                'manually locate the file.'],...
                'NO STAGE FILE');                                           %Show a warning.
            uiwait(h);                                                      %Wait for the warning dialog to close.
            [file, path] = uigetfile('*.tsv','LOCATE STAGE FILE');          %Have the user locate the file with a dialog box.
            if file(1) == 0                                                 %If the user selected "Cancel"...
                run = -1;                                                   %Set the run variable to -1.
                return                                                      %Skip execution of the rest of the function.
            end
            file = [path file];                                             %Add the directory to the located filename.
            temp = questdlg(['The file "' file '" will be copied to "'...
                handles.mainpath '" and will be renamed to '...
                '"MotoTrak_Stages.tsv" for future use.'],...
                'MOVING STAGE FILE','OK','Cancel','OK');                    %Show an OK/Cancel warning that the file will be moved.
            if isempty(temp) || strcmpi(temp,'cancel')                      %If the user closed the warning or pressed "Cancel"...
                run = -1;                                                   %Set the run variable to -1.
                return                                                      %Skip execution of the rest of the function.
            end
            copyfile(file,[handles.mainpath stage_file],'f');               %Copy the stage file to the main data path with the correct filename.
            delete(file);                                                   %Delete the stage file from it's original location.
        end
        stage_file = [handles.mainpath stage_file];                         %Add the main program path to the stage file name.       
        
        data = MotoTrak_Read_Stage_TSV_File(stage_file);                    %Read in the data from the TSV file.
        
    case 2                                                                  %If stages are being loaded from an online google spreadsheet.
        try                                                                 %Try to read in the stage information from the web.
        	data = Read_Google_Spreadsheet(handles.stage_url);              %Read in the stage information from the Google Docs URL.      
            filename = [handles.mainpath 'Mototrak_Stages.tsv'];            %Set the filename for the stage backup file.
        	MotoTrak_Write_Stage_TSV_File(data,filename);                   %Back up the stage information to a local TSV file.
        catch err                                                           %If there's an error...
            warning(['Read_Google_Spreadsheet:' err.identifier]',...
                err.message);                                               %Show a warning.
            stage_file = [handles.mainpath 'Mototrak_Stages.tsv'];          %Add the main program path to the stage file name.    
            data = MotoTrak_Read_Stage_TSV_File(stage_file);                %Read in the data from the TSV file.
        end
    case 3                                                                  %If stages are being loaded from an Excel spreadsheet.
end

stage = struct([]);                                                         %Create an empty stage structure.
for c = 1:size(data,2)                                                      %Step through each column of the stage information.    
    fname = [];                                                             %Assume, by default, that the column heading won't match any expected field.
    for p = 1:size(params,1)                                                %Step through every recognized parameter.
        if strncmpi(params{p,1},data{1,c},length(params{p,1}))              %If the column heading matches a recognized parameter.
            fname = params{p,2};                                            %Grab the associated field name.
        end
    end
    if isempty(fname)                                                       %If the column heading didn't match any recognized parameter.
        warndlg(['The stage parameters spreadsheet column heading "' ...
            data{1,c} '" doesn''t match any recognized stage parameter.'...
            ' This parameter will be ignored.'],...
            'STAGE PARAMETER NOT RECOGNIZED');                              %Show a warning that the parameter will be ignored.
    else                                                                    %Otherwise...
        for i = 2:size(data,1)                                              %Step through each listed stage.
            temp = data{i,c};                                               %Grab the entry for this stage.
            temp(temp == 39) = [];                                          %Kick out any apostrophes in the entry.
            if any(temp > 59)                                               %If there's any text characters in the entry...
                stage(i-1).(fname) = strtrim(temp);                         %Save the field value as a string.
            else                                                            %Otherwise, if there's no text characters in the entry.
                stage(i-1).(fname) = str2double(temp);                      %Evaluate the entry and save the field value as a number.
            end
        end
        
    end
end

for p = 1:size(params)                                                      %Now step through each parameter.
    if ~isfield(stage,params{p,2})                                          %If the parameter wasn't found in the stage information...
        if strcmpi(params{p,3},'required')                                  %If the parameter was a required parameter...
            errordlg(sprintf(['The required stage parameter "%s" '...
                'wasn''t found in the stage parameters spreadsheet! '...
                'Correct the stage spreadsheet and restart MotoTrak.'],...
                upper(params{p,1})),'MISSING STAGE PARAMETER');             %Show an error dialog.
            delete(handles.ardy.serialcon);                                 %Close the serial connection with the Arduino.
            close(handles.mainfig);                                         %Close the GUI.
            clear('run');                                                   %Clear the global run variable from the workspace.
            error(['ERROR IN MOTOTRAK_READ_STAGES: Required stage '...
                'parameter "' upper(params{p,1}) '" wasn''t found in '...
                ' the stage parameters spreadsheet!']);                     %Throw an error.
        else                                                                %Otherwise, if the parameter was an optional parameter...
            stage(1).(params{p,2}) = [];                                    %Add the parameter as a new field.
        end
    end
end

for p = 1:size(params)                                                      %Now step through each parameter.
    for i = 1:length(stage)                                                 %Step through each stage...
        if isempty(stage(i).(params{p,2})) && ~isempty(params{p,4})         %If no parameter value was specified and a default value exists...
            if strcmpi(params{p,4},'special case')                          %If the parameter default value is a special (i.e. conditional) case...
                switch params{p,2}                                          %Switch between the special case parameters.
                    case 'threshtype'                                       %If the parameter is the Threshold Units...
                        switch stage(i).device                              %Switch between the device types.
                            case 'pull'                                     %For the pull device...
                                stage(i).threshtype = 'grams (peak)';       %Set the default threshold units to peak force.
                            case 'squeeze'                                  %For the squeeze device...
                                stage(i).threshtype = 'grams (max)';        %Set the default threshold units to maximum force.
                            case 'knob'                                     %For the knob device...
                                stage(i).threshtype = 'degrees (total)';    %Set the default threshold units to total degrees.
                            case 'lever'                                    %For the lever device...
                                stage(i).threshtype = 'degrees (total)';    %Set the default threshold units to total degrees.
                            case 'touch'                                    %For the touch sensor...
                                stage(i).threshtype = ...
                                    'milliseconds (hold)';                  %Set the default threshold units to milliseconds holding.
                            case 'both'                                     %For the combined touch/pull device...
                                stage(i).threshtype = 'milliseconds/grams'; %Set the default threshold units to milliseconds holding and peak force.
                        end
                    case 'threshincr'                                       %If the parameter is the Hit Threshold Increment...
                        switch stage(i).threshadapt                         %Switch between the adaptation types.
                            case {'median','50th percentile'}               %For median adaptation...
                                stage(i).threshincr = 20;                   %Set the increment (number of trials to integrate over) to 20.
                            case 'linear'                                   %For linear adaptation...
                                stage(i).threshincr = 0.5;                  %Set the increment (number of units to increase per trial to integrate over) to 0.5.
                        end                        
                end
            else                                                            %Otherwise...
                stage(i).(params{p,2}) = params{p,4};                       %Set the parameter to the default value for this stage.
            end
        end
    end
end

for i = 1:length(stage)                                                     %Step through the stages.    
    stage(i).description = ...
        [stage(i).number ': ' stage(i).description];                        %Add the stage number to the stage description.
    if ~ischar(stage(i).const)                                              %If the listed constraint isn't a character.
        stage(i).const = ['#' num2str(stage(i).const)];                     %Turn the constraint number into a string.
    elseif ~any(stage(i).const == '#') && ...
            ~strcmpi(stage(i).const,'none')                                 %Otherwise, if there's no # sign preceding the constraint number...
        stage(i).const = ['#' stage(i).const];                              %Add a # sign preceding the constraint number.
    end
    if strcmpi(stage(i).const,'#0')                                         %If the listed constraint value is '#0'...
        stage(i).const = 'None';                                            %Set the constraint value to 'None'.
    end
    if stage(i).threshmin < stage(i).init && ...
            ~strcmpi(handles.custom,'machado lab')                          %If the initiation threshold is larger than the minimum hit threshold...
        stage(i).threshmin = stage(i).init;                                 %Set the minimum hit threshold to the initiation threshold.
    end
    if isfield(stage,'ir')                                                  %If an IR trial initiation mode was specified.
        stage(i).ir = strcmpi(stage(i).ir,'YES');                           %Convert the IR trial initiation mode to a binary value.
    end
end
            
handles.stage = stage;                                                      %Save the stage structure as a field in the handles structure.


function MotoTrak_Resize(hObject,~)

orig_h = 12;                                                                %List the initial GUI height, in centimeters.     

set(hObject,'units','centimeters');                                         %Set the figure units to centimeters.
h = get(hObject,'position');                                                %Grab the current figure position.
h = h(4);                                                                   %Keep only the current system height.

objs = get(hObject,'children');                                             %Grab all children of the parent object.
temp = get(objs,'type');                                                    %Grab the type of each object.
objs(strcmpi(temp,'uimenu')) = [];                                          %Kick out all uimenu objects.
i = strcmpi('uipanel',get(objs,'type'));                                    %Find all objects that are panels.
temp = get(objs(i),'children');                                             %Grab all children of the uipanels.
temp = vertcat(temp{:});                                                    %Vertically concatenate the children object handles from the uipanels.
objs = [objs; temp];                                                        %Add the uipanel children to the object handle list.
set(objs,'units','normalized');                                             %Make all units normalized.

if isempty(get(objs(1),'userdata'))                                         %If none of the objects yet have an userdata field...
    for i = 1:length(objs)                                                  %Step through all of the objects.
        set(objs(i),'userdata',get(objs(i),'fontsize'));                    %Save the original fontt size for each object.
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



function [port, booth_pairings] = ...
    MotoTrak_Select_Serial_Port(booth_pairings)

%MotoTrak_Select_Serial_Port.m - Vulintus, Inc., 2016
%
%   MotoTrak_Select_Serial_Port detects available serial ports for MotoTrak
%   systems and compares them to serial ports previously identified as
%   being connected to MotoTrak systems.
%
%   UPDATE LOG:
%   05/09/2016 - Drew Sloan - Separated serial port selection from
%       Connect_MotoTrak function to enable smarter port detection and list
%       "refresh" ability.

poll_once = 0;                                                              %Create a variable to indicate when all serial ports have been polled.

waitbar = big_waitbar('title','Connecting to MotoTrak',...
    'string','Detecting serial ports...',...
    'value',0.33);                                                          %Create a waitbar figure.

port = instrhwinfo('serial');                                               %Grab information about the available serial ports.
if isempty(port)                                                            %If no serial ports were found...
    errordlg(['ERROR: There are no available serial ports on this '...
        'computer.'],'No Serial Ports!');                                   %Show an error in a dialog box.
    port = [];                                                              %Set the function output to empty.
    return                                                                  %Skip execution of the rest of the function.
end
busyports = setdiff(port.SerialPorts,port.AvailableSerialPorts);            %Find all ports that are currently busy.
port = port.SerialPorts;                                                    %Save the list of all serial ports regardless of whether they're busy.

if waitbar.isclosed()                                                       %If the user closed the waitbar figure...
    errordlg('Connection to MotoTrak was cancelled by the user!',...
        'Connection Cancelled');                                            %Show an error.
    port = [];                                                              %Set the function output to empty.
    return                                                                  %Skip execution of the rest of the function.
end
waitbar.string('Matching ports to booth assignments...');                   %Update the waitbar text.
waitbar.value(0.66);                                                        %Update the waitbar value.

for i = 1:size(booth_pairings,1)                                            %Step through each row of the booth pairings.
    if ~any(strcmpi(port,booth_pairings{i,1}))                              %If the listed port isn't available on this computer...
        booth_pairings{i,1} = 'delete';                                     %Mark the row for deletion.
    end
end
if ~isempty(booth_pairings)                                                 %If there are any existing port-booth pairings...
    booth_pairings(strcmpi(booth_pairings(:,1),'delete'),:) = [];           %Kick out all rows marked for deletion.
end

waitbar.close();                                                            %Close the waitbar.

if isempty(booth_pairings)                                                  %If there are no existing booth pairings...
    booth_pairings = Poll_Available_Ports(port,busyports);                  %Call the subfunction to check each available serial port for a MotoTrak system.
    if isempty(booth_pairings)                                              %If no MotoTrak systems were found...
        errordlg(['ERROR: No MotoTrak Systems were detected on this '...
            'computer!'],'No MotoTrak Connections!');                       %Show an error in a dialog box.
        port = [];                                                          %Set the function output to empty.
        return                                                              %Skip execution of the rest of the function.
    end
end
      
while ~isempty(port) && length(port) > 1 && ...
        (size(booth_pairings,1) > 1 || poll_once == 0)                      %If there's more than one serial port available, loop until a MotoTrak port is chosen.
    uih = 1.5;                                                              %Set the height for all buttons.
    w = 10;                                                                 %Set the width of the port selection figure.
    h = (size(booth_pairings,1) + 1)*(uih + 0.1) + 0.2 - 0.25*uih;          %Set the height of the port selection figure.
    set(0,'units','centimeters');                                           %Set the screensize units to centimeters.
    pos = get(0,'ScreenSize');                                              %Grab the screensize.
    pos = [pos(3)/2-w/2, pos(4)/2-h/2, w, h];                               %Scale a figure position relative to the screensize.
    fig1 = figure('units','centimeters',...
        'Position',pos,...
        'resize','off',...
        'MenuBar','none',...
        'name','Select A Serial Port',...
        'numbertitle','off');                                               %Set the properties of the figure.
    for i = 1:size(booth_pairings,1)                                        %Step through each available serial port.        
        if strcmpi(busyports,booth_pairings{i,1})                           %If this serial port is busy...
            txt = ['Booth ' booth_pairings{i,2} ' (' booth_pairings{i,1}...
                '): busy (reset?)'];                                        %Create the text for the pushbutton.
        else                                                                %Otherwise, if this serial port is available...
            txt = ['Booth ' booth_pairings{i,2} ' (' booth_pairings{i,1}...
                '): available'];                                            %Create the text for the pushbutton.
        end
        uicontrol(fig1,'style','pushbutton',...
            'string',txt,...
            'units','centimeters',...
            'position',[0.1 h-i*(uih+0.1) 9.8 uih],...
            'fontweight','bold',...
            'fontsize',14,...
            'callback',['guidata(gcbf,' num2str(i) '); uiresume(gcbf);']);  %Make a button for the port showing that it is busy.
    end
    i = i + 1;                                                              %Increment the button counter.
    uicontrol(fig1,'style','pushbutton',...
        'string','Refresh List',...
        'units','centimeters',...
        'position',[3 h-i*(uih+0.1)+0.25*uih-0.1 3.8 0.75*uih],...
        'fontweight','bold',...
        'fontsize',12,...
        'foregroundcolor',[0 0.5 0],...
        'callback',['guidata(gcbf,' num2str(i) '); uiresume(gcbf);']);      %Make a button for the port showing that it is busy.
    uiwait(fig1);                                                           %Wait for the user to push a button on the pop-up figure.
    if ishandle(fig1)                                                       %If the user didn't close the figure without choosing a port...
        i = guidata(fig1);                                                  %Grab the index of chosen port name from the figure.
        close(fig1);                                                        %Close the figure.
        if i > size(booth_pairings,1)                                       %If the user selected to refresh the list...
            booth_pairings = Poll_Available_Ports(port,busyports);          %Call the subfunction to check each available serial port for a MotoTrak system.
            if isempty(booth_pairings)                                      %If no MotoTrak systems were found...
                errordlg(['ERROR: No MotoTrak Systems were detected on '...
                    'this computer!'],'No MotoTrak Connections!');          %Show an error in a dialog box.
                port = [];                                                  %Set the function output to empty.
                return                                                      %Skip execution of the rest of the function.
            end
        else                                                                %Otherwise...
            port = booth_pairings(i,1);                                     %Set the serial port to that chosen by the user.
        end        
    else                                                                    %Otherwise, if the user closed the figure without choosing a port...
       port = [];                                                           %Set the chosen port to empty.
    end
end

if ~isempty(port)                                                           %If a port was selected...
    port = port{1};                                                         %Convert the port cell array to a string.
    if strcmpi(busyports,port)                                              %If the selected serial port is busy...
        temp = instrfind('port',port);                                      %Grab the serial handle for the specified port.
        fclose(temp);                                                       %Close the busy serial connection.
        delete(temp);                                                       %Delete the existing serial connection.
    end
end


%% This subfunction steps through available serial ports to identify MotoTrak connections.
function booth_pairings = Poll_Available_Ports(port,busyports)
waitbar = big_waitbar('title','Polling Serial Ports');                      %Create a waitbar figure.
booth_pairings = cell(length(port),2);                                      %Create a cell array to hold booth-port pairings.
booth_pairings(:,1) = port;                                                 %Copy the available ports to the booth-port pairing cell array.
for i = 1:length(port)                                                      %Step through each available serial port.
    if waitbar.isclosed()                                                   %If the user closed the waitbar figure...
        errordlg('Connection to MotoTrak was cancelled by the user!',...
            'Connection Cancelled');                                        %Show an error.
        booth_pairings = {};                                                %Set the function output to empty.
        return                                                              %Skip execution of the rest of the function.
    end
    waitbar.value(i/(length(port)+1));                                      %Increment the waitbar value.
    waitbar.string(['Checking ' port{i} ' for a MotoTrak connection...']);  %Update the waitbar message.
    if strcmpi(busyports,port{i})                                           %If the port is currently busy...
        booth_pairings{i,2} = 'Unknown';                                    %Label the booth as "unknown (busy)".
    else                                                                    %Otherwise...
        serialcon = serial(port{i},'baudrate',115200);                      %Set up the serial connection on the specified port.
        try                                                                 %Try to open the serial port for communication.      
            booth_pairings{i,1} = 'delete';                                 %Assume at first that the port will be excluded.
            fopen(serialcon);                                               %Open the serial port.
            timeout = now + 10/86400;                                       %Set a time-out point for the following loop.
            while now < timeout && serialcon.BytesAvailable == 0            %Loop for 10 seconds or until the Arduino initializes.
                pause(0.1);                                                 %Pause for 100 milliseconds.
            end
            if serialcon.BytesAvailable > 0                                 %If there's a reply on the serial line.
                fscanf(serialcon,'%c',serialcon.BytesAvailable);            %Clear the reply off of the serial line.
                timeout = now + 10/86400;                                   %Set a time-out point for the following loop.
                fwrite(serialcon,'A','uchar');                              %Send the check status code to the Arduino board.
                while now < timeout && serialcon.BytesAvailable == 0        %Loop for 10 seconds or until a reply is noted.
                    pause(0.1);                                             %Pause for 100 milliseconds.
                end
                if serialcon.BytesAvailable > 0                             %If there's a reply on the serial line.
                    pause(0.01);                                            %Pause for 10 milliseconds.
                    temp = fscanf(serialcon,'%d');                          %Read each reply, replacing the last.
                    booth = [];                                             %Create a variable to hold the booth number.
                    if temp(end) == 111                                     %If the reply is the "111" expected from controller sketch V1.4...
                        fwrite(serialcon,'BA','uchar');                     %Send the command to the Arduino board.
                        booth = fscanf(serialcon,'%d');                     %Check the serial line for a reply.
                        booth = num2str(booth,'%1.0f');                     %Convert the booth number to a string.
                    elseif temp(end) == 123                                 %If the reply is the "123" expected from controller sketches 2.0+...
                        fwrite(serialcon,'B','uchar');                      %Send the command to the Arduino board.
                        booth = fscanf(serialcon,'%d');                     %Check the serial line for a reply.
                    end
                    if ~isempty(booth)                                      %If a booth number was returned...
                        booth_pairings{i,1} = port{i};                      %Save the port number.
                        booth_pairings{i,2} = booth;                        %Save the booth ID.
                    end
                end
            end
        catch                                                               %If no connection could be made to the serial port...
            booth_pairings{i,1} = 'delete';                                 %Mark the port for exclusion.
        end
        delete(serialcon);                                                  %Delete the serial object.
    end
    drawnow;                                                                %Immediately update the plot.
end
booth_pairings(strcmpi(booth_pairings(:,1),'delete'),:) = [];               %Kick out all rows marked for deletion.
waitbar.close();                                                            %Close the waitbar.


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
    Enable_All_Uicontrols(handles);                                         %Update all of the uicontrols.
    guidata(handles.mainfig,handles);                                       %Pin the handles structure to the main figure.
end
if ~isempty(handles.ratname)                                                %If the user's already selected a stage...
    set(handles.startbutton,'enable','on');                                 %Enable the start button.
end


function handles = MotoTrak_Set_Callbacks(handles)

%
%MotoTrak_Disable_Controls_Within_Session.m - Vulintus, Inc.
%
%   This function disables all of the uicontrol and uimenu objects that 
%   should not be active while MotoTrak is running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added disabling of uinmenu objects.
%


%Set the uicontrol callbacks.
set(handles.editrat,'callback',@MotoTrak_Edit_Rat,'string',[]);             %Set the callback for the rat name editbox.
set(handles.editbooth,'callback',@MotoTrak_Edit_Booth);                     %Set the callback for the booth number editbox.
set(handles.popstage,'callback',@MotoTrak_Select_Stage);                    %Set the callback for the stage pop-up menu.
set(handles.startbutton,'callback',@MotoTrak_StartStop)                     %Set the callback for the Start/Stop button.
set(handles.pausebutton,'callback','global run; run = 2')                   %Set the callback for the Pause button.
set(handles.feedbutton,'callback',@MotoTrak_Feed_Button_Press)              %Set the callback for the Manual Feed button.

%Set the figure callbacks.
set(handles.mainfig,'CloseRequestFcn',{@MotoTrak_Close,handles});           %This function is called when the user tries to close the GUI.

%Set the uimenu callbacks.
set(handles.menu.stages.view_spreadsheet,...
    'callback',{@MotoTrak_Open_Google_Spreadsheet,handles.stage_url});      %Set the callback for the "Open Spreadsheet" submenu option.
set(handles.menu.preferences.set_datapath,...
    'callback',@MotoTrak_Set_Datapath);                                     %Set the callback for the "Set Datapath" submenu option.



function MotoTrak_Set_Datapath(hObject,~)

handles = guidata(hObject);                                                 


function MotoTrak_Set_Stream_Params(handles)

%This function sets the streaming parameters on the Arduino.

handles.ardy.set_stream_period(handles.period);                             %Set the stream period on the Arduino.
handles.ardy.set_stream_ir(handles.current_ir);                             %Set the stream IR input index on the Arduino.


function MotoTrak_StartStop(hObject,~)

%
%MotoTrak_StartStop.m - Vulintus, Inc.
%
%   This function starts or stops a MotoTrak Behavioral session when the
%   user presses the "START"/"STOP" button on the MotoTrak GUI.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Removed automatic disabling of the feed
%       button when stopping a session.
%

global run                                                                  %Create the global run variable.

handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
if run > 0                                                                  %If a session is currently running...
    run = -2;                                                               %Set the run variable to -2 to stop the session.    
    set(handles.startbutton,'enable','off');                                %Disable the start/stop button until a new stage is selected.
    set(handles.pausebutton,'enable','off');                                %Disable the pause button.   
else                                                                        %Otherwise, if the program is currently idling...
    set(handles.startbutton,'string','STOP','foregroundcolor',[0.5 0 0]);   %Change the string on the Start/Stop button to make it say 'STOP'.
    MotoTrak_Disable_Controls_Within_Session(handles);                      %Disable all of the uicontrols and uimenus during the session.
    MotoTrak_Behavior_Loop(handles);                                        %Start the main behavior loop.
end


function MotoTrak_Startup


%% Define program-wide constants.
global run                                                                  %Create the global run variable.
run = 0;                                                                    %Set the run variable to zero.
handles = struct;                                                           %Create a handles structure.
handles.mainpath = Vulintus_Set_AppData_Path('MotoTrak');                   %Grab the expected directory for MotoTrak application data.


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
Disable_All_Uicontrols(handles.mainfig);                                    %Disable all of the uicontrols until the Arduino is connected.


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

Enable_All_Uicontrols(handles);                                             %Enable all of the uicontrols.

%These specific UI controls need to be disabled until the user has selected a stage.
set(handles.startbutton,'enable','off');                                    %Disable the start/stop button until a new stage is selected.
set(handles.pausebutton,'enable','off');                                    %Disable the pause button.

run = -1;                                                                   %Set the run variable to -1.
guidata(handles.mainfig,handles);                                           %Pin the handles structure to the main figure.
MotoTrak_Idle(handles);                                                     %Start the device-scanning loop.


function MotoTrak_Write_Config(variant,h,fields)

%
%MotoTrak_Write_Config.m - Vulintus, Inc.
%
%   This function create a configuration file with the specified fields
%   from the handles structure.
%   
%   UPDATE LOG:
%   07/07/2016 - Drew Sloan - Function originally created.

file = [h.mainpath, variant, '_mototrak.config'];                           %Create the configuration file name.
[fid, errmsg] = fopen(file,'wt');                                           %Create a new configuration file for writing as text.
if fid == -1                                                                %If the file could not be created...
    warndlg(sprintf(['Could not create the configuration file '...
        'in:\n\n%s\n\nError:\n\n%s'],file,...
        errmsg),'MotoTrak File Write Error');                               %Show a warning.
end
if ~isempty(fields)                                                         %If the fields input isn't empty...
    if ~iscell(fields)                                                      %If the fields input isn't a cell array...
        fields = {fields};                                                  %Convert the fields input to a cell array.
        for f = 1:length(fields)                                            %Step through each field.
            if ~ischar(fields{f})                                           %If the field value isn't a character array...
                warning(['A non-character field input in the '...
                    'configuration file write function was ignored.']);     %Show a warning.
            elseif ~any(strcmpi(fieldnames(h),fields{f}))                   %If the field value doesn't match any fields in the handles structure..
                warning(['The specified field "' fields{f} '"  isn''t '...
                    'a recognized field of the handles structure, '...
                    'it will be ignored by the configuration file '...
                    'write function']);                                     %Show a warning.
            else                                                            %Otherwise...
                temp = upper(fields{f});                                    %Grab the specified field name.
                temp(temp == '_') = ' ';                                    %Replace all underscores with spaces.
                fprintf(fid,'%s: ',temp);                                   %Print the field name to the configuration file.
                val = handles.(fields{f});                                  %Grab the value of the specified handles field.
                if ischar(val)                                              %If the value is a string...
                    fprintf(fid,'%s\n',val);                                %Print the value to the configuration file.
                elseif isnumeric(val)                                       %If the value is numeric...
                    if numel(val) > 1                                       %If there's more than one value...
                        fprintf(fid,'[');                                   %Print a left bracket to the configuration file.
                        for i = 1:numel(val)                                %Step through each value...
                            fprintf(fid,'%s',num2str(val(i)));              %Print each value as a string.
                            if i < numel(val)                               %If this isn't the last value.
                                fprintf(fid,' ');                           %Print a space to the configuration file.
                            end
                        end
                        fprintf(fid,']\n');                                 %Print a right bracket and carriage return to the configuration file.
                    else                                                    %Otherwise...
                        fprintf(fid,'%s\n',num2str(val));                   %Print the value and a carriage return to the configuration file.
                    end
                end
            end
        end
    end
end
fclose(fid);                                                                %Close the configuration file.


function fid = MotoTrak_Write_File_Header(handles)

%This function writes the file header for session data files.

if ~exist(handles.datapath,'dir')                                           %If the main data folder doesn't already exist on the C:\ drive...
    mkdir(handles.datapath);                                                %Create the main data folder on the C:\ drive.
end
filename = [handles.datapath handles.ratname '\'];                          %Make the folder name for this rat.
if ~exist(filename,'dir')                                                   %If a folder doesn't already exist for this rat.
    mkdir(filename);                                                        %Make the rat folder.
end
filename = [filename handles.ratname '-' 'Stage' ...
    handles.stage(handles.cur_stage).number '\'];                           %Make a folder name for the current stage in this rat's folder.
if ~exist(filename,'dir')                                                   %If the stage folder doesn't already exist for this rat.
    mkdir(filename);                                                        %Make the stage folder.
end
temp = datestr(now,30);                                                     %Grab a timestamp accurate to the second.
if handles.vns == 0                                                         %If we're not stimulating...      
    stim = 'NoVNS';                                                         %Show that there's no VNS in the filename.
elseif handles.vns == 1                                                     %If we're stimulating normally...
    stim = 'VNS';                                                           %Show that there's VNS in the filename.
elseif handles.vns == 2                                                     %If we're randomly stimulating...
    stim = 'RandomVNS';                                                     %Show that there's random stimulation in the filename.
elseif handles.vns == 3
    stim = 'BurstVNS';
end
temp = [handles.ratname...                                                  %(Rat name)
    '_' temp...                                                             %(Timestamp)
    '_Stage' handles.stage(handles.cur_stage).number...                     %(Stage title)
    '_' handles.device...                            %(Device)
    '_' stim...                                                             %(VNS on or off)
    '.ArdyMotor' ];                                                         %Create the filename, including the full pathandles.
Add_Msg(handles.msgbox,[datestr(now,13) ' - Session data file: ' ...
	temp '.']);                                                             %Show the user the session data file name.
filename = [filename temp];                                                 %Add the path to the filename.
[fid, errmsg] = fopen(filename,'w');                                        %Open the data file as a binary file for writing.
if fid == -1                                                                %If the file could not be created...
    errordlg(sprintf(['Could not create the session data file '...
        'at:\n\n%s\n\nError:\n\n%s'],filename,...
        errmsg),'MotoTrak File Write Error');                               %Show an error dialog box.
end
fwrite(fid,-3,'int8');                                                      %Write the data file version number.
fwrite(fid,daycode,'uint16');                                               %Write the DayCode.
fwrite(fid,handles.booth,'uint8');                                          %Write the booth number.
fwrite(fid,length(handles.ratname),'uint8');                                %Write the number of characters in the rat's name.
fwrite(fid,handles.ratname,'uchar');                                        %Write the characters of the rat's name.
fwrite(fid,handles.position,'float32');                                     %Write the position of the input device (in centimeters).
fwrite(fid,length(handles.stage(handles.cur_stage).description),'uint8');   %Write the number of characters in the stage description.
fwrite(fid,handles.stage(handles.cur_stage).description,'uchar');           %Write the characters of the stage description.
fwrite(fid,length(handles.device),'uint8');                                 %Write the number of characters in the device description.
fwrite(fid,handles.device,'uchar');                                         %Write the characters of the device description.
if any(strcmpi(handles.device,{'pull', 'lever','knob'}))                    %If the input device for this stage is the pull, lever, or knob
    fwrite(fid,handles.slope,'float32');                                    %Write the slope of the calibration equation y = m*(x - b).
    fwrite(fid,handles.baseline,'float32');                                 %Write the baseline of the calibration equation y = m*(x - b).
elseif any(strcmpi(handles.device,{'wheel'}))                               %If the input device for this stage is the wheel...
    fwrite(fid,handles.slope,'float32');                                    %Write the number of degrees per tick for the rotary encoder.
end
fwrite(fid,length(handles.cur_const),'uint8');                              %Write the number of characters in the constraint description.
fwrite(fid,handles.cur_const,'uchar');                                      %Write the characters of the constraint description.
fwrite(fid,length(handles.curthreshtype),'uint8');                         %Write the number of characters in the threshold units.
fwrite(fid,handles.curthreshtype,'uchar');                                 %Write the characters of the threshold units.


function MotoTrak_Write_Stage_TSV_File(data,filename)

%
%MotoTrak_Write_Stage_TSV_File.m - Vulintus, Inc.
%
%   MotoTrak_Write_Stage_TSV_File backs up MotoTrak stage data to a local 
%   TSV file with the specified filename.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Moved the TSV-reading code from
%       MotoTrak_Read_Stages.m to this function.
%

[fid, errmsg] = fopen(filename,'wt');                                       %Open a text-formatted configuration file to save the stage information.
if fid == -1                                                                %If a file could not be created...
    warndlg(sprintf(['Could not create stage file backup '...
        'in:\n\n%s\n\nError:\n\n%s'],filename,...
        errmsg),'MotoTrak File Write Error');                               %Show a warning.
end
for i = 1:size(data,1)                                                      %Step through the rows of the stage data.
    for j = 1:size(data,2)                                                  %Step through the columns of the stage data.
        data{i,j}(data{i,j} < 32) = [];                                     %Kick out all special characters.
        fprintf(fid,'%s',data{i,j});                                        %Write each element of the stage data as tab-separated values.
        if j < size(data,2)                                                 %If this isn't the end of a row...
            fprintf(fid,'\t');                                              %Write a tab to the file.
        elseif i < size(data,1)                                             %Otherwise, if this isn't the last row...
            fprintf(fid,'\n');                                              %Write a carriage return to the file.
        end
    end
end
fclose(fid);                                                                %Close the stages TSV file.    


function [pks,i] = PeakFinder(signal,minpkdist)

%This function finds peaks in the signal, accounting for equality of contiguous samples.
i = find(signal(2:end) - signal(1:end-1) > 0) + 1;                          %Find each point that's greater than the preceding point.
j = find(signal(1:end-1) - signal(2:end) >= 0);                             %Find each point that's greater than or equal to the following point.
i = intersect(i,j);                                                         %Find any points that meet both criteria.
checker = 1;                                                                %Make a variable to check for peaks too close together.
while checker == 1 && length(i) > 2                                         %Loop until no too-close together peaks are found.
    checker = 0;                                                            %Set the checker variable to a default of no too-close peaks found.
    j = i(2:end) - i(1:end-1);                                              %Find the time between peaks.
    if any(j < minpkdist)                                                   %If any too-close-together peaks were found...
        j = find(j < minpkdist,1,'first') + 1;                              %Find the first set of too-close-together peaks.
        i(j) = [];                                                          %Kick out the following peak of the too-close-together pair.
        checker = 1;                                                        %Set the checker variable back to one to loop around again.
    end
end
pks = signal(i);                                                            %Grab the value of the signal at each peak.


function path = Vulintus_Set_AppData_Path(program)

%
%Vulintus_Set_AppData_Path.m - Vulintus, Inc.
%
%   This function finds and/or creates the local application data folder
%   for Vulintus functions specified by "program".
%   
%   UPDATE LOG:
%   08/05/2016 - Drew Sloan - Function created to replace within-function
%       calls in multiple programs.
%

local = winqueryreg('HKEY_CURRENT_USER',...
        ['Software\Microsoft\Windows\CurrentVersion\' ...
        'Explorer\Shell Folders'],'Local AppData');                         %Grab the local application data directory.    
path = fullfile(local,'Vulintus','\');                                      %Create the expected directory name for Vulintus data.
if ~exist(path,'dir')                                                       %If the directory doesn't already exist...
    [status, msg, ~] = mkdir(path);                                         %Create the directory.
    if status ~= 1                                                          %If the directory couldn't be created...
        errordlg(sprintf(['Unable to create application data'...
            ' directory\n\n%s\n\nDetails:\n\n%s'],path,msg),...
            'Vulintus Directory Error');                                    %Show an error.
    end
end
path = fullfile(path,program,'\');                                          %Create the expected directory name for MotoTrak data.
if ~exist(path,'dir')                                                       %If the directory doesn't already exist...
    [status, msg, ~] = mkdir(path);                                         %Create the directory.
    if status ~= 1                                                          %If the directory couldn't be created...
        errordlg(sprintf(['Unable to create application data'...
            ' directory\n\n%s\n\nDetails:\n\n%s'],path,msg),...
            [program ' Directory Error']);                                  %Show an error.
    end
end

if strcmpi(program,'mototrak')                                              %If the specified function is MotoTrak.
    oldpath = fullfile(local,'MotoTrak','\');                               %Create the expected name of the previous version appdata directory.
    if exist(oldpath,'dir')                                                 %If the previous version directory exists...
        files = dir(oldpath);                                               %Grab the list of items contained within the previous directory.
        for f = 1:length(files)                                             %Step through each item.
            if ~files(f).isdir                                             	%If the item isn't a directory...
                copyfile([oldpath, files(f).name],path,'f');                %Copy the file to the new directory.
            end
        end
        [status, msg] = rmdir(oldpath,'s');                                 %Delete the previous version appdata directory.
        if status ~= 1                                                      %If the directory couldn't be deleted...
            warning(['Unable to delete application data'...
                ' directory\n\n%s\n\nDetails:\n\n%s'],oldpath,msg);         %Show an warning.
        end
    end
end


function Add_Msg(listbox,new_msg)
%
%ADD_MSG.m - Rennaker Neural Engineering Lab, 2013
%
%   ADD_MSG displays messages in a listbox on a GUI, adding new messages to
%   the bottom of the list.
%
%   Add_Msg(listbox,new_msg) adds the string or cell array of strings
%   specified in the variable "new_msg" as the last entry or entries in the
%   listbox whose handle is specified by the variable "listbox".
%
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Fixed the bug caused by setting the
%       ListboxTop property to an non-existent item.
%

messages = get(listbox,'string');                                           %Grab the current string in the messagebox.
if isempty(messages)                                                        %If there's no messages yet in the messagebox...
    messages = {};                                                          %Create an empty cell array to hold messages.
elseif ~iscell(messages)                                                    %If the string property isn't yet a cell array...
    messages = {messages};                                                  %Convert the messages to a cell array.
end
messages{end+1} = new_msg;                                                  %Add the new message to the 
set(listbox,'string',messages);                                             %Show that the Arduino connection was successful on the messagebox.
set(listbox,'value',length(messages),...
    'ListboxTop',length(messages));                                         %Set the value of the listbox to the newest messages.
drawnow;                                                                    %Update the GUI.
set(listbox,'min',0,'max',2','selectionhighlight','off','value',[]);        %Set the properties on the listbox to make it look like a simple messagebox.


function Clear_Msg(varargin)
%
%CLEAR_MSG.m - Rennaker Neural Engineering Lab, 2013
%
%   CLEAR_MSG deleles all messages in a listbox on a GUI.
%
%   CLEAR_MSG(listbox) or CLEAR_MSG(~,~,listbox) clears all messages out of
%   the listbox whose handle is specified in the variable "listbox".
%
%   Last modified January 24, 2013, by Drew Sloan.

if nargin == 1                                                              %If there's only one input argument...
    listbox = varargin{1};                                                  %The listbox handle is the first input argument.
elseif nargin == 3                                                          %Otherwise, if there's three input arguments...
    listbox = varargin{3};                                                  %The listbox handle is the third input argument.
end
set(listbox,'string',{},'min',0,'max',0','selectionhighlight','off',...
    'value',[]);                                                            %Clear the messages and set the properties on the listbox to make it look like a simple messagebox.


function [data, structure] = Read_Google_Spreadsheet(url)

%
%Read_Google_Spreadsheet.m - Rennaker Lab, 2010
%
%   Read_Google_Spreadsheet reads in spreadsheet data from Google Documents
%   spreadsheets and returns the data as a 2-D cell array.  To use this
%   function, you must first publish the document as a webpage with Plain
%   Text (TXT) formatting.
%
%   data = Read_Google_Spreadsheet(url) reads the spreadsheet data from the
%   Google Document link specified by "url" and returns it in the cell
%   array "data".
%   
%   UPDATE LOG:
%   07/07/2014 - Drew Sloan - Removed string-formating checks to work
%       around Google Docs updates.
%   07/06/2016 - Drew Sloan - Replaced "urlread" with "webread" when the
%       function is run on MATLAB versions 2014b+.


%% Download the spreadsheet as a string.
v = version;                                                                %Grab the MATLAB version.
v = str2double(v(1:3));                                                     %Convert the first three characters of the version to a number.
if v >= 8.4 || isdeployed                                                   %If the MATLAB version is 2014b or later, or is deployed compiled code...
    urldata = webread(url);                                                 %Use the WEBREAD function to read in the data from the Google spreadsheet as a string.
else                                                                        %Otherwise, for earlier versions...
    urldata = urlread(url);                                                 %Use the URLREAD function to read in the data from the Google spreadsheet as a string.
end


%% Convert the single string output from urlread into a cell array corresponding to cells in the spreadsheet.
tab = sprintf('\t');                                                        %Make a tab string for finding delimiters.
newline = sprintf('\n');                                                    %Make a new-line string for finding new lines.
a = find(urldata == tab | urldata == newline);                              %Find all delimiters in the string.
a = [0, a, length(urldata)+1];                                              %Add indices for the first and last elements of the string.
urldata = [urldata, newline];                                               %Add a new line to the end of the string to avoid confusing the spreadsheet-reading loop.
column = 1;                                                                 %Count across columns.
row = 1;                                                                    %Count down rows.
data = {};                                                                  %Make a cell array to hold the spreadsheet-formated data.
for i = 2:length(a)                                                         %Step through each entry in the string.
    if a(i) == a(i-1)+1                                                     %If there is no entry for this cell...
        data{row,column} = [];                                              %...assign an empty matrix.
    else                                                                    %Otherwise...
        data{row,column} = urldata((a(i-1)+1):(a(i)-1));                    %...read one entry from the string.
    end
    if urldata(a(i)) == tab                                                 %If the delimiter was a tab...
        column = column + 1;                                                %...advance the column count.
    else                                                                    %Otherwise, if the delimiter was a new-line...
        column = 1;                                                         %...reset the column count to 1...
        row = row + 1;                                                      %...and add one to the row count.
    end
end


%% Make a numeric matrix converting every cell to a number.
checker = zeros(size(data,1),size(data,2));                                 %Pre-allocate a matrix to hold boolean is-numeric checks.
numdata = nan(size(data,1),size(data,2));                                   %Pre-allocate a matrix to hold the numeric data.
for i = 1:size(data,1)                                                      %Step through each row.      
    for j = 1:size(data,2)                                                  %Step through each column.
        numdata(i,j) = str2double(data{i,j});                               %Convert the cell contents to a double-precision number.
        %If this cell's data is numeric, or if the cell is empty, or contains a placeholder like *, -, or NaN...
        if ~isnan(numdata(i,j)) || isempty(data{i,j}) ||...
                any(strcmpi(data{i,j},{'*','-','NaN'}))
            checker(i,j) = 1;                                               %Indicate that this cell has a numeric entry.
        end
    end
end
if all(checker(:))                                                          %If all the cells have numeric entries...
    data = numdata;                                                         %...save the data as a numeric matrix.
end


function waitbar = big_waitbar(varargin)

figsize = [2,16];                                                           %Set the default figure size, in centimeters.
barcolor = 'b';                                                             %Set the default waitbar color.
titlestr = 'Waiting...';                                                    %Set the default waitbar title.
txtstr = 'Waiting...';                                                      %Set the default waitbar string.
val = 0;                                                                    %Set the default value of the waitbar to zero.

str = {'FigureSize','Color','Title','String','Value'};                      %List the allowable parameter names.
for i = 1:2:length(varargin)                                                %Step through any optional input arguments.
    if ~ischar(varargin{i}) || ~any(strcmpi(varargin{i},str))               %If the first optional input argument isn't one of the expected property names...
        beep;                                                               %Play the Matlab warning noise.
        cprintf('red','%s\n',['ERROR IN BIG_WAITBAR: Property '...
            'name not recognized! Optional input properties are:']);        %Show an error.
        for j = 1:length(str)                                               %Step through each allowable parameter name.
            cprintf('red','\t%s\n',str{j});                                 %List each parameter name in the command window, in red.
        end
        return                                                              %Skip execution of the rest of the function.
    else                                                                    %Otherwise...
        if strcmpi(varargin{i},'FigureSize')                                %If the optional input property is "FigureSize"...
            figsize = varargin{i+1};                                        %Set the figure size to that specified, in centimeters.            
        elseif strcmpi(varargin{i},'Color')                                 %If the optional input property is "Color"...
            barcolor = varargin{i+1};                                       %Set the waitbar color the specified color.
        elseif strcmpi(varargin{i},'Title')                                 %If the optional input property is "Title"...
            titlestr = varargin{i+1};                                       %Set the waitbar figure title to the specified string.
        elseif strcmpi(varargin{i},'String')                                %If the optional input property is "String"...
            txtstr = varargin{i+1};                                         %Set the waitbar text to the specified string.
        elseif strcmpi(varargin{i},'Value')                                 %If the optional input property is "Value"...
            val = varargin{i+1};                                            %Set the waitbar value to the specified value.
        end
    end    
end

orig_units = get(0,'units');                                                %Grab the current system units.
set(0,'units','centimeters');                                               %Set the system units to centimeters.
pos = get(0,'Screensize');                                                  %Grab the screensize.
h = figsize(1);                                                             %Set the height of the figure.
w = figsize(2);                                                             %Set the width of the figure.
fig = figure('numbertitle','off',...
    'name',titlestr,...
    'units','centimeters',...
    'Position',[pos(3)/2-w/2, pos(4)/2-h/2, w, h],...
    'menubar','none',...
    'resize','off');                                                        %Create a figure centered in the screen.
ax = axes('units','centimeters',...
    'position',[0.25,0.25,w-0.5,h/2-0.3],...
    'parent',fig);                                                          %Create axes for showing loading progress.
if val > 1                                                                  %If the specified value is greater than 1...
    val = 1;                                                                %Set the value to 1.
elseif val < 0                                                              %If the specified value is less than 0...
    val = 0;                                                                %Set the value to 0.
end    
obj = fill(val*[0 1 1 0 0],[0 0 1 1 0],barcolor,'edgecolor','k');           %Create a fill object to show loading progress.
set(ax,'xtick',[],'ytick',[],'box','on','xlim',[0,1],'ylim',[0,1]);         %Set the axis limits and ticks.
txt = uicontrol(fig,'style','text','units','centimeters',...
    'position',[0.25,h/2+0.05,w-0.5,h/2-0.3],'fontsize',10,...
    'horizontalalignment','left','backgroundcolor',get(fig,'color'),...
    'string',txtstr);                                                       %Create a text object to show the current point in the wait process.  
set(0,'units',orig_units);                                                  %Set the system units back to the original units.

waitbar.title = @(str)SetTitle(fig,str);                                    %Set the function for changing the waitbar title.
waitbar.string = @(str)SetString(fig,txt,str);                              %Set the function for changing the waitbar string.
waitbar.value = @(val)SetVal(fig,obj,val);                                  %Set the function for changing waitbar value.
waitbar.color = @(val)SetColor(fig,obj,val);                                %Set the function for changing waitbar color.
waitbar.close = @()CloseWaitbar(fig);                                       %Set the function for closing the waitbar.
waitbar.isclosed = @()WaitbarIsClosed(fig);                                 %Set the function for checking whether the waitbar figure is closed.

drawnow;                                                                    %Immediately show the waitbar.


%% This function sets the name/title of the waitbar figure.
function SetTitle(fig,str)
if ishandle(fig)                                                            %If the waitbar figure is still open...
    set(fig,'name',str);                                                    %Set the figure name to the specified string.
    drawnow;                                                                %Immediately update the figure.
else                                                                        %Otherwise...
    warning('Cannot update the waitbar figure. It has been closed.');       %Show a warning.
end


%% This function sets the string on the waitbar figure.
function SetString(fig,txt,str)
if ishandle(fig)                                                            %If the waitbar figure is still open...
    set(txt,'string',str);                                                  %Set the string in the text object to the specified string.
    drawnow;                                                                %Immediately update the figure.
else                                                                        %Otherwise...
    warning('Cannot update the waitbar figure. It has been closed.');       %Show a warning.
end


%% This function sets the current value of the waitbar.
function SetVal(fig,obj,val)
if ishandle(fig)                                                            %If the waitbar figure is still open...
    if val > 1                                                              %If the specified value is greater than 1...
        val = 1;                                                            %Set the value to 1.
    elseif val < 0                                                          %If the specified value is less than 0...
        val = 0;                                                            %Set the value to 0.
    end
    set(obj,'xdata',val*[0 1 1 0 0]);                                       %Set the patch object to extend to the specified value.
    drawnow;                                                                %Immediately update the figure.
else                                                                        %Otherwise...
    warning('Cannot update the waitbar figure. It has been closed.');       %Show a warning.
end


%% This function sets the color of the waitbar.
function SetColor(fig,obj,val)
if ishandle(fig)                                                            %If the waitbar figure is still open...
    set(obj,'facecolor',val);                                               %Set the patch object to have the specified facecolor.
    drawnow;                                                                %Immediately update the figure.
else                                                                        %Otherwise...
    warning('Cannot update the waitbar figure. It has been closed.');       %Show a warning.
end


%% This function closes the waitbar figure.
function CloseWaitbar(fig)
if ishandle(fig)                                                            %If the waitbar figure is still open...
    close(fig);                                                             %Close the waitbar figure.
    drawnow;                                                                %Immediately update the figure to allow it to close.
end


%% This function returns a logical value indicate whether the waitbar figure has been closed.
function isclosed = WaitbarIsClosed(fig)
isclosed = ~ishandle(fig);                                                  %Check to see if the figure handle is still a valid handle.


function X = boxsmooth(X,wsize)
%Box smoothing function for 2-D matrices.

%X = BOXSMOOTH(X,WSIZE) performs a box-type smoothing function on 2-D
%matrices with window width and height equal to WSIZE.  If WSIZE isn't
%given, the function uses a default value of 5.

if (nargin < 2)                                                             %If the use didn't specify a box size...
    wsize = 5;                                                              %Set the default box size to a 5x5 square.
end     
if (nargin < 1)                                                             %If the user entered no input arguments...
   error('BoxSmooth requires 2-D matrix input.');                           %Show an error.
end

if length(wsize) == 1                                                       %If the user only inputted one dimension...
    rb = round(wsize);                                                      %Round the number of row bins to the nearest integer.
    cb = rb;                                                                %Set the number of column bins equal to the number of row bins.
elseif length(wsize) == 2                                                   %If the user inputted two dimensions...
    rb = round(wsize(1));                                                   %Round the number of row bins to the nearest integer.
    cb = round(wsize(2));                                                   %Round the number of column bins to the nearest integer.
else                                                                        %Otherwise, if the 
    error('The input box size for the boxsmooth can only be a one- or two-element matrix.');
end

w = ones(rb,cb);                                                            %Make a matrix to hold bin weights.
if rem(rb,2) == 0                                                           %If the number of row bins is an even number.
    rb = rb + 1;                                                            %Add an extra bin to the number of row bins.
    w([1,end+1],:) = 0.5;                                                   %Set the tail bins to have half-weight.
end
if rem(cb,2) == 0                                                           %If the number of column bins is an even number.
    cb = cb + 1;                                                            %Add an extra bin to the number of row bins.
    w(:,end+1) = w(:,1);                                                    %Make a new column of weights with the weight of the first column.
    w(:,[1,end]) = 0.5*w(:,[1,end]);                                        %Set the tail bins to have half-weight.
end

[r,c] = size(X);                                                            %Find the number of rows and columns in the input matrix.
S = nan(r+rb-1,c+cb-1);                                                     %Pre-allocate an over-sized matrix to hold the original data.
S((1:r)+(rb-1)/2,(1:c)+(cb-1)/2) = X;                                       %Copy the original matrix to the center of the over-sized matrix.

temp = zeros(size(w));                                                      %Pre-allocate a temporary matrix to hold the box values.
for i = 1:r                                                                 %Step through each row of the original matrix.
    for j = 1:c                                                             %Step through each column of the original matrix.
        temp(:) = S(i:(i+rb-1),j:(j+cb-1));                                 %Pull all of the bin values into a temporary matrix.
        k = ~isnan(temp(:));                                                %Find all the non-NaN bins.
        X(i,j) = sum(w(k).*temp(k))/sum(w(k));                              %Find the weighted mean of the box and save it to the original matrix.
    end
end


function count = cprintf(style,format,varargin)
% CPRINTF displays styled formatted text in the Command Window
%
% Syntax:
%    count = cprintf(style,format,...)
%
% Description:
%    CPRINTF processes the specified text using the exact same FORMAT
%    arguments accepted by the built-in SPRINTF and FPRINTF functions.
%
%    CPRINTF then displays the text in the Command Window using the
%    specified STYLE argument. The accepted styles are those used for
%    Matlab's syntax highlighting (see: File / Preferences / Colors / 
%    M-file Syntax Highlighting Colors), and also user-defined colors.
%
%    The possible pre-defined STYLE names are:
%
%       'Text'                 - default: black
%       'Keywords'             - default: blue
%       'Comments'             - default: green
%       'Strings'              - default: purple
%       'UnterminatedStrings'  - default: dark red
%       'SystemCommands'       - default: orange
%       'Errors'               - default: light red
%       'Hyperlinks'           - default: underlined blue
%
%       'Black','Cyan','Magenta','Blue','Green','Red','Yellow','White'
%
%    STYLE beginning with '-' or '_' will be underlined. For example:
%          '-Blue' is underlined blue, like 'Hyperlinks';
%          '_Comments' is underlined green etc.
%
%    STYLE beginning with '*' will be bold (R2011b+ only). For example:
%          '*Blue' is bold blue;
%          '*Comments' is bold green etc.
%    Note: Matlab does not currently support both bold and underline,
%          only one of them can be used in a single cprintf command. But of
%          course bold and underline can be mixed by using separate commands.
%
%    STYLE also accepts a regular Matlab RGB vector, that can be underlined
%    and bolded: -[0,1,1] means underlined cyan, '*[1,0,0]' is bold red.
%
%    STYLE is case-insensitive and accepts unique partial strings just
%    like handle property names.
%
%    CPRINTF by itself, without any input parameters, displays a demo
%
% Example:
%    cprintf;   % displays the demo
%    cprintf('text',   'regular black text');
%    cprintf('hyper',  'followed %s','by');
%    cprintf('key',    '%d colored', 4);
%    cprintf('-comment','& underlined');
%    cprintf('err',    'elements\n');
%    cprintf('cyan',   'cyan');
%    cprintf('_green', 'underlined green');
%    cprintf(-[1,0,1], 'underlined magenta');
%    cprintf([1,0.5,0],'and multi-\nline orange\n');
%    cprintf('*blue',  'and *bold* (R2011b+ only)\n');
%    cprintf('string');  % same as fprintf('string') and cprintf('text','string')
%
% Bugs and suggestions:
%    Please send to Yair Altman (altmany at gmail dot com)
%
% Warning:
%    This code heavily relies on undocumented and unsupported Matlab
%    functionality. It works on Matlab 7+, but use at your own risk!
%
%    A technical description of the implementation can be found at:
%    <a href="http://undocumentedmatlab.com/blog/cprintf/">http://UndocumentedMatlab.com/blog/cprintf/</a>
%
% Limitations:
%    1. In R2011a and earlier, a single space char is inserted at the
%       beginning of each CPRINTF text segment (this is ok in R2011b+).
%
%    2. In R2011a and earlier, consecutive differently-colored multi-line
%       CPRINTFs sometimes display incorrectly on the bottom line.
%       As far as I could tell this is due to a Matlab bug. Examples:
%         >> cprintf('-str','under\nline'); cprintf('err','red\n'); % hidden 'red', unhidden '_'
%         >> cprintf('str','regu\nlar'); cprintf('err','red\n'); % underline red (not purple) 'lar'
%
%    3. Sometimes, non newline ('\n')-terminated segments display unstyled
%       (black) when the command prompt chevron ('>>') regains focus on the
%       continuation of that line (I can't pinpoint when this happens). 
%       To fix this, simply newline-terminate all command-prompt messages.
%
%    4. In R2011b and later, the above errors appear to be fixed. However,
%       the last character of an underlined segment is not underlined for
%       some unknown reason (add an extra space character to make it look better)
%
%    5. In old Matlab versions (e.g., Matlab 7.1 R14), multi-line styles
%       only affect the first line. Single-line styles work as expected.
%       R14 also appends a single space after underlined segments.
%
%    6. Bold style is only supported on R2011b+, and cannot also be underlined.
%
% Change log:
%    2012-08-09: Graceful degradation support for deployed (compiled) and non-desktop applications; minor bug fixes
%    2012-08-06: Fixes for R2012b; added bold style; accept RGB string (non-numeric) style
%    2011-11-27: Fixes for R2011b
%    2011-08-29: Fix by Danilo (FEX comment) for non-default text colors
%    2011-03-04: Performance improvement
%    2010-06-27: Fix for R2010a/b; fixed edge case reported by Sharron; CPRINTF with no args runs the demo
%    2009-09-28: Fixed edge-case problem reported by Swagat K
%    2009-05-28: corrected nargout behavior sugegsted by Andreas Gäb
%    2009-05-13: First version posted on <a href="http://www.mathworks.com/matlabcentral/fileexchange/authors/27420">MathWorks File Exchange</a>
%
% See also:
%    sprintf, fprintf

% License to use and modify this code is granted freely to all interested, as long as the original author is
% referenced and attributed as such. The original author maintains the right to be solely associated with this work.

% Programmed and Copyright by Yair M. Altman: altmany(at)gmail.com
% $Revision: 1.08 $  $Date: 2012/10/17 21:41:09 $

  persistent majorVersion minorVersion
  if isempty(majorVersion)
      %v = version; if str2double(v(1:3)) <= 7.1
      %majorVersion = str2double(regexprep(version,'^(\d+).*','$1'));
      %minorVersion = str2double(regexprep(version,'^\d+\.(\d+).*','$1'));
      %[a,b,c,d,versionIdStrs]=regexp(version,'^(\d+)\.(\d+).*');  %#ok unused
      v = sscanf(version, '%d.', 2);
      majorVersion = v(1); %str2double(versionIdStrs{1}{1});
      minorVersion = v(2); %str2double(versionIdStrs{1}{2});
  end

  % The following is for debug use only:
  %global docElement txt el
  if ~exist('el','var') || isempty(el),  el=handle([]);  end  %#ok mlint short-circuit error ("used before defined")
  if nargin<1, showDemo(majorVersion,minorVersion); return;  end
  if isempty(style),  return;  end
  if all(ishandle(style)) && length(style)~=3
      dumpElement(style);
      return;
  end

  % Process the text string
  if nargin<2, format = style; style='text';  end
  %error(nargchk(2, inf, nargin, 'struct'));
  %str = sprintf(format,varargin{:});

  % In compiled mode
  try useDesktop = usejava('desktop'); catch, useDesktop = false; end
  if isdeployed | ~useDesktop %#ok<OR2> - for Matlab 6 compatibility
      % do not display any formatting - use simple fprintf()
      % See: http://undocumentedmatlab.com/blog/bold-color-text-in-the-command-window/#comment-103035
      % Also see: https://mail.google.com/mail/u/0/?ui=2&shva=1#all/1390a26e7ef4aa4d
      % Also see: https://mail.google.com/mail/u/0/?ui=2&shva=1#all/13a6ed3223333b21
      count1 = fprintf(format,varargin{:});
  else
      % Else (Matlab desktop mode)
      % Get the normalized style name and underlining flag
      [underlineFlag, boldFlag, style] = processStyleInfo(style);

      % Set hyperlinking, if so requested
      if underlineFlag
          format = ['<a href="">' format '</a>'];

          % Matlab 7.1 R14 (possibly a few newer versions as well?)
          % have a bug in rendering consecutive hyperlinks
          % This is fixed by appending a single non-linked space
          if majorVersion < 7 || (majorVersion==7 && minorVersion <= 1)
              format(end+1) = ' ';
          end
      end

      % Set bold, if requested and supported (R2011b+)
      if boldFlag
          if (majorVersion > 7 || minorVersion >= 13)
              format = ['<strong>' format '</strong>'];
          else
              boldFlag = 0;
          end
      end

      % Get the current CW position
      cmdWinDoc = com.mathworks.mde.cmdwin.CmdWinDocument.getInstance;
      lastPos = cmdWinDoc.getLength;

      % If not beginning of line
      bolFlag = 0;  %#ok
      %if docElement.getEndOffset - docElement.getStartOffset > 1
          % Display a hyperlink element in order to force element separation
          % (otherwise adjacent elements on the same line will be merged)
          if majorVersion<7 || (majorVersion==7 && minorVersion<13)
              if ~underlineFlag
                  fprintf('<a href=""> </a>');  %fprintf('<a href=""> </a>\b');
              elseif format(end)~=10  % if no newline at end
                  fprintf(' ');  %fprintf(' \b');
              end
          end
          %drawnow;
          bolFlag = 1;
      %end

      % Get a handle to the Command Window component
      mde = com.mathworks.mde.desk.MLDesktop.getInstance;
      cw = mde.getClient('Command Window');
      xCmdWndView = cw.getComponent(0).getViewport.getComponent(0);

      % Store the CW background color as a special color pref
      % This way, if the CW bg color changes (via File/Preferences), 
      % it will also affect existing rendered strs
      com.mathworks.services.Prefs.setColorPref('CW_BG_Color',xCmdWndView.getBackground);

      % Display the text in the Command Window
      count1 = fprintf(2,format,varargin{:});

      %awtinvoke(cmdWinDoc,'remove',lastPos,1);   % TODO: find out how to remove the extra '_'
      drawnow;  % this is necessary for the following to work properly (refer to Evgeny Pr in FEX comment 16/1/2011)
      docElement = cmdWinDoc.getParagraphElement(lastPos+1);
      if majorVersion<7 || (majorVersion==7 && minorVersion<13)
          if bolFlag && ~underlineFlag
              % Set the leading hyperlink space character ('_') to the bg color, effectively hiding it
              % Note: old Matlab versions have a bug in hyperlinks that need to be accounted for...
              %disp(' '); dumpElement(docElement)
              setElementStyle(docElement,'CW_BG_Color',1+underlineFlag,majorVersion,minorVersion); %+getUrlsFix(docElement));
              %disp(' '); dumpElement(docElement)
              el(end+1) = handle(docElement);  %#ok used in debug only
          end

          % Fix a problem with some hidden hyperlinks becoming unhidden...
          fixHyperlink(docElement);
          %dumpElement(docElement);
      end

      % Get the Document Element(s) corresponding to the latest fprintf operation
      while docElement.getStartOffset < cmdWinDoc.getLength
          % Set the element style according to the current style
          %disp(' '); dumpElement(docElement)
          specialFlag = underlineFlag | boldFlag;
          setElementStyle(docElement,style,specialFlag,majorVersion,minorVersion);
          %disp(' '); dumpElement(docElement)
          docElement2 = cmdWinDoc.getParagraphElement(docElement.getEndOffset+1);
          if isequal(docElement,docElement2),  break;  end
          docElement = docElement2;
          %disp(' '); dumpElement(docElement)
      end

      % Force a Command-Window repaint
      % Note: this is important in case the rendered str was not '\n'-terminated
      xCmdWndView.repaint;

      % The following is for debug use only:
      el(end+1) = handle(docElement);  %#ok used in debug only
      %elementStart  = docElement.getStartOffset;
      %elementLength = docElement.getEndOffset - elementStart;
      %txt = cmdWinDoc.getText(elementStart,elementLength);
  end

  if nargout
      count = count1;
  end
  return;  % debug breakpoint

% Process the requested style information
function [underlineFlag,boldFlag,style] = processStyleInfo(style)
  underlineFlag = 0;
  boldFlag = 0;

  % First, strip out the underline/bold markers
  if ischar(style)
      % Styles containing '-' or '_' should be underlined (using a no-target hyperlink hack)
      %if style(1)=='-'
      underlineIdx = (style=='-') | (style=='_');
      if any(underlineIdx)
          underlineFlag = 1;
          %style = style(2:end);
          style = style(~underlineIdx);
      end

      % Check for bold style (only if not underlined)
      boldIdx = (style=='*');
      if any(boldIdx)
          boldFlag = 1;
          style = style(~boldIdx);
      end
      if underlineFlag && boldFlag
          warning('YMA:cprintf:BoldUnderline','Matlab does not support both bold & underline')
      end

      % Check if the remaining style sting is a numeric vector
      %styleNum = str2num(style); %#ok<ST2NM>  % not good because style='text' is evaled!
      %if ~isempty(styleNum)
      if any(style==' ' | style==',' | style==';')
          style = str2num(style); %#ok<ST2NM>
      end
  end

  % Style = valid matlab RGB vector
  if isnumeric(style) && length(style)==3 && all(style<=1) && all(abs(style)>=0)
      if any(style<0)
          underlineFlag = 1;
          style = abs(style);
      end
      style = getColorStyle(style);

  elseif ~ischar(style)
      error('YMA:cprintf:InvalidStyle','Invalid style - see help section for a list of valid style values')

  % Style name
  else
      % Try case-insensitive partial/full match with the accepted style names
      validStyles = {'Text','Keywords','Comments','Strings','UnterminatedStrings','SystemCommands','Errors', ...
                     'Black','Cyan','Magenta','Blue','Green','Red','Yellow','White', ...
                     'Hyperlinks'};
      matches = find(strncmpi(style,validStyles,length(style)));

      % No match - error
      if isempty(matches)
          error('YMA:cprintf:InvalidStyle','Invalid style - see help section for a list of valid style values')

      % Too many matches (ambiguous) - error
      elseif length(matches) > 1
          error('YMA:cprintf:AmbigStyle','Ambiguous style name - supply extra characters for uniqueness')

      % Regular text
      elseif matches == 1
          style = 'ColorsText';  % fixed by Danilo, 29/8/2011

      % Highlight preference style name
      elseif matches < 8
          style = ['Colors_M_' validStyles{matches}];

      % Color name
      elseif matches < length(validStyles)
          colors = [0,0,0; 0,1,1; 1,0,1; 0,0,1; 0,1,0; 1,0,0; 1,1,0; 1,1,1];
          requestedColor = colors(matches-7,:);
          style = getColorStyle(requestedColor);

      % Hyperlink
      else
          style = 'Colors_HTML_HTMLLinks';  % CWLink
          underlineFlag = 1;
      end
  end

% Convert a Matlab RGB vector into a known style name (e.g., '[255,37,0]')
function styleName = getColorStyle(rgb)
  intColor = int32(rgb*255);
  javaColor = java.awt.Color(intColor(1), intColor(2), intColor(3));
  styleName = sprintf('[%d,%d,%d]',intColor);
  com.mathworks.services.Prefs.setColorPref(styleName,javaColor);

% Fix a bug in some Matlab versions, where the number of URL segments
% is larger than the number of style segments in a doc element
function delta = getUrlsFix(docElement)  %#ok currently unused
  tokens = docElement.getAttribute('SyntaxTokens');
  links  = docElement.getAttribute('LinkStartTokens');
  if length(links) > length(tokens(1))
      delta = length(links) > length(tokens(1));
  else
      delta = 0;
  end

% fprintf(2,str) causes all previous '_'s in the line to become red - fix this
function fixHyperlink(docElement)
  try
      tokens = docElement.getAttribute('SyntaxTokens');
      urls   = docElement.getAttribute('HtmlLink');
      urls   = urls(2);
      links  = docElement.getAttribute('LinkStartTokens');
      offsets = tokens(1);
      styles  = tokens(2);
      doc = docElement.getDocument;

      % Loop over all segments in this docElement
      for idx = 1 : length(offsets)-1
          % If this is a hyperlink with no URL target and starts with ' ' and is collored as an error (red)...
          if strcmp(styles(idx).char,'Colors_M_Errors')
              character = char(doc.getText(offsets(idx)+docElement.getStartOffset,1));
              if strcmp(character,' ')
                  if isempty(urls(idx)) && links(idx)==0
                      % Revert the style color to the CW background color (i.e., hide it!)
                      styles(idx) = java.lang.String('CW_BG_Color');
                  end
              end
          end
      end
  catch
      % never mind...
  end

% Set an element to a particular style (color)
function setElementStyle(docElement,style,specialFlag, majorVersion,minorVersion)
  %global tokens links urls urlTargets  % for debug only
  global oldStyles
  if nargin<3,  specialFlag=0;  end
  % Set the last Element token to the requested style:
  % Colors:
  tokens = docElement.getAttribute('SyntaxTokens');
  try
      styles = tokens(2);
      oldStyles{end+1} = styles.cell;

      % Correct edge case problem
      extraInd = double(majorVersion>7 || (majorVersion==7 && minorVersion>=13));  % =0 for R2011a-, =1 for R2011b+
      %{
      if ~strcmp('CWLink',char(styles(end-hyperlinkFlag))) && ...
          strcmp('CWLink',char(styles(end-hyperlinkFlag-1)))
         extraInd = 0;%1;
      end
      hyperlinkFlag = ~isempty(strmatch('CWLink',tokens(2)));
      hyperlinkFlag = 0 + any(cellfun(@(c)(~isempty(c)&&strcmp(c,'CWLink')),tokens(2).cell));
      %}

      styles(end-extraInd) = java.lang.String('');
      styles(end-extraInd-specialFlag) = java.lang.String(style);  %#ok apparently unused but in reality used by Java
      if extraInd
          styles(end-specialFlag) = java.lang.String(style);
      end

      oldStyles{end} = [oldStyles{end} styles.cell];
  catch
      % never mind for now
  end
  
  % Underlines (hyperlinks):
  %{
  links = docElement.getAttribute('LinkStartTokens');
  if isempty(links)
      %docElement.addAttribute('LinkStartTokens',repmat(int32(-1),length(tokens(2)),1));
  else
      %TODO: remove hyperlink by setting the value to -1
  end
  %}

  % Correct empty URLs to be un-hyperlinkable (only underlined)
  urls = docElement.getAttribute('HtmlLink');
  if ~isempty(urls)
      urlTargets = urls(2);
      for urlIdx = 1 : length(urlTargets)
          try
              if urlTargets(urlIdx).length < 1
                  urlTargets(urlIdx) = [];  % '' => []
              end
          catch
              % never mind...
              a=1;  %#ok used for debug breakpoint...
          end
      end
  end
  
  % Bold: (currently unused because we cannot modify this immutable int32 numeric array)
  %{
  try
      %hasBold = docElement.isDefined('BoldStartTokens');
      bolds = docElement.getAttribute('BoldStartTokens');
      if ~isempty(bolds)
          %docElement.addAttribute('BoldStartTokens',repmat(int32(1),length(bolds),1));
      end
  catch
      % never mind - ignore...
      a=1;  %#ok used for debug breakpoint...
  end
  %}
  
  return;  % debug breakpoint

% Display information about element(s)
function dumpElement(docElements)
  %return;
  numElements = length(docElements);
  cmdWinDoc = docElements(1).getDocument;
  for elementIdx = 1 : numElements
      if numElements > 1,  fprintf('Element #%d:\n',elementIdx);  end
      docElement = docElements(elementIdx);
      if ~isjava(docElement),  docElement = docElement.java;  end
      %docElement.dump(java.lang.System.out,1)
      disp(' ');
      disp(docElement)
      tokens = docElement.getAttribute('SyntaxTokens');
      if isempty(tokens),  continue;  end
      links = docElement.getAttribute('LinkStartTokens');
      urls  = docElement.getAttribute('HtmlLink');
      try bolds = docElement.getAttribute('BoldStartTokens'); catch, bolds = []; end
      txt = {};
      tokenLengths = tokens(1);
      for tokenIdx = 1 : length(tokenLengths)-1
          tokenLength = diff(tokenLengths(tokenIdx+[0,1]));
          if (tokenLength < 0)
              tokenLength = docElement.getEndOffset - docElement.getStartOffset - tokenLengths(tokenIdx);
          end
          txt{tokenIdx} = cmdWinDoc.getText(docElement.getStartOffset+tokenLengths(tokenIdx),tokenLength).char;  %#ok
      end
      lastTokenStartOffset = docElement.getStartOffset + tokenLengths(end);
      txt{end+1} = cmdWinDoc.getText(lastTokenStartOffset, docElement.getEndOffset-lastTokenStartOffset).char;  %#ok
      %cmdWinDoc.uiinspect
      %docElement.uiinspect
      txt = strrep(txt',sprintf('\n'),'\n');
      try
          data = [tokens(2).cell m2c(tokens(1)) m2c(links) m2c(urls(1)) cell(urls(2)) m2c(bolds) txt];
          if elementIdx==1
              disp('    SyntaxTokens(2,1) - LinkStartTokens - HtmlLink(1,2) - BoldStartTokens - txt');
              disp('    ==============================================================================');
          end
      catch
          try
              data = [tokens(2).cell m2c(tokens(1)) m2c(links) txt];
          catch
              disp([tokens(2).cell m2c(tokens(1)) txt]);
              try
                  data = [m2c(links) m2c(urls(1)) cell(urls(2))];
              catch
                  % Mtlab 7.1 only has urls(1)...
                  data = [m2c(links) urls.cell];
              end
          end
      end
      disp(data)
  end

% Utility function to convert matrix => cell
function cells = m2c(data)
  %datasize = size(data);  cells = mat2cell(data,ones(1,datasize(1)),ones(1,datasize(2)));
  cells = num2cell(data);

% Display the help and demo
function showDemo(majorVersion,minorVersion)
  fprintf('cprintf displays formatted text in the Command Window.\n\n');
  fprintf('Syntax: count = cprintf(style,format,...);  click <a href="matlab:help cprintf">here</a> for details.\n\n');
  url = 'http://UndocumentedMatlab.com/blog/cprintf/';
  fprintf(['Technical description: <a href="' url '">' url '</a>\n\n']);
  fprintf('Demo:\n\n');
  boldFlag = majorVersion>7 || (majorVersion==7 && minorVersion>=13);
  s = ['cprintf(''text'',    ''regular black text'');' 10 ...
       'cprintf(''hyper'',   ''followed %s'',''by'');' 10 ...
       'cprintf(''key'',     ''%d colored'',' num2str(4+boldFlag) ');' 10 ...
       'cprintf(''-comment'',''& underlined'');' 10 ...
       'cprintf(''err'',     ''elements:\n'');' 10 ...
       'cprintf(''cyan'',    ''cyan'');' 10 ...
       'cprintf(''_green'',  ''underlined green'');' 10 ...
       'cprintf(-[1,0,1],  ''underlined magenta'');' 10 ...
       'cprintf([1,0.5,0], ''and multi-\nline orange\n'');' 10];
   if boldFlag
       % In R2011b+ the internal bug that causes the need for an extra space
       % is apparently fixed, so we must insert the sparator spaces manually...
       % On the other hand, 2011b enables *bold* format
       s = [s 'cprintf(''*blue'',   ''and *bold* (R2011b+ only)\n'');' 10];
       s = strrep(s, ''')',' '')');
       s = strrep(s, ''',5)',' '',5)');
       s = strrep(s, '\n ','\n');
   end
   disp(s);
   eval(s);


%%%%%%%%%%%%%%%%%%%%%%%%%% TODO %%%%%%%%%%%%%%%%%%%%%%%%%
% - Fix: Remove leading space char (hidden underline '_')
% - Fix: Find workaround for multi-line quirks/limitations
% - Fix: Non-\n-terminated segments are displayed as black
% - Fix: Check whether the hyperlink fix for 7.1 is also needed on 7.2 etc.
% - Enh: Add font support


function [d] = daycode(varargin)

%
%daycode.m - OU Neural Engineering Lab, 2007
%
%   daycode.m returns the day code for today or any date inputted.  The day
%   code is simply the number of the day in a year, so between 1-365 unless
%   the year is a leap year, in which case it's between 1-366.
%
%   daycode returns the day code for today.
%
%   daycode(date) returns the day code for the input date, in which date is
%   in date string, date vector, or serial date number format.
%
%
%   NELtoSPK(...,'Property1',PropertyValue1,...) sets the values of any of the
%   following optional thresholding properties:
%
%   Last updated April 16, 2009, by Drew Sloan.

if isempty(varargin)            %If the user hasn't specified a date...
    temp = datevec(now);        %Find the daycode for today and convert that to a date vector.
elseif length(varargin) == 1    %If the user has specified a date...
    temp = cell2mat(varargin);  %Convert the cell input to a string or number.
    if ischar(temp) || length(temp) == 1  %If it's a date string or serial date number...
        temp = datevec(temp);           %Convert the date to a date vector.
    end
    if ~isequal(size(temp),[1 6])   %If the date vector is not properly formated...
        %Return an error message and cancel.
        error('- Input is not a proper date string, date vector, or serial date number.');
    end
else    %If the input argument is longer than one, then there's too many inputs.
    error('- Too many input arguments.  Input one date string, date vector, or serial date number.');
end


year = temp(1);     %Pull the year out of the date vector.
month = temp(2);    %Pull out the month.
day = temp(3);      %Pull out the day.

if year/4 == fix(year/4);   %If the year is a leap year, February has 29 days.
    numDays = [31 29 31 30 31 30 31 31 30 31 30 31];
else                        %Otherwise, February has 28 days.
	numDays = [31 28 31 30 31 30 31 31 30 31 30 31];
end

%The daycode is the day of the specified month plus all the days in the
%preceding months.
temp = sum(numDays(1:(month-1)));   %Days in the preceding months...
d = temp + day;                     %...plus day of the specified month.


function [varargout] = nanmax(varargin)
%NANMAX Maximum value, ignoring NaNs.
%   M = NANMAX(A) returns the maximum of A with NaNs treated as missing. 
%   For vectors, M is the largest non-NaN element in A.  For matrices, M is
%   a row vector containing the maximum non-NaN element from each column.
%   For N-D arrays, NANMAX operates along the first non-singleton
%   dimension.
%
%   [M,NDX] = NANMAX(A) returns the indices of the maximum values in A.  If
%   the values along the first non-singleton dimension contain more than
%   one maximal element, the index of the first one is returned.
%  
%   M = NANMAX(A,B) returns an array the same size as A and B with the
%   largest elements taken from A or B.  Either one can be a scalar.
%
%   [M,NDX] = NANMAX(A,[],DIM) operates along the dimension DIM.
%
%   See also MAX, NANMIN, NANMEAN, NANMEDIAN, NANMIN, NANVAR, NANSTD.

%   Copyright 1993-2004 The MathWorks, Inc. 


% Call [m,ndx] = max(a,b) with as many inputs and outputs as needed
[varargout{1:nargout}] = max(varargin{:});


function m = nanmean(x,dim)
%NANMEAN Mean value, ignoring NaNs.
%   M = NANMEAN(X) returns the sample mean of X, treating NaNs as missing
%   values.  For vector input, M is the mean value of the non-NaN elements
%   in X.  For matrix input, M is a row vector containing the mean value of
%   non-NaN elements in each column.  For N-D arrays, NANMEAN operates
%   along the first non-singleton dimension.
%
%   NANMEAN(X,DIM) takes the mean along dimension DIM of X.
%
%   See also MEAN, NANMEDIAN, NANSTD, NANVAR, NANMIN, NANMAX, NANSUM.

%   Copyright 1993-2004 The MathWorks, Inc.
%   $Revision: 2.13.4.3 $  $Date: 2004/07/28 04:38:41 $

% Find NaNs and set them to zero
nans = isnan(x);
x(nans) = 0;

if nargin == 1 % let sum deal with figuring out which dimension to use
    % Count up non-NaNs.
    n = sum(~nans);
    n(n==0) = NaN; % prevent divideByZero warnings
    % Sum up non-NaNs, and divide by the number of non-NaNs.
    m = sum(x) ./ n;
else
    % Count up non-NaNs.
    n = sum(~nans,dim);
    n(n==0) = NaN; % prevent divideByZero warnings
    % Sum up non-NaNs, and divide by the number of non-NaNs.
    m = sum(x,dim) ./ n;
end


function y = range(x,dim)
%RANGE  Sample range.
%   Y = RANGE(X) returns the range of the values in X.  For a vector input,
%   Y is the difference between the maximum and minimum values.  For a
%   matrix input, Y is a vector containing the range for each column.  For
%   N-D arrays, RANGE operates along the first non-singleton dimension.
%
%   RANGE treats NaNs as missing values, and ignores them.
%
%   Y = RANGE(X,DIM) operates along the dimension DIM.
%
%   See also IQR, MAD, MAX, MIN, STD.

%   Copyright 1993-2004 The MathWorks, Inc.
%   $Revision: 1.1.8.1 $  $Date: 2010/03/16 00:17:06 $

if nargin < 2
    y = max(x) - min(x);
else
    y = max(x,[],dim) - min(x,[],dim);
end


