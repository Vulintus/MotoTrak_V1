function MotoTrak_Display_Trial_Results(handles,session,trial)

%
%MotoTrak_Display_Trial_Results.m - Vulintus, Inc.
%
%   MOTOTRAK_DISPLAY_TRIAL_RESULTS plots trial data to the MotoTrak GUI's
%   hit rate and session performance axes, and shows trial results as text
%   in the messagebox.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial results plotting section from MotoTrak_Behavior_Loop.m.
%

%Display the trial results in the messagebox.
switch handles.curthreshtype                                                %Switch between the types of hit threshold.
    case {'presses', 'fullpresses'}                                         %If the threshold type was the number of presses...       
        str = sprintf('%s - Trial %1.0f - %s: %1.0f presses.',...
            datestr(now,13), trial.num, trial.score,...
            numel(trial.peak_vals));                                        %Show the user the number of presses that occurred within the hit window.       

    case 'grams (peak)'                                                     %If the threshold type was the peak force...  
        if isempty(trial.peak_vals)                                         %If there's no peak values.
            trial.peak_vals = 0;                                            %Set the peak value to zero.
        end
        str = sprintf('%s - Trial %1.0f - %s: %1.0f grams.',...
            datestr(now,13), trial.num, trial.score,...
            max(trial.peak_vals));                                          %Then show the user the peak force used by the rat within the trial.      

    otherwise                                                               %For all other threshold types...
        str = sprintf('%s - Trial %1.0f - %s', datestr(now,13),...
            trial.num, trial.score);                                        %Show the user the trial results.
end
Add_Msg(handles.msgbox,str);                                                %Display the message on the GUI messagebox.

%Plot the current hitrate on the hit rate axes.
cla(handles.hitrate_ax);                                                    %Clear the hit rate axes.    
if size(session.hit_log,1) == 1                                             %If there's only one trial.
    x = session.hit_log(1,1) + [-1,1]/1440;                                 %Create x coordinates for an areaseries plot.
    y = session.hit_log(1,2)*[1,1];                                         %Create y coordinates for an areaseries plot.
else                                                                        %Otherwise, if there's more than one trial.
    x = session.hit_log(:,1);                                               %Use the timestamps as x coordinates.
    y = session.hit_log(:,2);                                               %Grab all of hit/miss values for y coordinates.
    for i = numel(y):-1:2                                                   %Step backwards through all of the trials.
        y(i) = mean(y(1:i));                                                %Set each point equal to the session hit rate at each trial.
    end
end
c = [0.5*(1 - y(end)) + 0.5, 0.5*y(end) + 0.5, 0.5];                        %Set the areaseries color.
area(x,y,'facecolor',c,...
    'facealpha',0.8,...
    'parent',handles.hitrate_ax);                                           %Plot the hitrate as an areaseries.
ylim(handles.hitrate_ax,[-0.1,1.1]);                                        %Set the y-axis limits.
x = [x(1), x(end)] + [-0.1,0.05]*(x(end) - x(1));                           %Calculate x-axis limits.
if x(2) - x(1) < 2/1440                                                     %If the span of the data is less than two minutes...
    temp = 2/1440 - (x(2) - x(1));                                          %Calculate the difference between the time shown and 2 minutes.
    x = x + [-1,1]*temp/2;                                                  %Add that amount of time equally to each end of the timespan.
end
xlim(handles.hitrate_ax,x);                                                 %Set the x-axis limits.
set(handles.hitrate_ax,'ytick',0:0.2:1,'xtick',[]);                         %Set the x- and y-ticks.    
if x(2) - x(1) < 5/1440                                                     %If the session duration is currently less than 5 minutes...
    step_size = 1440/1;                                                     %Use 1 minute steps.        
elseif x(2) - x(1) < 10/1440                                                %If the session duration is currently less than 10 minutes...
    step_size = 1440/2;                                                     %Use 2 minute steps.   
elseif x(2) - x(1) < 30/1440                                                %If the session duration is currently less than 30 minutes...
    step_size = 1440/5;                                                     %Use 5 minute steps.   
elseif x(2) - x(1) < 60/1440                                                %If the session duration is currently less than 60 minutes...
    step_size = 1440/10;                                                    %Use 10 minute steps.   
else                                                                        %Otherwise...
    step_size = 1440/60;                                                    %Use 60 minute steps.   
end
t = fix((step_size*x(1)):1:(step_size*x(2)))/step_size;                     %Calculate time step ticks.
t(t < x(1) + 0.1*(x(2) - x(1)) | t > x(1) + 0.95*(x(2) - x(1))) = [];       %Kick out tick marks at the edges.
for i = 1:length(t)                                                         %Step through each tick mark.
    txt = text(t(i),0.5,datestr(t(i),'HH:MM'),...
        'horizontalalignment','center',...
        'verticalalignment','middle',...
        'fontsize',12,...
        'backgroundcolor','w',...
        'rotation',90,...
        'parent',handles.hitrate_ax);                                       %Label each tick line.
    uistack(txt,'bottom');                                                  %Send the line to the bottom of the stack.
    ln = line([1,1]*t(i),[-0.1,1.1],...
        'color','k',...
        'linestyle','--',...
        'linewidth',0.5,...
        'parent',handles.hitrate_ax);                                       %Plot a tick line.
    uistack(ln,'bottom');                                                   %Send the line to the bottom of the stack.
end
for i = 0:0.2:1                                                             %Step through the y-ticks.
    ln = line(x,i*[1,1],...
        'color','k',...
        'linestyle','--',...
        'linewidth',0.5,...
        'parent',handles.hitrate_ax);                                       %Plot a tick line.
    uistack(ln,'bottom');                                                   %Send the line to the bottom of the stack.
    text(x(1) + 0.01*(x(2) - x(1)),i,sprintf('%1.0f%%',100*i),...
        'horizontalalignment','left',...
        'verticalalignment','middle',...
        'fontsize',8,...
        'backgroundcolor','w',...
        'parent',handles.hitrate_ax);                                       %Label each tick line.
end