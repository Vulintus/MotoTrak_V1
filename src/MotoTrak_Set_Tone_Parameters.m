function MotoTrak_Set_Tone_Parameters(h)

%
%MotoTrak_Set_Tone_Parameters.m - Vulintus, Inc.
%
%   This function updates any enabled tone parameters on the MotoTrak
%   controller whenever a stage is loaded or the user changed the
%   calibration functions.
%
%   UPDATE LOG:
%   04/30/2018 - Drew Sloan - First function implementation.
%

for i = 1:h.max_num_tones                                                   %Step through each existing tone...
    h.ardy.set_tone_index(i);                                               %Set the tone index.
    h.ardy.set_tone_trig_type(0);                                           %Set the tone initiation type to Matlab-triggered. 
end

if h.stage(h.cur_stage).tones_enabled ~= 1                                  %If no tones are enabled for this stage...
    return                                                                  %Skip execution of the rest of the function.
end

for i = 1:numel(h.stage(h.cur_stage).tones)                                 %Step through each specified tone.        
    h.ardy.set_tone_index(i);                                               %Set the tone index.
    h.ardy.set_tone_freq(h.stage(h.cur_stage).tones(i).freq);               %Set the tone frequency.
    if strcmpi(h.stage(h.cur_stage).tones(i).event,'hitwindow')             %If the tone event is the hit window...
        h.ardy.set_tone_dur(30000);                                         %Set the tone duration to 30 seconds.
    else                                                                    %Otherwise...
        h.ardy.set_tone_dur(h.stage(h.cur_stage).tones(i).dur);             %Set the specified tone duration.
    end
    if any(strcmpi(h.stage(h.cur_stage).tones(i).event,...
            {'rising','falling'}))                                          %Is the initiation event is any of the automatically triggered types...
        if isnumeric(h.stage(h.cur_stage).tones(i).thresh) && ...
                ~isnan(h.stage(h.cur_stage).tones(i).thresh)                %If the user inputted a numeric value for the threshold...
            thresh = h.stage(h.cur_stage).tones(i).thresh;                  %Grab the user-specified threshold.
            thresh = round((thresh/h.slope) + h.baseline);                  %Calculate the threshold as a controller analog-read value.
            h.ardy.set_tone_trig_thresh(thresh);                            %Set the tone initiation threshould on the controller.
            switch lower(h.device)                                          %Switch between the recognized device types.
                case {'pull','lever'}                                       %For the isometric pull or the analog lever..
                    h.ardy.set_tone_mon_input(1);                           %Set the monitored input to 1.
                    switch lower(h.stage(h.cur_stage).tones(i).event)       %Switch between the recognized tone initiation event types.
                        case 'rising'                                       %If the user specified a rising edge threshold...
                            h.ardy.set_tone_trig_type(1);                   %Set the tone initiation to rising-edge.                                  
                        case 'falling'                                      %If the user specified a falling edge threshold...
                            h.ardy.set_tone_trig_type(2);                   %Set the tone initiation to falling-edge.  
                    end        
                case 'knob'                                                 %For the supination knob...
                    h.ardy.set_tone_mon_input(6);                           %Set the monitored input to 6.
                    switch lower(h.stage(h.cur_stage).tones(i).event)       %Switch between the recognized tone initiation event types.
                        case 'rising'                                       %If the user specified a rising edge threshold...
                            h.ardy.set_tone_trig_type(2);                   %Set the tone initiation to falling-edge (calibration reverses signal).                                  
                        case 'falling'                                      %If the user specified a falling edge threshold...
                            h.ardy.set_tone_trig_type(1);                   %Set the tone initiation to rising-edge (calibration reverses signal).    
                    end        
            end                
        else                                                                %Otherwise...
            h.ardy.set_tone_trig_type(0);                                   %Set the tone initiation to Matlab-triggered.
        end
    else                                                                    %Otherwise, for all other initiation types...
        h.ardy.set_tone_trig_type(0);                                       %Set the tone initiation to Matlab-triggered.
    end
end