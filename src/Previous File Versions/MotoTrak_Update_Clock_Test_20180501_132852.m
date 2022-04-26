function MotoTrak_Update_Clock_Test(session,trial)

%
%MotoTrak_Update_Clock_Test.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_CLOCK_TEST updates the clock text object on the
%   MotoTrak GUI showing the current session time.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       clock update sections from MotoTrak_Behavior_Loop.m.
%

x = 0.97*session.buffsize;                                                  %Calculate the x position of the clock text.
y = trial.max_y(2)-0.03*range(trial.max_y);                                 %Calculate the y position of the clock text.
str = sprintf('Session Time: %s', datestr(now - session.start,13));         %Create the text string.
set(trial.clock_text,...
    'position',[x,y],...
    'string',str);                                                          %Update the session timer text object.
if now > session.end                                                        %If the suggested session time has passed...
    set(trial.clock_text,'backgroundcolor','r');                            %Color the session timer text object red.
end