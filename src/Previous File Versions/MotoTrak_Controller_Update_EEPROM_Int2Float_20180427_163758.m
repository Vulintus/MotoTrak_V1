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

baseline = ardy.baseline();                                                 %Read in the baseline (unpressed) value for the lever.
total_range_in_degrees = ardy.cal_grams();                                  %Read in the range of the lever press, in degrees.
total_range_in_analog_values = ardy.n_per_cal_grams();                      %Read in the range of the lever press, in analog tick values.
slope = total_range_in_degrees / total_range_in_analog_values;              %Calculate the degrees/tick conversion for the lever.
[~, index] = MotoTrak_Identify_Device(ardy.device());                       %Call the function to identify the module based on the value of the analog device identifier.
ardy.set_baseline_float(index,baseline);                                    %Save the baseline as a float in the EEPROM address for the current module.
ardy.set_slope_float(index,slope);                                          %Save the slope as a float in the EEPROM address for the current module.
