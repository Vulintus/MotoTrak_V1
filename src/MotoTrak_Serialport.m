classdef MotoTrak_Serialport < matlabshared.testmeas.internal.SetGet & ...
        matlabshared.testmeas.CustomDisplay
    %SERIALPORT Create serial client for communication with the serial port
    %
    %   OBJ = SERIALPORT(PORT,BAUDRATE) constructs a serialport object, OBJ,
    %   associated with port value, PORT and a baud rate of BAUDRATE, and
    %   automatically connects to the serial port.
    %
    %   s = SERIALPORT(PORT,BAUDRATE,'NAME','VALUE', ...) constructs a
    %   serialport object using one or more name-value pair arguments. If an
    %   invalid property name or property value is specified the object will
    %   not be created. Serialport properties that can be set using name-value
    %   pairs are ByteOrder, DataBits, StopBits, Timeout, Parity, and
    %   FlowControl.
    %
    %   s = SERIALPORT constructs a serialport object using the property
    %   settings of the last cleared serialport object instance. The
    %   retained properties are Port, BaudRate, ByteOrder, FlowControl,
    %   StopBits, DataBits, Parity, Timeout, and Terminator.
    %
    %   SERIALPORT methods:
    %
    %   READ METHODS
    %   <a href="matlab:help internal.Serialport.read">read</a>                - Read data from the serialport device
    %   <a href="matlab:help internal.Serialport.readline">readline</a>            - Read ASCII-terminated string data from the serialport device
    %   <a href="matlab:help internal.Serialport.readbinblock">readbinblock</a>        - Read binblock data from the serialport device
    %
    %   WRITE METHODS
    %   <a href="matlab:help internal.Serialport.write">write</a>               - Write data to the serialport device
    %   <a href="matlab:help internal.Serialport.writeline">writeline</a>           - Write ASCII-terminated string data to the serialport device
    %   <a href="matlab:help internal.Serialport.writebinblock">writebinblock</a>       - Write binblock data to the serialport device
    %
    %   OTHER METHODS
    %   <a href="matlab:help internal.Serialport.writeread">writeread</a>           - Write ASCII-terminated string data to the serialport device
    %                         and read ASCII-terminated string data back as a response
    %   <a href="matlab:help internal.Serialport.configureCallback">configureCallback</a>   - Set the Bytes Available callback properties
    %   <a href="matlab:help internal.Serialport.configureTerminator">configureTerminator</a> - Set the serialport read and write terminator properties
    %   <a href="matlab:help internal.Serialport.flush">flush</a>               - Clear the input and/or output buffers of the serialport device
    %   <a href="matlab:help internal.Serialport.getpinstatus">getpinstatus</a>        - Get the serialport pin status
    %   <a href="matlab:help internal.Serialport.setDTR">setDTR</a>              - Set the serialport DTR (Data Terminal Ready) pin
    %   <a href="matlab:help internal.Serialport.setRTS">setRTS</a>              - Set the serialport RTS (Ready To Send) pin
    %
    %   SERIALPORT properties:
    %
    %   <a href="matlab:help internal.Serialport.Port">Port</a>                    - Serial port for connection
    %   <a href="matlab:help internal.Serialport.BaudRate">BaudRate</a>                - Speed of communication (in bits per second)
    %   <a href="matlab:help internal.Serialport.Parity">Parity</a>                  - Parity to check whether data has been lost or written
    %   <a href="matlab:help internal.Serialport.DataBits">DataBits</a>                - Number of bits used to represent one character of data
    %   <a href="matlab:help internal.Serialport.StopBits">StopBits</a>                - Pattern of bits that indicates the end of a character or of the whole transmission
    %   <a href="matlab:help internal.Serialport.FlowControl">FlowControl</a>             - Mode of managing the rate of data transmission
    %   <a href="matlab:help internal.Serialport.ByteOrder">ByteOrder</a>               - Sequential order in which bytes are arranged into larger numerical values
    %   <a href="matlab:help internal.Serialport.Timeout">Timeout</a>                 - Waiting time to complete read and write operations
    %   <a href="matlab:help internal.Serialport.NumBytesAvailable">NumBytesAvailable</a>       - Number of bytes available to be read
    %   <a href="matlab:help internal.Serialport.NumBytesWritten">NumBytesWritten</a>         - Number of bytes written to the serial port
    %   <a href="matlab:help internal.Serialport.Terminator">Terminator</a>              - Read and write terminator for the ASCII-terminated string communication
    %   <a href="matlab:help internal.Serialport.BytesAvailableFcn">BytesAvailableFcn</a>       - Function handle to be called when a Bytes Available event occurs
    %   <a href="matlab:help internal.Serialport.BytesAvailableFcnCount">BytesAvailableFcnCount</a>  - Number of bytes in the input buffer that triggers a Bytes Available event
    %                             (Only applicable for BytesAvailableFcnMode = "byte")
    %   <a href="matlab:help internal.Serialport.BytesAvailableFcnMode">BytesAvailableFcnMode</a>   - Condition for firing BytesAvailableFcn callback
    %   <a href="matlab:help internal.Serialport.ErrorOccurredFcn">ErrorOccurredFcn</a>        - Function handle to be called when an error event occurs
    %   <a href="matlab:help internal.Serialport.UserData">UserData</a>                - Application specific data for the serialport
    %
    %   Examples:
    %
    %       % Construct a serialport object.
    %       s = Serialport("COM1",38400);
    %
    %       % Write 1, 2, 3, 4, 5 as "uint8" data to the serial port.
    %       write(s,1:5,"uint8");
    %
    %       % Read 10 numbers of "uint16" data from the serial port.
    %       data = read(s,10,"uint16");
    %
    %       % Set the Terminator property
    %       configureTerminator(s,"CR/LF");
    %
    %       % Write "hello" to the serial port with the Terminator included.
    %       writeline(s,"hello");
    %
    %       % Read ASCII-terminated string from the serial port.
    %       data = readline(s);
    %
    %       % Write 1, 2, 3, 4, 5 as a binblock of "uint8" data to the serial
    %       % port.
    %       writebinblock(s,1:5,"uint8");
    %
    %       % Read binblock of "uint8" data from the serial port.
    %       data = readbinblock(s,"uint8");
    %
    %       % Query the serial port by writing an ASCII-terminated
    %       % string "*IDN?" to the serial port, and reading back an ASCII
    %       % terminated response from the serial port.
    %       response = writeread(s,"*IDN?");
    %
    %       % Set the Bytes Available Callback properties
    %       configureCallback(s,"byte",50,@myCallbackFcn);
    %
    %       % Flush output buffer
    %       flush(s,"output");
    %
    %       % Get the value of serialport pins
    %       status = getpinstatus(s);
    %
    %       % Set the DTR pin
    %       setDTR(s,true);
    %
    %       % Set the RTS pin
    %       setRTS(s,true);
    %
    %       % Disconnect and clear serialport connection
    %       clear s
    %
    %   See also SERIALPORTLIST.
    
    %   Copyright 2019-2020 The MathWorks, Inc
    
    properties (GetAccess = public, SetAccess = private, Dependent)
        % Port - Specifies the serial port for connection.
        % Read/Write Access - Read-only
        % Accepted Values - Port name as a string or char array
        % Default - NA
        Port
    end
    
    properties (Hidden, Access = private, Constant)
        % TransportType - Type of transport to be created.
        TransportType = "serial"
    end
    
    properties (Access = public, Dependent)
        % BaudRate - Specifies the speed of communication (in bits per
        %            second) for the serial port.
        % Read/Write Access - Both
        % Accepted Values - Positive integer values
        % Default - NA
        BaudRate
        
        % Timeout - Specifies the waiting time (in seconds) to complete
        %           read and write operations.
        % Read/Write Access - Both
        % Accepted Values - Positive numeric values
        % Default - 10
        Timeout
        
        % FlowControl - Specifies the mode of managing the rate of data
        %               transmission.
        % Read/Write Access - Both
        % Accepted Values - "none", "hardware", "software" (string or char)
        % Default - "none"
        FlowControl
        
        % Parity - Specifies the parity to check whether data has been lost
        %          or written.
        % Read/Write Access - Both
        % Valid Values - "none", "even", "odd" (string or char)
        % Default - "none"
        Parity
        
        % StopBits - Specifies the pattern of bits that indicates the end 
        %            of a character or of the whole transmission.
        % Read/Write Access - Both
        % Accepted Values - 1, 1.5, and 2
        % Default - 1
        StopBits
        
        % DataBits - Specifies the number of bits used to represent one 
        %            character of data.
        % Read/Write Access - Both
        % Accepted Values - 5, 6, 7, 8
        % Default - 8
        DataBits
        
        % ByteOrder - Specifies the sequential order in which bytes are
        %             arranged into larger numerical values.
        % Read/Write Access - Both
        % Accepted Values - "little-endian", "big-endian" (char and string)
        % Default - "little-endian"
        ByteOrder
        
        % UserData - To store application specific data
        % Read/Write Access - Both
        % Accepted Values - Any MATLAB type
        % Default - []
        UserData
        
        % Note - SetAccess for BytesAvailableFcnMode, BytesAvailableFcn,
        % BytesAvailableFcnCount and Terminator, which are read-only
        % properties, is public to be able to throw custom and more
        % meaningful errors for setting these properties.
        
        % Terminator - Specifies the read and write terminator for the
        % ASCII termninated string communication.
        % Read/Write Access - Read-only
        % Default - "LF"
        %
        % To set this property, see <a href="matlab:help internal.Serialport.configureTerminator">configureTerminator</a> function.
        Terminator
        
        % BytesAvailableFcnCount - For BytesAvailableFcnMode = "byte", the
        %                          number of bytes in the input buffer that
        %                          triggers BytesAvailableFcn.
        % Read/Write Access - Read-only
        % Default - 64
        %
        % To set this property, see <a href="matlab:help internal.Serialport.configureCallback">configureCallback</a> function.
        BytesAvailableFcnCount
        
       % BytesAvailableFcnMode - Specifies the condition when the bytes
        %                         available callback is to be fired:
        %                         a. when BytesAvailableFcnCount number of
        %                            bytes are available to be read, or
        %                         b. when the terminator is reached, or
        %                         c. disables BytesAvailable callback.
        % Read/Write Access - Read-only
        % Default - "off"
        %
        % To set this property, see <a href="matlab:help internal.Serialport.configureCallback">configureCallback</a> function.
        BytesAvailableFcnMode
        
        % BytesAvailableFcn - The callback function that gets fired when
        %                     BytesAvailable event occurs.
        % Read/Write Access - Read-only
        % Valid Values - any function_handle
        % Default - []
        %
        % To set this property, see <a href="matlab:help internal.Serialport.configureCallback">configureCallback</a> function.
        BytesAvailableFcn
    end
    
    properties (GetAccess = public, SetAccess = private, Dependent)
        % NumBytesAvailable - Specifies the number of bytes available to be
        %                     read.
        % Read/Write Access - Read-only
        % Default - 0
        NumBytesAvailable
        
        % NumBytesWritten - Specifies the number of bytes written to the
        %                   serial port.
        % Read/Write Access - Read-only
        % Default - 0
        NumBytesWritten
    end

    properties
        % ErrorOccurredFcn - The function that gets called when an error 
        %                    event occurs.
        % Read/Write Access - Both
        % Valid Values - function_handle
        % Default - []
        ErrorOccurredFcn = function_handle.empty()
    end
    
    properties (Hidden, Access = ...
            {?internal.Serialport, ?instrument.internal.ITestable})
        % Transport - The Serial transport used for serialport
        % communication.
        Transport
        
        % InstrumentImpl - Instrument specific functionality handler.
        InstrumentImpl
        
        % StringClient - String functionality handler.
        StringClient
        
        % DocIDSomeData - Doc ID for read warning when some data is read.
        DocIDSomeData
        
        % DocIDSomeData - Doc ID for read warning when no data is read.
        DocIDNoData
        
        % PrefsHandler - The handle to the Serialport Preferences Handler.
        PrefsHandler
        
        % BytesAvailableFcnModeLocal - The local copy of the
        % BytesAvailableFcnMode property. This is returned back when the
        % getter for BytesAvailableFcnMode is called. In configureCallback,
        % the BytesAvailableFcnModeLocal is set instead of
        % BytesAvailableFcnMode as the setter for BytesAvailableFcnMode
        % will error.
        BytesAvailableFcnModeLocal = "off"
        
        % BytesAvailableFcnLocal - The local copy of the
        % BytesAvailableFcn property. This is returned when the getter for 
        % BytesAvailableFcn is called. In configureCallback, the 
        % BytesAvailableFcnLocal is set instead of BytesAvailableFcn as the
        % setter for BytesAvailableFcn will error.
        BytesAvailableFcnLocal = function_handle.empty()
    end
    
    properties(Hidden, Constant)
        %% Serialport properties used for displaying error messages and serialport data

        ConfigureCallbackExample = {'configureCallback(s,"off")', ...
            'configureCallback(s,"terminator",@callbackFcn)', ...
            'configureCallback(s,"byte",count,@callbackFcn)'}
        
        ConfigureCallbackMode = struct('off', 1,  'terminator', 2, ...
            'byte', 3)
        
        SelectPropertyList = {'Port', 'BaudRate', 'NumBytesAvailable'}
        
        CommunicationPropertiesList = {'ByteOrder', 'DataBits', ...
            'StopBits', 'Parity', 'FlowControl', 'Timeout', 'Terminator'}
        
        BytesAvailablePropertiesList = {'BytesAvailableFcnMode', ...
            'BytesAvailableFcnCount', 'BytesAvailableFcn', 'NumBytesWritten'}
        
        AdditionalPropertiesList = {'ErrorOccurredFcn', 'UserData'}
        
        AllSupportedPrecision = ["single", "double", "int8", "uint8", ...
            "int16", "uint16", "int32", "uint32", "int64", "uint64", "char", "string"]

        CustomExamples = struct( ...
            "serialport", ("s = serialport()" + newline + "s = serialport(PORT,BAUDRATE)" ...
            + newline + "s = serialport(PORT,BAUDRATE,NAME,VALUE)"), ...
            "read", "DATA = read(s,COUNT,PRECISION)", ...
            "readline", "DATA = readline(s)", ...
            "readbinblock", ("DATA = readbinblock(s)" + newline + "DATA = readbinblock(s,PRECISION)"), ...
            "write", "write(s,DATA,PRECISION)", ...
            "writeline", "writeline(s,DATA)", ...
            "writebinblock", "writebinblock(s,DATA,PRECISION)", ...
            "configureCallback", ("configureCallback(s,""off"")" + newline + "configureCallback(s,""terminator"",CALLBACKFCN)" ...
            + newline + "configureCallback(s,""byte"",COUNT,CALLBACKFCN)"), ...
            "configureTerminator", ("configureTerminator(s,TERMINATOR)" + newline + "configureTerminator(s,READTERMINATOR,WRITETERMINATOR)"), ...
            "flush", ("flush(s)" + newline + "flush(s,BUFFER)"), ...
            "writeread", "RESPONSE = writeread(s,COMMAND)", ...
            "getpinstatus", "STATUS = getpinstatus(s)", ...
            "setDTR", "setDTR(s,FLAG)", ...
            "setRTS", "setRTS(s,FLAG)" ...
            )

        ICTLink = '<a href="matlab:matlab.internal.language.introspective.showAddon(''IC'')">Instrument Control Toolbox</a>'
    end
    
    properties(Hidden, Dependent)
        % The WriteComplete flag from the internal Serial Transport. This
        % is used to block the serialport write till the write data
        % has been transmitted, thus ensuring that the write is blocking.
        WriteComplete
    end

    methods (Access = public)
        function obj = MotoTrak_Serialport(varargin)
            %Serialport Constructs Serialport object.
            %
            %   OBJ = Serialport constructs a Serialport object, OBJ, using
            %   the previously cleared serialport object properties - PORT,
            %   BAUDRATE, BYTEORDER, FLOWCONTROL, STOPBITS, DATABITS, 
            %   PARITY, TIMEOUT, and TERMINATOR.
            %
            %   OBJ = Serialport(PORT,BAUDRATE) constructs a
            %   Serialport object, OBJ, associated with serial port, PORT
            %   and BaudRate, BAUDRATE
            %
            %   OBJ = Serialport(PORT,BAUDRATE,'NAME','VALUE', ...) 
            %   constructs a Serialport object, OBJ, associated with serial
            %   port, PORT and BaudRate, BAUDRATE, and one or more 
            %   name-value pair arguments. Serialport properties that can
            %   be set using name-value pairs are ByteOrder, DataBits, 
            %   StopBits, Timeout, Parity, and FlowControl.
            %
            % Input Arguments:
            %   PORT specifies the serial port to connect to
            %   BAUDRATE specifies the Baud rate for the serial communication.
            %
            %   Other writable Serialport properties can be passed in as an NV
            %   pair to the Serialport constructor, are "FLOWCONTROL", "STOPBITS",
            %   "DATABITS", "PARITY", "BYTEORDER", and "TIMEOUT".
            %
            % Example:
            %      % Create a serialport connection on COM1 with a Baud Rate
            %      % of 38400.
            %      s = serialport("COM1",38400);
            %
            %      % Create a serialport connection on COM3, Baud Rate of
            %      % 9600, and a Byte Order of "big-endian".
            %      s = serialport("COM3",9600,"ByteOrder","big-endian");
            
            if nargin == 1
                % This is an error condition
                funcName = 'MotoTrak_serialport';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsPlural', ...
                    funcName, obj.CustomExamples.(funcName))));
            end
            % Create instance of Serialport Preferences Handler
            obj.PrefsHandler = internal.SerialportPrefHandler();
            
            try
                terminator = [];
                if nargin == 0
                    % Use the serialport values saved in preferences
                    [port, baudrate, terminator, varargin] = ...
                        obj.PrefsHandler.parsePreferencesHandler();
                else
                    % Set the first argument to port, and second to
                    % BaudRate. Save the remaining (if any) as varargin.
                    port = varargin{1};
                    baudrate = varargin{2};
                    varargin = varargin(3:end);
                end
                
                port = instrument.internal.stringConversionHelpers.str2char(port);
                varargin = instrument.internal.stringConversionHelpers.str2char(varargin);
                validateattributes(port, {'char'}, {'nonempty'}, 'Serialport', 'PORT', 1);
                validateattributes(baudrate, {'double'}, {'nonempty', 'positive', 'scalar'} ...
                    , 'Serialport', 'BAUDRATE', 2);
                
                % Create the transport
                obj.Transport = matlabshared.transportlib.internal.TransportFactory. ...
                    getTransport(obj.TransportType, port);
                
                % Set the BaudRate
                obj.BaudRate = baudrate;
                
                % Create the String Client and update the terminator, if
                % using preferences.
                obj.StringClient = matlabshared.transportclients.internal.StringClient. ...
                    StringClient(obj.Transport);
                
                % Set the terminator value for the serialport, when creating
                % the serialport object using preferences data.
                if ~isempty(terminator)
                    obj.StringClient.Terminator = terminator;
                end
                
                % Validate that number of names and number of values match
                % for the NV pairs.
                if mod(numel(varargin), 2)
                    throwAsCaller(MException(message('serialport:serialport:UnmatchedPVPairs')));
                end
                
                % Initialize all properites to the default, or requested
                % state
                initProperties(obj, varargin);
                
                % Set Custom Display properties
                setCustomDisplay(obj);

                % Set the Transport's ErrorOccuredFcn
                obj.Transport.ErrorOccurredFcn = @obj.errorCallbackFunction;
                
                % Get the doc IDs for no-data and some-data returned.
                [obj.DocIDNoData, obj.DocIDSomeData] = ...
                    instrument.internal.warningMessagesHelpers.getReadWarningDocLinks("serialport");
            catch ex
                throwAsCaller(ex);
            end

            try
                % Establish a connection
                connect(obj.Transport);
            catch ex
                errText = string(message('serialport:serialport:ConnectionFailed', port).getString);

                % For linux, append the ex.message to the original error
                % text
                if ~ismac && isunix
                    errText = errText + ...
                        newline + "Additional Information: " + string(ex.message);
                end
                throwAsCaller(MException('serialport:serialport:ConnectionFailed', errText));
            end
            % Allow for partial reads. This ensures that in case of
            % incomplete reads, we get the requested data back along
            % with the timeout warning.
            obj.Transport.AllowPartialReads = true;
        end
        
        function delete(obj)
            % Update Preferences and delete the preferences handler.
            if ~isempty(obj.Transport) && obj.Transport.Connected
                obj.updatePreferences();
            end
            obj.PrefsHandler = [];
            
            % Clear the InstrumentImpl instance, if ever created
            if ~isempty(obj.InstrumentImpl)
                obj.InstrumentImpl = [];
            end
            
            % Clear the StringClient instance and Transport Instance.
            obj.StringClient = [];
            obj.Transport = [];
        end
        
        function data = read(obj, varargin)
            %READ Read data from the serial port.
            %
            %   DATA = READ(OBJ,COUNT,PRECISION) reads the specified
            %   number of values, COUNT, with the specified precision,
            %   PRECISION, from the device connected to the
            %   serial port, OBJ, and returns to DATA. For numeric PRECISION 
            %   types DATA is represented as a DOUBLE array in row format. 
            %   For char and string PRECISION types, DATA is represented as
            %   is.
            %
            % Input Arguments:
            %   COUNT indicates the number of items to read. COUNT cannot be
            %   set to INF or NAN. If COUNT is greater than the
            %   NumBytesAvailable property of OBJ, then this function 
            %   waits until the specified amount of data is read or a 
            %   timeout occurs.
            %
            %   PRECISION indicates the number of bits read for each value
            %   and the interpretation of those bits as a MATLAB data type.
            %   PRECISION must be one of 'UINT8', 'INT8', 'UINT16',
            %   'INT16', 'UINT32', 'INT32', 'UINT64', 'INT64', 'SINGLE',
            %   'DOUBLE', 'CHAR', or 'STRING'.
            %
            % Output Arguments:
            %   DATA is a 1xN matrix of numeric or ASCII data. If no data
            %   was returned, this is an empty array.
            %
            % Note:
            %   READ waits until the requested number of values are read 
            %   from the serial port.
            %
            % Example:
            %      % Read 5 count of data as "uint32" (5*4 = 20 bytes).
            %      data = read(s,5,"uint32");
            try
                narginchk(3, 3);
            catch
                funcName = 'read';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', funcName, obj.CustomExamples.(funcName))));
            end
            try
                count = varargin{1};
                precision = varargin{2};
                validateattributes(count, {'numeric'}, {'integer', 'nonzero'}, mfilename, 'count', 2);
                data = read(obj.Transport, count, precision);
                if strcmpi(precision, "string")
                    dataConverted = char(data);
                else
                    dataConverted = data;
                end

                if length(dataConverted) < count
                    obj.displayReadWarning(dataConverted, 'Read');
                end
                
                % If data is a numeric type, represent the data as an array
                % of doubles.
                data = obj.convertNumericToDouble(data, precision);
            catch ex
                throwAsCaller(ex);
            end
        end
        
        function data = readline(obj, varargin)
            %READLINE Read ASCII-terminated string data from the serial
            %         port device 
            %
            %   DATA = READLINE(OBJ) reads until the first occurrence of the
            %          terminator and returns the data back as a STRING. This
            %          function waits until the terminator is reached or a
            %          timeout occurs.
            %
            % Output Arguments:
            %   DATA is a string of ASCII data. If no data was returned,
            %   this is an empty string.
            %
            % Note:
            %   READLINE waits until the terminator is read from the serial
            %   port.
            %
            % Example:
            %      % Reads all data up to the first occurrence of the 
            %      % terminator. Returns the data as a string with the
            %      % terminator removed.
            %      data = readline(s);

            try
                narginchk(1, 1);
            catch
                funcName = 'readline';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                precision = "string";
                data = read(obj.StringClient, precision);
            catch ex
                if strcmpi(ex.identifier, 'transportclients:string:timeoutToken')
                    obj.displayReadWarning([], 'Readline');
                    data = [];
                else
                    throwAsCaller(ex);
                end
            end
        end
        
        function data = readbinblock(obj, varargin)
            %READBINBLOCK Read one binblock of data from the serial port.
            %
            %   DATA = READBINBLOCK(OBJ) reads the binblock data as UINT8
            %          and represents them as a DOUBLE array in row format.
            %
            %   DATA = READBINBLOCK(OBJ,PRECISION) reads the binblock data as
            %          PRECISION type.For numeric PRECISION types DATA is 
            %          represented as a DOUBLE array in row format. 
            %          For char and string PRECISION types, DATA is 
            %          represented as is.
            %
            % Input Arguments:
            %   PRECISION indicates the number of bits read for each value
            %   and the interpretation of those bits as a MATLAB data type.
            %   DATATYPE must be one of 'UINT8', 'INT8', 'UINT16',
            %   'INT16', 'UINT32', 'INT32', 'UINT64', 'INT64', 'SINGLE',
            %   'DOUBLE', 'CHAR', or 'STRING'.
            %
            %   Default PRECISION: 'UINT8'
            %
            % Output Arguments:
            %   DATA is a 1xN matrix of numeric or ASCII data. If no data
            %   was returned this is an empty array.
            %
            % Notes:
            %   READBINBLOCK waits until a binblock is read from the
            %   serial port.
            %   READBINBLOCK REQUIRES INSTRUMENT CONTROL TOOLBOX™.
            %
            % Example:
            %      % Reads the raw bytes in the binblock as uint8, and
            %      % represents them as a double array in row format.
            %      data = readbinblock(s);
            %
            %      % Reads the raw bytes in the binblock as uint16, and
            %      % represents them as a double array in row format.
            %      data = readbinblock(s,"uint16")

            try
                % Instantiate InstrumentImpl instance, if not already
                % instantiated.
                instrumentImpl = obj.getInstrumentImpl;
            catch
                throwAsCaller(MException(message(...
                    'serialport:serialport:NoICTLicense', obj.ICTLink, 'readbinblock')));
            end

            try
                narginchk(1, 2);
            catch
                funcName = 'readbinblock';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsPlural', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                if nargin == 1
                    precision = 'uint8';
                else
                    precision = varargin{1};
                end
                data = instrumentImpl.readbinblock(precision);

                % If data is a numeric type, represent the data as an array
                % of doubles.
                data = obj.convertNumericToDouble(data, precision);
            catch ex
                if strcmpi(ex.identifier, 'transportclients:binblock:timeoutToken')
                    obj.displayReadWarning([], 'Readbinblock');
                    data = [];
                else
                    throwAsCaller(ex);
                end
            end
        end
        
        function write(obj, varargin)
            %WRITE Write data to the serial port.
            %   WRITE(OBJ,DATA,PRECISION) sends the 1xN matrix of data to
            %   the serial port. The data is cast to the specified
            %   precision PRECISION regardless of the actual precision.
            %
            % Input Arguments:
            %   DATA is a 1xN matrix of numeric or ASCII data.
            %
            %   PRECISION controls the number of bits written for each value
            %   and the interpretation of those bits as integer, floating-point,
            %   or character values.
            %   PRECISION must be one of 'CHAR','STRING','UINT8', 'INT8', 'UINT16',
            %   'INT16', 'UINT32', 'INT32', 'UINT64', 'INT64', 'SINGLE', or
            %   'DOUBLE'.
            %
            % Notes:
            %   WRITE waits until the requested number of values are
            %   written to the serial port.
            %
            % Example:
            %      % Writes 1, 2, 3, 4, 5 as uint8. (5*1 = 5 bytes total)
            %      % to the serial port.
            %      write(s, 1:5, "uint8");

            try
                narginchk(3, 3);
            catch
                funcName = 'write';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                data = varargin{1};
                precision = varargin{2};
                write(obj.Transport, data, precision);

                % Wait for the write to be complete
                % waitfor(obj, "WriteComplete", true);
            catch ex
                throwAsCaller(ex);
            end
        end
        
        function writeline(obj, varargin)
            %WRITELINE Write ASCII data followed by the terminator to the serial
            %   port.
            %
            %   WRITELINE(OBJ,DATA) writes the ASCII data, DATA, followed 
            %   by the terminator, to the serial port.
            %
            % Input Arguments:
            %   DATA is the ASCII data that is written to the serial port. This
            %   DATA is always followed by the write terminator character(s).
            %
            % Notes:
            %   WRITELINE waits until the ASCII DATA followed by terminator
            %   is written to the serial port.
            %
            % Example:
            %      % writes "*IDN?" and adds the terminator to the end of
            %      % the line before writing to the serial port.
            %      writeline(s,"*IDN?");
            %
            try
                narginchk(2, 2);
            catch
                funcName = 'writeline';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                data = varargin{1};
                write(obj.StringClient, data);

                % Wait for the write to be complete
                % waitfor(obj, "WriteComplete", true);
            catch ex
                throwAsCaller(ex);
            end
        end
        
        function writebinblock(obj, varargin)
            %WRITEBINBLOCK Write a binblock of data to the serial port.
            %
            %   WRITEBINBLOCK(OBJ,DATA,PRECISION) converts DATA into a
            %   binblock and writes it to the serial port. The data is
            %   cast to the specified precision PRECISION regardless of the
            %   actual precision.
            %
            % Input Arguments:
            %   DATA is a 1xN matrix of numeric or ASCII data that is 
            %   written as a binblock to the serial port.
            %
            % Notes:
            %   WRITEBINBLOCK waits until the binblock DATA is written
            %   to the serial port.
            %   WRITEBINBLOCK REQUIRES INSTRUMENT CONTROL TOOLBOX™.
            %
            % Example:
            %      % Converts 1, 2, 3, 4, 5 to a binblock and writes it to 
            %      % the serial port as uint8.
            %      writebinblock(s,1:5,"uint8");
            
            try
                % Instantiate InstrumentImpl instance, if not already
                % instantiated.
                instrumentImpl = obj.getInstrumentImpl;
            catch
                throwAsCaller(MException(message(...
                    'serialport:serialport:NoICTLicense', obj.ICTLink, 'writebinblock')));
            end

            try
                narginchk(3, 3);
            catch
                funcName = 'writebinblock';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                data = varargin{1};
                precision = varargin{2};
                instrumentImpl.writebinblock(data, precision);

                % Wait for the write to be complete
                % waitfor(obj, "WriteComplete", true);
            catch ex
                throwAsCaller(ex);
            end
        end
        
        function response = writeread(obj, varargin)
            %WRITEREAD Write ASCII-terminated string COMMAND to serial port and
            %reads back an ASCII-terminated string RESPONSE. 
            %This function can be used to query an instrument connected to
            %the serial port.
            %
            %   RESPONSE = WRITEREAD(OBJ,COMMAND) writes the COMMAND
            %   followed by the write terminator to the serial port. It reads
            %   back the RESPONSE from the serial port, which is an ASCII 
            %   terminated string, and returns the RESPONSE after removing 
            %   the read terminator.
            %
            % Input Arguments:
            %   COMMAND: The terminated ASCII data that is written to the
            %   serial port
            %
            % Output Arguments:
            %   RESPONSE: The terminated ASCII data that is returned back
            %   from the serialport.
            %
            % Notes:
            %   WRITEREAD waits until the ASCII-terminated COMMAND is written
            %   and an ASCII-terminated RESPONSE is retuned from the serial port.
            %   WRITEREAD REQUIRES INSTRUMENT CONTROL TOOLBOX™.
            %
            % Example:
            %      % Query the serial port for a response by sending "IDN?"
            %      % command.
            %      response = writeread(s,"*IDN?");
            %
            
            try
                instrumentImpl = obj.getInstrumentImpl;
            catch
               throwAsCaller(MException(message( ...
                   'serialport:serialport:NoICTLicense', obj.ICTLink, 'writeread')));
            end

            try
                narginchk(2, 2);
            catch
                funcName = 'writeread';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                command = varargin{1};
                response = instrumentImpl.writeread(command);
            catch ex
                throwAsCaller(ex);
            end
        end
        
        function configureCallback(obj, varargin)
            %CONFIGURECALLBACK Set the BytesAvailable properties:
            % 1. <a href="matlab:help internal.Serialport.BytesAvailableFcnMode">BytesAvailableFcnMode</a> 
            % 2. <a href="matlab:help internal.Serialport.BytesAvailableFcnCount">BytesAvailableFcnCount</a>
            % 3. <a href="matlab:help internal.Serialport.BytesAvailableFcn">BytesAvailableFcn</a>
            %
            % CONFIGURECALLBACK(OBJ,MODE) - For this syntax, the only 
            % possible value for MODE is "off". This turns the BytesAvailable
            % callbacks off.
            %
            % CONFIGURECALLBACK(OBJ,MODE,CALLBACKFCN) - For this syntax, 
            % the only possible value for MODE is "terminator". This sets the
            % BytesAvailableFcnMode property to "terminator". CALLBACKFCN
            % is the function handle that is assigned to BytesAvailableFcn.
            % CALLBACKFCN is triggered whenever a terminator is available
            % to be read.
            %
            % CONFIGURECALLBACK(OBJ,MODE,COUNT,CALLBACKFCN) - For this 
            % syntax, the only possible value for MODE is "BYTE". This sets
            % the BytesAvailableFcnMode property to "BYTE". CALLBACKFCN is 
            % the function handle that is assigned to BytesAvailableFcn. 
            % CALLBACKFCN is triggered whenever COUNT number of bytes are 
            % available to be read. BytesAvailableFcnCount is set to COUNT.
            %
            % Input Arguments:
            %   MODE: The BytesAvailableFcnMode. Possible values are "off",
            %   "terminator", and "byte".
            %
            %   COUNT: The BytesAvailableFcnCount. This can be set to any
            %   positive integer value. Valid only for MODE = "byte"
            %
            %   CALLBACKFCN: The BytesAvailableFcn. This can be set to a
            %   function_handle.
            %
            % Example:
            %      % Turn the callback off
            %      configureCallback(s,"off")
            %
            %      % Set the BytesAvailableFcnMode to "terminator". This
            %      % triggers the callback function "callbackFcn" when a
            %      % terminator is available to be read.
            %      configureCallback(s,"terminator",@callbackFcn)
            %
            %      % Set the BytesAvailableFcnMode to "byte". This
            %      % triggers the callback function "callbackFcn" when 50
            %      % bytes of data are available to be read.
            %      configureCallback(s,"byte",50,@callbackFcn)

            try
                narginchk(2, 4);
            catch
                funcName = 'configureCallback';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsPlural', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                % convert to char in order to accept string datatype
                varargin = instrument.internal.stringConversionHelpers.str2char(varargin);
                
                % The Bytes Available Fcn Mode.
                mode = varargin{1};
                
                % Validate the mode
                validateattributes(mode, {'char'}, {'nonempty'}, 'configureCallback', 'mode', 2);
                mode = validatestring(mode, {'terminator', 'byte', 'off'}, 'configureCallback', 'mode', 2);
                
                % Validate that the mode is in accordance with the number
                % of input arguments to configureCallback.
                obj.validateBytesAvailableMode(mode, nargin);
                
                % Set the BytesAvailableFcnMode
                setBytesAvailableFcnMode(obj, mode);
                
                switch mode
                    case 'off'
                        % Set the callback functions to empty.
                        obj.Transport.BytesAvailableFcn = function_handle.empty();
                        obj.StringClient.StringReadFcn = function_handle.empty();
                        setBytesAvailableFcn(obj, function_handle.empty());
                        
                    case 'terminator'
                        fcnHandle = varargin{2};
                        % 1. Set the BytesAvailableFcnLocal to fcnHandle.
                        % 2. Set the StringClient's StringReadFcn to the
                        % custom handler function "callbackFunction".
                        % 3. Set SingleCallbackMode to true.
                        setBytesAvailableFcn(obj, fcnHandle);
                        obj.Transport.SingleCallbackMode = true;
                        obj.StringClient.StringReadFcn = @obj.callbackFunction;
                    case 'byte'
                        count = varargin{2};
                        fcnHandle = varargin{3};

                        % 1. Set the BytesAvailableFcnCount to count
                        % 2. Set the BytesAvailableFcnLocal to fcnHandle.
                        % 3. Set SingleCallbackMode to false.
                        % 4. Because mode = terminator, set StringClient's
                        %    StringReadFcn to empty.
                        % 5. Set the Transport's BytesAvailableFcn to the
                        % custom handler function "callbackFunction".
                        setBytesAvailableFcnCount(obj, count);
                        setBytesAvailableFcn(obj, fcnHandle);
                        obj.Transport.SingleCallbackMode = false;
                        obj.StringClient.StringReadFcn = function_handle.empty();
                        obj.Transport.BytesAvailableFcn = @obj.callbackFunction;
                end
            catch ex
                throwAsCaller(ex);
            end
        end

        function configureTerminator(obj, varargin)
            %CONFIGURETERMINATOR Set the Terminator property for ASCII 
            % terminated string communication on the serial port.
            %
            % CONFIGURETERMINATOR(OBJ,TERMINATOR) - Sets the Terminator
            % property to TERMINATOR for the serialport object. TERMINATOR 
            % applies to both Read and Write Terminators.  
            %
            % CONFIGURETERMINATOR(OBJ,READTERMINATOR,WRITETERMINATOR) -
            % Sets the Terminator property of the serialport to a cell
            % array of {READTERMINATOR,WRITETERMINATOR}. It sets the
            % Read Terminator to READTERMINATOR and the Write Terminator to
            % WRITETERMINATOR for the serialport object.
            %
            % Input Arguments:
            %   TERMINATOR: The terminating character for as ASCII
            %   terminated communication. This sets both Read and Write
            %   Terminators to TERMINATOR.
            %   Accepted Values - Integers ranging from 0 to 255
            %                     "CR", "LF", "CR/LF"
            %
            %   READTERMINATOR: The read terminating character for as ASCII
            %   terminated communication. This sets the Read Terminator to
            %   READTERMINATOR.
            %   Accepted Values - Integers ranging from 0 to 255
            %                     "CR", "LF", "CR/LF"
            %
            %   WRITETERMINATOR: The write terminating character for as ASCII
            %   terminated communication. This sets the write Terminator to
            %   WRITETERMINATOR.
            %   Accepted Values - Integers ranging from 0 to 255
            %                     "CR", "LF", "CR/LF"
            %
            % Example:
            %      % Set both read and write terminators to "CR/LF"
            %      configureTerminator(s,"CR/LF")
            %
            %      % Set read terminator to "CR" and write terminator to
            %      % ASCII value of 10
            %      configureTerminator(s,"CR",10)

            try
                narginchk(2, 3);
            catch
                funcName = 'configureTerminator';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsPlural', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                if nargin == 2
                    % Set both read and write terminators to 'value'.
                    value = obj.validateTerminator(varargin{1});
                    obj.StringClient.Terminator = value;
                else
                    % Set the different terminator values.
                    readTerminator = obj.validateTerminator(varargin{1});
                    writeTerminator = obj.validateTerminator(varargin{2});
                    obj.StringClient.Terminator = {readTerminator writeTerminator};
                end
            catch
                throwAsCaller(MException(message ...
                    ('serialport:serialport:InvalidTerminator')));
            end
        end
        
        function flush(obj, varargin)
            %FLUSH Clear the input buffer, output buffer, or both, based
            % on the value of BUFFER.
            %
            % FLUSH(OBJ) clears both the input and output buffers.
            %
            % FLUSH(OBJ,BUFFER) clears the serial input buffer or output 
            % buffer, based on the value of BUFFER.
            %
            % Input Arguments:
            %   BUFFER is the type of buffer that needs to be flushed.
            %   Accepted Values - "input", "output".
            %
            % Example:
            %      % Flush the input buffer
            %      flush(s,"input");
            %
            %      % Flush the output buffer
            %      flush(s,"output");
            %
            %      % Flush both the input and output buffers
            %      flush(s);
            try
                narginchk(1, 2);
            catch
                funcName = 'flush';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsPlural', ...
                    funcName, obj.CustomExamples.(funcName))));
            end

            try
                if nargin == 1
                    % No value passed to buffer, flush both input and
                    % output.
                    flushInput(obj.Transport);
                    obj.StringClient.LastCallbackIdx = 0;
                    flushOutput(obj.Transport);
                else
                    % Validate buffer to be either "input" or "output"
                    buffer = varargin{1};
                    validateattributes(buffer, {'char', 'string'}, {'nonempty'}, 'flush', 'buffer', 2);
                    buffer = validatestring(buffer, ["input", "output"], 'flush', 'buffer', 2);
                    
                    % flush input or output buffer.
                    if strcmpi(buffer, "input")
                        flushInput(obj.Transport);
                        obj.StringClient.LastCallbackIdx = 0;
                    else
                        flushOutput(obj.Transport);
                    end
                end
            catch ex
                throwAsCaller(ex);
            end
        end
        
        function status = getpinstatus(obj, varargin)
            %GETPINSTATUS Get the serial pin status.
            %
            % STATUS = GETPINSTATUS(OBJ) gets the serial pin status and
            % returns it as a struct to STATUS.
            %
            % Output Arguments:
            %   STATUS: 1x1 struct with the fields, ClearToSend,
            %   DataSetReady, CarrierDetect, and RingIndicator.
            %
            % Example:
            %      % Get the pin status
            %      status = getpinstatus(s);
            
            try
                narginchk(1, 1);
            catch
                funcName = 'getpinstatus';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', ...
                    funcName, obj.CustomExamples.(funcName))));
            end
            try
                status = getPinStatus(obj.Transport);
            catch ex
                throwAsCaller(ex);
            end
        end
        
        function setRTS(obj, varargin)
            %SETRTS Set/reset the serial RTS (Ready to Send) pin
            %
            % SETRTS(OBJ,FLAG) sets or resets the serial RTS pin, based
            % on the value of FLAG.
            %
            % Input Arguments:
            %   FLAG: Logical true or false. FLAG set to true sets the 
            %   RTS pin, false resets it.
            %
            % Example:
            %      % Set the RTS pin
            %      setRTS(s,true);
            %
            %      % Reset the RTS pin
            %      setRTS(s,false);

            try
                narginchk(2, 2);
            catch
                funcName = 'setRTS';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', ...
                    funcName, obj.CustomExamples.(funcName))));
            end
            try
                flag = varargin{1};
                setRTS(obj.Transport, flag);
            catch ex
                throwAsCaller(ex);
            end
        end
        
        function setDTR(obj, varargin)
            %SETDTR Set/reset the serial DTR (Data Terminal Ready) pin
            %
            % SETDTR(OBJ, FLAG) sets or resets the serial DTR pin, based
            % on the value of FLAG.
            %
            % Input Arguments:
            %   FLAG: Logical true or false. FLAG set to true sets the 
            %   DTR pin, false resets it.
            %
            % Example:
            %      % Set the DTR pin
            %      setDTR(s, true);
            %
            %      % Reset the RTS pin
            %      setDTR(s, false);
            
            try
                narginchk(2, 2);
            catch
                funcName = 'setDTR';
                throwAsCaller(MException(message...
                    ('serialport:serialport:IncorrectInputArgumentsSingular', ....
                    funcName, obj.CustomExamples.(funcName))));
            end
            
            try
                flag = varargin{1};
                setDTR(obj.Transport, flag);
            catch ex
                throwAsCaller(ex);
            end
        end
    end
    
    methods (Access = private)
        %% Private methods
        function setCustomDisplay(obj)
            % Set the matlabshared.testmeas.CustomDisplay properties
            obj.PropertyGroupList = {obj.SelectPropertyList, obj.CommunicationPropertiesList, ...
                obj.BytesAvailablePropertiesList, obj.AdditionalPropertiesList};
            obj.PropertyGroupNames = ["" "" "" ""];
        end

        function initProperties(obj, inputs)
            % INITPROPERITES Partial match contructor N-V pairs and assign
            % to properties
            p = inputParser;
            p.PartialMatching = true;
            addParameter(p, 'DataBits', 8, @isscalar);
            addParameter(p, 'Parity', 'none', @(x) validateattributes(x,{'char','string'},{'nonempty'}));
            addParameter(p, 'StopBits', 1, @isscalar);
            addParameter(p, 'FlowControl', 'none', @(x) validateattributes(x,{'char','string'},{'nonempty'}));
            addParameter(p, 'ByteOrder', 'little-endian', @(x) validateattributes(x,{'char','string'},{'nonempty'}));
            addParameter(p, 'Timeout', 10, @isscalar);
            parse(p, inputs{:});
            output = p.Results;
            
            % Set the properties.
            obj.DataBits  = output.DataBits;
            obj.Parity    = output.Parity;
            obj.StopBits  = output.StopBits;
            obj.FlowControl = output.FlowControl;
            obj.ByteOrder = output.ByteOrder;
            obj.Timeout   = output.Timeout;
        end
        
        function instrumentImpl = getInstrumentImpl(obj)
            % Creates and returns the Instance of InstrumentImpl for all
            % Instrument Functionalities.
            
            % Create the InstrumentImpl instance only if not previously
            % created.
            if isempty(obj.InstrumentImpl)
                try
                    obj.InstrumentImpl = ...
                        instrument.internal.InstrumentImpl(obj.Transport, obj.StringClient);
                catch ex
                    throwAsCaller(ex);
                end
            end
            instrumentImpl = obj.InstrumentImpl;
        end
    end

    methods (Hidden)
        function value = instrhwinfo(obj, propertyName)
            % instrhwinfo fucntion displays the properties of the serialport
            % object for instrhwinfo(s). For instrhwinfo(s, <propertyName>),
            % it displays the value of that particular proeprty.
            % E.g.
            % instrhwinfo(s, "BaudRate")
            % ans =
            %      9600
            try
                value = obj.(propertyName);
            catch ex
                throwAsCaller(ex);
            end
        end
    end

    methods (Static, Hidden)
        function result = clearPreferences()
            % Hidden method to clear all Preferences data for serialport.
            result = internal.SerialportPrefHandler.clearPreferences();
        end
    end
    
    methods (Access = private, Hidden)
        
        %% Helper functions
        function displayReadWarning(obj, data, readType)
            % This helper function displays the read warning if a timeout
            % error occurs and the user gets some or no data from the serial
            % port.
            warningstr = '';
            warnData = 'nodata';
            docId = obj.DocIDNoData;
            
            % When some data is read
            if ~isempty(data)
                warnData = 'somedata';
                docId = obj.DocIDSomeData;
            end
            
            % Display the warning.
            warningstr = ...
                instrument.internal.warningMessagesHelpers. ...
                getReadWarning(warningstr, 'serialport', docId, warnData);
            warnState = warning('backtrace', 'off');
            messageId = sprintf('serialport:serialport:%sWarning', readType);
            warningstr = message(messageId, warningstr).getString;
            warning(messageId, warningstr);
            warning(warnState);
        end
        
        function value = validateTerminator(~, value)
            % Validate the terminator values
            if ~isnumeric(value)
                validateattributes(value, {'char', 'string'}, {'nonempty'}, ...
                    mfilename, 'Terminator');
                value = validatestring(value, ["LF", "CR", "CR/LF"], mfilename, 'Terminator');
            else
                validateattributes(value, {'numeric'}, {'finite', 'scalar', 'nonempty', 'nonnegative', 'integer'}, ...
                    mfilename, "Terminator");
            end
        end
        
        function validateBytesAvailableMode(obj, mode, numargs)
            % This helper function checks for the proper formatting of the
            % configureCallback function.
            
            % If numargs == 2, this means the only possible
            % BytesAvailableFcnMode is "off". Error for other cases.
            % If numargs == 3, the only possibility of
            % BytesAvailableFcnMode is "terminator". Error for other cases.
            % If numargs == 4, the only possibility of
            % BytesAvailableFcnMode is "byte". Error for other cases.
            if (numargs == 2 && ~strcmpi(mode, 'off')) || ...
               (numargs == 3 && ~strcmpi(mode, 'terminator')) || ...
               (numargs == 4 && ~strcmpi(mode, 'byte'))

                throw(MException(message ...
                    ('serialport:serialport:IncorrectBytesAvailableModeSyntax', ...
                    obj.ConfigureCallbackExample ...
                    {obj.ConfigureCallbackMode.(mode)})));
            end
        end
        
        function data = convertNumericToDouble(~, data, precision)
            % This helper function represents numeric 'precision' type data
            % as double for any read operation.
            if ~strcmpi(precision, 'string') && ~strcmpi(precision, 'char')
                data = double(data);
            end
        end
        
        function callbackFunction(obj, ~, evt)
            % This is the callback function that gets fired whenever a bytes
            % available callback event occurs. The BytesAvailableFcn
            % contains the function handle for the specified callback
            % function, set in configureCallback.
            
            dataAvailableInfo = instrument.internal.DataAvailableInfo( ...
                obj.BytesAvailableFcnCount, evt.AbsTime);
            obj.BytesAvailableFcn(obj, dataAvailableInfo);
        end

        function updatePreferences(obj)
            % Helper function to update the preferences data for
            % Serialport.
            
            properties = obj.PrefsHandler.PreferencesPropertiesList;
            preferencesData = struct;
            for i = 1 : length(properties)
                preferencesData.(properties{i}) = obj.(properties{i});
            end
            obj.PrefsHandler.updatePreferences(preferencesData);
        end
        
        function setBytesAvailableFcnCount(obj, value)
            % Helper function to set the setBytesAvailableFcnCount.
            try
                validateattributes(value, {'numeric'}, {'scalar', 'nonzero', 'positive', 'integer', ...
                    'finite'}, 'serialport', 'BytesAvailableFcnCount');
                obj.Transport.BytesAvailableEventCount = value;
            catch ex
                throw(ex);
            end
        end
        
        function setBytesAvailableFcn(obj, value)
            % Helper function to set the BytesAvailableFcnLocal. The getter
            % for the BytesAvailableFcn property returns back the value of 
            % BytesAvailableFcnLocal.
            
            % This is for BytesAvailableFcn = []
            if isnumeric(value) && isempty(value)
                obj.BytesAvailableFcnLocal = function_handle.empty();
            elseif isa(value, 'function_handle')
                obj.BytesAvailableFcnLocal = value;
            else
                throw(MException(message ...
                    ('serialport:serialport:InvalidBytesAvailableFcn')));
            end
        end
        
        function setBytesAvailableFcnMode(obj, value)
            % Helper function to set the BytesAvailableFcnModeLocal. The
            % getter for the BytesAvailableFcnMode property returns back 
            % the value of BytesAvailableFcnLocal.
            validateattributes(value, {'char', 'string'}, {'nonempty'}, 'serialport', 'BytesAvailableFcnMode');
            value = validatestring(value, ["off", "byte", "terminator"], 'serialport', 'BytesAvailableFcnMode');
            obj.BytesAvailableFcnModeLocal = value;
        end
    end

    methods (Hidden, Access = ...
            {?internal.Serialport, ?instrument.internal.ITestable})

        function errorCallbackFunction(obj, ~, ex)
            % This is the callback function that gets fired whenever a
            % serialport device gets unplugged.
            if ~isempty(obj.ErrorOccurredFcn)
                obj.ErrorOccurredFcn(ex);
            else
                switch ex.ID
                    case 'seriallib:serial:lostConnectionState'
                        fprintf(2, message('serialport:serialport:ConnectionLost').getString());
                    otherwise
                        fprintf(2, ex.Message);
                end
                fprintf(2, newline);
            end
        end
    end

    %% Getters/Setters
    methods
        
        %% Getters
        function value = get.Port(obj)
            value = string(obj.Transport.Port);
        end

        function value = get.NumBytesAvailable(obj)
            value = obj.Transport.NumBytesAvailable;
        end

        function value = get.BytesAvailableFcn(obj)
            value = obj.BytesAvailableFcnLocal;
        end

        function value = get.BytesAvailableFcnCount(obj)
            value = obj.Transport.BytesAvailableEventCount;
        end

        function value = get.BytesAvailableFcnMode(obj)
            value = string(obj.BytesAvailableFcnModeLocal);
        end
        
        function value = get.Timeout(obj)
            value = obj.Transport.Timeout;
        end
        
        function value = get.BaudRate(obj)
            value = obj.Transport.BaudRate;
        end
        
        function value = get.FlowControl(obj)
            value = string(obj.Transport.FlowControl);
        end
        
        function value = get.Parity(obj)
            value = string(obj.Transport.Parity);
        end
        
        function value = get.StopBits(obj)
            value = obj.Transport.StopBits;
        end
        
        function value = get.ByteOrder(obj)
            value = string(obj.Transport.ByteOrder);
        end
        
        function value = get.DataBits(obj)
            value = obj.Transport.DataBits;
        end
        
        function value = get.Terminator(obj)
            value = obj.StringClient.UserTerminator;
        end
        
        function value = get.UserData(obj)
            value = obj.Transport.UserData;
        end
        
        function value = get.NumBytesWritten(obj)
            value = obj.Transport.NumBytesWritten;
        end
        
        function value = get.WriteComplete(obj)
            value = obj.Transport.WriteComplete;
        end

        %% Setters
        function set.Timeout(obj, value)
            try
                obj.Transport.Timeout = value;
            catch ex
                if ex.identifier == "Stream:timeout:invalidTime"
                    ex = MException(ex.identifier,message('serialport:serialport:IncorrectTimeout').getString);
                end
                throwAsCaller(ex);
            end
        end

        function set.BaudRate(obj, value)
            try
                % Validate the value.
                validateattributes(value, {'numeric'}, {'scalar', 'nonnegative', 'finite', ...
                    'nonzero', 'integer'}, mfilename, 'BaudRate');  
            catch
                throwAsCaller(MException(message( ...
                    'serialport:serialport:InvalidBaudRate')));
            end
            try
                obj.Transport.BaudRate = value;
            catch ex
                throwAsCaller(ex);
            end
        end

        function set.FlowControl(obj, value)
            try
                obj.Transport.FlowControl = value;
            catch ex
                throwAsCaller(ex);
            end
        end

        function set.Parity(obj, value)
            try
                obj.Transport.Parity = value;
            catch ex
                throwAsCaller(ex);
            end
        end

        function set.StopBits(obj, value)
            try
                obj.Transport.StopBits = value;
            catch ex
                throwAsCaller(ex);
            end
        end

        function set.DataBits(obj, value)
            try
                obj.Transport.DataBits = value;
            catch ex
                throwAsCaller(ex);
            end
        end

        function set.ByteOrder(obj, value)
            try
                obj.Transport.ByteOrder = value;
            catch ex
                throwAsCaller(ex);
            end
        end

        function set.UserData(obj, value)
            obj.Transport.UserData = value;
        end

        function set.ErrorOccurredFcn(obj, value)
            if isnumeric(value) && isempty(value)
                obj.ErrorOccurredFcn = function_handle.empty();
            elseif isa(value, 'function_handle')
                obj.ErrorOccurredFcn = value;
            else
                throwAsCaller(MException(message('serialport:serialport:InvalidErrorOccurredFcn')));
            end
        end

        % Setters for properties that throw an error when called.
        function set.Terminator(~, ~)
            throwAsCaller(MException(message('serialport:serialport:ReadOnlyProperty', ...
                'Terminator', 'configureTerminator')));
        end
        
        function set.BytesAvailableFcnCount(~, ~)
            throwAsCaller(MException(message('serialport:serialport:ReadOnlyProperty', ...
                'BytesAvailableFcnCount', 'configureCallback')));
        end
        
        function set.BytesAvailableFcnMode(~, ~)
            throwAsCaller(MException(message('serialport:serialport:ReadOnlyProperty', ...
                'BytesAvailableFcnMode', 'configureCallback')));
        end
        
        function set.BytesAvailableFcn(~, ~)
            throwAsCaller(MException(message('serialport:serialport:ReadOnlyProperty', ...
                'BytesAvailableFcn', 'configureCallback')));
        end
    end
end
