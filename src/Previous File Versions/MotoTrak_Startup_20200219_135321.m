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
    handles.version = 1.23;                                                 %Set the MotoTrak program version.
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
    if ~isempty(handles.ardy) && handles.ardy.version < 220                 %If the Arduino sketch version is older than version 2.2...
        str = sprintf(['The controller''s V%1.1f microcode is out of '...
            'date.'],handles.ardy.version/100);                             %Create a string showing the current microcode version.
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
        if handles.ardy.version < 200                                       %If the controller microcode version is less than 2.00...
            handles.baseline = handles.ardy.baseline();                     %Read in the baseline (unpressed) value for the lever.
            handles.total_range_in_degrees = handles.ardy.cal_grams();      %Read in the range of the lever press, in degrees.
            handles.total_range_in_analog_values = ...
                handles.ardy.n_per_cal_grams();                             %Read in the range of the lever press, in analog tick values.
            handles.slope = handles.total_range_in_degrees / ...
                handles.total_range_in_analog_values;                       %Calculate the degrees/tick conversion for the lever.
        else                                                                %Otherwise...
            handles.total_range_in_degrees = handles.ardy.lever_range();    %Grab the total range, in degrees for the lever.
            handles.baseline = handles.ardy.get_baseline_float(1);          %Read in the baseline (unpressed) value for the lever.
            handles.slope = handles.ardy.get_slope_float(1);                %Read in the slope value for the lever.
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
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        fig = figure('menubar','none',...
            'name','MotoTrak Error Summary',...
            'numbertitle','off');
        ax = axes('units','normalized',...
            'position',[0 0 1 1],...
            'color','w',...
            'xlim',[0,1],...
            'ylim',[0,1],...
            'parent',fig);
        t = text(0.05,1,err.identifier,...
            'fontsize',10,...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'interpreter','none',...
            'parent',ax);
        y = get(t,'extent');
        t = text(0.05,y(2) - 0.01,['     ' err.message],...
            'fontsize',10,...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'interpreter','none',...
            'parent',ax);
        for i = 1:length(err.stack)
            y = get(t,'extent');
            t = text(0.05,y(2) - 0.01,err.stack(i).name,...
                'fontsize',10,...
                'horizontalalignment','left',...
                'verticalalignment','top',...
                'interpreter','none',...
                'parent',ax);
            y = get(t,'extent');
            t = text(0.05,y(2) - 0.01,['     LINE: ' num2str(err.stack(i).line)],...
                'fontsize',10,...
                'horizontalalignment','left',...
                'verticalalignment','top',...
                'interpreter','none',...
                'parent',ax);
        end
        set(ax,'xtick',[],'ytick',[]);
        uiwait(fig);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~ishandle(handles.mainfig)                                       %If the original figure was closed (i.e. during calibration)...
            figs = get(0,'children');                                       %Grab handles for all open figures.
            j = zeros(numel(figs),1);                                       %Create a matrix for checking which figure is the MotoTrak figure.
            for i = 1:numel(figs)                                           %Step through each open figure...
                j(i) = strncmpi(get(figs(i),'name'),'MotoTrak',8);          %Find the MotoTrak figure based on the anme.
            end
            handles.mainfig = figs(j);                                      %Reset the main figure handle.         
        end        
        handles = guidata(handles.mainfig);                            %Grab the handles structure from the main GUI.
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