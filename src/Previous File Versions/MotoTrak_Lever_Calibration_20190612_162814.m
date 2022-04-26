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
    h.ardy.clear();
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
if h.ardy.version < 200                                                     %If the controller microcode version is less than 2.00...
    h.baseline = h.ardy.baseline();                                         %Read the baseline from the Arduino EEPROM.
    h.grams = h.ardy.cal_grams();                                           %Read in the grams per total ticks for calculating calibration slope from the Arduino EEPROM.
    h.ticks = h.ardy.n_per_cal_grams();                                     %Read in the total ticks for calculating the calibration slope from the Arduino EEPROM.
    h.slope = h.grams/h.ticks;                                              %Calculate the current calibration slope.
    h.lever_range = h.grams;                                                %Save the lever range.
else                                                                        %Otherwise...
    h.baseline = h.ardy.get_baseline_float(1);                              %Read in the baseline value for the isometric pull handle loadcell.    
    h.slope = h.ardy.get_slope_float(1);                                    %Read in the slope value for the isometric pull handle loadcell.
    h.lever_range = h.ardy.lever_range();                                   %Read in the lever range.
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
if h.lever_range == 5                                                       %If the lever range is 5 degrees...
    set(h.ratradio,'value',0);                                              %Set the rat radiobutton value to zero.
    set(h.mouseradio,'value',1);                                            %Set the mouse radiobutton value to one.
else                                                                        %Otherwise, if the lever range is 11 degrees...
    set(h.ratradio,'value',1);                                              %Set the rat radiobutton value to one.
    set(h.mouseradio,'value',0);                                            %Set the mouse radiobutton value to zero.
end

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
                                    h.lever_range = 11;                     %Calculate the degrees per tick for an 11 degree range.
                                else                                        %Otherwise, if the mouse lever radio button is checked...
                                    h.lever_range = 5;                      %Calculate the degrees per tick for a 5 degree range.
                                end
                                m = h.lever_range./m;                       %Calculate the degrees per tick for the range
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
                    minmax_y = [0, 11];                                     %Set the maximum value to 11 degrees.
                else                                                        %Otherwise...
                    minmax_y = [0, 5];                                      %Set the maximum value to 5 degrees.
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
                    h.ardy.set_lever_range(minmax_y(2));                    %Save the lever range.
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