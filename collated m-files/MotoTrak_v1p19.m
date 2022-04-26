function MotoTrak_v1p19

%Compiled: 01/11/2019, 14:56:58

MotoTrak_Startup;                                                           %Call the startup function.


%% ***********************************************************************
function varargout = MotoTrak_Startup(varargin)

%
%MotoTrak_Startup.m - Vulintus, Inc.
%
%   This function runs when MotoTrak is launched. It sets default
%   directories, creates the GUI, loads the training stages, and connects
%   to the MotoTrak controller.
%   
%   UPDATE LOG:
%   10/28/2016 - Drew Sloan - Replaced the device-specific settings section
%       with a switch-case section.
%   12/31/2018 - Drew Sloan - Added recognition and initial settings for
%       the water reaching module.
%

close all force;

%% Define program-wide constants.
global run                                                                  %Create the global run variable.
run = 1;                                                                    %Set the run variable to 1.
if nargin == 0                                                              %If there are no optional input arguments...
    handles = struct;                                                       %Create a handles structure.
    handles.mainpath = Vulintus_Set_AppData_Path('MotoTrak');               %Grab the expected directory for MotoTrak application data.
    handles.version = 1.19;                                                 %Set the MotoTrak program version.
else                                                                        %Otherwise, the first optional input argument will be a handles structure.
    handles = varargin{1};                                                  %Grab the pre-existing handles structure.    
end
varargout = {};                                                             %Create a variable output argument cell array.

%% Load the current configuration file.
if nargin == 0                                                              %If no pre-existing handles structure was passed to the startup function...
    handles = MotoTrak_Default_Config(handles);                             %Load the default configuration values.
    [~, temp] = system('hostname');                                         %Grab the local computer name.
    temp(temp < 33) = [];                                                   %Kick out any spaces and carriage returns from the computer name.
    handles.host = temp;                                                    %Save the local computer name.
    temp = [handles.mainpath '*mototrak.config'];                           %Set the expected filename of the configuration file.
    temp = dir(temp);                                                       %Find all matching configuration files in the main program path.
    if isempty(temp)                                                        %If no configuration file was found...
        yesno = questdlg(['It looks like this might be your first time '...
            'running MotoTrak. Do you have a configuration file you''d '...
            'like to load?'],'LOAD CONFIGURATION FILE?','YES','NO','YES');  %Show an OK/Cancel warning that the file will be moved.
        if strcmpi(yesno,'yes')                                             %If the user clicked "yes"...
            [file, path] = uigetfile('*mototrak.config',...
                'Load MotoTrak Configuration');                             %Have the user select a configuration file.
            if file(1) ~= 0                                                 %If the user selected a valid file...
                [status, errmsg] = copyfile([path file],...
                    handles.mainpath,'f');                                  %Copy the configuration file to the MotoTrak application data directory.
                if status ~= 1                                              %If the file couldn't be copied...
                    errordlg(sprintf(['Could not copy the '...
                        'configuration file in:\n\n%s\n\nError:\n\n%s'],...
                        handles.mainpath,errmsg),...
                        'MotoTrak File Copy Error');                        %Throw an error.
                end
                temp = struct('name',file);                                 %Create a temporary structure holding the configuration file name.
            end
        else                                                                %Otherwise, if the user didn't load a configuration file.
            MotoTrak_Write_Config('default',handles,[]);                    %Create a default configuration file.
        end
    end
    if ~isempty(temp)                                                       %If any configuration files were found...
        if length(temp) == 1                                                %If there's one configuration file in the main program path...
            handles.config_file = [handles.mainpath temp(1).name];          %Set the configuration file path to the single file.
        else                                                                %Otherwise, if there's multiple configuration files...
            temp = {temp.name};                                             %Create a cell array of configuration file names.
            i = listdlg('PromptString',...
                'Which configuration file would you like to use?',...
                'name','Multiple Configuration Files',...
                'SelectionMode','single',...
                'listsize',[300 200],...
                'initialvalue',1,...
                'uh',25,...
                'ListString',temp);                                         %Have the user pick a configuration file to use from a list dialog.
            if isempty(i)                                                   %If the user clicked "cancel" or closed the dialog...
                clear('run');                                               %Clear the global run variable from the workspace.
                return                                                      %Skip execution of the rest of the function.
            end
            handles.config_file = [handles.mainpath temp{i}];               %Set the configuration file path to the single file.
        end
        handles = MotoTrak_Load_Config(handles);                            %Call the function to the load the configuration file.
    end
    if handles.datapath(end) ~= '\'                                         %If the last character of the data path isn't a forward slash...
        handles.datapath(end+1) = '\';                                      %Add a forward slash to the end.
    end
    if ~exist(handles.datapath,'dir')                                       %If the primary local data path doesn't already exist...
        mkdir(handles.datapath);                                            %Create the primary local data path.
    end
end
handles.must_select_stage = 1;                                              %Set a flag saying the user must select a stage before starting.


%% Create the main GUI.
handles = MotoTrak_Make_GUI(handles);                                       %Call the subfunction to make the GUI.
set(handles.mainfig,'resize','on',...
    'ResizeFcn',@MotoTrak_Resize);                                          %Set the resize function for the MotoTrak main figure.
MotoTrak_Disable_All_Uicontrols(handles.mainfig);                           %Disable all of the uicontrols until the Arduino is connected.


%% Connect to the Arduino and check the sketch version.
if ~isfield(handles,'ardy')                                                 %If the Arduino isn't already connected in a pre-existing handles structure...
    handles.ardy = Connect_MotoTrak('listbox',handles.msgbox);              %Connect to the Arduino, passing the listbox handle to receive messages.    
    if ~isempty(handles.ardy) && handles.ardy.version < 200                 %If the Arduino sketch version is older than version 2.0...
        str = sprintf(['The controller''s V%1.2f microcode is out of '...
            'date.'],handles.ardy.version);                                 %Create a string showing the current microcode version.
        Add_Msg(handles.msgbox,str);                                        %Show the string in the messagebox.
        delete(handles.ardy.serialcon);                                     %Close the serial connection with the Arduino.
        try                                                                 %Attempt to run the program.
            MotoTrak_Upload_Controller_Sketch(handles.ardy.port,...
                handles.version, handles.msgbox);                           %Call the function to upload a sketch to the controller.
        catch err                                                           %If any error occurs...
            txt = MotoTrak_Save_Error_Report(handles,err);                  %Save a copy of the error in the AppData folder.
            MotoTrak_Send_Error_Report(handles,handles.err_rcpt,txt);       %Send an error report to the specified recipient.        
        end
        Add_Msg(handles.msgbox,'Reconnecting...');                          %Show the string in the messagebox.
        handles.ardy = Connect_MotoTrak('listbox',handles.msgbox);          %Re-connect to the Arduino, passing the listbox handle to receive messages.
    end
    if isempty(handles.ardy)                                                %If the user cancelled connection to the Arduino...
        close(handles.mainfig);                                             %Close the GUI.
        clear('run');                                                       %Clear the global run variable from the workspace.
        return                                                              %Skip execution of the rest of the function.
    end
end
if handles.ardy.version >= 200                                              %If the controller code is version 2.0 or newer...
    MotoTrak_Controller_Update_EEPROM_Int2Float(handles.ardy);              %Call the function to copy calibration values from integers to floats.
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
[handles.device, handles.d_index] = MotoTrak_Identify_Device(temp);         %Call the function to identify the module based on the value of the analog device identifier.
if strcmpi(handles.device,'pull') && ...
        any(strcmpi(handles.custom,{'machado lab', 'touch/pull'}))          %If the current device is the pull and this is the custom touch/pull variant...
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
switch handles.device                                                       %Switch between the recognized devices.
    case 'lever'                                                            %If the current device is the lever...     
        if handles.ardy.version < 2.00                                      %If the controller microcode version is less than 2.00...
            handles.baseline = handles.ardy.baseline();                     %Read in the baseline (unpressed) value for the lever.
            handles.total_range_in_degrees = handles.ardy.cal_grams();      %Read in the range of the lever press, in degrees.
            handles.total_range_in_analog_values = ...
                handles.ardy.n_per_cal_grams();                             %Read in the range of the lever press, in analog tick values.
            handles.slope = -handles.total_range_in_degrees / ...
                handles.total_range_in_analog_values;                       %Calculate the degrees/tick conversion for the lever.
        else                                                                %Otherwise...
            handles.baseline = handles.ardy.get_baseline_float(1);          %Read in the baseline (unpressed) value for the lever.
            handles.slope = handles.ardy.get_slope_float(1);                %Read in the slope value for the lever.
            handles.total_range_in_degrees = 11;      %Read in the range of the lever press, in degrees.
        end
        set(handles.primary_tab,'title','Lever Angle');                     %Change the title on the primary signal tab.
        set(handles.secondary_tab,'title','Swipe Sensor');                  %Change the title on the secondary signal tab.        
        handles.plot_tab_grp.SelectedTab = handles.primary_tab;             %Set focus on the primary signal tab.
    case 'knob'                                                             %If the current device is the knob...
        handles.ardy.knob_toggle(1);                                        %Toggle the knob on.
        handles.ardy.clear();                                               %Clear any residual data on serial line
        handles.slope = -0.25;                                              %Set the slope of the calibration.
        handles.baseline = handles.ardy.read_Pull();                        %Set the baseline as the current value on the analog line.
        set(handles.primary_tab,'title','Supination Angle');                %Change the title on the primary signal tab.
        set(handles.secondary_tab,'title','Swipe Sensor');                  %Change the title on the secondary signal tab.
        handles.plot_tab_grp.SelectedTab = handles.primary_tab;             %Set focus on the primary signal tab.
    case 'pull'                                                             %If the current device is the pull...
        if handles.ardy.version < 2.00                                      %If the controller microcode version is less than 2.00...
            handles.baseline = handles.ardy.baseline();                     %Read in the baseline (resting) value for the isometric pull handle loadcell.                
            handles.slope = handles.ardy.cal_grams();                       %Read in the loadcell range, in grams.
            temp = handles.ardy.n_per_cal_grams();                          %Read in the loadcell range, in analog tick values.
            handles.slope = handles.slope / temp;                           %Calculate the grams/tick conversion for the isometric pull handle loadcell.
        else                                                                %Otherwise...
            handles.baseline = handles.ardy.get_baseline_float(6);          %Read in the baseline (unpressed) value for the isometric pull handle loadcell.    
            handles.slope = handles.ardy.get_slope_float(6);                %Read in the slope (unpressed) value for the isometric pull handle loadcell.    
        end       
        set(handles.primary_tab,'title','Pull Force');                      %Change the title on the primary signal tab.
        set(handles.secondary_tab,'title','Swipe Sensor');                  %Change the title on the secondary signal tab.
        handles.plot_tab_grp.SelectedTab = handles.primary_tab;             %Set focus on the primary signal tab.
    case 'both'                                                             %If the current device is the combined pull/touch...
        if handles.ardy.version < 2.00                                      %If the controller microcode version is less than 2.00...
            handles.baseline = handles.ardy.baseline();                     %Read in the baseline (resting) value for the isometric pull handle loadcell.                
            handles.slope = handles.ardy.cal_grams();                       %Read in the loadcell range, in grams.
            temp = handles.ardy.n_per_cal_grams();                          %Read in the loadcell range, in analog tick values.
            handles.slope = handles.slope / temp;                           %Calculate the grams/tick conversion for the isometric pull handle loadcell.
        else                                                                %Otherwise...
            handles.baseline = handles.ardy.get_baseline_float(6);          %Read in the baseline (unpressed) value for the isometric pull handle loadcell.    
            handles.slope = handles.ardy.get_slope_float(6);                %Read in the slope (unpressed) value for the isometric pull handle loadcell.    
        end               
        set(handles.primary_tab,'title','Pull Force/Touch Sensor');         %Change the title on the primary signal tab.
        delete(handles.secondary_tab);                                      %Delete the secondary signal tab.
        handles = rmfield(handles,'secondary_tab');                         %Remove the secondary signal tab field from the handles structure.
        handles.plot_tab_grp.SelectedTab = handles.primary_tab;             %Set focus on the primary signal tab.
        set(handles.primary_ax,'units','normalized',...
            'position',[0 0 1 0.5]);                                        %Make the force axes half the original size.  
        handles.secondary_ax = axes('parent',handles.primary_tab,...
            'units','normalized',...
            'position',[0 0.5 1 0.5],...
            'box','on',...
            'xtick',[],...
            'ytick',[]);                                                    %Create new secondary axes to show the touch data.   
    case 'touch'                                                            %If the current device is the capacitive touch sensor...
        handles.baseline = 0;                                               %Set the baseline to zero.
        handles.slope = 1;                                                  %Set the calibration slope to 1.
        set(handles.primary_tab,'title','Pull Force');                      %Change the title on the primary signal tab.
        set(handles.secondary_tab,'title','Touch Sensor');                  %Change the title on the secondary signal tab.
        handles.plot_tab_grp.SelectedTab = handles.secondary_tab;           %Set focus on the secondary signal tab.
    case 'water'                                                            %If the current device is the water reaching module...
        handles.baseline = 0;                                               %Set the baseline to zero.
        handles.slope = 1;                                                  %Set the calibration slope to 1.
        set(handles.primary_tab,'title','Right/Left Sensor');               %Change the title on the primary signal tab.
        delete(handles.secondary_tab);                                      %Delete the secondary signal tab.
        handles = rmfield(handles,'secondary_tab');                         %Remove the secondary signal tab field from the handles structure.
        handles.plot_tab_grp.SelectedTab = handles.primary_tab;             %Set focus on the primary signal tab.
        set(handles.primary_ax,'units','normalized',...
            'position',[0 0 1 0.5]);                                        %Make the force axes half the original size.  
        handles.secondary_ax = axes('parent',handles.primary_tab,...
            'units','normalized',...
            'position',[0 0.5 1 0.5],...
            'box','on',...
            'xtick',[],...
            'ytick',[]);                                                    %Create new secondary axes to show the touch data.   
    otherwise                                                               %Otherwise, if no device was found...
        errordlg(['The Arduino didn''t detect any input devices.  '...
            'Attach a wheel, lever, pull, or knob module and restart '...
            'the program.']);                                               %Show an error message telling the user to attach a device.
        delete(handles.ardy.serialcon);                                     %Close the serial connection with the Arduino.
        close(handles.mainfig);                                             %Close the GUI.
        clear('run');                                                       %Clear the global run variable from the workspace.
        return                                                              %Skip execution of any further code. 
end

%Populate the device pop-up menu with the device label.
set(handles.popdevice,'string',upper(handles.device));                             

%% Load the stage information.
handles = MotoTrak_Read_Stages(handles);                                    %Call the function to load the stage information.
if run == 0                                                                 %If the user cancelled an operation during stage selection...
    close(handles.mainfig);                                                 %Close the GUI.
    clear('run');                                                           %Clear the global run variable from the workspace.
    return                                                                  %Skip execution of the rest of the function.
end

%Populate the stage selection pop-up menu.
a = strcmpi(handles.device, {handles.stage.device});                        %Find all stages that use the currently-connected device.
handles.stage(a == 0) = [];                                                 %Kick out all stages that don't use the currently-connected device.
if isempty(handles.stage)                                                   %If there are no stages pertaining to this device...
    errordlg(['Your stage file has no stages for the MotoTrak '...
        handles.device ' module. Please connect a different module and '...
        'restart MotoTrak.']);
    delete(handles.ardy.serialcon);                                         %Close the serial connection with the Arduino.
    close(handles.mainfig);                                                 %Close the GUI.
    clear('run');                                                           %Clear the global run variable from the workspace.
    return                                                                  %Skip execution of any further code. 
end

%Get all the unique threshold types and constraints for the device.
handles.threshtype = unique({handles.stage.threshtype});                    %List all of the unique threshold types for each device.    
handles.constraint = unique({handles.stage.const});                         %List all of the unique constraint numbers for each device.

%Set the current stage.
handles.cur_stage = 1;                                                      %Set the current stage to the first stage in the list.
handles = MotoTrak_Load_Stage(handles);                                     %Load the stage parameters for current stage.

% %Set the streaming parameters on the Arduino.
% MotoTrak_Set_Stream_Params(handles);                                        %Update the streaming properties on the Arduino.

%Set the callbacks for all the enabled uicontrols.
handles = MotoTrak_Set_Callbacks(handles);                                  %Set the callbacks for all uicontrols and menu options.

%Enable all of the uicontrols.
MotoTrak_Enable_All_Uicontrols(handles);                                    %Enable all of the uicontrols.

%These specific UI controls need to be disabled until the user has selected a stage.
set(handles.startbutton,'enable','off');                                    %Disable the start/stop button until a new stage is selected.
set(handles.pausebutton,'enable','off');                                    %Disable the pause button.

%Pin the handles structure to the GUI and go into the main run loop.
guidata(handles.mainfig,handles);                                           %Pin the handles structure to the main figure.
if nargin == 0                                                              %If the function wasn't called by another function...
    try                                                                     %Attempt to run the program.        
        MotoTrak_Main_Loop(handles.mainfig);                                %Start the main loop.
    catch err                                                               %If any error occurs...
        handles = guidata(handles.mainfig);                                 %Grab the handles structure from the main GUI.
        txt = MotoTrak_Save_Error_Report(handles,err);                      %Save a copy of the error in the AppData folder.
        MotoTrak_Send_Error_Report(handles,handles.err_rcpt,txt);           %Send an error report to the specified recipient.        
        MotoTrak_Close(handles.mainfig);                                    %Call the function to close the MotoTrak program.
        errordlg(sprintf(['An fatal error occurred in the MotoTrak '...
            'program. An message containing the error information has '...
            'been sent to "%s", and a Vulintus engineer will contact '...
            'you shortly.'], handles.err_rcpt),'Fatal Error in MotoTrak');  %Display an error dialog.
    end
else                                                                        %Otherwise...
    varargout{1} = handles;                                                 %Return the handles structure as the first variable output argument.
end


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
function [varargout] = nanmin(varargin)
%NANMIN Minimum value, ignoring NaNs.
%   M = NANMIN(A) returns the minimum of A with NaNs treated as missing. 
%   For vectors, M is the smallest non-NaN element in A.  For matrices, M
%   is a row vector containing the minimum non-NaN element from each
%   column.  For N-D arrays, NANMIN operates along the first non-singleton
%   dimension.
%
%   [M,NDX] = NANMIN(A) returns the indices of the minimum values in A.  If
%   the values along the first non-singleton dimension contain more than
%   one minimal element, the index of the first one is returned.
%  
%   M = NANMIN(A,B) returns an array the same size as A and B with the
%   smallest elements taken from A or B.  Either one can be a scalar.
%
%   [M,NDX] = NANMIN(A,[],DIM) operates along the dimension DIM.
%
%   See also MIN, NANMAX, NANMEAN, NANMEDIAN, NANVAR, NANSTD.

%   Copyright 1993-2004 The MathWorks, Inc. 


% Call [m,ndx] = min(a,b) with as many inputs and outputs as needed
[varargout{1:nargout}] = min(varargin{:});


%% ***********************************************************************
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


%% ***********************************************************************
function wav = text2speech(txt,voice,pace,fs)
%TEXT2SPEECH text to speech.
%   TEXT2SPEECH (TXT) synthesizes speech from string TXT, and speaks it. The audio
%   format is mono, 16 bit, 16k Hz by default.
%   
%   WAV = TEXT2SPEECH(TXT) does not vocalize but output to the variable WAV.
%
%   TEXT2SPEECH(TXT,VOICE) uses the specific voice. Use TEXT2SPEECH('','List') to see a
%   list of availble voices. Default is the first voice.
%
%   TEXT2SPEECH(...,PACE) set the pace of speech to PACE. PACE ranges from 
%   -10 (slowest) to 10 (fastest). Default 0.
%
%   TEXT2SPEECH(...,FS) set the sampling rate of the speech to FS kHz. FS must be
%   one of the following: 8000, 11025, 12000, 16000, 22050, 24000, 32000,
%       44100, 48000. Default 16.
%   
%   This function requires the Microsoft Win32 Speech API (SAPI).
%
%   Examples:
%       % Speak the text;
%       text2speech('I can speak.');
%       % List availble voices;
%       text2speech('I can speak.','List');
%       % Do not speak out, store the speech in a variable;
%       w = text2speech('I can speak.',[],-4,44100);
%       wavplay(w,44100);
%
%   See also WAVREAD, WAVWRITE, WAVPLAY.

% Written by Siyi Deng; 12-21-2007;

if ~ispc, error('Microsoft Win32 SAPI is required.'); end
if ~ischar(txt), error('First input must be string.'); end

SV = actxserver('SAPI.SpVoice');
TK = invoke(SV,'GetVoices');

if nargin > 1
    % Select voice;
    for k = 0:TK.Count-1
        if strcmpi(voice,TK.Item(k).GetDescription)
            SV.Voice = TK.Item(k);
            break;
        elseif strcmpi(voice,'list')
            disp(TK.Item(k).GetDescription);
        end
    end
    % Set pace;
    if nargin > 2
        if isempty(pace), pace = 0; end
        if abs(pace) > 10, pace = sign(pace)*10; end        
        SV.Rate = pace;
    end
end

if nargin < 4 || ~ismember(fs,[8000,11025,12000,16000,22050,24000,32000,...
        44100,48000]), fs = 16000; end

if nargout > 0
   % Output variable;
   MS = actxserver('SAPI.SpMemoryStream');
   MS.Format.Type = sprintf('SAFT%dkHz16BitMono',fix(fs/1000));
   SV.AudioOutputStream = MS;  
end

invoke(SV,'Speak',txt);

if nargout > 0
    % Convert uint8 to double precision;
    wav = reshape(double(invoke(MS,'GetData')),2,[])';
    wav = (wav(:,2)*256+wav(:,1))/32768;
    wav(wav >= 1) = wav(wav >= 1)-2;
    delete(MS);
    clear MS;
end

delete(SV); 
clear SV TK;
pause(0.2);


%% ***********************************************************************
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


%% ***********************************************************************
function Enable_All_Uicontrols(fig)

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
set(objs(i),'enable','on');                                                 %Enable all active objects.


%% ***********************************************************************
function serial_codes = Load_MotoTrak_Serial_Codes(ver)

%LOAD_MOTOTRAK_SERIAL_CODES.m
%
%	Vulintus, Inc.
%
%	MotoTrak serial communication code library.
%
%	Library V2 documentation:
%	https://docs.google.com/spreadsheets/d/e/2PACX-1vReo5eWk6dJPhLLSyOjzEkLDV0jcmT-TpUhvU49oHJ0S6veWHT8HyJVZmaRD_IX6uC9FPhcvgqdY_mW/pubhtml
%
%	This file was programmatically generated: 02-May-2018 12:58:50
%

serial_codes = [];

switch ver

	case 2.00
		serial_codes.CUR_DEF_VERSION = 200;

		serial_codes.SKETCH_VERIFY = 65;
		serial_codes.GET_SKETCH_VERSION = 90;
		serial_codes.GET_SERIAL_LIB_VER = 91;
		serial_codes.GET_BOOTH_NUMBER = 66;
		serial_codes.DEVICE_ID = 68;

		serial_codes.READ_DEVICE_VAL = 77;
		serial_codes.RESET_COUNTER = 76;
		serial_codes.STREAM_ENABLE = 103;
		serial_codes.SET_STREAM_ORDER = 97;
		serial_codes.RETURN_STREAM_ORDER = 100;
		serial_codes.SET_STREAM_PERIOD = 101;
		serial_codes.RETURN_STREAM_PERIOD = 102;
		serial_codes.SET_EVENT_INPUT = 105;
		serial_codes.RETURN_EVENT_INPUT = 106;
		serial_codes.SET_EVENT_SIZE = 107;
		serial_codes.RETURN_EVENT_SIZE = 108;

		serial_codes.SAVE_1BYTE_EEPROM = 69;
		serial_codes.READ_1BYTE_EEPROM = 70;
		serial_codes.SAVE_2BYTES_EEPROM = 67;
		serial_codes.READ_2BYTES_EEPROM = 73;
		serial_codes.SAVE_4BYTES_EEPROM = 71;
		serial_codes.READ_4BYTES_EEPROM = 72;

		serial_codes.TRIGGER_FEEDER = 87;
		serial_codes.STOP_FEED = 86;
		serial_codes.SET_FEED_TRIG_DUR = 53;
		serial_codes.RETURN_FEED_TRIG_DUR = 52;

		serial_codes.SET_AP_DIST = 110;
		serial_codes.RETURN_AP_DIST = 111;

		serial_codes.PLAY_TONE = 49;
		serial_codes.STOP_TONE = 50;
		serial_codes.SET_TONE_INDEX = 41;
		serial_codes.RETURN_TONE_INDEX = 42;
		serial_codes.SET_TONE_FREQ = 43;
		serial_codes.RETURN_TONE_FREQ = 44;
		serial_codes.SET_TONE_DUR = 45;
		serial_codes.RETURN_TONE_DUR = 46;
		serial_codes.SET_TONE_TYPE = 47;
		serial_codes.RETURN_TONE_TYPE = 48;
		serial_codes.SET_TONE_MON = 37;
		serial_codes.RETURN_TONE_MON = 38;
		serial_codes.SET_TONE_THRESH = 39;
		serial_codes.RETURN_TONE_THRESH = 40;
		serial_codes.RETURN_MAX_TONES = 51;

		serial_codes.SEND_TRIGGER = 88;
		serial_codes.STOP_TRIGGER = 104;
		serial_codes.SET_TRIG_INDEX = 78;
		serial_codes.RETURN_TRIG_INDEX = 79;
		serial_codes.SET_TRIG_DUR = 56;
		serial_codes.RETURN_TRIG_DUR = 55;
		serial_codes.SET_TRIG_TYPE = 80;
		serial_codes.RETURN_TRIG_TYPE = 81;
		serial_codes.SET_TRIG_MON = 82;
		serial_codes.RETURN_TRIG_MON = 83;
		serial_codes.SET_TRIG_THRESH = 84;
		serial_codes.RETURN_TRIG_THRESH = 85;

		serial_codes.SET_CAGE_LIGHTS = 57;
		serial_codes.RETURN_CAGE_LIGHTS = 58;
		serial_codes.CMD_SET_EEPROM_ADDR = 1;
		serial_codes.CMD_WRITE_EEPROM = 2;
		serial_codes.CMD_READ_EEPROM = 3;
		serial_codes.CMD_DEVICE_READING = 4;
		serial_codes.CMD_STREAM_ENABLE = 5;
		serial_codes.CMD_SET_STREAM_ORDER = 6;
		serial_codes.CMD_SET_STREAM_PERIOD = 7;
		serial_codes.CMD_SET_EVENT_INPUT = 8;
		serial_codes.CMD_SET_EVENT_SIZE = 9;
		serial_codes.CMD_SET_FEED_TRIG_DUR = 10;
		serial_codes.CMD_SET_TONE_INDEX = 11;
		serial_codes.CMD_SET_TONE_FREQ = 12;
		serial_codes.CMD_SET_TONE_DUR = 13;
		serial_codes.CMD_SET_TONE_TYPE = 14;
		serial_codes.CMD_SET_TONE_MON = 15;
		serial_codes.CMD_SET_TONE_THRESH = 16;
		serial_codes.CMD_PLAY_TONE = 17;
		serial_codes.CMD_SEND_TRIGGER = 18;
		serial_codes.CMD_SET_TRIG_INDEX = 19;
		serial_codes.CMD_SET_TRIG_DUR = 20;
		serial_codes.CMD_SET_TRIG_TYPE = 21;
		serial_codes.CMD_SET_TRIG_MON = 22;
		serial_codes.CMD_SET_TRIG_THRESH = 23;
		serial_codes.CMD_READ_AP_DIST = 24;
		serial_codes.CMD_SEND_AP_COMM = 25;
		serial_codes.CMD_SET_CAGE_LIGHTS = 26;
		serial_codes.EEPROM_BOOTH_NUM = 0;

		serial_codes.EEPROM_CAL_BASE_INT = 4;

		serial_codes.EEPROM_CAL_FORCE_INT = 6;

		serial_codes.EEPROM_CAL_TICK_INT = 8;

		serial_codes.EEPROM_SN = 10;

		serial_codes.EEPROM_BOOTH_ID = 14;

		serial_codes.EEPROM_CAL_BASE_FL = 38;

		serial_codes.EEPROM_CAL_SLOPE_FL = 42;

end


%% ***********************************************************************
function data = Vulintus_Read_TSV_File(file)

%
%Vulintus_Read_TSV_File.m - Vulintus, Inc.
%
%   Vulintus_Read_TSV_File reads in data from a spreadsheet-formated TSV
%   file.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Moved the TSV-reading code from
%       Vulintus_Read_Stages.m to this function.
%   09/13/2016 - Drew Sloan - Generalized the MotoTrak TSV-reading program
%       to also work with OmniTrak and future behavior programs.
%

[fid, errmsg] = fopen(file,'rt');                                           %Open the stage configuration file saved previously for reading as text.
if fid == -1                                                                %If the file could not be opened...
    warndlg(sprintf(['Could not open the stage file '...
        'in:\n\n%s\n\nError:\n\n%s'],file,...
        errmsg),'Vulintus File Read Error');                                %Show a warning.
    close(fid);                                                             %Close the file.
    data = [];                                                              %Set the output data variable to empty brackets.
    return                                                                  %Return to the calling function.
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


%% ***********************************************************************
function Vulintus_Send_Error_Report(recipient,subject,msg)

%
%Vulintus_Send_Error_Report.m - Vulintus, Inc.
%
%   Vulintus_Send_Error_Report sends an error report ("msg") by email to 
%   the specified recipient ("target") through the Vulintus dummy 
%   error-reporting account.
%
%   The funtion must be compiled for deployment. Compile using the
%   following command in the command line:
%   
%       mcc -e -v Vulintus_Send_Error_Report.m
%   
%   UPDATE LOG:
%   02/21/2017 - Drew Sloan - Added enabling of a STARTTLS command.
%

try                                                                         %Attempt to send an email with the error information.
    setpref('Internet','E_mail','error.report@vulintus.com');               %Set the default email sender to "error.report@vulintus.com".
    setpref('Internet','SMTP_Server','smtp.gmail.com');                     %Set the SMTP server to Gmail.
    setpref('Internet','SMTP_Username','error.report@vulintus.com');        %Set the SMTP username.
    setpref('Internet','SMTP_Password','vulintus');                         %Set the password for the error reporting account.
    props = java.lang.System.getProperties;                                 %Grab the javascript email properties.
    props.setProperty('mail.smtp.auth','true');                             %Set the email properties to enable gmail logins.
    props.setProperty('mail.smtp.starttls.enable','true');                  %Enable the STARTTLS command.
    props.setProperty('mail.smtp.socketFactory.class', ...
                      'javax.getprfenet.ssl.SSLSocketFactory');             %Create an SSL socket.                  
    props.setProperty('mail.smtp.socketFactory.port','465');                %Set the email socket to a secure port.
    sendmail(recipient,subject,msg);                                        %Email the new and old calibration values to the specified users.
catch err                                                                   %Otherwise...
    warning('%s - %s',err.identifier,err.message);                          %Show the error message as a warning.                                                                  
end


%% ***********************************************************************
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


%% ***********************************************************************
function Vulintus_Write_TSV_File(data,filename)

%
%OmniTrak_Write_Stage_TSV_File.m - Vulintus, Inc.
%
%   OmniTrak_Write_Stage_TSV_File backs up OmniTrak stage data to a local 
%   TSV file with the specified filename.
%   
%   UPDATE LOG:
%   09/13/2016 - Drew Sloan - Generalized the MotoTrak TSV-writing program
%       to also work with OmniTrak and future behavior programs.
%

[fid, errmsg] = fopen(filename,'wt');                                       %Open a text-formatted configuration file to save the stage information.
if fid == -1                                                                %If a file could not be created...
    warndlg(sprintf(['Could not create stage file backup '...
        'in:\n\n%s\n\nError:\n\n%s'],filename,...
        errmsg),'OmniTrak File Write Error');                               %Show a warning.
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


%% ***********************************************************************
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
%


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
    set(listbox,'string',message,'value',1,'listboxtop',1);                 %Show the Arduino connection status in the listbox.
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
catch err                                                                   %If no connection could be made to the serial port...
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
            set(listbox,'string',message,'value',[],'listboxtop',1);        %Update the message in the listbox.
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
            set(listbox,'string',message,'value',[],'listboxtop',1);        %Update the message in the listbox.
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
            set(listbox,'string',message,'value',[],'listboxtop',1);        %Update the message in the listbox.
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
    ardy.version = version;                                                 %Save the version number.
elseif version == 2.0                                                       %If the controller Arduino sketch version is 2.0...
	ardy = MotoTrak_Controller_V2pX_Serial_Functions(ardy);                 %Load the V2.X serial communication functions.
    ardy.version = ardy.check_version();                                    %Grab the sketch version number from the controller.
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


%% ***********************************************************************
function MotoTrak_Behavior_Loop(fig)

%
%MotoTrak_Behavior_Loop.m - Vulintus, Inc.
%
%   This function is the main behavioral loop for the MotoTrak program.
%   
%   UPDATE LOG:
%   07/06/2016 - Drew Sloan - Added in IR signal trial initiation
%       capability.
%   10/12/2016 - Drew Sloan - Added in remote error reporting through the
%       Vulintus error report email account.
%   10/28/2016 - Drew Sloan - Added support for tabbed plots and new run
%       variable loop control.
%   01/09/2017 - Drew Sloan - Implemented the global run variable update to
%       fix errors in function flow.
%   04/30/2018 - Drew Sloan - Added user-defined tone reinforcement
%       functions.
%   12/31/2018 - Drew Sloan - Added initial water reaching module
%       functionality.
%

global run                                                                  %Create the global run variable.

h = guidata(fig);                                                           %Grab the handles structure from the main GUI.

h = MotoTrak_Update_Controls_Within_Session(h);                             %Disable all of the uicontrols and uimenus during the session.
Clear_Msg([],[],h.msgbox);                                                  %Clear the original MotoTrak controller connection message out of the listbox.
       
%Create structures to hold session, trial, and stream data in one easily-passed variable.
temp = now;                                                                 %Grab the current clock reading.
session = struct(   'buffer',               [],...
                    'do_once',              1,...
                    'start',                temp,...
                    'end',                  temp + h.session_dur/1440,...
                    'burst_time',           temp,...
                    'burst_num',            0,...
                    'hitwin_tone_index',    0,...
                    'hit_tone_index',       0,...
                    'miss_tone_index',      0,...
                    'init_trig',            h.init_trig,...
                    'hit_log',              []);                            %Create a structure to hold session data.
trial = struct(     'num',                  0,...
                    'feeds',                0,...
                    'hit_time',             0,...
                    'stim_time',            [],...
                    'thresh',               [],...
                    'mon_signal',           []);                            %Create a structure to hold trial data.
                
%Initialize any enabled tones.
if h.ardy.version >= 2.00 && h.stage(h.cur_stage).tones_enabled == 1        %If the controller sketch is version 2.0+ and tones are enabled...    
    temp = {h.stage(h.cur_stage).tones.event};                              %Grab the tone initiation event types.
    for i = length(temp):-1:1                                               %Step backwards through the tones.
        switch lower(temp{i})                                               %Switch between the recognized tone initiation event types.
            case 'hitwindow'                                                %If the tone initiation event is the hit window...
                session.hitwin_tone_index = i;                              %Save the hit window start tone index.
            case 'hit'                                                      %If the tone initiation event is a hit...
                session.hit_tone_index = i;                                 %Save the hit tone index.
            case 'miss'                                                     %If the tone initiation event is a miss...
                session.miss_tone_index = i;                                %Save the miss tone index.
        end
    end
end

%Initialize various tracking variables.
pause_text = 0;                                                             %Create a variable to hold a text handle for a pause label.
session.cal = [h.slope, h.baseline];                                        %Grab the calibration function for the device.
session.minmax_ir = [1023,0,0];                                             %Keep track of the minimum and maximum IR values.
if strcmpi(h.ir_detector,'beam')                                            %If the IR detector is the beam type...
    session.minmax_ir(3) = 1023;                                            %Set the IR initiation threshold to a maximum value.
end
errstack = zeros(1,3);                                                      %Create a matrix to prevent duplicate error-reporting.

%Create the output data file.
[fid, filename] = MotoTrak_Write_File_Header(h);                            %Use the WriteFileHeader subfunction to write the file header.
h.data_file = filename;                                                     %Save the data file name in the handles structure.

%Create the variables for buffering the signal from the device.
session.pre_samples = round(1000*h.pre_trial_sampling/h.period);            %Calculate how many samples are in the pre-trial sample period.
session.post_samples = round(1000*h.post_trial_sampling/h.period);          %Calculate how many samples are in the post-trial sample period.
session.hit_samples = round(1000*h.hitwin/h.period);                        %Find the number of samples in the hit window.
session.hitwin = ...
    (session.pre_samples+1):(session.pre_samples + session.hit_samples);    %Save the samples within the hit window.
session.buffsize = ...
    session.pre_samples + session.hit_samples + session.post_samples;       %Specify the size of the data buffer, in samples.
session.min_peak_dist = round(100/h.period);                                %Find the number of samples in a 100 ms window for finding peaks.

%Set a minimum peak height depending on the connected device.
session.min_peak_val = 0;                                                   %Create a variable for excluding spurious peaks in the signal.
session.lever_return_pt = 0;                                                %Create a variable to prevent sustained signals from being treated as repeating peaks.
switch lower(h.device)                                                      %Switch between the recognized devices...
    case 'lever'                                                            %If the current device is the lever...       
        session.min_peak_val = h.total_range_in_degrees * 0.75;             %A "press" must be at least 3/4 of the range of motion of the lever.          
        session.lever_return_pt = h.total_range_in_degrees * 0.5;           %Lever must return to the 50% point in its range before a new press begins
    case 'knob'                                                             %If the current device is the knob.
        session.min_peak_val = 3;                                           %Set the minimum peak height to 3 degrees to prevent noise from appearing as a peak.
end

%Pre-allocate buffers and set expected indices.
session.buffer = zeros(session.buffsize,3);                                 %Create a matrix to buffer the stream data.
session.offset = ceil(session.min_peak_dist/2);                             %Calculate the number of samples to offset when grabbing the smoothed signal.
trial.data = zeros(session.buffsize,3);                                     %Create a matrix to hold the trial stream data.
trial.mon_signal = zeros(session.buffsize,1);                               %Create a matrix to hold the monitored signal.
trial.signal = zeros(session.buffsize,1);                                   %Create a matrix to hold the trial signal.
if strcmpi(h.device,'both')                                                 %If this is a combined touch-pull stage...
    trial.touch_signal = zeros(session.buffsize,1);                         %Zero out the trial signal.
end
session.max_thresh = 0;                                                     %Create a variable to keep track of the maximum threshold used.
session.total_degrees = nan(500,1);                                         %Create a buffer to hold the total number of degrees turned per trial.

%For random stimulation modes, set the random stimulation times.
session = MotoTrak_Set_Custom_Parameters(h, session);                       %Call the function to set any customized session parameters.

%Set the initiation threshold for static or adaptive thresholding.
trial.thresh = h.threshmin;                                                 %Set the initial hit threshold to the minimum hit threshold.
if strcmpi(h.threshadapt,'median')                                          %If this stage has a median-adapting threshold...
    session.thresh_buffer = nan(h.threshincr,1);                            %Create a matrix to track the maximum device reading within the hit window across trials.
end
if strcmpi(h.device,'touch')                                                %If the current device is the touch sensor...
    h.init = 0.5;                                                           %Set the initiation threshold to 0.5.
end

%Set any custom parameters for specific labs.

%Set the controller parameters for this session.
h.ardy.clear();                                                             %Clear any residual values from the serial line.
MotoTrak_Set_Stream_Params(h);                                              %Set the streaming properties on the MotoTrak controller.
h.ardy.stream_enable(1);                                                    %Enable periodic streaming on the MotoTrak controller.


%% MAIN LOOP ***********************************************************************************************************************
while fix(run) == 2                                                         %Loop until the user ends the session.
                                                             
    [h, trial] = MotoTrak_Reset_Trial_Data(h,session,trial);                %Call the function to reset the trial variables.
    trial = MotoTrak_Reset_Trial_Plots(h,session,trial);                    %Call the function to reset the streaming signal plots.
    
    
%WAITING FOR TRIAL INITIATION ******************************************************************************************************
    while max(trial.mon_signal) < h.init && ...
            trial.ir_initiate == 0 && ...
            run == 2                                                        %Loop until the the initiation threshold is broken or the session is stopped.
        
        [session, trial] = ...
            MotoTrak_Update_Monitor_Signal(h,session,trial);                %Call the function to update the monitored signal.
        if trial.N > 0                                                      %If new samples were found...
            session = MotoTrak_Update_IR_Bounds(h,session);                 %Update the IR bounds.
            trial = MotoTrak_Update_Monitor_Plots(h,session,trial);         %Update the stream signal plots.
        end
        
        if run == 2.1 && pause_text == 0                                    %If the user has paused the session...
            pause_text = text(mean(xlim),mean(ylim),'PAUSED',...
                'horizontalalignment','center',...
                'verticalalignment','middle',...
                'margin',2,...
                'edgecolor','k',...
                'backgroundcolor','y',...
                'fontsize',14,...
                'fontweight','bold',...
                'parent',h.primary_ax);                                     %Create text to show that the session is paused.
            fwrite(fid,0,'uint32');                                         %Write a trial number of zero.
            fwrite(fid,now,'float64');                                      %Write the pause time.
            fwrite(fid,'P','uint8');                                        %Write an 'P' (70) to indicate the session was paused.
        elseif pause_text ~= 0 && run ~= 2.1                                %If the session is unpaused and a pause label still exists...
            delete(pause_text);                                             %Delete the pause label.
            pause_text = 0;                                                 %Set the pause label handle variable to zero.
            fwrite(fid,now,'float64');                                      %Write the unpause time.
        elseif pause_text ~= 0                                              %If the session is still paused and the pause label exists...
            set(pause_text,'position',[mean(xlim),mean(ylim)]);             %Update the pause label position to center it on the plot.
        end
        
        MotoTrak_Update_Clock_Test(session,trial);                          %Call the function to update the clock text object.
        if now > session.end                                                %If the suggested session time has passed...
            session.end = Inf;                                              %Set the new suggested end time to infinite.
        end
        
        if h.stim == 2                                                      %If random stimulation is enabled...
            a = find(session.rand_stim_times > 0,1,'first');                %Find the next random stimulation time.
            if ~isempty(a) && now > session.rand_stim_times(a)              %If the clock has reached the next random stimulation time.
                h.ardy.stim();                                              %Trigger stimulation through the MotoTrak controller.
                trial.stim_time(end+1) = now;                               %Save the current time as a stimulation time.
                session.rand_stim_times(a) = 0;                             %Mark this stimulation time as completed.
            end
        end
        
        pause(0.01);                                                        %Pause for 10 milliseconds to keep from overwhelming the processor.
    end

    
%STARTING TRIAL ********************************************************************************************************************
    if run == 2                                                             %If the session is running and not paused or set for a manual feeding...
        
        try                                                                 %Attempt to initialize the trial signal.
            trial = ...
                MotoTrak_Initialize_Trial_Signal(h,session,trial);          %Call the function to initialize the trial signal.
        catch err                                                           %If an error occurred...
            if errstack(1) == 0                                             %If this error hasn't yet been reported...
                txt = MotoTrak_Save_Error_Report(h,err);                    %Save a copy of the error in the AppData folder.
                MotoTrak_Send_Error_Report(h,h.err_rcpt,txt);               %Send an error report to the specified recipient.
            end
            errstack(1) = 1;                                                %Set the error reported value to 1 to prevent redundant reports.
        end
        
        if trial.hitwin_tone_on == 1                                        %If a hit window start tone is enabled...
            h.ardy.play_tone(session.hitwin_tone_index);                    %Start the tone.
            trial.hitwin_tone_on = 2;                                       %Set the flag to two indicate the hit window tone is on.
        end
        
        if strcmpi(session.init_trig,'on')                                  %If an initiation trigger is enabled...
            h.ardy.stim();                                                  %Trigger stimulation through the MotoTrak controller.
        end
            
        trial = MotoTrak_Initialize_Trial_Plots(h,session,trial);           %Call the function to create the trial plots.      
    end
    
%     str = sprintf('size(trial.cur_sample) = [%1.2f, %1.2f], size(trial.buffsize) = [%1.2f, %1.2f]',...
%         size(trial.cur_sample),size(trial.buffsize));
%     msgbox(str);
    
%WAITING FOR HIT/MISS **************************************************************************************************************
    while run == 2 && trial.cur_sample < trial.buffsize                     %Loop until the end of the trial or the user stops the session/pauses/manual feeds.
        
        try                                                                 %Attempt to update the trial signals.
            [session, trial] = ...
                MotoTrak_Update_Trial_Signal(h,session,trial);              %Call the function to update the trial signals.
        catch err                                                           %If an error occurred...
            if errstack(2) == 0                                             %If this error hasn't yet been reported...
                txt = MotoTrak_Save_Error_Report(h,err);                    %Save a copy of the error in the AppData folder.
                MotoTrak_Send_Error_Report(h,h.err_rcpt,txt);               %Send an error report to the specified recipient.                    
            end
            errstack(2) = 1;                                                %Set the error reported value to 1 to prevent redundant reports.
        end        

        if trial.hit_time == 0                                              %If the animal hasn't gotten a hit yet.
            [trial, session] = MotoTrak_Check_For_Hit(h,session,trial);     %Call the function to check for a hit.   
        end
        
        if trial.hit_time ~= 0 && isfield(h,'variant')                      %If a hit was scored on this loop and there's a custom variant in the handles structure...
            switch h.variant                                                %Switch between the recognized custom variants.
                case 'hollis'                                               %If this is a custom stage for the Hollis labvariant...
                case 'machado lab'                                          %If this is the custom stage for Machado lab...
                    trial.buffsize = ...
                        trial.cur_sample + trial.N + ...
                        session.post_samples;                               %Set the new buffer timeout.
            end
        end    

        if trial.N > 0                                                      %If new samples were found...
            session = MotoTrak_Update_IR_Bounds(h,session);                 %Update the IR bounds.
            trial = MotoTrak_Update_Trial_Plots(h,session,trial);           %Update the stream signal plots.
        end
        
        MotoTrak_Update_Clock_Test(session,trial);                          %Call the function to update the clock text object.
        if now > session.end                                                %If the suggested session time has passed...
            session.end = Inf;                                              %Set the new suggested end time to infinite.
        end
        
        
        if h.stim == 2                                                      %If random stimulation is enabled...
            a = find(session.rand_stim_times > 0,1,'first');                %Find the next random stimulation time.
            if ~isempty(a) && now > session.rand_stim_times(a)              %If the clock has reached the next random stimulation time.
                h.ardy.stim();                                              %Trigger stimulation through the MotoTrak controller.
                trial.stim_time(end+1) = now;                               %Save the current time as a stimulation time.
                session.rand_stim_times(a) = 0;                             %Mark this stimulation time as completed.
            end
        end
        
        if (trial.hitwin_tone_on == 2 || trial.miss_tone_on == 1) && ...
                ~any(trial.cur_sample == session.hitwin)                    %If a hit window tone or a miss tone is enabled and the hit window has closed...
            if trial.miss_tone_on == 1                                      %If a miss tone is enabled...
                h.ardy.play_tone(session.miss_tone_index);                  %Start the miss tone.
                trial.miss_tone_on = 2;                                     %Set the miss tone flag to two to indicate it is currently on.
            elseif trial.hitwin_tone_on == 2                                %Otherwise, if a hit window tone is currently playing...
                h.ardy.stop_tone();                                         %Stop the hit window tone.
            end
            trial.hitwin_tone_on = 0;                                       %Set the hit window tone flag to zero.
            trial.hit_tone_on = 0;                                          %Set the hit tone flag to zero.
        end
        
        pause(0.01);                                                        %Pause for 10 milliseconds to keep from overwhelming the processor.
    end
    
    if h.stim == 1 && ...
            (~isempty(trial.stim_time) && trial.stim_time == 0) && ...
            strcmpi(h.curthreshtype,'milliseconds/grams')                   %If stimulation is turned on and this is a combined touch/pull stage...
        h.ardy.stim_off();                                                  %Immediately turn off stimulation.
        trial.stim_time = now;                                              %Save the current time as the hit time.
    end
                    
%RECORD TRIAL RESULTS **************************************************************************************************************
    if run == 2                                                             %If the session is still running...
                      
        %Check to see if this trial was a hit or a miss.
        if trial.hit_time > 0                                               %If the trial resulted in a hit...
            trial.score = 'HIT';                                            %Show the user it was a hit.            
        elseif trial.hit_time < 0                                           %If the trial resulted in an abort...
            trial.score = 'ABORT';                                          %Show the user it was an abort.
            trial.hit_time = 0;                                             %Set the hit time to zero.
            if trial.hitwin_tone_on == 2                                    %If a hit window tone is currently playing...
                h.ardy.stop_tone();                                         %Stop the hit window tone.                
            end
            trial.hitwin_tone_on = 0;                                       %Set the hit window tone flag to zero.
        else                                                                %Otherwise, if the trial resulted in a miss...
            trial.score = 'MISS';                                           %Show the user it was a miss.
            if trial.miss_tone_on == 1                                      %If a miss tone is enabled, but hasn't yet been played...
                h.ardy.play_tone(session.miss_tone_index);                  %Start the miss tone.
                trial.miss_tone_on = 2;                                     %Set the miss tone flag to two to indicate the tone is currently playing.
            elseif trial.hitwin_tone_on == 2                                %Otherwise, if a hit window tone is currently playing...
                h.ardy.stop_tone();                                         %Stop the hit window tone.                
            end
            trial.hitwin_tone_on = 0;                                       %Set the hit window tone flag to zero.
        end        
        
        trial.data(:,1) = trial.data(:,1) - trial.start(2);                 %Subtract the start time from the sample times.
        session.total_degrees(trial.num) = ...
            nanmax(trial.signal(session.hitwin));                           %Find the maximum rotation for this trial.
        
        MotoTrak_Write_Trial_Data(fid,h,trial);                             %Call the function to write the trial data to file.
        
        trial.stim_time = [];                                               %Reset the stimulation times buffer.        
        
        if any(strcmpi(trial.score,{'hit','miss'}))                         %If the trial was scored as a hit or a miss...
            session.hit_log(end+1,:) = ...
                [trial.start(1), trial.score(1) == 'H'];                    %Save the trial time and score for plotting.
        end        
            
        try                                                                 %Attempt to update the messagebox and trials axes.
            MotoTrak_Display_Trial_Results(h,session,trial);                %Call the function to display the trial results.
        catch err                                                           %If an error occurred...
            if errstack(3) == 0                                             %If this error hasn't yet been reported...
                txt = MotoTrak_Save_Error_Report(h,err);                    %Save a copy of the error in the AppData folder.
                MotoTrak_Send_Error_Report(h,h.err_rcpt,txt);               %Send an error report to the specified recipient.
            end
            errstack(3) = 1;                                                %Set the error reported value to 1 to prevent redundant reports.
        end
        
        [trial, session] = ...
            MotoTrak_Update_Threshold(h,session,trial);                     %Call the function to update the hit threshold.

    elseif h.stim == 2 && fix(run) ~= 2 && ~isempty(trial.stim_time)        %If the user's stopped the session and random stimulation is enabled and there's stimulation times to write...
        MotoTrak_Write_Pause_Data(fid,trial)
        trial.stim_time = [];                                               %Clear out the stimulation times buffer.    
        
    elseif run == 2.2                                                       %Otherwise if the user manually fed the rat...
        h.ardy.trigger_feeder(1);                                           %Trigger feeding on the MotoTrak controller.
        trial.num = trial.num - 1;                                          %Subtract one from the trial counter.
        fwrite(fid,0,'uint32');                                             %Write a trial of zero.
        fwrite(fid,now,'float64');                                          %Write the current time.
        fwrite(fid,'F','uint8');                                            %Write an 'F' (70) to indicate a manual feeding.
        Add_Msg(h.msgbox,[datestr(now,13) ' - Manual Feeding.']);           %Show the user that the session has ended.
        run = 2;                                                            %Reset the run variable to 2.
    end
end

fclose(fid);                                                                %Close the session data file.

%Stop the data stream.
try                                                                         %Attempt to clear the serial line.
    h.ardy.stream_enable(0);                                                %Disable streaming on the MotoTrak controller.
    h.ardy.clear();                                                         %Clear any residual values from the serial line.
catch err                                                                   %If an error occurred...
    txt = MotoTrak_Save_Error_Report(h,err);                                %Save a copy of the error in the AppData folder.
    MotoTrak_Send_Error_Report(h,h.err_rcpt,txt);                           %Send an error report to the specified recipient.
end

% Max_Degrees_Turned = nanmax(session.total_degrees);
Mean_Degrees_Turned = nanmean(session.total_degrees);                       %Calculate the average number of degrees turned per trial.


Add_Msg(h.msgbox,[datestr(now,13) ' - Session ended.']);                    %Show the user that the session has ended.

str = sprintf(['Pellets fed: %1.0f, '...
    'Max Threshold: %1.2f, '...
    'Thresholding Type: %s, '...
    'Mean Degrees Turned: %1.1f'],...
    trial.feeds, session.max_thresh, h.threshadapt, Mean_Degrees_Turned);   %Create a final session output message.
Add_Msg(h.msgbox, str);                                                     %Show the final session values to the user.

MotoTrak_Enable_Controls_Outside_Session(h);                                %Enable all of the non-session controls.

set(h.startbutton,'enable','off');                                          %Disable the start/stop button until a new stage is selected.
set(h.pausebutton,'enable','off');                                          %Disable the pause button.

guidata(h.mainfig,h);                                                       %Pin the handles structure to the main figure.


%% ***********************************************************************
function [trial, session] = MotoTrak_Check_For_Hit(handles,session,trial)

%
%MotoTrak_Check_For_Hit.m - Vulintus, Inc.
%
%   MOTOTRAK_CHECK_FOR_HIT checks the current signal to see if the current
%   "hit" criteria have been satisfied.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       hit checking sections from MotoTrak_Behavior_Loop.m.
%

                
switch handles.curthreshtype                                                %Switch between the types of hit threshold.

    case {  'grams (peak)',...
            'degrees (total)',...
            'degrees/s','bidirectional',...
            'milliseconds (hold)',...
            'milliseconds/grams'    }                                       %For threshold types in which the signal must just exceed a value...
        if  max(trial.signal(session.hitwin)) > trial.thresh                %If the trial threshold was exceeded within the hit window...            
            if ~isnan(handles.ceiling) && handles.ceiling ~= Inf            %If a ceiling is set for this stage...
                for s = (trial.cur_sample - trial.N + 1):trial.cur_sample   %Step through each new sample.
                    if any(s == session.hitwin) && trial.hit_time == 0      %If the current sample is within the hit window...                    
                        if trial.signal(s) >= trial.thresh && ...                            
                                trial.signal(s) <= handles.ceiling && ...
                                trial.ceiling_check == 0                    %If the current value is greater than the threshold but less than the ceiling...
                            trial.ceiling_check = 1;                        %Set the ceiling check variable to 1.
                            set(trial.plot_h(1),'facecolor',[0.5 1 0.5]);   %Set the area plot facecolor to green.                        
                        elseif trial.signal(s) > handles.ceiling            %If the current value is greater than the ceiling...
                            trial.ceiling_check = -1;                       %Set the ceiling check variable to -1.
                            set(trial.plot_h(1),'facecolor',[1 0.5 0.5]);   %Set the area plot facecolor to red.                        
                        elseif trial.ceiling_check == 1 && ...
                                trial.signal(s) < trial.thresh              %If the current value is less than the threshold which was previously exceeded...
                            [session, trial] = ...
                                MotoTrak_Score_Hit(handles,...
                                session, trial);                            %Call the function to score a hit.                        
                        elseif trial.ceiling_check == -1 && ...
                                trial.signal(s) <= handles.init             %If the rat previously exceeded the ceiling but the current value is below the initiation threshold...
                            trial.ceiling_check = 0;                        %Set the ceiling check variable back to 0.
                            set(trial.plot_h(1),'facecolor',[0.5 0.5 1]);   %Set the area plot facecolor to blue.                        
                        end
                    end      
                end          
            else                                                            %Otherwise, if there is no ceiling for this stage...       
                [session, trial] = MotoTrak_Score_Hit(handles, session,...
                    trial);                                                 %Call the function to score a hit.              
            end
        end

    case 'presses'                                                          %If the current threshold type is the number of presses...                    
        if (length(trial.peak_vals) >= trial.thresh)                        %Are there enough of these peaks? If so, it is a hit.
            [session, trial] = MotoTrak_Score_Hit(handles, session, trial); %Call the function to score a hit.  
        end

    case 'fullpresses'                                                      %If the current threshold type is full presses...                    
        if numel(trial.peak_vals) >= trial.thresh && ...
                length(trial.release_pts) >= trial.thresh                   %If the lever has been pressed AND released the required number of times...
            [session, trial] = MotoTrak_Score_Hit(handles, session, trial); %Call the function to score a hit.   
        end
end


%% ***********************************************************************
function MotoTrak_Close(fig)

%
%MotoTrak_Close.m - Vulintus, Inc.
%
%   MotoTrak_Close executes after the main loop terminates, usually because
%   the user closes the figure window.
%   
%   UPDATE LOG:
%

handles = guidata(fig);                                                     %Grab the handles structure from the main GUI.

handles.ardy.stream_enable(0);                                              %Double-check that streaming on the Arduino is disabled.
handles.ardy.clear();                                                       %Clear any leftover stream output.
fclose(handles.ardy.serialcon);                                             %Delete the serial connection to the Arduino.
delete(handles.mainfig);                                                    %Delete the main figure.


%% ***********************************************************************
function MotoTrak_Controller_Update_EEPROM_Int2Float(ardy)

%
%MotoTrak_Controller_Update_EEPROM_Int2Float.m - Vulintus, Inc.
%
%   This function converts calibration constants saved in the MotoTrak
%   controller's EEPROM from integers to floats when upgrading to V2.00+
%   controller microcode.
%
%   UPDATE LOG:
%   04/27/2018 - Drew Sloan - First function implementation.
%

for i = 1:10                                                                %Step through the available device indices.
    slope = ardy.get_slope_float(i);                                        %Fetch the slope for the device type.
    baseline = ardy.get_baseline_float(i);                                  %Fetch the baseline for the device type.
    
    if isnan(slope) || slope == 0                                           %If the slope value saved in EEPROM is NaN or zero...
        switch i                                                            %Switch between the recognized device types.
            
            case {1, 6}                                                     %If the device is the lever or the pull...
                slope = ardy.cal_grams()/ardy.n_per_cal_grams();            %Fetch the slope from the original EEPROM address.
                if slope == 0 || abs(slope) == Inf                          %If the slope is zero..
                    slope = 1;                                              %Set the slope equal to 1.
                end
                
            case 2                                                          %If the device is the supination knob...
                slope = -2.5;                                               %Set the slope to -2.5
                
            otherwise                                                       %For all other devices...
                slope = 1;                                                  %Set the slope to 1.
                
        end        
    end
    
    if isnan(baseline)                                                      %If the baseline value saved in EEPROM is NaN...
        switch i                                                            %Switch between the recognized device types.
            
            case {1, 6}                                                     %If the device is the lever or the pull...
                baseline = ardy.baseline();                                 %Fetch the baseline from the original EEPROM address.
                
            otherwise                                                       %For all other devices...
                baseline = 0;                                               %Set the baseline to zero.
                
        end        
    end
    
    if baseline > 1023                                                      %If the saved baseline is greater than 1023...
        baseline = 100;                                                     %Set the baseline to an arbitrary value of 100.
    end
    
    ardy.set_baseline_float(i,baseline);                                    %Save the baseline as a float in the EEPROM address for the current module.
    ardy.set_slope_float(i,slope);                                          %Save the slope as a float in the EEPROM address for the current module.
end


%% ***********************************************************************
function moto = MotoTrak_Controller_V1p4_Serial_Functions(moto)

%MotoTrak_Controller_V1p4_Serial_Functions.m - Vulintus, Inc., 2015
%
%   MotoTrak_Controller_V1p4_Serial_Functions defines and adds the Arduino
%   serial communication functions to the "moto" structure. These functions
%   are for sketch version 1.4 and earlier, and may not work with newer
%   version (2.0+).
%
%   UPDATE LOG:
%   05/09/2016 - Drew Sloan - Separated V1.4 serial functions from the
%       Connect_MotoTrak function to allow for loading V2.0 functions.
%   10/13/2016 - Drew Sloan - Added "v1p4_" prefix to all subfunction names
%       to prevent duplicate name errors in collated MotoTrak script.
%   04/25/2018 - Drew Sloan - Shortened the serial port time-out property
%       value from 10 seconds to 2 seconds.
%

serialcon = moto.serialcon;                                                 %Grab the handle for the serial connection.
serialcon.Timeout = 2;                                                      %Set the timeout for serial read/write operations, in seconds. << Added 4/25/2018
serialcon.UserData = 2;                                                     %Set the default number of inputs. << Added 4/25/2018

%Basic status functions.
moto.check_serial = @()v1p4_check_serial(serialcon);                        %Set the function for checking the serial connection.
moto.check_sketch = @()v1p4_check_sketch(serialcon);                        %Set the function for checking that the MotoTrak sketch is running.
moto.check_version = @()v1p4_simple_return(serialcon,'Z',[]);               %Set the function for returning the version of the MotoTrak sketch running on the Arduino.
moto.booth = @()v1p4_simple_return(serialcon,'BA',1);                       %Set the function for returning the booth number saved on the Arduino.
moto.set_booth = @(int)v1p4_long_command(serialcon,'Cnn',[],int);           %Set the function for setting the booth number saved on the Arduino.


%Motor manipulandi functions.
moto.device = @(i)v1p4_simple_return(serialcon,'DA',1);                     %Set the function for checking which device is connected to an input.
moto.baseline = @(i)v1p4_simple_return(serialcon,'NA',1);                   %Set the function for reading the loadcell baseline value.
moto.cal_grams = @(i)v1p4_simple_return(serialcon,'PA',1);                  %Set the function for reading the number of grams a loadcell was calibrated to.
moto.n_per_cal_grams = @(i)v1p4_simple_return(serialcon,'RA',1);            %Set the function for reading the counts-per-calibrated-grams for a loadcell.
moto.read_Pull = @(i)v1p4_simple_return(serialcon,'MA',1);                  %Set the function for reading the value on a loadcell.
moto.set_baseline = ...
    @(int)v1p4_long_command(serialcon,'Onn',[],int);                        %Set the function for setting the loadcell baseline value.
moto.set_cal_grams = ...
    @(int)v1p4_long_command(serialcon,'Qnn',[],int);                        %Set the function for setting the number of grams a loadcell was calibrated to.
moto.set_n_per_cal_grams = ...
    @(int)v1p4_long_command(serialcon,'Snn',[],int);                        %Set the function for setting the counts-per-newton for a loadcell.
moto.trigger_feeder = @(i)v1p4_simple_command(serialcon,'WA',1);            %Set the function for sending a trigger to a feeder.
moto.trigger_stim = @(i)v1p4_simple_command(serialcon,'XA',1);              %Set the function for sending a trigger to a stimulator.
moto.stream_enable = @(i)v1p4_simple_command(serialcon,'gi',i);             %Set the function for enabling or disabling the stream.
moto.set_stream_period = @(int)v1p4_long_command(serialcon,'enn',[],int);   %Set the function for setting the stream period.
moto.stream_period = @()v1p4_simple_return(serialcon,'f',[]);               %Set the function for checking the current stream period.
moto.set_stream_ir = @(i)v1p4_simple_command(serialcon,'ci',i);             %Set the function for setting which IR input is read out in the stream.
moto.stream_ir = @()v1p4_simple_return(serialcon,'d',[]);                   %Set the function for checking the current stream IR input.
moto.read_stream = @()v1p4_read_stream(serialcon);                          %Set the function for reading values from the stream.
moto.clear = @()v1p4_clear_stream(serialcon);                               %Set the function for clearing the serial line prior to streaming.
moto.knob_toggle = @(i)v1p4_simple_command(serialcon, 'Ei', i);             %Set the function for enabling/disabling knob analog input.
moto.sound_1000 = @(i)v1p4_simple_command(serialcon, '1', []);
moto.sound_1100 = @(i)v1p4_simple_command(serialcon, '2', []);


%Behavioral control functions.
moto.play_hitsound = @(i)v1p4_simple_command(serialcon,'J', 1);             %Set the function for playing a hit sound on the Arduino
% moto.digital_ir = @(i)simple_return(serialcon,'1i',i);                      %Set the function for checking the digital state of the behavioral IR inputs on the Arduino.
% moto.analog_ir = @(i)simple_return(serialcon,'2i',i);                       %Set the function for checking the analog reading on the behavioral IR inputs on the Arduino.
moto.feed = @(i)v1p4_simple_command(serialcon,'3A',1);                      %Set the function for triggering food/water delivery.
moto.feed_dur = @()v1p4_simple_return(serialcon,'4',[]);                    %Set the function for checking the current feeding/water trigger duration on the Arduino.
moto.set_feed_dur = @(int)v1p4_long_command(serialcon,'5nn',[],int);        %Set the function for setting the feeding/water trigger duration on the Arduino.
moto.stim = @()v1p4_simple_command(serialcon,'6',[]);                       %Set the function for sending a trigger to the stimulation trigger output.
moto.stim_off = @()v1p4_simple_command(serialcon,'h',[]);                   %Set the function for immediately shutting off the stimulation output.
moto.stim_dur = @()v1p4_simple_return(serialcon,'7',[]);                    %Set the function for checking the current stimulation trigger duration on the Arduino.
moto.set_stim_dur = @(int)v1p4_long_command(serialcon,'8nn',[],int);        %Set the function for setting the stimulation trigger duration on the Arduino.
moto.lights = @(i)v1p4_simple_command(serialcon,'9i',i);                    %Set the function for turn the overhead cage lights on/off.
moto.autopositioner = @(int)v1p4_long_command(serialcon,'0nn',[],int);      %Set the function for setting the stimulation trigger duration on the Arduino.


%% This function checks the status of the serial connection.
function output = v1p4_check_serial(serialcon)
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
function output = v1p4_check_sketch(serialcon)
fwrite(serialcon,'A','uchar');                                              %Send the check status code to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if output == 111                                                            %If the Arduino returned the number 111...
    output = 1;                                                             %...show that the Arduino connection is good.
else                                                                        %Otherwise...
    output = 0;                                                             %...show that the Arduino connection is bad.
end


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function v1p4_simple_command(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function output = v1p4_simple_return(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.


%% This function sends commands with 16-bit integers broken up into 2 characters encoding each byte.
function v1p4_long_command(serialcon,command,i,int)     
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
i = dec2bin(int16(int),16);                                                 %Convert the 16-bit integer to a 16-bit binary string.
byteA = bin2dec(i(1:8));                                                    %Find the character that codes for the first byte.
byteB = bin2dec(i(9:16));                                                   %Find the character that codes for the second byte.
i = strfind(command,'nn');                                                  %Find the spot for the 16-bit integer bytes in the command.
command(i:i+1) = char([byteA, byteB]);                                      %Insert the byte characters into the command.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function reads in the values from the data stream when streaming is enabled.
function output = v1p4_read_stream(serialcon)
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
function v1p4_clear_stream(serialcon)
tic;                                                                        %Start a timer.
while serialcon.BytesAvailable == 0 && toc < 0.05                           %Loop for 50 milliseconds or until there's a reply on the serial line.
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    fscanf(serialcon,'%d');                                                 %Read each byte and discard it.
end


%% ***********************************************************************
function moto = MotoTrak_Controller_V2pX_Serial_Functions(moto)

%MotoTrak_Controller_V2pX_Serial_Functions.m - Vulintus, Inc., 2016
%
%   MotoTrak_Controller_V2pX_Serial_Functions defines and adds the Arduino
%   serial communication functions to the "moto" structure. These functions
%   are for sketch versions 2.0+ and may not work with older versions.
%
%   UPDATE LOG:
%   05/12/2016 - Drew Sloan - Created the basic sketch status functions.
%   10/13/2016 - Drew Sloan - Added "v2p0_" prefix to all subfunction names
%       to prevent duplicate name errors in collated MotoTrak script.
%   04/19/2018 - Drew Sloan - Incorporated serial block codes matched to an
%       Arduino library to simplify serial code handling.
%


serialcon = moto.serialcon;                                                 %Grab the handle for the serial connection.
serialcon.Timeout = 2;                                                      %Set the timeout for serial read/write operations, in seconds.
serialcon.UserData = [2, 1, 2, 0, 0, 0, 0];                                 %Set the default number of inputs and the default stream order.

s = Load_MotoTrak_Serial_Codes(2.0);                                        %Load the serial block codes for sketch version 2.0.


%% Functions required for backwards compatibility.

%Basic status functions.
moto.check_serial = @()v2p0_check_serial(serialcon);                        %Set the function for checking the serial connection.
moto.check_sketch = @()v2p0_check_sketch(serialcon);                        %Set the function for checking that the MotoTrak sketch is running.
moto.check_version = ...
    @()v2p0_simple_return_uint16(serialcon,s.GET_SKETCH_VERSION);           %Set the function for returning the version of the MotoTrak sketch running on the controller.
moto.booth = @()v2p0_read_eeprom_uint16(serialcon,s,s.EEPROM_BOOTH_NUM);    %Set the function for returning the booth number saved on the controller.
moto.set_booth = ...
    @(int)v2p0_write_eeprom_uint16(serialcon,s,s.EEPROM_BOOTH_NUM,int);     %Set the function for setting the booth number saved on the controller.

%Motor manipulandi functions.
moto.device = @()v2p0_simple_return_uint16(serialcon,s.DEVICE_ID);          %Set the function for checking which device is connected to an input.
moto.baseline = ...
    @()v2p0_read_eeprom_uint16(serialcon,s,s.EEPROM_CAL_BASE_INT);          %Set the function for reading the loadcell baseline value.
moto.cal_grams = ...
    @()v2p0_read_eeprom_uint16(serialcon,s,s.EEPROM_CAL_FORCE_INT);         %Set the function for reading the number of grams a loadcell was calibrated to.
moto.n_per_cal_grams = ...
    @()v2p0_read_eeprom_uint16(serialcon,s,s.EEPROM_CAL_TICK_INT);          %Set the function for reading the counts-per-calibrated-grams for a loadcell.
moto.read_Pull = @()v2p0_read_pull(serialcon,s.READ_DEVICE_VAL);            %Set the function for reading the value on a loadcell.
moto.set_baseline = ...
    @(int)v2p0_write_eeprom_uint16(serialcon,s,s.EEPROM_CAL_BASE_INT,int);  %Set the function for setting the loadcell baseline value.
moto.set_cal_grams = ...
    @(int)v2p0_write_eeprom_uint16(serialcon,s,s.EEPROM_CAL_FORCE_INT,int); %Set the function for setting the number of grams a loadcell was calibrated to.
moto.set_n_per_cal_grams = ...
    @(int)v2p0_write_eeprom_uint16(serialcon,s,s.EEPROM_CAL_TICK_INT,int);  %Set the function for setting the counts-per-newton for a loadcell.
moto.trigger_feeder = @(i)v2p0_simple_command(serialcon,s.TRIGGER_FEEDER);  %Set the function for sending a trigger to a feeder.
moto.trigger_stim = @()v2p0_send_uint8(serialcon,s.SEND_TRIGGER,1,0);       %Set the function for sending a trigger to a stimulator.
moto.stream_enable = ...
    @(int)v2p0_stream_enable(serialcon,s.STREAM_ENABLE,int);                %Set the function for enabling or disabling the stream.
moto.set_stream_period = ...
    @(int)v2p0_set_stream_period(serialcon,s.SET_STREAM_PERIOD,int);        %Set the function for setting the stream period.
moto.stream_period = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_STREAM_PERIOD);         %Set the function for checking the current stream period.
moto.set_stream_ir = @(i)v2p0_set_stream_input(serialcon,s,2,i);            %Set the function for setting which IR input is read out in the stream.
moto.stream_ir = @()v2p0_get_stream_input(serialcon,s,2);                   %Set the function for checking the current stream IR input.
moto.read_stream = @()v2p0_read_stream(serialcon);                          %Set the function for reading values from the stream.
moto.clear = @()v2p0_clear_stream(serialcon);                               %Set the function for clearing the serial line prior to streaming.
moto.knob_toggle = @(i)v2p0_set_stream_input(serialcon,s,1,6);              %Set the function for enabling/disabling knob analog input.
moto.sound_1000 = @()v2p0_send_uint8(serialcon,s.PLAY_TONE,1,0);            %Set the function for playing a default 1000 Hz, 20 ms tone.
moto.sound_1100 = @()v2p0_send_uint8(serialcon,s.PLAY_TONE,2,0);            %Set the function for playing a default 1100 Hz, 20 ms tone.

%Behavioral control functions.
moto.play_hitsound = @(i)v2p0_send_uint8(serialcon,s.PLAY_TONE,3,0);        %Set the function for playing a hit sound on the Arduino (default 4000 Hz, 20 ms).
moto.feed = @()v2p0_simple_command(serialcon,s.TRIGGER_FEEDER);             %Set the function for triggering food/water delivery.
moto.feed_dur = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_FEED_TRIG_DUR);         %Set the function for checking the current feeding/water trigger duration on the controller.
moto.set_feed_dur = ...
    @(int)v2p0_send_uint16(serialcon,s.SET_FEED_TRIG_DUR,int,0);            %Set the function for setting the feeding/water trigger duration on the controller.
moto.stim = @()v2p0_send_uint8(serialcon,s.SEND_TRIGGER,1,0);               %Set the function for sending a trigger to the stimulation trigger output.
moto.stim_off = @()v2p0_simple_command(serialcon,s.STOP_TRIGGER);           %Set the function for immediately shutting off the stimulation output.
moto.stim_dur = @()v2p0_simple_return_uint16(serialcon,s.RETURN_TRIG_DUR);  %Set the function for checking the current stimulation trigger duration on the controller.
moto.set_stim_dur = @(int)v2p0_send_uint16(serialcon,s.SET_TRIG_DUR,int,0); %Set the function for setting the stimulation trigger duration on the controller.
moto.lights = @(i)v2p0_set_cage_lights(serialcon,s,i);                      %Set the function for turn the overhead cage lights on/off.
moto.autopositioner = ...
    @(int)v2p0_send_uint16(serialcon,s.SET_AP_DIST,int,1);                  %Set the function for setting the autopositioner distance.


%% Functions available on controller sketch version 2.0+.

%Basic status functions.
moto.set_serial_number = ...
    @(int)v2p0_write_eeprom_uint32(serialcon,s,s.EEPROM_SN,int);            %Set the function for saving the controller serial number in the EEPROM.
moto.get_serial_number = ...
    @()v2p0_read_eeprom_uint32(serialcon,s,s.EEPROM_SN);                    %Set the function for reading the controller serial number from the EEPROM.

%Calibration functions.
moto.set_baseline_float = ...
    @(i,val)v2p0_set_cal_float(serialcon,s,s.EEPROM_CAL_BASE_FL,i,val);     %Set the function for saving the device calibration baseline as a float in the EEPROM.
moto.get_baseline_float = ...
    @(i)v2p0_get_cal_float(serialcon,s,s.EEPROM_CAL_BASE_FL,i);             %Set the function for reading the device baseline as a float in the EEPROM.
moto.set_slope_float = ...
    @(i,val)v2p0_set_cal_float(serialcon,s,s.EEPROM_CAL_SLOPE_FL,i,val);    %Set the function for saving the device baseline as a float in the EEPROM.
moto.get_slope_float = ...
    @(i)v2p0_get_cal_float(serialcon,s,s.EEPROM_CAL_SLOPE_FL,i);            %Set the function for reading the device baseline as a float in the EEPROM.

%Motor manipulandi functions.
moto.read_input = ...
    @(i)v2p0_send_uint8_return_int16(serialcon,s.READ_DEVICE_VAL,i);       %Set the function for reading the value on one current input.
moto.reset_rotary_encoder = ...
    @()v2p0_simple_command(serialcon,s.RESET_COUNTER);                      %Set the function for resetting the current rotary encoder count.
moto.set_stream_input = ...
    @(index,input)v2p0_set_stream_input(serialcon,s,index,input);           %Set the function for setting which IR input is read out in the stream.
moto.get_stream_input = @(index)v2p0_get_stream_input(serialcon,s,index);   %Set the function for checking the current stream IR input.

%Tone commands.
moto.play_tone = @(i)v2p0_send_uint8(serialcon,s.PLAY_TONE,i,0);            %Set the function for immediate triggering of a tone.
moto.stop_tone = @()v2p0_simple_command(serialcon,s.STOP_TONE);             %Set the function for immediately silencing all tones.
moto.set_tone_index = ...
    @(i)v2p0_send_uint8(serialcon,s.SET_TONE_INDEX,i,0);                    %Set the function for setting the current tone index.
moto.get_tone_index = ...
    @()v2p0_simple_return_uint8(serialcon,s.RETURN_TONE_INDEX);             %Set the function for checking the current tone index.
moto.set_tone_freq = ...
    @(int)v2p0_send_uint16(serialcon,s.SET_TONE_FREQ,int,0);                %Set the function for setting the frequency of a tone.
moto.get_tone_freq = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_TONE_FREQ);             %Set the function for checking the current frequency of a tone.
moto.set_tone_dur = ...
    @(int)v2p0_send_uint16(serialcon,s.SET_TONE_DUR,int,0);                 %Set the function for setting the duration of a tone.
moto.get_tone_dur = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_TONE_DUR);              %Set the function for checking the current duration of a tone.
moto.set_tone_mon_input = ...
    @(int)v2p0_send_uint8(serialcon,s.SET_TONE_MON,int,0);                  %Set the function for setting the monitored input for triggering a tone.
moto.get_tone_mon_input =  ...
    @()v2p0_simple_return_uint8(serialcon,s.RETURN_TONE_MON);               %Set the function for checking the current monitored input for triggering a tone.
moto.set_tone_trig_type = ...
    @(int)v2p0_send_uint8(serialcon,s.SET_TONE_TYPE,int,0);                 %Set the function for setting the trigger type for a tone.
moto.get_tone_trig_type = ...
    @()v2p0_simple_return_uint8(serialcon,s.RETURN_TONE_TYPE);              %Set the function for checking the current trigger type for a tone.
moto.set_tone_trig_thresh = ...
    @(int)v2p0_send_int16(serialcon,s.SET_TONE_THRESH,int,0);               %Set the function for setting the trigger threshold for a tone.
moto.get_tone_trig_thresh = ...
    @()v2p0_simple_return_int16(serialcon,s.RETURN_TONE_THRESH);            %Set the function for checking the current trigger threshold for a tone.
moto.get_max_num_tones = ...
    @()v2p0_simple_return_uint8(serialcon,s.RETURN_MAX_TONES);              %Set the function for checking the maximum number of tones that can be set.

%Trigger commands.
moto.send_trigger = @(i)v2p0_send_uint8(serialcon,s.SEND_TRIGGER,i,0);      %Set the function for an immediate output trigger.
moto.stop_trigger = @()v2p0_simple_command(serialcon,s.STOP_TRIGGER);       %Set the function for immediately stopping the active trigger.
moto.set_trig_index = ...
    @(i)v2p0_send_uint8(serialcon,s.SET_TRIG_INDEX,i,0);                    %Set the function for setting the current trigger index.
moto.get_trig_index = ...
    @()v2p0_simple_return_uint8(serialcon,s.RETURN_TRIG_INDEX);             %Set the function for checking the current trigger index.
moto.set_trig_dur = ...
    @(int)v2p0_send_uint16(serialcon,s.SET_TRIG_DUR,int,0);                 %Set the function for setting the duration of a trigger.
moto.get_trig_dur = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_TRIG_DUR);              %Set the function for checking the current duration of a trigger.
moto.set_trig_mon_input = ...
    @(int)v2p0_send_uint8(serialcon,s.SET_TRIG_MON,int,0);                  %Set the function for setting the monitored input for a trigger.
moto.get_trig_mon_input =  ...
    @()v2p0_simple_return_uint8(serialcon,s.RETURN_TRIG_MON);               %Set the function for checking the current monitored input a trigger.
moto.set_trig_type = ...
    @(int)v2p0_send_uint8(serialcon,s.SET_TRIG_TYPE,int,0);                 %Set the function for setting the trigger type.
moto.get_trig_type = ...
    @()v2p0_simple_return_uint8(serialcon,s.RETURN_TRIG_TYPE);              %Set the function for checking the current trigger type.
moto.set_trig_thresh = ...
    @(int)v2p0_send_int16(serialcon,s.SET_TRIG_THRESH,int,0);               %Set the function for setting the trigger threshold.
moto.get_trig_thresh = ...
    @()v2p0_simple_return_int16(serialcon,s.RETURN_TRIG_THRESH);            %Set the function for checking the current trigger threshold.


%% This function checks the status of the serial connection.
function output = v2p0_check_serial(serialcon)
if isa(serialcon,'serial') && isvalid(serialcon) && ...
        strcmpi(get(serialcon,'status'),'open')                             %Check the serial connection...
    output = 1;                                                             %Return an output of one.
    disp(['Serial port ''' serialcon.Port ''' is connected and open.']);    %Show that everything checks out on the command line.
else                                                                        %If the serial connection isn't valid or open.
    output = 0;                                                             %Return an output of zero.
    warning('CONNECT_MOTOTRAK:NonresponsivePort',...
        'The serial port is not responding to status checks!');             %Show a warning.
end


%% This function checks to see if the MotoTrak_Controller_V2_0 sketch is current running on the controller.
function output = v2p0_check_sketch(serialcon)
fwrite(serialcon,'A','uchar');                                              %Send the check sketch code to the controller.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if output == 123                                                            %If the Arduino returned the number 123...
    output = 1;                                                             %...show that the Arduino connection is good.
else                                                                        %Otherwise...
    output = 0;                                                             %...show that the Arduino connection is bad.
end


%% This function sends a byte command without an expected reply.
function v2p0_simple_command(serialcon,cmd)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.


%% This function sends a byte command and receives a single uint8 reply.
function output = v2p0_simple_return_uint8(serialcon,cmd)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 1 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 1                                            %If the controller replied...
    output = fread(serialcon,1,'uint8');                                    %Read the reply from the serial line as an unsigned 16-bit integer.
end


%% This function sends a byte command and receives a single uint16 reply.
function output = v2p0_simple_return_uint16(serialcon,cmd)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 2 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 2                                            %If the controller replied...
    output = fread(serialcon,1,'uint16');                                   %Read the reply from the serial line as an unsigned 16-bit integer.
end


%% This function sends a byte command and receives a single int16 reply.
function output = v2p0_simple_return_int16(serialcon,cmd)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 2 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 2                                            %If the controller replied...
    output = fread(serialcon,1,'int16');                                    %Read the reply from the serial line as an unsigned 16-bit integer.
end


%% This function sends a byte command with a single uint8 argument.
function v2p0_send_uint8(serialcon,cmd,int,dummy_bytes)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,int,'uint8');                                              %Send the uint8 argument.
for i = 1:dummy_bytes                                                       %Step through any dummy bytes.
    fwrite(serialcon,0,'uint8');                                            %Send a dummy byte to advance the command queue.
end


%% This function sends a byte command with a single uint16 argument.
function v2p0_send_uint16(serialcon,cmd,int,dummy_bytes)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,int,'uint16');                                             %Send the uint16 argument.
for i = 1:dummy_bytes                                                       %Step through any dummy bytes.
    fwrite(serialcon,0,'uint8');                                            %Send a dummy byte to advance the command queue.
end


%% This function sends a byte command with a single int16 argument.
function v2p0_send_int16(serialcon,cmd,int,dummy_bytes)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,int,'int16');                                              %Send the int16 argument.
for i = 1:dummy_bytes                                                       %Step through any dummy bytes.
    fwrite(serialcon,0,'uint8');                                            %Send a dummy byte to advance the command queue.
end


%% This function sends a byte command with a single uint16 argument and receives a single int16 reply.
function output = v2p0_send_uint8_return_int16(serialcon,cmd,int)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,int,'uint8');                                              %Send the uint8 value to the controller.
fwrite(serialcon,0,'uint16');                                               %Send a dummy uint16 value to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 2 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 2                                            %If the controller replied...
    output = fread(serialcon,1,'int16');                                    %Read the reply from the serial line as an unsigned 16-bit integer.
end


%% This function reads a uint16 out of the controller's EEPROM.
function output = v2p0_read_eeprom_uint16(serialcon,s,addr)     
fwrite(serialcon,s.READ_2BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,0,'uint16');                                               %Send a dummy uint16 value to the controller to push back the reply uint16.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 2 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 2                                            %If the controller replied...
    output = fread(serialcon,1,'uint16');                                   %Read the reply from the serial line as an unsigned 16-bit integer.
end


%% This function writes a uint16 to the controller's EEPROM.
function v2p0_write_eeprom_uint16(serialcon,s,addr,int)     
fwrite(serialcon,s.SAVE_2BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,int,'uint16');                                             %Send a dummy uint16 value to the controller to push back the reply uint16.


%% This function reads a uint16 out of the controller's EEPROM.
function output = v2p0_read_eeprom_uint32(serialcon,s,addr)     
fwrite(serialcon,s.READ_4BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,0,'uint32');                                               %Send a dummy uint32 value to the controller to push back the reply uint16.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration.
while serialcon.BytesAvailable < 4 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 4                                            %If the controller replied...
    output = fread(serialcon,1,'uint32');                                   %Read the reply from the serial line as an unsigned 32-bit integer.
end


%% This function writes a uint32 to the controller's EEPROM.
function v2p0_write_eeprom_uint32(serialcon,s,addr,int)     
fwrite(serialcon,s.SAVE_2BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,int,'uint32');                                             %Send a dummy uint16 value to the controller to push back the reply uint32.


%% This function saves a calibration float32 value in the EEPROM.
function v2p0_set_cal_float(serialcon,s,addr,i,val)                         
addr = addr + 8*i;                                                          %Set the corresponding calibration value EEPROM address for the specified device.
v2p0_write_eeprom_float32(serialcon,s,addr,val);                            %Call the function to write float32 to the EEPROM.  


%% This function retrieves a calibration float32 value from the EEPROM.
function output = v2p0_get_cal_float(serialcon,s,addr,i)                      
addr = addr + 8*i;                                                          %Set the corresponding calibration value EEPROM address for the specified device.
output = v2p0_read_eeprom_float32(serialcon,s,addr);                        %Call the function to read the float32 from the EEPROM.


%% This function reads a float32 out of the controller's EEPROM.
function output = v2p0_read_eeprom_float32(serialcon,s,addr)     
fwrite(serialcon,s.READ_4BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,0,'uint32');                                               %Send a dummy uint32 value to the controller to push back the reply float32.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration.
while serialcon.BytesAvailable < 4 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 4                                            %If the controller replied...
    bytes = fread(serialcon,4,'uint8');                                     %Read the reply from the serial line as a 4 unsigned bytes.
    output = double(typecast(uint8(bytes),'single'));                       %Cast the 4 unsigned bytes back into a floating-point number.
end


%% This function writes a float32 to the controller's EEPROM.
function v2p0_write_eeprom_float32(serialcon,s,addr,val)     
fwrite(serialcon,s.SAVE_4BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
bytes = typecast(single(val),'uint8');                                      %Cast the floating-point value to 4 unsigned bytes.
for i = 1:4                                                                 %Step through each byte.
    fwrite(serialcon,bytes(i),'uint8');                                     %Send the 32-bit floating point number to the controller.
end


%% This function reads a value from the isometric pull or the knob.
function output = v2p0_read_pull(serialcon,cmd)
if serialcon.UserData(2) == 1                                               %If the isometric pull is the primary device...
    index = 1;                                                              %Set the input index to 1.
else                                                                        %Otherwise...
    index = 6;                                                              %Set the input index to 6.
end
output = v2p0_send_uint8_return_int16(serialcon,cmd,index);                 %Set the function for reading the value on a loadcell.


%% This function enables/disables streaming.
function v2p0_stream_enable(serialcon,cmd,enable_val)
if enable_val > 0                                                           %If streaming is being enabled...
    v2p0_clear_stream(serialcon);                                           %Clear any bytes currently on the stream.
end
v2p0_send_uint8(serialcon,cmd,enable_val,0);                                %Call the function to set the streaming state on the controller.


%% This function sets the streaming period, converting a millisecond argument to microseconds.
function v2p0_set_stream_period(serialcon,cmd,stream_period)
stream_period = round(1000*stream_period);                                  %Convert the specified stream period from milliseconds to microseconds.
v2p0_send_uint16(serialcon,cmd,stream_period,0);                            %Set the function for setting the stream period.


%% This function sets the input for one index in the controller's stream.
function v2p0_set_stream_input(serialcon,s,index,input)     
stream_order = serialcon.UserData(2:7);                                     %Grab the current stream order.
stream_order(index) = input;                                                %Set the specified stream position to the specified source.
fwrite(serialcon,s.SET_STREAM_ORDER,'uint8');                               %Send the command to the controller.
fwrite(serialcon,stream_order,'uint8');                                     %Send the modified stream order back to the controller.
serialcon.UserData(1) = sum(stream_order ~= 0);                             %Save the number of streaming inputs in the serial connection's "UserData" property.
serialcon.UserData(2:7) = stream_order;                                     %Save the modified stream order back to the serial connection's "UserData" property.


%% This function sets the input for one index in the controller's stream.
function output = v2p0_get_stream_input(serialcon,s,index)     
fwrite(serialcon,s.RETURN_STREAM_ORDER,'uint8');                            %Send the command to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 6 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 6                                            %If the controller replied...
    stream_order = fread(serialcon,6,'uint8');                              %Read the reply from the serial line as unsigned 8-bit integer.
    output = stream_order(index);                                           %Return the current source from the specified stream position.
    serialcon.UserData(1) = sum(stream_order ~= 0);                         %Save the number of streaming inputs in the serial connection's "UserData" property.
    serialcon.UserData(2:7) = stream_order;                                 %Save the current stream order back to the serial connection's "UserData" property.
end


%% This function reads in the values from the data stream when streaming is enabled.
function output = v2p0_read_stream(serialcon)
N = serialcon.UserData(1) + 1;                                              %Grab the number of inputs and line count from the user data.

timeout = now + 0.05*86400;                                                 %Set the following loop to timeout after 50 milliseconds.
while serialcon.BytesAvailable == 0 && now < timeout                        %Loop until there's a reply on the serial line or there's 
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
output = [];                                                                %Create an empty matrix to hold the serial line reply.
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    try
        streamdata = fscanf(serialcon,'%d')';
        output(end+1,:) = streamdata(1:N(1));                               %Read each byte and save it to the output matrix.
    catch err                                                               %If there was a stream read error...
        warning('MOTOTRAK:StreamingError',['MOTOTRAKSTREAM READ '...
            'WARNING: ' err.identifier]);                                   %Show that a stream read error occured.
    end
end


% if N(2) > 0                                                                 %If there's at least one line to grab...
%     output = nan(N(2),N(1)+1);                                              %Pre-allocate a matrix to hold the output.
%     for i = 1:N(2)                                                          %Step through all available lines.
%         try
%             output(i,:) = fscanf(serialcon,'%d')';                          %Read each byte and save it to the output matrix.
%         catch err                                                           %If there was a stream read error...
%             warning('MOTOTRAK:StreamingError',['MOTOTRAKSTREAM READ '...
%                 'WARNING: ' err.identifier]);                               %Show that a stream read error occured.
%         end
%     end
%     serialcon.UserData(2) = serialcon.UserData(2) - N(2);                   %Reset the line counter.
% else                                                                        %Otherwise...
%     output = [];                                                            %Output an empty matrix.
% end

% %The following comment section streams using Serial.write on the Arduino,
% %but it didn't significantly improve streaming speed, so Serial.print is
% %used for better backwards compatibility.
% ln_bytes = 4 + 2*num_inputs;                                                %Calculate the number of bytes per line.
% N = fix(serialcon.BytesAvailable/ln_bytes);                                 %Check how many lines are available.
% if N == 0                                                                   %If no complete lines are available...
%     output = [];                                                            %Return empty brackets.
% else                                                                        %Otherwise...
%     output = zeros(N, num_inputs + 1);                                      %Pre-allocate an output matrix.
%     for i = 1:N                                                             %Step through the available lines.
%         output(i,1) = fread(serialcon,1,'uint32');                          %Read in the sample timestamp.
%         for j = 1:num_inputs                                                %Step through the streaming inputs.
%             output(i,j+1) = fread(serialcon,1,'int16');                     %Read in each input sample.
%         end
%     end
% end


%% This function clears any remaining values from the serial line.
function v2p0_clear_stream(serialcon)
timeout = now + 50/86400000;                                                %Set the reply timeout duration (50 milliseconds).
while serialcon.BytesAvailable == 0 && now < timeout                        %Loop for the timeout duration or until there's bytes available on the serial line.
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    fread(serialcon,1,'uint8');                                             %Read each byte and discard it.
end
% serialcon.UserData(2) = 0;                                                  %Reset the line counter.


%% This function sets the PWM output value of the cage lights.
function v2p0_set_cage_lights(serialcon,s,pwm_val)
pwm_val = round(255*pwm_val);                                               %Convert the input value to an integer from 0 to 255.
if pwm_val > 255                                                            %If the PWM value is greater than 255..
    pwm_val = 255;                                                          %Set the PWM value to 255.
elseif pwm_val < 0                                                          %If the PWM value is less than 0...
    pwm_val = 0;                                                            %Set the PWM value to 0.
end
fwrite(serialcon,s.SET_CAGE_LIGHTS,'uint8');                                %Send the command to the controller.
fwrite(serialcon,pwm_val,'uint8');                                          %Send the PWM value to the controller.


% %% This function is called whenever the serial line receiveds a line feed terminator.
% function v2p0_serial_line_counter(serialcon,~,~)
% serialcon.UserData(2) = serialcon.UserData(2) + 1;                          %Increment the line counter.


%% ***********************************************************************
function handles = MotoTrak_Default_Config(varargin)

%
%MotoTrak_Default_Config.m - Vulintus, Inc.
%
%   MotoTrak_Default_Config sets the default values of all program
%   parameters when MotoTrak is launched.
%   
%   UPDATE LOG:
%   10/12/2016 - Drew Sloan - Added a default recipient for automatic error
%       reporting through email.
%   10/03/2017 - Drew Sloan - Replaced the 'handles' input with a variable
%       input argument term to handle unexpected function uses.
%
%   10/

if nargin > 0                                                               %If there's at least one optional input argument...
    handles = varargin{1};                                                  %An existing handles structure is the first expected argument.
else                                                                        %Otherwise...
    handles = struct([]);                                                   %Create a new, empty handles structure.
end

handles.custom = 'none';                                                    %Set the customization field to 'none' by default.
handles.stage_mode = 2;                                                     %Set the default stage selection mode to 2 (1 = local TSV file, 2 = Google Spreadsheet).
handles.stage_url = ['https://docs.google.com/spreadsheets/d/1Iii9Z'...
    'pXjJIm3z1xA1R9iSh3Vkjp00erUD8g6KPU_0Uk/pub?output=tsv'];               %Set the google spreadsheet address.
handles.stim = 0;                                                           %Disable stimulation by default.
handles.pre_trial_sampling = 1;                                             %Set the pre-trial sampling period, in seconds.
handles.post_trial_sampling = 2;                                            %Set the post-trial sampling period, in seconds.
handles.positioner_offset = 48;                                             %Set the zero position offset of the autopositioner, in millimeters.
handles.datapath = 'C:\MotoTrak\';                                          %Set the primary local data path for saving data files.
handles.ratname = [];                                                       %Create a field to hold the rat's name.
handles.sound_stages = [];                                                  %Create a field for marking stages with beeps.
handles.enable_error_reporting = 1;                                         %Enable automatic error reports by default.
handles.err_rcpt = 'drew@vulintus.com';                                     %Automatically send any error reports to Drew Sloan.
handles.ir_initiation_threshold = 0.20;                                     %Set the IR initiation threshold, as a proportion of the total range.
handles.ir_detector = 'bounce';                                             %Set the IR polarity ("bounce" or "beam");
handles.init_trig = 'off';                                                  %Turn on/off the trial initiation trigger signal.


%% ***********************************************************************
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


%% ***********************************************************************
function MotoTrak_Display_Trial_Results(handles,session,trial)

%
%MotoTrak_Display_Trial_Results.m - Vulintus, Inc.
%
%   MOTOTRAK_DISPLAY_TRIAL_RESULTS plots trial data to the MotoTrak GUI's
%   hit rate and session performance axes, and shows trial results as text
%   in the messagebox.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial results plotting section from MotoTrak_Behavior_Loop.m.
%

%Display the trial results in the messagebox.
switch handles.curthreshtype                                                %Switch between the types of hit threshold.
    case {'presses', 'fullpresses'}                                         %If the threshold type was the number of presses...       
        str = sprintf('%s - Trial %1.0f - %s: %1.0f presses.',...
            datestr(now,13), trial.num, trial.score,...
            numel(trial.peak_vals));                                        %Show the user the number of presses that occurred within the hit window.       

    case 'grams (peak)'                                                     %If the threshold type was the peak force...  
        if isempty(trial.peak_vals)                                         %If there's no peak values.
            trial.peak_vals = 0;                                            %Set the peak value to zero.
        end
        str = sprintf('%s - Trial %1.0f - %s: %1.0f grams.',...
            datestr(now,13), trial.num, trial.score,...
            max(trial.peak_vals));                                          %Then show the user the peak force used by the rat within the trial.      

    otherwise                                                               %For all other threshold types...
        str = sprintf('%s - Trial %1.0f - %s', datestr(now,13),...
            trial.num, trial.score);                                        %Show the user the trial results.
end
Add_Msg(handles.msgbox,str);                                                %Display the message on the GUI messagebox.

%Plot the current hitrate on the hit rate axes.
cla(handles.hitrate_ax);                                                    %Clear the hit rate axes.    
if size(session.hit_log,1) == 1                                             %If there's only one trial.
    x = session.hit_log(1,1) + [-1,1]/1440;                                 %Create x coordinates for an areaseries plot.
    y = session.hit_log(1,2)*[1,1];                                         %Create y coordinates for an areaseries plot.
else                                                                        %Otherwise, if there's more than one trial.
    x = session.hit_log(:,1);                                               %Use the timestamps as x coordinates.
    y = session.hit_log(:,2);                                               %Grab all of hit/miss values for y coordinates.
    for i = numel(y):-1:2                                                   %Step backwards through all of the trials.
        y(i) = mean(y(1:i));                                                %Set each point equal to the session hit rate at each trial.
    end
end
c = [0.5*(1 - y(end)) + 0.5, 0.5*y(end) + 0.5, 0.5];                        %Set the areaseries color.
area(x,y,'facecolor',c,...
    'facealpha',0.8,...
    'parent',handles.hitrate_ax);                                           %Plot the hitrate as an areaseries.
ylim(handles.hitrate_ax,[-0.1,1.1]);                                        %Set the y-axis limits.
x = [x(1), x(end)] + [-0.1,0.05]*(x(end) - x(1));                           %Calculate x-axis limits.
if x(2) - x(1) < 2/1440                                                     %If the span of the data is less than two minutes...
    temp = 2/1440 - (x(2) - x(1));                                          %Calculate the difference between the time shown and 2 minutes.
    x = x + [-1,1]*temp/2;                                                  %Add that amount of time equally to each end of the timespan.
end
xlim(handles.hitrate_ax,x);                                                 %Set the x-axis limits.
set(handles.hitrate_ax,'ytick',0:0.2:1,'xtick',[]);                         %Set the x- and y-ticks.    
if x(2) - x(1) < 5/1440                                                     %If the session duration is currently less than 5 minutes...
    step_size = 1440/1;                                                     %Use 1 minute steps.        
elseif x(2) - x(1) < 10/1440                                                %If the session duration is currently less than 10 minutes...
    step_size = 1440/2;                                                     %Use 2 minute steps.   
elseif x(2) - x(1) < 30/1440                                                %If the session duration is currently less than 30 minutes...
    step_size = 1440/5;                                                     %Use 5 minute steps.   
elseif x(2) - x(1) < 60/1440                                                %If the session duration is currently less than 60 minutes...
    step_size = 1440/10;                                                    %Use 10 minute steps.   
else                                                                        %Otherwise...
    step_size = 1440/60;                                                    %Use 60 minute steps.   
end
t = fix((step_size*x(1)):1:(step_size*x(2)))/step_size;                     %Calculate time step ticks.
t(t < x(1) + 0.1*(x(2) - x(1)) | t > x(1) + 0.95*(x(2) - x(1))) = [];       %Kick out tick marks at the edges.
for i = 1:length(t)                                                         %Step through each tick mark.
    txt = text(t(i),0.5,datestr(t(i),'HH:MM'),...
        'horizontalalignment','center',...
        'verticalalignment','middle',...
        'fontsize',12,...
        'backgroundcolor','w',...
        'rotation',90,...
        'parent',handles.hitrate_ax);                                       %Label each tick line.
    uistack(txt,'bottom');                                                  %Send the line to the bottom of the stack.
    ln = line([1,1]*t(i),[-0.1,1.1],...
        'color','k',...
        'linestyle','--',...
        'linewidth',0.5,...
        'parent',handles.hitrate_ax);                                       %Plot a tick line.
    uistack(ln,'bottom');                                                   %Send the line to the bottom of the stack.
end
for i = 0:0.2:1                                                             %Step through the y-ticks.
    ln = line(x,i*[1,1],...
        'color','k',...
        'linestyle','--',...
        'linewidth',0.5,...
        'parent',handles.hitrate_ax);                                       %Plot a tick line.
    uistack(ln,'bottom');                                                   %Send the line to the bottom of the stack.
    text(x(1) + 0.01*(x(2) - x(1)),i,sprintf('%1.0f%%',100*i),...
        'horizontalalignment','left',...
        'verticalalignment','middle',...
        'fontsize',8,...
        'backgroundcolor','w',...
        'parent',handles.hitrate_ax);                                       %Label each tick line.
end


%% ***********************************************************************
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


%% ***********************************************************************
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


%% ***********************************************************************
function MotoTrak_Enable_All_Uicontrols(handles)

%
%MotoTrak_Enable_All_Uicontrols.m - Vulintus, Inc.
%
%   MotoTrak_Enable_All_Uicontrols enables all of the uicontrol and uimenu
%   objects that should  be active while MotoTrak is idling between
%   behavioral sessions.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added enabling of the stages top menu.
%   10/13/2016 - Drew Sloan - Added enabling of the stages top menu.
%   10/28/2016 - Drew Sloan - Changed if statements to switch-case.
%

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

switch handles.device                                                       %Switch between the recognized devices.
    case 'knob'                                                             %If the current input device is a knob...
        temp = [0.9 0.7 0.9];                                               %Set the label color to a light red.
    case 'pull'                                                             %If the current input device is a pull...
        temp = [0.7 0.9 0.7];                                               %Set the label color to a light green.
    case 'lever'                                                            %If the current input device is a lever...
        temp = [0.7 0.7 0.9];                                               %Set the label color to a light red.
    case 'wheel'                                                            %If the current input device is a wheel...
        temp = [0.9 0.9 0.7];                                               %Set the label color to a light yellow.
    case 'touch'                                                            %If the current input device is a capacitive touch sensor...
        temp = [0.9 0.7 0.9];                                               %Set the label color to a light magenta.
    case 'both'                                                             %If the current input device is a capacitive touch sensor...
        temp = [0.7 0.9 0.9];                                               %Set the label color to a light cyan.
    otherwise                                                               %Otherwise, for any unrecognized device...
        temp = [0.7 0.7 0.7];                                               %Set the label color to a neutral gray.
end
set(handles.label,'backgroundcolor',temp);                                  %Set the background color of all label editboxes.    
if handles.stim == 1                                                        %If stimulation is turned on...
    set(handles.popvns,'foregroundcolor',[1 0 0]);                          %Make the "ON" text red.
elseif handles.stim == 2                                                    %Otherwise, if stimulation is randomly presented...
    set(handles.popvns,'foregroundcolor',[0 0 1]);                          %Make the "RANDOM" text blue.
else                                                                        %Otherwise, if VNS is turned OFF...
    set(handles.popvns,'foregroundcolor','k');                              %Make the "ON" text black.
end

%Enable the top menu options.
set(handles.menu.stages.h,'enable','on');                                   %Enable the stages menu.
set(handles.menu.stages.view_spreadsheet,'enable','on');                    %Enable the "Open Spreadsheet" menu option.
set(handles.menu.stages.set_load_option,'enable','on');                     %Enable the stage-loading selection.
set(handles.menu.pref.h,'enable','on');                                     %Enable the preferences menu.
set(handles.menu.cal.h,'enable','on');                                      %Enable the calibration menu.
switch handles.device                                                       %Switch between the available MotoTrak devices...
    case {'pull','both','touch'}                                            %If the current device is the pull...
        set(handles.menu.cal.open_calibration,'enable','on');               %Enable "Open Calibration" selection.
        set(handles.menu.cal.reset_baseline,'enable','on');                 %Enable "Reset Baseline" selection.
    case 'knob'                                                             %If the current device is the knob...
        set(handles.menu.cal.reset_baseline,'enable','on');                 %Enable "Reset Baseline" selection.
    case 'lever'                                                            %If the current device is the lever...
        set(handles.menu.cal.open_calibration,'enable','on');               %Enable "Open Calibration" selection.
end


%% ***********************************************************************
function MotoTrak_Enable_Controls_Outside_Session(handles)

%
%MotoTrak_Enable_Controls_Outside_Session.m - Vulintus, Inc.
%
%   This function enables all of the uicontrol and uimenu objects that 
%   should be active when MotoTrak is not running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added enabling of uimenu objects.
%   10/13/2016 - Drew Sloan - Added disabling of the preferences menu.
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
set(handles.menu.pref.h,'enable','on');                                     %Enable the preferences menu.
set(handles.menu.cal.h,'enable','on');                                      %Enable the calibration menu.


%% ***********************************************************************
function [device, index] = MotoTrak_Identify_Device(val)

%
%MotoTrak_Identify_Device.m - Vulintus, Inc.
%
%   This function identifies the behavioral module attached to the MotoTrak
%   system based on the analog identifier returned from the module.
%   
%   UPDATE LOG:
%   12/31/2018 - Drew Sloan - Added the water reaching module.
%

if val < 20                                                                 %If the device-identifier value is less than ~0.1V...
    device = 'none';                                                        %There is no device connected.
    index = 0;                                                              %Set the index to 0.
elseif val >= 20 && val < 100                                               %If the device-identifier value is between ~0.1V and ~0.5V...
    device = 'lever';                                                       %The device is the lever (1.5 MOhm resistor).
    index = 1;                                                              %Set the index to 1.
elseif val >= 100 && val < 200                                              %If the device-identifier value is between ~0.5V and ~1.0V...
    device = 'knob';                                                        %The device is the knob (560 kOhm resistor).
    index = 2;                                                              %Set the index to 2.
elseif val >= 200 && val < 300                                              %If the device-identifier value is between ~1.0V and ~1.5V...
    device = 'knob';                                                        %The device is the knob (270 kOhm resistor).
    index = 2;                                                              %Set the index to 2.
elseif val >= 300 && val < 400                                              %If the device-identifier value is between ~1.5V and ~2.0V...
    device = 'knob';                                                        %The device is the knob (200 kOhm resistor).
    index = 2;                                                              %Set the index to 2.
elseif val >= 400 && val < 500                                              %If the device-identifier value is between ~2.0V and ~2.5V...
    device = 'pull';                                                        %The device is the pull (130 kOhm resistor).
    index = 6;                                                              %Set the index to 6.
elseif val >= 500 && val < 600                                              %If the device-identifier value is between ~2.5V and ~3.0V...
    device = 'pull';                                                        %The device is the pull (85 kOhm resistor).
    index = 6;                                                              %Set the index to 6.
elseif val >= 600 && val < 700                                              %If the device-identifier value is between ~3.0V and ~3.5V...
    device = 'pull';                                                        %The device is the pull (57 kOhm resistor).
    index = 6;                                                              %Set the index to 6.
elseif val >= 700 && val < 800                                              %If the device-identifier value is between ~3.5V and ~4.0V...
    device = 'water';                                                       %The device is the pull (36 kOhm resistor).
    index = 8;                                                              %Set the index to 6.
elseif val >= 800 && val < 900                                              %If the device-identifier value is between ~4.0V and ~4.5V...
    device = 'lever';                                                       %The device is the lever (20 kOhm resistor).
    index = 1;                                                              %Set the index to 1.
elseif val >= 900 && val < 1000                                             %If the device-identifier value is between ~4.5V and ~5.0V...
    device = 'knob';                                                        %The device is the knob (8 kOhm resistor).
    index = 2;                                                              %Set the index to 2.
elseif val >= 1000                                                          %If the device-identifier value is greather than ~5.0V...
    device = 'knob';                                                        %The device is the knob (wire jumper).
    index = 2;                                                              %Set the index to 2.
end


%% ***********************************************************************
function MotoTrak_Idle(fig)

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
%   10/13/2016 - Drew Sloan - Added automatic error reporting for the
%       final try/catch statement.
%   01/09/2017 - Drew Sloan - Changed the values expected from the global
%       run variable for triggering events during idle.
%   04/27/2018 - Drew Sloan - Fixed the "FEED" button callback so that
%       feeding triggers can be delivered during idle.
%   12/31/2018 - Drew Sloan - Added plot handling for the water reaching
%       module.
%

global run                                                                  %Create the global run variable.

handles = guidata(fig);                                                     %Grab the handles structure from the main GUI.

set(handles.startbutton,'string','START',...
   'foregroundcolor',[0 0.5 0],...
   'callback','global run; run = 2;')                                       %Set the string and callback for the Start/Stop button.
set(handles.feedbutton,'callback','global run; run = 1.3;')                 %Set the callback for the Manual Feed button.
            
p = [0,0];                                                                  %Create a matrix to hold plot handles.
ln = [0,0];                                                                 %Create a matrix to hold line object handles.
txt = [0,0];                                                                %Create a matrix to hold text object handles.
[p(1), ln(1), txt(1)] = ...
    MotoTrak_Idle_Initialize_Plots(handles.primary_ax);                     %Create plots on the primary axes for the main sensor signal.
set(p(1),'facecolor',[0.5 0.5 1]);                                          %Color the primary signal plot light blue.
[p(2), ln(2), txt(2)] = ...
    MotoTrak_Idle_Initialize_Plots(handles.secondary_ax);                   %Create plots on the secondary axes for the secondary sensor signal.
set(p(2),'facecolor',[1 0.5 0.5]);                                          %Color the secondary signal plot light red.

ir_minmax = [1023, 0];                                                      %Create a matrix to hold the minimum and maximum IR sensor values.

ceiling_ln = line([1,1],[1,1],...
    'color','k',...
    'linestyle',':',...
    'visible','off',...
    'parent',handles.primary_ax);                                           %Plot a dotted line to show the ceiling on the primary plot.
ceiling_txt = text(1,1,'Ceiling',...
    'horizontalalignment','right',...
    'verticalalignment','bottom',...
    'fontsize',8,...
    'fontweight','bold',...
    'visible','off',...
    'parent',handles.primary_ax);                                           %Create text to label the the ceiling line on the primary plot.

tabs = get(handles.plot_tab_grp.Children,'title');                          %Grab the plot tab titles.

handles.ardy.clear();                                                       %Clear any residual values from the serial line.
run = 1.2;                                                                  %Set the run variable to 1.2 to create the plot variables.

while fix(run) == 1                                                         %Loop until the user starts a session, runs the calibration, or closes the program.
    
    if run == 1.1                                                           %If the user has selected a new stage...
        handles = guidata(fig);                                             %Grab the handles structure from the main GUI.
        i = get(handles.popstage,'value');                                  %Grab the value of the stage select pop-up menu.
        handles.must_select_stage = 0;                                      %Set a flag indicating that the user has properly selected a stage.        
        if i ~= handles.cur_stage                                           %If the selected stage is different from the current stage.
            handles.cur_stage = i;                                          %Set the current stage to the selected stage.
            handles = MotoTrak_Load_Stage(handles);                         %Load the new stage parameters. 
        end
        guidata(handles.mainfig,handles);                                   %Re-pin the handles structure to the main figure.
        if ~isempty(handles.ratname)                                        %If the user's already selected a stage...
            set(handles.startbutton,'enable','on');                         %Enable the start button.
        end
        run = 1.2;                                                          %Set the run variable to 1.2 to create the plot variables.
    end
    
    if run == 1.2                                                           %If new plot variables must be created...
        handles.ardy.stream_enable(0);                                      %Disable streaming on the Arduino.
        buffsize = round(5000*handles.hitwin/handles.period);               %Specify the size of the data buffer, in samples.        
        hit_samples = round(1000*handles.hitwin/handles.period);            %Find the number of samples in the hit window.
        if strcmpi(handles.device,'both')                                   %If the current device is the combined touch-pull sensor...
            if buffsize > 1000                                              %If there's more than 1000 samples in the buffer...
                buffsize = 1000;                                            %Set the buffer size to 1000.
                hit_samples = 200;                                          %Set the hit samples to 200.
            end
        end
        data = zeros(buffsize,3);                                           %Create a matrix to buffer the stream data.
        MotoTrak_Set_Stream_Params(handles);                                %Update the streaming properties on the Arduino.   
        handles.ardy.clear();                                               %Clear any residual values from the serial line.            
        signal = zeros(buffsize,2);                                         %Create a matrix to hold the monitored signal.
        thresh = [handles.threshmin, NaN];                                  %Create a matrix to hold the threshold.
        minmax_y = nan(2,2);                                                %Create a matrix to hold the maximum y-value.
        if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                %If a ceiling is set for this stage...
            minmax_y(1,:) = [-0.1,1.3]*handles.ceiling;                     %Set the initial y-axis limits according to the ceiling value
            set(ceiling_ln,'xdata',[1,buffsize],...
                'ydata',handles.ceiling*[1,1],...                
                'visible','on');                                            %Update the ceiling-marking line.
            set(ceiling_txt,'position',[0.99*buffsize, handles.ceiling],...
                'visible','on');                                            %Update the position of the threshold label.
        else                                                                %Otheriwse, if there is no ceiling set for this stage.
            set([ceiling_ln, ceiling_txt],'visible','off');                 %Make the ceiling line and text invisible.
            minmax_y(1,:) = [-0.1,1.3]*thresh(1);                           %Set the initial primary y-axis limits according to the threshold value.
        end
        switch lower(handles.device)                                        %Switch between the various devices.
            case {'touch', 'both'}                                          %For the touch sensor...
                thresh(2) = 511.5;                                          %Set the minimum threshold to half of the analog range.
                minmax_y(2,:) = [0, 1100];                                  %Set the y-axis limits for the secondary plots.
            case 'water'                                                    %For the water reach module...
                thresh(:) = 511.5;                                          %Set both thresholds to half of the analog range.
                minmax_y = [0, 1100; 0, 1100];                              %Set the y-axis limits for both the primary and secondary plots.                
        end
        set(p(1),'xdata',(1:buffsize)','ydata',signal(:,1));                %Zero the primary signal area plot.
        set(p(2),'xdata',(1:buffsize)','ydata',signal(:,2));                %Zero the secondary signal area plot.        
        set(ln,'xdata',[1,buffsize],'visible','on');                        %Set the x-coordinates for both threshold lines.
        set(ln(1),'ydata',thresh(1)*[1,1]);                                 %Set the y-coordinates for the primary signal threshold line.
        set(txt(1),'position',[0.99*buffsize, thresh(1)],...
            'visible','on');                                                %Update the position of the primary threshold label.
        if ~isnan(thresh(2))                                                %If there's a secondary signal threshold line...
            set(ln(2),'ydata',thresh(2)*[1,1],'visible','on');               %Set the y-coordinates for the secondary signal threshold line.
            set(txt(2),'position',[0.99*buffsize, thresh(2)],...
            'visible','on');                                                %Update the position of the secondary threshold label.
        else                                                                %Otherwise...
            set(ln(2),'visible','off');                                     %Make the threshold line invisible.
        end        
        ylim(handles.primary_ax,minmax_y(1,:));                             %Set the y-axis limits for the primary plots.
        if ~any(isnan(minmax_y(2,:)))                                       %If values were set for the secondary plot y-axis limits...
            ylim(handles.secondary_ax,minmax_y(2,:));                       %Set the y-axis limits for the secondary plots.
        end
        xlim(handles.primary_ax,[1,buffsize]);                              %Set the primary x-axis limits according to the buffersize.
        xlim(handles.secondary_ax,[1,buffsize]);                            %Set the primary x-axis limits according to the buffersize.
        set([handles.primary_ax,handles.secondary_ax],'ytickmode','auto');  %Set the y-tick mode to auto for the both axes.
        ticks = {[NaN,NaN],[NaN,NaN]};                                      %Create a cell array to hold tick label handles.
        cal(1) = handles.slope;                                             %Set the calibration slope for the device.
        cal(2) = handles.baseline;                                          %Set the calibration baseline for the device.
        handles.ardy.stream_enable(1);                                      %Re-enable periodic streaming on the Arduino.        
        do_once = 0;                                                        %Reset the checker variable to zero out the signal before the first stream read.
        run = 1;                                                            %Set the run variable back to 1.
    end
    
    if run == 1.3                                                           %If the user pressed the manual feed button...     
        handles.ardy.trigger_feeder(1);                                     %Trigger feeding on the Arduino.
        Add_Msg(handles.msgbox,[datestr(now,13) ' - Manual Feeding.']);     %Show the user that the session has ended.
        run = 1;                                                            %Set the run variable back to 1.
    end
    
    if run == 1.4                                                           %If the user wants to reset the baseline...
        handles = guidata(fig);                                             %Grab the current handles structure from the main GUI.
        N = fix(buffsize/5);                                                %Find the number of samples in the last 1/5th of the existing signal.
        temp = (data(end-N+1:end,2)/cal(1)) + cal(2);                       %Convert the buffered data back to the uncalibrated raw values.
        handles.baseline = mean(temp);                                      %Set the baseline to the average of the last 100 signal samples.
        cal(2) = handles.baseline;                                          %Set the calibration baseline for the device.
        guidata(fig,handles);                                               %Pin the updated handles structure back to the GUI.
        if any(strcmpi(handles.device,{'pull','lever'}))                    %If the current device is the pull or the lever...
            if handles.ardy.version < 2.00                                  %If the controller microcode version is less than 2.00...
                if cal(1) > 1                                               %If the slope of the line is greater than 1...
                    b = 32767;                                              %Set the calibration force to a maximum 16-bit integer.
                    a = round(b/cal(1));                                    %Calculate the sensor reading that would correspond to that force.
                else                                                        %Otherwise, if the slope of the line is less than 1...
                    a = 32767;                                              %Set the calibration loadcell reading to a maximum 16-bit integer.
                    b = round(cal(1)*a);                                    %Calculate the calibration force that would yield such a sensor reading.
                end
                handles.ardy.set_baseline(cal(2));                          %Save the baseline value in the EEPROM on the Arduino board.
                handles.ardy.set_n_per_cal_grams(a);                        %Save the maximum sensor reading on the EEPROM.
                handles.ardy.set_cal_grams(b);                              %Save the maximum calibration force on the EEPROM.
            else                                                            %Otherwise...
                handles.ardy.set_baseline_float(handles.d_index,cal(2));    %Save the baseline as a float in the EEPROM address for the current module.
                handles.ardy.set_slope_float(handles.d_index,cal(1));       %Save the slope as a float in the EEPROM address for the current module.
            end
        end
        if handles.ardy.version >= 2.00 && ...
                handles.stage(handles.cur_stage).tones_enabled == 1         %If tones are enabled for this stage...
            MotoTrak_Set_Tone_Parameters(handles);                          %Call the function to update the tone parameters.
        end
        run = 1;                                                            %Set the run variable back to 1.
    end
    
    new_data = handles.ardy.read_stream();                                  %Read in any new stream output.     
    N = size(new_data,1);                                                   %Find the number of new samples.
    if N > 0                                                                %If there was any new data in the stream.     
        
        new_data(:,2) = cal(1)*(new_data(:,2) - cal(2));                    %Apply the calibration constants to the primary data signal.        
        data(1:end-N,:) = data(N+1:end,:);                                  %Shift the existing buffer samples to make room for the new samples.
        data(end-N+1:end,:) = new_data;                                     %Add the new samples to the buffer.
        
        signal(1:end-N,:) = signal(N+1:end,:);                              %Shift the existing samples in the monitored to make room for the new samples.
        if do_once == 0                                                     %If this was the first stream read...                     
            signal(:,1) = data(end,2);                                      %Fill the primary signal with the last value of the data buffer.
            switch handles.curthreshtype                                    %Switch between the types of signal thresholds.  
                case {'milliseconds/grams','water reach (shaping)'}          %If the current threshold type is the combined touch-pull...
                    signal(:,2) = data(end,3);                              %Fill the secondary signal with the last value of the data buffer.
                otherwise                                                   %Otherwise, for all other threshold types.
                    signal(:,2) = 1023 - data(end,3);                       %Fill the secondary signal with the inverse of the last value of the data buffer.
            end
            data(1:buffsize-N,2) = data(buffsize-N+1,2);                    %Set all of the preceding primary data points equal to the first point.
            data(1:buffsize-N,3) = data(buffsize-N+1,3);                    %Set all of the preceding secondary data points equal to the first point.            
            do_once = 1;                                                    %Set the checker variable to 1.
        end
        
        i = buffsize-N+1:buffsize;                                          %Grab the indices for the new samples.        
        switch handles.curthreshtype                                        %Switch between the types of signal thresholds.                      
            case {'presses', 'fullpresses'}                                 %If the threshold type is the number of presses or the number of full presses...
                if strcmpi(handles.device,'knob')                           %If the current device is the knob...
                    signal(i,1) = data(i,2) - data(i-hit_samples+1,2);      %Find the change in the degrees integrated over the hit window.
                else                                                        %Otherwise, if the current device is the lever...
                    signal(i,1) = data(i,2);                                %Transfer the new samples to the signal as-is.
                end
            case {'grams (peak)', 'grams (sustained)'}                      %If the current threshold type is the peak pull force or sustained pull force.
                if strcmpi(handles.stage(handles.cur_stage).number,...
                        'PASCI1')                                           %If the current stage is PASCI1...
                    signal(i,1) = abs(data(i,2));                           %Convert the new samples to absolute values.
                else                                                        %Otherwise, for all other stages...
                    signal(i,1) = data(i,2);                                %Transfer the new samples to the signal as-is.
                end
            case 'milliseconds/grams'                                       %If the current threshold type is the combined touch-pull...
                signal(i,1) = data(i,2);                                    %Transfer the new samples to the signal as-is.
            otherwise                                                       %Otherwise, for all other threshold types.
                signal(i,1) = data(i,2);                                    %Transfer the new samples to the signal as-is.
        end        
        switch handles.curthreshtype                                        %Switch between the types of signal thresholds.  
            case {'milliseconds/grams', 'water reach (shaping)'}            %If the current threshold type is the combined touch-pull...
                signal(i,2) = data(i,3);                                    %Transfer the new secondary samples to the signal as-is.
                ir_minmax = [0, 1023];                                      %Set the secondary signal minimum and maximum to the outermost possible values.
            otherwise                                                       %Otherwise, for all other threshold types.
                signal(i,2) = 1023 - data(i,3);                             %Invert the secondary signal samples.                
                ir_minmax(1) = min([ir_minmax(1); signal(:,2)]);            %Check for a new secondary signal minimum.
                ir_minmax(2) = max([ir_minmax(2); signal(:,2)]);            %Check for a new secondary signal maximum.
                thresh(2) = handles.ir_initiation_threshold*...
                    (ir_minmax(2) - ir_minmax(1)) + ir_minmax(1);           %Recalculate the secondary threshold.
        end

        cur_tab = handles.plot_tab_grp.SelectedTab.Title;                   %Grab the currently selected tab title.
        i = strcmpi(cur_tab,tabs);                                          %Find the index for the currently selected tab.
        if i(1) == 1                                                        %If the primary tab is selected...
            set(p(1),'ydata',signal(:,1));                                  %Update the area plot.
            set(txt(1),'verticalalignment','top');                          %Set the threshold text to align along its bottom.
            if ~isnan(handles.ceiling) && handles.ceiling ~= Inf            %If a ceiling is set for this stage...
                minmax_y(1,:) = ...
                    [min([1.1*min(signal(:,1)), -0.1*handles.ceiling]),...
                    max([1.1*max(signal(:,1)), 1.3*handles.ceiling])];      %Calculate new y-axis limits.
            else                                                            %Otherwise...
                minmax_y(1,:) = ...
                    [min([1.1*min(signal(:,1)), -0.1*thresh(1)]),...
                max([1.1*max(signal(:,1)), 1.3*thresh(1)])];                %Calculate new y-axis limits.  
            end      
            if minmax_y(1,1) == minmax_y(1,2)                               %If the top and bottom limits are the same...
                minmax_y(1,:) = minmax_y(1,1) + [-1,1];                     %Arbitrarily add one above and below the constant value.
            end
            if ~strcmpi(handles.device,'water')                             %If this isn't the water reaching module...
                ylim(handles.primary_ax,minmax_y(1,:));                     %Set the new y-axis limits.
                temp = get(txt(1),'extent');                                %Grab the position of the threshold label.
                if temp(2) < minmax_y(1,1)                                  %If the bottom edge of the text is outside the bounds...
                    set(txt(1),'verticalalignment','bottom');               %Align the text at its bottom.
                end
                temp_ticks = get(handles.primary_ax,'ytick')';              %Grab the current y-axis tick values.
                if ~isequal(ticks{1}(:,1),temp_ticks)                       %If the tick values have changed.
                    if ~isnan(ticks{1}(1,2))                                %If there are pre-existing tick values...
                        delete(ticks{1}(:,2));                              %Delete the tick label handles.
                    end
                    switch handles.curthreshtype                            %Switch between the types of signal thresholds.                      
                        case {'grams (peak)', 'grams (sustained)',...
                                'milliseconds/grams' }                      %If the current threshold type is any of the pull force variants.
                            units = ' g';                                   %Label the ticks with a grams unit.
                        otherwise                                           %Otherwise, for all other threshold types.
                            units = '\circ';                                %Label the ticks with a degree sign.
                    end      
                    ticks{1} = [temp_ticks, nan(size(temp_ticks))];         %Create a new matrix of tick values and handles.
                    for j = 1:numel(temp_ticks)                             %Step through each tick mark.
                        ticks{1}(j,2) = text(0.02*buffsize,temp_ticks(j),...
                            [num2str(temp_ticks(j)) units],...
                            'horizontalalignment','left',...
                            'verticalalignment','middle',...
                            'fontsize',8,...
                            'parent',handles.primary_ax);                   %Create tick labels at each tick mark.
                    end
                end
            end
        end
        if any(strcmpi(handles.curthreshtype,...
                {'milliseconds/grams','water reach (shaping)'})) || ...
                i(2) == 1                                                   %If the secondary tab is selected or it's a combined touch/pull stage...
            set(p(2),'ydata',signal(:,2),'basevalue',ir_minmax(1));         %Update the area plot.
            set(txt(2),'verticalalignment','top',...
                'position',[0.99*buffsize,thresh(2)]);                      %Set the position of the threshold label.
            set(ln(2),'ydata',thresh(2)*[1,1]);                             %Set the position of the threshold line.
            minmax_y(2,1) = ir_minmax(1)-0.1*(ir_minmax(2)-ir_minmax(1));   %Calculate the lower end of the y-axis limits.    
            minmax_y(2,2) = max([1.1*max(signal(:,2)), 1.3*thresh(2)]);     %Calculate the upper end of the y-axis limits.
            if minmax_y(2,1) == minmax_y(2,2)                               %If the top and bottom limits are the same...
                minmax_y(2,:) = [-1,1];                                     %Arbitrarily add one above and below the constant value.
            end
            ylim(handles.secondary_ax,minmax_y(2,:));                       %Set the new y-axis limits.
        end
    end
    
    if (handles.delay_autopositioning ~= 0 && ...
            now > handles.delay_autopositioning)                            %If an autopositioning delay is currently in force, but has now lapsed.
        temp = round(10*(handles.positioner_offset - 10*handles.position)); %Calculate the absolute position to send to the autopositioner.
        handles.ardy.autopositioner(temp);                                  %Set the specified position value.
        handles.delay_autopositioning = 0;                                  %Reset the autopositioning delay value to zero.
    end
    
    pause(0.01);                                                            %Pause for 10 milliseconds.
end

try                                                                         %Attempt to stop the signal streaming.
    handles.ardy.stream_enable(0);                                          %Disable streaming on the Arduino.
    handles.ardy.clear();                                                   %Clear any residual values from the serial line.
    Add_Msg(handles.msgbox,[datestr(now,13) ' - Idle mode stopped.']);      %Show the user that the session has ended.
catch err                                                                   %If an error occured while closing the serial line...
    cprintf([1,0.5,0],'WARNING: %s\n',err.message);                         %Show the error message as a warning.
    str = ['\t<a href="matlab:opentoline(''%s'',%1.0f)">%s '...
        '(line %1.0f)</a>\n'];                                              %Create a string for making a hyperlink to the error-causing line in each function of the stack.
    for i = 2:numel(err.stack)                                              %Step through each script in the stack.
        cprintf([1,0.5,0],str,err.stack(i).file,err.stack(i).line,...
            err.stack(i).name, err.stack(i).line);                          %Display a jump-to-line link for each error-throwing function in the stack.
    end
    txt = MotoTrak_Save_Error_Report(handles,err);                           %Save a copy of the error in the AppData folder.
    MotoTrak_Send_Error_Report(handles,handles.err_rcpt,txt);               %Send an error report to the specified recipient.    
end


%% This subfunction initializes the plots for the idle loop.
function [p, ln, txt] = MotoTrak_Idle_Initialize_Plots(ax)
p = area(1,1,...
    'linewidth',2,...
    'facecolor',[0.5 0.5 1],...
    'parent',ax);                                                           %Plot some dummy data to be overwritten as an areaseries plot.
ln = line([1,1],[1,1],...
    'color','k',...
    'linestyle',':',...
    'visible','off',...
    'parent',ax);                                                           %Plot a dotted line to show the threshold.
txt = text(1,1,'Threshold',...
    'horizontalalignment','right',...
    'verticalalignment','top',...
    'fontsize',8,...
    'fontweight','bold',...
    'visible','off',...
    'parent',ax);                                                           %Create text to label the the threshold line.
set(ax,'xtick',[],'ytick',[]);                                              %Get rid of the x- y-axis ticks.


%% ***********************************************************************
function trial = MotoTrak_Initialize_Trial_Plots(handles,session,trial)

%
%MotoTrak_Initialize_Trial_Plots.m - Vulintus, Inc.
%
%   MOTOTRAK_INITIALIZE_TRIAL_PLOTS resets the plots on the MotoTrak GUI to
%   switch from showing the pre-initialization signal to showing the saved
%   trial signals.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial plot sections from MotoTrak_Behavior_Loop.m.
%

cla(handles.primary_ax);                                                    %Clear the primary axes.

trial.plot_h(1) = area(1:session.buffsize,trial.signal,...
    'linewidth',2,...
    'facecolor',[0.5 0.5 1],...
    'parent',handles.primary_ax);                                           %Make an areaseries plot to show the trial signal.

hold(handles.primary_ax,'on');                                              %Hold the primary axes for multiple plots.
if any(strcmpi(handles.curthreshtype,{'# of spins','presses'}))             %If the threshold type is the number of spins or number of pressess...
    trial.plot_h(2) = plot(-1,-1,'*r','parent',handles.primary_ax);         %Mark the peaks with red asterixes.
end
hold(handles.primary_ax,'off');                                             %Release the plot hold.

if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                        %If a ceiling is set for this stage...
    trial.max_y = [min([1.1*min(trial.signal), -0.1*handles.ceiling]),...
        1.3*max([trial.signal; handles.ceiling])];                          %Calculate y-axis limits based on the ceiling.
else                                                                        %Otherwise, if there is no ceiling...
    trial.max_y = [min([1.1*min(trial.signal), -0.1*trial.thresh]),...
        1.3*max([trial.signal; trial.thresh])];                             %Calculate y-axis limits based on the hit threshold.
end        

str = sprintf('Trial %1.0f', trial.num);                                %   Create the string for a text object.
trial.trial_txt = text(1,trial.max_y(2),str,...
    'fontsize',12,...
    'fontweight','bold',...
    'horizontalalignment','left',...
    'verticalalignment','top',...
    'parent',handles.primary_ax);                                           %Create a text object to show the trial number.
    
if ~strcmpi(handles.curthreshtype,'# of spins')                             %If the threshold type isn't number of spins...
    x = [session.pre_samples,session.pre_samples + session.hit_samples];    %Set the x coordinates for a line to show the threshold.
    y = trial.thresh*[1,1];                                                 %Set the y coordinates for a line to show the threshold.
    line(x,y,...
        'color','k',...
        'linestyle',':',...
        'parent',handles.primary_ax);                                       %Plot a dotted line to show the threshold.
     text(x(1),y(1),'Hit Threshold',...
        'horizontalalignment','left',...
        'verticalalignment','top',...
        'fontsize',8,...
        'fontweight','bold',...
        'visible','off',...
        'parent',handles.primary_ax);                                       %Create text to label the the threshold line.
    
    if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                    %If this stage has a ceiling...
        x = [session.pre_samples, ...
            session.pre_samples + session.hit_samples];                     %Set the x coordinates for a line to show the ceiling.
        y = handles.ceiling*[1,1];                                          %Set the y coordinates for a line to show the ceiling.
        line(x,y,...
            'color','k',...
            'linestyle',':',...
            'parent',handles.primary_ax);                                   %Plot a dotted line to show the ceiling.
        text(x(1),y(1),'Ceiling',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'visible','off',...
            'parent',handles.primary_ax);                                   %Create text to label the the threshold line.
    end
end       

set(handles.primary_ax,'xtick',[],'ytick',[]);                              %Get rid of the x- y-axis ticks.

ylim(handles.primary_ax,trial.max_y);                                       %Set the new y-axis limits.
xlim(handles.primary_ax,[1,session.buffsize]);                              %Set the x-axis limits according to the buffersize.

x = session.pre_samples*[1,1];                                              %Set x coordinates for a line.
trial.ln = line(x,trial.max_y,...
    'color','k',...
    'parent',handles.primary_ax);                                           %Plot a line to show the start of the hit window.
x = (session.pre_samples+session.hit_samples)*[1,1];                        %Set x coordinates for a line.
trial.ln(2) = line(x,trial.max_y,...
    'color','k',...
    'parent',handles.primary_ax);                                           %Plot a line to show the end of the hit window.

% x = 0.02*session.buffsize;                                                  %Set the x position of the IR signal text.
% y = trial.max_y(2)-0.03*range(trial.max_y);                                 %Set the y position of the IR signal text.
% trial.ir_text = text(x,y,'IR',...
%     'horizontalalignment','left',...
%     'verticalalignment','top',...
%     'margin',2,...
%     'edgecolor','k',...
%     'backgroundcolor','w',...
%     'fontsize',10,...
%     'fontweight','bold',...
%     'parent',handles.primary_ax);                                           %Create text to show the state of the IR signal.

x = 0.97*session.buffsize;                                                  %Set the x position of the session clock text object.
y = trial.max_y(2)-0.03*range(trial.max_y);                                 %Set the y position of the session clock text object.
str = sprintf('Session Time: %s', datestr(now - session.start,13));         %Create the text string.
trial.clock_text = text(x,y,str,...
    'horizontalalignment','right',...
    'verticalalignment','top',...
    'margin',2,...
    'edgecolor','k',...
    'backgroundcolor','w',...
    'fontsize',10,...
    'fontweight','bold',...
    'parent',handles.primary_ax);                                           %Create text to show a session timer.

trial.peak_text = [];                                                       %Create a matrix to hold handles to peak labels.
trial.hit_time = 0;                                                         %Start off assuming an outcome of a miss.
trial.stim_time = 0;                                                        %Start off assuming stimulation will not be delivered.   


%% ***********************************************************************
function trial = MotoTrak_Initialize_Trial_Signal(handles,session,trial)
        
%
%MotoTrak_Initialize_Trial_Signal.m - Vulintus, Inc.
%
%   MOTOTRAK_INITIALIZE_TRIAL_SIGNAL starts the trial signal that will be
%   saved following a recognized trial initiation event.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial signal initializtion sections from MotoTrak_Behavior_Loop.m.
%

        
if trial.ir_initiate == 0                                                   %If the trial wasn't initiated by the IR detector...
    init_sample = find(trial.mon_signal >= handles.init,1,'first') - 1;     %Find the timepoint where the trial initiation threshold was first crossed.
else                                                                        %Otherwise...
    init_sample = session.buffsize;                                         %Set initiation sample to the current sample.
end

trial.cur_sample = session.buffsize - init_sample + session.pre_samples;    %Find the number of samples to copy from the pre-trail monitoring.
init_sample = init_sample - session.pre_samples + 1;                        %Find the start of the pre-trial period.

trial.data(1:trial.cur_sample,:) = ...
    session.buffer(init_sample:session.buffsize,:);                         %Copy the pre-trial period to the trial data.

trial.start = [now, session.buffer(init_sample,1)];                         %Save the trial start times (computer and MotoTrak controller clocks).

switch handles.curthreshtype                                                %Switch between the types of hit threshold.

    case {'degrees (total)','bidirectional'}                                %If the current threshold type is the total number of degrees...
        if handles.cur_stage == 1
            trial.base_value = min(session.buffer(end-200,2));              %Set the base value to the degrees value right at the initiation threshold crossing.
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2) - ...
                trial.base_value;                                           %Copy the pre-trial wheel position minus the base value.
        else
            trial.base_value = 0;                                           %Set the base value to the degrees value right at the initiation threshold crossing.
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2);             %Copy the pre-trial wheel position minus the base value.    
        end

    case {'degrees/s','# of spins'}                                         %If the current threshold type is the number of spins or spin velocity.
        trial.base_value = 0;                                               %Set the base value to zero spin velocity.
        temp = diff(session.buffer(:,2));                                   %Find the wheel velocity at each point in the buffer.
        temp = boxsmooth(temp,session.min_peak_dist);                       %Boxsmooth the wheel velocity with a 100 ms smoothandles.
        trial.signal(1:trial.cur_sample) = ...
            temp(init_sample-1:session.buffsize-1);                         %Grab the pre-trial spin velocity.

    case {'grams (peak)', 'grams (sustained)'}                              %If the current threshold type is the peak pull force.
        trial.base_value = 0;                                               %Set the base value to zero force.
        if strcmpi(handles.stage(handles.cur_stage).number,'PASCI1')        %If the current stage is PASCI1...
            trial.signal(1:trial.cur_sample) = ...
                abs(session.buffer(init_sample:session.buffsize,2));        %Copy the pre-trial force values.
        else
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2);             %Copy the pre-trial force values.
        end

    case {'presses', 'fullpresses'}                                         %If the current threshold type is presses (for LeverHD)            
        if strcmpi(handles.device,'knob')
            trial.base_value = session.buffer(init_sample,2);               %Set the base value to the initial value.
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2) - ...
                trial.base_value;                                           %Copy the pre-trial wheel position minus the base value.
        else
            trial.base_value = 0;                                           %Set the base value to zero.
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2);             %Copy the pre-trial angle values.
        end

    case 'milliseconds (hold)'                                              %If the current threshold type is a hold...
        trial.base_value = trial.cur_sample;                                %Set the base value to the starting sample.
        trial.signal(trial.cur_sample) = handles.period;                    %Set the first sensor value to 10.

    case 'milliseconds/grams'                                               %If the current threshold type is a hold...
%         handles.ardy.play_hitsound(1);                                      %Play the hit sound.
        trial.base_value = 0;                                               %Set the base value to zero force.
        trial.signal(1:trial.cur_sample) = ...
            session.buffer(init_sample:session.buffsize,2);                 %Copy the pre-trial force values.
%         trial.touch_signal(1:trial.cur_sample) = ...
%             1023 - data(a:session.buffsize,3);                              %Copy the pre-trial touch values.
        trial.touch_signal(1:trial.cur_sample) = ...
            session.buffer(init_sample:session.buffsize,3);                 %Copy the pre-trial touch values.
        if handles.stim == 1                                                %If stimulation is on...
            handles.ardy.stim();                                            %Turn on stimulation.
        end
end


%% ***********************************************************************
function MotoTrak_Launch_Calibration(device,ardy)

%
%MotoTrak_Launch_Pull_Calibration.m - Vulintus, Inc.
%
%   MotoTrak_Launch_Pull_Calibration closes the main MotoTrak figure and
%   launches the GUI for calibrating the MotoTrak Isometric Pull Module.
%   
%   UPDATE LOG:
%   01/09/2017 - Drew Sloan - Removed the global run variable and removed
%       the input arguments for use as a uicontrol-initiated function.
%

switch device                                                               %Switch between the available MotoTrak devices...
    case 'pull'                                                             %If the current device is the pull...
        MotoTrak_Pull_Calibration(ardy);                                    %Call the isometric pull calibration, passing the Arduino control structure.
    case 'knob'                                                             %If the current device is the knob...
    case 'lever'                                                            %If the current device is the lever...
        MotoTrak_Lever_Calibration(ardy);                                   %Call the lever calibration, passing the arduino control structure.
end               

% MotoTrak_Startup(handles);                                                  %Relaunch the MotoTrak startup script.


%% ***********************************************************************
function MotoTrak_Lever_Calibration(varargin)

%
%MotoTrak_Lever_Calibration.m - Vulintus, Inc.
%
%   MotoTrak_Lever_Calibration creates and manages a GUI through which 
%   users can calibrate the MotoTrak lever press module.
%   
%   UPDATE LOG:
%   01/04/2019 - Drew Sloan - Function first created, adapted from
%       MotoTrak_Pull_Calibration.m.
%

global run                                                                  %Create a global run variable.
if nargin == 0 || isempty(run)                                              %If the function was launched standalone or the run variable is undefined...
    run = 3;                                                                %Set the run variable to 3.
end

h = MotoTrak_Lever_Calibration_GUI(nargin);                                 %Create the calibration GUI.
Disable_All_Uicontrols(h.mainfig);                                          %Disable all uicontrols.

if nargin == 0                                                              %If there's no input arguments.
    h.ardy = Connect_MotoTrak('axes',h.stream_ax);                             %Connect to a MotoTrak controller.
    if isempty(h.ardy)                                                      %If no serial connection was made.
        delete(h.mainfig);                                                  %Delete the main figure.
        return                                                              %Skip execution of the rest of the function.
    end
    temp = h.ardy.device();                                                 %Grab the current value of the analog device identifier.
    device = MotoTrak_Identify_Device(temp);                                %Identify the currently connected device... *INCLUDE AS SUBFUNCTION*
    if ~strcmpi(device,'lever')                                             %If a pull module isn't currently connected...
        warndlg(['No lever press module was detected on this '...
            'controller. Check the connections and try again.'],...
            'No Lever Module Detected');                                    %Show a warning dialog box.
        delete(h.mainfig);                                                  %Delete the main figure.
        delete(h.ardy.serialcon);                                           %Delete the serial connection.
        return                                                              %Skip execution of the rest of the function.
    end
    h.booth = h.ardy.booth();                                               %Grab the booth number from the Arduino board.
    h.close_ardy = 1;                                                       %Indicate that the serial connection should be closed after calibration.
    h.ardy.version = h.ardy.check_version();                                %Read the controller sketch version.
    if h.ardy.version >= 200                                                %If the controller sketch version is 2.00 or newer...
        h.ardy.set_stream_input(1,1);                                       %Set the stream input index for the lever module.
    end
else
    h.ardy = varargin{1};                                                   %The serial connection handle is the first input argument.
    h.close_ardy = 0;                                                       %Indicate that the serial connection should NOT be closed after calibration.
    h.booth = h.ardy.booth();                                               %Get the booth number from the EEPROM.
end
set(h.editport,'string',h.ardy.port);                                       %Show the port on the GUI.
set(h.editbooth,'string',num2str(h.booth));                                 %Show the booth number on the GUI.

%Set the properties of various pushbuttons.
set(h.ratradio,'callback',{@RadioClick,h.mouseradio});                      %Set the callback for the rat lever select radio button.
set(h.mouseradio,'callback',{@RadioClick,h.ratradio});                      %Set the callback for the mouse lever select radio button.
set(h.recordbutton,'callback','global run; run = 3.1;');                    %Set the callback for the calibration measuring button.
set(h.savebutton,'callback','global run; run = 3.5;');                      %Set the callback for the calibration save button.
set(h.mainfig,'CloseRequestFcn','global run; run = 1;');                    %Set the close request function for the main figure.

%Read in the current calibration values and reset them to the defaults if necessary.
if h.ardy.version < 2.00                                                    %If the controller microcode version is less than 2.00...
    h.baseline = h.ardy.baseline();                                         %Read the baseline from the Arduino EEPROM.
    h.grams = h.ardy.cal_grams();                                           %Read in the grams per total ticks for calculating calibration slope from the Arduino EEPROM.
    h.ticks = h.ardy.n_per_cal_grams();                                     %Read in the total ticks for calculating the calibration slope from the Arduino EEPROM.
    h.slope = h.grams/h.ticks;                                              %Calculate the current calibration slope.
else                                                                        %Otherwise...
    h.baseline = h.ardy.get_baseline_float(1);                              %Read in the baseline value for the isometric pull handle loadcell.    
    h.slope = h.ardy.get_slope_float(1);                                    %Read in the slope value for the isometric pull handle loadcell.    
end
if h.baseline < 0 || h.baseline > 1023                                      %If the baseline is less than zero or greater than 1023...
    h.baseline = 500;                                                       %Set the baseline to a default of 500.
end
if h.slope == 0                                                             %If the current slope is zero...
    h.slope = 1;                                                            %Set the slope to 1.
end
set(h.editslope,'string',num2str(h.slope,'%1.3f'),...
    'callback',@EditSlope);                                                 %Show the slope in the slope editbox.
set(h.editbaseline,'string',num2str(h.baseline,'%1.0f'),...
    'callback',@EditBaseline);                                              %Show the baseline in the baseline editbox.

Calibration_Loop(h);                                                        %Run the calibration testing/setting loop.


%% This subfunction loops to show the streaming lever press signal.
function Calibration_Loop(h)
global run                                                                  %Create a global run variable.
signal = zeros(500,1);                                                      %Create a signal buffer.
h = MakePlot(h,signal);                                                     %Call the subfunction to create the plots.
temp = get(h.ratradio,'value');                                             %Grab the current value of the rat radio button.
if temp == 1                                                                %If the rat radio button is selected...
    minmax_y = [0, 11];                                                     %Set the maximum value to 11 degrees.
else                                                                        %Otherwise...
    minmax_y = [0, 5];                                                      %Set the maximum value to 5 degrees.
end
baseline_samples = 200;                                                     %Set the number of samples to capture for measuring the baseline.
range_samples = 300;                                                        %Set the number of samples to capture for measuring the sweep.
temp_baseline = nan(100,1);                                                 %Create a matrix to hold the baseline samples.
next_sound = 0;                                                             %Create a variable to keep track of when to play the next sound/instruction.
sample_count = 0;                                                           %Create a variable to hold the sample count during measurements.
show_save = 0;                                                              %Create a timing variable for flashing a "Calibration Saved" message on the axes.
baseline_captured = 0;                                                      %Create a variable to indicate when the baseline is captured.
txt = [];                                                                   %Create a variable to hold text objects.
h.ardy.clear();                                                             %Clear any residual values from the serial line.
h.ardy.stream_enable(1);                                                    %Enable periodic streaming on the Arduino.
guidata(h.mainfig,h);                                                       %Pin the updated handles structure to the GUI.
Enable_All_Uicontrols(h.mainfig);                                           %Enable all uicontrols.
while fix(run) == 3                                                         %Loop until the user exits calibration..
    
    temp = h.ardy.read_stream();                                            %Read in any new stream output.
    a = size(temp,1);                                                       %Find the number of new samples.
    if a > 0                                                                %If there was any new data in the stream.
        if sample_count > 0                                                 %If samples are currently being recorded...
            sample_count = sample_count - a;                                %Subtract the number of new samples from the sample count.
        end
        signal(1:end-a) = signal(a+1:end);                                  %Shift the existing buffer samples to make room for the new samples.
        signal(end-a+1:end,:) = h.slope*(temp(:,2) - h.baseline);           %Scale the new samples and them to the buffer.        
        if any(signal < minmax_y(1))                                        %If there's a new minimum signal value...
            minmax_y(1) = nanmin(signal);                                   %Save the new minimum angle value.
        end
        if any(signal > minmax_y(2))                                        %If there's a new maximum signal value...
            minmax_y(2) = nanmax(signal);                                   %Save the new maximum angle value.
        end        
        set(h.stream_plot,'xdata',1:500,'ydata',signal);                    %Update the streaming plot.
        temp = [-0.1,0.1]*(minmax_y(2) - minmax_y(1)) + minmax_y;           %Calculate the y-axis limits.        
        xlim(h.stream_ax,[1,500]);                                          %Set the x-axis limits.
        ylim(h.stream_ax,temp);                                             %Set the y-axis limits.
    end
    
    if show_save > 0 && now > show_save                                     %If a "Calibration Saved" message is present and it's time to close it...
        if h.close_ardy == 1                                                %If the program was launched as a standalone...
            Enable_All_Uicontrols(h.mainfig);                               %Enable all uicontrols.
            show_save = 0;                                                  %Reset the message time.
            delete(txt);                                                    %Delete the "Calibration Saved" text.
        else                                                                %Otherwise, if the program was launched from the main MotoTrak program.
            run = 1;                                                        %Set the run variable to 1 to close the pull calibration program.
        end
    end
    
    if ~any(run == [1,3])                                                   %If the user clicked a button...
        
        switch run                                                          %Switch between the recognized values of the run variable.
            
            case 3.1                                                        %If the run variable equals 3.1, run the measurement protocol.
                if baseline_captured == 0 && next_sound == 0                %If the sounds haven't yet been queued...                    
                    Disable_All_Uicontrols(h.mainfig);                      %Disable all uicontrols.
                    str = {[],'3','2','1','MEASURING...','THANK YOU'};      %Create a cell array to count down.
                    str{1} = ['ESTABLISHING BASELINE. PLEASE DO NOT '...
                        'PRESS THE LEVER.'];                                %Create a cell array of strings for setting the baseline.
                    cur_sound = 1;                                          %Set the current sound to 1.
                    x = mean(xlim(h.stream_ax));                            %Set the x-coordinate for the following text.
                    y = mean(ylim(h.stream_ax));                            %Set the y-coordinate for the following text.
                    next_sound = now;                                       %Set the next sound to begin immediately.
                    txt = text(x,y,str{1},...
                        'horizontalalignment','center',...
                        'fontsize',12,...
                        'verticalalignment','middle',...
                        'fontweight','bold',...
                        'margin',5,...
                        'edgecolor','k',...
                        'backgroundcolor','w',...
                        'parent',h.stream_ax);                              %Create a text object on the axes.
                    temp = get(txt,'extent');                               %Grab the extent of the text object.
                    temp = temp(3)/range(xlim(h.stream_ax));                %Find the ratio of the text length to the axes width.
                    set(txt,'fontsize',0.9*get(txt,'fontsize')/temp);       %Scale the fontsize of the text object to fit the axes.
                end
                if now >= next_sound                                        %If it's time to play the next sound.
                    if sample_count <= 0                                    %If we've captured the required number of samples...
                        temp = text2speech(str{cur_sound},5);               %Create a wavform of the voice command.            
                        sound(temp,16000);                                  %Send the voice command to the speaker.
                        if cur_sound == 1                                   %If this is the first command...
                            if baseline_captured == 0                       %If we're capturing the baseline...
                            	set(txt,'string',{['ESTABLISHING '...
                                    'BASELINE.']; ['PLEASE DO NOT PRESS'...
                                    ' THE LEVER.']});                       %Update the string in the text object.
                            else                                            %Otherwise, if we're capturing the range...
                                set(txt,'string',...
                                    {'ESTABLISHING RANGE.';...
                                    ['PLEASE PRESS THE LEVER UP AND '...
                                    'DOWN']; ['REPEATEDLY DURING '...
                                    'MEASUREMENT.']});                      %Update the string in the text object.
                            end
                        else                                                %Otherwise, if this isn't the first command...
                            set(txt,'string',str{cur_sound});               %Update the string in the text object.
                        end
                    end
                    if cur_sound == 1                                       %If the current sound is the first sound...
                        if baseline_captured == 0                           %If we're capturing the baseline...
                            next_sound = now + 4/86400;                     %Set the next sound to play in three seconds.  
                        else                                                %Otherwise, if we're capturing the range...
                            next_sound = now + 6/86400;                     %Set the next sound to play in three seconds.  
                        end                          
                        cur_sound = cur_sound + 1;                          %Increment the current sound counter.
                    elseif cur_sound == 5                                   %If the current sound is the "Measuring" sound...
                        next_sound = now + 1/86400;                         %Set the next sound to play in four seconds.
                        if baseline_captured == 0                           %If we're capturing the baseline...
                            sample_count = baseline_samples;                %Set the number of samples to capture for the baseline.
                        else                                                %Otherwise, if we're capturing the range...
                            sample_count = range_samples;                   %Set the number of samples to capture for the range.
                        end
                        cur_sound = cur_sound + 1;                           %Increment the current sound counter.
                    elseif cur_sound == 6                                   %If the current sound is the final sound.
                        if sample_count <= 0                                %If we've captured the required number of samples...
                            if baseline_captured == 0                       %If this is the end of the baseline measurement...
                                temp_baseline = ...
                                    signal(end-baseline_samples+1:end);     %Set the baseline to the median tick value.
                                str{1} = ['ESTABLISHING RANGE. PLEASE '...
                                    'PRESS THE LEVER UP AND DOWN'...
                                    ' REPEATEDLY DURING MEASUREMENT.'];     %Create a cell array of strings for setting the baseline.
                                cur_sound = 1;                              %Reset the current sound counter to one.
                                baseline_captured = 1;                      %Set the baseline captured indicator to 1.
                                next_sound = now + 2/86400;                 %Set the next sound to play in four seconds.   
                            else                                            %Otherwise, if the baseline is already captured...
                                delete(txt);                                %Delete the text object.
                                txt = [];                                   %Set the text object handle to empty brackets.
                                next_sound = 0;                             %Set the next sound variable to zero.
                                temp = signal(end-range_samples+1:end);     %Grab the signal snippet containing the measurements.
                                b = (median(temp_baseline)/h.slope) + ...
                                    h.baseline;                             %Back-calculate the new baseline in ticks from the old coefficients.
                                b = round(b);                               %Round the new baseline to the nearest whole number.
                                temp = [min(temp), max(temp)];              %Calculae the maximum and minimum of the range.
                                m = (temp/h.slope) + h.baseline;            %Back-calculate the new range in ticks from the old coefficients.
                                m = m - b;                                  %Calculate the difference between the minimum and maximum and the measured baseline.
                                if get(h.ratradio,'value') == 1             %If the rat lever radio button is checked...
                                    m = 11.04./m;                           %Calculate the degrees per tick for an 11 degree range.
                                else                                        %Otherwise, if the mouse lever radio button is checked...
                                    m = 5./m;                               %Calculate the degrees per tick for a 5 degree range.
                                end
                                m = m(min(abs(m)) == abs(m));               %Set the slope to the smaller of the two returned values.
                                h.baseline = b;                             %Save the baseline.
                                h.slope = m;                                %Save the slope.       
                                guidata(h.mainfig,h);                       %Pin the updated handles structure to the GUI.
                                run = 3.3;                                  %Reset the run variable to 3.3 to reset the y-axis limits.
                                Enable_All_Uicontrols(h.mainfig);           %Re-enable all uicontrols.
                                baseline_captured = 0;                      %Reset the baseline captured indicator.
                            end
                        end
                    else                                                    %Otherwise, for all other sounds...                    
                        next_sound = now + 1/86400;                         %Set the next sound to play in one second.
                        set(txt,'string',str{cur_sound},'fontsize',16);     %Update the string in the text object.
                        cur_sound = cur_sound + 1;                          %Increment the current sound counter.
                    end                    
                end
                
            case 3.3                                                        %If the run variable equals 3.3, change the expected range to the selected rat/mouse version...
                temp = get(h.ratradio,'value');                             %Grab the current value of the rat radio button.
                if temp == 1                                                %If the rat radio button is selected...
                    minmax_y = [0, 11];                                     %Set the maximum value to 17 degrees.
                else                                                        %Otherwise...
                    minmax_y = [0, 5];                                      %Set the maximum value to 13 degrees.
                end
                set(h.editslope,'string',num2str(h.slope,'%1.3f'));         %Show the slope in the slope editbox.
                set(h.editbaseline,'string',num2str(h.baseline,'%1.0f'));   %Show the baseline in the baseline editbox.
                signal(:) = 0;                                              %Reset the signal buffer by filling it with zeros.
                run = 3;                                                    %Reset the run variable to 3 to go back to idling.

            case 3.5                                                        %If the run variable equals 3.5, save the calibration to the controller.
                Disable_All_Uicontrols(h.mainfig);                          %Disable all uicontrols.
                set([h.editslope, h.editbaseline],'foregroundcolor','k');   %Set the foreground color for the slope and baseline editboxes to black.
                if h.ardy.version < 200                                     %If the controller code is older than version 2.00...
                    if h.slope > 1                                          %If the slope of the line is greater than 1...
                        h.grams = 32767;                                    %Set the calibration force to a maximum 16-bit integer.
                        h.ticks = round(h.grams/h.slope);                   %Calculate the sensor reading that would correspond to that force.
                    else                                                    %Otherwise, if the slope of the line is less than 1...
                        h.ticks = 32767;                                    %Set the calibration loadcell reading to a maximum 16-bit integer.
                        h.grams = round(h.slope*h.ticks);                   %Calculate the calibration force that would yield such a sensor reading.
                    end
                    h.ardy.set_baseline(h.baseline);                        %Save the baseline value in the EEPROM on the Arduino board.
                    h.ardy.set_n_per_cal_grams(h.ticks);                    %Save the maximum sensor reading on the EEPROM.
                    h.ardy.set_cal_grams(h.grams);                          %Save the maximum calibration force on the EEPROM.
                else                                                        %Otherwise...
                    h.ardy.set_baseline_float(1,h.baseline);                %Save the baseline as a float in the EEPROM address for the pull module.
                    h.ardy.set_slope_float(1,h.slope);                      %Save the slope as a float in the EEPROM address for the pull module.
                end
                str = {'Calibration','Saved!'};                             %Create a string for showing that the calibration was saved.
                x = mean(xlim(h.stream_ax));                                %Set the x-coordinate for the following text.
                y = mean(ylim(h.stream_ax));                                %Set the y-coordinate for the following text.
                txt = text(x,y,str,...
                        'horizontalalignment','center',...
                        'fontsize',12,...
                        'verticalalignment','middle',...
                        'fontweight','bold',...
                        'margin',5,...
                        'edgecolor','k',...
                        'backgroundcolor','w',...
                        'parent',h.stream_ax);                              %Create a text object on the axes.
                run = 3;                                                    %Reset the run variable to 3 to go back to idling.
                show_save = now + 1/86400;                                  %Set a time-out for the calibration saved message in one second.

        end
    end
    
    pause(0.01);                                                            %Pause for 10 milliseconds to keep from overwhelming the processor.
end
h.ardy.stream_enable(0);                                                    %Disable streaming on the Arduino.
h.ardy.clear();                                                             %Clear any residual values from the serial line.
if h.close_ardy == 1                                                        %If the serial connection should be closed after calibration...
    delete(h.ardy.serialcon);                                               %Delete the serial connection.
end
delete(h.mainfig);                                                          %Delete the main figure.
    
    
%% This subfunction creates the plots in the calibration and streaming axes.
function h = MakePlot(h,buffer)
h.stream_plot = area(1:length(buffer),buffer,'linewidth',2,...
    'facecolor',[0.5 0.5 1],'parent',h.stream_ax);                          %Create an areaseries plot in the stream axes.
% set(h.stream_ax,'ylim',[0,800],'xlim',[1,length(buffer)]);                  %Set the x- and y-axis limits of the stream axes.
% ylabel(h.stream_ax,'Loadcell','fontsize',10,'fontweight','bold');           %Set the x-axis label for the calibration curve.



%% This function executes when the user presses either of the rat/mouse lever radiobuttons.
function RadioClick(hObject,~,disable_h)
global run                                                                  %Create a global run variable.
set(disable_h,'value',0);                                                   %Uncheck the opposite radiobutton.
run = 3.3;                                                                  %Set the run variable to 3.3 to reset the y-limits on the streaming plot.


%% This function executes when the user modifies the text in the slope editbox.
function EditSlope(hObject,~)
global run                                                                  %Create a global run variable.
h = guidata(hObject);                                                       %Grab the handles structure from the GUI.
temp = get(hObject,'string');                                               %Grab the string from the slope editbox.
temp = str2double(temp);                                                    %Convert the string to a number.
if ~isnan(temp) && temp >= 0 && temp ~= h.slope                             %If the entered slope is a valid number different from the previous slope...
    h.slope = temp;                                                         %Save the specified slope in the handles structure.
    guidata(h.mainfig,h);                                                   %Pin the handles structure back to the GUI.
    run = 3.3;                                                              %Set the run variable to 3.3 to reset the plots.
end
set(hObject,'string',num2str(h.slope,'%1.3f'));                             %Reset the string in the baseline editbox to the current slope.


%% This function executes when the user modifies the text in the baseline editbox.
function EditBaseline(hObject,~)
global run                                                                  %Create a global run variable.
h = guidata(hObject);                                                       %Grab the handles structure from the GUI.
temp = get(hObject,'string');                                               %Grab the string from the baseline editbox.
temp = str2double(temp);                                                    %Convert the string to a number.
if ~isnan(temp) && temp >= 0 && temp ~= h.baseline                          %If the entered baseline is a valid number different from the previous baseline...
    h.baseline = temp;                                                      %Save the specified slope in the handles structure.
    guidata(h.mainfig,h);                                                   %Pin the handles structure back to the GUI.
    run = 3.3;                                                              %Set the run variable to 3.3 to reset the plots.
end
set(hObject,'string',num2str(h.baseline,'%1.0f'));                          %Reset the string in the baseline editbox to the current baseline.


%% ***********************************************************************
function handles = MotoTrak_Lever_Calibration_GUI(mode)

%
%MotoTrak_Lever_Calibration_GUI.m - Vulintus, Inc.
%
%   MotoTrak_Lever_Calibration_GUI creates a GUI for calibrating the 
%   MotoTrak lever press module.
%   
%   UPDATE LOG:
%   01/04/2019 - Drew Sloan - Function first created.
%

%Set the common properties of subsequent uicontrols.
fontsize = 14;                                                              %Set the fontsize for all uicontrols.
ui_h = 0.9;                                                                 %Set the height of all editboxes and listboxes, in centimeters.
sp = 0.1;                                                                   %Set the spacing between elements, in centimeters.
label_color = [0.7 0.7 0.9];                                                %Set the color for all labels.

%Create the main figure.
w = 20;                                                                     %Set the figure width, in centimeters.
h = 15;                                                                     %Set the figure height, in centimeters.
set(0,'units','centimeters');                                               %Set the system units to centimeters.
pos = get(0,'screensize');                                                  %Grab the screen size.
fig_pos = [pos(3)/2 - w/2, pos(4)/2 - h/2, w, h];                           %Set the figure position.
handles.mainfig = figure('units','centimeter',...
    'position',fig_pos,...
    'menubar','none',...
    'numbertitle','off',...
    'resize','off',...
    'name','MotoTrak Lever Press Calibration');                             %Set the properties of the main figure.

%Create a panel housing all of the calibration information uicontrols.
w = fig_pos(3) - 2*sp;                                                      %Set the width of the following panel, in centimeters.
h = 4*sp + 2*ui_h;                                                          %Set the height of the following panel, in centimeters.
pos = [sp, fig_pos(4) - h - sp, w, h];                                      %Set the panel position.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',pos,...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create the panel to hold the controller infomation uicontrols.
h = fliplr({'editport','editbooth'});                                       %Create the uicontrol handles field names for the controller infomation uicontrols.
l = fliplr({'Port: ','Booth: '});                                           %Create the labels for the uicontrols' string property.
x = sp;                                                                     %Set the left edge of the uicontrols.
w = [0.15, 0.2]*(pos(3) - 3*sp);                                            %Set the width of the following uicontrols.
for i = 1:2                                                                 %Step through the uicontrols.    
    handles.label(i) = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',l{i},...
        'units','centimeters',...
        'position',[x, pos(4)-i*(sp+ui_h)-sp, w(1), ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','right',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
    temp = uicontrol(p,'style','edit',...
        'units','centimeters',...
        'string','-',...
        'position',[x+w(1), pos(4)-i*(sp+ui_h)-sp, w(2), ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','center',...
        'backgroundcolor','w');                                             %Create an editbox for entering in each parameter.
    handles.(h{i}) = temp;                                                  %Save the uicontrol handle to the specified field in the handles structure.
end
set(handles.editport,'enable','inactive');                                  %Disable the port editbox.
h = fliplr({'editslope','editbaseline'});                                   %Create the uicontrol handles field names for session information uicontrols.
l = fliplr({'Slope: ','Baseline: '});                                       %Create the labels for the uicontrols' string property.
u = fliplr({' degrees/tick',' ticks'});                                     %Create the labels for the units uicontrols' string property.
x = x + sum(w) + sp;                                                        %Set the left edge of the uicontrols.
w = [0.15, 0.3, 0.2]*(pos(3) - 3*sp);                                       %Set the width of the following uicontrols.
for i = 1:2                                                                 %Step through the uicontrols.
    handles.label(end+1) = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',l{i},...
        'units','centimeters',...
        'position',[x, pos(4)-i*(sp+ui_h)-sp, w(1), ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','right',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
    temp = uicontrol(p,'style','edit',...
        'units','centimeters',...
        'string','-',...
        'position',[x+w(1), pos(4)-i*(sp+ui_h)-sp, w(2), ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','center',...
        'backgroundcolor','w');                                             %Create an editbox for entering in each parameter.
    handles.(h{i}) = temp;                                                  %Save the uicontrol handle to the specified field in the handles structure.
    handles.label(end+1) = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',u{i},...
        'units','centimeters',...
        'position',[x+w(1)+w(2), pos(4)-i*(sp+ui_h)-sp, w(3)-sp, ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','left',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
end

%Create a panel housing axes to show the calibration curve.
w = fig_pos(3) - 2*sp;                                                      %Set the width of the following panel, in centimeters.
h = 0.8*(fig_pos(4) - pos(4) - 4*sp);                                       %Set the height of the following panel, in centimeters.
pos = [sp, fig_pos(4) - pos(4) - 2*sp - h, w, h];                           %Set the panel position.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',pos,...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create a panel to hold the calibration axes.
w = w - 3.5*sp;                                                             %Set the width of the following axes, in centimeters.
h = h - 3*sp;                                                               %Set the height of the following axes, in centimeters.
handles.stream_ax = axes('parent',p,...
    'units','centimeters',...
    'position',[sp + 0.07*w, sp + 0.01*h, 0.93*w, 0.98*h],...
    'box','on',...
    'xlim',[0,800],...
    'ylim',[0,800],...
    'fontsize',10);                                                         %Create the calibration curve axes.
ylabel(handles.stream_ax,'Angle (\circ)',...
    'fontsize',10,...
    'fontweight','bold');                                                   %Set the y-axis label for the streaming signal curve.
set(handles.stream_ax,'xtick',[]);                                          %Remove the x-tick labels from the plot.

%Create a panel housing radio buttons to select the lever sweep (rat/mouse).
w = 0.5*(fig_pos(3) - 3*sp);                                                %Set the width of the following panel, in centimeters.
h = pos(2) - 2*sp;                                                          %Set the height of the following panel, in centimeters.
ui_h = (h - 7*sp)/2;                                                        %Set the height for the following radio buttons based on the panel height.
pos = [sp, sp, w, h];                                                       %Set the panel position.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',pos,...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create the panel to hold the stream axes.
w = (w - 12*sp);                                                            %Set the width of the radio buttons.
handles.ratradio = uicontrol(p,'style','radiobutton',...
    'string',' Rat Lever (11 degrees)',...
    'units','centimeters',...
    'position',[5*sp, 5*sp + ui_h, w, ui_h],...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'value',1,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a radio button for selecting the rat model lever.
handles.mouseradio = uicontrol(p,'style','radiobutton',...
    'string',' Mouse Lever (5 degrees)',...
    'units','centimeters',...
    'position',[5*sp, 2*sp, w, ui_h],...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'value',0,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a radio button for selecting the mouse model lever.
    
%Create buttons for capturing the calibration signal and saving the coefficients.
ui_h = (h - sp)/2;                                                          %Set the height for the following buttons based on the remaining height.
x = 0.5*(fig_pos(3) - 3*sp) + 2*sp;                                         %Set the width of the following panel, in centimeters.
w = 0.5*(fig_pos(3) - 3*sp);                                                %Set the width of the following panel, in centimeters.
handles.savebutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','SAVE CALIBRATION',...
    'units','centimeters',...
    'position',[x, sp, w, ui_h],...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a calibration save button. 
if mode == 1                                                                %If the pull calibration was launched from the MotoTrak parent window...
    set(handles.savebutton,'string','SAVE AND EXIT');                       %Change the button text to say "SAVE AND EXIT".
end
handles.recordbutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','MEASURE CALIBRATION',...
    'units','centimeters',...
    'position',[x, 2*sp+ui_h, w, ui_h],...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a reset button.


%% ***********************************************************************
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

abbrev_fields = {   'SESSION DURATION',     'session_dur';...
                    'MAIN DATA LOCATION',   'datapath';...
                    'INITIATION TRIGGER',   'init_trig'};                   %List the parameter names that have corresponding abbreviations.

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


%% ***********************************************************************
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
%   01/09/2017 - Drew Sloan - Forced the current threshold type string to
%       be lower-case for better compatibility with switch-case statements.
%

Add_Msg(h.msgbox,[datestr(now,13) ' - Current stage is '...
    h.stage(h.cur_stage).description '.']);                                 %Show the user what new stage was selected is.
d = h.stage(h.cur_stage).device;                                            %Grab the required device for the current stage.
if strcmpi(d,'water')                                                       %If the device is the water reach module...
    d = 'water reach module';                                               %Display a more verbose description.
end
Add_Msg(h.msgbox,[datestr(now,13) ...
    ' - Current device is the ' d '.']);                                    %Show the user what the new current device is.

h.threshmax = h.stage(h.cur_stage).threshmax;                               %Set the maximum hit threshold.
h.curthreshtype = lower(h.stage(h.cur_stage).threshtype);                   %Set the current threshold type.
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

    switch h.threshmin
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
set(h.editthresh,'string',num2str(h.threshmin,'%1.1f'));                    %Show the minimum hit threshold in the hit threshold editbox.
h.threshincr = h.stage(h.cur_stage).threshincr;                             %Set the adaptive hit threshold increment.    

h.threshmax = h.stage(h.cur_stage).threshmax;                               %Set the pull maximum hit threshold.     
h.threshmin = h.stage(h.cur_stage).threshmin;                               %Set the pull minimum hit threshold to this number if we aren't on a dynamic threshold type
h.threshadapt = h.stage(h.cur_stage).threshadapt;                           %Set the pull threshold adaptation type.
h.threshincr = h.stage(h.cur_stage).threshincr;                             %Set the pull adaptive hit threshold increment.
h.ceiling = h.stage(h.cur_stage).ceiling;                                   %Set the pull force ceiling.
    
h.curthreshtype = h.stage(h.cur_stage).threshtype;                          %Set the pull current threshold type.
set(h.popunits,'string',h.threshtype);                                      %Set the string and value of the threshold type pop-up menu.
h.init = h.stage(h.cur_stage).init;                                         %Set the trial initiation threshold.
set(h.editinit,'string',num2str(h.init,'%1.1f'));                           %Show the trial initiation threshold in the initiation threshold editbox.    
set(h.lblinit,'string',h.curthreshtype);                                    %Set the initiation threshold units label to the current threshold type.

% handles.stage(handles.cur_stage).threshmin
h.period = h.stage(h.cur_stage).period;                                     %Set the streaming sampling period.
h.position = h.stage(h.cur_stage).pos;                                      %Set the device position.
if (h.delay_autopositioning == 0)                                           %If there's no autopositioning delay currently in force.
    temp = round(10*(h.positioner_offset - 10*h.position));                 %Calculate the absolute position to send to the autopositioner.
    h.ardy.autopositioner(temp);                                            %Set the specified position value.
    h.delay_autopositioning = (10 + temp)/86400000;                         %Don't allow another autopositioning trigger until the current one is complete.
end
set(h.editpos,'string',num2str(h.position,'%1.1f'));                        %Show the device position in the device position editbox.
h.cur_const = h.stage(h.cur_stage).const;                                   %Set the current constraint.
set(h.popconst,'string',h.constraint);                                      %Set the string and value of the constraint type pop-up menu.
h.hitwin = h.stage(h.cur_stage).hitwin;                                     %Set the hit window.
set(h.edithitwin,'string',num2str(h.hitwin,'%1.1f'));                       %Show the hit window in the hit window editbox.

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

if h.ardy.version >= 2.00                                                   %If the controller sketch version is 2.00 or newer...
    if ~isfield(h,'max_num_tones')                                          %If the maximum number of tones isn't yet set...
        h.max_num_tones = h.ardy.get_max_num_tones();                       %Get the maximum number of tones allowed by the controller.
    end
    MotoTrak_Set_Tone_Parameters(h);                                        %Call the function to update the tone parameters.
end


%% ***********************************************************************
function MotoTrak_Main_Loop(fig)

%
%MotoTrak_Main_Loop.m - Vulintus, Inc.
%
%   MotoTrak_Main_Loop switches between the various loops of the MotoTrak
%   program based on the value of the run variable. This loop is necessary
%   because the global run variable can only be used to modify a running
%   loop if the function calling it has fully executed.
%
%   Run States:
%       - run = 0 >> Close program.
%       - run = 1 >> Idle mode.
%           - run = 1.1 >> Change idle mode parameters (stage select).
%           - run = 1.2 >> Create the new plot varibles.
%           - run = 1.3 >> Manual feed.
%           - run = 1.4 >> Reset Baseline.
%       - run = 2 >> Behavior session.
%           - run = 2.1 >> Pause session.
%           - run = 2.2 >> Manual feed.
%       - run = 3 >> Full device calibration.
%           = run = 3.1 >> Measure the maximum and minimum of the potentiometer signal (lever).
%           - run = 3.1000 to 3.1999 >> Measure specified weight (isometric pull).
%           - run = 3.2 >> Update the handles structure.
%           - run = 3.3 >> Update the calibration plots (isometric pull).
%           - run = 3.3 >> Switch between rat/mouse lever range (lever).
%           - run = 3.4 >> Revert to the previous calibration.
%           - run = 3.5 >> Save the calibration.
%   
%   UPDATE LOG:
%   01/09/2017 - Drew Sloan - Moved the baseline reset function into the
%       idle mode function.
%   01/04/2019 - Drew Sloan - Updated the above documentation to include
%       run states for lever module calibration.
%

global run                                                                  %Create the global run variable.

while run ~= 0                                                              %Loop until the user closes the program.
    switch run                                                              %Switch between the various run states.
        
        case 1                                                              %Run state 1 = Idle Mode.
            MotoTrak_Idle(fig);                                             %Call the MotoTrak idle loop.  
            
        case 2                                                              %Run state 2 = Behavior Session.
            MotoTrak_Behavior_Loop(fig);                                    %Call the MotoTrak behavioral session loop.
            
        case 3                                                              %Run state 3 = Calibration.
            h = guidata(fig);                                               %Grab the handles structue from the figure.          
            delete(fig);                                                    %Delete the main figure.
            MotoTrak_Launch_Calibration(h.device, h.ardy);                  %Call the function to open the appropriate calibration window.            
            h = MotoTrak_Startup(h);                                        %Restart MotoTrak, passing the original handles structure.
            fig = h.mainfig;                                                %Reset the figure handle.
            
    end        
end

MotoTrak_Close(fig);                                                        %Call the function to close the MotoTrak program.


%% ***********************************************************************
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
%   09/13/2016 - Drew Sloan - Renamed the preferences menu handles
%       structure field to "pref".
%   10/13/2016 - Drew Sloan - Soft-coded the version number displayed on
%       the figure so it can be set from the top of the startup function.
%   10/27/2016 - Drew Sloan - Changed the axes panel to a tab group.
%   01/09/2017 - Drew Sloan - Added a section at the end to normalize units
%       for all figure objects to fix bugs with the figure resize function.
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
if isfield(handles,'variant')                                               %If this is a custom variant...
    temp = sprintf('MotoTrak %1.2f (%s)',handles.version,handles.variant);  %Create a string showing the MotoTrak version number and the variant.
else                                                                        %If this is just the default variant...
    temp = sprintf('MotoTrak %1.2f',handles.version);                       %Create a string showing the MotoTrak version number.
end
handles.mainfig = figure('units','centimeter',...
    'Position',[pos(3)/2-w/2, pos(4)/2-h/2, w, h],...
    'MenuBar','none',...
    'numbertitle','off',...
    'resize','off',...
    'name',temp);                                                           %Create the main figure.

%% Reset any handles already existing in the structure.
handles.label = [];                                                         %Reset the handles for the labels.

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
    'enable','off');                                                        %Create a submenu option for reloading the stages spreadsheet.
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
    'label','Open Calibration...',...
    'enable','off');                                                        %Create a submenu option for opening the calibration window.

%% Create a preferences menu at the top of the figure.
handles.menu.pref.h = uimenu(handles.mainfig,'label','Preferences');        %Create a preferences menu at the top of the MotoTrak figure.
handles.menu.pref.set_datapath = uimenu(handles.menu.pref.h,...
    'label','Data Directory',...
    'enable','off');                                                        %Create a submenu option for setting the target data directory.
handles.menu.pref.err_report = uimenu(handles.menu.pref.h,...
    'label','Automatic Error Reporting',...
    'enable','on',...
    'separator','on');                                                      %Create a submenu option for tuning Automatic Error Reporting on/off.
handles.menu.pref.err_report_on = ...
    uimenu(handles.menu.pref.err_report,...
    'label','On',...
    'enable','on',...
    'checked','on');                                                        %Create a sub-submenu option for tuning Automatic Error Reporting on.
handles.menu.pref.err_report_off = ...
    uimenu(handles.menu.pref.err_report,...
    'label','Off',...
    'enable','on',...
    'checked','off');                                                       %Create a sub-submenu option for tuning Automatic Error Reporting on.
handles.menu.pref.error_reports = uimenu(handles.menu.pref.h,...
    'label','View Error Reports',...
    'enable','on');                                                         %Create a submenu option for opening the error reports directory.
handles.menu.pref.config_dir = uimenu(handles.menu.pref.h,...
    'label','Configuration Files...',...
    'enable','on',...
    'separator','on');                                                      %Create a submenu option for opening the configuration files directory.

%% Create a help menu at the top of the figure.
handles.menu.help.h = uimenu(handles.mainfig,'label','Help');               %Create a preferences menu at the top of the MotoTrak figure.
handles.menu.help.setup_guide = uimenu(handles.menu.help.h,...
    'label','Hardware Setup Guide',...
    'enable','off');                                                        %Create a submenu option for opening the hardware setup guide.
handles.menu.help.calibration_guide = uimenu(handles.menu.help.h,...
    'label','Calibration Guide',...
    'enable','off');                                                        %Create a submenu option for opening the calibration guide.
        
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

%% Create a tab group housing axes for displaying streaming data and trial results.
handles.plot_tab_grp = uitabgroup('parent',handles.mainfig,...
    'units','centimeters',...
    'position',[0.1, 2.65, 14.8, 5]);                                       %Create a tab group to hold the different types of plots.
handles.primary_tab = uitab('parent',handles.plot_tab_grp,...
    'title','Primary Signal',...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create a tab for the primary streaming signal.
handles.primary_ax = axes('parent',handles.primary_tab,...
    'units','normalized',...
    'position',[0 0 1 1],...
    'box','on',...
    'xtick',[],...
    'ytick',[]);                                                            %Create the primary streaming data axes.
handles.secondary_tab = uitab('parent',handles.plot_tab_grp,...
    'title','Secondary Signal',...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create a tab for the secondary streaming signal.
handles.secondary_ax = axes('parent',handles.secondary_tab,...
    'units','normalized',...
    'position',[0 0 1 1],...
    'box','on',...
    'xtick',[],...
    'ytick',[]);                                                            %Create the secondary streaming data axes.

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

%% Set the units for all children of the main figure to "normalized".
objs = get(handles.mainfig,'children');                                     %Grab the handles for all children of the main figure.
checker = ones(1,numel(objs));                                              %Create a checker variable to control the following loop.
while any(checker == 1)                                                     %Loop until no new children are found.
    for i = 1:numel(objs)                                                   %Step through each object.
        if isempty(get(objs(i),'children'))                                 %If the object doesn't have any children.
            checker(i) = 0;                                                 %Set the checker variable entry for this object to 0.
        end
    end
    if any(checker == 1)                                                    %If any objects were found to have children...
        temp = get(objs(checker == 1),'children');                          %Grab the handles of the newly-identified children.
        objs = vertcat(objs,temp{:});                                       %Add the new children to the objects handles list.
        checker(:) = 0;                                                     %Set all existing checker variable entries to zero.
        checker(end+1:numel(objs)) = 1;                                     %Add new entries to the checker variable for the new children.
    end
end
type = get(objs,'type');                                                    %Grab the type of each object.
objs(strcmpi(type,'uimenu')) = [];                                          %Kick out all uimenu items.
set(objs,'units','normalized');                                             %Set all units to normalized.


%% ***********************************************************************
function MotoTrak_Open_Google_Spreadsheet(~,~,url)

%
%MotoTrak_Open_Google_Spreadsheet.m - Vulintus, Inc.
%
%   MOTOTRAK_OPEN_GOOGLE_SPREADSHEET opens the linked Google Docs stage 
%   spreadsheet in the user's default browser.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Function first implemented.
%

if strncmpi(url,'https://docs.google.com/spreadsheet/pub',39)               %If the URL is in the old-style format...
    i = strfind(url,'key=') + 4;                                            %Find the start of the spreadsheet key.
    key = url(i:i+43);                                                      %Grab the 44-character spreadsheet key.
else                                                                        %Otherwise...
    i = strfind(url,'/d/') + 3;                                             %Find the start of the spreadsheet key.
    key = url(i:i+43);                                                      %Grab the 44-character spreadsheet key.
end
str = sprintf('https://docs.google.com/spreadsheets/d/%s/',key);            %Create the Google spreadsheet general URL from the spreadsheet key.
web(str,'-browser');                                                        %Open the Google spreadsheet in the default system browser.


%% ***********************************************************************
function [pks,i] = MotoTrak_Peak_Finder(signal,minpkdist)

%This function finds peaks in MotoTrak input signals, accounting for equality of contiguous samples.
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


%% ***********************************************************************
function MotoTrak_Pull_Calibration(varargin)

%
%MotoTrak_Pull_Calibration.m - Vulintus, Inc.
%
%   MotoTrak_Pull_Calibration creates and manages a GUI through which users
%   can calibrate the MotoTrak isometric pull module.
%   
%   UPDATE LOG:
%   01/09/2017 - Drew Sloan - Changed the values of the global run variable
%       to match those used in the MotoTrak main loop. Added varargin
%       functionality to receive/send the handle for the MotoTrak serial
%       connection.
%

global run                                                                  %Create a global run variable.
if nargin == 0 || isempty(run)                                              %If the function was launched standalone or the run variable is undefined...
    run = 3;                                                                %Set the run variable to 3.
end

test_weights = sort([0,10,20,50:40:250,100,200]);                           %Set the available test weights.

h = MotoTrak_Pull_Calibration_GUI(test_weights,nargin);                     %Create the calibration GUI.
Disable_All_Uicontrols(h.mainfig);                                          %Disable all uicontrols.

if nargin == 0                                                              %If there's no input arguments.
    h.ardy = Connect_MotoTrak('axes',h.cal_ax);                             %Connect to a MotoTrak controller.
    if isempty(h.ardy)                                                      %If no serial connection was made.
        delete(h.mainfig);                                                  %Delete the main figure.
        return                                                              %Skip execution of the rest of the function.
    end
    temp = h.ardy.device();                                                 %Grab the current value of the analog device identifier.
    device = MotoTrak_Identify_Device(temp);                                %Identify the currently connected device... *INCLUDE AS SUBFUNCTION*
    if ~strcmpi(device,'pull')                                              %If a pull module isn't currently connected...
        warndlg(['No isometric force module was detected on this '...
            'controller. Check the connections and try again.'],...
            'No Pull Module Detected');                                     %Show a warning dialog box.
        delete(h.mainfig);                                                  %Delete the main figure.
        delete(h.ardy.serialcon);                                           %Delete the serial connection.
        return                                                              %Skip execution of the rest of the function.
    end
    h.booth = h.ardy.booth();                                               %Grab the booth number from the Arduino board.
    h.close_ardy = 1;                                                       %Indicate that the serial connection should be closed after calibration.
else
    h.ardy = varargin{1};                                                   %The serial connection handle is the first input argument.
    h.close_ardy = 0;                                                       %Indicate that the serial connection should NOT be closed after calibration.
    h.booth = h.ardy.booth();                                               %Get the booth number from the EEPROM.
end
set(h.editport,'string',h.ardy.port);                                       %Show the port on the GUI.
set(h.editbooth,'string',num2str(h.booth));                                 %Show the booth number on the GUI.

%Set the properties of various pushbuttons.
for w = [10,20,100,200]                                                     %Step through test weights that we'll skip by default.
    i = length(test_weights) - find(test_weights == w) + 1;                 %Find the button index for this weight.
    set(h.skipbutton(i),'string','SKIP','foregroundcolor',[0.5 0 0]);       %Set the button string to "SKIP".
end
set(h.weightbutton,'callback',@TestWeight);                                 %Set the callback for all test weight pushbuttons.
set(h.editbooth,'callback',@MotoTrak_Edit_Booth);                           %Set the callback for the booth number editbox.
set(h.skipbutton,'callback',@SkipVoice);                                    %Set the callback for the voice-guided calibration skip buttons.
set(h.guidebutton,'callback',@GuidedCalibration);                           %Set the callback for the voice-guided calibration button.
set(h.clearbutton,'callback','global run; run = 3.4;');                     %Set the callback for the revert to previous button.
set(h.savebutton,'callback','global run; run = 3.5;');                      %Set the callback for the calibration save button.
set(h.countbutton,'callback',@ToggleCountdown);                             %Set the callback for the countdown toggle button.
set(h.mainfig,'CloseRequestFcn','global run; run = 1;');                    %Set the close request function for the main figure.

%Read in the current calibration values and reset them to the defaults if necessary.
if h.ardy.version < 2.00                                                    %If the controller microcode version is less than 2.00...
    h.baseline = h.ardy.baseline();                                         %Read the baseline from the Arduino EEPROM.
    h.grams = h.ardy.cal_grams();                                           %Read in the grams per total ticks for calculating calibration slope from the Arduino EEPROM.
    h.ticks = h.ardy.n_per_cal_grams();                                     %Read in the total ticks for calculating the calibration slope from the Arduino EEPROM.
    if h.baseline < 0                                                       %If the baseline is less than zero...
        h.baseline = 100;                                                   %Set the baseline to a default of 100.
    end
    if h.grams <= 0                                                         %If the grams per total ticks is less than or equal to zero...
        h.grams = 500;                                                      %Set the grams per total ticks to a default of 500.
    end
    if h.ticks <= 0                                                         %If the total ticks is less than or equal to zero...
        h.ticks = 1000;                                                     %Set the total ticks to a default of 500.
    end
    h.slope = h.grams/h.ticks;                                              %Calculate the current calibration slope.
else                                                                        %Otherwise...
    h.baseline = h.ardy.get_baseline_float(6);                              %Read in the baseline value for the isometric pull handle loadcell.    
    h.slope = h.ardy.get_slope_float(6);                                    %Read in the slope value for the isometric pull handle loadcell.    
end
set(h.editslope,'string',num2str(h.slope,'%1.3f'),...
    'callback',@EditSlope);                                                 %Show the slope in the slope editbox.
set(h.editbaseline,'string',num2str(h.baseline,'%1.0f'),...
    'callback',@EditBaseline);                                              %Show the baseline in the baseline editbox.

Calibration_Loop(h);                                                        %Run the calibration testing/setting loop.


%% This subfunction loops to show real-time plots of incoming calibration signals.
function Calibration_Loop(h)
global run                                                                  %Create a global run variable.
global run_guide                                                            %Create a global variable to control running the voice-guided calibration.
run_guide = 0;                                                              %Set the voice guide run variable to 0.
signal = h.baseline*ones(500,1);                                            %Create a signal buffer.
h = MakePlots(h,signal);                                                    %Call the subfunction to create the plots.
max_tick = 800;                                                             %Set the maximum tick value to 800.
show_save = 0;                                                              %Create a timing variable for flashing a "Calibration Saved" message on the axes.
h.ardy.clear();                                                             %Clear any residual values from the serial line.
h.ardy.stream_enable(1);                                                    %Enable periodic streaming on the Arduino.
next_sound = 0;                                                             %Create a variable to keep track of when to play the next sound.
cal_pts = [h.baseline, 0];                                                  %Create a matrix to hold calibration data points.
cal_h = line(cal_pts(:,1),cal_pts(:,2),'linestyle','none',...
    'marker','*','markersize',7,'color',[0.5 0 0],...
    'markerfacecolor',[0.5 0 0],'parent',h.cal_ax,'visible','off');         %Show the calibration points as asterixes.
txt = [];                                                                   %Create a variable to hold text objects.
cur_wt = 0;                                                                 %Create a counter for the voice-guided calibration.
guidata(h.mainfig,h);                                                       %Pin the updated handles structure to the GUI.
Enable_All_Uicontrols(h.mainfig);                                           %Enable all uicontrols.
while fix(run) == 3                                                         %Loop until the user exits calibration.
    temp = h.ardy.read_stream();                                            %Read in any new stream output.
    a = size(temp,1);                                                       %Find the number of new samples.
    if a > 0                                                                %If there was any new data in the stream.        
        signal(1:end-a) = signal(a+1:end);                                  %Shift the existing buffer samples to make room for the new samples.
        signal(end-a+1:end,:) = temp(:,2);                                  %Add the new samples to the buffer.
        set(h.stream_plot,'ydata',signal);                                  %Update the streaming plot.
        if any(signal > max_tick)                                           %If there's a new maximum signal value...
            max_tick = max(signal);                                         %Save the new maximum tick value.
            temp = (1.05*[0,max_tick] - h.baseline)*h.slope;                %Calculate the y-axis limits of the calibration axes.
            set(h.cal_ax,'xlim',1.025*[0,max_tick],'ylim',temp);            %Reset the x-axis limits of the calibration plot.
            set(h.cur_cal,'xdata',1.05*[0,max_tick],'ydata',temp);          %Reset the bounds of the current calibration line.
            set(h.stream_ax,'ylim',1.05*[0,max_tick]);                      %Reset the y-axis limits of the streaming plot.
            x = 1.05*max_tick*[0.4,0.45];                                   %Calculate the x-coordinates of a legend line.
            y = ylim(h.cal_ax);                                             %Grab the calibration axes y-limits.
            y = 0.95*(y(2)-y(1)) + y(1);                                    %Calculate the height of the legend.
            set(h.prev_legend(1),'xdata',x,'ydata',y*[1,1]);                %Update the previous calibration legend line.
            set(h.prev_legend(2),'position',[x(2),y]);                      %Update the previous calibration legend text.
        end
        tick = mean(signal(end-9:end));                                     %Find the average value of the signal over the last 10 samples.
        val = (tick*[0,1,1] - h.baseline)*h.slope;                          %Calculate the degrees from the current slope and baseline.
        set(h.cur_ln,'xdata',tick*[1,1,0],'ydata',val);                     %Reset the position of the current reading line.        
        set(h.val_txt,'string',[num2str(val(2),'%1.0f') ' g'],...
            'position',[0.025*max_tick, val(2)]);                           %Adjust the position and text of the gram force text label.
        temp = 0.025*range(ylim(h.cal_ax)) + min(ylim(h.cal_ax));           %Calculate the current  position of the tick text label.
        set(h.tick_txt,'string',num2str(tick,'%1.0f'),...
            'position',[tick, temp]);                                       %Adjust the position and text of the gram force text label.
    end
    if show_save > 0 && now > show_save                                     %If a "Calibration Saved" message is present and it's time to close it...
        if h.close_ardy == 1                                                %If the program was launched as a standalone...
            Enable_All_Uicontrols(h.mainfig);                               %Enable all uicontrols.
            show_save = 0;                                                  %Reset the message time.
            delete(txt);                                                    %Delete the "Calibration Saved" text.
        else                                                                %Otherwise, if the program was launched from the main MotoTrak program.
            run = 1;                                                        %Set the run variable to 1 to close the pull calibration program.
        end
    end
    
    if ~any(run == [1,3])                                                   %If the user clicked a button...
        
        switch run                                                          %Switch between the recognized values of the run variable.
            
            case 3.2                                                        %If the run variable equals 3.2, update the handles structure.
                h = guidata(h.mainfig);                                     %Update the handles structure by pulling it down from the GUI.
                cal_pts = [h.baseline, 0];                                  %Reset the calibration data points matrix.
                set(cal_h,'visible','off');                                 %Make the calibration data points invisible.
                run = 3.3;                                                  %Set the run variable to 3.3 to update the calibration plots.
                
            case 3.3                                                        %If the run variable equals 3.3, update the calibration plots.
                temp = (1.05*[0,max_tick] - h.baseline)*h.slope;            %Calculate the y-axis limits of the calibration axes.
                set(h.cal_ax,'xlim',1.025*[0,max_tick],'ylim',temp);        %Reset the x-axis limits of the calibration plot.
                set(h.cur_cal,'xdata',1.05*[0,max_tick],'ydata',temp);      %Reset the bounds of the current calibration line.
                set(h.base_ln,'xdata',h.baseline*[1,1],'ydata',temp);       %Update the baseline line.
                temp = get(h.prev_cal,'userdata');                          %Grab the previous slope and calibration from the previous calibration line's 'UserData' property.
                temp = (1.05*[0,max_tick]-temp(2))*temp(1);                 %Calculate the y-axis limits of the calibration curves.
                set(h.prev_cal,'xdata',1.05*[0,max_tick],'ydata',temp);     %Show the previous calibration with a line.
                x = 1.05*max_tick*[0.4,0.45];                               %Calculate the x-coordinates of a legend line.
                y = ylim(h.cal_ax);                                         %Grab the calibration axes y-limits.
                y = 0.95*(y(2)-y(1)) + y(1);                                %Calculate the height of the legend.
                set(h.prev_legend(1),'xdata',x,'ydata',y*[1,1]);            %Update the previous calibration legend line.
                set(h.prev_legend(2),'position',[x(2),y]);                  %Update the previous calibration legend text.
                run = 3;                                                    %Reset the run variable to 3 to go back to idling.
                
            case 3.4                                                        %If the run variable equals 3.4, revert to the previous calibration.
                temp = get(h.prev_cal,'userdata');                          %Grab the previous slope and calibration from the previous calibration line's 'UserData' property.
                h.slope = temp(1);                                          %Set the current slope to the previous slope.
                h.baseline = temp(2);                                       %Set the current baseline to the previous baseline.
                cal_pts = [h.baseline, 0];                                  %Reset the calibration data points matrix.
                set(cal_h,'visible','off');                                 %Make the calibration data points invisible.
                set(h.editslope,'string',num2str(h.slope,'%1.3f'),...
                    'foregroundcolor','k');                                 %Update the string in the slope editbox.
                set(h.editbaseline,'string',num2str(h.baseline,'%1.0f'),...
                    'foregroundcolor','k');                                 %Update the string in the baseline editbox.
                guidata(h.mainfig,h);                                       %Pin the updated handles structure to the GUI.                
                run = 3.3;                                                  %Set the run variable to 3.3 to update the calibration plots.
                
            case 3.5                                                        %If the run variable equals 3.5, save the calibration to the controller.
                Disable_All_Uicontrols(h.mainfig);                          %Disable all uicontrols.
                set(h.prev_cal,'xdata',get(h.cur_cal,'xdata'),...
                    'ydata',get(h.cur_cal,'ydata'),...
                    'userdata',[h.slope, h.baseline]);                      %Update the previous calibration line to match the current line.
                set([h.editslope, h.editbaseline],'foregroundcolor','k');   %Set the foreground color for the slope and baseline editboxes to black.
                if h.ardy.version < 200                                     %If the controller code is older than version 2.00...
                    if h.slope > 1                                          %If the slope of the line is greater than 1...
                        h.grams = 32767;                                    %Set the calibration force to a maximum 16-bit integer.
                        h.ticks = round(h.grams/h.slope);                   %Calculate the sensor reading that would correspond to that force.
                    else                                                    %Otherwise, if the slope of the line is less than 1...
                        h.ticks = 32767;                                    %Set the calibration loadcell reading to a maximum 16-bit integer.
                        h.grams = round(h.slope*h.ticks);                   %Calculate the calibration force that would yield such a sensor reading.
                    end
                    h.ardy.set_baseline(h.baseline);                        %Save the baseline value in the EEPROM on the Arduino board.
                    h.ardy.set_n_per_cal_grams(h.ticks);                    %Save the maximum sensor reading on the EEPROM.
                    h.ardy.set_cal_grams(h.grams);                          %Save the maximum calibration force on the EEPROM.
                else                                                        %Otherwise...
                    h.ardy.set_baseline_float(6,h.baseline);                %Save the baseline as a float in the EEPROM address for the pull module.
                    h.ardy.set_slope_float(6,h.slope);                      %Save the slope as a float in the EEPROM address for the pull module.
                end
                str = {'Calibration','Saved!'};                             %Create a string for showing that the calibration was saved.
                x = mean(xlim(h.cal_ax));                                   %Set the x-coordinate for the following text.
                y = mean(ylim(h.cal_ax));                                   %Set the y-coordinate for the following text.
                txt = text(x,y,str,...
                        'horizontalalignment','center',...
                        'fontsize',12,...
                        'verticalalignment','middle',...
                        'fontweight','bold',...
                        'margin',5,...
                        'edgecolor','k',...
                        'backgroundcolor','w',...
                        'parent',h.cal_ax);                                 %Create a text object on the axes.
                run = 3.3;                                                  %Set the run variable to 3.3 to update the calibration plots.
                show_save = now + 1/86400;                                  %Set a time-out for the calibration saved message in one second.
        
            otherwise                                                       %For all other values of the run variable, assume we're measuring a test weight.
                wt = 10000*(run - 3.1);                                     %Convert the run variable value into a test weight.
                if next_sound == 0                                          %If the sounds haven't yet been queued...
                    Disable_All_Uicontrols(h.mainfig);                      %Disable all uicontrols.
                    if run_guide == 1                                       %If we're running a voice-guided calibration...
                        set(h.guidebutton,'enable','on');                   %Enable the voice-guided calibration button.
                    end
                    str = {[],'3','2','1','MEASURING...','Thank you'};      %Create a cell array to count down
                    if wt == 0                                              %If the run variable equals 3.1...
                        str{1} = ['Establishing baseline. Please do '...
                            'not apply any force.'];                        %Create a string for setting the baseline.
                    else                                                    %Otherwise...                        
                        str{1} = sprintf(['Please apply %1.0f grams '...
                            'and hold.'],wt);                               %Create a string for setting a test weight. 
                    end            
                    cur_sound = 1;                                          %Set the current sound to 1.
                    x = mean(xlim(h.cal_ax));                               %Set the x-coordinate for the following text.
                    y = mean(ylim(h.cal_ax));                               %Set the y-coordinate for the following text.
                    next_sound = now;                                       %Set the next sound to begin immediately.
                    txt = text(x,y,str{1},...
                        'horizontalalignment','center',...
                        'fontsize',12,...
                        'verticalalignment','middle',...
                        'fontweight','bold',...
                        'margin',5,...
                        'edgecolor','k',...
                        'backgroundcolor','w',...
                        'parent',h.cal_ax);                                 %Create a text object on the axes.
                    temp = get(txt,'extent');                               %Grab the extent of the text object.
                    temp = temp(3)/range(xlim(h.cal_ax));                   %Find the ratio of the text length to the axes width.
                    set(txt,'fontsize',0.9*get(txt,'fontsize')/temp);       %Scale the fontsize of the text object to fit the axes.
                    temp = get(h.countbutton,'string');                     %Grab the countdown toggle button string.
                    if strcmpi(temp,'COUNTDOWN OFF')                        %If the user turned the countdown off...
                        cur_sound = 5;                                      %Set the current sound to 5.
                        next_sound = now + 0.5/86400;                       %Set the next sound to start in half-a-second.
                    end
                end
                if now >= next_sound                                        %If it's time to play the next sound.                
                    temp = text2speech(str{cur_sound},5);                   %Create a wavform of the voice command.            
                    sound(temp,16000);                                      %Send the voice command to the speaker.
                    set(txt,'string',str{cur_sound});                       %Update the string in the text object.
                    if cur_sound == 1                                       %If the current sound is the first sound...
                        next_sound = now + 4/86400;                         %Set the next sound to play in three seconds.                
                    elseif cur_sound == 5                                   %If the current sound is the "Measuring" sound...
                        next_sound = now + 1/86400;                         %Set the next sound to play in three seconds.
                    elseif cur_sound ~= 6                                   %If this isn't the final sound...                    
                        next_sound = now + 1/86400;                         %Set the next sound to play in one second.
                        set(txt,'string',str{cur_sound},'fontsize',16);     %Update the string in the text object.
                    else                                                    %Otherwise, if this is the last sound...
                        delete(txt);                                        %Delete the text object.
                        txt = [];                                           %Set the text object handle to empty brackets.
                        next_sound = 0;                                     %Set the next sound variable to zero.
                        tick = median(signal(end-99:end));                  %Grab the median value from the last second of the signal.
                        if wt == 0                                          %If the test weight is zero (resetting baseline)...
                            cal_pts(:,1) = ...
                                cal_pts(:,1) - h.baseline + tick;           %Adjust the previous calibration data.
                            h.baseline = tick;                              %Set the baseline to the median signal.
                            set(h.editbaseline,...
                                'string',num2str(tick,'%1.0f'),...
                                'foregroundcolor',[0 0 0.5]);               %Update the string in the baseline editbox.
                            set(cal_h,'xdata',cal_pts(:,1));                %Update the calibration points.
                        else                                                %Otherwise...
                            cal_pts(end+1,1:2) = [tick, wt];                %Add a new row to the calibration data matrix.
                            set(cal_h,'xdata',cal_pts(:,1),...
                                'ydata',cal_pts(:,2),...
                                'visible','on');                            %Update the calibration points.
                            h.slope = sum(cal_pts(2:end,2))/...
                                sum(cal_pts(2:end,1) - cal_pts(1,1));       %Update the slope.
                            set(h.editslope,...
                                'string',num2str(h.slope,'%1.3f'),...
                                'foregroundcolor',[0 0 0.5]);               %Update the string in the slope editbox.
                        end
                        guidata(h.mainfig,h);                               %Pin the updated handles structure to the GUI.
                        run = 3.3;                                          %Reset the run variable to 3.
                        Enable_All_Uicontrols(h.mainfig);                   %Re-enable all uicontrols.
                    end
                    cur_sound = cur_sound + 1;                              %Increment the current sound counter.
                end
        end
    end
    
    if run_guide == 1                                                       %If the run guide variable equals 1...
        if run == 3                                                         %If the calibration is currently idling...
            if cur_wt == 0                                                  %If this if the first test weight of the sequence.
                set(h.countbutton,'string','COUNTDOWN ON',...
                    'foregroundcolor',[0 0.5 0]);                           %Update the countdown toggle button to turn the countdown on.
                cur_wt = 1;                                                 %Set the current weight to test to the first weight.
            else                                                            %Otherwise...
                cur_wt = cur_wt + 1;                                        %Increment the weight counter.
            end
            if cur_wt > length(h.weights)                                   %If the count is greater than the list of weights...
                run_guide = 0;                                              %Set the run guide to zero.
                cur_wt = 0;                                                 %Set the weight counter back to zero.
                set(h.guidebutton,'string','RUN VOICE GUIDE',...
                    'foregroundcolor','k');                                 %Reset the string on the run guide button.
            else                                                            %Otherwise...
                i = length(h.weights) - cur_wt + 1;                         %Find the button index for this weight.
                temp = get(h.skipbutton(i),'string');                       %Grab the string from the skip button for the current weight.
                if strcmpi(temp,'VOICE')                                    %If the user hasn't opted to skip this weight...
                    run = 3.1 + (h.weights(cur_wt)/10000);                  %Set the run variable to the current weight.
                end
            end
        end
    elseif run_guide == -1                                                  %If the run guide variable equals -1...
        delete(txt);                                                        %Delete the text object.
        txt = [];                                                           %Set the text object handle to empty brackets.
        next_sound = 0;                                                     %Set the next sound variable to zero.
        set(h.guidebutton,'string','RUN VOICE GUIDE',...
            'foregroundcolor','k');                                         %Reset the string on the run guide button.
        run_guide = 0;                                                      %Set the run guide to zero.
        run = 3.3;                                                          %Set the run variable to 3.3 to update the calibration plots.
        Enable_All_Uicontrols(h.mainfig);                                   %Re-enable all uicontrols.
    end
    pause(0.01);                                                            %Pause for 10 milliseconds to keep from overwhelming the processor.
end
h.ardy.stream_enable(0);                                                    %Disable streaming on the Arduino.
h.ardy.clear();                                                             %Clear any residual values from the serial line.
if h.close_ardy == 1                                                        %If the serial connection should be closed after calibration...
    delete(h.ardy.serialcon);                                               %Delete the serial connection.
end
delete(h.mainfig);                                                          %Delete the main figure.


%% This subfunction creates the plots in the calibration and streaming axes.
function h = MakePlots(h,buffer)
h.stream_plot = area(1:length(buffer),buffer,'linewidth',2,...
    'facecolor',[0.5 0.5 1],'parent',h.stream_ax);                          %Create an areaseries plot in the stream axes.
set(h.stream_ax,'ylim',[0,800],'xlim',[1,length(buffer)]);                  %Set the x- and y-axis limits of the stream axes.
ylabel(h.stream_ax,'Loadcell','fontsize',10,'fontweight','bold');           %Set the x-axis label for the calibration curve.
temp = ([0,800]-h.baseline)*h.slope;                                        %Calculate the y-axis limits of the calibration axes.
set(h.cal_ax,'xlim',[0,800],'ylim',temp);                                   %Set the x- and y-axis limits of the calibration plot.
temp = ([0,1023]-h.baseline)*h.slope;                                       %Calculate the y-axis limits of the calibration curves.
h.prev_cal = line([0,1023],temp,'linestyle',':','linewidth',2,...
    'color','b','parent',h.cal_ax,'userdata',[h.slope, h.baseline]);        %Show the previous calibration with a line.
h.cur_cal = line([0,1023],temp,'linestyle',':','linewidth',2,...
    'color','k','parent',h.cal_ax);                                         %Show the current calibration with a line.
h.base_ln = line(h.baseline*[1,1],temp,'color',[0 0 0.5],...
    'linewidth',1,'parent',h.cal_ax);                                       %Plot a line to show the current baseline.
h.zero_ln = line([0,1023],[0,0],'color',[0 0 0.5],'linewidth',1,...
    'parent',h.cal_ax);                                                     %Plot a line to show zero force.
h.cur_ln = line(h.baseline*[0,1,1],temp(1)*[0,0,1],'color',[0.5 0 0],...
    'markersize',5,'marker','o','markerfacecolor',[0.5 0 0],...
    'linewidth',1.5,'parent',h.cal_ax);                                     %Create a line to show the current reading.
temp = 0.025*range(ylim(h.cal_ax)) + min(ylim(h.cal_ax));                   %Calculate the initial position of the tick text label.
h.tick_txt = text(h.baseline,temp,' ','verticalalignment','bottom',...
    'horizontalalignment','center','fontsize',8,'margin',2,...
    'edgecolor',[0.5 0 0],'backgroundcolor','w','linewidth',1.5,...
    'parent',h.cal_ax,'fontweight','bold');                                 %Create a text object to show the current tick reading.
h.val_txt = text(0.025*800,0,' ','verticalalignment','middle',...
    'horizontalalignment','left','fontsize',8,'margin',2,...
    'edgecolor',[0.5 0 0],'backgroundcolor','w','linewidth',1.5,...
    'parent',h.cal_ax,'fontweight','bold');                                 %Create a text object to show the current grams of force.
h.prev_legend = [0,0];                                                      %Create a field to hold the line and text handles for a legend.
x = 800*[0.4,0.45];                                                         %Calculate the x-coordinates of a legend line.
y = ylim(h.cal_ax);                                                         %Grab the calibration axes y-limits.
y = 0.95*(y(2)-y(1)) + y(1);                                                 %Calculate the height of the legend.
h.prev_legend(1) = line(x,y*[1,1],'linestyle',':','linewidth',2,...
    'color','b','parent',h.cal_ax);                                         %Draw a line as a legend for the previous calibration.
h.prev_legend(2) = text(x(2),y,' PREVIOUS','fontsize',8,'color','b',...
    'fontweight','bold','parent',h.cal_ax);                                 %Label the legend line.
uistack(h.prev_legend,'bottom');                                            %Move the legend to the bottom of the UI stack.


%% This function executes whenever the user presses one of the test weight pushbuttons.
function TestWeight(hObject,~)
global run                                                                  %Create a global run variable.
val = get(hObject,'UserData');                                              %Grab the test weight value from the button's 'UserData' property.
run = 3.1 + (val/10000);                                                    %Set the run variable to the test weight value.


%% This function executes when the user modifies the text in the slope editbox.
function EditSlope(hObject,~)
global run                                                                  %Create a global run variable.
h = guidata(hObject);                                                       %Grab the handles structure from the GUI.
temp = get(hObject,'string');                                               %Grab the string from the slope editbox.
temp = str2double(temp);                                                    %Convert the string to a number.
if ~isnan(temp) && temp >= 0 && temp ~= h.slope                             %If the entered slope is a valid number different from the previous slope...
    h.slope = temp;                                                         %Save the specified slope in the handles structure.
    guidata(h.mainfig,h);                                                   %Pin the handles structure back to the GUI.
    run = 3.2;                                                              %Set the run variable to -2 to indicate that the handles structure should be updated.
end
set(hObject,'string',num2str(h.slope,'%1.3f'));                             %Reset the string in the baseline editbox to the current slope.


%% This function executes when the user modifies the text in the baseline editbox.
function EditBaseline(hObject,~)
global run                                                                  %Create a global run variable.
h = guidata(hObject);                                                       %Grab the handles structure from the GUI.
temp = get(hObject,'string');                                               %Grab the string from the baseline editbox.
temp = str2double(temp);                                                    %Convert the string to a number.
if ~isnan(temp) && temp >= 0 && temp ~= h.baseline                          %If the entered baseline is a valid number different from the previous baseline...
    h.baseline = temp;                                                      %Save the specified slope in the handles structure.
    guidata(h.mainfig,h);                                                   %Pin the handles structure back to the GUI.
    run = 3.2;                                                              %Set the run variable to -2 to indicate that the handles structure should be updated.
end
set(hObject,'string',num2str(h.baseline,'%1.0f'));                          %Reset the string in the baseline editbox to the current baseline.


%% This function executes when the user presses one of the voice-guided calibration skip buttons.
function SkipVoice(hObject,~)
temp = get(hObject,'string');                                               %Grab the current button string.
if strcmpi(temp,'VOICE')                                                    %If the current string is "VOICE"...
    set(hObject,'string','SKIP','foregroundcolor',[0.5 0 0]);               %Set the string to "SKIP" and color the text red.
else                                                                        %Otherwise...
    set(hObject,'string','VOICE','foregroundcolor',[0 0.5 0]);              %Set the string to "VOICE" and color the text green.
end


%% This function executes when the user presses the voice-guided calibration button.
function GuidedCalibration(hObject,~)
global run_guide                                                            %Create a global variable to control running the voice-guided calibration.
if run_guide == 0                                                           %If a voice-guided calibration isn't currently running.
    run_guide = 1;                                                          %Set the run guide variable to 1.
    set(hObject,'string','CANCEL GUIDE','foregroundcolor',[0.5 0 0]);       %Change the string on the run guide button to say "CANCEL GUIDE".
else                                                                        %Otherwise, if a voice-guided calibration is currently running.
    run_guide = -1;                                                         %Set the run guide variable to 1.
end


%% This furnction executes when the user presses the countdown toggle button.
function ToggleCountdown(hObject,~)
str = get(hObject,'string');                                                %Grab the current button string.
if strcmpi(str,'countdown on')                                              %If the countdown is currently turned on...
    set(hObject,'string','COUNTDOWN OFF','foregroundcolor',[0.5 0 0]);      %Change the text on the button to turn the countdown off.
else                                                                        %Otherwise...
    set(hObject,'string','COUNTDOWN ON','foregroundcolor',[0 0.5 0]);       %Change the text on the button to turn the countdown on.
end


%% ***********************************************************************
function handles = MotoTrak_Pull_Calibration_GUI(weights,mode)

%
%MotoTrak_Pull_Calibration_GUI.m - Vulintus, Inc.
%
%   MotoTrak_Pull_Calibration_GUI creates a GUI for calibrating the 
%   MotoTrak isometric pull module.
%   
%   UPDATE LOG:
%   01/04/2019 - Drew Sloan - Updated with initial function description.
%

%Set the common properties of subsequent uicontrols.
fontsize = 14;                                                              %Set the fontsize for all uicontrols.
ui_h = 0.9;                                                                 %Set the height of all editboxes and listboxes, in centimeters.
sp = 0.1;                                                                   %Set the spacing between elements, in centimeters.
label_color = [0.7 0.7 0.9];                                                %Set the color for all labels.

%Create the main figure.
w = 20;                                                                     %Set the figure width, in centimeters.
h = 15;                                                                     %Set the figure height, in centimeters.
set(0,'units','centimeters');                                               %Set the system units to centimeters.
pos = get(0,'screensize');                                                  %Grab the screen size.
fig_pos = [pos(3)/2 - w/2, pos(4)/2 - h/2, w, h];                           %Set the figure position.
handles.mainfig = figure('units','centimeter',...
    'position',fig_pos,...
    'menubar','none',...
    'numbertitle','off',...
    'resize','off',...
    'name','MotoTrak Isometric Pull Calibration');                          %Set the properties of the main figure.
        
%Create a panel housing all of the calibration information uicontrols.
w = fig_pos(3) - 2*sp;                                                      %Set the width of the following panel, in centimeters.
h = 4*sp + 2*ui_h;                                                          %Set the height of the following panel, in centimeters.
pos = [sp, fig_pos(4) - h - sp, w, h];                                      %Set the panel position.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',pos,...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create the panel to hold the controller infomation uicontrols.
h = fliplr({'editport','editbooth'});                                       %Create the uicontrol handles field names for the controller infomation uicontrols.
l = fliplr({'Port: ','Booth: '});                                           %Create the labels for the uicontrols' string property.
x = sp;                                                                     %Set the left edge of the uicontrols.
w = [0.15, 0.2]*(pos(3) - 3*sp);                                            %Set the width of the following uicontrols.
for i = 1:2                                                                 %Step through the uicontrols.    
    handles.label(i) = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',l{i},...
        'units','centimeters',...
        'position',[x, pos(4)-i*(sp+ui_h)-sp, w(1), ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','right',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
    temp = uicontrol(p,'style','edit',...
        'units','centimeters',...
        'string','-',...
        'position',[x+w(1), pos(4)-i*(sp+ui_h)-sp, w(2), ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','center',...
        'backgroundcolor','w');                                             %Create an editbox for entering in each parameter.
    handles.(h{i}) = temp;                                                  %Save the uicontrol handle to the specified field in the handles structure.
end
set(handles.editport,'enable','inactive');                                  %Disable the port editbox.
h = fliplr({'editslope','editbaseline'});                                   %Create the uicontrol handles field names for session information uicontrols.
l = fliplr({'Slope: ','Baseline: '});                                       %Create the labels for the uicontrols' string property.
u = fliplr({' gm/tick',' ticks'});                                          %Create the labels for the units uicontrols' string property.
x = x + sum(w) + sp;                                                        %Set the left edge of the uicontrols.
w = [0.2, 0.3, 0.15]*(pos(3) - 3*sp);                                       %Set the width of the following uicontrols.
for i = 1:2                                                                 %Step through the uicontrols.
    handles.label(end+1) = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',l{i},...
        'units','centimeters',...
        'position',[x, pos(4)-i*(sp+ui_h)-sp, w(1), ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','right',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
    temp = uicontrol(p,'style','edit',...
        'units','centimeters',...
        'string','-',...
        'position',[x+w(1), pos(4)-i*(sp+ui_h)-sp, w(2), ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','center',...
        'backgroundcolor','w');                                             %Create an editbox for entering in each parameter.
    handles.(h{i}) = temp;                                                  %Save the uicontrol handle to the specified field in the handles structure.
    handles.label(end+1) = uicontrol(p,'style','edit',...
        'enable','inactive',...
        'string',u{i},...
        'units','centimeters',...
        'position',[x+w(1)+w(2), pos(4)-i*(sp+ui_h)-sp, w(3)-sp, ui_h],...
        'fontweight','bold',...
        'fontsize',fontsize,...
        'horizontalalignment','left',...
        'backgroundcolor',label_color);                                     %Make a static text label for each uicontrol.
end

%Create a panel housing axes to show the calibration curve.
w = 0.7*(fig_pos(3) - 3*sp);                                                %Set the width of the following panel, in centimeters.
h = 0.8*(fig_pos(4) - pos(4) - 4*sp);                                       %Set the height of the following panel, in centimeters.
pos = [sp, fig_pos(4) - pos(4) - 2*sp - h, w, h];                           %Set the panel position.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',pos,...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create a panel to hold the calibration axes.
w = w - 3.5*sp;                                                             %Set the width of the following axes, in centimeters.
h = h - 3*sp;                                                               %Set the height of the following axes, in centimeters.
handles.cal_ax = axes('parent',p,...
    'units','centimeters',...
    'position',[sp + 0.1*w, sp + 0.1*h, 0.9*w, 0.9*h],...
    'box','on',...
    'xlim',[0,800],...
    'ylim',[0,800],...
    'fontsize',10);                                                         %Create the calibration curve axes.
xlabel(handles.cal_ax,'Loadcell Reading (ticks)','fontsize',10,...
    'fontweight','bold');                                                   %Set the x-axis label for the calibration curve.
ylabel(handles.cal_ax,'Force (gm)','fontsize',10,'fontweight','bold');      %Set the y-axis label for the calibration curve.

%Create a panel housing axes to show the calibration curve.
w = 0.7*(fig_pos(3) - 3*sp);                                                %Set the width of the following panel, in centimeters.
h = pos(2) - 2*sp;                                                          %Set the height of the following panel, in centimeters.
pos = [sp, sp, w, h];                                                       %Set the panel position.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',pos,...
    'fontweight','bold',...
    'fontsize',fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create the panel to hold the stream axes.
w = w - 3.5*sp;                                                             %Set the width of the following axes, in centimeters.
handles.stream_ax = axes('parent',p,...
    'units','centimeters',...
    'position',[sp + 0.1*w, sp, 0.9*w, h - 3*sp],...
    'box','on',...
    'xlim',[0,500],...
    'ylim',[0,1023],...
    'xtick',[],...
    'ytick',0:200:1000,...
    'fontsize',7);                                                          %Create the calibration curve axes.
ylabel(handles.stream_ax,'Loadcell','fontsize',10,'fontweight','bold');     %Set the x-axis label for the calibration curve.

%Create pushbuttons for saving and clearing calibration values.
x = 0.7*(fig_pos(3) - 3*sp) + 2*sp;                                         %Set the width of the following panel, in centimeters.
w = 0.3*(fig_pos(3) - 3*sp);                                                %Set the width of the following panel, in centimeters.
handles.savebutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','SAVE CALIBRATION',...
    'units','centimeters',...
    'position',[x, sp, w, ui_h],...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a calibration save button. 
if mode == 1                                                                %If the pull calibration was launched from the MotoTrak parent window...
    set(handles.savebutton,'string','SAVE AND EXIT');                       %Change the button text to say "SAVE AND EXIT".
end
handles.clearbutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','RESET TO PREVIOUS',...
    'units','centimeters',...
    'position',[x, 2*sp+ui_h, w, ui_h],...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a reset button.
handles.guidebutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','RUN VOICE GUIDE',...
    'units','centimeters',...
    'position',[x, 3*sp+2*ui_h, w, ui_h],...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a voice-guided calibration button.
handles.countbutton = uicontrol(handles.mainfig,'style','pushbutton',...
    'string','COUNTDOWN ON',...
    'units','centimeters',...
    'position',[x, 4*sp+3*ui_h, w, ui_h],...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'foregroundcolor',[0 0.5 0],...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Make a voice-guided calibration button.

%Create a panel housing the test weight buttons.
h = fig_pos(4) - 11*sp - 6*ui_h;                                            %Set the height of the following panel, in centimeters.
pos = [x, 5*sp+4*ui_h, w, h];                                               %Set the panel position.
p = uipanel(handles.mainfig,'units','centimeters',...
    'position',pos,...
    'title','Test Weights',...
    'fontweight','bold',...
    'fontsize',0.9*fontsize,...
    'backgroundcolor',get(handles.mainfig,'color'));                        %Create the panel to hold the test weight buttons.
h = h - (7+length(weights))*sp;                                             %Subtract some from the overall panel height.
ui_h = h/length(weights);                                                   %Calculate the height of buttons for the test wieghts.
handles.weightbutton = zeros(1,length(weights));                            %Create a field to hold handles for the test weight buttons.
handles.skipbutton = zeros(1,length(weights));                              %Create a field to hold handles for the voice-guided skip buttons.
w = (w - 3*sp);                                                             %Set the width of the buttons.
weights = sort(weights,'descend');                                          %Sort the weights in descending order.
for i = 1:length(weights)                                                   %Step through the weights.
    handles.weightbutton(i) = uicontrol(p,'style','pushbutton',...
        'string',[num2str(weights(i)) ' gm'],...
        'units','centimeters',...
        'position',[sp, i*sp+(i-1)*ui_h, 0.7*w, ui_h],...
        'fontweight','bold',...
        'fontsize',0.7*fontsize,...
        'userdata',weights(i),...
        'backgroundcolor',get(handles.mainfig,'color'));                    %Make a pause pushbutton.
    handles.skipbutton(i) = uicontrol(p,'style','pushbutton',...
        'string','VOICE',...
        'units','centimeters',...
        'position',[sp+0.7*w+sp , i*sp+(i-1)*ui_h, 0.3*w-sp, ui_h],...
        'fontweight','bold',...
        'fontsize',0.7*fontsize,...
        'userdata',weights(i),...
        'foregroundcolor',[0 0.5 0],...
        'backgroundcolor',get(handles.mainfig,'color'));                    %Make a pause pushbutton.
end
set(handles.weightbutton(end),'string','0 gm (Re-baseline)');               %Update the string on the 0 gram button.

handles.weights = sort(weights,'ascend');                                   %Save the weight values to the handles structure.


%% ***********************************************************************
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
%   09/13/2016 - Drew Sloan - Switch out MotoTrak-specific TSV Read/Write
%       functions for generalized versions compatible with OmniTrak.
%   01/09/2017 - Drew Sloan - Added support for ceiling values in stages.
%   12/31/2018 - Drew Sloan - Added special stage parameter handling for
%       the water reaching module.
%

global run                                                                  %Create a global run variable.

num_tones = 10;                                                             %Set the number of tones to make available.

%List the available column headings with stage structure fieldnames and default values.
params = {  'stage number',                             'number',               'required',         [];... 
            'description',                              'description',          'required',         [];...
            'input device',                             'device',               'required',         [];...
            'primary input device',                     'device',               'required',         [];...
            'position',                                 'pos',                  'required',         [];...
            'hit threshold - minimum',                  'threshmin',            'required',         [];...
            '1st input device',                         'device',               'optional',         5;...
            'secondary input device',                   'input2',               'optional',         5;...
            '2nd input device',                         'input2',               'optional',         5;...
            '3rd input device',                         'input3',               'optional',         0;...
            '4th input device',                         'input4',               'optional',         0;...
            '5th input device',                         'input5',               'optional',         0;...
            '6th input device',                         'input6',               'optional',         0;...            
            'constraint',                               'const',                'optional',         0;...            
            'hit threshold - type',                     'threshadapt',          'optional',         'static';...            
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
        
for i = 1:num_tones                                                         %Step through all of the available tones.
    params(end+1:end+4,:) = ...
        {   sprintf('tone %1.0f frequency',i),      	sprintf('tone_%1.0f_freq',i),       'optional',         1000;...
            sprintf('tone %1.0f duration',i),       	sprintf('tone_%1.0f_dur',i),        'optional',         50;...
            sprintf('tone %1.0f event',i),          	sprintf('tone_%1.0f_event',i),      'optional',         [];... 
            sprintf('tone %1.0f thresh',i),             sprintf('tone_%1.0f_thresh',i),     'optional',         []};  %Add stage parameter for each available tone.
end                                  

inputs = {  'pull',                     1;...
            'knob',                     6;...
            'lever',                    1;...
            'swipe sensor',             5;....
            'touch',                    1;...
            'both',                     1;...
            'capacitive sensor',        4;...
            'water reach',              3};                                 %Match the input devices to their stream input indices.
        
switch handles.stage_mode                                                   %Switch among the stage selection modes.
    case 1                                                                  %If stages are being loaded from a local TSV file.
        stage_file = 'MotoTrak_Stages.tsv';                                 %Set the default stage file name.
        file = [handles.mainpath stage_file];                               %Assume the stage file exists in the main program path.
        if ~exist(file,'file')                                              %If the stage file doesn't exist in the main program path...
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
                run = 0;                                                    %Set the run variable to 0.
                return                                                      %Skip execution of the rest of the function.
            end
            file = [path file];                                             %Add the directory to the located filename.
            temp = questdlg(['The file "' file '" will be copied to "'...
                handles.mainpath '" and will be renamed to '...
                '"MotoTrak_Stages.tsv" for future use.'],...
                'MOVING STAGE FILE','OK','Cancel','OK');                    %Show an OK/Cancel warning that the file will be moved.
            if isempty(temp) || strcmpi(temp,'cancel')                      %If the user closed the warning or pressed "Cancel"...
                run = 0;                                                    %Set the run variable to 0.
                return                                                      %Skip execution of the rest of the function.
            end
            copyfile(file,[handles.mainpath stage_file],'f');               %Copy the stage file to the main data path with the correct filename.
            delete(file);                                                   %Delete the stage file from it's original location.
        end
        stage_file = [handles.mainpath stage_file];                         %Add the main program path to the stage file name.       
        
        data = Vulintus_Read_TSV_File(stage_file);                          %Read in the data from the TSV file.
        
    case 2                                                                  %If stages are being loaded from an online google spreadsheet.
        try                                                                 %Try to read in the stage information from the web.
        	data = Read_Google_Spreadsheet(handles.stage_url);              %Read in the stage information from the Google Docs URL.      
            filename = [handles.mainpath 'Mototrak_Stages.tsv'];            %Set the filename for the stage backup file.
        	Vulintus_Write_TSV_File(data,filename);                         %Back up the stage information to a local TSV file.
        catch err                                                           %If there's an error...
            warning(['Read_Google_Spreadsheet:' err.identifier]',...
                err.message);                                               %Show a warning.
            stage_file = [handles.mainpath 'Mototrak_Stages.tsv'];          %Add the main program path to the stage file name.    
            data = Vulintus_Read_TSV_File(stage_file);                      %Read in the data from the TSV file.
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

for p = 1:size(params,1)                                                    %Now step through each parameter.
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
        if (isempty(stage(i).(params{p,2})) || ...
                any(isnan(stage(i).(params{p,2})))) && ...
                ~isempty(params{p,4})                                       %If no parameter value was specified and a default value exists...
            if strcmpi(params{p,4},'special case')                          %If the parameter default value is a special (i.e. conditional) case...
                switch lower(params{p,2})                                   %Switch between the special case parameters.
                    case 'threshtype'                                       %If the parameter is the Threshold Units...
                        switch lower(stage(i).device)                       %Switch between the device types.
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
                            case 'water reach'                              %For the water reach module...
                                stage(i).threshtype = ...
                                    'water reach (shaping)';                %Set the default threshold units to milliseconds holding.
                        end
                    case 'threshincr'                                       %If the parameter is the Hit Threshold Increment...
                        switch lower(stage(i).threshadapt)                  %Switch between the adaptation types.
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
            ~any(strcmpi(handles.custom,{'machado lab', 'touch/pull'}))     %If the initiation threshold is larger than the minimum hit threshold...
        stage(i).threshmin = stage(i).init;                                 %Set the minimum hit threshold to the initiation threshold.
    end
    if isfield(stage,'ir')                                                  %If an IR trial initiation mode was specified.
        stage(i).ir = strcmpi(stage(i).ir,'YES');                           %Convert the IR trial initiation mode to a binary value.
    end
    if ischar(stage(i).ceiling)                                             %If the threshold ceiling value is a string...
        stage(i).ceiling = NaN;                                             %Set the ceiling value to NaN.
    end
    stage(i).tones_enabled = 0;                                             %Assume that no tones will be enabled.
    for t = 1:num_tones                                                     %Step through all tone indices.
        fname = sprintf('tone_%1.0f_event',t);                              %Create the expected field name.
        if ~isempty(stage(i).(fname)) && ~any(isnan(stage(i).(fname)))      %If the user entered a value for at least one tone initiation event...
            stage(i).tones_enabled = 1;                                     %Indicate tones are enabled on the stage.
        end
    end
    stage(i).stream_order = zeros(1,6);                                     %Create a field to hold stream order.
    stage(i).stream_order(1) = ...
        inputs{strcmpi(stage(i).device,inputs(:,1)),2};                     %Set the primary data stream device index.
    for j = 2:6                                                             %Step through the secondary inputs...
        fname = sprintf('input%1.0f',j);                                    %Create the expected field name for the input.
        stage(i).stream_order(j) = stage(i).(fname);                        %Copy each input indice into the stream order field.
    end        
    if any(strcmpi(stage(i).device,{'both','touch'}))                       %If the device is specified as "both" or "touch"...
        stage(i).stream_order(2) = 4;                                       %Make sure the second input is the capacitive sensor.
    end
    if strcmpi(stage(i).device,'water reach')                               %For all water reaching stages...
        stage(i).device = 'water';                                          %Change the device name to simply "Water".
        stage(i).stream_order(2) = 2;                                       %Make sure the second input is the left capacitive sensor.
    end
end

if any(vertcat(stage.tones_enabled) == 1)                                   %If any stage has tones enabled...
    stage(1).tones = [];                                                    %Create a field for tones.
    for i = 1:length(stage)                                                 %Step through the stages.    
        if stage(i).tones_enabled == 1                                      %If tones are enabled for this stage...
            counter = 1;                                                    %Create a counter.
            for t = 1:num_tones                                             %Step through all tone indices.
                fname = sprintf('tone_%1.0f_event',t);                      %Create the expected field name for the tone initiation event.
                if ~isempty(stage(i).(fname)) && ...
                        ~any(isnan(stage(i).(fname)))                       %If the user entered a value for at least one tone initiation event...
                    stage(i).tones(counter).event = stage(i).(fname);       %Copy the tone event initiation type into the stage structure tone field.
                    fname = sprintf('tone_%1.0f_freq',t);                   %Create the expected field name for the tone frequency.
                    stage(i).tones(counter).freq = stage(i).(fname);        %Copy the tone frequency into the stage structure tone field.
                    fname = sprintf('tone_%1.0f_dur',t);                    %Create the expected field name for the tone duration.
                    stage(i).tones(counter).dur = stage(i).(fname);         %Copy the tone frequency into the stage structure tone field.
                    fname = sprintf('tone_%1.0f_thresh',t);                 %Create the expected field name for the tone initiation threshold.
                    stage(i).tones(counter).thresh = stage(i).(fname);      %Copy the tone initiation threshold into the stage structure tone field.
                    counter = counter + 1;                                  %Increment the counter.
                end
            end
        end
    end
end

for t = 1:num_tones                                                         %Step through all tone indices...
    fname = {sprintf('tone_%1.0f_freq',t),...
        sprintf('tone_%1.0f_dur',t),...
        sprintf('tone_%1.0f_event',t)};                                     %Create the list of fields to remove.
    stage = rmfield(stage,fname);                                           %Remove the redundant tone-related field names from the stage structure.
end
for i = 2:6                                                                 %Step through the secondary input fields.
    fname = sprintf('input%1.0f',i);                                        %Create the expected field name for the input.
    stage = rmfield(stage,fname);                                           %Remove the redundant tone-related field names from the stage structure.
end
            
handles.stage = stage;                                                      %Save the stage structure as a field in the handles structure.


%% ***********************************************************************
function [handles, trial] = MotoTrak_Reset_Trial_Data(handles,session,trial)

%
%MotoTrak_Reset_Trial_Data.m - Vulintus, Inc.
%
%   MOTOTRAK_RESET_TRIAL_DATA resets all trial variables at the start of a
%   session or following a completed trial to prepare monitoring for the
%   next trial initiation.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial variable reset sections from MotoTrak_Behavior_Loop.m.
%

trial.num = trial.num + 1;                                                  %Increment the trial counter.

trial.mon_signal(:) = 0;                                                    %Reset out the monitor signal.
trial.signal(:) = 0;                                                        %Reset out the trial signal.
if strcmpi(handles.device,'both')                                           %If this is a combined touch-pull stage...
    trial.touch_signal(:) = 0;                                              %Reset the touch signal.
end
trial.data(:) = 0;                                                          %Zero out the trial data.

trial.base_value = 0;                                                       %Reset the base value.
trial.ir_initiate = 0;                                                      %Reset the IR initiation flag.
trial.buffsize = session.buffsize;                                          %Set the trial buffsize to be the entire buffer size.
trial.ceiling_check = 0;                                                    %Reset the threshold ceiling flag.

if session.hitwin_tone_index > 0                                            %If a hit window tone is enabled...
    trial.hitwin_tone_on = 1;                                               %Set the value of the hit window tone flag to 1 to indicate it hasn't yet played.
else                                                                        %Otherwise...
    trial.hitwin_tone_on = 0;                                               %Set the value of the hit window tone flag to 0.
end
if session.hit_tone_index > 0                                               %If a hit tone is enabled...
    trial.hit_tone_on = 1;                                                  %Set the value of the hit tone flag to 1 to indicate it hasn't yet played.
else                                                                        %Otherwise...
    trial.hit_tone_on = 0;                                                  %Set the value of the hit tone flag to 0.
end
if session.miss_tone_index > 0                                              %If a miss tone is enabled...
    trial.miss_tone_on = 1;                                                 %Set the value of the miss tone flag to 1 to indicate it hasn't yet played.
else                                                                        %Otherwise...
    trial.miss_tone_on = 0;                                                 %Set the value of the miss tone flag to 0.
end


%% ***********************************************************************
function trial = MotoTrak_Reset_Trial_Plots(handles,session,trial)

%
%MotoTrak_Reset_Trial_Plots.m - Vulintus, Inc.
%
%   MOTOTRAK_RESET_TRIAL_PLOTS resets the streaming plots on the MotoTrak
%   GUI at the start of a session or following a completed trial to prepare
%   monitoring for the next trial initiation.
%   
%   UPDATE LOG:
%   05/02/2015 - Drew Sloan - Function first implemented, cutting existing
%       plot reset sections from MotoTrak_Behavior_Loop.m.
%


cla(handles.primary_ax);                                                    %Clear the primary streaming axes.
trial.plot_h = zeros(1,3);                                                  %Pre-allocate a matrix to hold plot handles.
trial.plot_h(1) = area(1:session.buffsize,trial.mon_signal,...
    'linewidth',2,...
    'facecolor',[0.5 0.5 1],...
    'parent',handles.primary_ax);                                           %Make an  areaseries plot.    
set(handles.primary_ax,'xtick',[],'ytick',[]);                              %Get rid of the x- and y-axis ticks.
trial.max_y = [-0.1,1.3]*handles.init;                                      %Calculate y-axis limits based on the trial initiation threshold.
ylim(handles.primary_ax,trial.max_y);                                       %Set the new y-axis limits.
xlim(handles.primary_ax,[1,session.buffsize]);                              %Set the x-axis limits according to the buffersize.
% x = 0.02*session.buffsize;                                                  %Set the x position of the IR signal text.
% y = trial.max_y(2)-0.03*range(trial.max_y);                                 %Set the y position of the IR signal text.
% trial.ir_text = text(x,y,'IR',...
%     'horizontalalignment','left',...
%     'verticalalignment','top',...
%     'margin',2,...
%     'edgecolor','k',...
%     'backgroundcolor','w',...
%     'fontsize',10,...
%     'fontweight','bold',...
%     'parent',handles.primary_ax);                                           %Create text to show the state of the IR signal.
x = 0.97*session.buffsize;                                                  %Set the x position of the clock text.
y = trial.max_y(2)-0.03*range(trial.max_y);                                 %Set the y position of the clock text.
str = sprintf('Session Time: %s', datestr(now - session.start,13));         %Create the text string.
trial.clock_text = text(x,y,str,...
    'horizontalalignment','right',...
    'verticalalignment','top',...
    'margin',2,...
    'edgecolor','k',...
    'backgroundcolor','w',...
    'fontsize',10,...
    'fontweight','bold',...
    'parent',handles.primary_ax);                                           %Create text to show a session timer.

switch lower(handles.device)                                                %Switch between the recognized device types.
    
    case 'both'                                                             %If the user selected combined touch-pull...
        trial.plot_h(3) = area(1:session.buffsize,trial.mon_signal,...
            'linewidth',2,...
            'facecolor',[0.5 1 0.5],...
            'parent',handles.secondary_ax);                                 %Make an initiation areaseries plot.
        line([1,session.buffsize],handles.init*[1,1],...
            'color','k',...
            'linestyle',':',...
            'parent',handles.secondary_ax);                                 %Plot a dotted line to show the threshold.
        text(1,handles.init,' Initiation Threshold',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'parent',handles.secondary_ax);                                 %Create text to label the the threshold line.        
        trial.max_y = [-1.3,1.3]*handles.init;                              %Calculate y-axis limits based on the trial initiation threshold.
        ylim(handles.secondary_ax,trial.max_y);                             %Set the new y-axis limits.
    
    otherwise                                                               %For all other device types...
        line([1,session.buffsize],handles.init*[1,1],...
            'color','k',...
            'linestyle',':',...
            'parent',handles.primary_ax);                                   %Plot a dotted line to show the threshold.
        text(1,1,' Initiation Threshold',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'parent',handles.primary_ax);                                   %Create text to label the the threshold line.
        trial.plot_h(3) = area(1:session.buffsize,session.buffer(:,3),...
            'linewidth',2,...
            'facecolor',[1 0.5 0.5],...
            'basevalue',session.minmax_ir(1),...
            'parent',handles.secondary_ax);                                 %Make an areaseries plot for the IR signal on the secondary axes.
        trial.ir_thresh_ln = ...
            line([1,session.buffsize],[1,1]*session.minmax_ir(3),...
            'color','k',...
            'linestyle',':',...
            'parent',handles.secondary_ax);                                 %Plot a dotted line to show the current IR threshold.
        trial.ir_thresh_txt = ...
            text(1,session.minmax_ir(3),' Initiation Threshold',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'parent',handles.secondary_ax);                                 %Create text to label the the threshold line.
        temp = session.minmax_ir(1:2);                                      %Grab the current historical minimum and maximum.
        if temp(1) > temp(2)                                                %If the 1st value is greater than the second...
            temp = [0, 1023];                                               %Set the infrared bounds to the maximum possible.
        elseif temp(1) == temp(2)                                           %If the 1st value equals the 2nd...
            temp = temp(1) + [-1,1];                                        %Add one above and below the single value.
        end
        temp = temp + [-0.1,0.1]*(temp(2) - temp(1));                       %Calculate y-axis limits.
        ylim(handles.secondary_ax,temp);                                    %Set the secondary axes y-axis limits.
end
set(handles.secondary_ax,'xtick',[],'ytick',[]);                            %Get rid of the x- y-axis ticks.
xlim(handles.secondary_ax,[1,session.buffsize]);                            %Set the secondary x-axis limits according to the buffersize.


%% ***********************************************************************
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


%% ***********************************************************************
function varargout = MotoTrak_Save_Error_Report(handles,msg)

%
%MotoTrak_Save_Error_Report.m - Vulintus, Inc.
%
%   MotoTrak_Save_Error_Report saves an error report ("msg") to a text file
%   in the \AppData\Local\Vulintus\MotoTrak\Error Reports\ directory.
%   
%   UPDATE LOG:
%   02/21/2017 - Drew Sloan - First function implementation.
%

clc;                                                                        %Clear the command line.
fprintf(1,'Generating MotoTrak error report...\n\n');                       %Print a line to show an error report is being generated.
if isa(msg,'MException')                                                    %If the message to send is an error exception...
    txt = getReport(msg,'extended');                                        %Get an extended report about the error.
    a = strfind(txt,'<a');                                                  %Find all hyperlink starts in the text.
    for i = length(a):-1:1                                                  %Step backwards through all hyperlink commands.
        j = find(txt(a(i):end) == '>',1,'first') + a(i) - 1;                %Find the end of the hyperlink start.
        txt(a(i):j) = [];                                                   %Kick out all hyperlink calls.
    end
    a = strfind(txt,'a>') + 1;                                              %Find all hyperlink ends in the text.
    for i = length(a):-1:1                                                  %Step backwards through all hyperlink commands.
        j = find(txt(1:a(i)) == '<',1,'last');                              %Find the end of the hyperlink end.
        txt(j:a(i)) = [];                                                   %Kick out all hyperlink calls.
    end
else                                                                        %Otherwise, if the message to send isn't an error exception...
    if iscell(msg)                                                          %If the message text is a cell array of strings.
        txt = sprintf('%s\n',msg{:});                                       %Convert the cell array to a continuous string.
    elseif ischar(msg)                                                      %Otherwise, if the message text is already a string...
        txt = msg;                                                          %Send the message text as-is.
    else                                                                    %Otherwise, for all other messages...
        return                                                              %Skip execution of the rest of the function.
    end    
end
err_path = [handles.mainpath 'Error Reports\'];                             %Create the expected directory name for the error reports.
if ~exist(err_path,'dir')                                                   %If the error report directory doesn't exist...
    mkdir(err_path);                                                        %Create the error report directory.
end
if isfield(handles,'variant')                                               %If this is a custom variant...
    source = upper(handles.variant);                                        %Set the source to the known variant.
else                                                                        %Otherwise...
    [~,source] = system('hostname');                                        %Use the computer hostname as the source.
end
filename = sprintf('%smototrak_error_report_%s.txt',...
    err_path, datestr(now,30));                                             %Create a filename for the error report.
fid = fopen(filename,'wt');                                                 %Open the file for writing as text.
fprintf(fid,'MotoTrak Error Report From %s\n', source);                     %Print the error source.
fprintf(fid,'Timestamp: %s\n',datestr(now,21));                             %Print a timestamp.
for i = 1:numel(txt)                                                        %Step through the error message text by character.
    fprintf(fid,txt(i),'%s');                                               %Print the error stack to the file.
    fprintf(1,txt(i),'%s');                                                 %Print the error stack to the command line as well.
end
fprintf(fid,'\n');                                                          %Print a carraige return to the file.
fields = fieldnames(handles);                                               %Grab all of the field names from the handles structure.
for i = 1:length(fields)                                                    %Step through each field.
    fprintf(fid,'handles.%s = ',fields{i});                                 %Print the field name.
    switch class(handles.(fields{i}))                                       %Switch between the possible field classes.
        case 'cell'                                                         %If the field is a cell array.
            fprintf(fid,'{');                                               %Print a left bracket.
            for k = 1:size(handles.(fields{i}),2)                           %Step through each column of the cell array.
                for j = 1:size(handles.(fields{i}),1)                       %Step through each row of the cell array.                
                    switch class(handles.(fields{i}){j,k})                  %Switch between the possible cell classes.
                        case 'char'                                         %If the cell is a character array...
                            fprintf(fid,'''%s''',handles.(fields{i}){j,k}); %Print the characters to the text file.
                        case {'single','double'}                            %If the cell is numeric...
                            fprintf(fid,'%1.4f',handles.(fields{i}){j,k});  %Print the values to the text file.
                        otherwise                                           %For all other classes...
                            fprintf(fid,'%s\n',...
                                class(handles.(fields{i}){j,k}));           %Print the cell class.
                    end
                    if j ~= size(handles.(fields{i}),2)                     %If this isn't the last entry in the row...
                        fprintf(fid,' ');                                   %Print a space to the text file.
                    end
                end
                if k == size(handles.(fields{i}),2)                         %If this was the last row in the array...
                    fprintf(fid,'}\n');                                     %Print a left bracket and a carriage return.
                else                                                        %Otherwise...
                    fprintf(fid,'\n\t');                                    %Print a carrage return and a tab.
                end
            end            
        case 'char'                                                         %If the field is a character array.
            fprintf(fid,'''%s''\n',handles.(fields{i}));                    %Print the characters to the text file.
        case {'single','double'}                                            %Otherwise, if the field is numeric...
            fprintf(fid,'[');                                               %Print a left bracket.
            for k = 1:size(handles.(fields{i}),2)                           %Step through each column of the cell array.
                for j = 1:size(handles.(fields{i}),1)                       %Step through each row of the cell array.                
                    fprintf(fid,'%1.4f',handles.(fields{i})(j,k));          %Print the values to the text file.
                    if j ~= size(handles.(fields{i}),2)                     %If this isn't the last entry in the row...
                        fprintf(fid,' ');                                   %Print a space to the text file.
                    end
                end
                if k == size(handles.(fields{i}),2)                         %If this was the last row in the array...
                    fprintf(fid,']\n');                                     %Print a left bracket and a carriage return.
                else                                                        %Otherwise...
                    fprintf(fid,'\n\t');                                    %Print a carrage return and a tab.
                end
            end            
        otherwise                                                           %For all other data types...
            fprintf(fid,'%s\n',class(handles.(fields{i})));                 %Print the field class.
    end
end
fclose(fid);                                                                %Close the error report file.
if nargout > 0                                                              %If the user requested the text of the error report file...
    fid = fopen(filename,'rt');                                             %Open the error report file for reading as text.
    varargout{1} = fread(fid,'*char')';                                      %Read in the data as characters.
    fclose(fid);                                                            %Close the error report file again.
end


%% ***********************************************************************
function [session, trial] = MotoTrak_Score_Hit(handles, session, trial)

%
%MotoTrak_Score_Hit.m - Vulintus, Inc.
%
%   MOTOTRAK_SCORE_HIT executes all operations associated with an animal
%   scoring a "Hit" during a behavioral session, including triggering
%   rewards, playing any enabled tones, and outputting any enabled 
%   stimulation triggers.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       hit operation sections from MotoTrak_Behavior_Loop.m.
%

trial.hit_time = now;                                                       %Save the current time as the hit time.
handles.ardy.trigger_feeder(1);                                             %Trigger feeding on the Arduino.
trial.feeds = trial.feeds + 1;                                              %Add one to the feedings counter.
% handles.ardy.play_hitsound(1);                                            %Play the hit sound.
if handles.stim == 1                                                        %If stimulation is enabled...
    handles.ardy.stim();                                                    %Trigger stimulation through the controller.
    trial.stim_time = now;                                                  %Save the current time as the hit time.
elseif handles.stim == 3                                                    %If we are in burst stim mode...                                
    elapsed_time = etime(datevec(now),...
        datevec(session.burst_time));                                       %Check to see if 5 minutes has elapsed since the start of the session.
    if (elapsed_time >= 300)                                                %If 5 min has elapsed, then we can pair this hit with a stim.
        if (session.burst_num < 3)                                        
            session.burst_time = now;                                       %Record the first stim time as now
            session.burst_num = ...
                session.burst_num + 1;                                      %Increment the burst stimulation counter.                                        
            handles.ardy.stim();                                            %Trigger the stimulator.
            trial.stim_time = session.burst_time;                           %Save the stimulation time so that it can be written out to the data file
        end                            
    end
else                                                                        %Otherwise...
    trial.stim_time = 0;                                                    %Set the stimulation time to zero.
end                          
if trial.hit_tone_on == 1                                                   %If a hit tone is enabled, but hasn't yet been played...
    handles.ardy.play_tone(session.hit_tone_index);                         %Start the tone.
    trial.hit_tone_on = 2;                                                  %Set the hit tone flag to 2 to indicate it is currently playing.
    trial.miss_tone_on = 0;                                                 %Set the miss tone flag to 0 to disable it.
elseif trial.hitwin_tone_on == 2                                            %Otherwise, if a hit window tone is enabled and currently playing...
    handles.ardy.stop_tone();                                               %Stop the hit window tone.
    trial.hitwin_tone_on = 0;                                               %Set the hit window tone flag to zero.
end
trial.ln(3) = line(trial.cur_sample*[1,1],trial.max_y,...
    'color',[0.5 0 0],...,
    'linewidth',2,...
    'parent',handles.primary_ax);                                           %Plot a line to show where the hit occurred at the current sample.


%% ***********************************************************************
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
    'value',0.25);                                                          %Create a waitbar figure.

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
waitbar.string('Identifying MotoTrak controllers...');                      %Update the waitbar text.
waitbar.value(0.50);                                                        %Update the waitbar value.

key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB\';              %Set the registry query field.
[~, txt] = dos(['REG QUERY ' key ' /s /f "FriendlyName" /t "REG_SZ"']);     %Query the registry for all USB devices.
checker = ones(numel(port),1);                                              %Create a check matrix to identify Arduino Unos.
for i = 1:numel(port)                                                       %Step through each port name.
    j = strfind(txt,['(' port{i} ')']);                                     %Find the port in the USB device list.
    if isempty(i) || ~strcmpi(txt(j-12:j-2),'Arduino Uno')                  %If the device isn't an Arduino Uno.
        checker(i) = 0;                                                     %Mark the device for exclusion.
    end
end
port(checker == 0) = [];                                                    %Kick out all non-Arduino devices from the ports list.
busyports = intersect(port,busyports);                                      %Kick out all non-Arduino devices from the busy ports list.

if waitbar.isclosed()                                                       %If the user closed the waitbar figure...
    errordlg('Connection to MotoTrak was cancelled by the user!',...
        'Connection Cancelled');                                            %Show an error.
    port = [];                                                              %Set the function output to empty.
    return                                                                  %Skip execution of the rest of the function.
end
waitbar.string('Matching ports to booth assignments...');                   %Update the waitbar text.
waitbar.value(0.75);                                                        %Update the waitbar value.

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


%% ***********************************************************************
function MotoTrak_Send_Error_Report(handles,target,msg)

%
%MotoTrak_Send_Error_Report.m - Vulintus, Inc.
%
%   MotoTrak_Send_Error_Report sends an error report ("msg") by email to 
%   the specified recipient ("target") through the Vulintus dummy 
%   error-reporting account.
%   
%   UPDATE LOG:
%   10/12/2016 - Drew Sloan - First function implementation.
%   10/13/2016 - Drew Sloan - Added support for general string and cell
%       array message inputs instead of just MException objects.
%

if handles.enable_error_reporting == 0                                      %If remote error reporting is disabled...
    return                                                                  %Skip execution of the rest of the function.
end
if isa(msg,'MException')                                                    %If the message to send is an error exception...
    txt = getReport(msg,'extended');                                        %Get an extended report about the error.
    a = strfind(txt,'<a');                                                  %Find all hyperlink starts in the text.
    for i = length(a):-1:1                                                  %Step backwards through all hyperlink commands.
        j = find(txt(a(i):end) == '>',1,'first') + a(i) - 1;                %Find the end of the hyperlink start.
        txt(a(i):j) = [];                                                   %Kick out all hyperlink calls.
    end
    a = strfind(txt,'a>') + 1;                                              %Find all hyperlink ends in the text.
    for i = length(a):-1:1                                                  %Step backwards through all hyperlink commands.
        j = find(txt(1:a(i)) == '<',1,'last');                              %Find the end of the hyperlink end.
        txt(j:a(i)) = [];                                                   %Kick out all hyperlink calls.
    end
else                                                                        %Otherwise, if the message to send isn't an error exception...
    if iscell(msg)                                                          %If the message text is a cell array of strings.
        txt = sprintf('%s\n',msg{:});                                       %Convert the cell array to a continuous string.
    elseif ischar(msg)                                                      %Otherwise, if the message text is already a string...
        txt = msg;                                                          %Send the message text as-is.
    else                                                                    %Otherwise, for all other messages...
        return                                                              %Skip execution of the rest of the function.
    end    
end
if isfield(handles,'variant')                                               %If this is a custom variant...
    source = upper(handles.variant);                                        %Set the source to the known variant.
else                                                                        %Otherwise...
    [~,source] = system('hostname');                                        %Use the computer hostname as the source.
end
subject = sprintf('MotoTrak Error Report From %s', source);                 %Create a subject line.
subject(subject < 32) = [];                                                 %Kick out all special characters from the subject line.
if isdeployed                                                               %If this is deployed code...
    [~, result] = system('path');                                           %Grab the current environmental path variable.
    path = char(regexpi(result, 'Path=(.*?);', 'tokens', 'once'));          %Find the directory pertaining to the current compiled program.
    program = [path '\subfuns\vulintus_send_error_report.exe'];             %Add the full path to the error-reporting program name.    
    cmd = sprintf('"%s" "%s" "%s" "%s"',program,target,subject,txt);        %Create a command-line call for the error-reporting program.
    fprintf(1,'Reporting MotoTrak error to %s\n',target);                   %Show that the error reporting program is being run on the command line.
    [~, cmdout] = system(cmd);                                              %Call the error reporting program.
    fprintf(1,'\t%s\n',cmdout);                                             %Return any reply to the command line.
else                                                                        %Otherwise, if the code isn't deployed...
    Vulintus_Send_Error_Report(target,subject,txt);                         %Use the common subfunction to send the error report.
end


%% ***********************************************************************
function handles = MotoTrak_Set_Callbacks(handles)

%
%MotoTrak_Set_Callbacks.m - Vulintus, Inc.
%
%   This function sets the callbacks for all user interface objects that
%   are active during idle mode.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added disabling of uinmenu objects.
%   01/09/2017 - Drew Sloan - Updated global run variable values.
%   02/21/2017 - Drew Sloan - Added a callback for opening the error report
%       directory from the preferences menu.
%


%Set the uicontrol callbacks.
set(handles.editrat,'callback',@MotoTrak_Edit_Rat,'string',[]);             %Set the callback for the rat name editbox.
set(handles.editbooth,'callback',@MotoTrak_Edit_Booth);                     %Set the callback for the booth number editbox.
set(handles.popstage,'callback','global run; run = 1.1;');                  %Set the callback for the stage pop-up menu.
set(handles.pausebutton,'callback','global run; run = 2.2;')                %Set the callback for the Pause button.

%Set the figure callbacks.
set(handles.mainfig,'CloseRequestFcn','global run; run = 0;');              %Set the callback for when the user tries to close the GUI.

%Set the uimenu callbacks.
set(handles.menu.stages.view_spreadsheet,...
    'callback',{@MotoTrak_Open_Google_Spreadsheet,handles.stage_url});      %Set the callback for the "Open Spreadsheet" submenu option.
set(handles.menu.pref.set_datapath,...
    'callback',@MotoTrak_Set_Datapath);                                     %Set the callback for the "Set Datapath" submenu option.
set([handles.menu.pref.err_report_on,handles.menu.pref.err_report_off],...
    'callback',@Mototrak_Set_Error_Reporting);                              %Set the callback for turning off/on automatic error reporting.
set(handles.menu.pref.error_reports,...
    'callback',@Mototrak_Open_Error_Reports);                               %Set the callback for opening the error reports directory.
set(handles.menu.pref.config_dir,...
    'callback',@Mototrak_Open_Configuration_Directory);                     %Set the callback for opening the configuration directory.
set(handles.menu.cal.open_calibration,'callback','global run; run = 3;');   %Set the callback for the the "Open Calibration" option.
set(handles.menu.cal.reset_baseline,'callback','global run; run = 1.4;');   %Set the callback for the "Reset Baseline" option.


%% ***********************************************************************
function session = MotoTrak_Set_Custom_Parameters(handles, session)

%
%MotoTrak_Set_Custom_Parameters.m - Vulintus, Inc.
%
%   MOTOTRAK_SET_CUSTOM_PARAMETERS sets various session parameters that are
%   specific to individual labs.
%   
%   UPDATE LOG:
%   05/02/2015 - Drew Sloan - Function first implemented, cutting existing
%       sections from MotoTrak_Behavior_Loop.m.
%

if isfield(handles,'custom')                                                %If the handles structure has a custom field...
    switch lower(handles.custom)                                            %Switch between the various recognized variants.
        case {'machado lab', 'touch/pull'}                                  %Touch/Pull customization.        
            if handles.stim == 1 && ...
                    strcmpi(handles.curthreshtype,'milliseconds/grams')     %If stimulation is on and this is a touch/pull stage...
                temp = round(1000*handles.hitwin);                          %Find the length of the hit window in milliseconds.
                handles.ardy.set_stim_dur(temp);                            %Set the default stimulation duration to the entire hit window.
                session.stim_time_out = ...
                    round(1000*handles.stim_time_out/...
                    handles.stage(handles.cur_stage).period) - 1;           %Calculate the number of samples in the stimulation time-out duration.
            end
    end
end


%% ***********************************************************************
function MotoTrak_Set_Datapath(hObject,~)

handles = guidata(hObject);                                                 


%% ***********************************************************************
function MotoTrak_Set_Stream_Params(handles)

%This function sets the streaming parameters on the Arduino.

handles.ardy.set_stream_period(handles.period);                             %Set the stream period on the Arduino.
if handles.ardy.version >= 2.00                                             %If the controller sketch version is 2.00 or newer...
    inputs = handles.stage(handles.cur_stage).stream_order;                 %Copy over the inputs.
%     fprintf(1,'STREAM ORDER = ');
    for i = 1:numel(inputs)                                                 %Step through each input.
%         fprintf(1,'%1.0f\t',inputs(i)); 
        handles.ardy.set_stream_input(i,inputs(i));                         %Set each input.
    end
%     fprintf(1,'\n');
end


%% ***********************************************************************
function MotoTrak_Set_Tone_Parameters(h)

%
%MotoTrak_Set_Tone_Parameters.m - Vulintus, Inc.
%
%   This function updates any enabled tone parameters on the MotoTrak
%   controller whenever a stage is loaded or the user changed the
%   calibration functions.
%
%   UPDATE LOG:
%   04/30/2018 - Drew Sloan - First function implementation.
%

for i = 1:h.max_num_tones                                                   %Step through each existing tone...
    h.ardy.set_tone_index(i);                                               %Set the tone index.
    h.ardy.set_tone_trig_type(0);                                           %Set the tone initiation type to Matlab-triggered. 
end

if h.stage(h.cur_stage).tones_enabled ~= 1                                  %If no tones are enabled for this stage...
    return                                                                  %Skip execution of the rest of the function.
end

for i = 1:numel(h.stage(h.cur_stage).tones)                                 %Step through each specified tone.        
    h.ardy.set_tone_index(i);                                               %Set the tone index.
    h.ardy.set_tone_freq(h.stage(h.cur_stage).tones(i).freq);               %Set the tone frequency.
    if strcmpi(h.stage(h.cur_stage).tones(i).event,'hitwindow')             %If the tone event is the hit window...
        h.ardy.set_tone_dur(30000);                                         %Set the tone duration to 30 seconds.
    else                                                                    %Otherwise...
        h.ardy.set_tone_dur(h.stage(h.cur_stage).tones(i).dur);             %Set the specified tone duration.
    end
    if any(strcmpi(h.stage(h.cur_stage).tones(i).event,...
            {'rising','falling'}))                                          %Is the initiation event is any of the automatically triggered types...
        if isnumeric(h.stage(h.cur_stage).tones(i).thresh) && ...
                ~isnan(h.stage(h.cur_stage).tones(i).thresh)                %If the user inputted a numeric value for the threshold...
            thresh = h.stage(h.cur_stage).tones(i).thresh;                  %Grab the user-specified threshold.
            thresh = round((thresh/h.slope) + h.baseline);                  %Calculate the threshold as a controller analog-read value.
            h.ardy.set_tone_trig_thresh(thresh);                            %Set the tone initiation threshould on the controller.
            switch lower(h.device)                                          %Switch between the recognized device types.
                case {'pull','lever'}                                       %For the isometric pull or the analog lever..
                    h.ardy.set_tone_mon_input(1);                           %Set the monitored input to 1.
                    switch lower(h.stage(h.cur_stage).tones(i).event)       %Switch between the recognized tone initiation event types.
                        case 'rising'                                       %If the user specified a rising edge threshold...
                            h.ardy.set_tone_trig_type(1);                   %Set the tone initiation to rising-edge.                                  
                        case 'falling'                                      %If the user specified a falling edge threshold...
                            h.ardy.set_tone_trig_type(2);                   %Set the tone initiation to falling-edge.  
                    end        
                case 'knob'                                                 %For the supination knob...
                    h.ardy.set_tone_mon_input(6);                           %Set the monitored input to 6.
                    switch lower(h.stage(h.cur_stage).tones(i).event)       %Switch between the recognized tone initiation event types.
                        case 'rising'                                       %If the user specified a rising edge threshold...
                            h.ardy.set_tone_trig_type(2);                   %Set the tone initiation to falling-edge (calibration reverses signal).                                  
                        case 'falling'                                      %If the user specified a falling edge threshold...
                            h.ardy.set_tone_trig_type(1);                   %Set the tone initiation to rising-edge (calibration reverses signal).    
                    end        
            end                
        else                                                                %Otherwise...
            h.ardy.set_tone_trig_type(0);                                   %Set the tone initiation to Matlab-triggered.
        end
    else                                                                    %Otherwise, for all other initiation types...
        h.ardy.set_tone_trig_type(0);                                       %Set the tone initiation to Matlab-triggered.
    end
end


%% ***********************************************************************
function MotoTrak_Update_Clock_Test(session,trial)

%
%MotoTrak_Update_Clock_Test.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_CLOCK_TEST updates the clock text object on the
%   MotoTrak GUI showing the current session time.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       clock update sections from MotoTrak_Behavior_Loop.m.
%

x = 0.97*session.buffsize;                                                  %Calculate the x position of the clock text.
y = trial.max_y(2)-0.03*range(trial.max_y);                                 %Calculate the y position of the clock text.
str = sprintf('Session Time: %s', datestr(now - session.start,13));         %Create the text string.
set(trial.clock_text,...
    'position',[x,y],...
    'string',str);                                                          %Update the session timer text object.
if now > session.end                                                        %If the suggested session time has passed...
    set(trial.clock_text,'backgroundcolor','r');                            %Color the session timer text object red.
end


%% ***********************************************************************
function handles = MotoTrak_Update_Controls_Within_Session(handles)

%
%MotoTrak_Update_Controls_Within_Session.m - Vulintus, Inc.
%
%   This function disables all of the uicontrol and uimenu objects that 
%   should not be active while MotoTrak is running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added disabling of uimenu objects.
%   10/13/2016 - Drew Sloan - Added disabling of the preferences menu.
%   05/01/2018 - Drew Sloan - Moved GUI settings from the start of 
%       MotoTrak_Behavior_Loop to this function and renamed the function 
%       from:
%           "MotoTrak_Disable_Controls_Within_Session"
%       to:
%           "MotoTrak_Update_Controls_Within_Session"
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
set(handles.menu.stages.h,'enable','off');                                  %Disable the stages menu.
set(handles.menu.pref.h,'enable','off');                                    %Disable the preferences menu.
set(handles.menu.cal.h,'enable','off');                                     %Disable the calibration menu.

%Change the Start/Stop button to stop mode.
set(handles.startbutton,'string','STOP',...
   'foregroundcolor',[0.5 0 0],...
   'callback','global run; run = 1;')                                       %Set the string and callback for the Start/Stop button.
set(handles.feedbutton,'callback','global run; run = 2.2;')                 %Set the callback for the Manual Feed button.

%Add a tab for a hit rate plot if it doesn't already exist.
if ~isfield(handles,'hitrate_tab')                                          %If there is no tab yet for session hit rate axes...
    handles.hitrate_tab = uitab('parent',handles.plot_tab_grp,...
        'title','Session Hit Rate',...
        'backgroundcolor',get(handles.mainfig,'color'));                    %Create a tab for the trial-by-trial hit rate.

end
if ~isfield(handles,'hitrate_ax')                                           %If there is no axes yet for session hit rate...
    handles.hitrate_ax = axes('parent',handles.hitrate_tab,...
        'units','normalized',...
        'position',[0 0 1 1],...
        'box','on',...
        'xtick',[],...
        'ytick',[]);                                                        %Create the trial hit rate axes.
end
cla(handles.hitrate_ax);                                                    %Clear the hit rate axes.

% %Add a tab for session performance plots if it doesn't already exist.
% if ~isfield(handles,'session_tab')                                          %If there is no tab yet for session performance measures...
%     handles.session_tab = uitab('parent',handles.plot_tab_grp,...
%         'title','Session Performance',...
%         'backgroundcolor',get(handles.mainfig,'color'));                    %Create a tab for the performance measure axes.
% end
% if ~isfield(handles,'session_ax')                                           %If there's no axes yet for session performance measures.
%     handles.session_ax = axes('parent',handles.session_tab,...
%         'units','normalized',...
%         'position',[0 0 1 1],...
%         'box','on',...
%         'xtick',[],...
%         'ytick',[]);                                                        %Create the performance measure axes.
% end
% cla(handles.session_ax);                                                    %Clear the hit rate axes.

% switch handles.curthreshtype                                                %Switch between the recognized threshold types.
%     case {'degrees (total)', 'bidirectional'}                               %If the threshold type is the total number of degrees...
%         set(handles.session_tab,'title','Trial Peak Angle');                %Set the performance axes to display trial spin velocity.
%     case 'degrees/s'                                                        %If the threshold type is the number of spins or spin velocity.
%         set(handles.session_tab,'title','Trial Spin Velocity');             %Set the performance axes to display trial spin velocity.
%     case '# of spins'                                                       %If the threshold type is the number of spins or spin velocity.
%         set(handles.session_tab,'title','Trial Number of Spins');           %Set the performance axes to display trial number of spins.
%     case {'grams (peak)', 'grams (sustained)','milliseconds/grams'}         %If the threshold type is a variant of peak pull force.
%         set(handles.session_tab,'title','Trial Peak Force');                %Set the performance axes to display trial peak force.
%     case {'presses', 'fullpresses'}                                         %If the threshold type is presses or full presses..
%         set(handles.session_tab,'title','Trial Press Counts');              %Set the performance axes to display trial press counts.
%     case 'milliseconds (hold)'                                              %If the threshold type is a hold...
%         set(handles.session_tab,'title','Trial Hold Time');                 %Set the performance axes to display trial hold times.
% end        

hold(handles.hitrate_ax, 'off');                                            %Release any plot hold on the trial hit rate axes.
cla(handles.hitrate_ax);                                                    %Clear any plots off the trial hit rate axes.
text(0,0,'Waiting for first trial...',...
    'fontsize',12,...
    'verticalalignment','middle',...
    'horizontalalignment','center',...
    'parent',handles.hitrate_ax);                                           %Plot text to show no trials have started yet.
set(handles.hitrate_ax,'xlim',[-1,1],...
    'ylim',[-1,1],...
    'xtick',[],...
    'ytick',[]);                                                            %Set the bounds and clear the tick marks from the hit rate axes.
% hold(handles.performance_ax, 'off');                                        %Release any plot hold on the trial performance measure axes.
% cla(handles.performance_ax);                                                %Clear any plots off the trial hperformance measure axes.

drawnow;                                                                    %Immediately update the figure.


%% ***********************************************************************
function session = MotoTrak_Update_IR_Bounds(handles,session)

%
%MotoTrak_Update_IR_Bounds.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_IR_BOUNDS updates the minimum and maximum historical
%   infrared sensor values, and adjusts the infrared sensor threshold
%   accordingly.
%   
%   UPDATE LOG:
%   05/02/2015 - Drew Sloan - Function first implemented, cutting existing
%       IR update sections from MotoTrak_Behavior_Loop.m.
%   01/11/2019 - Drew Sloan - Added different IR range thresholds for when
%       it's okay to set the IR initiation threshold for the beam- and
%       bounce-type detectors.
%

switch lower(handles.ir_detector)                                           %Switch between the different types of IR detector.
    case 'beam'                                                             %For the beam-type detector...
        activation_threshold = 100;                                         %Set the activation threshold to 100.
    case 'bounce'                                                           %For the bounce-type detector...
        activation_threshold = 25;                                          %Set the activation threshold to 25.
end

session.minmax_ir(1) = min([session.minmax_ir(1); session.buffer(:,3)]);    %Calculate a new minimum IR value.
session.minmax_ir(2) = max([session.minmax_ir(2); session.buffer(:,3)]);    %Calculate a new maximum IR value.
if session.minmax_ir(2) - session.minmax_ir(1) >= activation_threshold      %If the IR value range is greater than the activation threshold.
    session.minmax_ir(3) = ...
        handles.ir_initiation_threshold*(session.minmax_ir(2) - ...
        session.minmax_ir(1)) + session.minmax_ir(1);                       %Set the IR threshold to the specified relative threshold.
elseif session.minmax_ir(1) == session.minmax_ir(2)                         %If there is no range in the IR values.
    session.minmax_ir(1) = session.minmax_ir(1) - 1;                        %Set the IR minimum to one less than the current value.
end


%% ***********************************************************************
function trial = MotoTrak_Update_Monitor_Plots(handles,session,trial)

%
%MotoTrak_Update_Monitor_Plots.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_MONITOR_PLOTs plots new streaming data from the
%   MotoTrak controller to the streaming plots on the MotoTrak GUI during
%   inter-trial idle periods.
%   
%   UPDATE LOG:
%   05/02/2015 - Drew Sloan - Function first implemented, cutting existing
%       monitored signal stream read sections from 
%       MotoTrak_Behavior_Loop.m.
%

cur_tab = handles.plot_tab_grp.SelectedTab.Title;                           %Grab the currently selected tab title.
if strcmpi(handles.device,'both')                                           %If this is a combined touch-pull session...
    set(trial.plot_h(1),'ydata',session.buffer(:,2));                       %Update the force area plot.
    trial.max_y = ...
        [min([1.1*min(session.buffer(:,2)), -0.1*trial.thresh]),...
        max([1.1*max(session.buffer(:,2)), 1.3*trial.thresh])];             %Calculate new y-axis limits.
    ylim(handles.primary_ax,trial.max_y);                                   %Set the new y-axis limits.
    set(trial.plot_h(3),'ydata',trial.mon_signal);                          %Update the touch area plot.
    trial.max_y = ...
        [min([1.1*min(trial.mon_signal), -1.1*handles.init]),...
        max([1.1*max(trial.mon_signal), 1.1*handles.init])];                %Calculate new y-axis limits.
    ylim(handles.secondary_ax,trial.max_y);                                 %Set the new y-axis limits.
else                                                                        %Otherwise...
    switch lower(cur_tab)                                                   %Switch between the tabs...
        case {'supination angle',...
                'pull force',...
                'lever angle'}                                              %If the selected tab is the primary signal...
            set(trial.plot_h(1),'ydata',trial.mon_signal);                  %Update the area plot.
            trial.max_y = ...
                [min([1.1*min(trial.mon_signal), -0.1*trial.thresh]),...
                max([1.1*max(trial.mon_signal), 1.3*trial.thresh])];        %Calculate new y-axis limits.
            ylim(handles.primary_ax,trial.max_y);                           %Set the new y-axis limits.            
        case 'swipe sensor'                                                 %If the selected tab is the secondary signal...
            set(trial.plot_h(3),'ydata',session.buffer(:,3),...
                'basevalue',session.minmax_ir(1));                          %Update the IR signal plot.
            set(trial.ir_thresh_ln,'ydata',[1,1]*session.minmax_ir(3));     %Update the threshold line.
            set(trial.ir_thresh_txt,'position',[1,session.minmax_ir(3)]);   %Update the threshold line label.
            temp = session.minmax_ir(1:2);                                  %Grab the current historical minimum and maximum.
            if temp(1) > temp(2)                                            %If the 1st value is greater than the second...
                temp = [0, 1023];                                           %Set the infrared bounds to the maximum possible.
            elseif temp(1) == temp(2)                                       %If the 1st value equals the 2nd...
                temp = temp(1) + [-1,1];                                    %Add one above and below the single value.
            end
            temp = temp + [-0.1,0.1]*(temp(2) - temp(1));                   %Calculate y-axis limits.
            ylim(handles.secondary_ax,temp);                                %Set the secondary axes y-axis limits.
    end    
end


%% ***********************************************************************
function [session, trial] = MotoTrak_Update_Monitor_Signal(handles,session,trial)

%
%MotoTrak_Update_Monitor_Signal.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_MONITOR_SIGNAL checks the MotoTrak controller for new
%   streaming data, and adds any new data it finds to the trial initiation
%   monitored signal.
%   
%   UPDATE LOG:
%   05/01/2018 - Drew Sloan - Function first implemented, cutting existing
%       monitored signal stream read sections from 
%       MotoTrak_Behavior_Loop.m.
%   05/02/2018 - Drew Sloan - Added the new sample count as an output
%       argument.
%   12/31/2018 - Drew Sloan - Added initial monitored signal calculations
%       for shaping on the water reaching module.
%

new_data = handles.ardy.read_stream();                                      %Read in any new stream output.
trial.N = size(new_data,1);                                                 %Find the number of new samples.

if trial.N == 0                                                             %If there's no new data...
    return                                                                  %Skip the rest of the function.
end
    
% for i = 1:N                                                               %Step through each new sample.
%     fprintf(1,'STREAM:\t%1.0f\t%1.0f\t%1.0f\n',new_data(i,:));            %Print the new data to the command line.
% end

new_data(:,2) = session.cal(1)*(new_data(:,2) - session.cal(2));            %Apply the calibration constants to the data signal.
session.buffer(1:end-trial.N,:) = ...
    session.buffer(trial.N+1:end,:);                                        %Shift the existing buffer samples to make room for the new samples.

try                                                                         %Attempt to add new samples to the buffer.
    session.buffer(end-trial.N+1:end,:) = new_data;                         %Add the new samples to the buffer.
catch err                                                                   %If an error occurred...
    txt = getReport(err,'extended');                                        %Get an extended report about the error.
    a = strfind(txt,'<a');                                                  %Find all hyperlink starts in the text.
    for i = length(a):-1:1                                                  %Step backwards through all hyperlink commands.
        j = find(txt(a(i):end) == '>',1,'first') + a(i) - 1;                %Find the end of the hyperlink start.
        txt(a(i):j) = [];                                                   %Kick out all hyperlink calls.
    end
    a = strfind(txt,'a>') + 1;                                              %Find all hyperlink ends in the text.
    for i = length(a):-1:1                                                  %Step backwards through all hyperlink commands.
        j = find(txt(1:a(i)) == '<',1,'last');                              %Find the end of the hyperlink end.
        txt(j:a(i)) = [];                                                   %Kick out all hyperlink calls.
    end
    txt = horzcat(txt,...
        sprintf('\n\nsize(session.buffer) = [%1.0f, %1.0f]',...
        size(session.buffer)));                                             %Add the size of the data variable to the text.
    txt = horzcat(txt,...
        sprintf('\n\na = %1.3f\n\nnew_data = \n',a));                       %Add the value of the a variable.
    for i = 1:trial.N                                                       %Step through each line of the temp variable.
        txt = horzcat(txt,sprintf('%1.3f ',new_data(i,:)),10);              %Add the value of the a variable.
    end
    txt = MotoTrak_Save_Error_Report(handles,txt);                          %Save a copy of the error in the AppData folder.
    MotoTrak_Send_Error_Report(handles,handles.err_rcpt,txt);               %Send an error report to the specified recipient.                
end

if session.do_once == 1                                                     %If this was the first stream read...
    session.buffer(1:session.buffsize-trial.N,2) = ...
        session.buffer(session.buffsize-trial.N+1,2);                       %Set all of the preceding signal data points equal to the first point.           
    session.buffer(1:session.buffsize-trial.N,3) = ...
        session.buffer(session.buffsize-trial.N+1,3);                       %Set all of the preceding IR data points equal to the first point.    
    session.do_once = 0;                                                    %Set the checker variable to 1.
end
trial.mon_signal(1:end-trial.N,:) = trial.mon_signal(trial.N+1:end);        %Shift the existing samples in the monitored to make room for the new samples.

new_samples = session.buffsize-trial.N+1:session.buffsize;                  %Grab the indices for the new samples.

switch handles.curthreshtype                                                %Switch between the types of hit threshold.

    case 'degrees (total)'                                                  %If the theshold type is the total number of degrees.                
        if handles.cur_stage == 1 && strcmpi(handles.device, 'knob')        %If this is the first stage...
            trial.mon_signal(new_samples) = ...
                session.buffer(new_samples,2) - ...
                session.buffer(new_samples-session.hit_samples+1,2);        %Find the change in the degrees integrated over the hit window.
        else                                                                %Otherwise, for all other stages...
            trial.mon_signal(new_samples) = ...
                session.buffer(new_samples,2);                              %Find the change in the degrees integrated over the hit window
        end

    case 'bidirectional'                                                    %If the threshold type is the bidirectional number of degrees...
        trial.mon_signal(new_samples) = ...
            abs(session.buffer(new_samples,2));                             %Find the change in the degrees integrated over the hit window.

    case {'presses', 'fullpresses'}                                         %If the current threshold type is presses (for LeverHD)
        if strcmpi(handles.device, 'knob')
              trial.mon_signal(new_samples) = ...
                  abs(session.buffer(new_samples,2) - ...
                  session.buffer(new_samples-session.hit_samples+1,2));     %Calculate the degrees turned in the hit window.
        else                                                                %If the device is a lever.
            presses_signal = ...
                session.buffer(:, 2) - session.min_peak_val;                %Subtract the minimum peak value from the entire signal.
            negative_bound = ...
                0 - (session.min_peak_val - session.lever_return_pt);       %Set the negative bound.

            presses_signal(presses_signal > 0) = 1;                         %Find all indices for points greater than the minimum peak value.
            presses_signal((presses_signal <= 0) & (presses_signal >= negative_bound)) = 0; 
            presses_signal(presses_signal < negative_bound) = -1;

            original_indices = find(presses_signal ~= 0);
            modified_presses_signal = presses_signal(presses_signal ~= 0);
            modified_presses_signal(modified_presses_signal < 0) = 0;

            diff_presses_signal = [0; diff(modified_presses_signal)];

            trial.mon_signal(1:end) = 0;
            trial.mon_signal(original_indices(diff_presses_signal == 1)) = 1;
            trial.mon_signal(1:(session.buffsize-trial.N)) = 0;
        end

    case {'grams (peak)', 'grams (sustained)'}                              %If the current threshold type is the peak pull force.
        if strcmpi(handles.stage(handles.cur_stage).number,'PASCI1')        %If the current stage is PASCI1...
            trial.mon_signal(new_samples) = ...
                abs(session.buffer(new_samples,2));                         %Show the pull force at each point.
        else                                                                %Otherwise, for all other stages.
            trial.mon_signal(new_samples) = ...
                session.buffer(new_samples,2);                              %Show the pull force at each point.
        end

    case 'milliseconds (hold)'                                              %If the current threshold type is a sustained hold...
        trial.mon_signal(new_samples) = ...
            (session.buffer(new_samples,3) > 511.5);                        %Digitize the threshold.

    case 'water reach (shaping)'                                            %If the current threshold type is water reaching to either needle...
        temp = max(session.buffer(new_samples,2:3),2);                      %Find the maximum value of either the left or right sensor signal.
        trial.mon_signal(new_samples) = (temp > 511.5);                     %Digitize the threshold.
        
    case 'milliseconds/grams'                                               %If the current threshold type is a combined hold/pull...
        for i = new_samples                                                 %Step through each new sample...
            if session.buffer(i,3) > 511.5                                  %If the sample is a logical high...
                trial.mon_signal(i) = trial.mon_signal(i-1) - ...
                    handles.period;                                         %Add the stream period to the running count for this sample.
            else                                                            %Otherwise...
                if abs(trial.mon_signal(i-1)) > handles.init && ...
                        session.buffer(i,3) < 511.5                         %If the animal just released the sensor after holding for the appropriate time.
                    trial.mon_signal(i) = handles.init;                     %Set the monitor signal current sample to the initiation threshold.
                else                                                        %Otherwise...
                    trial.mon_signal(i) = 0;                                %Reset the count.
                end
            end
        end
end

if handles.ir == 1                                                          %If IR swipe initiation is enabled...
    if strcmpi(handles.ir_detector,'bounce')                                %If the IR detector is the bounce type...
        trial.ir_initiate = any(new_data(:,3) < session.minmax_ir(3));      %Check for sub-threshold IR signals.
    elseif strcmpi(handles.ir_detector,'beam')                              %If the IR detector is the beam type...
        trial.ir_initiate = any(new_data(:,3) > session.minmax_ir(3));      %Check for supra-threshold IR signals.
    end
end


%% ***********************************************************************
function [trial, session] = MotoTrak_Update_Threshold(handles,session,trial)

%
%MotoTrak_Update_Threshold.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_THRESHOLD calculates the hit threshold for the next
%   trial when dynamic thresholds are enabled.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       threshold calculation section from MotoTrak_Behavior_Loop.m.
%

switch lower(handles.threshadapt)                                           %Switch between the recognized threshold adaptation methods.
    
    case 'median'                                                           %If this stage has a median-adapting threshold...
        session.thresh_buffer(1:end-1) = session.thresh_buffer(2:end);      %Shift the previous maximum hit window values one spot, overwriting the oldest.
        switch lower(handles.curthreshtype)                                 %Switch between the recognized threshold types...

            case {  'grams (peak)',...
                    'degrees (total)',...
                    'degrees/s',...
                    'bidirectional',...
                    'milliseconds/grams'}                                   %If the threshold was an analog value...
                session.thresh_buffer(end) = ...
                    max(trial.signal(session.hitwin));                      %Add the last trial's maximum value to the maximum value tracking matrix.

            otherwise                                                       %For all other threshold types...
                session.thresh_buffer(end) = length(trial.peak_vals);       %Add the last trial's number of presses to the maximum value tracking matrix.

        end

        if ~any(isnan(session.thresh_buffer))                               %If there's no NaN values in the maximum value tracking matrix...
            trial.thresh = median(session.thresh_buffer);                   %Set the current threshold to the median of the preceding trials.
            if trial.thresh > session.max_thresh                            %If the threshold is greater than the historical maximum...
                session.max_thresh = trial.thresh;                          %Save the threshold as the new historical maximum.
            end
            if strcmpi(handles.curthreshtype, 'degrees (total)')            %If the current threshold type is the total number of degrees...
                if trial.thresh < (0.7*session.max_thresh)                  %If the threshold is less than 70% of the historical maximum...
                    trial.thresh = 0.7*session.max_thresh;                  %Set the threshold to 70% of the historical maximum.
                end
            end
        end

    case 'linear'                                                           %If this stage has a linear-adpating threshold...
        if trial.hit_time(1) ~= 0                                           %If the last trial was scored as a hit...
            trial.thresh = trial.thresh + handles.threshincr;               %Increment the hit threshold by the specified increment.
        end

    case 'static'                                                           %If this stage has a static threshold...
    session.max_thresh = trial.thresh;                                      %Save the threshold as the maximum threshold.
    
end
trial.thresh = min([trial.thresh, handles.threshmax]);                      %Don't allow the hit threshold to exceed the specified maximum.
trial.thresh = max([trial.thresh, handles.threshmin]);                      %Don't allow the hit threshold to go below the specified minimum.
set(handles.editthresh,'string',num2str(trial.thresh,'%1.1f'));             %Show the current threshold in the hit threshold editbox with one decimal.


%% ***********************************************************************
function trial = MotoTrak_Update_Trial_Plots(handles,session,trial)

%
%MotoTrak_Update_Trial_Plots.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_TRIAL_PLOTS plots new streaming data from the MotoTrak
%   controller to the streaming plots on the MotoTrak GUI during a trial.
%   
%   UPDATE LOG:
%   05/02/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial signal plotting sections from MotoTrak_Behavior_Loop.m.
%


cur_tab = handles.plot_tab_grp.SelectedTab.Title;                           %Grab the currently selected tab title.
if strcmpi(handles.device,'both')                                           %If this is a combined touch-pull session...
        set(trial.plot_h(1),'ydata',session.buffer(:,2));                   %Update the force area plot.
    trial.max_y = ...
        [min([1.1*min(session.buffer(:,2)), -0.1*trial.thresh]),...
        max([1.1*max(session.buffer(:,2)), 1.3*trial.thresh])];             %Calculate new y-axis limits.
    ylim(handles.primary_ax,trial.max_y);                                   %Set the new y-axis limits.
    set(trial.plot_h(3),'ydata',trial.mon_signal);                          %Update the touch area plot.
    trial.max_y = ...
        [min([1.1*min(trial.mon_signal), -1.1*handles.init]),...
        max([1.1*max(trial.mon_signal), 1.1*handles.init])];                %Calculate new y-axis limits.
    ylim(handles.secondary_ax,trial.max_y);                                 %Set the new y-axis limits.
else                                                                        %Otherwise...
    switch lower(cur_tab)                                                   %Switch between the tabs...
        case {'supination angle',...
                'pull force',...
                'lever angle'}                                              %If the selected tab is the primary signal...    
            set(trial.plot_h(1),'ydata',trial.signal);                      %Update the area plot.
            if strcmpi(handles.curthreshtype,'# of spins') ...
                    || strcmpi(handles.curthreshtype,'presses')
                set(trial.plot_h(2),'xdata',trial.peak_indices-1,...
                    'ydata',trial.peak_vals);                               %Update the peak markers.
                for i = 1:length(trial.peak_vals)                           %Step through each of the peaks.
                    x = trial.peak_indices(i) - 1;                          %Calculate x coordinates for a peak label.
                    y = trial.peak_vals(i);                                 %Calculate y coordinates for a peak label.
                    if i > length(trial.peak_text)                          %If this is a new peak since the last data read...
                        str = num2str(i);                                   %Convert the peak index to a string.
                        trial.peak_text(i) = text(x,y,str,...
                            'horizontalalignment','left',...
                            'verticalalignment','bottom',...
                            'fontsize',8,...
                            'fontweight','bold',...
                            'parent',handles.primary_ax);                   %Create text to mark each peak in the hit window.
                    else                                                    %Otherwise, if this isn't a new peak...
                        set(trial.peak_text(i),'position',[x,y]);           %Update the position of the peak label.
                    end
                end
            end
            if ~isnan(handles.ceiling) && handles.ceiling ~= Inf            %If a ceiling is set for this stage...
                trial.max_y = [min([1.1*min(trial.signal),...
                    -0.1*handles.ceiling]),...
                    max([1.3*max(trial.signal), 1.3*handles.ceiling])];     %Calculate new y-axis limits.
            else                                                            %Otherwise, if there is no ceiling set for this stage...
                trial.max_y = [min([1.1*min(trial.signal),...
                    -0.1*trial.thresh]),...
                    max([1.3*max(trial.signal), 1.3*trial.thresh])];        %Calculate new y-axis limits.
            end
            set(trial.trial_txt,'position',[1,trial.max_y(2)]);             %Update the text postiion.
            ylim(handles.primary_ax,trial.max_y);                           %Set the new y-axis limits.            
            set(trial.ln,'ydata',trial.max_y);                              %Update the lines marking the hit window bounds.
        case 'swipe sensor'                                                 %If the selected tab is the secondary signal...
            set(trial.plot_h(3),'ydata',session.buffer(:,3),...
                'basevalue',session.minmax_ir(1));                          %Update the IR signal plot.
            set(trial.ir_thresh_ln,'ydata',[1,1]*session.minmax_ir(3));     %Update the threshold line.
            set(trial.ir_thresh_txt,'position',[1,session.minmax_ir(3)]);   %Update the threshold line label.
            temp = session.minmax_ir(1:2);                                  %Grab the current historical minimum and maximum.
            if temp(1) > temp(2)                                            %If the 1st value is greater than the second...
                temp = [0, 1023];                                           %Set the infrared bounds to the maximum possible.
            elseif temp(1) == temp(2)                                       %If the 1st value equals the 2nd...
                temp = temp(1) + [-1,1];                                    %Add one above and below the single value.
            end
            temp = temp + [-0.1,0.1]*(temp(2) - temp(1));                   %Calculate y-axis limits.
            ylim(handles.secondary_ax,temp);                                %Set the secondary axes y-axis limits.
    end
end


%% ***********************************************************************
function [session, trial, N] = MotoTrak_Update_Trial_Signal(handles,session,trial)

%
%MotoTrak_Update_Trial_Signal.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_TRIAL_SIGNAL checks the MotoTrak controller for new
%   streaming data, and adds any new data it finds to the data for the
%   current trial.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial signal stream read sections from MotoTrak_Behavior_Loop.m.
%

new_data = handles.ardy.read_stream();                                      %Read in any new stream output.
N = size(new_data,1);                                                       %Find the number of new samples.

if N == 0                                                                   %If there's no new data...
    return                                                                  %Skip the rest of the function.
end

% for i = 1:N
%     fprintf(1,'STREAM:\t%1.0f\t%1.0f\t%1.0f\n',new_data(i,:));            %Print the new data to the command line.
% end
    
new_data(:,2) = session.cal(1)*(new_data(:,2) - session.cal(2));            %Apply the calibration constants to the data signal.
session.buffer(1:end-N,:) = ...
    session.buffer(N+1:end,:);                                              %Shift the existing buffer samples to make room for the new samples.
try
session.buffer(end-N+1:end,:) = new_data;                                   %Add the new samples to the buffer.
catch
    disp('yo');
end

if trial.cur_sample + N > session.buffsize                                  %If more samples were read than we'll record for the trial...
    N = session.buffsize - trial.cur_sample;                                %Pare down the read samples to only those needed.
end

new_samples = trial.cur_sample+(1:N);                                       %Grab the indices for the new samples.

trial.data(new_samples,:) = new_data(1:N,:);                                %Add the new samples to the trial data.    

switch handles.curthreshtype                                                %Switch between the types of hit threshold.

    case 'bidirectional'                                                    %If the current threshold type is the bidirectional number of degrees...
        trial.signal(trial.cur_sample+(1:N)) = ...
            abs(trial.data(new_samples,2) - trial.base_value);              %Save the new section of the knob position signal, subtracting the trial base value.

    case {  'grams (peak)',...
            'grams (sustained)',...
            'degrees (total)',...
            'presses',...
            'fullpresses'}                                                  %If the current threshold type is the total number of degrees or peak force...
        if strcmpi(handles.stage(handles.cur_stage).number,'PASCI1')        %If the current stage is PASCI1...
            trial.signal(new_samples) = ...
                abs(trial.data(new_samples,2) - trial.base_value);          %Save the new section of the wheel position signal, subtracting the trial base value. 
        else                                                                %Otherwise, for the other threshold types...
            trial.signal(new_samples) = ...
                trial.data(new_samples,2) - trial.base_value;               %Save the new section of the wheel position signal, subtracting the trial base value. 
        end
        trial.cur_val = trial.signal(trial.cur_sample + N);                 %Grab the current value.
    case {'degrees/s','# of spins'}                                         %If the current threshold type is the number of spins or spin velocity.
        temp = diff(session.buffer(:,2));                                   %Find the wheel velocity at each point in the buffer.
        temp = boxsmooth(temp,session.min_peak_dist);                       %Boxsmooth the wheel velocity with a 100 ms smoothandles.            
        trial.signal(trial.cur_sample+(-session.offset:N)) = ...
                temp(session.buffsize-N-1-session.offset:session.buffsize-N+N-1);       %Find the wheel velocity thus far in the trial.

    case 'milliseconds (hold)'                                              %If the current threshold type is a hold...
        trial.signal(trial.cur_sample + (1:N)) = ...
            handles.period*(trial.data(new_samples,3) > 511.5);             %Digitize and save the new section of signal.
        for i = new_samples                                                 %Step through each new signa.
            if trial.signal(i) > 0                                          %If the touch sensor is held for this sample...
                trial.signal(i) = trial.signal(i) + trial.signal(i-1);      %Add the sample time to all of the preceding non-zero sample times.
            end
        end

    case 'milliseconds/grams'                                               %If the current threshold type is a hold...
        trial.signal(new_samples) = ...
                trial.data(new_samples,2) - trial.base_value;               %Save the new section of the wheel position signal, subtracting the trial base value.
        trial.touch_signal(new_samples) = ...
            1023 - trial.data(new_samples,3);                               %Save the new section of the wheel position signal, subtracting the trial base value.
        trial.touch_signal(new_samples) = trial.data(new_samples,3);        %Save the new section of the wheel position signal, subtracting the trial base value.
        i = trial.cur_sample + N;                                           %Grab the current sample.
        if trial.hit_time == 0 && ...
                any(trial.touch_signal(new_samples) > 511.5)                %If the rat went back to the touch sensor...
            trial.buffsize = trial.cur_sample + N;                          %Set the new buffer timeout.
            trial.hit_time = -1;                                            %Set the hit time to -1 to indicate an abort.
        elseif handles.stim == 1 && any(trial.signal >= 5) && ...
                all(trial.signal(i-session.stim_time_out:i) < 5)            %If stimulation is on and the rat hasn't pull the handle in half a second...
            handles.ardy.stim_off();                                        %Immediately turn off stimulation.
            trial.stim_time = now;                                          %Save the current time as the hit time.                    
        end            
end            


switch handles.curthreshtype                                                %Switch between the types of hit threshold.

    case {'presses', 'fullpresses'}                                         %For lever press count thresholds...

        %Find all the presses of the lever
        presses_signal = trial.signal(1:trial.cur_sample+N) - session.min_peak_val;
        negative_bound = 0 - (session.min_peak_val - session.lever_return_pt);

        presses_signal(presses_signal > 0) = 1;
        presses_signal((presses_signal <= 0) & (presses_signal >= negative_bound)) = 0;
        presses_signal(presses_signal < negative_bound) = -1;

        original_indices = find(presses_signal ~= 0);
        modified_presses_signal = presses_signal(presses_signal ~= 0);
        modified_presses_signal(modified_presses_signal < 0) = 0;

        diff_presses_signal = [0; diff(modified_presses_signal)];

        %Find the position/time of each press
        new_data = original_indices(find(diff_presses_signal == 1))';

        %Find the position/time of each release
        trial.release_points = original_indices(find(diff_presses_signal == -1))';

        %Set the magnitude of each press (this is constant.  it is
        %just the threshold, which is session.min_peak_val).
        trial.peak_vals = [];
        trial.peak_vals(1:length(new_data)) = session.min_peak_val;

        rpks = [];
        rpks(1:length(trial.release_points)) = session.lever_return_pt;

    otherwise

        %If the threshold type is presses (with the rotary encoder
        %lever), and the threshold is greater than 1 (we are not on a
        %shaping stage, then find peaks above a specific height
        [trial.peak_vals,trial.peak_indices] = ...
            MotoTrak_Peak_Finder(trial.signal,session.min_peak_dist);  
        trial.release_points = [];
        rpks = [];

end

%Kick out all peaks that don't reach the session.min_peak_val criterion
trial.peak_indices = trial.peak_indices(trial.peak_vals >= session.min_peak_val);
trial.peak_vals = trial.peak_vals(trial.peak_vals >= session.min_peak_val);


i = find(trial.peak_indices >= session.pre_samples & trial.peak_vals >= 1 &...
    trial.peak_indices < session.pre_samples + session.hit_samples & ...
    trial.peak_indices <= trial.cur_sample + N - session.offset );          %Find all of the of peaks in the hit window.
br = find(trial.release_points >= session.pre_samples & rpks >= 1 & ...
    trial.release_points < session.pre_samples + session.hit_samples & ...
    trial.release_points <= trial.cur_sample + N - session.offset );
%                 rpks = rpks(br);
trial.release_points = trial.release_points(br);

trial.peak_vals = trial.peak_vals(i);                                       %Kick out all of the peaks outside of the hit window.
trial.peak_indices = trial.peak_indices(i);                                 %Kick out all of the peak times outside of the hit window.

trial.cur_sample = trial.cur_sample + N;                                    %Add the number of new samples to the current sample counter.


%% ***********************************************************************
function MotoTrak_Upload_Controller_Sketch(port,ver,msgbox)

%
%MotoTrak_Upload_Controller_Sketch.m - Vulintus, Inc.
%
%   This function calls uploads a new sketch to the MotoTrak controller
%   using the avrdude.exe program.
%
%   UPDATE LOG:
%   04/27/2018 - Drew Sloan - First function implementation.
%

if isdeployed                                                               %If this is deployed code...
    prog_path = 'C:\Program Files\Vulintus\MotoTrak\application';           %Set the expected path of the controller hex file program.
else                                                                        %Otherwise, if the code isn't deployed...
    [prog_path,~,~] = ...
        fileparts(which('MotoTrak_Upload_Controller_Sketch.m'));            %Grab the location of the current sketch.    
    if isempty(prog_path)                                                   %If no location was found for the current m-file...
        temp = sprintf('%1.2f',ver);                                        %Convert the version number to a string.
        temp(temp == '.') = 'p';                                            %Change the period to a "p";
        temp = sprintf('MotoTrak_v%s.m',temp);                              %Construct the expected filename.
        [prog_path,~,~] = fileparts(which(temp));                           %Check for the location of the collated MotoTrak m-file.
    end
end

if ~exist([prog_path '\avrdude.exe'],'file') || ...
        ~exist([prog_path '\avrdude.conf'],'file')                          %If avrdude.exe or it's configuration file aren't found...
        warning([upper(mfilename) ':AvrdudeNotFound'],['The '...
            '"avrdude.exe" program isn''t in the current directory!']);     %Show a warning.
    return                                                                  %Skip execution of the function.
end

hex_files = dir([prog_path '\MotoTrak_Controller_V*.ino.hex']);             %Find all hex files in the path.
if isempty(hex_files)                                                       %If no matching hex files were found...
    warning([upper(mfilename) ':NoHexFilesFound'],['No MotoTrak '...
        '*.ino.hex files files were found in the current directory!']);     %Show a warning.
    return                                                                  %Skip execution of the function.
end

for i = 1:length(hex_files)                                                 %Step through each hex file.
    a = find(hex_files(i).name == 'V',1,'last');                            %Find the last "V" in the filename.
    b = strfind(hex_files(i).name,'.ino.hex');                              %Find the start of the file extension.        
    str = hex_files(i).name(a+1:b-1);                                       %Pull the version number out of the filename.
    str(str == '_') = '.';                                                  %Replace all underscores with periods.
    hex_files(i).ver = str2double(str);                                     %Convert the string to a number.
end
i = vertcat(hex_files.ver) == max(vertcat(hex_files.ver));                  %Identify the most recent file.
hex_files = hex_files(i(1));                                                %Keep only the most recent file.

str = sprintf('Updating controller microcode to V%1.2f...',...
    hex_files(1).ver);                                                      %Create a message showing the new microcode version.
Add_Msg(msgbox,str);                                                        %Show an "updating..." message in the messagebox.    

%Build the command line call.
cmd = ['"' prog_path '\avrdude" '...                                        %avrdude.exe location
    '-C"' prog_path '\avrdude.conf" '...                                    %avrdude.conf location
    '-patmega328p '...                                                      %microcontroller type
    '-carduino '...                                                         %arduino programmer
    '-P' port ' '...                                                        %port
    '-b115200 '...                                                          %baud rate
    '-D '...                                                                %disable erasing the chip
    '-Uflash:w:"' prog_path '\' hex_files(1).name '":i'];                   %hex file name                             

clc;                                                                        %Clear the command line.
cprintf('*blue','\n%s\n',cmd);                                              %Print the command in bold green.
[status, ~] = dos(cmd,'-echo');                                             %Execute the command in a dos prompt, showing the results.

if status == 0                                                              %If the command was successful...
    Add_Msg(msgbox,'Controller microcode successfully updated!');           %Show a success message in the messagebox.    
else                                                                        %Otherwise...
    Add_Msg(msgbox,'Controller microcode update failed!');                  %Show a failure message in the messagebox.    
    Add_Msg(msgbox,'Reverting to existing controller microcode.');          %Show that we're reverting to the previous microcode.
end

pause(1);                                                                   %Pause for 1 second.


%% ***********************************************************************
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


%% ***********************************************************************
function [fid, filename] = MotoTrak_Write_File_Header(handles)

%This function writes the file header for session data files.
%   This function runs in the background to display the streaming input
%   signals from MotoTrak while a session is not running.
%   
%   UPDATE LOG:
%   01/09/2017 - Drew Sloan - Added an if statement to create version -4
%       data files for stages with a ceiling enabled.
%   02/21/2017 - Drew Sloan - Added the data filename as a second output
%       argument.
%

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
if handles.stim == 0                                                        %If we're not stimulating...      
    stim = 'NoStim';                                                        %Show that there's no stimulation in the filename.
elseif handles.stim == 1                                                    %If we're stimulating normally...
    stim = 'Stim';                                                          %Show that there's stimulation in the filename.
elseif handles.stim == 2                                                    %If we're randomly stimulating...
    stim = 'RandomStim';                                                    %Show that there's random stimulation in the filename.
elseif handles.stim == 3
    stim = 'BurstStim';
end
temp = [handles.ratname...                                                  %(Rat name)
    '_' temp...                                                             %(Timestamp)
    '_Stage' handles.stage(handles.cur_stage).number...                     %(Stage title)
    '_' handles.device...                                                   %(Device)
    '_' stim...                                                             %(Stimulation on or off)
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
if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                        %If a ceiling was specified for this stage...
    fwrite(fid,-4,'int8');                                                  %Write the data file version number.
else                                                                        %Otherwise, if there is no ceiling...
    fwrite(fid,-3,'int8');                                                  %Write the data file version number.
end
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


%% ***********************************************************************
function MotoTrak_Write_Pause_Data(fid,trial)

%
%MotoTrak_Write_Pause_Data.m - Vulintus, Inc.
%
%   MOTOTRAK_WRITE_PAUSE_DATA writes any session pause data to the output
%   data file.
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       data write section from MotoTrak_Behavior_Loop.m.
%

fwrite(fid,trial.num,'uint32');                                             %Write the trial number.
fwrite(fid,now,'float64');                                                  %Write the start time of the trial.
fwrite(fid,'V','uint8');                                                    %Write the letter "V" to indicate this is a dummy trial.
fwrite(fid,0,'float32');                                                    %Write a hit window of 0 for this trial.
fwrite(fid,0,'float32');                                                    %Write a trial initiation threshold of 0 for this trial.
fwrite(fid,0,'float32');                                                    %Write a hit threshold of 0 for this trial.
fwrite(fid,0,'uint8');                                                      %Write the number of hits in this trial.
fwrite(fid,length(trial.stim_time),'uint8');                                %Write the number of VNS events in this trial.
for i = 1:length(trial.stim_time)                                           %Step through each of the VNS event times.
    fwrite(fid,trial.stim_time(i),'float64');                               %Write each VNS event time.
end
fwrite(fid,0,'uint32');                                                     %Write a buffer size of 0 for this trial.


%% ***********************************************************************
function MotoTrak_Write_Trial_Data(fid,handles,trial)

%
%MotoTrak_Write_Trial_Data.m - Vulintus, Inc.
%
%   MOTOTRAK_WRITE_TRIAL_DATA writes the data for one trial to a MotoTrak
%   data file.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       data write section from MotoTrak_Behavior_Loop.m.
%

fwrite(fid,trial.num,'uint32');                                             %Write the trial number.
fwrite(fid,trial.start(1),'float64');                                       %Write the start time of the trial.
fwrite(fid,trial.score(1),'uint8');                                         %Write the first letter of 'HIT' or 'MISS' as the outcome.
fwrite(fid,handles.hitwin,'float32');                                       %Write the hit window for this trial.
fwrite(fid,handles.init,'float32');                                         %Write the trial initiation threshold for reward for this trial.
fwrite(fid,trial.thresh,'float32');                                         %Write the hit threshold for reward for this trial.
if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                        %If there's a force ceiling.
    fwrite(fid,handles.ceiling,'float32');                                  %Write the force ceiling for this trial.
end
fwrite(fid,length(trial.hit_time),'uint8');                                 %Write the number of hits in this trial.
for i = 1:length(trial.hit_time)                                            %Step through each of the hit/reward times.
    fwrite(fid,trial.hit_time(i),'float64');                                %Write each hit/reward time.
end
fwrite(fid,length(trial.stim_time),'uint8');                                %Write the number of VNS events in this trial.
for i = 1:length(trial.stim_time)                                           %Step through each of the VNS event times.
    fwrite(fid,trial.stim_time(i),'float64');                               %Write each VNS event time.
end            
fwrite(fid,trial.buffsize,'uint32');                                        %Write the number of samples in the trial data signal.
fwrite(fid,trial.data(1:trial.buffsize,1)/1000,'int16');                    %Write the millisecond timestamps for all datapoints.
fwrite(fid,trial.data(1:trial.buffsize,2),'float32');                       %Write all device signal datapoints.
fwrite(fid,trial.data(1:trial.buffsize,3),'int16');                         %Write all IR signal datapoints.


%% ***********************************************************************
function Mototrak_Open_Configuration_Directory(~,~)

%
%Mototrak_Open_Configuration_Directory.m - Vulintus, Inc.
%
%   Mototrak_Open_Configuration_Directory is called whenever the user 
%   selects "Configuration Files..." from the MotoTrak GUI Preferences
%   menu. The function opens the local AppData folder containing the 
%   MotoTrak configuration files.
%
%   UPDATE LOG:
%   08/17/2018 - Drew Sloan - First function implementation, adapted from 
%       "Mototrak_Open_Error_Reports.m".
%

handles = guidata(gcbf);                                                    %Grab the handles structure from the main figure.
system(['explorer ' handles.mainpath]);                                     %Open the configuration directory in Windows Explorer.


%% ***********************************************************************
function Mototrak_Open_Error_Reports(~,~)

%
%Mototrak_Open_Error_Reports.m - Vulintus, Inc.
%
%   Mototrak_Open_Error_Reports is called whenever the user selects "View
%   Error Reports" from the MotoTrak GUI Preferences menu and opens the
%   local AppData folder containing all archived error reports.
%
%   UPDATE LOG:
%   02/21/2017 - Drew Sloan - First function implementation.
%

handles = guidata(gcbf);                                                    %Grab the handles structure from the main figure.
err_path = [handles.mainpath 'Error Reports\'];                             %Create the expected directory name for the error reports.
if ~exist(err_path,'dir')                                                   %If the error report directory doesn't exist...
    mkdir(err_path);                                                        %Create the error report directory.
end
system(['explorer ' err_path]);                                             %Open the error report directory in Windows Explorer.


%% ***********************************************************************
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


