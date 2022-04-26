function MotoTrak_Set_Stream_Params(handles)

%This function sets the streaming parameters on the Arduino.

handles.ardy.set_stream_period(handles.period);                             %Set the stream period on the Arduino.
if handles.ardy.version >= 2.00                                             %If the controller sketch version is 2.00 or newer...
    inputs = handles.stage(handles.cur_stage).stream_order;                 %Copy over the inputs.
    fprintf(1,'STREAM ORDER = ');
    for i = 1:numel(inputs)                                                 %Step through each input.
        fprintf(1,'%1.0f\t',inputs(i)); 
        handles.ardy.set_stream_input(i,inputs(i));                         %Set each input.
    end
    fprintf(1,'\n');
end