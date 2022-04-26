function handles = MotoTrak_Update_Controls_Within_Session(handles)

%
%MotoTrak_Update_Controls_Within_Session.m - Vulintus, Inc.
%
%   This function disables all of the uicontrol and uimenu objects that 
%   should not be active while MotoTrak is running a behavioral session.
%   
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Added disabling of uimenu objects.
%   10/13/2016 - Drew Sloan - Added disabling of the preferences menu.
%   05/01/2018 - Drew Sloan - Moved GUI settings from the start of 
%       MotoTrak_Behavior_Loop to this function and renamed the function 
%       from:
%           "MotoTrak_Disable_Controls_Within_Session"
%       to:
%           "MotoTrak_Update_Controls_Within_Session"
%

%Disable the uicontrol objects.
set(handles.editrat,'enable','off');                                        %Disable the rat name editbox.
set(handles.editbooth,'enable','off');                                      %Disable the booth number editbox.
set(handles.editport,'enable','off');                                       %Disable the port editbox.
set(handles.popdevice,'enable','off');                                      %Disable the device pop-up menu.
set(handles.popvns,'enable','off');                                         %Disable the VNS pop-up menu.
set(handles.popstage,'enable','off');                                       %Disable the stage pop-up menu.
set(handles.editpos,'enable','off');                                        %Disable the position editbox.
set(handles.popconst,'enable','off');                                       %Disable the constraint pop-up menu.
set(handles.edithitwin,'enable','off');                                     %Disable the hit window editbox.
set(handles.popunits,'enable','off');                                       %Disable the threshold units pop-up menu.
set(handles.editinit,'enable','off');                                       %Disable the time-out editbox.

%Enable the uimenu objects.
set(handles.menu.stages.h,'enable','off');                                  %Disable the stages menu.
set(handles.menu.pref.h,'enable','off');                                    %Disable the preferences menu.
set(handles.menu.cal.h,'enable','off');                                     %Disable the calibration menu.

%Change the Start/Stop button to stop mode.
set(handles.startbutton,'string','STOP',...
   'foregroundcolor',[0.5 0 0],...
   'callback','global run; run = 1;')                                       %Set the string and callback for the Start/Stop button.
set(handles.feedbutton,'callback','global run; run = 2.2;')                 %Set the callback for the Manual Feed button.

%Add a tab for a hit rate plot if it doesn't already exist.
if ~isfield(handles,'hitrate_tab')                                          %If there is no tab yet for session hit rate axes...
    handles.hitrate_tab = uitab('parent',handles.plot_tab_grp,...
        'title','Session Hit Rate',...
        'backgroundcolor',get(handles.mainfig,'color'));                    %Create a tab for the trial-by-trial hit rate.

end
if ~isfield(handles,'hitrate_ax')                                           %If there is no axes yet for session hit rate...
    handles.hitrate_ax = axes('parent',handles.hitrate_tab,...
        'units','normalized',...
        'position',[0 0 1 1],...
        'box','on',...
        'xtick',[],...
        'ytick',[]);                                                        %Create the trial hit rate axes.
end
cla(handles.hitrate_ax);                                                    %Clear the hit rate axes.

% %Add a tab for session performance plots if it doesn't already exist.
% if ~isfield(handles,'session_tab')                                          %If there is no tab yet for session performance measures...
%     handles.session_tab = uitab('parent',handles.plot_tab_grp,...
%         'title','Session Performance',...
%         'backgroundcolor',get(handles.mainfig,'color'));                    %Create a tab for the performance measure axes.
% end
% if ~isfield(handles,'session_ax')                                           %If there's no axes yet for session performance measures.
%     handles.session_ax = axes('parent',handles.session_tab,...
%         'units','normalized',...
%         'position',[0 0 1 1],...
%         'box','on',...
%         'xtick',[],...
%         'ytick',[]);                                                        %Create the performance measure axes.
% end
% cla(handles.session_ax);                                                    %Clear the hit rate axes.

% switch handles.curthreshtype                                                %Switch between the recognized threshold types.
%     case {'degrees (total)', 'bidirectional'}                               %If the threshold type is the total number of degrees...
%         set(handles.session_tab,'title','Trial Peak Angle');                %Set the performance axes to display trial spin velocity.
%     case 'degrees/s'                                                        %If the threshold type is the number of spins or spin velocity.
%         set(handles.session_tab,'title','Trial Spin Velocity');             %Set the performance axes to display trial spin velocity.
%     case '# of spins'                                                       %If the threshold type is the number of spins or spin velocity.
%         set(handles.session_tab,'title','Trial Number of Spins');           %Set the performance axes to display trial number of spins.
%     case {'grams (peak)', 'grams (sustained)','milliseconds/grams'}         %If the threshold type is a variant of peak pull force.
%         set(handles.session_tab,'title','Trial Peak Force');                %Set the performance axes to display trial peak force.
%     case {'presses', 'fullpresses'}                                         %If the threshold type is presses or full presses..
%         set(handles.session_tab,'title','Trial Press Counts');              %Set the performance axes to display trial press counts.
%     case 'milliseconds (hold)'                                              %If the threshold type is a hold...
%         set(handles.session_tab,'title','Trial Hold Time');                 %Set the performance axes to display trial hold times.
% end        

hold(handles.hitrate_ax, 'off');                                            %Release any plot hold on the trial hit rate axes.
cla(handles.hitrate_ax);                                                    %Clear any plots off the trial hit rate axes.
text(0,0,'Waiting for first trial...',...
    'fontsize',12,...
    'verticalalignment','middle',...
    'horizontalalignment','center',...
    'parent',handles.hitrate_ax);                                           %Plot text to show no trials have started yet.
set(handles.hitrate_ax,'xlim',[-1,1],...
    'ylim',[-1,1],...
    'xtick',[],...
    'ytick',[]);                                                            %Set the bounds and clear the tick marks from the hit rate axes.
% hold(handles.performance_ax, 'off');                                        %Release any plot hold on the trial performance measure axes.
% cla(handles.performance_ax);                                                %Clear any plots off the trial hperformance measure axes.

drawnow;                                                                    %Immediately update the figure.