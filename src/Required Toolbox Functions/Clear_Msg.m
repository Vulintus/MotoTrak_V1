function Clear_Msg(varargin)

%
%Clear_Msg.m - Vulintus, Inc.
%
%   CLEAR_MSG deleles all messages in a listbox on a GUI.
%
%   CLEAR_MSG(msgbox) or CLEAR_MSG(~,~,msgbox) clears all messages out of
%   the ListBox / uitextarea whose handle is specified in the variable 
%   "msgbox".
%
%   UPDATE LOG:
%   01/24/2013 - Drew Sloan - Function first created.
%   11/26/2021 - Drew Sloan - Added functionality to use scrolling text
%       areas (uitextarea) as messageboxes.
%

if nargin == 1                                                              %If there's only one input argument...
    msgbox = varargin{1};                                                  %The listbox handle is the first input argument.
elseif nargin == 3                                                          %Otherwise, if there's three input arguments...
    msgbox = varargin{3};                                                  %The listbox handle is the third input argument.
end

switch get(msgbox,'type')                                                   %Switch between the recognized components.
    
    case 'listbox'                                                          %If the messagebox is a listbox...
        set(msgbox,'string',{},...
            'min',0,...
            'max',0',...
            'selectionhighlight','off',...
            'value',[]);                                                    %Clear the messages and set the properties on the listbox to make it look like a simple messagebox.
        
    case 'uitextarea'                                                       %If the messagebox is a uitextarea...
        messages = {''};                                                    %Create a cell array with one empty entry.
        msgbox.Value = messages;                                            %Update the strings in the Text Area.
        scroll(msgbox,'bottom');                                            %Scroll to the bottom of the Text Area.
        drawnow;                                                            %Update the GUI.
        
end