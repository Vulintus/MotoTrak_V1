function moto = MotoTrak_Controller_V2pX_Serial_Functions_Deprecated(moto)

%MotoTrak_Controller_V2pX_Serial_Functions_Deprecated.m - Vulintus, Inc., 2016
%
%   MotoTrak_Controller_V2pX_Serial_Functions_Deprecated is the deprecated
%   version of MotoTrak_Controller_V2pX_Serial_Functions, which defines and
%   adds the Arduino serial communication functions to the "moto" 
%   structure. These functions are for sketch versions 2.0+ and may not 
%   work with older versions. This deprecated version is being kept active
%   for the benefit of users running pre-2019b MATLAB.
%
%   UPDATE LOG:
%   05/12/2016 - Drew Sloan - Created the basic sketch status functions.
%   10/13/2016 - Drew Sloan - Added "v2p0_" prefix to all subfunction names
%       to prevent duplicate name errors in collated MotoTrak script.
%   04/19/2018 - Drew Sloan - Incorporated serial block codes matched to an
%       Arduino library to simplify serial code handling.
%   11/08/2019 - Drew Sloan - Added functions for sensory vibration task
%       control.
%   04/08/2021 - Drew Sloan - Reverted the sketch ID value from 123 back to
%       111 to fix compatibility errors between MotoTrak 1.1 and 2.0.
%   04/28/2021 - Drew Sloan - Added a close serial connection function to
%       let the user close the connection through a function on the control 
%       structure.
%   04/28/2021 - Drew Sloan - Deprecated function copied from
%       MotoTrak_Controller_V2pX_Serial_Functions.
%   07/23/2021 - Drew Sloan - Added a debugging mode with commands printed
%       to the command line.
%


serialcon = moto.serialcon;                                                 %Grab the handle for the serial connection.
serialcon.Timeout = 2;                                                      %Set the timeout for serial read/write operations, in seconds.
serialcon.UserData = [2, 1, 2, 0, 0, 0, 0, 0];                              %Set the default number of inputs and the default stream order.
serialcon.Userdata(end) = 1;                                                %Use the last element of the UserData as a debugging flag.

if ~isfield(moto,'version')                                                 %If no version is yet specified...
    pause(0.1);                                                             %Pause for 100 milliseconds.
    while serialcon.BytesAvailable > 0                                      %If there's any junk leftover on the serial line...
        fscanf(serialcon,'%d',serialcon.BytesAvailable);                    %Remove all of the replies from the serial line.
    end
    fwrite(serialcon,'Z','uchar');                                          %Send the check status code to the Arduino board.
    temp = fscanf(serialcon,'%d');                                          %Read the reply, which should be the version number.
    moto.version = temp/100;                                                %Divide the reply by 100 to get the version number.
end
s = Load_MotoTrak_Serial_Codes(moto.version);                               %Load the serial block codes for the specified sketch version.


%% Functions required for backwards compatibility.

%Basic status functions.
moto.check_serial = @()v2p0_check_serial_deprecated(serialcon);             %Set the function for checking the serial connection.
moto.check_sketch = @()v2p0_check_sketch_deprecated(serialcon);             %Set the function for checking that the MotoTrak sketch is running.
moto.check_version = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.GET_SKETCH_VER);    %Set the function for returning the version of the MotoTrak sketch running on the controller.
moto.booth = ...
    @()v2p0_read_eeprom_uint16_deprecated(serialcon,s,s.EEPROM_BOOTH_NUM);  %Set the function for returning the booth number saved on the controller.
moto.booth_bwc = ...
    @()v2p0_simple_return_char_deprecated(serialcon,...
    [char(s.GET_BOOTH_NUMBER), 'A']);                                       %Set the function for returning the booth number saved on the controller, in the backwards compatible method.
moto.set_booth = ...
    @(int)v2p0_write_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_BOOTH_NUM,int);                                              %Set the function for setting the booth number saved on the controller.
moto.close_serialcon = @()v2p0_close_serialcon_deprecated(serialcon);       %Set the function for closing and deleting the serial connection.

%Motor manipulandi functions.
moto.device = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.DEVICE_ID);         %Set the function for checking which device is connected to an input.
moto.baseline = ...
    @()v2p0_read_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_CAL_BASE_INT);                                               %Set the function for reading the loadcell baseline value.
moto.cal_grams = ...
    @()v2p0_read_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_CAL_FORCE_INT);                                              %Set the function for reading the number of grams a loadcell was calibrated to.
moto.n_per_cal_grams = ...
    @()v2p0_read_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_CAL_TICK_INT);                                               %Set the function for reading the counts-per-calibrated-grams for a loadcell.
moto.read_Pull = ...
    @()v2p0_read_pull_deprecated(serialcon,s.READ_DEVICE_VAL);              %Set the function for reading the value on a loadcell.
moto.set_baseline = ...
    @(int)v2p0_write_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_CAL_BASE_INT,int);                                           %Set the function for setting the loadcell baseline value.
moto.set_cal_grams = ...
    @(int)v2p0_write_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_CAL_FORCE_INT,int);                                          %Set the function for setting the number of grams a loadcell was calibrated to.
moto.set_n_per_cal_grams = ...
    @(int)v2p0_write_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_CAL_TICK_INT,int);                                           %Set the function for setting the counts-per-newton for a loadcell.
moto.trigger_feeder = ...
    @(i)v2p0_simple_command_deprecated(serialcon,s.TRIGGER_FEEDER);         %Set the function for sending a trigger to a feeder.
moto.trigger_stim = ...
    @()v2p0_send_uint8_deprecated(serialcon,s.SEND_TRIGGER,1,0);            %Set the function for sending a trigger to a stimulator.
moto.stream_enable = ...
    @(int)v2p0_stream_enable_deprecated(serialcon,s.STREAM_ENABLE,int);     %Set the function for enabling or disabling the stream.
moto.set_stream_period = ...
    @(int)v2p0_set_stream_period_deprecated(serialcon,...
    s.SET_STREAM_PERIOD,int);                                               %Set the function for setting the stream period.
moto.stream_period = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,...
    s.RETURN_STREAM_PERIOD);                                                %Set the function for checking the current stream period.
moto.set_stream_ir = @(i)v2p0_set_stream_input_deprecated(serialcon,s,2,i); %Set the function for setting which IR input is read out in the stream.
moto.stream_ir = @()v2p0_get_stream_input_deprecated(serialcon,s,2);        %Set the function for checking the current stream IR input.
moto.read_stream = @()v2p0_read_stream_deprecated(serialcon);               %Set the function for reading values from the stream.
moto.clear = @()v2p0_clear_stream_deprecated(serialcon);                    %Set the function for clearing the serial line prior to streaming.
moto.knob_toggle = @(i)v2p0_set_stream_input_deprecated(serialcon,s,1,6);   %Set the function for enabling/disabling knob analog input.
moto.sound_1000 = @()v2p0_send_uint8_deprecated(serialcon,s.PLAY_TONE,1,0); %Set the function for playing a default 1000 Hz, 20 ms tone.
moto.sound_1100 = @()v2p0_send_uint8_deprecated(serialcon,s.PLAY_TONE,2,0); %Set the function for playing a default 1100 Hz, 20 ms tone.
moto.lever_range = ...
    @()v2p0_read_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_LEVER_RANGE);                                                %Set the function for reading the degree range of a lever.
moto.set_lever_range = ...
    @(int)v2p0_write_eeprom_uint16_deprecated(serialcon,...
    s,s.EEPROM_LEVER_RANGE,int);                                            %Set the function for setting the loadcell baseline value.

%Behavioral control functions.
moto.play_hitsound = ...
    @(i)v2p0_send_uint8_deprecated(serialcon,s.PLAY_TONE,3,0);              %Set the function for playing a hit sound on the Arduino (default 4000 Hz, 20 ms).
moto.feed = @()v2p0_simple_command_deprecated(serialcon,s.TRIGGER_FEEDER);  %Set the function for triggering food/water delivery.
moto.feed_dur = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,...
    s.RETURN_FEED_TRIG_DUR);                                                %Set the function for checking the current feeding/water trigger duration on the controller.
moto.set_feed_dur = ...
    @(int)v2p0_send_uint16_deprecated(serialcon,s.SET_FEED_TRIG_DUR,int,0); %Set the function for setting the feeding/water trigger duration on the controller.
moto.stim = @()v2p0_send_uint8_deprecated(serialcon,s.SEND_TRIGGER,1,0);    %Set the function for sending a trigger to the stimulation trigger output.
moto.stim_off = ...
    @()v2p0_simple_command_deprecated(serialcon,s.STOP_TRIGGER);            %Set the function for immediately shutting off the stimulation output.
moto.stim_dur = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_TRIG_DUR);   %Set the function for checking the current stimulation trigger duration on the controller.
moto.set_stim_dur = ...
    @(int)v2p0_send_uint16_deprecated(serialcon,s.SET_TRIG_DUR,int,0);      %Set the function for setting the stimulation trigger duration on the controller.
moto.lights = @(i)v2p0_set_cage_lights_deprecated(serialcon,s,i);           %Set the function for turn the overhead cage lights on/off.
moto.autopositioner = ...
    @(int)v2p0_send_uint16_deprecated(serialcon,s.SET_AP_DIST,int,1);       %Set the function for setting the autopositioner distance.
moto.bwc_autopositioner = ...
    @(int)v2p0_bwc_long_command_deprecated(serialcon,...
    s.BWC_SET_AP_DIST,int,0);                                               %Set the backwards-compatible function for setting the autopositioner distance.

%% Functions available on controller sketch version 2.0+.

%Basic status functions.
moto.set_serial_number = ...
    @(int)v2p0_write_eeprom_uint32_deprecated(serialcon,s,s.EEPROM_SN,int); %Set the function for saving the controller serial number in the EEPROM.
moto.get_serial_number = ...
    @()v2p0_read_eeprom_uint32_deprecated(serialcon,s,s.EEPROM_SN);         %Set the function for reading the controller serial number from the EEPROM.

%Calibration functions.
moto.set_baseline_float = ...
    @(i,val)v2p0_set_cal_float_deprecated(serialcon,s,s.EEPROM_CAL_BASE_FL,i,val);     %Set the function for saving the device calibration baseline as a float in the EEPROM.
moto.get_baseline_float = ...
    @(i)v2p0_get_cal_float_deprecated(serialcon,s,s.EEPROM_CAL_BASE_FL,i);             %Set the function for reading the device baseline as a float in the EEPROM.
moto.set_slope_float = ...
    @(i,val)v2p0_set_cal_float_deprecated(serialcon,s,s.EEPROM_CAL_SLOPE_FL,i,val);    %Set the function for saving the device baseline as a float in the EEPROM.
moto.get_slope_float = ...
    @(i)v2p0_get_cal_float_deprecated(serialcon,s,s.EEPROM_CAL_SLOPE_FL,i);            %Set the function for reading the device baseline as a float in the EEPROM.

%Motor manipulandi functions.
moto.read_input = ...
    @(i)v2p0_send_uint8_return_int16_deprecated(serialcon,s.READ_DEVICE_VAL,i);       %Set the function for reading the value on one current input.
moto.reset_rotary_encoder = ...
    @()v2p0_simple_command_deprecated(serialcon,s.RESET_COUNTER);                      %Set the function for resetting the current rotary encoder count.
moto.set_stream_input = ...
    @(index,input)v2p0_set_stream_input_deprecated(serialcon,s,index,input);           %Set the function for setting which IR input is read out in the stream.
moto.get_stream_input = @(index)v2p0_get_stream_input_deprecated(serialcon,s,index);   %Set the function for checking the current stream IR input.

%Tone commands.
moto.play_tone = @(i)v2p0_send_uint8_deprecated(serialcon,s.PLAY_TONE,i,0);            %Set the function for immediate triggering of a tone.
moto.stop_tone = @()v2p0_simple_command_deprecated(serialcon,s.STOP_TONE);             %Set the function for immediately silencing all tones.
moto.set_tone_index = ...
    @(i)v2p0_send_uint8_deprecated(serialcon,s.SET_TONE_INDEX,i,0);                    %Set the function for setting the current tone index.
moto.get_tone_index = ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_TONE_INDEX);             %Set the function for checking the current tone index.
moto.set_tone_freq = ...
    @(int)v2p0_send_uint16_deprecated(serialcon,s.SET_TONE_FREQ,int,0);                %Set the function for setting the frequency of a tone.
moto.get_tone_freq = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_TONE_FREQ);             %Set the function for checking the current frequency of a tone.
moto.set_tone_dur = ...
    @(int)v2p0_send_uint16_deprecated(serialcon,s.SET_TONE_DUR,int,0);                 %Set the function for setting the duration of a tone.
moto.get_tone_dur = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_TONE_DUR);              %Set the function for checking the current duration of a tone.
moto.set_tone_mon_input = ...
    @(int)v2p0_send_uint8_deprecated(serialcon,s.SET_TONE_MON,int,0);                  %Set the function for setting the monitored input for triggering a tone.
moto.get_tone_mon_input =  ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_TONE_MON);               %Set the function for checking the current monitored input for triggering a tone.
moto.set_tone_trig_type = ...
    @(int)v2p0_send_uint8_deprecated(serialcon,s.SET_TONE_TYPE,int,0);                 %Set the function for setting the trigger type for a tone.
moto.get_tone_trig_type = ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_TONE_TYPE);              %Set the function for checking the current trigger type for a tone.
moto.set_tone_trig_thresh = ...
    @(int)v2p0_send_int16_deprecated(serialcon,s.SET_TONE_THRESH,int,0);               %Set the function for setting the trigger threshold for a tone.
moto.get_tone_trig_thresh = ...
    @()v2p0_simple_return_int16_deprecated(serialcon,s.RETURN_TONE_THRESH);            %Set the function for checking the current trigger threshold for a tone.
moto.get_max_num_tones = ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_MAX_TONES);              %Set the function for checking the maximum number of tones that can be set.

%Vibration control commands.
moto.toggle_vibration = @()v2p0_send_uint8_deprecated(serialcon,s.VIB_TOGGLE,[],0);    %Set the function for switching the LRA pin mode to output.
moto.start_vibration = @()v2p0_send_uint8_deprecated(serialcon,s.START_VIB,[],0);      %Set the function for immediately starting a vibration pulse train.
moto.stop_vibration = @()v2p0_send_uint8_deprecated(serialcon,s.STOP_VIB,[],0);        %Set the function for immediately stopping a vibration pulse train.
moto.set_vibration_dur = ...
    @(dur)v2p0_send_uint16_deprecated(serialcon,s.SET_VIB_DUR,dur,0);                  %Set the function for setting the vibration pulse duration.
moto.get_vibration_dur = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_VIB_DUR);               %Set the function for checking the current vibration pulse duration.
moto.set_vibration_ipi = ...
    @(dur)v2p0_send_uint16_deprecated(serialcon,s.SET_VIB_IPI,dur,0);                  %Set the function for setting the vibration pulse train onset-to-onset inter-pulse interval.
moto.get_vibration_ipi = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_VIB_IPI);               %Set the function for checking the current vibration pulse train onset-to-onset inter-pulse interval.
moto.set_vibration_n = ...
    @(dur)v2p0_send_uint16_deprecated(serialcon,s.SET_VIB_N,dur,0);                    %Set the function for setting the vibration pulse train duration, in numbers of pulses.
moto.get_vibration_n = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_VIB_N);                 %Set the function for checking the current vibration pulse train duration, in numbers of pulses.
moto.set_vibration_gap_start = ...
    @(dur)v2p0_send_uint16_deprecated(serialcon,s.SET_VIB_GAP_START,dur,0);            %Set the function for setting the vibration train starting skipped pulse index.
moto.get_vibration_gap_start = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_VIB_GAP_START);         %Set the function for checking the current vibration train starting skipped pulse index.
moto.set_vibration_gap_stop = ...
    @(dur)v2p0_send_uint16_deprecated(serialcon,s.SET_VIB_GAP_STOP,dur,0);             %Set the function for setting the vibration train stop skipped pulse index.
moto.get_vibration_gap_stop = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_VIB_GAP_STOP);          %Set the function for checking the current vibration train stop skipped pulse index.
moto.set_vibration_masking = ...
    @(int)v2p0_send_uint8_deprecated(serialcon,s.VIB_MASK_ENABLE,int,0);               %Set the function for enabling or disabling the stream.
moto.set_vibration_tone_freq = ...
    @(int)v2p0_send_uint16_deprecated(serialcon,s.SET_VIB_TONE_FREQ,int,0);            %Set the function for setting the frequency of a tone.
moto.get_vibration_tone_freq = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_VIB_TONE_FREQ);         %Set the function for checking the current frequency of a tone.
moto.set_vibration_tone_dur = ...
    @(int)v2p0_send_uint16_deprecated(serialcon,s.SET_VIB_TONE_DUR,int,0);             %Set the function for setting the duration of a tone.
moto.get_vibration_tone_dur = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_VIB_TONE_DUR);          %Set the function for checking the current duration of a tone.
moto.set_vibration_task_mode = ...
    @(int)v2p0_send_uint8_deprecated(serialcon,s.SET_VIB_TASK_MODE,int,0);             %Set the function for setting the duration of a tone.
moto.get_vibration_task_mode = ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_VIB_TASK_MODE);          %Set the function for checking the current duration of a tone.
moto.set_vibrator_index = ...
    @(i)v2p0_send_uint8_deprecated(serialcon,s.SET_VIB_INDEX,i,0);                     %Set the function for setting the vibrator index.
moto.get_vibrator_index = ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_VIB_INDEX);              %Set the function for checking the current vibrator index.


%Trigger commands.
moto.send_trigger = @(i)v2p0_send_uint8_deprecated(serialcon,s.SEND_TRIGGER,i,0);      %Set the function for an immediate output trigger.
moto.stop_trigger = @()v2p0_simple_command_deprecated(serialcon,s.STOP_TRIGGER);       %Set the function for immediately stopping the active trigger.
moto.set_trig_index = ...
    @(i)v2p0_send_uint8_deprecated(serialcon,s.SET_TRIG_INDEX,i,0);                    %Set the function for setting the current trigger index.
moto.get_trig_index = ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_TRIG_INDEX);             %Set the function for checking the current trigger index.
moto.set_trig_dur = ...
    @(int)v2p0_send_uint16_deprecated(serialcon,s.SET_TRIG_DUR,int,0);                 %Set the function for setting the duration of a trigger.
moto.get_trig_dur = ...
    @()v2p0_simple_return_uint16_deprecated(serialcon,s.RETURN_TRIG_DUR);              %Set the function for checking the current duration of a trigger.
moto.set_trig_mon_input = ...
    @(int)v2p0_send_uint8_deprecated(serialcon,s.SET_TRIG_MON,int,0);                  %Set the function for setting the monitored input for a trigger.
moto.get_trig_mon_input =  ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_TRIG_MON);               %Set the function for checking the current monitored input a trigger.
moto.set_trig_type = ...
    @(int)v2p0_send_uint8_deprecated(serialcon,s.SET_TRIG_TYPE,int,0);                 %Set the function for setting the trigger type.
moto.get_trig_type = ...
    @()v2p0_simple_return_uint8_deprecated(serialcon,s.RETURN_TRIG_TYPE);              %Set the function for checking the current trigger type.
moto.set_trig_thresh = ...
    @(int)v2p0_send_int16_deprecated(serialcon,s.SET_TRIG_THRESH,int,0);               %Set the function for setting the trigger threshold.
moto.get_trig_thresh = ...
    @()v2p0_simple_return_int16_deprecated(serialcon,s.RETURN_TRIG_THRESH);            %Set the function for checking the current trigger threshold.


%% This function checks the status of the serial connection.
function output = v2p0_check_serial_deprecated(serialcon)
if isa(serialcon,'serial') && isvalid(serialcon) && ...
        strcmpi(get(serialcon,'status'),'open')                             %Check the serial connection...
    output = 1;                                                             %Return an output of one.
    disp(['Serial port ''' serialcon.Port ''' is connected and open.']);    %Show that everything checks out on the command line.
else                                                                        %If the serial connection isn't valid or open.
    output = 0;                                                             %Return an output of zero.
    warning('CONNECT_MOTOTRAK:NonresponsivePort',...
        'The serial port is not responding to status checks!');             %Show a warning.
end


%% This function checks to see if the MotoTrak_Controller_V2_0 sketch is current running on the controller.
function output = v2p0_check_sketch_deprecated(serialcon)
fwrite(serialcon,'A','uchar');                                              %Send the check sketch code to the controller.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if output == 111                                                            %If the Arduino returned the number 111...
    output = 1;                                                             %...show that the Arduino connection is good.
else                                                                        %Otherwise...
    output = 0;                                                             %...show that the Arduino connection is bad.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    Debug_Message('A',[]);                                                  %Print a debug message.
end


%% This function sends a byte command without an expected reply.
function v2p0_simple_command_deprecated(serialcon,cmd)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function sends a byte command and receives a character reply.
function output = v2p0_simple_return_char_deprecated(serialcon,cmd)
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function sends a byte command and receives a single uint8 reply.
function output = v2p0_simple_return_uint8_deprecated(serialcon,cmd)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 1 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 1                                            %If the controller replied...
    output = fread(serialcon,1,'uint8');                                    %Read the reply from the serial line as an unsigned 16-bit integer.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function sends a byte command and receives a single uint16 reply.
function output = v2p0_simple_return_uint16_deprecated(serialcon,cmd)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 2 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 2                                            %If the controller replied...
    output = fread(serialcon,1,'uint16');                                   %Read the reply from the serial line as an unsigned 16-bit integer.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function sends a byte command and receives a single int16 reply.
function output = v2p0_simple_return_int16_deprecated(serialcon,cmd)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 2 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 2                                            %If the controller replied...
    output = fread(serialcon,1,'int16');                                    %Read the reply from the serial line as an unsigned 16-bit integer.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function sends a byte command with a single uint8 argument.
function v2p0_send_uint8_deprecated(serialcon,cmd,int,dummy_bytes)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,int,'uint8');                                              %Send the uint8 argument.
for i = 1:dummy_bytes                                                       %Step through any dummy bytes.
    fwrite(serialcon,0,'uint8');                                            %Send a dummy byte to advance the command queue.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    cmd = [cmd, int, zeros(1,dummy_bytes)];                                 %Concatenate the whole command.
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function sends a byte command with a single uint16 argument.
function v2p0_send_uint16_deprecated(serialcon,cmd,int,dummy_bytes)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,int,'uint16');                                             %Send the uint16 argument.
for i = 1:dummy_bytes                                                       %Step through any dummy bytes.
    fwrite(serialcon,0,'uint8');                                            %Send a dummy byte to advance the command queue.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    bytes = fliplr(typecast(uint16(int),'uint8'));                          %Typecast the 16-bit integer into two bytes.
    cmd = [cmd, bytes, zeros(1,dummy_bytes)];                               %Concatenate the whole command.
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function sends a byte command with a single int16 argument.
function v2p0_send_int16_deprecated(serialcon,cmd,int,dummy_bytes)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,int,'int16');                                              %Send the int16 argument.
for i = 1:dummy_bytes                                                       %Step through any dummy bytes.
    fwrite(serialcon,0,'uint8');                                            %Send a dummy byte to advance the command queue.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    bytes = fliplr(typecast(int16(int),'uint8'));                           %Typecast the 16-bit integer into two bytes.
    cmd = [cmd, bytes, zeros(1,dummy_bytes)];                               %Concatenate the whole command.
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function sends a byte command with a single int16 argument.
function v2p0_bwc_long_command_deprecated(serialcon,cmd,int,dummy_bytes)     
bytes = typecast(int16(int),'uint8');                                       %Typecast the 16-bit integer into two bytes.
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,fliplr(bytes),'uint8');                                    %Send the int16 argument.
for i = 1:dummy_bytes                                                       %Step through any dummy bytes.
    fwrite(serialcon,0,'uint8');                                            %Send a dummy byte to advance the command queue.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    cmd = [cmd, bytes, zeros(1,dummy_bytes)];                               %Concatenate the whole command.
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function sends a byte command with a single uint16 argument and receives a single int16 reply.
function output = v2p0_send_uint8_return_int16_deprecated(serialcon,cmd,int)     
fwrite(serialcon,cmd,'uint8');                                              %Send the command to the controller.
fwrite(serialcon,int,'uint8');                                              %Send the uint8 value to the controller.
fwrite(serialcon,0,'uint16');                                               %Send a dummy uint16 value to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 2 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 2                                            %If the controller replied...
    output = fread(serialcon,1,'int16');                                    %Read the reply from the serial line as an unsigned 16-bit integer.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    cmd = [cmd, int, zeros(1,2)];                                           %Concatenate the whole command.
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function reads a uint16 out of the controller's EEPROM.
function output = v2p0_read_eeprom_uint16_deprecated(serialcon,s,addr)     
fwrite(serialcon,s.READ_2BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,0,'uint16');                                               %Send a dummy uint16 value to the controller to push back the reply uint16.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 2 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 2                                            %If the controller replied...
    output = fread(serialcon,1,'uint16');                                   %Read the reply from the serial line as an unsigned 16-bit integer.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    addr = typecast(uint16(addr),'uint8');                                  %Typecast the 16-bit address into two bytes.
    cmd = [s.READ_2BYTES_EEPROM, addr, zeros(1,2)];                         %Concatenate the whole command.
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function writes a uint16 to the controller's EEPROM.
function v2p0_write_eeprom_uint16_deprecated(serialcon,s,addr,int)     
fwrite(serialcon,s.SAVE_2BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,int,'uint16');                                             %Send a dummy uint16 value to the controller to push back the reply uint16.
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    addr = typecast(uint16(addr),'uint8');                                  %Typecast the 16-bit address into two bytes.
    int = typecast(uint16(int),'uint8');                                    %Typecast the 16-bit integer into two bytes.
    cmd = [s.SAVE_2BYTES_EEPROM, addr, int];                                %Concatenate the whole command.
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function reads a uint16 out of the controller's EEPROM.
function output = v2p0_read_eeprom_uint32_deprecated(serialcon,s,addr)     
fwrite(serialcon,s.READ_4BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,0,'uint32');                                               %Send a dummy uint32 value to the controller to push back the reply uint16.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration.
while serialcon.BytesAvailable < 4 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 4                                            %If the controller replied...
    output = fread(serialcon,1,'uint32');                                   %Read the reply from the serial line as an unsigned 32-bit integer.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    addr = typecast(uint16(addr),'uint8');                                  %Typecast the 16-bit address into two bytes.
    cmd = [s.READ_4BYTES_EEPROM, addr, zeros(1,4)];                         %Concatenate the whole command.
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function writes a uint32 to the controller's EEPROM.
function v2p0_write_eeprom_uint32_deprecated(serialcon,s,addr,int)     
fwrite(serialcon,s.SAVE_4BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,int,'uint32');                                             %Send a dummy uint16 value to the controller to push back the reply uint32.
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    addr = typecast(uint16(addr),'uint8');                                  %Typecast the 16-bit address into two bytes.
    int = typecast(uint32(int),'uint8');                                    %Typecast the 32-bit integer into two bytes.
    cmd = [s.SAVE_4BYTES_EEPROM, addr, int];                                %Concatenate the whole command.
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function saves a calibration float32 value in the EEPROM.
function v2p0_set_cal_float_deprecated(serialcon,s,addr,i,val)                         
addr = addr + 8*i;                                                          %Set the corresponding calibration value EEPROM address for the specified device.
v2p0_write_eeprom_float32_deprecated(serialcon,s,addr,val);                 %Call the function to write float32 to the EEPROM.  


%% This function retrieves a calibration float32 value from the EEPROM.
function output = v2p0_get_cal_float_deprecated(serialcon,s,addr,i)                      
addr = addr + 8*i;                                                          %Set the corresponding calibration value EEPROM address for the specified device.
output = v2p0_read_eeprom_float32_deprecated(serialcon,s,addr);             %Call the function to read the float32 from the EEPROM.


%% This function reads a float32 out of the controller's EEPROM.
function output = v2p0_read_eeprom_float32_deprecated(serialcon,s,addr)     
fwrite(serialcon,s.READ_4BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
fwrite(serialcon,0,'uint32');                                               %Send a dummy uint32 value to the controller to push back the reply float32.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration.
while serialcon.BytesAvailable < 4 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 4                                            %If the controller replied...
    bytes = fread(serialcon,4,'uint8');                                     %Read the reply from the serial line as a 4 unsigned bytes.
    output = double(typecast(uint8(bytes),'single'));                       %Cast the 4 unsigned bytes back into a floating-point number.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    addr = typecast(uint16(addr),'uint8');                                  %Typecast the 16-bit address into two bytes.
    cmd = [s.READ_4BYTES_EEPROM, addr, zeros(1,4)];                         %Concatenate the whole command.
    Debug_Message(cmd,output);                                              %Print a debug message.
end


%% This function writes a float32 to the controller's EEPROM.
function v2p0_write_eeprom_float32_deprecated(serialcon,s,addr,val)     
fwrite(serialcon,s.SAVE_4BYTES_EEPROM,'uint8');                             %Send the command to the controller.
fwrite(serialcon,addr,'uint16');                                            %Send the uint16 EEPROM address to the controller.
bytes = typecast(single(val),'uint8');                                      %Cast the floating-point value to 4 unsigned bytes.
for i = 1:4                                                                 %Step through each byte.
    fwrite(serialcon,bytes(i),'uint8');                                     %Send the 32-bit floating point number to the controller.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    addr = typecast(uint16(addr),'uint8');                                  %Typecast the 16-bit address into two bytes.
    cmd = [s.SAVE_4BYTES_EEPROM, addr, bytes];                              %Concatenate the whole command.
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function reads a value from the isometric pull or the knob.
function output = v2p0_read_pull_deprecated(serialcon,cmd)
if serialcon.UserData(2) == 1                                               %If the isometric pull is the primary device...
    index = 1;                                                              %Set the input index to 1.
else                                                                        %Otherwise...
    index = 6;                                                              %Set the input index to 6.
end
output = v2p0_send_uint8_return_int16_deprecated(serialcon,cmd,index);      %Set the function for reading the value on a loadcell.


%% This function enables/disables streaming.
function v2p0_stream_enable_deprecated(serialcon,cmd,enable_val)
if enable_val > 0                                                           %If streaming is being enabled...
    v2p0_clear_stream_deprecated(serialcon);                                %Clear any bytes currently on the stream.
end
v2p0_send_uint8_deprecated(serialcon,cmd,enable_val,0);                     %Call the function to set the streaming state on the controller.


%% This function sets the streaming period, converting a millisecond argument to microseconds.
function v2p0_set_stream_period_deprecated(serialcon,cmd,stream_period)
stream_period = round(1000*stream_period);                                  %Convert the specified stream period from milliseconds to microseconds.
v2p0_send_uint16_deprecated(serialcon,cmd,stream_period,0);                 %Set the function for setting the stream period.


%% This function sets the input for one index in the controller's stream.
function v2p0_set_stream_input_deprecated(serialcon,s,index,input)     
stream_order = serialcon.UserData(2:7);                                     %Grab the current stream order.
stream_order(index) = input;                                                %Set the specified stream position to the specified source.
fwrite(serialcon,s.SET_STREAM_ORDER,'uint8');                               %Send the command to the controller.
fwrite(serialcon,stream_order,'uint8');                                     %Send the modified stream order back to the controller.
serialcon.UserData(1) = sum(stream_order ~= 0);                             %Save the number of streaming inputs in the serial connection's "UserData" property.
serialcon.UserData(2:7) = stream_order;                                     %Save the modified stream order back to the serial connection's "UserData" property.
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    cmd = [s.SET_STREAM_ORDER, stream_order];                               %Concatenate the whole command.
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function sets the input for one index in the controller's stream.
function output = v2p0_get_stream_input_deprecated(serialcon,s,index)     
fwrite(serialcon,s.RETURN_STREAM_ORDER,'uint8');                            %Send the command to the controller.
output = [];                                                                %Create a variable to hold the output.
timeout = now + 1/86400;                                                    %Set the reply timeout duration (100 milliseconds).
while serialcon.BytesAvailable < 6 && now < timeout                         %Loop until there's a reply or the operating times out.
    pause(0.001);                                                           %Pause for 1 millisecond.
end
if serialcon.BytesAvailable >= 6                                            %If the controller replied...
    stream_order = fread(serialcon,6,'uint8');                              %Read the reply from the serial line as unsigned 8-bit integer.
    output = stream_order(index);                                           %Return the current source from the specified stream position.
    serialcon.UserData(1) = sum(stream_order ~= 0);                         %Save the number of streaming inputs in the serial connection's "UserData" property.
    serialcon.UserData(2:7) = stream_order;                                 %Save the current stream order back to the serial connection's "UserData" property.
end
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    cmd = [s.RETURN_STREAM_ORDER];                                          %Concatenate the whole command.
    Debug_Message(cmd,stream_order);                                        %Print a debug message.
end


%% This function reads in the values from the data stream when streaming is enabled.
function output = v2p0_read_stream_deprecated(serialcon)
N = serialcon.UserData(1) + 1;                                              %Grab the number of inputs and line count from the user data.

timeout = now + 0.05*86400;                                                 %Set the following loop to timeout after 50 milliseconds.
while serialcon.BytesAvailable == 0 && now < timeout                        %Loop until there's a reply on the serial line or there's 
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
output = [];                                                                %Create an empty matrix to hold the serial line reply.
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    try
        streamdata = fscanf(serialcon,'%d')';                               %Read in the incoming data.
        output(end+1,:) = streamdata(1:N(1));                               %Read each byte and save it to the output matrix.
    catch err                                                               %If there was a stream read error...
        warning('MOTOTRAK:StreamingError',['MOTOTRAK STREAM READ '...
            'WARNING: ' err.identifier]);                                   %Show that a stream read error occured.
    end
end


% if N(2) > 0                                                                 %If there's at least one line to grab...
%     output = nan(N(2),N(1)+1);                                              %Pre-allocate a matrix to hold the output.
%     for i = 1:N(2)                                                          %Step through all available lines.
%         try
%             output(i,:) = fscanf(serialcon,'%d')';                          %Read each byte and save it to the output matrix.
%         catch err                                                           %If there was a stream read error...
%             warning('MOTOTRAK:StreamingError',['MOTOTRAKSTREAM READ '...
%                 'WARNING: ' err.identifier]);                               %Show that a stream read error occured.
%         end
%     end
%     serialcon.UserData(2) = serialcon.UserData(2) - N(2);                   %Reset the line counter.
% else                                                                        %Otherwise...
%     output = [];                                                            %Output an empty matrix.
% end

% %The following comment section streams using Serial.write on the Arduino,
% %but it didn't significantly improve streaming speed, so Serial.print is
% %used for better backwards compatibility.
% ln_bytes = 4 + 2*num_inputs;                                                %Calculate the number of bytes per line.
% N = fix(serialcon.BytesAvailable/ln_bytes);                                 %Check how many lines are available.
% if N == 0                                                                   %If no complete lines are available...
%     output = [];                                                            %Return empty brackets.
% else                                                                        %Otherwise...
%     output = zeros(N, num_inputs + 1);                                      %Pre-allocate an output matrix.
%     for i = 1:N                                                             %Step through the available lines.
%         output(i,1) = fread(serialcon,1,'uint32');                          %Read in the sample timestamp.
%         for j = 1:num_inputs                                                %Step through the streaming inputs.
%             output(i,j+1) = fread(serialcon,1,'int16');                     %Read in each input sample.
%         end
%     end
% end


%% This function clears any remaining values from the serial line.
function v2p0_clear_stream_deprecated(serialcon)
flushinput(serialcon);                                                      %Flush the input buffer.
flushoutput(serialcon);                                                     %Flush the output buffer.
% serialcon.UserData(2) = 0;                                                  %Reset the line counter.


%% This function sets the PWM output value of the cage lights.
function v2p0_set_cage_lights_deprecated(serialcon,s,pwm_val)
% pwm_val = round(255*pwm_val);                                               %Convert the input value to an integer from 0 to 255.
if pwm_val > 255                                                            %If the PWM value is greater than 255..
    pwm_val = 255;                                                          %Set the PWM value to 255.
elseif pwm_val < 0                                                          %If the PWM value is less than 0...
    pwm_val = 0;                                                            %Set the PWM value to 0.
end
fwrite(serialcon,s.SET_CAGE_LIGHTS,'uint8');                                %Send the command to the controller.
fwrite(serialcon,pwm_val,'uint8');                                          %Send the PWM value to the controller.
if serialcon.Userdata(end) == 1                                             %If the debug flag is turned on...
    cmd = [s.SET_CAGE_LIGHTS, pwm_val];                                     %Concatenate the whole command.
    Debug_Message(cmd,[]);                                                  %Print a debug message.
end


%% This function closes the serial connection and deletes the serial object.
function v2p0_close_serialcon_deprecated(serialcon)
v2p0_clear_stream_deprecated(serialcon);                                               %Clear any data off the serial line.
fclose(serialcon);                                                          %Close the serial connection.
delete(serialcon);                                                          %Delete the serial object.

% %% This function is called whenever the serial line receiveds a line feed terminator.
% function v2p0_serial_line_counter(serialcon,~,~)
% serialcon.UserData(2) = serialcon.UserData(2) + 1;                          %Increment the line counter.


%% This function prints debug message when the debugging flag is true.
function Debug_Message(cmd,output)
fprintf(1,'%s: ',datestr(now,'HH:MM:SS.FFF'));                              %Print a timestamped to the command line.
fprintf(1,'''%s'' [ ',cmd);                                                 %Print the command string to the command line.
fprintf(1,'%1.0f ',cmd);                                                    %Print the command values to the command line.
fprintf(1,'] ');                                                            %Print a close bracket around the command values.
if ~isempty(output)                                                         %If an output was specified...
    fprintf(1,' >> ');                                                      %Print an output indicator.
    fprintf(1,'%1.0f\t',output);                                            %Print the output.
end
fprintf(1,'\n');                                                            %Print a carriage return.