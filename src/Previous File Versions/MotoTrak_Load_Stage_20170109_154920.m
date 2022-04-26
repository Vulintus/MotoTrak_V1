function h = MotoTrak_Load_Stage(h)

%
%MotoTrak_Load_Stage.m - Vulintus, Inc.
%
%   MotoTrak_Load_Stage loads in the parameters for a single MotoTrak
%   training/testing stage, displays the stage information on the GUI, and
%   adjusts the plotting to reflect the updated threshold values.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Added session duration as a stage parameter.
%   01/09/2017 - Drew Sloan - Forced the current threshold type string to
%       be lower-case for better compatibility with switch-case statements.
%

Add_Msg(h.msgbox,[datestr(now,13) ' - Current stage is '...
    h.stage(h.cur_stage).description '.']);                                 %Show the user what new stage was selected is.
d = h.stage(h.cur_stage).device;                                            %Grab the required device for the current stage.
Add_Msg(h.msgbox,[datestr(now,13) ...
    ' - Current device is the ' d '.']);                                    %Show the user what the new current device is.

h.threshmax = h.stage(h.cur_stage).threshmax;                               %Set the maximum hit threshold.
h.curthreshtype = lower(h.stage(h.cur_stage).threshtype);                   %Set the current threshold type.
set(h.popunits,'string',h.threshtype);                                      %Set the string and value of the threshold type pop-up menu.    
if strcmpi(h.stage(h.cur_stage).threshadapt, 'dynamic')                     %This code sets the minimum threshold if the dynamic threshold type is chosen   
    if ~isempty(h.ratname)                                                  %If a rat name was entered
        h.threshmin = Adaptive_Calc(h.ratname,h.vns, ... 
            h.stage(h.cur_stage).number, h.datapath, h.threshmax);
        h.threshadapt = 'median'; 
%         if h.threshmin >= h.threshmax
%            h.threshadapt = 'static';                                  %Set threshadapt to static if we have reached max threshold
%         else
%             h.threshadapt = 'median';                                 %Set threshadapt to median if we have not reached max threshold
%         end
    else    
        h.threshmin = 1;                                                    %If no rat was selected yet set threshmin equal to 1 to indicate no rat
        h.threshadapt = 'median';
    end

    switch h.threshmin;
        case 0
            errordlg('No previous sessions detected.  Defaulting to minimum threshold of 15 degrees.');
        case 1
            errordlg('No rat name entered. Defaulting to minimum threshold of 15 degrees.');
        otherwise
            if isnan(h.threshmin)
                errordlg('No sessions detected greater than 50 trials.  Defaulting to minimum threshold of 15 degrees.');
            end
    end
    %If our threshold is below our minimum
    if h.threshmin < h.stage(h.cur_stage).threshmin || isnan(h.threshmin)
        h.threshmin = h.stage(h.cur_stage).threshmin;                       %Default the previous cases to 15 degrees
    end
else                                                                        %Else if dynamic thresh type is not selected in the spreadsheet
    h.threshmin = h.stage(h.cur_stage).threshmin;                           %Set the minimum hit threshold to this number if we aren't on a dynamic threshold type
    h.threshadapt = h.stage(h.cur_stage).threshadapt;
end
set(h.editthresh,'string',num2str(h.threshmin));                            %Show the minimum hit threshold in the hit threshold editbox.
h.threshincr = h.stage(h.cur_stage).threshincr;                             %Set the adaptive hit threshold increment.    

h.threshmax = h.stage(h.cur_stage).threshmax;                               %Set the pull maximum hit threshold.     
h.threshmin = h.stage(h.cur_stage).threshmin;                               %Set the pull minimum hit threshold to this number if we aren't on a dynamic threshold type
h.threshadapt = h.stage(h.cur_stage).threshadapt;                           %Set the pull threshold adaptation type.
h.threshincr = h.stage(h.cur_stage).threshincr;                             %Set the pull adaptive hit threshold increment.
h.ceiling = h.stage(h.cur_stage).ceiling;                                   %Set the pull force ceiling.
    
h.curthreshtype = h.stage(h.cur_stage).threshtype;                          %Set the pull current threshold type.
set(h.popunits,'string',h.threshtype);                                      %Set the string and value of the threshold type pop-up menu.
h.init = h.stage(h.cur_stage).init;                                         %Set the trial initiation threshold.
set(h.editinit,'string',num2str(h.init));                                   %Show the trial initiation threshold in the initiation threshold editbox.    
set(h.lblinit,'string',h.curthreshtype);                                    %Set the initiation threshold units label to the current threshold type.

% handles.stage(handles.cur_stage).threshmin
h.period = h.stage(h.cur_stage).period;                                     %Set the streaming sampling period.
h.position = h.stage(h.cur_stage).pos;                                      %Set the device position.
if (h.delay_autopositioning == 0)                                           %If there's no autopositioning delay currently in force.
    temp = round(10*(h.positioner_offset - 10*h.position));                 %Calculate the absolute position to send to the autopositioner.
    h.ardy.autopositioner(temp);                                            %Set the specified position value.
    h.delay_autopositioning = (10 + temp)/86400000;                         %Don't allow another autopositioning trigger until the current one is complete.
end
set(h.editpos,'string',num2str(h.position));                                %Show the device position in the device position editbox.
h.cur_const = h.stage(h.cur_stage).const;                                   %Set the current constraint.
set(h.popconst,'string',h.constraint);                                      %Set the string and value of the constraint type pop-up menu.
h.hitwin = h.stage(h.cur_stage).hitwin;                                     %Set the hit window.
set(h.edithitwin,'string',num2str(h.hitwin));                               %Show the hit window in the hit window editbox.

h.session_dur = h.stage(h.cur_stage).session_dur;                           %Set the session duration.

if isfield(h,'ir_trial_initiation') && strcmpi(h.ir_trial_initiation,'on')  %If IR signal trial initiation is enabled...
    h.ir = h.stage(h.cur_stage).ir;                                         %Set the IR swipe-initiation variable.
else                                                                        %Otherwise...
    h.ir = 0;                                                               %Set the IR swipe-initiation variable to zero.
end

if ~isfield(h,'ir_initiation_threshold')                                    %If no IR signal initiation threshold is set...
    h.ir_initiation_threshold = 0.5;                                        %Set the IR swipe-initiation variable.
end

temp = {h.stage.description};                                               %Make a cell array holding the stage descriptions.
set(h.popstage,'string',temp,'value',h.cur_stage);                          %Populate the stage selection listbox and set its value.

if strcmpi(h.stage(h.cur_stage).vns,'ON')                                   %If VNS is enabled by default for this stage...
    h.vns = 1;                                                              %Set the VNS field to 1.
    set(h.popvns,'value',1);                                                %Show that VNS is enabled in the VNS pop-up menu.
    set(h.popvns,'foregroundcolor',[1 0 0]);                                %Make the VNS pop-up menu "ON" text red.
elseif strcmpi(h.stage(h.cur_stage).vns,'RANDOM')                           %Otherwise, if VNS is randomly-presented by default for this stage...
    h.vns = 2;                                                              %Set the VNS field to 0.
    set(h.popvns,'value',3);                                                %Show that VNS is randomly-presented in the VNS pop-up menu.
    set(h.popvns,'foregroundcolor',[0 0 1]);                                %Make the VNS pop-up menu "RANDOM" text blue.
elseif strcmpi(h.stage(h.cur_stage).vns,'BURST')                            %Otherwise, if VNS is burst mode
    h.vns = 3;                                                              %Set the VNS field to 3
    set(h.popvns,'value',4);                                                %Show that the VNS is in burst mode in the VNS pop-up menu.
    set(h.popvns,'foregroundcolor',[0 1 0]);                                %Make the VNS pop-up menu "BURST" text green.
else                                                                        %Otherwise, if VNS is disabled by default for this stage...
    h.vns = 0;                                                              %Set the VNS field to 0.
    set(h.popvns,'value',2);                                                %Show that VNS is enabled in the VNS pop-up menu.
    set(h.popvns,'foregroundcolor','k');                                    %Make the VNS pop-up menu "OFF" text black.
end