function [device, index] = MotoTrak_Identify_Device(val)

%
%MotoTrak_Identify_Device.m - Vulintus, Inc.
%
%   This function identifies the behavioral module attached to the MotoTrak
%   system based on the analog identifier returned from the module.
%   
%   UPDATE LOG:
%   12/31/2018 - Drew Sloan - Added the water reaching module.
%   04/26/2022 - Drew Sloan - Lowered the pull module lower bound from 500
%       to 495 to prevent misidentification of pull modules.
%

if val < 20                                                                 %If the device-identifier value is less than ~0.1V...
    device = 'none';                                                        %There is no device connected.
    index = 0;                                                              %Set the index to 0.
elseif val >= 20 && val < 100                                               %If the device-identifier value is between ~0.1V and ~0.5V...
    device = 'lever';                                                       %The device is the lever (1.5 MOhm resistor).
    index = 1;                                                              %Set the index to 1.
elseif val >= 100 && val < 200                                              %If the device-identifier value is between ~0.5V and ~1.0V...
    device = 'knob';                                                        %The device is the knob (560 kOhm resistor).
    index = 2;                                                              %Set the index to 2.
elseif val >= 200 && val < 300                                              %If the device-identifier value is between ~1.0V and ~1.5V...
    device = 'knob';                                                        %The device is the knob (270 kOhm resistor).
    index = 2;                                                              %Set the index to 2.
elseif val >= 300 && val < 400                                              %If the device-identifier value is between ~1.5V and ~2.0V...
    device = 'knob';                                                        %The device is the knob (200 kOhm resistor).
    index = 2;                                                              %Set the index to 2.
elseif val >= 400 && val < 495                                              %If the device-identifier value is between ~2.0V and ~2.5V...
    device = 'lever';                                                       %The device is the pull (130 kOhm resistor).
    index = 5;                                                              %Set the index to 1.
elseif val >= 495 && val < 600                                              %If the device-identifier value is between ~2.5V and ~3.0V...
    device = 'pull';                                                        %The device is the pull (85 kOhm resistor).
    index = 6;                                                              %Set the index to 6.
elseif val >= 600 && val < 700                                              %If the device-identifier value is between ~3.0V and ~3.5V...
    device = 'pull';                                                        %The device is the pull (57 kOhm resistor).
    index = 6;                                                              %Set the index to 6.
elseif val >= 700 && val < 800                                              %If the device-identifier value is between ~3.5V and ~4.0V...
    device = 'water';                                                       %The device is the pull (36 kOhm resistor).
    index = 8;                                                              %Set the index to 6.
elseif val >= 800 && val < 900                                              %If the device-identifier value is between ~4.0V and ~4.5V...
    device = 'lever';                                                       %The device is the lever (20 kOhm resistor).
    index = 1;                                                              %Set the index to 1.
elseif val >= 900 && val < 1000                                             %If the device-identifier value is between ~4.5V and ~5.0V...
    device = 'vibration';                                                   %The device is the vibration handle (10 kOhm resistor).
    index = 10;                                                             %Set the index to 0.
elseif val >= 1000                                                          %If the device-identifier value is greather than ~5.0V...
    device = 'knob';                                                        %The device is the knob (wire jumper).
    index = 2;                                                              %Set the index to 2.
end