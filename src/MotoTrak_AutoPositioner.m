classdef MotoTrak_AutoPositioner
    % MotoTrak_AutoPositioner - author David Pruitt
    % Last edited: 6/23/2016
    % This class centralizes function of the autopositioner within
    % MotoTrak so that there are not multiple places within the code trying
    % to keep track of it.
    %
    % This class is written such that it acts as if it were a STATIC class
    % in C/C++/C#.  Matlab does not allow static class properties, so I have
    % gotten around this by using "persistent" variables within member
    % methods, and then getters/setters that call into these methods.
    %
    % This class essentially keeps a queue of all positions that the
    % autopositioner must visit.  A position can be added to the queue by
    % calling the set_position method.  The position should be in units of
    % CENTIMETERS (the scale actually printed on the MotoTrak booth
    % itself)!
    %
    % The actual movement only happens when the run_autopositioner method 
    % is called.  This method should be called on every iteration of the
    % program loop.  When called, it will simply check to see if it has
    % been N seconds since the last time an autopositioner command was
    % executed (N = 5 by default), and if so, it will execute the next
    % autopositioner command.
    %
    % Example usage:
    %
    % while(session_is_running)
    %   if (trial_was_successful)
    %       if (position_change_required)
    %           MotoTrak_AutoPositioner.set_position(2);
    %       end
    %   end
    %
    %   MotoTrak_AutoPositioner.run_autopositioner(handles.ardy, ...
    %       handles.positioner_offset);
    % end
    %
    %
    
    properties (Constant)
        
        %The number of seconds to wait inbetween moves of the
        %autopositioner
        TIME_TO_WAIT_INBETWEEN_MOVES = 5;
        
    end
    
    methods (Static)
        
        %Set the position of the auto-positioner
        function set_position ( new_position )
            MotoTrak_AutoPositioner.position('enqueue', new_position);
        end
        
        %Retrieve the entire queue of positions that the autopositioner is
        %set to visit
        function out = get_current_position_queue ( )
            out = MotoTrak_AutoPositioner.position('peek_all', NaN);
        end
        
        %Run through the autopositioner code
        function run_autopositioner ( ardy, positioner_offset )
            time_of_last_move = MotoTrak_AutoPositioner.get_time_of_last_move();
            current_time = now;
            enough_time_elapsed = current_time >= (time_of_last_move + seconds(MotoTrak_AutoPositioner.TIME_TO_WAIT_INBETWEEN_MOVES));
            if (enough_time_elapsed)
                MotoTrak_AutoPositioner.set_time_of_last_move(current_time);
                new_position_to_set = MotoTrak_AutoPositioner.position('dequeue', NaN);
                if (~isnan(new_position_to_set))
                    actual_position = round(10*(positioner_offset - 10*new_position_to_set));
                    ardy.autopositioner(actual_position);
                end
            end
        end
        
        %Reset the autopositioner
        function reset_autopositioner ( ardy )
            MotoTrak_AutoPositioner.position('clear', NaN);
            MotoTrak_AutoPositioner.set_time_of_last_move(now);
            ardy.autopositioner(0);
        end
        
    end
    
    methods (Static, Access = private)
        
        %Set the time of the most recent move of the autopositioner
        function set_time_of_last_move ( new_time )
            MotoTrak_AutoPositioner.setGetTime(new_time);
        end
        
        %Get the time of the most recent move of the autopositioner
        function out = get_time_of_last_move ( )
            out = MotoTrak_AutoPositioner.setGetTime();
        end
        
        % Private static getter/setter for the position
        function out = position ( function_name, function_value )
            persistent position_list;
            out = NaN;
            
            if (strcmpi(function_name, 'enqueue'))
                %Enqueue the element
                position_list = [position_list function_value];
            elseif (strcmpi(function_name, 'dequeue'))
                %Set the output value
                if (~isempty(position_list))
                    out = position_list(1);
                end
                
                %Dequeue the element
                if (length(position_list) >= 2)
                    position_list = position_list(2:end);
                else
                    position_list = [];
                end
            elseif (strcmpi(function_name, 'peek'))
                %Peek at the front element
                if (~isempty(position_list))
                    out = position_list(1);
                end
            elseif (strcmpi(function_name, 'peek_all'))
                %Return the entire queue
                out = position_list;
            elseif (strcmpi(function_name, 'clear'))
                %Clear the queue
                position_list = [];
            end
        end
        
        % Private static getter/setter for the most recent time the
        % autopositioner moved
        function out = setGetTime ( new_time )
           persistent last_time;
           if (isempty(last_time))
               last_time = 0;
           end
           if (nargin)
               last_time = new_time;
           end
           out = last_time;
        end
        
    end
    
end

