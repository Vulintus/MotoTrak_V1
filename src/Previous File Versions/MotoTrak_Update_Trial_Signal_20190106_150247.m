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
session.buffer(end-N+1:end,:) = new_data;                                   %Add the new samples to the buffer.

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