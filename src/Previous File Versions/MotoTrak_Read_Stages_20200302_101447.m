function handles = MotoTrak_Read_Stages(handles)

%
%MotoTrak_Read_Stages.m - Vulintus, Inc.
%
%   MotoTrak_Read_Stages reads in the stage information for the format
%   (Google Spreadsheet, TSV, or Excel file) specified by the user.
%   
%   UPDATE LOG:
%   09/12/2016 - Drew Sloan - Added default values for optional stage
%       parameters to simplify stage definitions.
%   09/13/2016 - Drew Sloan - Switch out MotoTrak-specific TSV Read/Write
%       functions for generalized versions compatible with OmniTrak.
%   01/09/2017 - Drew Sloan - Added support for ceiling values in stages.
%   12/31/2018 - Drew Sloan - Added special stage parameter handling for
%       the water reaching module.
%

global run                                                                  %Create a global run variable.

num_tones = 10;                                                             %Set the number of tones to make available.

%List the available column headings with stage structure fieldnames and default values.
params = {  'stage number',                             'number',               'required',         [];... 
            'description',                              'description',          'required',         [];...
            'input device',                             'device',               'required',         [];...
            'primary input device',                     'device',               'required',         [];...
            'position',                                 'pos',                  'required',         [];...
            'hit threshold - minimum',                  'threshmin',            'required',         [];...
            '1st input device',                         'device',               'optional',         5;...
            'secondary input device',                   'input2',               'optional',         5;...
            '2nd input device',                         'input2',               'optional',         5;...
            '3rd input device',                         'input3',               'optional',         0;...
            '4th input device',                         'input4',               'optional',         0;...
            '5th input device',                         'input5',               'optional',         0;...
            '6th input device',                         'input6',               'optional',         0;...            
            'constraint',                               'const',                'optional',         0;...            
            'hit threshold - type',                     'threshadapt',          'optional',         'static';...            
            'hit threshold - maximum',                  'threshmax',            'optional',         Inf;...
            'hit threshold - increment',                'threshincr',           'optional',         'special case';...
            'hit threshold - ceiling',                  'ceiling',              'optional',         Inf;... 
            'hit threshold - hold duration',            'hold_dur',             'optional',         NaN;...
            'trial initiation threshold',               'init',                 'required',         [];...
            'threshold units',                          'threshtype',           'optional',         'special case';...
            'ir trial initiation',                      'ir',                   'optional',         'NO';...
            'hit window (s)',                           'hitwin',               'optional',         2;...
            'pre-trial sampling time',                  'pre_trial_sampling',   'optional',         1;...
            'post-trial sampling time',                 'post_trial_sampling',  'optional',         2;...
            'sample period (ms)',                       'period',               'optional',         10;...
            'stimulation',                              'vns',                  'optional',         'OFF';...
            'vns default',                              'vns',                  'optional',         'OFF';...
            'session duration',                         'session_dur',          'optional',         Inf;...
            'force stop',                               'force_stop',           'optional',         'NO';...
            'random feeding - minimum',                 'random_feed_min',      'optional',         [];
            'random feeding - maximum',                 'random_feed_max',      'optional',         []};
        
for i = 1:num_tones                                                         %Step through all of the available tones.
    params(end+1:end+4,:) = ...
        {   sprintf('tone %1.0f frequency',i),      	sprintf('tone_%1.0f_freq',i),       'optional',         1000;...
            sprintf('tone %1.0f duration',i),       	sprintf('tone_%1.0f_dur',i),        'optional',         50;...
            sprintf('tone %1.0f event',i),          	sprintf('tone_%1.0f_event',i),      'optional',         [];... 
            sprintf('tone %1.0f thresh',i),             sprintf('tone_%1.0f_thresh',i),     'optional',         []};  %Add stage parameter for each available tone.
end                                  

inputs = {  'pull',                     1;...
            'knob',                     6;...
            'lever',                    1;...
            'swipe sensor',             5;....
            'touch',                    1;...
            'both',                     1;...
            'capacitive sensor',        4;...
            'water reach',              3};                                 %Match the input devices to their stream input indices.
        
switch handles.stage_mode                                                   %Switch among the stage selection modes.
    case 1                                                                  %If stages are being loaded from a local TSV file.
        stage_file = 'MotoTrak_Stages.tsv';                                 %Set the default stage file name.
        file = [handles.mainpath stage_file];                               %Assume the stage file exists in the main program path.
        if ~exist(file,'file')                                              %If the stage file doesn't exist in the main program path...
            file = which(stage_file);                                       %Look through the entire search path for the stage file.    
        end
        if isempty(file)                                                    %If the stage file wasn't found...
            h = warndlg(['The program couldn''t find the stage '...
                'definition file "MotoTrak_Stages.tsv". Press "OK" to '...
                'manually locate the file.'],...
                'NO STAGE FILE');                                           %Show a warning.
            uiwait(h);                                                      %Wait for the warning dialog to close.
            [file, path] = uigetfile('*.tsv','LOCATE STAGE FILE');          %Have the user locate the file with a dialog box.
            if file(1) == 0                                                 %If the user selected "Cancel"...
                run = 0;                                                    %Set the run variable to 0.
                return                                                      %Skip execution of the rest of the function.
            end
            file = [path file];                                             %Add the directory to the located filename.
            temp = questdlg(['The file "' file '" will be copied to "'...
                handles.mainpath '" and will be renamed to '...
                '"MotoTrak_Stages.tsv" for future use.'],...
                'MOVING STAGE FILE','OK','Cancel','OK');                    %Show an OK/Cancel warning that the file will be moved.
            if isempty(temp) || strcmpi(temp,'cancel')                      %If the user closed the warning or pressed "Cancel"...
                run = 0;                                                    %Set the run variable to 0.
                return                                                      %Skip execution of the rest of the function.
            end
            copyfile(file,[handles.mainpath stage_file],'f');               %Copy the stage file to the main data path with the correct filename.
            delete(file);                                                   %Delete the stage file from it's original location.
        end
        stage_file = [handles.mainpath stage_file];                         %Add the main program path to the stage file name.       
        
        data = Vulintus_Read_TSV_File(stage_file);                          %Read in the data from the TSV file.
        for c = 1:size(data,2)                                              %Step through each column of the data.
            data{1,c}(data{1,c} == '"') = [];                               %Kick out any quotation marks in the column heading.
        end
        
    case 2                                                                  %If stages are being loaded from an online google spreadsheet.
        try                                                                 %Try to read in the stage information from the web.
        	data = Read_Google_Spreadsheet(handles.stage_url);              %Read in the stage information from the Google Docs URL.      
            filename = [handles.mainpath 'Mototrak_Stages.tsv'];            %Set the filename for the stage backup file.
        	Vulintus_Write_TSV_File(data,filename);                         %Back up the stage information to a local TSV file.
        catch err                                                           %If there's an error...
            warning(['Read_Google_Spreadsheet:' err.identifier]',...
                err.message);                                               %Show a warning.
            stage_file = [handles.mainpath 'Mototrak_Stages.tsv'];          %Add the main program path to the stage file name.    
            data = Vulintus_Read_TSV_File(stage_file);                      %Read in the data from the TSV file.
        end
    case 3                                                                  %If stages are being loaded from an Excel spreadsheet.
end

stage = struct([]);                                                         %Create an empty stage structure.
for c = 1:size(data,2)                                                      %Step through each column of the stage information.    
    fname = [];                                                             %Assume, by default, that the column heading won't match any expected field.
    for p = 1:size(params,1)                                                %Step through every recognized parameter.
        if strncmpi(params{p,1},data{1,c},length(params{p,1}))              %If the column heading matches a recognized parameter.
            fname = params{p,2};                                            %Grab the associated field name.
        end
    end
    if isempty(fname)                                                       %If the column heading didn't match any recognized parameter.
        warndlg(['The stage parameters spreadsheet column heading "' ...
            data{1,c} '" doesn''t match any recognized stage parameter.'...
            ' This parameter will be ignored.'],...
            'STAGE PARAMETER NOT RECOGNIZED');                              %Show a warning that the parameter will be ignored.
    else                                                                    %Otherwise...
        for i = 2:size(data,1)                                              %Step through each listed stage.
            temp = data{i,c};                                               %Grab the entry for this stage.
            temp(temp == 39) = [];                                          %Kick out any apostrophes in the entry.
            if any(temp > 59)                                               %If there's any text characters in the entry...
                stage(i-1).(fname) = strtrim(temp);                         %Save the field value as a string.
            else                                                            %Otherwise, if there's no text characters in the entry.
                stage(i-1).(fname) = str2double(temp);                      %Evaluate the entry and save the field value as a number.
            end
        end        
    end
end

keepers = ones(length(stage),1);                                            %Create a matrix to mark stages for exclusion.
for p = 1:size(params,1)                                                    %Now step through each parameter.
    if ~isfield(stage,params{p,2})                                          %If the parameter wasn't found in the stage information...
        if strcmpi(params{p,3},'required')                                  %If the parameter was a required parameter...
            errordlg(sprintf(['The required stage parameter "%s" '...
                'wasn''t found in the stage parameters spreadsheet! '...
                'Correct the stage spreadsheet and restart MotoTrak.'],...
                upper(params{p,1})),'MISSING STAGE PARAMETER');             %Show an error dialog.
            delete(handles.ardy.serialcon);                                 %Close the serial connection with the Arduino.
            close(handles.mainfig);                                         %Close the GUI.
            clear('run');                                                   %Clear the global run variable from the workspace.
            error(['ERROR IN MOTOTRAK_READ_STAGES: Required stage '...
                'parameter "' upper(params{p,1}) '" wasn''t found in '...
                ' the stage parameters spreadsheet!']);                     %Throw an error.
        else                                                                %Otherwise, if the parameter was an optional parameter...
            stage(1).(params{p,2}) = [];                                    %Add the parameter as a new field.
        end
    end
    for i = 1:length(stage)                                                 %Step through each stage.
        if strcmpi(params{p,3},'required') && ...
                any(isnan(stage(i).(params{p,2})))                          %If a required parameter is listed as NaN...
            keepers(i) = 0;                                                 %Mark the stage for exclusion.
        end
    end
end
stage(keepers == 0) = [];                                                   %Kick out any invalid stages.

for p = 1:size(params)                                                      %Now step through each parameter.
    for i = 1:length(stage)                                                 %Step through each stage...
        if (isempty(stage(i).(params{p,2})) || ...
                any(isnan(stage(i).(params{p,2})))) && ...
                ~isempty(params{p,4})                                       %If no parameter value was specified and a default value exists...
            if strcmpi(params{p,4},'special case')                          %If the parameter default value is a special (i.e. conditional) case...
                switch lower(params{p,2})                                   %Switch between the special case parameters.
                    case 'threshtype'                                       %If the parameter is the Threshold Units...
                        switch lower(stage(i).device)                       %Switch between the device types.
                            case 'pull'                                     %For the pull device...
                                stage(i).threshtype = 'grams (peak)';       %Set the default threshold units to peak force.
                            case 'squeeze'                                  %For the squeeze device...
                                stage(i).threshtype = 'grams (max)';        %Set the default threshold units to maximum force.
                            case 'knob'                                     %For the knob device...
                                stage(i).threshtype = 'degrees (total)';    %Set the default threshold units to total degrees.
                            case 'lever'                                    %For the lever device...
                                stage(i).threshtype = 'degrees (total)';    %Set the default threshold units to total degrees.
                            case 'touch'                                    %For the touch sensor...
                                stage(i).threshtype = ...
                                    'milliseconds (hold)';                  %Set the default threshold units to milliseconds holding.
                            case 'both'                                     %For the combined touch/pull device...
                                stage(i).threshtype = 'milliseconds/grams'; %Set the default threshold units to milliseconds holding and peak force.
                            case 'water reach'                              %For the water reach module...
                                stage(i).threshtype = ...
                                    'water reach (shaping)';                %Set the default threshold units to milliseconds holding.
                        end
                    case 'threshincr'                                       %If the parameter is the Hit Threshold Increment...
                        switch lower(stage(i).threshadapt)                  %Switch between the adaptation types.
                            case {'median','50th percentile'}               %For median adaptation...
                                stage(i).threshincr = 20;                   %Set the increment (number of trials to integrate over) to 20.
                            case 'linear'                                   %For linear adaptation...
                                stage(i).threshincr = 0.5;                  %Set the increment (number of units to increase per trial to integrate over) to 0.5.
                        end                        
                end
            else                                                            %Otherwise...
                stage(i).(params{p,2}) = params{p,4};                       %Set the parameter to the default value for this stage.
            end
        end
    end
end

for i = 1:length(stage)                                                     %Step through the stages.    
    stage(i).description = ...
        [stage(i).number ': ' stage(i).description];                        %Add the stage number to the stage description.
    if ~ischar(stage(i).const)                                              %If the listed constraint isn't a character.
        stage(i).const = ['#' num2str(stage(i).const)];                     %Turn the constraint number into a string.
    elseif ~any(stage(i).const == '#') && ...
            ~strcmpi(stage(i).const,'none')                                 %Otherwise, if there's no # sign preceding the constraint number...
        stage(i).const = ['#' stage(i).const];                              %Add a # sign preceding the constraint number.
    end
    if strcmpi(stage(i).const,'#0')                                         %If the listed constraint value is '#0'...
        stage(i).const = 'None';                                            %Set the constraint value to 'None'.
    end
    if stage(i).threshmin < stage(i).init && ...
            ~any(strcmpi(handles.custom,{'machado lab', 'touch/pull'}))     %If the initiation threshold is larger than the minimum hit threshold...
        stage(i).threshmin = stage(i).init;                                 %Set the minimum hit threshold to the initiation threshold.
    end
    if isfield(stage,'ir')                                                  %If an IR trial initiation mode was specified.
        stage(i).ir = strcmpi(stage(i).ir,'YES');                           %Convert the IR trial initiation mode to a binary value.
    end
    if ischar(stage(i).ceiling)                                             %If the threshold ceiling value is a string...
        stage(i).ceiling = NaN;                                             %Set the ceiling value to NaN.
    end
    if ischar(stage(i).post_trial_sampling) || ...
            (stage(i).post_trial_sampling < 0)                              %If the post trial sampling duration is a string or less than zero...
        stage(i).post_trial_sampling = handles.default_post_trial_sampling; %Set the post trial sampling duration to the default value.
    end
    stage(i).tones_enabled = 0;                                             %Assume that no tones will be enabled.
    for t = 1:num_tones                                                     %Step through all tone indices.
        fname = sprintf('tone_%1.0f_event',t);                              %Create the expected field name.
        if ~isempty(stage(i).(fname)) && ~any(isnan(stage(i).(fname)))      %If the user entered a value for at least one tone initiation event...
            stage(i).tones_enabled = 1;                                     %Indicate tones are enabled on the stage.
        end
    end
    stage(i).stream_order = zeros(1,6);                                     %Create a field to hold stream order.
    stage(i).stream_order(1) = ...
        inputs{strcmpi(stage(i).device,inputs(:,1)),2};                     %Set the primary data stream device index.
    for j = 2:6                                                             %Step through the secondary inputs...
        fname = sprintf('input%1.0f',j);                                    %Create the expected field name for the input.
        stage(i).stream_order(j) = stage(i).(fname);                        %Copy each input indice into the stream order field.
    end        
    if any(strcmpi(stage(i).device,{'both','touch'}))                       %If the device is specified as "both" or "touch"...
        stage(i).stream_order(2) = 4;                                       %Make sure the second input is the capacitive sensor.
    end
    if strcmpi(stage(i).device,'water reach')                               %For all water reaching stages...
        stage(i).device = 'water';                                          %Change the device name to simply "Water".
        stage(i).stream_order(2) = 2;                                       %Make sure the second input is the left capacitive sensor.
    end
end

if any(vertcat(stage.tones_enabled) == 1)                                   %If any stage has tones enabled...
    stage(1).tones = [];                                                    %Create a field for tones.
    for i = 1:length(stage)                                                 %Step through the stages.    
        if stage(i).tones_enabled == 1                                      %If tones are enabled for this stage...
            counter = 1;                                                    %Create a counter.
            for t = 1:num_tones                                             %Step through all tone indices.
                fname = sprintf('tone_%1.0f_event',t);                      %Create the expected field name for the tone initiation event.
                if ~isempty(stage(i).(fname)) && ...
                        ~any(isnan(stage(i).(fname)))                       %If the user entered a value for at least one tone initiation event...
                    stage(i).tones(counter).event = stage(i).(fname);       %Copy the tone event initiation type into the stage structure tone field.
                    fname = sprintf('tone_%1.0f_freq',t);                   %Create the expected field name for the tone frequency.
                    stage(i).tones(counter).freq = stage(i).(fname);        %Copy the tone frequency into the stage structure tone field.
                    fname = sprintf('tone_%1.0f_dur',t);                    %Create the expected field name for the tone duration.
                    stage(i).tones(counter).dur = stage(i).(fname);         %Copy the tone frequency into the stage structure tone field.
                    fname = sprintf('tone_%1.0f_thresh',t);                 %Create the expected field name for the tone initiation threshold.
                    stage(i).tones(counter).thresh = stage(i).(fname);      %Copy the tone initiation threshold into the stage structure tone field.
                    counter = counter + 1;                                  %Increment the counter.
                end
            end
        end
    end
end

for t = 1:num_tones                                                         %Step through all tone indices...
    fname = {sprintf('tone_%1.0f_freq',t),...
        sprintf('tone_%1.0f_dur',t),...
        sprintf('tone_%1.0f_event',t)};                                     %Create the list of fields to remove.
    stage = rmfield(stage,fname);                                           %Remove the redundant tone-related field names from the stage structure.
end
for i = 2:6                                                                 %Step through the secondary input fields.
    fname = sprintf('input%1.0f',i);                                        %Create the expected field name for the input.
    stage = rmfield(stage,fname);                                           %Remove the redundant tone-related field names from the stage structure.
end
            
handles.stage = stage;                                                      %Save the stage structure as a field in the handles structure.