function MotoTrak_Send_Error_Report(handles,target,msg)

%
%MotoTrak_Send_Error_Report.m - Vulintus, Inc.
%
%   MotoTrak_Send_Error_Report sends an error report ("msg") by email to 
%   the specified recipient ("target") through the Vulintus dummy 
%   error-reporting account.
%   
%   UPDATE LOG:
%   10/12/2016 - Drew Sloan - First function implementation.
%   10/13/2016 - Drew Sloan - Added support for general string and cell
%       array message inputs instead of just MException objects.
%

if handles.enable_error_reporting == 0                                      %If remote error reporting is disabled...
    return                                                                  %Skip execution of the rest of the function.
end
if isa(msg,'MException')                                                    %If the message to send is an error exception...
    txt = getReport(msg,'extended');                                        %Get an extended report about the error.
    a = strfind(txt,'<a');                                                  %Find all hyperlink starts in the text.
    for i = length(a):-1:1                                                  %Step backwards through all hyperlink commands.
        j = find(txt(a(i):end) == '>',1,'first') + a(i) - 1;                %Find the end of the hyperlink start.
        txt(a(i):j) = [];                                                   %Kick out all hyperlink calls.
    end
    a = strfind(txt,'a>') + 1;                                              %Find all hyperlink ends in the text.
    for i = length(a):-1:1                                                  %Step backwards through all hyperlink commands.
        j = find(txt(1:a(i)) == '<',1,'last');                              %Find the end of the hyperlink end.
        txt(j:a(i)) = [];                                                   %Kick out all hyperlink calls.
    end
else                                                                        %Otherwise, if the message to send isn't an error exception...
    if iscell(msg)                                                          %If the message text is a cell array of strings.
        txt = sprintf('%s\n',msg{:});                                       %Convert the cell array to a continuous string.
    elseif ischar(msg)                                                      %Otherwise, if the message text is already a string...
        txt = msg;                                                          %Send the message text as-is.
    else                                                                    %Otherwise, for all other messages...
        return                                                              %Skip execution of the rest of the function.
    end    
end
if isfield(handles,'variant')                                               %If this is a custom variant...
    source = upper(handles.variant);                                        %Set the source to the known variant.
else                                                                        %Otherwise...
    [~,source] = system('hostname');                                        %Use the computer hostname as the source.
end
subject = sprintf('MotoTrak Error Report From %s', source);                 %Create a subject line.
subject(subject < 32) = [];                                                 %Kick out all special characters from the subject line.
if isdeployed                                                               %If this is deployed code...
    [~, result] = system('path');                                           %Grab the current environmental path variable.
    path = char(regexpi(result, 'Path=(.*?);', 'tokens', 'once'));          %Find the directory pertaining to the current compiled program.
    program = [path '\subfuns\vulintus_send_error_report.exe'];             %Add the full path to the error-reporting program name.    
    cmd = sprintf('"%s" "%s" "%s" "%s"',program,target,subject,txt);        %Create a command-line call for the error-reporting program.
    fprintf(1,'Reporting MotoTrak error to %s\n',target);                   %Show that the error reporting program is being run on the command line.
    [~, cmdout] = system(cmd);                                              %Call the error reporting program.
    fprintf(1,'\t%s\n',cmdout);                                             %Return any reply to the command line.
else                                                                        %Otherwise, if the code isn't deployed...
    Vulintus_Send_Error_Report(target,subject,txt);                         %Use the common subfunction to send the error report.
end