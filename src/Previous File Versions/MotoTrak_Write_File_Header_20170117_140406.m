function fid = MotoTrak_Write_File_Header(handles)

%This function writes the file header for session data files.
%   This function runs in the background to display the streaming input
%   signals from MotoTrak while a session is not running.
%   
%   UPDATE LOG:
%   01/09/2017 - Drew Sloan - Added an if statement to create version -4
%       data files for stages with a ceiling enabled.
%

if ~exist(handles.datapath,'dir')                                           %If the main data folder doesn't already exist on the C:\ drive...
    mkdir(handles.datapath);                                                %Create the main data folder on the C:\ drive.
end
filename = [handles.datapath handles.ratname '\'];                          %Make the folder name for this rat.
if ~exist(filename,'dir')                                                   %If a folder doesn't already exist for this rat.
    mkdir(filename);                                                        %Make the rat folder.
end
filename = [filename handles.ratname '-' 'Stage' ...
    handles.stage(handles.cur_stage).number '\'];                           %Make a folder name for the current stage in this rat's folder.
if ~exist(filename,'dir')                                                   %If the stage folder doesn't already exist for this rat.
    mkdir(filename);                                                        %Make the stage folder.
end
temp = datestr(now,30);                                                     %Grab a timestamp accurate to the second.
if handles.vns == 0                                                         %If we're not stimulating...      
    stim = 'NoVNS';                                                         %Show that there's no VNS in the filename.
elseif handles.vns == 1                                                     %If we're stimulating normally...
    stim = 'VNS';                                                           %Show that there's VNS in the filename.
elseif handles.vns == 2                                                     %If we're randomly stimulating...
    stim = 'RandomVNS';                                                     %Show that there's random stimulation in the filename.
elseif handles.vns == 3
    stim = 'BurstVNS';
end
temp = [handles.ratname...                                                  %(Rat name)
    '_' temp...                                                             %(Timestamp)
    '_Stage' handles.stage(handles.cur_stage).number...                     %(Stage title)
    '_' handles.device...                            %(Device)
    '_' stim...                                                             %(VNS on or off)
    '.ArdyMotor' ];                                                         %Create the filename, including the full pathandles.
Add_Msg(handles.msgbox,[datestr(now,13) ' - Session data file: ' ...
	temp '.']);                                                             %Show the user the session data file name.
filename = [filename temp];                                                 %Add the path to the filename.
[fid, errmsg] = fopen(filename,'w');                                        %Open the data file as a binary file for writing.
if fid == -1                                                                %If the file could not be created...
    errordlg(sprintf(['Could not create the session data file '...
        'at:\n\n%s\n\nError:\n\n%s'],filename,...
        errmsg),'MotoTrak File Write Error');                               %Show an error dialog box.
end
if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                        %If a ceiling was specified for this stage...
    fwrite(fid,-4,'int8');                                                  %Write the data file version number.
else                                                                        %Otherwise, if there is no ceiling...
    fwrite(fid,-3,'int8');                                                  %Write the data file version number.
end
fwrite(fid,daycode,'uint16');                                               %Write the DayCode.
fwrite(fid,handles.booth,'uint8');                                          %Write the booth number.
fwrite(fid,length(handles.ratname),'uint8');                                %Write the number of characters in the rat's name.
fwrite(fid,handles.ratname,'uchar');                                        %Write the characters of the rat's name.
fwrite(fid,handles.position,'float32');                                     %Write the position of the input device (in centimeters).
fwrite(fid,length(handles.stage(handles.cur_stage).description),'uint8');   %Write the number of characters in the stage description.
fwrite(fid,handles.stage(handles.cur_stage).description,'uchar');           %Write the characters of the stage description.
fwrite(fid,length(handles.device),'uint8');                                 %Write the number of characters in the device description.
fwrite(fid,handles.device,'uchar');                                         %Write the characters of the device description.
if any(strcmpi(handles.device,{'pull', 'lever','knob'}))                    %If the input device for this stage is the pull, lever, or knob
    fwrite(fid,handles.slope,'float32');                                    %Write the slope of the calibration equation y = m*(x - b).
    fwrite(fid,handles.baseline,'float32');                                 %Write the baseline of the calibration equation y = m*(x - b).
elseif any(strcmpi(handles.device,{'wheel'}))                               %If the input device for this stage is the wheel...
    fwrite(fid,handles.slope,'float32');                                    %Write the number of degrees per tick for the rotary encoder.
end
fwrite(fid,length(handles.cur_const),'uint8');                              %Write the number of characters in the constraint description.
fwrite(fid,handles.cur_const,'uchar');                                      %Write the characters of the constraint description.
fwrite(fid,length(handles.curthreshtype),'uint8');                         %Write the number of characters in the threshold units.
fwrite(fid,handles.curthreshtype,'uchar');                                 %Write the characters of the threshold units.