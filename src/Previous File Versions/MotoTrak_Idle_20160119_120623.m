function MotoTrak_Idle(handles)

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
run = -2;                                                                   %Initially set the run variable fto -2.
handles.ardy.clear();                                                       %Clear any residual values from the serial line.
do_once = 0;                                                                %Make a checker variable to see if a stream read is the first stream read.

active_offset = 0;
active_multiplier = 0;
static_offset = handles.total_range_in_degrees;

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
    warning(err.message);                                                   %Show the error message as a warning.
end