function MotoTrak_Write_Pause_Data(fid,trial)

%
%MotoTrak_Write_Pause_Data.m - Vulintus, Inc.
%
%   MOTOTRAK_WRITE_PAUSE_DATA writes any session pause data to the output
%   data file.
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       data write section from MotoTrak_Behavior_Loop.m.
%

fwrite(fid,trial.num,'uint32');                                             %Write the trial number.
fwrite(fid,now,'float64');                                                  %Write the start time of the trial.
fwrite(fid,'V','uint8');                                                    %Write the letter "V" to indicate this is a dummy trial.
fwrite(fid,0,'float32');                                                    %Write a hit window of 0 for this trial.
fwrite(fid,0,'float32');                                                    %Write a trial initiation threshold of 0 for this trial.
fwrite(fid,0,'float32');                                                    %Write a hit threshold of 0 for this trial.
fwrite(fid,0,'uint8');                                                      %Write the number of hits in this trial.
fwrite(fid,length(trial.stim_time),'uint8');                                %Write the number of VNS events in this trial.
for i = 1:length(trial.stim_time)                                           %Step through each of the VNS event times.
    fwrite(fid,trial.stim_time(i),'float64');                               %Write each VNS event time.
end
fwrite(fid,0,'uint32');                                                     %Write a buffer size of 0 for this trial.