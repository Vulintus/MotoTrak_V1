function Replace_Msg(msgbox,new_msg)

%
%REPLACE_MSG.m - Rennaker Neural Engineering Lab, 2013
%
%   REPLACE_MSG displays messages in a listbox on a GUI, replacing messages
%   at the bottom of the list with new lines.
%
%   Replace_Msg(listbox,new_msg) replaces the last N entry or entries in
%   the listbox or text area whose handle is specified by the variable 
%   "msgbox" with the string or cell array of strings specified in the 
%   variable "new_msg".
%
%   UPDATE LOG:
%   01/24/2013 - Drew Sloan - Function first created.
%   11/26/2021 - Drew Sloan - Added functionality to use scrolling text
%       areas (uitextarea) as messageboxes.
%

switch get(msgbox,'type')                                                   %Switch between the recognized components.
    
    case 'uicontrol'                                                        %If the messagebox is a listbox...
        switch get(msgbox,'style')                                          %Switch between the recognized uicontrol styles.
            
            case 'listbox'                                                  %If the messagebox is a listbox...
                messages = get(msgbox,'string');                            %Grab the current string in the messagebox.
                if isempty(messages)                                        %If there's no messages yet in the messagebox...
                    messages = {};                                          %Create an empty cell array to hold messages.
                elseif ~iscell(messages)                                    %If the string property isn't yet a cell array...
                    messages = {messages};                                  %Convert the messages to a cell array.
                end
                if ~iscell(new_msg)                                         %If the new message isn't a cell array...
                    new_msg = {new_msg};                                    %Convert the new message to a cell array.
                end
                messages(end+1-(1:length(new_msg))) = new_msg;              %Add the new message where the previous last message was.
                set(msgbox,'string',messages);                              %Show that the Arduino connection was successful on the messagebox.
                set(msgbox,'value',length(messages));                       %Set the value of the listbox to the newest messages.
                drawnow;                                                    %Update the GUI.
                a = get(msgbox,'listboxtop');                               %Grab the top-most value of the listbox.
                set(msgbox,'min',0,...
                    'max',2',...
                    'selectionhighlight','off',...
                    'value',[],...
                    'listboxtop',a);                                        %Set the properties on the listbox to make it look like a simple messagebox.
                drawnow;                                                    %Update the GUI.
                
        end
        
    case 'uitextarea'                                                       %If the messagebox is a uitextarea...
        messages = msgbox.Value;                                            %Grab the current strings in the messagebox.
        if ~iscell(messages)                                                %If the string property isn't yet a cell array...
            messages = {messages};                                          %Convert the messages to a cell array.
        end
        checker = 1;                                                        %Create a matrix to check for non-empty cells.
        for i = 1:numel(messages)                                           %Step through each message.
            if ~isempty(messages{i})                                        %If there any non-empty messages...
                checker = 0;                                                %Set checker equal to zero.
            end
        end
        if checker == 1                                                     %If all messages were empty.
            messages = {};                                                  %Set the messages to an empty cell array.
        end
        if ~iscell(new_msg)                                                 %If the new message isn't a cell array...
            new_msg = {new_msg};                                            %Convert the new message to a cell array.
        end
        messages(end+1-(1:length(new_msg))) = new_msg;                      %Add the new message where the previous last message was.
        msgbox.Value = messages;                                            %Update the strings in the Text Area.
        scroll(msgbox,'bottom');                                            %Scroll to the bottom of the Text Area.
        drawnow;                                                            %Update the GUI.
        
end
