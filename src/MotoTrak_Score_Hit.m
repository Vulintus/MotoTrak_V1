function [session, trial] = MotoTrak_Score_Hit(handles, session, trial)

%
%MotoTrak_Score_Hit.m - Vulintus, Inc.
%
%   MOTOTRAK_SCORE_HIT executes all operations associated with an animal
%   scoring a "Hit" during a behavioral session, including triggering
%   rewards, playing any enabled tones, and outputting any enabled 
%   stimulation triggers.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       hit operation sections from MotoTrak_Behavior_Loop.m.
%

trial.hit_time = now;                                                       %Save the current time as the hit time.
handles.ardy.trigger_feeder(1);                                             %Trigger feeding on the Arduino.
trial.feeds = trial.feeds + 1;                                              %Add one to the feedings counter.
% handles.ardy.play_hitsound(1);                                            %Play the hit sound.
if handles.stim == 1                                                        %If stimulation is enabled...
    handles.ardy.stim();                                                    %Trigger stimulation through the controller.
    trial.stim_time = now;                                                  %Save the current time as the hit time.
elseif handles.stim == 3                                                    %If we are in burst stim mode...                                
    elapsed_time = etime(datevec(now),...
        datevec(session.burst_time));                                       %Check to see if 5 minutes has elapsed since the start of the session.
    if (elapsed_time >= 300)                                                %If 5 min has elapsed, then we can pair this hit with a stim.
        if (session.burst_num < 3)                                        
            session.burst_time = now;                                       %Record the first stim time as now
            session.burst_num = ...
                session.burst_num + 1;                                      %Increment the burst stimulation counter.                                        
            handles.ardy.stim();                                            %Trigger the stimulator.
            trial.stim_time = session.burst_time;                           %Save the stimulation time so that it can be written out to the data file
        end                            
    end
else                                                                        %Otherwise...
    trial.stim_time = 0;                                                    %Set the stimulation time to zero.
end                          
if trial.hit_tone_on == 1                                                   %If a hit tone is enabled, but hasn't yet been played...
    handles.ardy.play_tone(session.hit_tone_index);                         %Start the tone.
    trial.hit_tone_on = 2;                                                  %Set the hit tone flag to 2 to indicate it is currently playing.
    trial.miss_tone_on = 0;                                                 %Set the miss tone flag to 0 to disable it.
elseif trial.hitwin_tone_on == 2                                            %Otherwise, if a hit window tone is enabled and currently playing...
    handles.ardy.stop_tone();                                               %Stop the hit window tone.
    trial.hitwin_tone_on = 0;                                               %Set the hit window tone flag to zero.
end
trial.ln(3) = line(trial.cur_sample*[1,1],trial.max_y,...
    'color',[0.5 0 0],...,
    'linewidth',2,...
    'parent',handles.primary_ax);                                           %Plot a line to show where the hit occurred at the current sample.