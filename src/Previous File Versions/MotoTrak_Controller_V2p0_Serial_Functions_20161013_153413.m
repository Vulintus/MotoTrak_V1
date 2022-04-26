function ardy = MotoTrak_Controller_V2p0_Serial_Functions(ardy)

%MotoTrak_Controller_V2p0_Serial_Functions.m - Vulintus, Inc., 2016
%
%   MotoTrak_Controller_V2p0_Serial_Functions defines and adds the Arduino
%   serial communication functions to the "ardy" structure. These functions
%   are for sketch versions 2.0+ and may not work with older versions.
%
%   UPDATE LOG:
%   05/12/2016 - Drew Sloan - Created the basic sketch status functions.
%   10/13/2016 - Drew Sloan - Added "v2p0_" prefix to all subfunction names
%       to prevent duplicate name errors in collated MotoTrak script.
%


serialcon = ardy.serialcon;                                                 %Grab the handle for the serial connection.

%Basic status functions.
ardy.check_serial = @()v2p0_check_serial(serialcon);                        %Set the function for checking the status of the serial connection.
ardy.check_sketch = @()v2p0_check_sketch(serialcon);                        %Set the function for checking the version of the CONNECT_MOTOTRAK sketch.
ardy.check_version = @()v2p0_check_version(serialcon);                      %Set the function for returning the Arduino sketch version number.
ardy.set_serial_number = @(int)v2p0_set_int32(serialcon,'C%%%%',int);       %Set the function for saving the controller serial number in the EEPROM.
ardy.get_serial_number = @()v2p0_get_int32(serialcon,'D####');              %Set the function for reading the controller serial number from the EEPROM.

% ardy.set_booth = @(int)long_cmd(serialcon,'B%%',[],int);                    %Set the function for setting the booth number saved on the Arduino.
% ardy.get_booth = @()simple_return(serialcon,'C#',1);                        %Set the function for returning the booth number saved on the Arduino.
% ardy.device = @(i)simple_return(serialcon,'D',1);                           %Set the function for checking which device is connected to the primary input.
% ardy.set_byte = @(int,i)long_cmd(serialcon,'E%%*',i,int);                   %Set the function for saving a byte in the EEPROM.
% ardy.get_byte = @(int)long_return(serialcon,'F%%#',[],int);                 %Set the function for returning a byte from the EEPROM.
% ardy.clear = @()clear_stream(serialcon);                                    %Set the function for clearing the serial line prior to streaming.
% 
% %Calibration functions.
% ardy.set_baseline = @(int)long_cmd(serialcon,'G%%',[],int);                 %Set the function for setting the primary device baseline value in the EEPROM.
% ardy.get_baseline = @()simple_return(serialcon,'H#',[]);                    %Set the function for reading the primary device baseline value from the EEPROM.
% ardy.set_slope = @(float)set_float(serialcon,'I%%%%',float);                %Set the function for setting the primary device slope in the EEPROM.
% ardy.get_slope = @()get_float(serialcon,'J####');                           %Set the function for reading the primary device slope from the EEPROM.
% ardy.set_range = @(float)set_float(serialcon,'K%%%%',float);                %Set the function for setting the primary device range in the EEPROM.
% ardy.get_range = @()get_float(serialcon,'L####');                           %Set the function for reading the primary device range from the EEPROM.
% 
% %Feeder functions.
% ardy.set_feed_trig_dur = @(int)long_cmd(serialcon,'M%%',[],int);            %Set the function for setting the feeding trigger duration on the Arduino.
% ardy.get_feed_trig_dur = @()simple_return(serialcon,'N',[]);                %Set the function for checking the current feeding trigger duration on the Arduino.
% ardy.set_feed_led_dur = @(int)long_cmd(serialcon,'O%%',[],int);             %Set the function for setting the feeder indicator LED duration on the Arduino.
% ardy.get_feed_led_dur = @()simple_return(serialcon,'P',[]);                 %Set the function for checking the current feeder indicator LED duration on the Arduino.
% ardy.feed = @()simple_cmd(serialcon,'Q',[]);                                %Set the function for triggering the feeder.
% 
% %Cage light functions.
% ardy.cage_lights = @(i)set_cage_lights(serialcon,'R*',i);                   %Set the function for setting the intensity (0-1) of the cage lights.
% 
% %One-shot input commands.
% ardy.get_val = @(i)simple_return(serialcon,'S*',i);                         %Set the function for checking the current value of any input.
% ardy.reset_rotary_encoder = @()simple_cmd(serialcon,'Z',[]);                %Set the function for resetting the current rotary encoder count.
% 
% %Streaming commands.
% ardy.set_stream_input = @(int,i)long_cmd(serialcon,'T%%*',i,int);           %Set the function for enabling/disabling the streaming states of the inputs.
% ardy.get_stream_input = @()simple_return(serialcon,'U',[]);                 %Returning the current streaming states of all the inputs.
% ardy.set_stream_period = @(int)long_cmd(serialcon,'V%%',[],int);            %Set the function for setting the stream period.
% ardy.get_stream_period = @()simple_return(serialcon,'W',[]);                %Set the function for checking the current stream period.
% ardy.stream_enable = @(i)simple_cmd(serialcon,'X*',i);                      %Set the function for enabling or disabling the stream.
% ardy.stream_trig_input = @(i)simple_cmd(serialcon,'Y*',i);                  %Set the function for setting the input to monitor for event-triggered streaming.
% ardy.read_stream = @()read_stream(serialcon);                               %Set the function for reading values from the stream.
% ardy.clear = @()clear_stream(serialcon);                                    %Set the function for clearing the serial line prior to streaming.
% 
% %Tone commands.
% ardy.set_tone_chan = @(i)simple_cmd(serialcon,'a*',i);                      %Set the function for setting the channel to play tones out of.
% ardy.set_tone_freq = @(i,int)long_cmd(serialcon,'b*%%',i,int);              %Set the function for setting the frequency of a tone.
% ardy.get_tone_freq = @(i)simple_return(serialcon,'g*',i);                   %Set the function for checking the current frequency of a tone.
% ardy.set_tone_dur = @(i,int)long_cmd(serialcon,'c*%%',i,int);               %Set the function for setting the duration of a tone.
% ardy.get_tone_dur = @(i)simple_return(serialcon,'h*',i);                    %Set the function for checking the current duration of a tone.
% ardy.set_tone_mon_input = @(i,int)long_cmd(serialcon,'d*%%',i,int);         %Set the function for setting the monitored input for triggering a tone.
% ardy.get_tone_mon_input = @(i)simple_return(serialcon,'i*',i);              %Set the function for checking the current monitored input for triggering a tone.
% ardy.set_tone_trig_type = @(i,int)long_cmd(serialcon,'e*%%',i,int);         %Set the function for setting the trigger type for a tone.
% ardy.get_tone_trig_type = @(i)simple_return(serialcon,'j*',i);              %Set the function for checking the current trigger type for a tone.
% ardy.set_tone_trig_thresh  = @(i,int)long_cmd(serialcon,'f*%%',i,int);      %Set the function for setting the trigger threshold for a tone.
% ardy.get_tone_trig_thresh = @(i)simple_return(serialcon,'k*',i);            %Set the function for checking the current trigger threshold for a tone.
% ardy.play_tone = @(i)simple_cmd(serialcon,'l*',i);                          %Set the function for immediate triggering of a tone.
% ardy.silence_tones = @()simple_cmd(serialcon,'m',[]);                       %Set the function for immediately silencing all tones.


%% This function checks the status of the serial connection.
function output = v2p0_check_serial(serialcon)
if isa(serialcon,'serial') && isvalid(serialcon) && ...
        strcmpi(get(serialcon,'status'),'open')                             %Check the serial connection...
    output = 1;                                                             %Return an output of one.
    disp(['Serial port ''' serialcon.Port ''' is connected and open.']);    %Show that everything checks out on the command line.
else                                                                        %If the serial connection isn't valid or open.
    output = 0;                                                             %Return an output of zero.
    warning('CONNECT_MOTOTRAK:NonresponsivePort',...
        'The serial port is not responding to status checks!');             %Show a warning.
end


%% This function checks to see if the MotoTrak_Controller_V2_0 sketch is current running on the Arduino.
function output = v2p0_check_sketch(serialcon)
fwrite(serialcon,'A','uchar');                                              %Send the check sketch code to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if output == 123                                                            %If the Arduino returned the number 123...
    output = 1;                                                             %...show that the Arduino connection is good.
else                                                                        %Otherwise...
    output = 0;                                                             %...show that the Arduino connection is bad.
end


%% This function checks the version of the Arduino sketch.
function output = v2p0_check_version(serialcon)
fwrite(serialcon,'B','uchar');                                              %Send the check sketch code to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
output = output/100;                                                        %Divide the returned value by 100 to find the version number.


%% This function sends commands with a 32-bit integer number into 4 characters encoding each byte.
function v2p0_set_int32(serialcon,command,int)     
i = strfind(command,'%%%%');                                                %Find the place in the command to insert the 32-bit floating-point bytes.
int = int32(int);                                                           %Make sure the input value is a 32-bit floating-point number.
bytes = typecast(int,'uint8');                                              %Convert the 32-bit floating-point number to 4 unsigned 8-bit integers.
for j = 0:3                                                                 %Step through the 4 bytes of the 32-bit binary string.
    command(i+j) = bytes(j+1);                                              %Add each byte of the 32-bit string to the command.
end
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function sends queries expected to return a 32-bit integer broken into 4 characters encoding each byte.
function output = v2p0_get_int32(serialcon,command)     
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
tic;                                                                        %Start a timer.
output = [];                                                                %Create an empty matrix to hold the serial line reply.
while numel(output) < 4 && toc < 0.05                                       %Loop until the output matrix is full or 50 milliseconds passes.
    if serialcon.BytesAvailable > 0                                         %If there's bytes available on the serial line...
        output(end+1) = fscanf(serialcon,'%d');                             %Collect all replies in one matrix.
        tic;                                                                %Restart the timer.
    end
end
if numel(output) < 4                                                        %If there's less than 4 replies...
    warning('CONNECT_MOTOTRAK:UnexpectedReply',['The Arduino sketch '...
        'did not return 4 bytes for a 32-bit integer query.']);             %Show a warning and return the reply, whatever it is, to the user.
else                                                                        %Otherwise...
    output = typecast(uint8(output(1:4)),'int32');                          %Convert the 4 received unsigned integers to a 32-bit integer.
end