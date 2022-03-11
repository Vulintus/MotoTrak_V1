function session = MotoTrak_Update_IR_Bounds(handles,session)

%
%MotoTrak_Update_IR_Bounds.m - Vulintus, Inc.
%
%   MOTOTRAK_UPDATE_IR_BOUNDS updates the minimum and maximum historical
%   infrared sensor values, and adjusts the infrared sensor threshold
%   accordingly.
%   
%   UPDATE LOG:
%   05/02/2015 - Drew Sloan - Function first implemented, cutting existing
%       IR update sections from MotoTrak_Behavior_Loop.m.
%   01/11/2019 - Drew Sloan - Added different IR range thresholds for when
%       it's okay to set the IR initiation threshold for the beam- and
%       bounce-type detectors.
%

switch lower(handles.ir_detector)                                           %Switch between the different types of IR detector.
    case 'beam'                                                             %For the beam-type detector...
        activation_threshold = 100;                                         %Set the activation threshold to 100.
    case 'bounce'                                                           %For the bounce-type detector...
        activation_threshold = 25;                                          %Set the activation threshold to 25.
end

session.minmax_ir(1) = min([session.minmax_ir(1); session.buffer(:,3)]);    %Calculate a new minimum IR value.
session.minmax_ir(2) = max([session.minmax_ir(2); session.buffer(:,3)]);    %Calculate a new maximum IR value.
if session.minmax_ir(2) - session.minmax_ir(1) >= activation_threshold      %If the IR value range is greater than the activation threshold.
    session.minmax_ir(3) = ...
        handles.ir_initiation_threshold*(session.minmax_ir(2) - ...
        session.minmax_ir(1)) + session.minmax_ir(1);                       %Set the IR threshold to the specified relative threshold.
elseif session.minmax_ir(1) == session.minmax_ir(2)                         %If there is no range in the IR values.
    session.minmax_ir(1) = session.minmax_ir(1) - 1;                        %Set the IR minimum to one less than the current value.
end