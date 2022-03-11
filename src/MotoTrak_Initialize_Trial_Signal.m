function trial = MotoTrak_Initialize_Trial_Signal(handles,session,trial)
        
%
%MotoTrak_Initialize_Trial_Signal.m - Vulintus, Inc.
%
%   MOTOTRAK_INITIALIZE_TRIAL_SIGNAL starts the trial signal that will be
%   saved following a recognized trial initiation event.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial signal initializtion sections from MotoTrak_Behavior_Loop.m.
%

        
if trial.ir_initiate == 0                                                   %If the trial wasn't initiated by the IR detector...
    init_sample = find(trial.mon_signal >= handles.init,1,'first') - 1;     %Find the timepoint where the trial initiation threshold was first crossed.
else                                                                        %Otherwise...
    init_sample = session.buffsize;                                         %Set initiation sample to the current sample.
end

trial.cur_sample = session.buffsize - init_sample + session.pre_samples;    %Find the number of samples to copy from the pre-trail monitoring.
init_sample = init_sample - session.pre_samples + 1;                        %Find the start of the pre-trial period.

trial.data(1:trial.cur_sample,:) = ...
    session.buffer(init_sample:session.buffsize,:);                         %Copy the pre-trial period to the trial data.

trial.start = [now, session.buffer(init_sample,1)];                         %Save the trial start times (computer and MotoTrak controller clocks).

switch handles.curthreshtype                                                %Switch between the types of hit threshold.

    case {'degrees (total)','bidirectional'}                                %If the current threshold type is the total number of degrees...
        if handles.cur_stage == 1
            trial.base_value = min(session.buffer(end-200,2));              %Set the base value to the degrees value right at the initiation threshold crossing.
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2) - ...
                trial.base_value;                                           %Copy the pre-trial wheel position minus the base value.
        else
            trial.base_value = 0;                                           %Set the base value to the degrees value right at the initiation threshold crossing.
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2);             %Copy the pre-trial wheel position minus the base value.    
        end

    case {'degrees/s','# of spins'}                                         %If the current threshold type is the number of spins or spin velocity.
        trial.base_value = 0;                                               %Set the base value to zero spin velocity.
        temp = diff(session.buffer(:,2));                                   %Find the wheel velocity at each point in the buffer.
        temp = boxsmooth(temp,session.min_peak_dist);                       %Boxsmooth the wheel velocity with a 100 ms smoothandles.
        trial.signal(1:trial.cur_sample) = ...
            temp(init_sample-1:session.buffsize-1);                         %Grab the pre-trial spin velocity.

    case {'grams (peak)', 'grams (sustained)'}                              %If the current threshold type is the peak pull force.
        trial.base_value = 0;                                               %Set the base value to zero force.
        if strcmpi(handles.stage(handles.cur_stage).number,'PASCI1')        %If the current stage is PASCI1...
            trial.signal(1:trial.cur_sample) = ...
                abs(session.buffer(init_sample:session.buffsize,2));        %Copy the pre-trial force values.
        else
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2);             %Copy the pre-trial force values.
        end

    case {'presses', 'fullpresses'}                                         %If the current threshold type is presses (for LeverHD)            
        if strcmpi(handles.device,'knob')
            trial.base_value = session.buffer(init_sample,2);               %Set the base value to the initial value.
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2) - ...
                trial.base_value;                                           %Copy the pre-trial wheel position minus the base value.
        else
            trial.base_value = 0;                                           %Set the base value to zero.
            trial.signal(1:trial.cur_sample) = ...
                session.buffer(init_sample:session.buffsize,2);             %Copy the pre-trial angle values.
        end

    case 'milliseconds (hold)'                                              %If the current threshold type is a hold...
        trial.base_value = trial.cur_sample;                                %Set the base value to the starting sample.
        trial.signal(trial.cur_sample) = handles.period;                    %Set the first sensor value to 10.

    case 'milliseconds/grams'                                               %If the current threshold type is a hold...
%         handles.ardy.play_hitsound(1);                                      %Play the hit sound.
        trial.base_value = 0;                                               %Set the base value to zero force.
        trial.signal(1:trial.cur_sample) = ...
            session.buffer(init_sample:session.buffsize,2);                 %Copy the pre-trial force values.
%         trial.touch_signal(1:trial.cur_sample) = ...
%             1023 - data(a:session.buffsize,3);                              %Copy the pre-trial touch values.
        trial.touch_signal(1:trial.cur_sample) = ...
            session.buffer(init_sample:session.buffsize,3);                 %Copy the pre-trial touch values.
        if handles.stim == 1                                                %If stimulation is on...
            handles.ardy.stim();                                            %Turn on stimulation.
        end
end