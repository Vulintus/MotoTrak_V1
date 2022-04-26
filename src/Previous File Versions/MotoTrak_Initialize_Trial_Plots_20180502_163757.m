function trial = MotoTrak_Initialize_Trial_Plots(handles,session,trial)

%
%MotoTrak_Initialize_Trial_Plots.m - Vulintus, Inc.
%
%   MOTOTRAK_INITIALIZE_TRIAL_PLOTS resets the plots on the MotoTrak GUI to
%   switch from showing the pre-initialization signal to showing the saved
%   trial signals.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       trial plot sections from MotoTrak_Behavior_Loop.m.
%

cla(handles.primary_ax);                                                    %Clear the primary axes.

trial.plot_h(1) = area(1:session.buffsize,trial.signal,...
    'linewidth',2,...
    'facecolor',[0.5 0.5 1],...
    'parent',handles.primary_ax);                                           %Make an areaseries plot to show the trial signal.

hold(handles.primary_ax,'on');                                              %Hold the primary axes for multiple plots.
if any(strcmpi(handles.curthreshtype,{'# of spins','presses'}))             %If the threshold type is the number of spins or number of pressess...
    trial.plot_h(2) = plot(-1,-1,'*r','parent',handles.primary_ax);         %Mark the peaks with red asterixes.
end
hold(handles.primary_ax,'off');                                             %Release the plot hold.

if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                        %If a ceiling is set for this stage...
    trial.max_y = [min([1.1*min(trial.signal), -0.1*handles.ceiling]),...
        1.3*max([trial.signal; handles.ceiling])];                          %Calculate y-axis limits based on the ceiling.
else                                                                        %Otherwise, if there is no ceiling...
    trial.max_y = [min([1.1*min(trial.signal), -0.1*trial.thresh]),...
        1.3*max([trial.signal; trial.thresh])];                             %Calculate y-axis limits based on the hit threshold.
end        

str = sprintf('Trial %1.0f', trial.num);                                %   Create the string for a text object.
trial.trial_txt = text(1,trial.max_y(2),str,...
    'fontsize',12,...
    'fontweight','bold',...
    'horizontalalignment','left',...
    'verticalalignment','top',...
    'parent',handles.primary_ax);                                           %Create a text object to show the trial number.
    
if ~strcmpi(handles.curthreshtype,'# of spins')                             %If the threshold type isn't number of spins...
    x = [session.pre_samples,session.pre_samples + session.hit_samples];    %Set the x coordinates for a line to show the threshold.
    y = trial.thresh*[1,1];                                                 %Set the y coordinates for a line to show the threshold.
    line(x,y,...
        'color','k',...
        'linestyle',':',...
        'parent',handles.primary_ax);                                       %Plot a dotted line to show the threshold.
     text(x(1),y(1),'Hit Threshold',...
        'horizontalalignment','left',...
        'verticalalignment','top',...
        'fontsize',8,...
        'fontweight','bold',...
        'visible','off',...
        'parent',handles.primary_ax);                                       %Create text to label the the threshold line.
    
    if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                    %If this stage has a ceiling...
        x = [session.pre_samples, ...
            session.pre_samples + session.hit_samples];                     %Set the x coordinates for a line to show the ceiling.
        y = handles.ceiling*[1,1];                                          %Set the y coordinates for a line to show the ceiling.
        line(x,y,...
            'color','k',...
            'linestyle',':',...
            'parent',handles.primary_ax);                                   %Plot a dotted line to show the ceiling.
        text(x(1),y(1),'Ceiling',...
            'horizontalalignment','left',...
            'verticalalignment','top',...
            'fontsize',8,...
            'fontweight','bold',...
            'visible','off',...
            'parent',handles.primary_ax);                                   %Create text to label the the threshold line.
    end
end       

set(handles.primary_ax,'xtick',[],'ytick',[]);                              %Get rid of the x- y-axis ticks.

ylim(handles.primary_ax,trial.max_y);                                       %Set the new y-axis limits.
xlim(handles.primary_ax,[1,session.buffsize]);                              %Set the x-axis limits according to the buffersize.

x = session.pre_samples*[1,1];                                              %Set x coordinates for a line.
trial.ln = line(x,trial.max_y,...
    'color','k',...
    'parent',handles.primary_ax);                                           %Plot a line to show the start of the hit window.
x = (session.pre_samples+session.hit_samples)*[1,1];                        %Set x coordinates for a line.
trial.ln(2) = line(x,trial.max_y,...
    'color','k',...
    'parent',handles.primary_ax);                                           %Plot a line to show the end of the hit window.

% x = 0.02*session.buffsize;                                                  %Set the x position of the IR signal text.
% y = trial.max_y(2)-0.03*range(trial.max_y);                                 %Set the y position of the IR signal text.
% trial.ir_text = text(x,y,'IR',...
%     'horizontalalignment','left',...
%     'verticalalignment','top',...
%     'margin',2,...
%     'edgecolor','k',...
%     'backgroundcolor','w',...
%     'fontsize',10,...
%     'fontweight','bold',...
%     'parent',handles.primary_ax);                                           %Create text to show the state of the IR signal.

x = 0.97*session.buffsize;                                                  %Set the x position of the session clock text object.
y = trial.max_y(2)-0.03*range(trial.max_y);                                 %Set the y position of the session clock text object.
str = sprintf('Session Time: %s', datestr(now - session.start,13));         %Create the text string.
trial.clock_text = text(x,y,str,...
    'horizontalalignment','right',...
    'verticalalignment','top',...
    'margin',2,...
    'edgecolor','k',...
    'backgroundcolor','w',...
    'fontsize',10,...
    'fontweight','bold',...
    'parent',handles.primary_ax);                                           %Create text to show a session timer.

trial.peak_text = [];                                                       %Create a matrix to hold handles to peak labels.
trial.hit_time = 0;                                                         %Start off assuming an outcome of a miss.
trial.stim_time = 0;                                                        %Start off assuming stimulation will not be delivered.   