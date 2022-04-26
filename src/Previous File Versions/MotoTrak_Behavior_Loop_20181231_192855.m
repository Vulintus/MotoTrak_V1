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

%Set a minimum  peak height depending on the connected device.
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