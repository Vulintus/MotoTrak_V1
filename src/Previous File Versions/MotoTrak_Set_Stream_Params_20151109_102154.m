function MotoTrak_Set_Stream_Params(handles)

%This function sets the streaming parameters on the Arduino.

handles.ardy.set_stream_period(handles.period);                             %Set the stream period on the Arduino.
handles.ardy.set_stream_ir(handles.current_ir);                             %Set the stream IR input index on the Arduino.