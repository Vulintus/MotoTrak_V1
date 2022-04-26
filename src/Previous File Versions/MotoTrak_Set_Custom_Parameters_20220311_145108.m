function session = MotoTrak_Set_Custom_Parameters(handles, session)

%
%MotoTrak_Set_Custom_Parameters.m - Vulintus, Inc.
%
%   MOTOTRAK_SET_CUSTOM_PARAMETERS sets various session parameters that are
%   specific to individual labs.
%   
%   UPDATE LOG:
%   05/02/2015 - Drew Sloan - Function first implemented, cutting existing
%       sections from MotoTrak_Behavior_Loop.m.
%

if isfield(handles,'custom')                                                %If the handles structure has a custom field...
    switch lower(handles.custom)                                            %Switch between the various recognized variants.
        case {'machado lab', 'touch/pull'}                                  %Touch/Pull customization.        
            if handles.stim == 1 && ...
                    strcmpi(handles.curthreshtype,'milliseconds/grams')     %If stimulation is on and this is a touch/pull stage...
                temp = round(1000*handles.hitwin);                          %Find the length of the hit window in milliseconds.
                handles.ardy.set_stim_dur(temp);                            %Set the default stimulation duration to the entire hit window.
                session.stim_time_out = ...
                    round(1000*handles.stim_time_out/...
                    handles.stage(handles.cur_stage).period) - 1;           %Calculate the number of samples in the stimulation time-out duration.
            end
    end
end