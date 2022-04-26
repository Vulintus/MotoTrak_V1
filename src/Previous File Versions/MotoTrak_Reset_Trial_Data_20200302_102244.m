function [handles, trial] = MotoTrak_Reset_Trial_Data(handles,session,trial)

%
%MotoTrak_Reset_Trial_Data.m - Vulintus, Inc.
%
%   MOTOTRAK_RESET_TRIAL_DATA resets all trial variables at the start of a
%   session or following a completed trial to prepare monitoring for the
%   next trial initiation.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial variable reset sections from MotoTrak_Behavior_Loop.m.
%

trial.num = trial.num + 1;                                                  %Increment the trial counter.

trial.mon_signal(:) = 0;                                                    %Reset out the monitor signal.
trial.signal(:) = 0;                                                        %Reset out the trial signal.
if strcmpi(handles.device,'both')                                           %If this is a combined touch-pull stage...
    trial.touch_signal(:) = 0;                                              %Reset the touch signal.
end
trial.data(:) = 0;                                                          %Zero out the trial data.

trial.base_value = 0;                                                       %Reset the base value.
trial.ir_initiate = 0;                                                      %Reset the IR initiation flag.
trial.buffsize = session.buffsize;                                          %Set the trial buffsize to be the entire buffer size.
trial.ceiling_check = 0;                                                    %Reset the threshold ceiling flag.
trial.time_held = 0;                                                        %Reset the time held tracker.
trial.hold_check = 0;                                                       %Reset the hold time flag.
trial.peak_vals = [];                                                       %Reset the peak values field.
trial.peak_indices = [];                                                    %Reset the peak indices field.

if session.hitwin_tone_index > 0                                            %If a hit window tone is enabled...
    trial.hitwin_tone_on = 1;                                               %Set the value of the hit window tone flag to 1 to indicate it hasn't yet played.
else                                                                        %Otherwise...
    trial.hitwin_tone_on = 0;                                               %Set the value of the hit window tone flag to 0.
end
if session.hit_tone_index > 0                                               %If a hit tone is enabled...
    trial.hit_tone_on = 1;                                                  %Set the value of the hit tone flag to 1 to indicate it hasn't yet played.
else                                                                        %Otherwise...
    trial.hit_tone_on = 0;                                                  %Set the value of the hit tone flag to 0.
end
if session.miss_tone_index > 0                                              %If a miss tone is enabled...
    trial.miss_tone_on = 1;                                                 %Set the value of the miss tone flag to 1 to indicate it hasn't yet played.
else                                                                        %Otherwise...
    trial.miss_tone_on = 0;                                                 %Set the value of the miss tone flag to 0.
end