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