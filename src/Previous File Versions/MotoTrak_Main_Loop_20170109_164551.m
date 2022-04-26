function MotoTrak_Main_Loop(fig)

%
%MotoTrak_Main_Loop.m - Vulintus, Inc.
%
%   MotoTrak_Main_Loop switches between the various loops of the MotoTrak
%   program based on the value of the run variable. This loop is necessary
%   because the global run variable can only be used to modify a running
%   loop if the function calling it has fully executed.
%
%   Run States:
%       - run = 0 >> Close program.
%       - run = 1 >> Idle mode.
%           - run = 1.1 >> Change idle mode parameters (stage select).
%           - run = 1.2 >> Create the new plot varibles.
%           - run = 1.3 >> Manual feed.
%           - run = 1.4 >> Reset Baseline.
%       - run = 2 >> Behavior session.
%           - run = 2.1 >> Pause session.
%           - run = 2.2 >> Manual feed.
%       - run = 3 >> Full device calibration.
%           - run = 3.1000 to 3.1999 >> Measure specified weight.
%           - run = 3.2 >> Update the handles structure.
%           - run = 3.3 >> Update the calibration plots.
%           - run = 3.4 >> Revert to the previous calibration.
%           - run = 3.5 >> Save the calibration.
%   
%   UPDATE LOG:
%   01/09/2017 - Drew Sloan - Moved the baseline reset function into the
%       idle mode function.
%

global run                                                                  %Create the global run variable.

while run ~= 0                                                              %Loop until the user closes the program.
    switch run                                                              %Switch between the various run states.
        
        case 1                                                              %Run state 1 = Idle Mode.
            MotoTrak_Idle(fig);                                             %Call the MotoTrak idle loop.  
            
        case 2                                                              %Run state 2 = Behavior Session.
            MotoTrak_Behavior_Loop(fig);                                    %Call the MotoTrak behavioral session loop.
            
        case 3                                                              %Run state 3 = Calibration.
            h = guidata(fig);                                               %Grab the handles structue from the figure.          
            delete(fig);                                                    %Delete the main figure.
            MotoTrak_Launch_Calibration(h.device, h.ardy);                  %Call the function to open the appropriate calibration window.            
            h = MotoTrak_Startup(h);                                        %Restart MotoTrak, passing the original handles structure.
            fig = h.mainfig;                                                %Reset the figure handle.
            
    end        
end

MotoTrak_Close(fig);                                                        %Call the function to close the MotoTrak program.