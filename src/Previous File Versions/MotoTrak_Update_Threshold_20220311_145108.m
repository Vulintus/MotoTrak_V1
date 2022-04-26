function [trial, session] = MotoTrak_Update_Threshold(handles,session,trial)

%
%MotoTrak_Update_Threshold.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_THRESHOLD calculates the hit threshold for the next
%   trial when dynamic thresholds are enabled.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       threshold calculation section from MotoTrak_Behavior_Loop.m.
%

switch lower(handles.threshadapt)                                           %Switch between the recognized threshold adaptation methods.
    
    case 'median'                                                           %If this stage has a median-adapting threshold...
        session.thresh_buffer(1:end-1) = session.thresh_buffer(2:end);      %Shift the previous maximum hit window values one spot, overwriting the oldest.
        switch lower(handles.curthreshtype)                                 %Switch between the recognized threshold types...

            case {  'grams (peak)',...
                    'degrees (total)',...
                    'degrees/s',...
                    'bidirectional',...
                    'milliseconds/grams'}                                   %If the threshold was an analog value...
                session.thresh_buffer(end) = ...
                    max(trial.signal(session.hitwin));                      %Add the last trial's maximum value to the maximum value tracking matrix.

            otherwise                                                       %For all other threshold types...
                session.thresh_buffer(end) = length(trial.peak_vals);       %Add the last trial's number of presses to the maximum value tracking matrix.

        end

        if ~any(isnan(session.thresh_buffer))                               %If there's no NaN values in the maximum value tracking matrix...
            trial.thresh = median(session.thresh_buffer);                   %Set the current threshold to the median of the preceding trials.
            if trial.thresh > session.max_thresh                            %If the threshold is greater than the historical maximum...
                session.max_thresh = trial.thresh;                          %Save the threshold as the new historical maximum.
            end
            if strcmpi(handles.curthreshtype, 'degrees (total)')            %If the current threshold type is the total number of degrees...
                if trial.thresh < (0.7*session.max_thresh)                  %If the threshold is less than 70% of the historical maximum...
                    trial.thresh = 0.7*session.max_thresh;                  %Set the threshold to 70% of the historical maximum.
                end
            end
        end

    case 'linear'                                                           %If this stage has a linear-adpating threshold...
        if trial.hit_time(1) ~= 0                                           %If the last trial was scored as a hit...
            trial.thresh = trial.thresh + handles.threshincr;               %Increment the hit threshold by the specified increment.
        end

    case 'static'                                                           %If this stage has a static threshold...
    session.max_thresh = trial.thresh;                                      %Save the threshold as the maximum threshold.
    
end
trial.thresh = min([trial.thresh, handles.threshmax]);                      %Don't allow the hit threshold to exceed the specified maximum.
trial.thresh = max([trial.thresh, handles.threshmin]);                      %Don't allow the hit threshold to go below the specified minimum.
set(handles.editthresh,'string',num2str(trial.thresh,'%1.1f'));             %Show the current threshold in the hit threshold editbox with one decimal.