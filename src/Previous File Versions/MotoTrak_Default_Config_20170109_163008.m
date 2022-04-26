function handles = MotoTrak_Default_Config(handles)

%
%MotoTrak_Default_Config.m - Vulintus, Inc.
%
%   MotoTrak_Default_Config sets the default values of all program
%   parameters when MotoTrak is launched.
%   
%   UPDATE LOG:
%   10/12/2016 - Drew Sloan - Added a default recipient for automatic error
%       reporting through email.
%

handles.custom = 'none';                                                    %Set the customization field to 'none' by default.
handles.stage_mode = 2;                                                     %Set the default stage selection mode to 2 (1 = local TSV file, 2 = Google Spreadsheet).
handles.stage_url = ['https://docs.google.com/spreadsheets/d/1Iii9Z'...
    'pXjJIm3z1xA1R9iSh3Vkjp00erUD8g6KPU_0Uk/pub?output=tsv'];               %Set the google spreadsheet address.
handles.vns = 0;                                                            %Disable VNS by default.
handles.pre_trial_sampling = 1;                                             %Set the pre-trial sampling period, in seconds.
handles.post_trial_sampling = 2;                                            %Set the post-trial sampling period, in seconds.
handles.positioner_offset = 48;                                             %Set the zero position offset of the autopositioner, in millimeters.
handles.datapath = 'C:\MotoTrak\';                                          %Set the primary local data path for saving data files.
handles.ratname = [];                                                       %Create a field to hold the rat's name.
handles.sound_stages = [];                                                  %Create a field for marking stages with beeps.
handles.enable_error_reporting = 1;                                         %Enable automatic error reports by default.
handles.err_rcpt = 'drew@vulintus.com';                                     %Automatically send any error reports to Drew Sloan.
handles.ir_initiation_threshold = 0.20;                                     %Set the IR initiation threshold, as a proportion of the total range.