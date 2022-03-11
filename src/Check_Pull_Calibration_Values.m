function Check_Pull_Calibration_Values

supply_voltage = 5;                                                         %Set the expected supply voltage, in volts.

mototrak = Connect_MotoTrak;                                                %Use the MotoTrak connection function to create a serial connected to MotoTrak.

baseline = mototrak.baseline();                                             %Read in the baseline (resting) value for the isometric pull handle loadcell.                
slope = mototrak.cal_grams();                                               %Read in the loadcell range, in grams.
temp = mototrak.n_per_cal_grams();                                          %Read in the loadcell range, in analog tick values.
slope = slope/temp;                                                         %Calculate the grams/tick conversion for the isometric pull handle loadcell.

clc;                                                                        %Clear the command window.
fprintf(1,'Calibration values for the controller on port %s:\n',...
    mototrak.port);                                                         %Print the port name.
fprintf(1,'\t[force] = m*([voltage] - b)\n');                               %Print the calibration equation.
fprintf(1,'\tm = %1.3f gm/V\n',supply_voltage*slope/1023);                  %Print the calibration slope.
fprintf(1,'\tb = %1.3f V\n',supply_voltage*baseline/1023);                  %Print the calibration baseline.

fclose(mototrak.serialcon);                                                 %Delete the serial connection to the Arduino.



        