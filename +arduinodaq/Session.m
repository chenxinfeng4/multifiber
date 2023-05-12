classdef Session < matlab.mixin.CustomDisplay & matlab.mixin.SetGet & handle
    properties
        UserData
        Rate = 1000 %'useless'
        NotifyWhenDataAvailableExceeds %'userless'
        Vendor
        Channels = arduinodaq.Channel.empty
        port 
        Status 
        DurationInSeconds = 1
        IsContinuous = false
        IsRunning = false
        SerialObj = []
        TimerObj = timer('ExecutionMode','singleShot') 
    end
    events
        DataAvailable  %'useless'
        DataRequired   %'useless'
    end
    methods %useless
        function queueOutputData(s, ~, ~)
            
        end
        function t = addAnalogOutputChannel(s, ~, ~, ~)
            t = [];
        end
    end
    methods(Access=protected)
        function displayScalarObject(obj)  
            nch = length(obj.Channels);
            fprintf(['Data acquisition session using Arduino(TM) hardware:\n',...
                     '   Will run for 1 second (1000 scans) at 1000 scans/second.\n']);
            fprintf('   Device at: [%s]\n', obj.port);
            if nch == 0
                fprintf('   No channels have been added.\n');
            else
                obj.Channels.makeChannelTableDispaly();
            end
            footer = getFooter(obj);
            disp(footer)
        end
    end
    methods
        function s = Session(port)
            s.port = port;
            if ispc()
                s.port = upper(s.port);
            end
            assert(ismember(s.port, serialportlist));
            connectedSer = instrfindall('type', 'serial', 'Name', ['Serial-', s.port], 'Status', 'open');
            if ~isempty(connectedSer)
                warning('backtrace', 'off');warning('Serial port [%s]has been opened, now force to reconnect.', s.port);
                delete(connectedSer);
            end
            s.SerialObj = serial(s.port,'BaudRate',19200, 'Terminator', 'LF', ...
                                'InputBufferSize', 2048, 'OutputBufferSize', 2048);
            fopen(s.SerialObj);
            pause(2);
            s.arduinoConnectionCheck();
            s.Status = 'open';
            s.TimerObj.TimerFcn = @(obj,evt)s.stop();
        end
        function arduinoConnect(s)
            if ~isvalid(s.SerialObj)
                s.SerialObj = serial(s.port,'BaudRate',250000, 'Terminator', 'LF');
            end
            if strcmp(s.SerialObj.Status, 'closed')
                fopen(s.SerialObj);
                pause(2);
            end
        end
        function startBackground(s)
            startBackground_getready(s)
            startBackground_go(s)
        end
        function startBackground_getready(s)
            s.arduinoConnect();
            s.arduinoInitParamsUpload();
        end
        function startBackground_go(s)
            s.Status = 'open';
            s.IsRunning = true;
            fprintf(s.SerialObj, '<-b>');
            if s.IsContinuous 
                ; %nothing
            else
                s.TimerObj.StartDelay = s.DurationInSeconds;
                start(s.TimerObj);
            end
        end
        function arduinoConnectionCheck(s)
            serobj = s.SerialObj;
            serialEmptyCheck(serobj)
            fprintf(serobj, '<-h>');
            tline = fgetl(serobj);
            assert(strcmp(tline, '[Arduino daq for Matlab]'), 'Cannot cannect to Arduino daq for Matlab!');
            disp('Hand shake OK to [Arduino daq for Matlab]');
        end
        function arduinoInitParamsUpload(s)
            serobj = s.SerialObj;
            fprintf(serobj, '<-p^>');
            tline = fgetl(serobj); fprintf([tline,'\n']);
            assert(strcmp(tline, '[Parameters: Adding Channel Begin]'));
%             fprintf(serobj, 'addAnalogInputChannel(3)');
%             fprintf(serobj, 'addCounterOutputChannel(4, 101, 0.5, 0)');
            nch = length(s.Channels);
            for i=1:nch
                strparam = getloggingstring(s.Channels(i));
                if ~isempty(strparam)
                    fprintf(serobj, strparam);
                    pause(0.005);
                    fprintf(fgetl(serobj));
                end
            end
            while serobj.BytesAvailable
                fprintf(fgetl(serobj));
                pause(0.005);
            end
            fprintf(serobj, '<-pv>');
            tline = fgetl(serobj);
            disp(tline);
            assert(strcmp(tline, '[Parameters: Adding Channel End]'));
            disp('Parameters uploaded. Begin [Arduino daq for Matlab]');
        end
        function [ch,idx] = addAnalogInputChannel(s,deviceID,channelID,measurementType)
            if ~isempty(deviceID)
                fprintf('addAnalogInputChannel: "deviceID" is in vain, please set it as ''''!\n');
            end
            if exist('measurement', 'var') && (~isempty(measurementType) || ~strcmpi(measurementType, 'PulseGeneration'))
                fprintf('addCounterOutputChannel : "measurementType" is recetified as "Voltage"!\n');
            end
            ch = arduinodaq.Channel.empty;
            if ischar(channelID)
                nch = 1;
                ch = arduinodaq.Channel('addCounterOutputChannel', channelID);
            else
                nch = length(channelID);
                for i=1:nch
                    ch(i) = arduinodaq.Channel('addAnalogInputChannel', channelID(i));
                end
            end
            s.Channels(end+1:end+nch) = ch;
        end
        function [ch,idx] = addCounterOutputChannel(s,deviceID,channelID,measurementType)
            if ~isempty(deviceID)
                fprintf('addCounterOutputChannel : "deviceID" is in vain, please set it as ''''!\n');
            end
            if exist('measurement', 'var') && (~isempty(measurementType) || ~strcmpi(measurementType, 'PulseGeneration'))
                fprintf('addCounterOutputChannel : "measurementType" is recetified as "PulseGeneration"!\n');
            end
            ch = arduinodaq.Channel.empty;
            if ischar(channelID)
                nch = 1;
                ch = arduinodaq.Channel('addCounterOutputChannel', channelID);
            else
                nch = length(channelID);
                for i=1:nch
                    ch(i) = arduinodaq.Channel('addCounterOutputChannel', channelID);
                end
            end
            s.Channels(end+1:end+nch) = ch;
        end
        function removeChannel(s, idx)
            assert(isnumeric(idx), 'The "idx" should be numberic!');
            assert(length(s.Channels)>=max(idx), 'Invaliable channel index!');
            s.Channels(idx) = [];
        end
        function startForeground(s)
            s.arduinoConnect();
            s.arduinoInitParamsUpload();
            s.Status = 'open';
            pause(s.DurationInSeconds);
            stop(s)
        end
        function stop(s)
            s.IsRunning = false;
            tobj = s.TimerObj;
            if(strcmp(tobj.Running, 'on'))
                stop(tobj)
            end
            switch s.Status
                case 'open'
                    assert(strcmp(s.SerialObj.Status, 'open'))
                    fclose(s.SerialObj);
                    fopen(s.SerialObj);
                    pause(2);
                    s.Status = 'closed';
                case 'closed'
                    assert(strcmp(s.SerialObj.Status, 'open'))
%                     fclose(s.SerialObj);
%                     fopen(s.SerialObj);
                    fclose(s.SerialObj);
                    s.Status = 'deleted';
                case 'deleted'
                    assert(strcmp(s.SerialObj.Status, 'closed'))
            end
        end
        function delete(s)
            if isvalid(s.SerialObj)
                s.stop();
                s.stop();
            end
        end
    end
end

function serialEmptyCheck(serobj)
    assert(isvalid(serobj));
    assert(serobj.BytesToOutput == 0);
    if serobj.BytesAvailable
        warning('Not Empty Serial Port!')
        fread(serobj);
        assert(serobj.BytesAvailable == 0);
    end
end