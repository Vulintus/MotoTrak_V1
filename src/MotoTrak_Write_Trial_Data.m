function MotoTrak_Write_Trial_Data(fid,handles,trial)

%
%MotoTrak_Write_Trial_Data.m - Vulintus, Inc.
%
%   MOTOTRAK_WRITE_TRIAL_DATA writes the data for one trial to a MotoTrak
%   data file.
%   
%   UPDATE LOG:
%   05/01/2015 - Drew Sloan - Function first implemented, cutting existing
%       data write section from MotoTrak_Behavior_Loop.m.
%

fwrite(fid,trial.num,'uint32');                                             %Write the trial number.
fwrite(fid,trial.start(1),'float64');                                       %Write the start time of the trial.
fwrite(fid,trial.score(1),'uint8');                                         %Write the first letter of 'HIT' or 'MISS' as the outcome.
fwrite(fid,handles.hitwin,'float32');                                       %Write the hit window for this trial.
fwrite(fid,handles.init,'float32');                                         %Write the trial initiation threshold for reward for this trial.
fwrite(fid,trial.thresh,'float32');                                         %Write the hit threshold for reward for this trial.
if ~isnan(handles.ceiling) && handles.ceiling ~= Inf                        %If there's a force ceiling.
    fwrite(fid,handles.ceiling,'float32');                                  %Write the force ceiling for this trial.
end
fwrite(fid,length(trial.hit_time),'uint8');                                 %Write the number of hits in this trial.
for i = 1:length(trial.hit_time)                                            %Step through each of the hit/reward times.
    fwrite(fid,trial.hit_time(i),'float64');                                %Write each hit/reward time.
end
fwrite(fid,length(trial.stim_time),'uint8');                                %Write the number of VNS events in this trial.
for i = 1:length(trial.stim_time)                                           %Step through each of the VNS event times.
    fwrite(fid,trial.stim_time(i),'float64');                               %Write each VNS event time.
end            
fwrite(fid,trial.buffsize,'uint32');                                        %Write the number of samples in the trial data signal.
fwrite(fid,trial.data(1:trial.buffsize,1)/1000,'int16');                    %Write the millisecond timestamps for all datapoints.
fwrite(fid,trial.data(1:trial.buffsize,2),'float32');                       %Write all device signal datapoints.
fwrite(fid,trial.data(1:trial.buffsize,3),'int16');                         %Write all IR signal datapoints.