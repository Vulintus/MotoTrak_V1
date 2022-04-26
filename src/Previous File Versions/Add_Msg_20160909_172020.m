function Add_Msg(listbox,new_msg)
%
%ADD_MSG.m - Rennaker Neural Engineering Lab, 2013
%
%   ADD_MSG displays messages in a listbox on a GUI, adding new messages to
%   the bottom of the list.
%
%   Add_Msg(listbox,new_msg) adds the string or cell array of strings
%   specified in the variable "new_msg" as the last entry or entries in the
%   listbox whose handle is specified by the variable "listbox".
%
%   UPDATE LOG:
%   09/09/2016 - Drew Sloan - Fixed the bug caused by setting the
%       ListboxTop property to an non-existent item.
%

messages = get(listbox,'string');                                           %Grab the current string in the messagebox.
if isempty(messages)                                                        %If there's no messages yet in the messagebox...
    messages = {};                                                          %Create an empty cell array to hold messages.
elseif ~iscell(messages)                                                    %If the string property isn't yet a cell array...
    messages = {messages};                                                  %Convert the messages to a cell array.
end
messages{end+1} = new_msg;                                                  %Add the new message to the 
set(listbox,'string',messages);                                             %Show that the Arduino connection was successful on the messagebox.
set(listbox,'value',length(messages),...
    'ListboxTop',length(messages));                                         %Set the value of the listbox to the newest messages.
drawnow;                                                                    %Update the GUI.
set(listbox,'min',0,'max',2','selectionhighlight','off','value',[]);        %Set the properties on the listbox to make it look like a simple messagebox.