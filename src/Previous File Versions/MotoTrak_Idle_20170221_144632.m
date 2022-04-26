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
%

global run                                                                  %Create the global run variable.

handles = guidata(fig);                                                     %Grab the handles structure from the main GUI.

set(handles.startbutton,'string','START',...
   'foregroundcolor',[0 0.5 0],...
   'callback','global run; run = 2;')                                       %Set the string and callback for the Start/Stop button.
set(handles.feedbutton,'callback','global run; run = 1.2;')                 %Set the callback for the Manual Feed button.
            
p = [0,0];                                                                  %Create a matrix to hold plot handles.
ln = [0,0];                                                                 %Create a matrix to hold line object handles.
txt = [0,0];                                                                %Create a matrix to hold text object handles.
[p(1), ln(1), txt(1)] = MotoTrak_Idle_Initialize_Plots(handles.primary_ax); %Create plots on the primary axes for the main sensor signal.
set(p(1),'facecolor',[0.5 0.5 1]);                                          %Color the primary signal plot light blue.
[p(2), ln(2), txt(2)] = ...
    MotoTrak_Idle_Initialize_Plots(handles.secondary_ax);                   %Create plots on the secondary axes for the secondary sensor signal.
set(p(2),'facecolor',[1 0.5 0.5]);                                          %Color the secondary signal plot light red.
if strcmpi(handles.device,'both')                                           %If the user selected combined touch-pull...
    set(ln(2),'xdata',[1,1],'ydata',511.5*[1,1]);                           %Adjust the threshold line.
    set(txt(2),'position',[1,511.5]);                                       %Set the threshold label position.
    ylim(handles.secondary_ax,[0,1100]);                                    %Set the secondary axes y-axis limits.
end
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
        set(p(1),'xdata',(1:buffsize)','ydata',signal(:,1));                %Zero the primary signal area plot.
        set(p(2),'xdata',(1:buffsize)','ydata',signal(:,2));                %Zero the secondary signal area plot.
        if strcmpi(handles.device,'touch')                                  %If the current device is the touch sensor...
            thresh(2) = 511.5;                                              %Set the minimum threshold to half of the analog range.
        end
        set(ln,'xdata',[1,buffsize],'visible','on');                        %Set the x-coordinates for both threshold lines.
        set(ln(1),'ydata',thresh(1)*[1,1]);                                 %Set the y-coordinates for the primary signal threshold line.
        if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                %If a ceiling is set for this stage...
            max_y = [-0.1,1.3]*handles.ceiling;                             %Set the initial y-axis limits according to the ceiling value
            set(ceiling_ln,'xdata',[1,buffsize],...
                'ydata',handles.ceiling*[1,1],...                
                'visible','on');                                            %Update the ceiling-marking line.
            set(ceiling_txt,'position',[0.99*buffsize, handles.ceiling],...
                'visible','on');                                            %Update the position of the threshold label.
        else                                                                %Otheriwse, if there is no ceiling set for this stage.
            set([ceiling_ln, ceiling_txt],'visible','off');                 %Make the ceiling line and text invisible.
            max_y = [-0.1,1.3]*thresh(1);                                   %Set the initial primary y-axis limits according to the threshold value.
        end
        ylim(handles.primary_ax,max_y);                                     %Set the y-axis limits.
        xlim(handles.primary_ax,[1,buffsize]);                              %Set the primary x-axis limits according to the buffersize.
        xlim(handles.secondary_ax,[1,buffsize]);                            %Set the primary x-axis limits according to the buffersize.
        set(handles.primary_ax,'ytickmode','auto');                         %Set the y-tick mode to auto for the secondary axes.
        ticks = {[NaN,NaN],[NaN,NaN]};                                      %Create a cell array to hold tick label handles.
        set(txt(1),'position',[0.99*buffsize, thresh(1)],...
            'visible','on');                                                %Update the position of the primary threshold label.
        set(txt(2),'position',[0.99*buffsize, thresh(2)],...
            'visible','on');                                                %Update the position of the secondary threshold label.
        cal(1) = handles.slope;                                             %Set the calibration slope for the device.
        cal(2) = handles.baseline;                                          %Set the calibration baseline for the device.
        handles.ardy.stream_enable(1);                                      %Re-enable periodic streaming on the Arduino.        
        do_once = 0;                                                        %Reset the checker variable to zero out the signal before the first stream read.
        run = 1;                                                            %Set the run variable back to 1.
    end
    
    if run == 1.3                                                           %If the user pressed the manual feed button...        
        h.ardy.trigger_feeder(1);                                           %Trigger feeding on the Arduino.
        Add_Msg(h.msgbox,[datestr(now,13) ' - Manual Feeding.']);           %Show the user that the session has ended.
        run = 1;                                                            %Set the run variable back to 1.
    end
    
    if run == 1.4                                                           %If the user wants to reset the baseline...
        handles = guidata(fig);                                             %Grab the current handles structure from the main GUI.
        N = fix(buffsize/5);                                                %Find the number of samples in the last 1/5th of the existing signal.
        temp = (data(end-N+1:end,2)/cal(1)) + cal(2);                       %Convert the buffered data back to the uncalibrated raw values.
        handles.baseline = mean(temp);                                      %Set the baseline to the average of the last 100 signal samples.
        cal(2) = handles.baseline;                                          %Set the calibration baseline for the device.
        guidata(fig,handles);                                               %Pin the updated handles structure back to the GUI.
        
        if cal(1) > 1                                                       %If the slope of the line is greater than 1...
            b = 32767;                                                      %Set the calibration force to a maximum 16-bit integer.
            a = round(b/cal(1));                                            %Calculate the sensor reading that would correspond to that force.
        else                                                                %Otherwise, if the slope of the line is less than 1...
            a = 32767;                                                      %Set the calibration loadcell reading to a maximum 16-bit integer.
            b = round(cal(1)*a);                                            %Calculate the calibration force that would yield such a sensor reading.
        end
        handles.ardy.set_baseline(cal(2));                                  %Save the baseline value in the EEPROM on the Arduino board.
        handles.ardy.set_n_per_cal_grams(a);                                %Save the maximum sensor reading on the EEPROM.
        handles.ardy.set_cal_grams(b);                                      %Save the maximum calibration force on the EEPROM.                
        run = 1;                                                            %Set the run variable back to 1.
    end
    
    temp = handles.ardy.read_stream();                                      %Read in any new stream output.          
    a = size(temp,1);                                                       %Find the number of new samples.
    if a > 0                                                                %If there was any new data in the stream.     
        
        temp(:,2) = cal(1)*(temp(:,2) - cal(2));                            %Apply the calibration constants to the primary data signal.        
        data(1:end-a,:) = data(a+1:end,:);                                  %Shift the existing buffer samples to make room for the new samples.
        data(end-a+1:end,:) = temp;                                         %Add the new samples to the buffer.
        
        signal(1:end-a,:) = signal(a+1:end,:);                              %Shift the existing samples in the monitored to make room for the new samples.
        if do_once == 0                                                     %If this was the first stream read...                     
            signal(:,1) = data(end,2);                                      %Fill the primary signal with the last value of the data buffer.
            switch handles.curthreshtype                                    %Switch between the types of signal thresholds.  
                case 'milliseconds/grams'                                   %If the current threshold type is the combined touch-pull...
                    signal(:,2) = data(end,3);                              %Fill the secondary signal with the last value of the data buffer.
                otherwise                                                   %Otherwise, for all other threshold types.
                    signal(:,2) = 1023 - data(end,3);                       %Fill the secondary signal with the inverse of the last value of the data buffer.
            end
            data(1:buffsize-a,2) = data(buffsize-a+1,2);                    %Set all of the preceding primary data points equal to the first point.
            data(1:buffsize-a,3) = data(buffsize-a+1,3);                    %Set all of the preceding secondary data points equal to the first point.            
            do_once = 1;                                                    %Set the checker variable to 1.
        end
        
        i = buffsize-a+1:buffsize;                                          %Grab the indices for the new samples.        
        switch handles.curthreshtype                                        %Switch between the types of signal thresholds.                      
            case {'presses', 'fullpresses'}                                 %If the threshold type is the number of presses or the number of full presses...
                if strcmpi(handles.device,'knob')                           %If the current device is the knob...
                    signal(i,1) = data(i,2) - data(i-hit_samples+1,2);      %Find the change in the degrees integrated over the hit window.
                else                                                        %Otherwise, if the current device is the lever...
                    signal(i,1) = data(i,2);                                %Transfer the new samples to the signal as-is.
                end
            case {'grams (peak)', 'grams (sustained)'}                      %If the current threshold type is the peak pull force or sustained pull force.
                if strcmpi(handles.stage(handles.cur_stage).number,'PASCI1')               %If the current stage is PASCI1...
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
            case 'milliseconds/grams'                                       %If the current threshold type is the combined touch-pull...
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
                max_y = ...
                    [min([1.1*min(signal(:,1)), -0.1*handles.ceiling]),...
                    max([1.1*max(signal(:,1)), 1.3*handles.ceiling])];      %Calculate new y-axis limits.
            else                                                            %Otherwise...
                max_y = [min([1.1*min(signal(:,1)), -0.1*thresh(1)]),...
                max([1.1*max(signal(:,1)), 1.3*thresh(1)])];                %Calculate new y-axis limits.  
            end      
            if max_y(1) == max_y(2)                                         %If the top and bottom limits are the same...
                max_y = max_y(1) + [-1,1];                                  %Arbitrarily add one above and below the constant value.
            end
            ylim(handles.primary_ax,max_y);                                 %Set the new y-axis limits.
            temp = get(txt(1),'extent');                                    %Grab the position of the threshold label.
            if temp(2) < max_y(1)                                           %If the bottom edge of the text is outside the bounds...
                set(txt(1),'verticalalignment','bottom');                   %Align the text at its bottom.
            end
            temp_ticks = get(handles.primary_ax,'ytick')';                  %Grab the current y-axis tick values.
            if ~isequal(ticks{1}(:,1),temp_ticks)                           %If the tick values have changed.
                if ~isnan(ticks{1}(1,2))                                    %If there are pre-existing tick values...
                    delete(ticks{1}(:,2));                                  %Delete the tick label handles.
                end
                switch handles.curthreshtype                                %Switch between the types of signal thresholds.                      
                    case {'grams (peak)', 'grams (sustained)',...
                            'milliseconds/grams' }                          %If the current threshold type is any of the pull force variants.
                        units = ' g';                                       %Label the ticks with a grams unit.
                    otherwise                                               %Otherwise, for all other threshold types.
                        units = '\circ';                                    %Label the ticks with a degree sign.
                end      
                ticks{1} = [temp_ticks, nan(size(temp_ticks))];             %Create a new matrix of tick values and handles.
                for j = 1:numel(temp_ticks)                                 %Step through each tick mark.
                    ticks{1}(j,2) = text(0.02*buffsize,temp_ticks(j),...
                        [num2str(temp_ticks(j)) units],...
                        'horizontalalignment','left',...
                        'verticalalignment','middle',...
                        'fontsize',8,...
                        'parent',handles.primary_ax);                       %Create tick labels at each tick mark.
                end
            end
        end
        if i(2) == 1 || ...
                strcmpi(handles.curthreshtype,'milliseconds/grams');        %If the secondary tab is selected or it's a combined touch/pull stage...
            set(p(2),'ydata',signal(:,2),'basevalue',ir_minmax(1));         %Update the area plot.
            set(txt(2),'verticalalignment','top',...
                'position',[0.99*buffsize,thresh(2)]);                      %Set the position of the threshold label.
            set(ln(2),'ydata',thresh(2)*[1,1]);                             %Set the position of the threshold line.
            max_y(1) = ir_minmax(1)-0.1*(ir_minmax(2)-ir_minmax(1));        %Calculate the lower end of the y-axis limits.    
            max_y(2) = max([1.1*max(signal(:,2)), 1.3*thresh(2)]);          %Calculate the upper end of the y-axis limits.
            if max_y(1) == max_y(2)                                         %If the top and bottom limits are the same...
                max_y = [-1,1];                                             %Arbitrarily add one above and below the constant value.
            end
            ylim(handles.secondary_ax,max_y);                               %Set the new y-axis limits.
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