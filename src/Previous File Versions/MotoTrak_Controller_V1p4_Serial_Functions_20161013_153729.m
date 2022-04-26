function ardy = MotoTrak_Controller_V1p4_Serial_Functions(ardy)

%MotoTrak_Controller_V1p4_Serial_Functions.m - Vulintus, Inc., 2015
%
%   MotoTrak_Controller_V1p4_Serial_Functions defines and adds the Arduino
%   serial communication functions to the "ardy" structure. These functions
%   are for sketch version 1.4 and earlier, and may not work with newer
%   version (2.0+).
%
%   UPDATE LOG:
%   05/09/2016 - Drew Sloan - Separated V1.4 serial functions from the
%       Connect_MotoTrak function to allow for loading V2.0 functions.
%   10/13/2016 - Drew Sloan - Added "v1p4_" prefix to all subfunction names
%       to prevent duplicate name errors in collated MotoTrak script.
%

%Basic status functions.
serialcon = ardy.serialcon;                                                 %Grab the handle for the serial connection.
ardy.check_serial = @()v1p4_check_serial(serialcon);                        %Set the function for checking the serial connection.
ardy.check_sketch = @()v1p4_check_sketch(serialcon);                        %Set the function for checking that the Ardyardy sketch is running.
ardy.check_version = @()v1p4_simple_return(serialcon,'Z',[]);               %Set the function for returning the version of the MotoTrak sketch running on the Arduino.
ardy.booth = @()v1p4_simple_return(serialcon,'BA',1);                       %Set the function for returning the booth number saved on the Arduino.
ardy.set_booth = @(int)v1p4_long_command(serialcon,'Cnn',[],int);           %Set the function for setting the booth number saved on the Arduino.


%Motor manipulandi functions.
ardy.device = @(i)v1p4_simple_return(serialcon,'DA',1);                     %Set the function for checking which device is connected to an input.
ardy.baseline = @(i)v1p4_simple_return(serialcon,'NA',1);                   %Set the function for reading the loadcell baseline value.
ardy.cal_grams = @(i)v1p4_simple_return(serialcon,'PA',1);                  %Set the function for reading the number of grams a loadcell was calibrated to.
ardy.n_per_cal_grams = @(i)v1p4_simple_return(serialcon,'RA',1);            %Set the function for reading the counts-per-calibrated-grams for a loadcell.
ardy.read_Pull = @(i)v1p4_simple_return(serialcon,'MA',1);                  %Set the function for reading the value on a loadcell.
ardy.set_baseline = ...
    @(int)v1p4_long_command(serialcon,'Onn',[],int);                        %Set the function for setting the loadcell baseline value.
ardy.set_cal_grams = ...
    @(int)v1p4_long_command(serialcon,'Qnn',[],int);                        %Set the function for setting the number of grams a loadcell was calibrated to.
ardy.set_n_per_cal_grams = ...
    @(int)v1p4_long_command(serialcon,'Snn',[],int);                        %Set the function for setting the counts-per-newton for a loadcell.
ardy.trigger_feeder = @(i)v1p4_simple_command(serialcon,'WA',1);            %Set the function for sending a trigger to a feeder.
ardy.trigger_stim = @(i)v1p4_simple_command(serialcon,'XA',1);              %Set the function for sending a trigger to a stimulator.
ardy.stream_enable = @(i)v1p4_simple_command(serialcon,'gi',i);             %Set the function for enabling or disabling the stream.
ardy.set_stream_period = @(int)v1p4_long_command(serialcon,'enn',[],int);   %Set the function for setting the stream period.
ardy.stream_period = @()v1p4_simple_return(serialcon,'f',[]);               %Set the function for checking the current stream period.
ardy.set_stream_ir = @(i)v1p4_simple_command(serialcon,'ci',i);             %Set the function for setting which IR input is read out in the stream.
ardy.stream_ir = @()v1p4_simple_return(serialcon,'d',[]);                   %Set the function for checking the current stream IR input.
ardy.read_stream = @()v1p4_read_stream(serialcon);                          %Set the function for reading values from the stream.
ardy.clear = @()v1p4_clear_stream(serialcon);                               %Set the function for clearing the serial line prior to streaming.
ardy.knob_toggle = @(i)v1p4_simple_command(serialcon, 'Ei', i);             %Set the function for enabling/disabling knob analog input.
ardy.sound_1000 = @(i)v1p4_simple_command(serialcon, '1', []);
ardy.sound_1100 = @(i)v1p4_simple_command(serialcon, '2', []);


%Behavioral control functions.
ardy.play_hitsound = @(i)v1p4_simple_command(serialcon,'J', 1);             %Set the function for playing a hit sound on the Arduino
% ardy.digital_ir = @(i)simple_return(serialcon,'1i',i);                      %Set the function for checking the digital state of the behavioral IR inputs on the Arduino.
% ardy.analog_ir = @(i)simple_return(serialcon,'2i',i);                       %Set the function for checking the analog reading on the behavioral IR inputs on the Arduino.
ardy.feed = @(i)v1p4_simple_command(serialcon,'3A',1);                      %Set the function for triggering food/water delivery.
ardy.feed_dur = @()v1p4_simple_return(serialcon,'4',[]);                    %Set the function for checking the current feeding/water trigger duration on the Arduino.
ardy.set_feed_dur = @(int)v1p4_long_command(serialcon,'5nn',[],int);        %Set the function for setting the feeding/water trigger duration on the Arduino.
ardy.stim = @()v1p4_simple_command(serialcon,'6',[]);                       %Set the function for sending a trigger to the stimulation trigger output.
ardy.stim_off = @()v1p4_simple_command(serialcon,'h',[]);                   %Set the function for immediately shutting off the stimulation output.
ardy.stim_dur = @()v1p4_simple_return(serialcon,'7',[]);                    %Set the function for checking the current stimulation trigger duration on the Arduino.
ardy.set_stim_dur = @(int)v1p4_long_command(serialcon,'8nn',[],int);        %Set the function for setting the stimulation trigger duration on the Arduino.
ardy.lights = @(i)v1p4_simple_command(serialcon,'9i',i);                    %Set the function for turn the overhead cage lights on/off.
ardy.autopositioner = @(int)v1p4_long_command(serialcon,'0nn',[],int);      %Set the function for setting the stimulation trigger duration on the Arduino.


%Behavioral control functions.
ardy.play_hitsound = @(i)v1p4_simple_command(serialcon,'J', 1);             %Set the function for playing a hit sound on the Arduino
% ardy.digital_ir = @(i)simple_return(serialcon,'1i',i);                      %Set the function for checking the digital state of the behavioral IR inputs on the Arduino.
% ardy.analog_ir = @(i)simple_return(serialcon,'2i',i);                       %Set the function for checking the analog reading on the behavioral IR inputs on the Arduino.
ardy.feed = @(i)v1p4_simple_command(serialcon,'3A',1);                      %Set the function for triggering food/water delivery.
ardy.feed_dur = @()v1p4_simple_return(serialcon,'4',[]);                    %Set the function for checking the current feeding/water trigger duration on the Arduino.
ardy.set_feed_dur = @(int)v1p4_long_command(serialcon,'5nn',[],int);        %Set the function for setting the feeding/water trigger duration on the Arduino.
ardy.stim = @()v1p4_simple_command(serialcon,'6',[]);                       %Set the function for sending a trigger to the stimulation trigger output.
ardy.stim_off = @()v1p4_simple_command(serialcon,'h',[]);                   %Set the function for immediately shutting off the stimulation output.
ardy.stim_dur = @()v1p4_simple_return(serialcon,'7',[]);                    %Set the function for checking the current stimulation trigger duration on the Arduino.
ardy.set_stim_dur = @(int)v1p4_long_command(serialcon,'8nn',[],int);        %Set the function for setting the stimulation trigger duration on the Arduino.
ardy.lights = @(i)v1p4_simple_command(serialcon,'9i',i);                    %Set the function for turn the overhead cage lights on/off.
ardy.autopositioner = @(int)v1p4_long_command(serialcon,'0nn',[],int);      %Set the function for setting the stimulation trigger duration on the Arduino.


%% This function checks the status of the serial connection.
function output = v1p4_check_serial(serialcon)
if isa(serialcon,'serial') && isvalid(serialcon) && ...
        strcmpi(get(serialcon,'status'),'open')                             %Check the serial connection...
    output = 1;                                                             %Return an output of one.
    disp(['Serial port ''' serialcon.Port ''' is connected and open.']);    %Show that everything checks out on the command line.
else                                                                        %If the serial connection isn't valid or open.
    output = 0;                                                             %Return an output of zero.
    warning('CONNECT_MOTOTRAK:NonresponsivePort',...
        'The serial port is not responding to status checks!');             %Show a warning.
end


%% This function checks to see if the MotoTrak_V3_0.pde sketch is current running on the Arduino.
function output = v1p4_check_sketch(serialcon)
fwrite(serialcon,'A','uchar');                                              %Send the check status code to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if output == 111                                                            %If the Arduino returned the number 111...
    output = 1;                                                             %...show that the Arduino connection is good.
else                                                                        %Otherwise...
    output = 0;                                                             %...show that the Arduino connection is bad.
end


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function v1p4_simple_command(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function output = v1p4_simple_return(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.


%% This function sends commands with 16-bit integers broken up into 2 characters encoding each byte.
function v1p4_long_command(serialcon,command,i,int)     
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
i = dec2bin(int16(int),16);                                                 %Convert the 16-bit integer to a 16-bit binary string.
byteA = bin2dec(i(1:8));                                                    %Find the character that codes for the first byte.
byteB = bin2dec(i(9:16));                                                   %Find the character that codes for the second byte.
i = strfind(command,'nn');                                                  %Find the spot for the 16-bit integer bytes in the command.
command(i:i+1) = char([byteA, byteB]);                                      %Insert the byte characters into the command.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function reads in the values from the data stream when streaming is enabled.
function output = v1p4_read_stream(serialcon)
timeout = now + 0.05*86400;                                                 %Set the following loop to timeout after 50 milliseconds.
while serialcon.BytesAvailable == 0 && now < timeout                        %Loop until there's a reply on the serial line or there's 
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
output = [];                                                                %Create an empty matrix to hold the serial line reply.
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    try
        streamdata = fscanf(serialcon,'%d')';
        output(end+1,:) = streamdata(1:3);                                  %Read each byte and save it to the output matrix.
    catch err                                                               %If there was a stream read error...
        warning('MOTOTRAK:StreamingError',['MOTOTRAKSTREAM READ '...
            'WARNING: ' err.identifier]);                                   %Show that a stream read error occured.
    end
end


%% This function clears any residual streaming data from the serial line prior to streaming.
function v1p4_clear_stream(serialcon)
tic;                                                                        %Start a timer.
while serialcon.BytesAvailable == 0 && toc < 0.05                           %Loop for 50 milliseconds or until there's a reply on the serial line.
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    fscanf(serialcon,'%d');                                                 %Read each byte and discard it.
end