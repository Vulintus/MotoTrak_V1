function MotoTrak_Controller_Update_EEPROM_Int2Float(ardy)

%
%MotoTrak_Controller_Update_EEPROM_Int2Float.m - Vulintus, Inc.
%
%   This function converts calibration constants saved in the MotoTrak
%   controller's EEPROM from integers to floats when upgrading to V2.00+
%   controller microcode.
%
%   UPDATE LOG:
%   04/27/2018 - Drew Sloan - First function implementation.
%

for i = 1:10                                                                %Step through the available device indices.
    slope = ardy.get_slope_float(i);                                        %Fetch the slope for the device type.
    baseline = ardy.get_baseline_float(i);                                  %Fetch the baseline for the device type.
    
    if isnan(slope) || slope == 0                                           %If the slope value saved in EEPROM is NaN or zero...
        switch i                                                            %Switch between the recognized device types.
            
            case {1, 6}                                                     %If the device is the lever or the pull...
                slope = ardy.cal_grams()/ardy.n_per_cal_grams();            %Fetch the slope from the original EEPROM address.
                if slope == 0 || abs(slope) == Inf                          %If the slope is zero..
                    slope = 1;                                              %Set the slope equal to 1.
                end
                
            case 2                                                          %If the device is the supination knob...
                slope = -2.5;                                               %Set the slope to -2.5
                
            otherwise                                                       %For all other devices...
                slope = 1;                                                  %Set the slope to 1.
                
        end        
    end
    
    if isnan(baseline)                                                      %If the baseline value saved in EEPROM is NaN...
        switch i                                                            %Switch between the recognized device types.
            
            case {1, 6}                                                     %If the device is the lever or the pull...
                baseline = ardy.baseline();                                 %Fetch the baseline from the original EEPROM address.
                
            otherwise                                                       %For all other devices...
                baseline = 0;                                               %Set the baseline to zero.
                
        end        
    end
    
    if baseline > 1023                                                      %If the saved baseline is greater than 1023...
        baseline = 100;                                                     %Set the baseline to an arbitrary value of 100.
    end
    
    ardy.set_baseline_float(i,baseline);                                    %Save the baseline as a float in the EEPROM address for the current module.
    ardy.set_slope_float(i,slope);                                          %Save the slope as a float in the EEPROM address for the current module.
end