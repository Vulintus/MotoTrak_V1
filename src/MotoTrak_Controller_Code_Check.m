function MotoTrak_Controller_Code_Check(varargin)

if nargin == 0                                                              %If there were no input arguments.
    ardy = Connect_MotoTrak;                                                %Connect to the MotoTrak Controller.
else                                                                        %Otherwise...
    ardy = varargin{1};                                                     %Assume the first input argument is the "ardy" function structure.
end

clc;                                                                        %Clear the command line.
cprintf('*blue','MotoTrak_Controller_Code_Check:\n\n');                     %Print the code check header.


%% ardy.trigger_feeder()
cprintf(-[0.01,0.01,0.01],'ardy.trigger_feeder()\n');                       %Print the function field.
N = 3;                                                                      %Set the number of tests to run.
fprintf(1,'\tVerify that the pellet dispenser activates %1.0f times.\n',N); %Print a header for the success rate.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    fprintf(1,'\t\tSending test feed trigger #%1.0f...\n',i);               %Print a line showing the current test trigger number.
    tic;                                                                    %Start a timer.
    ardy.trigger_feeder();                                                  %Send a feeder trigger to the controller.
    times(i) = toc;                                                         %Save the operation time.
    pause(5);                                                               %Pause for 5 seconds.
end
median_time = 1000*median(times);                                           %Calculate the median function execution time.
max_time = 1000*max(times);                                                 %Calculate the maximum function execution time.
min_time = 1000*min(times);                                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.autopositioner()
cprintf(-[0.01,0.01,0.01],'ardy.autopositioner()\n');                       %Print the function field.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
times = nan(5,1);                                                           %Create a matrix to hold operation times.
fprintf(1,'\tVerify that the autopositioner moves 5 times.\n');             %Print a header for the success rate.
fprintf(1,'\t\tResetting autopositioner.\n');                               %Print a header for the success rate.
tic;                                                                        %Start a timer.
ardy.autopositioner(0);                                                     %Reset the autopositioner.
times(1) = toc;                                                             %Save the operation time.
pause(10);                                                                  %Pause for 3 seconds.
fprintf(1,'\t\tMoving to +4 position.\n');                                  %Print a header for the success rate.
tic;                                                                        %Start a timer.
ardy.autopositioner(480 - 400);                                             %Set the autoposioner to +4.
times(2) = toc;                                                             %Save the operation time.
pause(3);                                                                   %Pause for 3 seconds.
fprintf(1,'\t\tMoving to +3 position.\n');                                  %Print a header for the success rate.
tic;                                                                        %Start a timer.
ardy.autopositioner(480 - 300);                                             %Set the autoposioner to +4.
times(3) = toc;                                                             %Save the operation time.
pause(3);                                                                   %Pause for 3 seconds.
fprintf(1,'\t\tMoving to +2 position.\n');                                  %Print a header for the success rate.
tic;                                                                        %Start a timer.
ardy.autopositioner(480 - 200);                                             %Set the autoposioner to +4.
times(4) = toc;                                                             %Save the operation time.
pause(3);                                                                   %Pause for 3 seconds.
fprintf(1,'\t\tMoving to +1 position.\n');                                  %Print a header for the success rate.
tic;                                                                        %Start a timer.
ardy.autopositioner(480 - 100);                                             %Set the autoposioner to +4.
times(5) = toc;                                                             %Save the operation time.
pause(3);                                                                   %Pause for 3 seconds.
median_time = 1000*median(times(:));                                        %Calculate the median function execution time.
max_time = 1000*max(times(:));                                              %Calculate the maximum function execution time.
min_time = 1000*min(times(:));                                              %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.trigger_stim()
cprintf(-[0.01,0.01,0.01],'ardy.trigger_stim()\n');                         %Print the function field.
N = 3;                                                                      %Set the number of tests to run.
fprintf(1,'\tVerify that %1.0f stimulation triggers are sent.\n',N);        %Print a header for the success rate.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    fprintf(1,'\t\tSending test trigger #%1.0f...\n',i);                    %Print a line showing the current test trigger number.
    tic;                                                                    %Start a timer.
    ardy.trigger_stim();                                                    %Send a trigger from the controller.
    times(i) = toc;                                                         %Save the operation time.
    pause(3);                                                               %Pause for 5 seconds.
end
median_time = 1000*median(times);                                           %Calculate the median function execution time.
max_time = 1000*max(times);                                                 %Calculate the maximum function execution time.
min_time = 1000*min(times);                                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.sound_1000()
cprintf(-[0.01,0.01,0.01],'ardy.sound_1000()\n');                           %Print the function field.
N = 3;                                                                      %Set the number of tests to run.
fprintf(1,'\tVerify that %1.0f 1000 Hz tones are heard.\n',N);              %Print a header for the success rate.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    fprintf(1,'\t\tPlaying tone #%1.0f...\n',i);                            %Print a line showing the current test trigger number.
    tic;                                                                    %Start a timer.
    ardy.sound_1000();                                                      %Send a trigger from the controller.
    times(i) = toc;                                                         %Save the operation time.
    pause(1);                                                               %Pause for 1 second.
end
median_time = 1000*median(times);                                           %Calculate the median function execution time.
max_time = 1000*max(times);                                                 %Calculate the maximum function execution time.
min_time = 1000*min(times);                                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.sound_1100()
cprintf(-[0.01,0.01,0.01],'ardy.sound_1100()\n');                           %Print the function field.
N = 3;                                                                      %Set the number of tests to run.
fprintf(1,'\tVerify that %1.0f 1100 Hz tones are heard.\n',N);              %Print a header for the success rate.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    fprintf(1,'\t\tPlaying tone #%1.0f...\n',i);                            %Print a line showing the current test trigger number.
    tic;                                                                    %Start a timer.
    ardy.sound_1100();                                                      %Send a trigger from the controller.
    times(i) = toc;                                                         %Save the operation time.
    pause(1);                                                               %Pause for 1 seconds.
end
median_time = 1000*median(times);                                           %Calculate the median function execution time.
max_time = 1000*max(times);                                                 %Calculate the maximum function execution time.
min_time = 1000*min(times);                                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.play_hitsound()
cprintf(-[0.01,0.01,0.01],'ardy.play_hitsound()\n');                        %Print the function field.
N = 3;                                                                      %Set the number of tests to run.
fprintf(1,'\tVerify that %1.0f hit sound tones are heard.\n',N);            %Print a header for the success rate.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    fprintf(1,'\t\tPlaying tone #%1.0f...\n',i);                            %Print a line showing the current test trigger number.
    tic;                                                                    %Start a timer.
    ardy.play_hitsound();                                                   %Send a trigger from the controller.
    times(i) = toc;                                                         %Save the operation time.
    pause(1);                                                               %Pause for 1 seconds.
end
median_time = 1000*median(times);                                           %Calculate the median function execution time.
max_time = 1000*max(times);                                                 %Calculate the maximum function execution time.
min_time = 1000*min(times);                                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.feed()
cprintf(-[0.01,0.01,0.01],'ardy.feed()\n');                                 %Print the function field.
N = 3;                                                                      %Set the number of tests to run.
fprintf(1,'\tVerify that the pellet dispenser activates %1.0f times.\n',N); %Print a header for the success rate.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    fprintf(1,'\t\tSending test feed trigger #%1.0f...\n',i);               %Print a line showing the current test trigger number.
    tic;                                                                    %Start a timer.
    ardy.feed();                                                            %Send a feeder trigger to the controller.
    times(i) = toc;                                                         %Save the operation time.
    pause(5);                                                               %Pause for 5 seconds.
end
median_time = 1000*median(times);                                           %Calculate the median function execution time.
max_time = 1000*max(times);                                                 %Calculate the maximum function execution time.
min_time = 1000*min(times);                                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.lights()
cprintf(-[0.01,0.01,0.01],'ardy.lights()\n');                               %Print the function field.
N = 3;                                                                      %Set the number of tests to run.
fprintf(1,'\tVerify that the cage lights turn on %1.0f times.\n',N);        %Print a header for the success rate.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
ardy.lights(0);                                                             %Turn the cage lights off.
times = nan(N,2);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    pause(1);                                                               %Pause for 1 second.
    tic;                                                                    %Start a timer.
    fprintf(1,'\t\tTest #%1.0f: Cage lights on... ',i);                     %Print a line showing the current test trigger number.
    ardy.lights(1);                                                         %Turn the cage lights on.
    times(i,1) = toc;                                                       %Save the operation time.
    pause(1);                                                               %Pause for 1 second.
    fprintf(1,'\t\tCage lights off...\n');                                  %Print a line showing the current test trigger number.
    tic;                                                                    %Start a timer.
    ardy.lights(0);                                                         %Turn the cage lights off.
    times(i,2) = toc;                                                       %Save the operation time.
end
median_time = 1000*median(times(:));                                        %Calculate the median function execution time.
max_time = 1000*max(times(:));                                              %Calculate the maximum function execution time.
min_time = 1000*min(times(:));                                              %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.check_version()
cprintf(-[0.01,0.01,0.01],'ardy.check_version()\n');                        %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    tic;                                                                    %Start a timer.
    temp = ardy.check_version();                                            %Fetch the sketch version from the controller.
    times(i) = toc;                                                         %Save the operation time.
    if isempty(temp)                                                        %If no sketch version was returned...
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful retrievals (N = %1.0f):',N);                        %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials));                           %Calculate the median function execution time.
max_time = 1000*max(times(success_trials));                                 %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials));                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.booth() / ardy.set_booth()
cprintf(-[0.01,0.01,0.01],'ardy.booth() / ardy.set_booth()\n');             %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,2);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    rand_int16 = round(32767*rand);                                        %Fetch a random booth number.
    tic;                                                                    %Start a timer.
    ardy.set_booth(rand_int16);                                            %Set the booth number on the controller.
    times(i,1) = toc;                                                       %Save the operation time.
    tic;                                                                    %Start a timer.
    temp = ardy.booth();                                                    %Fetch the booth number from the controller.
    times(i,2) = toc;                                                       %Save the operation time.
    if isempty(temp)                                                        %If no booth number was returned...        
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    elseif temp ~= rand_int16                                              %If the booth number doesn't match what was sent...
        checker(i) = 0;                                                     %Mark the test as a failure.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful settings/retrievals (N = %1.0f):',N);               %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials,1));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,1));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,1));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (set_booth): %1.2f ms\n',median_time);    %Print the median function execution time.
fprintf(1,'\tMax. function time (set_booth): %1.2f ms\n',max_time);         %Print the maximum function execution time.
fprintf(1,'\tMin. function time (set_booth): %1.2f ms\n',min_time);         %Print the minimum function execution time.
median_time = 1000*median(times(success_trials,2));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,2));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,2));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (booth): %1.2f ms\n',median_time);        %Print the median function execution time.
fprintf(1,'\tMax. function time (booth): %1.2f ms\n',max_time);             %Print the maximum function execution time.
fprintf(1,'\tMin. function time (booth): %1.2f ms\n',min_time);             %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.
    

%% ardy.device()
cprintf(-[0.01,0.01,0.01],'ardy.device()\n');                               %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    tic;                                                                    %Start a timer.
    temp = ardy.device();                                                   %Fetch the device identifier from the controller.
    times(i) = toc;                                                         %Save the operation time.
    if isempty(temp)                                                        %If no sketch version was returned...
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful retrievals (N = %1.0f):',N);                        %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials));                           %Calculate the median function execution time.
max_time = 1000*max(times(success_trials));                                 %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials));                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.baseline() / ardy.set_baseline()
cprintf(-[0.01,0.01,0.01],'ardy.baseline() / ardy.set_baseline()\n');       %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,2);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    rand_int16 = round(32767*rand);                                        %Fetch a random booth number.
    tic;                                                                    %Start a timer.
    ardy.set_baseline(rand_int16);                                         %Set the baseline on the controller.
    times(i,1) = toc;                                                       %Save the operation time.
    tic;                                                                    %Start a timer.
    temp = ardy.baseline();                                                 %Fetch the booth number from the controller.
    times(i,2) = toc;                                                       %Save the operation time.
    if isempty(temp)                                                        %If no booth number was returned...        
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    elseif temp ~= rand_int16                                              %If the booth number doesn't match what was sent...
        checker(i) = 0;                                                     %Mark the test as a failure.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful settings/retrievals (N = %1.0f):',N);               %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials,1));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,1));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,1));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (set_baseline): %1.2f ms\n',median_time); %Print the median function execution time.
fprintf(1,'\tMax. function time (set_baseline): %1.2f ms\n',max_time);      %Print the maximum function execution time.
fprintf(1,'\tMin. function time (set_baseline): %1.2f ms\n',min_time);      %Print the minimum function execution time.
median_time = 1000*median(times(success_trials,2));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,2));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,2));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (baseline): %1.2f ms\n',median_time);     %Print the median function execution time.
fprintf(1,'\tMax. function time (baseline): %1.2f ms\n',max_time);          %Print the maximum function execution time.
fprintf(1,'\tMin. function time (baseline): %1.2f ms\n',min_time);          %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.cal_grams() / ardy.set_cal_grams()
cprintf(-[0.01,0.01,0.01],'ardy.cal_grams() / ardy.set_cal_grams()\n');     %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,2);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    rand_int16 = round(32767*rand);                                        %Fetch a random booth number.
    tic;                                                                    %Start a timer.
    ardy.set_cal_grams(rand_int16);                                        %Set the baseline on the controller.
    times(i,1) = toc;                                                       %Save the operation time.
    tic;                                                                    %Start a timer.
    temp = ardy.cal_grams();                                                %Fetch the booth number from the controller.
    times(i,2) = toc;                                                       %Save the operation time.
    if isempty(temp)                                                        %If no booth number was returned...        
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    elseif temp ~= rand_int16                                              %If the booth number doesn't match what was sent...
        checker(i) = 0;                                                     %Mark the test as a failure.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful settings/retrievals (N = %1.0f):',N);               %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials,1));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,1));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,1));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (set_cal_grams): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (set_cal_grams): %1.2f ms\n',max_time);     %Print the maximum function execution time.
fprintf(1,'\tMin. function time (set_cal_grams): %1.2f ms\n',min_time);     %Print the minimum function execution time.
median_time = 1000*median(times(success_trials,2));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,2));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,2));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (cal_grams): %1.2f ms\n',median_time);    %Print the median function execution time.
fprintf(1,'\tMax. function time (cal_grams): %1.2f ms\n',max_time);         %Print the maximum function execution time.
fprintf(1,'\tMin. function time (cal_grams): %1.2f ms\n',min_time);         %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.n_per_cal_grams() / ardy.set_n_per_cal_grams()
cprintf(-[0.01,0.01,0.01],...
    'ardy.n_per_cal_grams() / ardy.set_n_per_cal_grams()\n');               %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,2);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    rand_int16 = round(32767*rand);                                         %Fetch a random booth number.
    tic;                                                                    %Start a timer.
    ardy.set_n_per_cal_grams(rand_int16);                                   %Set the baseline on the controller.
    times(i,1) = toc;                                                       %Save the operation time.
    tic;                                                                    %Start a timer.
    temp = ardy.n_per_cal_grams();                                          %Fetch the booth number from the controller.
    times(i,2) = toc;                                                       %Save the operation time.
    if isempty(temp)                                                        %If no booth number was returned...        
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    elseif temp ~= rand_int16                                               %If the booth number doesn't match what was sent...
        checker(i) = 0;                                                     %Mark the test as a failure.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful settings/retrievals (N = %1.0f):',N);               %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials,1));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,1));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,1));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (set_n_per_cal_grams): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (set_n_per_cal_grams): %1.2f ms\n',...
    max_time);                                                              %Print the maximum function execution time.
fprintf(1,'\tMin. function time (set_n_per_cal_grams): %1.2f ms\n',...
    min_time);                                                              %Print the minimum function execution time.
median_time = 1000*median(times(success_trials,2));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,2));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,2));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (n_per_cal_grams): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (n_per_cal_grams): %1.2f ms\n',max_time);   %Print the maximum function execution time.
fprintf(1,'\tMin. function time (n_per_cal_grams): %1.2f ms\n',min_time);   %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.read_Pull()
cprintf(-[0.01,0.01,0.01],'ardy.read_Pull()\n');                            %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,1);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    tic;                                                                    %Start a timer.
    temp = ardy.read_Pull();                                                %Fetch the device identifier from the controller.
    times(i) = toc;                                                         %Save the operation time.
    if isempty(temp)                                                        %If no sketch version was returned...
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful settings/retrievals (N = %1.0f):',N);               %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials));                           %Calculate the median function execution time.
max_time = 1000*max(times(success_trials));                                 %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials));                                 %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time: %1.2f ms\n',median_time);                %Print the median function execution time.
fprintf(1,'\tMax. function time: %1.2f ms\n',max_time);                     %Print the maximum function execution time.
fprintf(1,'\tMin. function time: %1.2f ms\n',min_time);                     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.feed_dur() / ardy.set_feed_dur()
cprintf(-[0.01,0.01,0.01],'ardy.feed_dur() / ardy.set_feed_dur()\n');       %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,2);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    rand_int16 = round(32767*rand);                                         %Fetch a random booth number.
    tic;                                                                    %Start a timer.
    ardy.set_feed_dur(rand_int16);                                          %Set the baseline on the controller.
    times(i,1) = toc;                                                       %Save the operation time.
    tic;                                                                    %Start a timer.
    temp = ardy.feed_dur();                                                 %Fetch the booth number from the controller.
    times(i,2) = toc;                                                       %Save the operation time.
    if isempty(temp)                                                        %If no booth number was returned...        
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    elseif temp ~= rand_int16                                               %If the booth number doesn't match what was sent...
        checker(i) = 0;                                                     %Mark the test as a failure.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful settings/retrievals (N = %1.0f):',N);               %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials,1));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,1));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,1));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (set_feed_dur): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (set_feed_dur): %1.2f ms\n',...
    max_time);                                                              %Print the maximum function execution time.
fprintf(1,'\tMin. function time (set_feed_dur): %1.2f ms\n',...
    min_time);                                                              %Print the minimum function execution time.
median_time = 1000*median(times(success_trials,2));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,2));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,2));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (feed_dur): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (feed_dur): %1.2f ms\n',max_time);          %Print the maximum function execution time.
fprintf(1,'\tMin. function time (feed_dur): %1.2f ms\n',min_time);          %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.stim_dur() / ardy.set_stim_dur()
cprintf(-[0.01,0.01,0.01],'ardy.stim_dur() / ardy.set_stim_dur()\n');       %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,2);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    rand_int16 = round(32767*rand);                                         %Fetch a random booth number.
    tic;                                                                    %Start a timer.
    ardy.set_stim_dur(rand_int16);                                          %Set the baseline on the controller.
    times(i,1) = toc;                                                       %Save the operation time.
    tic;                                                                    %Start a timer.
    temp = ardy.stim_dur();                                                 %Fetch the booth number from the controller.
    times(i,2) = toc;                                                       %Save the operation time.
    if isempty(temp)                                                        %If no booth number was returned...        
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    elseif temp ~= rand_int16                                               %If the booth number doesn't match what was sent...
        checker(i) = 0;                                                     %Mark the test as a failure.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = (checker == 1);                                            %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful settings/retrievals (N = %1.0f):',N);               %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials,1));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,1));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,1));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (set_stim_dur): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (set_stim_dur): %1.2f ms\n',...
    max_time);                                                              %Print the maximum function execution time.
fprintf(1,'\tMin. function time (set_stim_dur): %1.2f ms\n',...
    min_time);                                                              %Print the minimum function execution time.
median_time = 1000*median(times(success_trials,2));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,2));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,2));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (stim_dur): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (stim_dur): %1.2f ms\n',max_time);          %Print the maximum function execution time.
fprintf(1,'\tMin. function time (stim_dur): %1.2f ms\n',min_time);          %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.stream_period() / ardy.set_stream_period()
cprintf(-[0.01,0.01,0.01],...
    'ardy.stream_period() / ardy.set_stream_period()\n');                   %Print the function field.
N = 1000;                                                                   %Set the number of tests to run.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.
checker = nan(N,1);                                                         %Create a matrix to hold each test result.
times = nan(N,2);                                                           %Create a matrix to hold operation times.
for i = 1:N                                                                 %Step through the tests.
    rand_int16 = round(32767*rand);                                         %Fetch a random booth number.
    tic;                                                                    %Start a timer.
    ardy.set_stream_period(rand_int16);                                     %Set the baseline on the controller.
    times(i,1) = toc;                                                       %Save the operation time.
    tic;                                                                    %Start a timer.
    temp = ardy.stream_period();                                            %Fetch the booth number from the controller.
    times(i,2) = toc;                                                       %Save the operation time.
    if isempty(temp)                                                        %If no booth number was returned...        
        pause(0.2);                                                         %Pause for 200 milliseconds.
        ardy.clear();                                                       %Clear any remaining bytes on the serial line.
    elseif temp ~= rand_int16                                               %If the booth number doesn't match what was sent...
        checker(i) = 0;                                                     %Mark the test as a failure.
    else                                                                    %Otherwise...
        checker(i) = 1;                                                     %Mark the test as successful.
    end
end
success_trials = ~isnan(checker);                                           %Find the indices for all successful trials.
success_rate = 100*mean(success_trials);                                    %Calculate the success rate.
fprintf(1,'\tSuccessful settings/retrievals (N = %1.0f):',N);               %Print a header for the success rate.
fprintf(1,' ');                                                             %Print a space.
if success_rate == 100                                                      %If the success rate is 100%...
    cprintf([0 0.5 0],'%1.2f%%\n',success_rate);                            %Print the success rate in green.
else                                                                        %Otherwise...
    cprintf([1 0.5 0.5],'%1.2f%%\n',success_rate);                          %Print the success rate in bold red.
end
median_time = 1000*median(times(success_trials,1));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,1));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,1));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (set_stream_period): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (set_stream_period): %1.2f ms\n',...
    max_time);                                                              %Print the maximum function execution time.
fprintf(1,'\tMin. function time (set_stream_period): %1.2f ms\n',...
    min_time);                                                              %Print the minimum function execution time.
median_time = 1000*median(times(success_trials,2));                         %Calculate the median function execution time.
max_time = 1000*max(times(success_trials,2));                               %Calculate the maximum function execution time.
min_time = 1000*min(times(success_trials,2));                               %Calculate the minimum function execution time.
fprintf(1,'\tMedian function time (stream_period): %1.2f ms\n',...
    median_time);                                                           %Print the median function execution time.
fprintf(1,'\tMax. function time (stream_period): %1.2f ms\n',max_time);     %Print the maximum function execution time.
fprintf(1,'\tMin. function time (stream_period): %1.2f ms\n',min_time);     %Print the minimum function execution time.
fprintf(1,'\n');                                                            %Print a carriage return.


%% ardy.stream_enable() / ardy.read_stream()
cprintf(-[0.01,0.01,0.01],'ardy.stream_enable() / ardy.stream_enable()\n'); %Print the function field.
data = nan(15000,3);                                                        %Pre-allocate a matrix to hold the stream samples.
for fs = 100:100:500                                                        %Step through test sampling rates.
    data(:) = NaN;                                                          %Reset all the samples to NaNs.
    fprintf(1,'\tTesting %1.0f Hz sampling:\n',fs);                         %Print the tested sampling rate.
    ardy.set_stream_period(1000/fs);                                        %Set the stream period.
    pause(0.1);                                                             %Pause for 100 milliseconds.
    ardy.clear();                                                           %Clear any remaining bytes on the serial line.
    pause(0.1);                                                             %Pause for 100 milliseconds.
    ardy.stream_enable(1);                                                  %Enable periodic streaming on the Arduino.   
    test_time = now + 5/86400;                                              %Stream for 10 seconds.
    i = 0;                                                                  %Reset the sample counter.
    while now < test_time                                                   %Loop for the test duration.
        temp = ardy.read_stream();                                          %Read in any new stream output.          
        a = size(temp,1);                                                   %Find the number of new samples.
        if a > 0                                                            %If there was any new data in the stream.    
            data(i+1:i+a,:) = temp;                                         %Copy the new data to the buffer.
            i = i + a;                                                      %Increment the sample counter.
        end       
        pause(0.001);                                                       %Pause for 1 millisecond.
    end
    ardy.stream_enable(0);                                                  %Disable periodic streaming on the Arduino.
    fprintf(1,'\t\tSamples received: %1.0f\n',i);                           %Print the number of samples received.
    times = diff(data(1:i,1));                                              %Grab the times between samples.
    fprintf(1,'\t\tMedian sampling period: %1.0f us\n',median(times));      %Print the median sampling period.
    fprintf(1,'\t\tMax. sampling period: %1.0f us\n',max(times));           %Print the median sampling period.
    fprintf(1,'\t\tMin. sampling period: %1.0f us\n',median(times));        %Print the median sampling period.
    fprintf(1,'\t\tEffective sampling rate: %1.2f Hz\n',...
        1000000/mean(times));                                               %Print the effective sampling rate.
end
pause(0.1);                                                                 %Pause for 100 milliseconds.
ardy.clear();                                                               %Clear any remaining bytes on the serial line.