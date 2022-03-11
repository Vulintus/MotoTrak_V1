function session = MotoTrak_Set_Stimulation_Parameters(handles,session)
%
%MotoTrak_Set_Stimulation_Parameters.m - Vulintus, Inc.
%
%   MOTOTRAK_SET_STIMULATION_PARAMETERS sets the stimulation timing based
%   on the stimulation parameters set in the stage file.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       stimulation parameter settings from MotoTrak_Behavior_Loop.m.
%


switch handles.stim                                                         %Switch between the recognized stimulation modes...
    case 2                                                                  %If random stimulation is enabled...
        if strcmpi(handles.stage(handles.cur_stage).number,'P11')           %If the current stage is P11...
            num_stim = 180;                                                 %Set the desired total number of stimulation events.
            isi = 5;                                                        %Set the fixed ISI between all events, stimulation or catch trials.
            catch_trial_prob = 0.5;                                         %Set the catch trial probability.
            N = ceil(num_stim/(1-catch_trial_prob));                        %Calculate the required total number of events to meet the catch trial probability.
            temp = randperm(N);                                             %Create random permutation of the events.
            temp = sort(temp(1:num_stim));                                  %Grab the indices for only the stimulation events.
            session.rand_stim_times = isi*temp/86400;                       %Set times for the random stimulation events, in units of serial date number.
            session.rand_stim_times = session.rand_stim_times + now;        %Adjust the times relative to the session start.
        elseif strcmpi(handles.stage(handles.cur_stage).number,'P15')       %If the current stage is P15...
            num_stim = 900;                                                 %Set the desired total number of stimulation events.
            session.rand_stim_times = ones(1,num_stim);                     %Create a matrix of 1-second inter-stimulation intervals.
            session.rand_stim_times(1:round(num_stim/2)) = 3;               %Set half of the inter-stimulation intervals to 3 seconds.
            session.rand_stim_times = ...
                session.rand_stim_times(randperm(num_stim));                %Randomize the inter-stimulation intervals.
            for i = num_stim:-1:2                                           %Step backward through the inter-stimulation intervals.
                session.rand_stim_times(i) = ...
                    sum(session.rand_stim_times(1:i));                      %Set each stimulation time as the sum of all precedingin inter-stimulation intervals.
            end
            session.rand_stim_times = now + session.rand_stim_times/86400;  %Convert the intervals to stimulation times, in units of serial date number.
        end
    case 3                                                              	%If burst stimulation is enabled.
        handles.ardy.set_stim_dur(29550);                                   %Set the stimulus duration to trigger free running stimulation for 30 seconds.
        %Note:  We set this to a conservative 29550 instead of 30000 so that we
        %       don't accidentally trigger an extra pulse train at the end of
        %       30 seconds of stimulation.
end