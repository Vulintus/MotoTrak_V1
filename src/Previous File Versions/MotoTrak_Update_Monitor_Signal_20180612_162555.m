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
        if handles.cur_stage == 1                                           %If this is the first stage...
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
                session.buffer(:, 2) - session.min_peak_val;                %Subtract the minimum peak value from the entire signa.
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
            trial.mon_signal(1:(session.buffsize-a)) = 0;
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

    case 'milliseconds/grams'                                               %If the current threshold type is a combined hold/pull...
        for i = new_samples                                                 %Step through each new sample...
            if session.buffer(i,3) > 511.5                                  %If the sample is a logical highandles...
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