function Clear_Msg(varargin)
%
%CLEAR_MSG.m - Rennaker Neural Engineering Lab, 2013
%
%   CLEAR_MSG deleles all messages in a listbox on a GUI.
%
%   CLEAR_MSG(listbox) or CLEAR_MSG(~,~,listbox) clears all messages out of
%   the listbox whose handle is specified in the variable "listbox".
%
%   Last modified January 24, 2013, by Drew Sloan.

if nargin == 1                                                              %If there's only one input argument...
    listbox = varargin{1};                                                  %The listbox handle is the first input argument.
elseif nargin == 3                                                          %Otherwise, if there's three input arguments...
    listbox = varargin{3};                                                  %The listbox handle is the third input argument.
end
set(listbox,'string',{},'min',0,'max',0','selectionhighlight','off',...
    'value',[]);                                                            %Clear the messages and set the properties on the listbox to make it look like a simple messagebox.