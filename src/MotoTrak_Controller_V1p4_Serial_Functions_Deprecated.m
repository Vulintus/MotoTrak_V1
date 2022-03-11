function moto = MotoTrak_Controller_V1p4_Serial_Functions_Deprecated(moto)

%MotoTrak_Controller_V1p4_Serial_Functions_Deprecated.m - Vulintus, Inc., 2015
%
%   MotoTrak_Controller_V1p4_Serial_Functions_Deprecated is the deprecated
%   version of MotoTrak_Controller_V2pX_Serial_Functions, which defines and 
%   adds the Arduino serial communication functions to the "moto"
%   structure. These functions are for sketch version 1.4 and earlier, and
%   may not work with newer version (2.0+). This deprecated version is
%   being kept active for the benefit of users running pre-2019b MATLAB.
%
%   UPDATE LOG:
%   05/09/2016 - Drew Sloan - Separated V1.4 serial functions from the
%       Connect_MotoTrak function to allow for loading V2.0 functions.
%   10/13/2016 - Drew Sloan - Added "v1p4_" prefix to all subfunction names
%       to prevent duplicate name errors in collated MotoTrak script.
%   04/25/2018 - Drew Sloan - Shortened the serial port time-out property
%       value from 10 seconds to 2 seconds.
%   04/28/2021 - Drew Sloan - Added a close serial connection function to
%       let the user close the connection through a function on the control 
%       structure.
%   04/28/2021 - Drew Sloan - Deprecated functions copied from
%       MotoTrak_Controller_V1p4_Serial_Functions.
%   11/29/2021 - Drew Sloan - Copied the "booth" function field to a
%       "get_booth" function field for forward compatibility.
%
%

serialcon = moto.serialcon;                                                 %Grab the handle for the serial connection.
serialcon.Timeout = 2;                                                      %Set the timeout for serial read/write operations, in seconds. << Added 4/25/2018
serialcon.UserData = 2;                                                     %Set the default number of inputs. << Added 4/25/2018

%Basic status functions.
moto.check_serial = @()v1p4_check_serial_deprecated(serialcon);             %Set the function for checking the serial connection.
moto.check_sketch = @()v1p4_check_sketch_deprecated(serialcon);             %Set the function for checking that the MotoTrak sketch is running.
moto.check_version = @()v1p4_simple_return_deprecated(serialcon,'Z',[]);    %Set the function for returning the version of the MotoTrak sketch running on the Arduino.
moto.booth = @()v1p4_simple_return_deprecated(serialcon,'BA',1);            %Set the function for returning the booth number saved on the Arduino.
moto.set_booth = ...
    @(int)v1p4_long_command_deprecated(serialcon,'Cnn',[],int);             %Set the function for setting the booth number saved on the Arduino.
moto.close_serialcon = @()v1p4_close_serialcon_deprecated(serialcon);       %Set the function for closing and deleting the serial connection.

%Motor manipulandi functions.
moto.device = @(i)v1p4_simple_return_deprecated(serialcon,'DA',1);          %Set the function for checking which device is connected to an input.
moto.baseline = @(i)v1p4_simple_return_deprecated(serialcon,'NA',1);        %Set the function for reading the loadcell baseline value.
moto.cal_grams = @(i)v1p4_simple_return_deprecated(serialcon,'PA',1);       %Set the function for reading the number of grams a loadcell was calibrated to.
moto.n_per_cal_grams = @(i)v1p4_simple_return_deprecated(serialcon,'RA',1); %Set the function for reading the counts-per-calibrated-grams for a loadcell.
moto.read_Pull = @(i)v1p4_simple_return_deprecated(serialcon,'MA',1);       %Set the function for reading the value on a loadcell.
moto.set_baseline = ...
    @(int)v1p4_long_command_deprecated(serialcon,'Onn',[],int);             %Set the function for setting the loadcell baseline value.
moto.set_cal_grams = ...
    @(int)v1p4_long_command_deprecated(serialcon,'Qnn',[],int);             %Set the function for setting the number of grams a loadcell was calibrated to.
moto.set_n_per_cal_grams = ...
    @(int)v1p4_long_command_deprecated(serialcon,'Snn',[],int);             %Set the function for setting the counts-per-newton for a loadcell.
moto.trigger_feeder = @(i)v1p4_simple_command_deprecated(serialcon,'WA',1); %Set the function for sending a trigger to a feeder.
moto.trigger_stim = @(i)v1p4_simple_command_deprecated(serialcon,'XA',1);   %Set the function for sending a trigger to a stimulator.
moto.stream_enable = @(i)v1p4_simple_command_deprecated(serialcon,'gi',i);  %Set the function for enabling or disabling the stream.
moto.set_stream_period = ...
    @(int)v1p4_long_command_deprecated(serialcon,'enn',[],int);             %Set the function for setting the stream period.
moto.stream_period = @()v1p4_simple_return_deprecated(serialcon,'f',[]);    %Set the function for checking the current stream period.
moto.set_stream_ir = @(i)v1p4_simple_command_deprecated(serialcon,'ci',i);  %Set the function for setting which IR input is read out in the stream.
moto.stream_ir = @()v1p4_simple_return_deprecated(serialcon,'d',[]);        %Set the function for checking the current stream IR input.
moto.read_stream = @()v1p4_read_stream_deprecated(serialcon);               %Set the function for reading values from the stream.
moto.clear = @()v1p4_clear_stream_deprecated(serialcon);                    %Set the function for clearing the serial line prior to streaming.
moto.knob_toggle = @(i)v1p4_simple_command_deprecated(serialcon, 'Ei', i);  %Set the function for enabling/disabling knob analog input.
moto.sound_1000 = @(i)v1p4_simple_command_deprecated(serialcon, '1', []);
moto.sound_1100 = @(i)v1p4_simple_command_deprecated(serialcon, '2', []);
% moto.lever_range = @(i)v1p4_simple_return_deprecated(serialcon,'NA',1);     %Set the function for reading the degree range of a lever.
% moto.set_lever_range = ...
%     @(int)v1p4_long_command_deprecated(serialcon,'Onn',[],int);             %Set the function for setting the degree range of a lever.

%Behavioral control functions.
moto.play_hitsound = @(i)v1p4_simple_command_deprecated(serialcon,'J', 1);  %Set the function for playing a hit sound on the Arduino
% moto.digital_ir = @(i)simple_return(serialcon,'1i',i);                    %Set the function for checking the digital state of the behavioral IR inputs on the Arduino.
% moto.analog_ir = @(i)simple_return(serialcon,'2i',i);                     %Set the function for checking the analog reading on the behavioral IR inputs on the Arduino.
moto.feed = @(i)v1p4_simple_command_deprecated(serialcon,'3A',1);           %Set the function for triggering food/water delivery.
moto.feed_dur = @()v1p4_simple_return_deprecated(serialcon,'4',[]);         %Set the function for checking the current feeding/water trigger duration on the Arduino.
moto.set_feed_dur = ...
    @(int)v1p4_long_command_deprecated(serialcon,'5nn',[],int);             %Set the function for setting the feeding/water trigger duration on the Arduino.
moto.stim = @()v1p4_simple_command_deprecated(serialcon,'6',[]);            %Set the function for sending a trigger to the stimulation trigger output.
moto.stim_off = @()v1p4_simple_command_deprecated(serialcon,'h',[]);        %Set the function for immediately shutting off the stimulation output.
moto.stim_dur = @()v1p4_simple_return_deprecated(serialcon,'7',[]);         %Set the function for checking the current stimulation trigger duration on the Arduino.
moto.set_stim_dur = ...
    @(int)v1p4_long_command_deprecated(serialcon,'8nn',[],int);             %Set the function for setting the stimulation trigger duration on the Arduino.
moto.lights = @(i)v1p4_simple_command_deprecated(serialcon,'9i',i);         %Set the function for turn the overhead cage lights on/off.
moto.autopositioner = ...
    @(int)v1p4_long_command_deprecated(serialcon,'0nn',[],int);             %Set the function for setting the stimulation trigger duration on the Arduino.

%Forward-compatibility functions.
moto.get_booth = @()v1p4_simple_return_deprecated(serialcon,'BA',1);        %Set the function for returning the booth number saved on the Arduino.


%% This function checks the status of the serial connection.
function output = v1p4_check_serial_deprecated(serialcon)
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
function output = v1p4_check_sketch_deprecated(serialcon)
fwrite(serialcon,'A','uchar');                                              %Send the check status code to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
if output == 111                                                            %If the Arduino returned the number 111...
    output = 1;                                                             %...show that the Arduino connection is good.
else                                                                        %Otherwise...
    output = 0;                                                             %...show that the Arduino connection is bad.
end


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function v1p4_simple_command_deprecated(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function output = v1p4_simple_return_deprecated(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.


%% This function sends commands with 16-bit integers broken up into 2 characters encoding each byte.
function v1p4_long_command_deprecated(serialcon,command,i,int)     
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
% i = dec2bin(int16(int),16);                                                 %Convert the 16-bit integer to a 16-bit binary string.
% byteA = bin2dec(i(1:8));                                                    %Find the character that codes for the first byte.
% byteB = bin2dec(i(9:16));                                                   %Find the character that codes for the second byte.
% i = strfind(command,'nn');                                                  %Find the spot for the 16-bit integer bytes in the command.
% command(i:i+1) = char([byteA, byteB]);                                      %Insert the byte characters into the command.
bytes = typecast(int16(int),'uint8');                                       %Typecast the 16-bit integer into two bytes.
i = strfind(command,'nn');                                                  %Find the spot for the 16-bit integer bytes in the command.
command(i:i+1) = char(fliplr(bytes));                                       %Insert the byte characters into the command.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.


%% This function reads in the values from the data stream when streaming is enabled.
function output = v1p4_read_stream_deprecated(serialcon)
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
function v1p4_clear_stream_deprecated(serialcon)
flushinput(serialcon);                                                      %Flush the input buffer.
flushoutput(serialcon);                                                     %Flush the output buffer.


%% This function closes the serial connection and deletes the serial object.
function v1p4_close_serialcon_deprecated(serialcon)
v1p4_clear_stream_deprecated(serialcon);                                               %Clear any data off the serial line.
fclose(serialcon);                                                          %Close the serial connection.
delete(serialcon);                                                          %Delete the serial object.