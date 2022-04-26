function Connect_MotoTrak

%Compiled: 01/11/2021, 10:01:27

Connect_MotoTrak;                                                           %Call the startup function.


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
        version = 140;                                                      %Set the sketch version to 1.4.
    elseif temp == 123                                                      %Otherwise, if the reply is the "123" expected from controller sketches 2.0+...        
        version = 200;                                                      %Set the version to 2.0.
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
if version == 140                                                           %If the controller Arduino sketch version is 1.4...
    ardy = MotoTrak_Controller_V1p4_Serial_Functions(ardy);                 %Load the V1.4 serial communication functions.
    ardy.version = version;                                                 %Save the version number.
elseif version == 200                                                       %If the controller Arduino sketch version is 2.0...
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
%	Library V2 documentation:
%	https://docs.google.com/spreadsheets/d/e/2PACX-1vQinoUdNJ9lOkU2rXf7XYloEV3dRdZEd-AJRCSSkMoRjaA03AsaVFRaJIMWbD7IIyDRDrkSpkOE6Qp1/pubhtml
%
%	This file was programmatically generated: 26-Feb-2020 09:49:14
%	by script: Update_MotoTrak_Libraries.m
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
		serial_codes.RETURN_AP_POS = 112;

		serial_codes.PLAY_TONE = 49;
		serial_codes.STOP_TONE = 50;
		serial_codes.SET_TONE_VOLUME = 54;
		serial_codes.RETURN_TONE_VOLUME = 59;
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
		serial_codes.CMD_SET_TONE_VOLUME = 27;

		serial_codes.EEPROM_BOOTH_NUM = 0;

		serial_codes.EEPROM_CAL_BASE_INT = 4;

		serial_codes.EEPROM_CAL_FORCE_INT = 6;

		serial_codes.EEPROM_CAL_TICK_INT = 8;

		serial_codes.EEPROM_LEVER_RANGE = 126;

		serial_codes.EEPROM_SN = 10;

		serial_codes.EEPROM_BOOTH_ID = 14;

		serial_codes.EEPROM_CAL_BASE_FL = 38;

		serial_codes.EEPROM_CAL_SLOPE_FL = 42;


    otherwise

		serial_codes.CUR_DEF_VERSION = 210;

		serial_codes.SKETCH_VERIFY = 65;
		serial_codes.SET_BOOTH_NUMBER = 67;
		serial_codes.GET_SKETCH_VER = 110;
		serial_codes.GET_BOOTH_NUMBER = 111;
		serial_codes.DEVICE_ID = 112;
		serial_codes.GET_SERIAL_LIB_VER = 113;

		serial_codes.READ_1BYTE_EEPROM = 120;
		serial_codes.SAVE_1BYTE_EEPROM = 121;
		serial_codes.READ_2BYTES_EEPROM = 122;
		serial_codes.SAVE_2BYTES_EEPROM = 123;
		serial_codes.READ_4BYTES_EEPROM = 124;
		serial_codes.SAVE_4BYTES_EEPROM = 125;

		serial_codes.STREAM_ENABLE = 130;
		serial_codes.RETURN_STREAM_PERIOD = 131;
		serial_codes.SET_STREAM_PERIOD = 132;
		serial_codes.RETURN_STREAM_ORDER = 133;
		serial_codes.SET_STREAM_ORDER = 134;
		serial_codes.RETURN_EVENT_INPUT = 135;
		serial_codes.SET_EVENT_INPUT = 136;
		serial_codes.RETURN_EVENT_SIZE = 137;
		serial_codes.SET_EVENT_SIZE = 138;
		serial_codes.READ_DEVICE_VAL = 139;
		serial_codes.RESET_COUNTER = 140;

		serial_codes.RETURN_AP_DIST = 150;
		serial_codes.SET_AP_DIST = 151;

		serial_codes.TRIGGER_FEEDER = 160;
		serial_codes.STOP_FEED = 161;
		serial_codes.RETURN_FEED_TRIG_DUR = 162;
		serial_codes.SET_FEED_TRIG_DUR = 163;

		serial_codes.RETURN_CAGE_LIGHTS = 170;
		serial_codes.SET_CAGE_LIGHTS = 171;

		serial_codes.PLAY_TONE = 180;
		serial_codes.STOP_TONE = 181;
		serial_codes.RETURN_TONE_INDEX = 182;
		serial_codes.SET_TONE_INDEX = 183;
		serial_codes.RETURN_TONE_FREQ = 184;
		serial_codes.SET_TONE_FREQ = 185;
		serial_codes.RETURN_TONE_DUR = 186;
		serial_codes.SET_TONE_DUR = 187;
		serial_codes.RETURN_TONE_TYPE = 188;
		serial_codes.SET_TONE_TYPE = 189;
		serial_codes.RETURN_TONE_MON = 190;
		serial_codes.SET_TONE_MON = 191;
		serial_codes.RETURN_TONE_THRESH = 192;
		serial_codes.SET_TONE_THRESH = 193;
		serial_codes.RETURN_MAX_TONES = 194;

		serial_codes.SEND_TRIGGER = 200;
		serial_codes.STOP_TRIGGER = 201;
		serial_codes.RETURN_TRIG_INDEX = 202;
		serial_codes.SET_TRIG_INDEX = 203;
		serial_codes.RETURN_TRIG_DUR = 204;
		serial_codes.SET_TRIG_DUR = 205;
		serial_codes.RETURN_TRIG_TYPE = 206;
		serial_codes.SET_TRIG_TYPE = 207;
		serial_codes.RETURN_TRIG_MON = 208;
		serial_codes.SET_TRIG_MON = 209;
		serial_codes.RETURN_TRIG_THRESH = 210;
		serial_codes.SET_TRIG_THRESH = 211;

		serial_codes.RETURN_DAC_STATUS = 220;
		serial_codes.RETURN_DAC_MODE = 221;
		serial_codes.SET_DAC_MODE = 222;

		serial_codes.VIB_TOGGLE = 33;
		serial_codes.RETURN_VIB_DUR = 34;
		serial_codes.SET_VIB_DUR = 35;
		serial_codes.RETURN_VIB_IPI = 36;
		serial_codes.SET_VIB_IPI = 37;
		serial_codes.RETURN_VIB_N = 38;
		serial_codes.SET_VIB_N = 39;
		serial_codes.RETURN_VIB_GAP_START = 40;
		serial_codes.SET_VIB_GAP_START = 41;
		serial_codes.RETURN_VIB_GAP_STOP = 42;
		serial_codes.SET_VIB_GAP_STOP = 43;
		serial_codes.START_VIB = 44;
		serial_codes.STOP_VIB = 45;
		serial_codes.VIB_MASK_ENABLE = 46;
		serial_codes.RETURN_VIB_TONE_FREQ = 47;
		serial_codes.SET_VIB_TONE_FREQ = 58;
		serial_codes.RETURN_VIB_TONE_DUR = 59;
		serial_codes.SET_VIB_TONE_DUR = 60;
		serial_codes.RETURN_VIB_TASK_MODE = 61;
		serial_codes.SET_VIB_TASK_MODE = 62;

		serial_codes.BWC_GET_BOOTH_NUMBER = 66;
		serial_codes.BWC_GET_SKETCH_VER = 90;
		serial_codes.BWC_SET_AP_DIST = 48;
		serial_codes.BWC_RETURN_FEED_TRIG_DUR = 52;
		serial_codes.BWC_SET_FEED_TRIG_DUR = 53;
		serial_codes.BWC_TRIGGER_FEEDER = 87;
		serial_codes.BWC_FEED = 51;
		serial_codes.BWC_SEND_TRIGGER = 88;
		serial_codes.BWC_STIMULATE = 54;
		serial_codes.BWC_RETURN_TRIG_DUR = 55;
		serial_codes.BWC_SET_TRIG_DUR = 56;
		serial_codes.BWC_SET_CAGE_LIGHTS = 57;
		serial_codes.BWC_DEVICE_ID = 68;
		serial_codes.BWC_KNOB_TOGGLE = 69;
		serial_codes.BWC_READ_DEVICE_VAL = 77;
		serial_codes.BWC_GET_BASELINE = 78;
		serial_codes.BWC_SET_BASELINE = 79;
		serial_codes.BWC_GET_CAL_GRAMS = 80;
		serial_codes.BWC_SET_CAL_GRAMS = 81;
		serial_codes.BWC_GET_CAL_TICKS = 82;
		serial_codes.BWC_SET_CAL_TICKS = 83;
		serial_codes.BWC_SET_STREAM_PERIOD = 101;
		serial_codes.BWC_RETURN_STREAM_PERIOD = 102;
		serial_codes.BWC_STREAM_ENABLE = 103;
		serial_codes.BWC_PLAY_HIT_SOUND = 74;
		serial_codes.BWC_PLAY_1000HZ_TONE = 49;
		serial_codes.BWC_PLAY_1100HZ_TONE = 50;

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
		serial_codes.CMD_RETURN_DAC_MODE = 27;
		serial_codes.CMD_SET_DAC_MODE = 28;
		serial_codes.CMD_SET_DAC_INDEX = 29;
		serial_codes.CMD_BWC_MODE_2 = 30;
		serial_codes.CMD_BWC_MODE_3 = 31;
		serial_codes.CMD_BWC_MODE_7 = 32;
		serial_codes.CMD_BWC_MODE_8 = 33;
		serial_codes.CMD_BWC_MODE_13 = 34;
		serial_codes.CMD_BWC_MODE_16 = 35;
		serial_codes.CMD_BWC_MODE_17 = 36;
		serial_codes.CMD_BWC_MODE_104 = 37;
		serial_codes.CMD_BWC_MODE_105 = 38;
		serial_codes.CMD_BWC_MODE_106 = 39;
		serial_codes.CMD_BWC_MODE_107 = 40;
		serial_codes.CMD_BWC_IGNORE = 41;
		serial_codes.CMD_SET_VIB_DUR = 42;
		serial_codes.CMD_SET_VIB_IPI = 43;
		serial_codes.CMD_SET_VIB_N = 44;
		serial_codes.CMD_SET_VIB_GAP_START = 45;
		serial_codes.CMD_SET_VIB_GAP_STOP = 46;
		serial_codes.CMD_VIB_MASK_ENABLE = 47;
		serial_codes.CMD_SET_VIB_TONE_FREQ = 48;
		serial_codes.CMD_SET_VIB_TONE_DUR = 49;
		serial_codes.CMD_SET_VIB_TASK_MODE = 50;

		serial_codes.EEPROM_BOOTH_NUM = 0;

		serial_codes.EEPROM_CAL_BASE_INT = 4;

		serial_codes.EEPROM_CAL_FORCE_INT = 6;

		serial_codes.EEPROM_CAL_TICK_INT = 8;

		serial_codes.EEPROM_LEVER_RANGE = 126;

		serial_codes.EEPROM_SN = 10;

		serial_codes.EEPROM_BOOTH_ID = 14;

		serial_codes.EEPROM_CAL_BASE_FL = 38;

		serial_codes.EEPROM_CAL_SLOPE_FL = 42;

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
% moto.lever_range = @(i)v1p4_simple_return(serialcon,'NA',1);                %Set the function for reading the degree range of a lever.
% moto.set_lever_range = @(int)v1p4_long_command(serialcon,'Onn',[],int);     %Set the function for setting the degree range of a lever.

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
% i = dec2bin(int16(int),16);                                                 %Convert the 16-bit integer to a 16-bit binary string.
% byteA = bin2dec(i(1:8));                                                    %Find the character that codes for the first byte.
% byteB = bin2dec(i(9:16));                                                   %Find the character that codes for the second byte.
% i = strfind(command,'nn');                                                  %Find the spot for the 16-bit integer bytes in the command.
% command(i:i+1) = char([byteA, byteB]);                                      %Insert the byte characters into the command.
bytes = typecast(int16(int),'uint8');                                       %Typecast the 16-bit integer into two bytes.
i = strfind(command,'nn');                                                  %Find the spot for the 16-bit integer bytes in the command.
command(i:i+1) = char(fliplr(bytes));                                       %Insert the byte characters into the command.
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
%   11/08/2019 - Drew Sloan - Added functions for sensory vibration task
%       control.
%


serialcon = moto.serialcon;                                                 %Grab the handle for the serial connection.
serialcon.Timeout = 2;                                                      %Set the timeout for serial read/write operations, in seconds.
serialcon.UserData = [2, 1, 2, 0, 0, 0, 0];                                 %Set the default number of inputs and the default stream order.

if ~isfield(moto,'version')                                                 %If no version is yet specified...
    pause(0.1);                                                             %Pause for 100 milliseconds.
    while serialcon.BytesAvailable > 0                                      %If there's any junk leftover on the serial line...
        fscanf(serialcon,'%d',serialcon.BytesAvailable);                    %Remove all of the replies from the serial line.
    end
    fwrite(serialcon,'Z','uchar');                                          %Send the check status code to the Arduino board.
    temp = fscanf(serialcon,'%d');                                          %Read the reply, which should be the version number.
    moto.version = temp/100;                                                %Divide the reply by 100 to get the version number.
end
s = Load_MotoTrak_Serial_Codes(moto.version);                               %Load the serial block codes for the specified sketch version.


%% Functions required for backwards compatibility.

%Basic status functions.
moto.check_serial = @()v2p0_check_serial(serialcon);                        %Set the function for checking the serial connection.
moto.check_sketch = @()v2p0_check_sketch(serialcon);                        %Set the function for checking that the MotoTrak sketch is running.
moto.check_version = ...
    @()v2p0_simple_return_uint16(serialcon,s.GET_SKETCH_VER);               %Set the function for returning the version of the MotoTrak sketch running on the controller.
moto.booth = @()v2p0_read_eeprom_uint16(serialcon,s,s.EEPROM_BOOTH_NUM);    %Set the function for returning the booth number saved on the controller.
moto.booth_bwc = ...
    @()v2p0_simple_return_char(serialcon,[char(s.GET_BOOTH_NUMBER), 'A']);  %Set the function for returning the booth number saved on the controller, in the backwards compatible method.
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
moto.lever_range = ...
    @()v2p0_read_eeprom_uint16(serialcon,s,s.EEPROM_LEVER_RANGE);           %Set the function for reading the degree range of a lever.
moto.set_lever_range = ...
    @(int)v2p0_write_eeprom_uint16(serialcon,s,s.EEPROM_LEVER_RANGE,int);   %Set the function for setting the loadcell baseline value.

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

%Vibration control commands.
moto.toggle_vibration = @()v2p0_send_uint8(serialcon,s.VIB_TOGGLE,[],0);    %Set the function for switching the LRA pin mode to output.
moto.start_vibration = @()v2p0_send_uint8(serialcon,s.START_VIB,[],0);      %Set the function for immediately starting a vibration pulse train.
moto.stop_vibration = @()v2p0_send_uint8(serialcon,s.STOP_VIB,[],0);        %Set the function for immediately stopping a vibration pulse train.
moto.set_vibration_dur = ...
    @(dur)v2p0_send_uint16(serialcon,s.SET_VIB_DUR,dur,0);                  %Set the function for setting the vibration pulse duration.
moto.get_vibration_dur = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_VIB_DUR);               %Set the function for checking the current vibration pulse duration.
moto.set_vibration_ipi = ...
    @(dur)v2p0_send_uint16(serialcon,s.SET_VIB_IPI,dur,0);                  %Set the function for setting the vibration pulse train onset-to-onset inter-pulse interval.
moto.get_vibration_ipi = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_VIB_IPI);               %Set the function for checking the current vibration pulse train onset-to-onset inter-pulse interval.
moto.set_vibration_n = ...
    @(dur)v2p0_send_uint16(serialcon,s.SET_VIB_N,dur,0);                    %Set the function for setting the vibration pulse train duration, in numbers of pulses.
moto.get_vibration_n = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_VIB_N);                 %Set the function for checking the current vibration pulse train duration, in numbers of pulses.
moto.set_vibration_gap_start = ...
    @(dur)v2p0_send_uint16(serialcon,s.SET_VIB_GAP_START,dur,0);            %Set the function for setting the vibration train starting skipped pulse index.
moto.get_vibration_gap_start = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_VIB_GAP_START);         %Set the function for checking the current vibration train starting skipped pulse index.
moto.set_vibration_gap_stop = ...
    @(dur)v2p0_send_uint16(serialcon,s.SET_VIB_GAP_STOP,dur,0);             %Set the function for setting the vibration train stop skipped pulse index.
moto.get_vibration_gap_stop = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_VIB_GAP_STOP);          %Set the function for checking the current vibration train stop skipped pulse index.
moto.set_vibration_masking = ...
    @(int)v2p0_send_uint8(serialcon,s.VIB_MASK_ENABLE,int,0);               %Set the function for enabling or disabling the stream.
moto.set_vibration_tone_freq = ...
    @(int)v2p0_send_uint16(serialcon,s.SET_VIB_TONE_FREQ,int,0);            %Set the function for setting the frequency of a tone.
moto.get_vibration_tone_freq = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_VIB_TONE_FREQ);         %Set the function for checking the current frequency of a tone.
moto.set_vibration_tone_dur = ...
    @(int)v2p0_send_uint16(serialcon,s.SET_VIB_TONE_DUR,int,0);             %Set the function for setting the duration of a tone.
moto.get_vibration_tone_dur = ...
    @()v2p0_simple_return_uint16(serialcon,s.RETURN_VIB_TONE_DUR);          %Set the function for checking the current duration of a tone.
moto.set_vibration_task_mode = ...
    @(int)v2p0_send_uint8(serialcon,s.SET_VIB_TASK_MODE,int,0);             %Set the function for setting the duration of a tone.
moto.get_vibration_task_mode = ...
    @()v2p0_simple_return_uint8(serialcon,s.RETURN_VIB_TASK_MODE);          %Set the function for checking the current duration of a tone.


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


%% This function sends a byte command and receives a character reply.
function output = v2p0_simple_return_char(serialcon,cmd)
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.


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
        streamdata = fscanf(serialcon,'%d')';                               %Read in the incoming data.
        output(end+1,:) = streamdata(1:N(1));                               %Read each byte and save it to the output matrix.
    catch err                                                               %If there was a stream read error...
        warning('MOTOTRAK:StreamingError',['MOTOTRAK STREAM READ '...
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
checker = zeros(numel(port),1);                                              %Create a check matrix to identify Arduino Unos.
for i = 1:numel(port)                                                       %Step through each port name.
    j = strfind(txt,['(' port{i} ')']);                                     %Find the port in the USB device list.
    if ~isempty(j)                                                          %If a matching port was found...
        if strcmpi(txt(j-12:j-2),'Arduino Uno') || ...
                strcmpi(txt(j-18:j-2),'USB Serial Device')                  %If the device is an Arduino Uno or a SAMD21.
            checker(i) = 1;                                                 %Mark the device for inclusion.
        end
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
            fwrite(serialcon,'A','uchar');                                  %Send the check status code to the Arduino board.
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


