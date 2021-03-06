function [trial, session] = MotoTrak_Check_For_Hit(handles,session,trial)

%
%MotoTrak_Check_For_Hit.m - Vulintus, Inc.
%
%   MOTOTRAK_CHECK_FOR_HIT checks the current signal to see if the current
%   "hit" criteria have been satisfied.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       hit checking sections from MotoTrak_Behavior_Loop.m.
%

                
switch handles.curthreshtype                                                %Switch between the types of hit threshold.

    case {  'grams (peak)',...
            'degrees (total)',...
            'degrees/s','bidirectional',...
            'milliseconds (hold)',...
            'milliseconds/grams'    }                                       %For threshold types in which the signal must just exceed a value...
        if  max(trial.signal(session.hitwin)) > trial.thresh                %If the trial threshold was exceeded within the hit window...            
            if ~isnan(handles.ceiling) && handles.ceiling ~= Inf            %If a ceiling is set for this stage...
                for s = (trial.cur_sample - trial.N + 1):trial.cur_sample   %Step through each new sample.
                    if any(s == session.hitwin) && trial.hit_time == 0      %If the current sample is within the hit window...                    
                        if trial.signal(s) >= trial.thresh && ...                            
                                trial.signal(s) <= handles.ceiling && ...
                                trial.ceiling_check == 0                    %If the current value is greater than the threshold but less than the ceiling...
                            trial.ceiling_check = 1;                        %Set the ceiling check variable to 1.
                            set(trial.plot_h(1),'facecolor',[0.5 1 0.5]);   %Set the area plot facecolor to green.         
%                             fprintf(1,'[%1.0f] trial.ceiling_check = 1\n', s);
                        elseif trial.signal(s) > handles.ceiling            %If the current value is greater than the ceiling...
                            trial.ceiling_check = -1;                       %Set the ceiling check variable to -1.
                            set(trial.plot_h(1),'facecolor',[1 0.5 0.5]);   %Set the area plot facecolor to red.     
%                             fprintf(1,'[%1.0f] trial.ceiling_check = -1\n', s);
                        elseif trial.ceiling_check == 1 && ...
                                trial.signal(s) < trial.thresh              %If the current value is less than the threshold which was previously exceeded...
                            [session, trial] = ...
                                MotoTrak_Score_Hit(handles,...
                                session, trial);                            %Call the function to score a hit.    
%                             fprintf(1,'[%1.0f] HIT\n', s);
                        elseif trial.ceiling_check == -1 && ...
                                trial.signal(s) <= handles.init             %If the rat previously exceeded the ceiling but the current value is below the initiation threshold...
                            trial.ceiling_check = 0;                        %Set the ceiling check variable back to 0.
                            set(trial.plot_h(1),'facecolor',[0.5 0.5 1]);   %Set the area plot facecolor to blue.      
%                             fprintf(1,'[%1.0f] trial.ceiling_check = 0\n', s);
                        end
                    end      
                end          
            else                                                            %Otherwise, if there is no ceiling for this stage...       
                [session, trial] = MotoTrak_Score_Hit(handles, session,...
                    trial);                                                 %Call the function to score a hit.              
            end
        end

    case 'grams (sustained)'
        if  max(trial.signal(session.hitwin)) > trial.thresh                %If the trial threshold was exceeded within the hit window...            
            if ~isnan(handles.hold_dur) && handles.hold_dur > 1             %If there's a hold duration set for this stage.
                for s = (trial.cur_sample - trial.N + 1):trial.cur_sample   %Step through each new sample.
                    if any(s == session.hitwin) && trial.hit_time == 0      %If the current sample is within the hit window...       
                        if trial.signal(s) >= trial.thresh                  %If the current sample is above the threshold.
                            trial.time_held = ...
                                trial.time_held + handles.period;           %Increment the time held.
                            set(trial.plot_h(1),'facecolor',[0.5 1 0.5]);   %Set the area plot facecolor to green.
                            if trial.time_held >= handles.hold_dur          %If the force has been high for the required hold duration...
                                [session, trial] = ...
                                    MotoTrak_Score_Hit(handles,...
                                    session, trial);                        %Call the function to score a hit. 
                            end
                        else                                                %Otherwise...
                            trial.time_held = 0;                            %Reset the time held.
                            set(trial.plot_h(1),'facecolor',[0.5 0.5 1]);   %Set the area plot facecolor to blue.     
                        end
                    end      
                end      
            else                                                            %Otherwise, if there is no ceiling for this stage...       
                [session, trial] = MotoTrak_Score_Hit(handles, session,...
                    trial);                                                 %Call the function to score a hit.              
            end
        end
    case 'presses'                                                          %If the current threshold type is the number of presses...                    
        if (length(trial.peak_vals) >= trial.thresh)                        %Are there enough of these peaks? If so, it is a hit.
            [session, trial] = MotoTrak_Score_Hit(handles, session, trial); %Call the function to score a hit.  
        end

    case 'fullpresses'                                                      %If the current threshold type is full presses...                    
        if numel(trial.peak_vals) >= trial.thresh && ...
                length(trial.release_pts) >= trial.thresh                   %If the lever has been pressed AND released the required number of times...
            [session, trial] = MotoTrak_Score_Hit(handles, session, trial); %Call the function to score a hit.   
        end
end