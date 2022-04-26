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
%

global run                                                                  %Create the global run variable.

h = guidata(fig);                                                           %Grab the handles structure from the main GUI.

MotoTrak_Disable_Controls_Within_Session(h);                                %Disable all of the uicontrols and uimenus during the session.
    
set(h.startbutton,'string','STOP',...
   'foregroundcolor',[0.5 0 0],...
   'callback','global run; run = 1;')                                       %Set the string and callback for the Start/Stop button.
set(h.feedbutton,'callback','global run; run = 2.2;')                 %Set the callback for the Manual Feed button.

if ~isfield(h,'hitrate_tab')                                                %If there is no tab yet for session hit rate axes...
    h.hitrate_tab = uitab('parent',h.plot_tab_grp,...
        'title','Session Hit Rate',...
        'backgroundcolor',get(h.mainfig,'color'));                          %Create a tab for the trial-by-trial hit rate.
    h.hitrate_ax = axes('parent',h.hitrate_tab,...
        'units','normalized',...
        'position',[0 0 1 1],...
        'box','on',...
        'xtick',[],...
        'ytick',[]);                                                        %Create the trial hit rate axes.
else                                                                        %Otherwise...
    cla(h.hitrate_ax);                                                      %Clear the hit rate axes.
end
if ~isfield(h,'session_tab')                                                %If there is no tab yet for session performance measure...
    h.session_tab = uitab('parent',h.plot_tab_grp,...
        'title','Session Performance',...
        'backgroundcolor',get(h.mainfig,'color'));                          %Create a tab for the performance measure axes.
    h.session_ax = axes('parent',h.session_tab,...
        'units','normalized',...
        'position',[0 0 1 1],...
        'box','on',...
        'xtick',[],...
        'ytick',[]);                                                        %Create the performance measure axes.
else                                                                        %Otherwise...
    cla(h.session_ax);                                                      %Clear the hit rate axes.
end
switch h.curthreshtype                                                      %Switch between the recognized threshold types.
    case {'degrees (total)', 'bidirectional'}                               %If the threshold type is the total number of degrees...
        set(h.session_tab,'title','Trial Peak Angle');                      %Set the performance axes to display trial spin velocity.
    case 'degrees/s'                                                        %If the threshold type is the number of spins or spin velocity.
        set(h.session_tab,'title','Trial Spin Velocity');                   %Set the performance axes to display trial spin velocity.
    case '# of spins'                                                       %If the threshold type is the number of spins or spin velocity.
        set(h.session_tab,'title','Trial Number of Spins');                 %Set the performance axes to display trial number of spins.
    case {'grams (peak)', 'grams (sustained)','milliseconds/grams'}         %If the threshold type is a variant of peak pull force.
        set(h.session_tab,'title','Trial Peak Force');                      %Set the performance axes to display trial peak force.
    case {'presses', 'fullpresses'}                                         %If the threshold type is presses or full presses..
        set(h.session_tab,'title','Trial Press Counts');                    %Set the performance axes to display trial press counts.
    case 'milliseconds (hold)'                                              %If the threshold type is a hold...
        set(h.session_tab,'title','Trial Hold Time');                       %Set the performance axes to display trial hold times.
end        

Clear_Msg([],[],h.msgbox);                                                  %Clear the original Arduino connection message out of the listbox.

pause_text = 0;                                                             %Create a variable to hold a text handle for a pause label.
start_time = now;                                                           %Set the session start time.
endtime = start_time + h.session_dur/1440;                                  %Set a suggested session end time.
trial = 0;                                                                  %Make a counter to count trials.
feedings = 0;                                                               %Make a counter to count feedings.
cal(1) = h.slope;                                                           %Set the calibration slope for the device.
cal(2) = h.baseline;                                                        %Set the calibration baseline for the device.
minmax_ir = [1023,0,0];                                                     %Keep track of the minimum and maximum IR values.
errstack = zeros(1,4);                                                      %Create a matrix to prevent duplicate error-reporting.

fid = MotoTrak_Write_File_Header(h);                                        %Use the WriteFileHeader subfunction to write the file header.

%Create the variables for buffering the signal from the device.
pre_samples = round(1000*h.pre_trial_sampling/h.period);                    %Calculate how many samples are in the pre-trial sample period.
post_samples = round(1000*h.post_trial_sampling/h.period);                  %Calculate how many samples are in the post-trial sample period.
hit_samples = round(1000*h.hitwin/h.period);                                %Find the number of samples in the hit window.
hitwin = (pre_samples+1):(pre_samples+hit_samples);                         %Save the samples within the hit window.
buffsize = pre_samples + hit_samples + post_samples;                        %Specify the size of the data buffer, in samples.
minpkdist = round(100/h.period);                                            %Find the number of samples in a 100 ms window for finding peaks.

%Set the min peak height depending on the device connected
minpkheight = 0;                                                            %Create a variable for excluding spurious peaks in the signal.
lever_return_point = 0;                                                     %Create a variable to prevent sustained signals from being treated as repeating peaks.
if strcmpi(h.device,{'lever'})                                              %If the current device is the lever...       
    minpkheight = h.total_range_in_degrees * 0.75;                          %A "press" must be at least 3/4 of the range of motion of the lever.          
    lever_return_point = h.total_range_in_degrees * 0.5;                    %Lever must return to the 50% point in its range before a new press begins
elseif (strcmpi(h.device,{'knob'}) == 1)                                    %Otherwise, if the current device is the knob.
    minpkheight = 3;                                                        %Set the minimum peak height to 3 degrees to prevent noise from appearing as a peak.
end

offset = ceil(minpkdist/2);                                                 %Calculate the number of samples to offset when grabbing the smoothed signal.
data = zeros(buffsize,3);                                                   %Create a matrix to buffer the stream data.
trial_data = zeros(buffsize,3);                                             %Create a matrix to hold the trial stream data.
mon_signal = zeros(buffsize,1);                                             %Create a matrix to hold the monitored signal.
trial_signal = zeros(buffsize,1);                                           %Create a matrix to hold the trial signal.
if strcmpi(h.device,'both')                                                 %If this is a combined touch-pull stage...
    touch_signal = zeros(buffsize,1);                                       %Zero out the trial signal.
end
do_once = 1;                                                                %Create a one-shot checker to keep from counting transient signals on the first stream read.
vns_time = [];                                                              %Create a buffer matrix to hold VNS times.
maxthresh = 0;                                                              %Create a variable to keep track of the maximum threshold used.
sustained_pull_grams_threshold = 35;                                        %Hit threshold with respect to grams for sustained pull.

burst_stim_num = 0;                                                         %Create a variable to hold the number of times burst stimulation has happened (for burst stim mode only)
burst_stim_time = start_time;                                               %Create a variable to hold the time of the first burst stim (for burst stim mode only)

% hold(h.hitrate_ax, 'off');                                                  %Release any plot hold on the trial hit rate axes.
% cla(h.hitrate_ax);                                                          %Clear any plots off the trial hit rate axes.
% hold(h.performance_ax, 'off');                                              %Release any plot hold on the trial performance measure axes.
% cla(h.performance_ax);                                                      %Clear any plots off the trial hperformance measure axes.

%For random stimulation modes, set the random stimulation times.
if h.vns == 2                                                               %If random stimulation is enabled...
    if strcmpi(h.stage(h.cur_stage).number,'P11')                           %If the current stage is P11...
        num_stim = 180;                                                     %Set the desired total number of VNS events.
        isi = 5;                                                            %Set the fixed ISI between all events, VNS or catch trials.
        catch_trial_prob = 0.5;                                             %Set the catch trial probability.
        N = ceil(num_stim/(1-catch_trial_prob));                            %Calculate the required total number of events to meet the catch trial probability.
        temp = randperm(N);                                                 %Create random permutation of the events.
        temp = sort(temp(1:num_stim));                                      %Grab the indices for only the VNS events.
        rand_vns_times = isi*temp/86400;                                    %Set times for the random VNS events, in units of serial date number.
        rand_vns_times = rand_vns_times + now;                              %Adjust the times relative to the session start.
    elseif strcmpi(h.stage(h.cur_stage).number,'P15')                       %If the current stage is P15...
        num_stim = 900;                                                     %Set the desired total number of VNS events.
        rand_vns_times = ones(1,num_stim);                                  %Create a matrix of 1-second inter-VNS intervals.
        rand_vns_times(1:round(num_stim/2)) = 3;                            %Set half of the inter-VNS intervals to 3 seconds.
        rand_vns_times = rand_vns_times(randperm(num_stim));                %Randomize the inter-VNS intervals.
        for i = num_stim:-1:2                                               %Step backward through the inter-VNS intervals.
            rand_vns_times(i) = sum(rand_vns_times(1:i));                   %Set each stimulation time as the sum of all precedingin inter-VNS intervals.
        end
        rand_vns_times = now + rand_vns_times/86400;                        %Convert the intervals to stimulation times, in units of serial date number.
    end
elseif h.vns == 3                                                           %If burst stimulation is enabled.
    h.ardy.set_stim_dur(29550);                                             %Set the stimulus duration to trigger free running stimulation for 30 seconds.
    %Note:  We set this to a conservatice 29550 instead of 30000 so that we
    %       don't accidentally trigger an extra pulse train at the end of
    %       30 seconds of stimulation.
end

%Set the initiation threshold for static or adaptive thresholding.
curthresh = h.threshmin;                                                    %Set the current hit threshold to the minimum hit threshold.
if strcmpi(h.threshadapt,'median')                                          %If this stage has a median-adapting threshold...
    max_tracker = nan(h.threshincr,1);                                      %Create a matrix to track the maximum device reading within the hit window across trials.
end
if strcmpi(h.device,'touch')                                                %If the current device is the touch sensor...
    h.init = 0.5;                                                           %Set the initiation threshold to 0.5.
end

%Set the Arduino parameters for this session.
h.ardy.clear();                                                             %Clear any residual values from the serial line.
if h.vns == 1 && strcmpi(h.custom,'machado lab') && ...
        strcmpi(h.curthreshtype,'milliseconds/grams')                       %If stimulation is on and this is a the Machado lab variant...
    temp = round(1000*h.hitwin);                                            %Find the length of the hit window in milliseconds.
    h.ardy.set_stim_dur(temp);                                              %Set the default stimulation duration to the entire hit window.
    stim_time_out = round(1000*h.stim_time_out/...
        h.stage(h.cur_stage).period) - 1;                                   %Calculate the number of samples in the stimulation time-out duration.
end
MotoTrak_Set_Stream_Params(h);                                              %Set the streaming properties on the Arduino.
h.ardy.stream_enable(1);                                                    %Enable periodic streaming on the Arduino.


Total_Degrees_Turned = nan(500,1);

while fix(run) == 2                                                         %Loop until the user ends the session.
                                                             
    trial = trial + 1;                                                      %Increment the trial counter.
    mon_signal(:) = 0;                                                      %Zero out the monitor signal.
    trial_signal(:) = 0;                                                    %Zero out the trial signal.
    if strcmpi(h.device,'both')                                             %If this is a combined touch-pull stage...
        touch_signal(:) = 0;                                                %Zero out the trial signal.
    end
    trial_data(:) = 0;                                                      %Zero out the trial data.
    base_value = 0;
    ir_initiate = 0;                                                        %Create a variable for triggering trial initiation with the IR signal.
    trial_buffsize = buffsize;                                              %Set the trial buffsize to be the entire buffer size.
    ceiling_check = 0;                                                      %Keep track of whether the ceiling was broken.
    
    cla(h.primary_ax);                                                      %Clear the streaming axes.
    p = zeros(1,3);                                                         %Pre-allocate a matrix to hold plot handles.
    p(1) = area(1:buffsize,mon_signal,...
        'linewidth',2,...
        'facecolor',[0.5 0.5 1],...
        'parent',h.primary_ax);                                             %Make an initiation areaseries plot.    
    set(h.primary_ax,'xtick',[],'ytick',[]);                                %Get rid of the x- y-axis ticks.
    max_y = [-0.1,1.3]*h.init;                                              %Calculate y-axis limits based on the trial initiation threshold.
    ylim(h.primary_ax,max_y);                                               %Set the new y-axis limits.
    xlim(h.primary_ax,[1,buffsize]);                                        %Set the x-axis limits according to the buffersize.
%     ir_text = text(0.02*buffsize,max_y(2)-0.03*range(max_y),'IR',...
%         'horizontalalignment','left',...
%         'verticalalignment','top',...
%         'margin',2,...
%         'edgecolor','k',...
%         'backgroundcolor','w',...
%         'fontsize',10,...
%         'fontweight','bold',...
%         'parent',h.primary_ax);                                             %Create text to show the state of the IR signal.
    clock_text = text(0.97*buffsize,max_y(2)-0.03*range(max_y),...
        ['Session Time: ' datestr(now-start_time,13)],...
        'horizontalalignment','right',...
        'verticalalignment','top',...
        'margin',2,...
        'edgecolor','k',...
        'backgroundcolor','w',...
        'fontsize',10,...
        'fontweight','bold',...
        'parent',h.primary_ax);                                             %Create text to show a session timer.
    if strcmpi(h.device,'both')                                             %If the user selected combined touch-pull...
        p(3) = area(1:buffsize,mon_signal,...
            'linewidth',2,...
            'facecolor',[0.5 1 0.5],...
            'parent',h.secondary_ax);                                       %Make an initiation areaseries plot.
        line([1,buffsize],h.init*[1,1],...
            'color','k',...
            'linestyle',':',...
            'parent',h.secondary_ax);                                       %Plot a dotted line to show the threshold.
        text(1,h.init,' Initiation Threshold',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'parent',h.secondary_ax);                                       %Create text to label the the threshold line.
        set(h.secondary_ax,'xtick',[],'ytick',[]);                          %Get rid of the x- y-axis ticks.
        max_y = [-1.3,1.3]*h.init;                                          %Calculate y-axis limits based on the trial initiation threshold.
        ylim(h.secondary_ax,max_y);                                         %Set the new y-axis limits.
        xlim(h.secondary_ax,[1,buffsize]);                                  %Set the x-axis limits according to the buffersize.
    else                                                                    %Otherwise, if this isn't a combined touch-pull stage...
        line([1,buffsize],h.init*[1,1],...
            'color','k',...
            'linestyle',':',...
            'parent',h.primary_ax);                                         %Plot a dotted line to show the threshold.
        text(1,1,' Initiation Threshold',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'parent',h.primary_ax);                                         %Create text to label the the threshold line.
    end
    
    while max(mon_signal) < h.init && ...
            ir_initiate == 0 && ...
            run == 2                                                        %Loop until the the initiation threshold is broken or the session is stopped.
    	temp = h.ardy.read_stream();                                        %Read in any new stream output.
        a = size(temp,1);                                                   %Find the number of new samples.
        if a > 0                                                            %If there was any new data in the stream.
            temp(:,2) = cal(1)*(temp(:,2) - cal(2));                        %Apply the calibration constants to the data signal.
            
            data(1:end-a,:) = data(a+1:end,:);                              %Shift the existing buffer samples to make room for the new samples.
            try                                                             %Attempt to add new samples to the buffer.
                data(end-a+1:end,:) = temp;                                 %Add the new samples to the buffer.
            catch err                                                       %If an error occurred...
                txt = getReport(err,'extended');                            %Get an extended report about the error.
                a = strfind(txt,'<a');                                      %Find all hyperlink starts in the text.
                for i = length(a):-1:1                                      %Step backwards through all hyperlink commands.
                    j = find(txt(a(i):end) == '>',1,'first') + a(i) - 1;    %Find the end of the hyperlink start.
                    txt(a(i):j) = [];                                       %Kick out all hyperlink calls.
                end
                a = strfind(txt,'a>') + 1;                                  %Find all hyperlink ends in the text.
                for i = length(a):-1:1                                      %Step backwards through all hyperlink commands.
                    j = find(txt(1:a(i)) == '<',1,'last');                  %Find the end of the hyperlink end.
                    txt(j:a(i)) = [];                                       %Kick out all hyperlink calls.
                end
                txt = horzcat(txt,...
                    sprintf('\n\nsize(data) = [%1.0f, %1.0f]',size(data))); %Add the size of the data variable to the text.
                txt = horzcat(txt,...
                    sprintf('\n\na = %1.3f\n\ntemp = \n',a));               %Add the value of the a variable.
                for i = 1:size(temp,1)                                      %Step through each line of the temp variable.
                    txt = horzcat(txt,sprintf('%1.3f ',temp(i,:)),10);      %Add the value of the a variable.
                end
                MotoTrak_Send_Error_Report(h,h.err_rcpt,txt);               %Send an error report to the specified recipient.
            end
            data(end-a+1:end,:) = temp;                                     %Add the new samples to the buffer.
            if do_once == 1                                                 %If this was the first stream read...
                data(1:buffsize-a,2) = data(buffsize-a+1,2);                %Set all of the preceding signal data points equal to the first point.           
                data(1:buffsize-a,3) = data(buffsize-a+1,3);                %Set all of the preceding IR data points equal to the first point.    
                do_once = 0;                                                %Set the checker variable to 1.
            end
            mon_signal(1:end-a,:) = mon_signal(a+1:end);                    %Shift the existing samples in the monitored to make room for the new samples.
            
            switch h.curthreshtype                                          %Switch between the types of hit threshold.
                
                case 'degrees (total)'                                      %If the theshold type is the total number of degrees.                
                    if h.cur_stage == 1
                        for i = buffsize-a+1:buffsize                       %Step through each new sample in the monitored signal.
                            mon_signal(i) = data(i,2) - ...
                                data(i-hit_samples+1,2);                    %Find the change in the degrees integrated over the hit window.
                        end
                    else
                        for i = buffsize-a+1:buffsize                       %Step through each new sample in the monitored signal.
                            mon_signal(i) = data(i,2);                      %Find the change in the degrees integrated over the hit window
                        end
                    end
                
                case 'bidirectional'                                        %If the threshold type is the bidirectional number of degrees...
                    for i = buffsize-a+1:buffsize                           %Step through each new sample in the monitored signal.
                        mon_signal(i) = abs(data(i,2));                     %Find the change in the degrees integrated over the hit window.
                    end
                    
                case {'presses', 'fullpresses'}                             %If the current threshold type is presses (for LeverHD)
                    if (strcmpi(h.device, {'knob'}) == 1)
                         for i = buffsize-a+1:buffsize                      %Step through each new sample in the monitored signal.
                              mon_signal(i) = abs(data(i,2) - ...
                                  data(i-hit_samples+1,2));
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
                    
                case {'grams (peak)', 'grams (sustained)'}                  %If the current threshold type is the peak pull force.
                    if strcmpi(h.stage(h.cur_stage).number,'PASCI1')        %If the current stage is PASCI1...
                        mon_signal(buffsize-a+1:buffsize) = ...
                            abs(data(buffsize-a+1:buffsize,2));             %Show the pull force at each point.
                    else
                        mon_signal(buffsize-a+1:buffsize) = ...
                            data(buffsize-a+1:buffsize,2);                  %Show the pull force at each point.
                    end
                    
                case 'milliseconds (hold)'                                  %If the current threshold type is a sustained hold...
                    mon_signal(buffsize-a+1:buffsize) = ...
                            (data(buffsize-a+1:buffsize,3) > 511.5);        %Digitize the threshold.
                        
                case 'milliseconds/grams'                                   %If the current threshold type is a combined hold/pull...
                    for i = buffsize-a+1:buffsize                           %Step through each new sample...
                        if data(i,3) > 511.5                                %If the sample is a logical high...
                            mon_signal(i) = mon_signal(i-1) - 10;           %Add 10 milliseconds to the running count for this sample.
                        else                                                %Otherwise...
                            if abs(mon_signal(i-1)) > h.init && ...
                                    data(i,3) < 511.5                       %If the rat just released the sensor after holding for the appropriate time.
                                mon_signal(i) = h.init;                     %Set the monitor signal current sample to the initiation threshold.
                            else                                            %Otherwise...
                                mon_signal(i) = 0;                          %Reset the count.
                            end
                        end
                    end
            end
            
            if h.ir == 1 && any(data(end-a+1:end,3) < minmax_ir(3))         %If IR-initiation is enabled and the IR beam is blocked...
                ir_initiate = 1;                                            %Initiate a trial.
            end
            
            if strcmpi(h.device,'both')                                     %If this is a combined touch-pull session...
                set(p(1),'ydata',data(:,2));                                %Update the force area plot.
                max_y = [min([1.1*min(data(:,2)), -0.1*curthresh]),...
                    max([1.1*max(data(:,2)), 1.3*curthresh])];              %Calculate new y-axis limits.
                ylim(h.primary_ax,max_y);                                   %Set the new y-axis limits.
                set(p(3),'ydata',mon_signal);                               %Update the touch area plot.
                max_y = [min([1.1*min(mon_signal), -1.1*h.init]),...
                    max([1.1*max(mon_signal), 1.1*h.init])];                %Calculate new y-axis limits.
                ylim(h.secondary_ax,max_y);                                 %Set the new y-axis limits.
            else                                                            %Otherwise...
                set(p(1),'ydata',mon_signal);                               %Update the area plot.
                max_y = [min([1.1*min(mon_signal), -0.1*curthresh]),...
                    max([1.1*max(mon_signal), 1.3*curthresh])];             %Calculate new y-axis limits.
                ylim(h.primary_ax,max_y);                                   %Set the new y-axis limits.
            end
%             ir_pos = [0.02*buffsize, max_y(2)-0.03*range(max_y)];           %Update the x-y position of the IR text object.
            minmax_ir(1) = min([minmax_ir(1); data(:,3)]);                  %Calculate a new minimum IR value.
            minmax_ir(2) = max([minmax_ir(2); data(:,3)]);                  %Calculate a new maximum IR value.
            if minmax_ir(2) - minmax_ir(1) >= 25                            %If the IR value range is less than 25...
                minmax_ir(3) = h.ir_initiation_threshold*(minmax_ir(2) -...
                    minmax_ir(1)) + minmax_ir(1);                           %Set the IR threshold to the specified relative threshold.
            elseif minmax_ir(1) == minmax_ir(2)                             %If there is no range in the IR values.
                minmax_ir(1) = minmax_ir(1) - 1;                            %Set the IR minimum to one less than the current value.
            end
%             c = (data(end,3) - minmax_ir(1))/(minmax_ir(2) - minmax_ir(1)); %Calculate the color of the IR indicator.
%             set(ir_text,'backgroundcolor',[1 c c],...
%                 'position',ir_pos);                                         %Color the IR indicator text according to the signal..
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
        set(clock_text,...
            'position',[0.97*buffsize, max_y(2)-0.03*range(max_y)],...
            'string',['Session Time: ' datestr(now-start_time,13)]);        %Update the session timer text object.
        if now > endtime                                                    %If the suggested session time has passed...
            set(clock_text,'backgroundcolor','r');                          %Color the session timer text object red.
            endtime = Inf;                                                  %Set the new suggested end time to infinite.
        end
        if h.vns == 2                                                       %If random VNS is enabled...
            a = find(rand_vns_times > 0,1,'first');                         %Find the next random VNS time.
            if ~isempty(a) && now > rand_vns_times(a)                       %If the clock has reached the next random stimulation time.
                h.ardy.stim();                                              %Trigger VNS through the Arduino.
                vns_time(end+1) = now;                                      %Save the current time as a VNS time.
                rand_vns_times(a) = 0;                                      %Mark this stimulation time as completed.
            end
        end
        pause(0.01);                                                        %Pause for 10 milliseconds to keep from overwhelming the processor.
        drawnow;                                                            %Update the figure and flush the event queue.
    end
    
    if run == 2                                                             %If the session is running and not paused or set for a manual feeding...
        if ir_initiate == 0                                                 %If the trial wasn't initiated by the IR detector...
            a = find(mon_signal >= h.init,1,'first') - 1;                   %Find the timepoint where the trial initiation threshold was first crossed.
        else                                                                %Otherwise...
            a = buffsize;                                                   %Set initiation sample to the current sample.
        end
        cur_sample = buffsize - a + pre_samples;                            %Find the number of samples to copy from the pre-trail monitoring.
        a = a - pre_samples + 1;                                            %Find the start of the pre-trial period.
        try
            trial_data(1:cur_sample,:) = data(a:buffsize,:);                %Copy the pre-trial period to the trial data.
        catch err                                                           %If an error occurred...
            if errstack(1) == 0                                             %If this error hasn't yet been reported...
                MotoTrak_Send_Error_Report(h,h.err_rcpt,err);               %Send an error report to the specified recipient.
            end
            errstack(1) = 1;                                                %Set the error reported value to 1 to prevent redundant reports.
        end
        trial_start = [now, data(a,1)];                                     %Save the trial start times (computer and Arduino clocks).
        
        switch h.curthreshtype                                              %Switch between the types of hit threshold.
            
            case {'degrees (total)','bidirectional'}                        %If the current threshold type is the total number of degrees...
                if h.cur_stage == 1
                    base_value = min(data(end-200,2));                      %Set the base value to the degrees value right at the initiation threshold crossing.
                    trial_signal(1:cur_sample) = data(a:buffsize,2) - ...
                        base_value;                                         %Copy the pre-trial wheel position minus the base value.
                else
                    base_value = 0;                                         %Set the base value to the degrees value right at the initiation threshold crossing.
                    trial_signal(1:cur_sample) = data(a:buffsize,2);        %Copy the pre-trial wheel position minus the base value.    
                end
                
            case {'degrees/s','# of spins'}                                 %If the current threshold type is the number of spins or spin velocity.
                base_value = 0;                                             %Set the base value to zero spin velocity.
                temp = diff(data(:,2));                                     %Find the wheel velocity at each point in the buffer.
                temp = boxsmooth(temp,minpkdist);                           %Boxsmooth the wheel velocity with a 100 ms smooth.
                trial_signal(1:cur_sample) = temp(a-1:buffsize-1);          %Grab the pre-trial spin velocity.
                
            case {'grams (peak)', 'grams (sustained)'}                      %If the current threshold type is the peak pull force.
                base_value = 0;                                             %Set the base value to zero force.
                if strcmpi(h.stage(h.cur_stage).number,'PASCI1')            %If the current stage is PASCI1...
                    trial_signal(1:cur_sample) = abs(data(a:buffsize,2));   %Copy the pre-trial force values.
                else
                    trial_signal(1:cur_sample) = data(a:buffsize,2);        %Copy the pre-trial force values.
                end
                
            case {'presses', 'fullpresses'}                                 %If the current threshold type is presses (for LeverHD)            
                if (strcmpi(h.device,{'knob'}) == 1)
                    base_value = data(a,2);
                    trial_signal(1:cur_sample) = data(a:buffsize,2) - ...
                        base_value;                                         %Copy the pre-trial wheel position minus the base value.
                else
                    base_value = 0;
                    trial_signal(1:cur_sample) = data(a:buffsize,2);
                end
                
            case 'milliseconds (hold)'                                      %If the current threshold type is a hold...
                base_value = cur_sample;                                    %Set the base value to the starting sample.
                trial_signal(cur_sample) = 10;                              %Set the first sensor value to 10.
                
            case 'milliseconds/grams'                                       %If the current threshold type is a hold...
                h.ardy.play_hitsound(1);                                    %Play the hit sound.
                base_value = 0;                                             %Set the base value to zero force.
                trial_signal(1:cur_sample) = data(a:buffsize,2);            %Copy the pre-trial force values.
    %             touch_signal(1:cur_sample) = 1023 - data(a:buffsize,3);	  %Copy the pre-trial touch values.
                touch_signal(1:cur_sample) = data(a:buffsize,3);            %Copy the pre-trial touch values.
                if h.vns == 1                                               %If stimulation is on...
                    h.ardy.stim();                                          %Turn on stimulation.
                end
        end
        
        cla(h.primary_ax);                                                  %Clear the current axes.
        p(1) = area(1:buffsize,trial_signal,...
            'linewidth',2,...
            'facecolor',[0.5 0.5 1],...
            'parent',h.primary_ax);                                         %Make an areaseries plot to show the trial signal.
        hold(h.primary_ax,'on');                                            %Hold the axes for multiple plots.
        
        if any(strcmpi(h.curthreshtype,{'# of spins','presses'}))           %If the threshold type is the number of spins or number of pressess...
            p(2) = plot(-1,-1,'*r','parent',h.primary_ax);                  %Mark the peaks with red asterixes.
        end
        
        hold(h.primary_ax,'off');                                           %Release the plot hold.
        if ~strcmpi(h.curthreshtype,'# of spins')                           %If the threshold type isn't number of spins...
            line([pre_samples,pre_samples + hit_samples],...
                curthresh*[1,1],...
                'color','k',...
                'linestyle',':',...
                'parent',h.primary_ax);                                     %Plot a dotted line to show the threshold.
             text(pre_samples,curthresh,'Hit Threshold',...
                'horizontalalignment','left',...
                'verticalalignment','top',...
                'fontsize',8,...
                'fontweight','bold',...
                'visible','off',...
                'parent',h.primary_ax);                                     %Create text to label the the threshold line.
            if ~isnan(h.ceiling)  && h.ceiling ~= Inf                       %If this stage has a ceiling...
                line([pre_samples,pre_samples + hit_samples],...
                    h.ceiling*[1,1],...
                    'color','k',...
                    'linestyle',':',...
                    'parent',h.primary_ax);                                 %Plot a dotted line to show the ceiling.
                text(pre_samples,h.ceiling,'Ceiling',...
                    'horizontalalignment','left',...
                    'verticalalignment','top',...
                    'fontsize',8,...
                    'fontweight','bold',...
                    'visible','off',...
                    'parent',h.primary_ax);                                 %Create text to label the the threshold line.
            end
        end       
        set(h.primary_ax,'xtick',[],'ytick',[]);                            %Get rid of the x- y-axis ticks.
        if ~isnan(h.ceiling) && h.ceiling ~= Inf                            %If a ceiling is set for this stage...
            max_y = [min([1.1*min(trial_signal), -0.1*h.ceiling]),...
                1.3*max([trial_signal; h.ceiling])];                        %Calculate y-axis limits based on the ceiling.
        else                                                                %Otherwise, if there is no ceiling...
            max_y = [min([1.1*min(trial_signal), -0.1*curthresh]),...
                1.3*max([trial_signal; curthresh])];                        %Calculate y-axis limits based on the hit threshold.
        end        
        ylim(h.primary_ax,max_y);                                           %Set the new y-axis limits.
        xlim(h.primary_ax,[1,buffsize]);                                    %Set the x-axis limits according to the buffersize.
        ln = line(pre_samples*[1,1],max_y,...
            'color','k',...
            'parent',h.primary_ax);                                         %Plot a line to show the start of the hit window.
        ln(2) = line((pre_samples+hit_samples)*[1,1],max_y,...
            'color','k',...
            'parent',h.primary_ax);                                         %Plot a line to show the end of the hit window.
%         ir_text = text(0.02*buffsize,max_y(2)-0.03*range(max_y),'IR',...
%             'horizontalalignment','left',...
%             'verticalalignment','top',...
%             'margin',2,...
%             'edgecolor','k',...
%             'backgroundcolor','w',...
%             'fontsize',10,...
%             'fontweight','bold',...
%             'parent',h.primary_ax);                                         %Create text to show the state of the IR signal.
        clock_text = text(0.97*buffsize,max_y(2)-0.03*range(max_y),...
            ['Session Time: ' datestr(now-start_time,13)],...
            'horizontalalignment','right',...
            'verticalalignment','top',...
            'margin',2,...
            'edgecolor','k',...
            'backgroundcolor','w',...
            'fontsize',10,...
            'fontweight','bold',...
            'parent',h.primary_ax);                                         %Create text to show a session timer.
        peak_text = [];                                                     %Create a matrix to hold handles to peak labels.
        hit_time = 0;                                                       %Start off assuming an outcome of a miss.
        vns_time = 0;                                                       %Start off assuming VNS will not be delivered.
        
        if strcmpi(h.device,'both')                                         %If the user selected combined touch-pull...
            cla(h.secondary_ax);                                            %Clear the touch axes.
            p(3) = area(1:buffsize,touch_signal,...
                'linewidth',2,...
                'facecolor',[0.5 1 0.5],...
                'parent',h.secondary_ax);                                   %Make an areaseries plot to show the trial signal.
            set(h.secondary_ax,'xtick',[],'ytick',[]);                      %Get rid of the x- y-axis ticks.
            ylim(h.secondary_ax,[0 1100]);                                  %Set the new y-axis limits.
            xlim(h.secondary_ax,[1,buffsize]);                              %Set the x-axis limits according to the buffersize.
        end   
        
    end
    
    first_sound = 0;
    second_sound = 0;
    
    while run == 2 && cur_sample < trial_buffsize                           %Loop until the end of the trial or the user stops the session/pauses/manual feeds.
        temp = h.ardy.read_stream();                                        %Read in any new stream output.
        a = size(temp,1);                                                   %Find the number of new samples.
        if a > 0                                                            %If there was any new data in the stream.
            temp(:,2) = cal(1)*(temp(:,2) - cal(2));                        %Apply the calibration constants to the data signal.
            
            data(1:end-a,:) = data(a+1:end,:);                              %Shift the existing buffer samples to make room for the new samples.
            data(end-a+1:end,:) = temp;                                     %Add the new samples to the buffer.
            if cur_sample + a > buffsize                                    %If more samples were read than we'll record for the trial...
                b = buffsize - cur_sample;                                  %Pare down the read samples to only those needed.
            else                                                            %Otherwise...
                b = a;                                                      %Grab all of the samples returned.
            end
            
            trial_data(cur_sample+(1:b),:) = temp(1:b,:);                   %Add the new samples to the trial data.
            
            switch h.curthreshtype                                          %Switch between the types of hit threshold.
                
                case 'bidirectional'                                        %If the current threshold type is the bidirectional number of degrees...
                    trial_signal(cur_sample+(1:b)) = ...
                        abs(trial_data(cur_sample+(1:b),2) - ...
                        base_value);                                        %Save the new section of the knob position signal, subtracting the trial base value.
                case {'grams (peak)','grams (sustained)',...
                        'degrees (total)', 'presses','fullpresses'}         %If the current threshold type is the total number of degrees or peak force...
                    if strcmpi(h.stage(h.cur_stage).number,'PASCI1')        %If the current stage is PASCI1...
                        trial_signal(cur_sample+(1:b)) = ...
                            abs(trial_data(cur_sample+(1:b),2) - ...
                            base_value);                                    %Save the new section of the wheel position signal, subtracting the trial base value. 
                    else                                                    %Otherwise, for the other threshold types...
                        trial_signal(cur_sample+(1:b)) = ...
                            trial_data(cur_sample+(1:b),2) - base_value;    %Save the new section of the wheel position signal, subtracting the trial base value. 
                    end
                    cur_val = trial_signal(cur_sample + b);                 %Grab the current value.
                case {'degrees/s','# of spins'}                             %If the current threshold type is the number of spins or spin velocity.
                    temp = diff(data(:,2));                                 %Find the wheel velocity at each point in the buffer.
                    temp = boxsmooth(temp,minpkdist);                       %Boxsmooth the wheel velocity with a 100 ms smooth.
                    trial_signal(cur_sample+(-offset:b)) = ...
                            temp(buffsize-a-1-offset:buffsize-a+b-1);       %Find the wheel velocity thus far in the trial.
                        
                case 'milliseconds (hold)'                                  %If the current threshold type is a hold...
                    trial_signal(cur_sample + (1:b)) = ...
                        10*(trial_data(cur_sample +(1:b),3) > 511.5);       %Digitize and save the new section of signal.
                    for i = cur_sample + (1:b)                              %Step through each new signa.
                        if trial_signal(i) > 0                              %If the touch sensor is held for this sample...
                            trial_signal(i) = ...
                                trial_signal(i) + trial_signal(i-1);        %Add the sample time to all of the preceding non-zero sample times.
                        end
                    end
                    
                case 'milliseconds/grams'                                   %If the current threshold type is a hold...
                    trial_signal(cur_sample+(1:b)) = ...
                            trial_data(cur_sample+(1:b),2) - base_value;    %Save the new section of the wheel position signal, subtracting the trial base value.
    %                 touch_signal(cur_sample+(1:b)) = ...
    %                     1023 - trial_data(cur_sample+(1:b),3);              %Save the new section of the wheel position signal, subtracting the trial base value.
                    touch_signal(cur_sample+(1:b)) = ...
                        trial_data(cur_sample+(1:b),3);                     %Save the new section of the wheel position signal, subtracting the trial base value.
                    temp = cur_sample + b;                                  %Grab the current sample.
                    if hit_time == 0 && ...
                            any(touch_signal(cur_sample+(1:b)) > 511.5)     %If the rat went back to the touch sensor...
                        trial_buffsize = cur_sample + b;                    %Set the new buffer timeout.
                        hit_time = -1;                                      %Set the hit time to -1 to indicate an abort.
                    elseif h.vns == 1 && ...
                            any(trial_signal >= 5) && ...
                            all(trial_signal(temp-stim_time_out:temp) < 5)  %If stimulation is on and the rat hasn't pull the handle in half a second...
                        h.ardy.stim_off();                                  %Immediately turn off stimulation.
                        vns_time = now;                                     %Save the current time as the hit time.                    
                    end
                    set(p(3),'ydata',touch_signal);                         %Update the area plot.
            end            
            
            if strcmpi(h.curthreshtype, 'degrees (total)') && ...      
                    any(cur_sample == hitwin) && ...
                    hit_time == 0 && ...
                    any(h.cur_stage == h.sound_stages)                      %If this is a knob and we are currently in the hit window...
                if max(temp(:,2)) >= curthresh/3 && first_sound == 0        %If we have gone above 1/3 of our threshold, and have not played a sound
                    h.ardy.sound_1000(1);                                   %Play the 1KHz sound.
                    first_sound = 1;                                        %Set our first sound variable to 1 to indicate we have already played sound
                end

                if max(temp(:,2)) >= curthresh/2 && second_sound == 0   	%If we have gone above 2/3 of our threshold, and have not played this sound
                    h.ardy.sound_1100(1);                                   %Play the 1.1KHz sound.
                    second_sound = 1;                                       %Set our second sound varaible to 1 to indiacte we have played this sound
                end

                if any(temp(:,2) < 5)                                       %If we have any elements less than 5 (This constitutes as a "reset")
                    first_sound = 0;                                        %Set our sounds back to 0
                    second_sound = 0;                                       %Set our sounds back to 0
                end
            end
            
            set(p(1),'ydata',trial_signal);                                 %Update the area plot.

            switch h.curthreshtype                                          %Switch between the types of hit threshold.
                
                case {'presses', 'fullpresses'}                             %For lever press count thresholds...
                
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
                
                case 'grams (sustained)'                                    %If the current threshold type is "sustained pull"...
                
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
            
                otherwise
            
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
            catch err                                                       %If an error occurred...
                if errstack(2) == 0                                         %If this error hasn't yet been reported...
                    MotoTrak_Send_Error_Report(h,h.err_rcpt,err);           %Send an error report to the specified recipient.
                end
                errstack(2) = 1;                                            %Set the error reported value to 1 to prevent redundant reports.
            end
            
            try
                b = find(temp >= pre_samples & pks >= 1 &...
                    temp < pre_samples + hit_samples & ...
                    temp <= cur_sample + a - offset );                      %Find all of the of peaks in the hit window.
                br = find(release_points >= pre_samples & rpks >= 1 & ...
                    release_points < pre_samples + hit_samples & ...
                    release_points <= cur_sample + a - offset );

%                 rpks = rpks(br);
                release_points = release_points(br);
            catch err                                                       %If an error occurred...
                if errstack(3) == 0                                         %If this error hasn't yet been reported...
                    MotoTrak_Send_Error_Report(h,h.err_rcpt,err);           %Send an error report to the specified recipient.
                end
                errstack(3) = 1;                                            %Set the error reported value to 1 to prevent redundant reports.
            end
            pks = pks(b);                                                   %Kick out all of the peaks outside of the hit window.
            temp = temp(b);                                                 %Kick out all of the peak times outside of the hit window.

            if hit_time == 0                                                %If the rat hasn't gotten a hit yet.
                
                switch h.curthreshtype                                      %Switch between the types of hit threshold.
                    
                    case '# of spins'                                       %If the threshold type is the number of spins...
                        if length(pks) >= curthresh                         %If the number of spins has met or exceeded the required number of spins.
                            hit_time = now;                                 %Save the current time as the hit time.
                            h.ardy.trigger_feeder(1);                       %Trigger feeding on the Arduino.
                            feedings = feedings + 1;                        %Add one to the feedings counter.
                            if h.vns == 1                                   %If VNS is enabled...
                                h.ardy.stim();                              %Trigger VNS through the Arduino.
                                vns_time = now;                             %Save the current time as the hit time.
                            elseif h.vns == 3                               %If we are in burst stim mode...                                
                                elapsed_time = etime(datevec(now),...
                                    datevec(burst_stim_time));              %Check to see if 5 minutes has elapsed since the start of the session.
                                if (elapsed_time >= 300)                    %If 5 min has elapsed, then we can pair this hit with a stim.
                                    if (burst_stim_num < 3)                                        
                                        burst_stim_time = now;              %Record the first stim time as now
                                        burst_stim_num = ...
                                            burst_stim_num + 1;             %Increment the burst stimulation counter.                                        
                                        h.ardy.stim();                      %Trigger the stimulator.
                                        vns_time = burst_stim_time;         %Save the vns stim time so that it can be written out to the data file
                                    end                            
                                end                        
                            end
                            
                            ln(3) = line(temp(curthresh)*[1,1],max_y,...
                            'color',[0.5 0 0],...
                            'linewidth',2,...
                            'parent',h.primary_ax);                         %Plot a line to show where the hit occurred at the current sample.
                        end
                        
                    case {  'grams (peak)',...
                            'degrees (total)',...
                            'degrees/s','bidirectional',...
                            'milliseconds (hold)',...
                            'milliseconds/grams'    }                       %For threshold types in which the signal must just exceed a value...
                        if  max(trial_signal(hitwin)) > curthresh           %If the trial threshold was exceeded within the hit window...
                            if ~isnan(h.ceiling) && h.ceiling ~= Inf        %If a ceiling is set for this stage...
                                if any(cur_sample == hitwin)                %If the current sample is within the hit window...
                                    if cur_val >= curthresh && ...
                                        cur_val <= h.ceiling && ...
                                        ceiling_check == 0                  %If the current value is greater than the threshold but less than the ceiling...
                                        ceiling_check = 1;                  %Set the ceiling check variable to 1.
                                        set(p(1),'facecolor',[0.5 1 0.5]);  %Set the area plot facecolor to green.
                                    elseif cur_val > h.ceiling              %If the current value is greater than the ceiling...
                                        ceiling_check = -1;                 %Set the ceiling check variable to -1.
                                        set(p(1),'facecolor',[1 0.5 0.5]);  %Set the area plot facecolor to red.
                                    elseif ceiling_check == 1 && ...
                                            cur_val < curthresh             %If the current value is less than the threshold which was previously exceeded...
                                        hit_time = now;                     %Save the current time as the hit time.
                                        h.ardy.trigger_feeder(1);           %Trigger feeding on the Arduino.
                                        feedings = feedings + 1;            %Add one to the feedings counter.
                                        h.ardy.play_hitsound(1);            %Play the hit sound.
                                        if h.vns == 1                       %If VNS is enabled...
                                            h.ardy.stim();                  %Trigger VNS through the Arduino.
                                            vns_time = now;                 %Save the current time as the hit time.
                                        end
                                    elseif ceiling_check == -1 && ...
                                            cur_val <= h.init               %If the rat previously exceeded the ceiling but the current value is below the initiation threshold...
                                        ceiling_check = 0;                  %Set the ceiling check variable back to 0.
                                        set(p(1),'facecolor',[0.5 0.5 1]);  %Set the area plot facecolor to blue.
                                    end
                                end
                            else                                            %Otherwise, if there is no ceiling for this stage...       
                                hit_time = now;                             %Save the current time as the hit time.
                                h.ardy.trigger_feeder(1);                   %Trigger feeding on the Arduino.
                                feedings = feedings + 1;                    %Add one to the feedings counter.
                                if isfield(h,'variant')                     %If there's a custom variant in the handles structure...
                                    switch h.variant                        %Switch between the recognized custom variants.

                                        case 'hollis'                       %If this is a custom stage for the Hollis labvariant...

                                        case 'machado lab'                  %If this is the custom stage for Machado lab...
                                            trial_buffsize = ...
                                                cur_sample + a + ...
                                                post_samples;               %Set the new buffer timeout.
                                    end
                                end
                    
                                %If this is not the regular pull task, play a sound when the animal gets a hit
                                %Currently we don't want to play a sound for the
                                %regular pull task, except for shaping stage
                                %(h.cur_stage == 1)
                                if ~strcmpi(h.device,'both')  
                                    h.ardy.play_hitsound(1);                    %Play the hit sound.
                                end

                                if (~strcmpi(h.curthreshtype,{'grams (peak)'}) ... 
                                        || h.cur_stage == 1)
                                    h.ardy.play_hitsound(1);                    %Play the hit sound.
                                end

                                if h.vns == 1                                   %If VNS is enabled...
                                    if ~strcmpi(h.curthreshtype,'milliseconds/grams')   %If this isn't the touch/pull variant for the Machado lab...
            %                             h.ardy.stim_off();              %Immediately turn off stimulation.
            %                             vns_time = now;                       %Save the current time as the hit time.
            %                         else                                      %Otherwise...
                                        h.ardy.stim();                          %Trigger VNS through the Arduino.
                                        vns_time = now;                         %Save the current time as the hit time.
                                    end
                                elseif h.vns == 3                               %If we are in burst stim mode...                                
                                    elapsed_time = etime(datevec(now),...
                                        datevec(burst_stim_time));              %Check to see if 5 minutes has elapsed since the start of the session.
                                    if (elapsed_time >= 300)                    %If 5 min has elapsed, then we can pair this hit with a stim.
                                        if (burst_stim_num < 3)                                        
                                            burst_stim_time = now;              %Record the first stim time as now
                                            burst_stim_num = ...
                                                burst_stim_num + 1;             %Increment the burst stimulation counter.                                        
                                            h.ardy.stim();                      %Trigger the stimulator.
                                            vns_time = burst_stim_time;         %Save the vns stim time so that it can be written out to the data file
                                        end                            
                                    end                       
                                end

                                ln(3) = line(cur_sample*[1,1],max_y,...
                                    'color',[0.5 0 0],...,
                                    'linewidth',2,...
                                    'parent',h.primary_ax);                     %Plot a line to show where the hit occurred at the current sample.
                            end
                        end
                            
                    case 'presses'                                          %If the current threshold type is the number of presses...                    
                        if (length(pks) >= curthresh)                       %Are there enough of these peaks? If so, it is a hit.
                            hit_time = now;                                 %Save the current time as the hit time.
                            h.ardy.trigger_feeder(1);                       %Trigger feeding on the Arduino.
                            feedings = feedings + 1;                        %Add one to the feedings counter.
                            h.ardy.play_hitsound(1);                        %Play hit sound.
                            ln(3) = line(cur_sample*[1,1],max_y,...
                                'color',[0.5 0 0],...
                                'linewidth',2,...
                                'parent',h.primary_ax);                     %Plot a line to show where the hit occurred at the current sample.

                        end
                        
                    case 'fullpresses'                                      %If the current threshold type is full presses...                    
                        if length(pks) >= curthresh && ...
                                length(release_points) >= curthresh         %If the lever has been pressed AND released the required number of times...
                            hit_time = now;                                 %Save the current time as the hit time.
                            h.ardy.trigger_feeder(1);                       %Trigger feeding on the Arduino.
                            feedings = feedings + 1;                        %Add one to the feedings counter.
                            h.ardy.play_hitsound(1);                        %Play hit sound.
                            ln(3) = line(cur_sample*[1,1],max_y,...
                                'color',[0.5 0 0],...
                                'linewidth',2,...
                                'parent',h.primary_ax);                     %Plot a line to show where the hit occurred at the current sample.
                        end
                    
                    case 'grams (sustained)'                                %If the current threshold is a sustained force...
                    
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

                            hit_time = now;                                 %Save the current time as the hit time.
                            h.ardy.trigger_feeder(1);                       %Trigger feeding on the Arduino.
                            feedings = feedings + 1;                        %Add one to the feedings counter.
                            h.ardy.play_hitsound(1);                        %Play hit sound 
                            ln(3) = line(cur_sample*[1,1],max_y,...
                                'color',[0.5 0 0],...
                                'linewidth',2,...
                                'parent',h.primary_ax);                     %Plot a line to show where the hit occurred at the current sample.

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
                            'parent',h.primary_ax);                         %Create text to mark each peak in the hit window.
                    else                                                    %Otherwise, if this isn't a new peak...
                        set(peak_text(i),'position',[temp(i)-1,pks(i)]);    %Update the position of the peak label.
                    end
                end
            
            end
            
            if ~isnan(h.ceiling) && h.ceiling ~= Inf                        %If a ceiling is set for this stage...
                max_y = [min([1.1*min(trial_signal), -0.1*h.ceiling]),...
                    max([1.3*max(trial_signal), 1.3*h.ceiling])];           %Calculate new y-axis limits.
            else                                                            %Otherwise, if there is no ceiling set for this stage...
                max_y = [min([1.1*min(trial_signal), -0.1*curthresh]),...
                    max([1.3*max(trial_signal), 1.3*curthresh])];           %Calculate new y-axis limits.
            end
            ylim(h.primary_ax,max_y);                                       %Set the new y-axis limits.
            set(ln,'ydata',max_y);                                          %Update the lines marking the hit window bounds.
%             ir_pos = [0.02*buffsize, max_y(2)-0.03*range(max_y)];           %Update the x-y position of the IR text object.
            minmax_ir(1) = min([minmax_ir(1); data(:,3)]);                  %Calculate a new minimum IR value.
            minmax_ir(2) = max([minmax_ir(2); data(:,3)]);                  %Calculate a new maximum IR value.
            if minmax_ir(2) - minmax_ir(1) >= 25                            %If the IR value range is less than 25...
                minmax_ir(3) = h.ir_initiation_threshold*(minmax_ir(2) -...
                    minmax_ir(1)) + minmax_ir(1);                           %Set the IR threshold to the specified relative threshold.
            elseif minmax_ir(1) == minmax_ir(2)                             %If there is no range in the IR values.
                minmax_ir(1) = minmax_ir(1) - 1;                            %Set the IR minimum to one less than the current value.
            end
%             c = (data(end,3) - minmax_ir(1))/(minmax_ir(2) - minmax_ir(1)); %Calculate the color of the IR indicator.
%             set(ir_text,'backgroundcolor',[1 c c],...
%                 'position',ir_pos);                                         %Color the IR indicator text according to the signal..
            cur_sample = cur_sample + a;                                    %Add the number of new samples to the current sample counter.
        end
        set(clock_text,...
            'position',[0.97*buffsize, max_y(2)-0.03*range(max_y)],...
            'string',['Session Time: ' datestr(now-start_time,13)]);        %Update the session timer text object.
        if now > endtime                                                    %If the suggested session time has passed...
            set(clock_text,'backgroundcolor','r');                          %Color the session timer text object red.
            endtime = Inf;                                                  %Set the new suggested end time to infinite.
        end
        if h.vns == 2                                                       %If random VNS is enabled...
            a = find(rand_vns_times > 0,1,'first');                         %Find the next random VNS time.
            if ~isempty(a) && now > rand_vns_times(a)                       %If the clock has reached the next random stimulation time.
                h.ardy.stim();                                              %Trigger VNS through the Arduino.
                vns_time(end+1) = now;                                      %Save the current time as a VNS time.
                rand_vns_times(a) = 0;                                      %Mark this stimulation time as completed.
            end
        end
        pause(0.01);                                                        %Pause for 10 milliseconds to keep from overwhelming the processor.
        drawnow;                                                            %Update the figure and flush the event queue.
    end
    
    if h.vns == 1 && (~isempty(vns_time) && vns_time == 0) && ...
            strcmpi(h.curthreshtype,'milliseconds/grams')                   %If stimulation is turned on and this is a combined touch/pull stage...
        h.ardy.stim_off();                                                  %Immediately turn off stimulation.
        vns_time = now;                                                     %Save the current time as the hit time.
    end
                    
    if run == 2                                                             %If the session is still running...
        
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
        switch h.curthreshtype                                              %Switch between the types of hit threshold.
            
            case {'presses', 'fullpresses'}                                 %If the threshold type was the number of presses...           
                Add_Msg(h.msgbox,...
                    sprintf('%s - Trial %1.0f - %s: %1.0f presses.',...
                    datestr(now,13), trial, temp, length(pks)));            %Then show the user the number of presses that occurred within the hit window.                
                y_data = length(pks);                                       %Save the number of peaks as the y-axis data for the trials plot.
                
            case 'grams (peak)'                                             %If the threshold type was the peak force...                
                Add_Msg(h.msgbox,...
                    sprintf('%s - Trial %1.0f - %s: %1.0f grams.',...
                    datestr(now,13), trial, temp, max(pks)));               %Then show the user the peak force used by the rat within the trial.                
                y_data = round(max(pks));                                   %Save the number of peaks as the y-axis data for the trials plot.
                
            otherwise                                                       %For all other threshold types.
                Add_Msg(h.msgbox,sprintf('%s - Trial %1.0f - %s',...
                    datestr(now,13),trial, temp));                          %Show the user the trial results.
        end
        trial_data(:,1) = trial_data(:,1) - trial_start(2);                 %Subtract the start time from the sample times.
        
        fwrite(fid,trial,'uint32');                                         %Write the trial number.
        fwrite(fid,trial_start(1),'float64');                               %Write the start time of the trial.
        fwrite(fid,temp(1),'uint8');                                        %Write the first letter of 'HIT' or 'MISS' as the outcome.
        fwrite(fid,h.hitwin,'float32');                                     %Write the hit window for this trial.
        fwrite(fid,h.init,'float32');                                       %Write the trial initiation threshold for reward for this trial.
        fwrite(fid,curthresh,'float32');                                    %Write the hit threshold for reward for this trial.
        if ~isnan(h.ceiling) && h.ceiling ~= Inf                            %If there's a force ceiling.
            fwrite(fid,h.ceiling,'float32');                                %Write the force ceiling for this trial.
        end
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
        hold(h.hitrate_ax, 'on');                                           %Hold the trials axis.
        
        try                                                                 %Attempt to update the trial axes.
            plot(h.hitrate_ax, trial, y_data, '*', 'Color', trial_color);   %Plot the new trial on the trials axis
        catch err                                                           %If an error occurred...
            if errstack(4) == 0                                             %If this error hasn't yet been reported...
                MotoTrak_Send_Error_Report(h,h.err_rcpt,err);               %Send an error report to the specified recipient.
            end
            errstack(4) = 1;                                                %Set the error reported value to 1 to prevent redundant reports.
        end
        
        if strcmpi(h.threshadapt,'median')                                  %If this stage has a median-adapting threshold...
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
            
        elseif strcmpi(h.threshadapt,'linear') && hit_time(1) ~= 0          %If this stage has a linear-adapting threshold and the last trial was scored as a hit.
        	curthresh = curthresh + h.threshincr;                           %Increment the hit threshold by the specified increment.
        elseif strcmpi(h.threshadapt, 'static')
            maxthresh = curthresh;
        end
        curthresh = min([curthresh, h.threshmax]);                          %Don't allow the hit threshold to exceed the specified maximum.
        curthresh = max([curthresh, h.threshmin]);                          %Don't allow the hit threshold to go below the specified minim.
        set(h.editthresh,'string',num2str(curthresh));                      %Show the current threshold in the hit threshold editbox.

    elseif h.vns == 2 && fix(run) ~= 2 && ~isempty(vns_time)                %If the user's stopped the session and random stimulation is enabled and there's VNS times to write...
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
    elseif run == 2.2                                                       %Otherwise if the user manually fed the rat...
        h.ardy.trigger_feeder(1);                                           %Trigger feeding on the Arduino.
        trial = trial - 1;                                                  %Subtract one from the trial counter.
        fwrite(fid,0,'uint32');                                             %Write a trial of zero.
        fwrite(fid,now,'float64');                                          %Write the current time.
        fwrite(fid,'F','uint8');                                            %Write an 'F' (70) to indicate a manual feeding.
        Add_Msg(h.msgbox,[datestr(now,13) ' - Manual Feeding.']);           %Show the user that the session has ended.
        run = 2;                                                            %Reset the run variable to 2.
    end
end

fclose(fid);                                                                %Close the session data file.

try                                                                         %Attempt to clear the serial line.
    h.ardy.stream_enable(0);                                                %Disable streaming on the Arduino.
    h.ardy.clear();                                                         %Clear any residual values from the serial line.
catch err                                                                   %If an error occurred...
    MotoTrak_Send_Error_Report(h,h.err_rcpt,err);                           %Send an error report to the specified recipient.
end

% Max_Degrees_Turned = nanmax(Total_Degrees_Turned);
Mean_Degrees_Turned = nanmean(Total_Degrees_Turned);


Add_Msg(h.msgbox,[datestr(now,13) ' - Session ended.']);                    %Show the user that the session has ended.

finalSessionOutput = sprintf(['Pellets fed: %1.0f, '...
    'Max Threshold: %1.2f, '...
    'Thresholding Type: %s, '...
    'Mean Degrees Turned: %1.1f'],...
    feedings, maxthresh, h.threshadapt, Mean_Degrees_Turned);               %Create a final session output message.
Add_Msg(h.msgbox, finalSessionOutput);                                      %Show the final session values to the user.

MotoTrak_Enable_Controls_Outside_Session(h);                      

if isfield(h,'variant') && strcmpi(h.variant,'isaac cassar')                %If this is Isaac Cassar's variant...
    str = get(h.msgbox,'string');                                           %Grab the current string from the message box.
    str{end+1} = sprintf('run = %1.0f',run);                                %Add the current state of the run variable to the string.
    MotoTrak_Send_Error_Report(h,h.err_rcpt,str);                           %Send the string as error report to the specified recipient.
end

set(h.startbutton,'enable','off');                                    %Disable the start/stop button until a new stage is selected.
set(h.pausebutton,'enable','off');                                    %Disable the pause button.   