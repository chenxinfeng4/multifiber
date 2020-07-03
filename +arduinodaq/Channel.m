classdef Channel < matlab.mixin.CustomDisplay & matlab.mixin.SetGet & handle
    properties
        % type %
        functioname 
        
        % general %
        Type
        ID
        % Counter Output Channel %
        Device = ''
        DutyCycle = 0.5
        Frequency = 100
        InitialDelay = 0
        MeasurementType
        Name = ''
        
        IdleState
        
    end
    methods(Access=protected)
        function displayNonScalarObject(objAry)       
            makeChannelTableDispaly(objAry);
        end
    end
    methods 
        function ch = Channel(functioname, channelID)
            assert(~isempty(channelID));
            assert(ismember(functioname, {'addCounterOutputChannel',  'addAnalogInputChannel'}));
            ch_prex = '';
            switch functioname
                case 'addCounterOutputChannel'
                    ch.MeasurementType = 'PulseGeneration';
                    ch.Type = 'co';
                    ch_prex = 'd';
                case 'addAnalogInputChannel'
                    ch.MeasurementType = 'Voltage (Ground)';
                    ch.Type = 'ai';
                    ch_prex = 'a';
                otherwise
                    ;
            end
            ch.functioname = functioname;
            if ischar(channelID) && contains(lower(channelID), 'ctr')
                ch.ID = [ch_prex, num2str(str2double(channelID(end))+2)]; %ctr0 -> d2
            elseif isnumeric(channelID)
                ch.ID = [ch_prex, num2str(channelID)];
            elseif ischar(channelID)
                channelID = lower(channelID);
                if(~isnan(str2double(channelID)))
                    ch.ID = [ch_prex, channelID];
                else
                    ch.ID = channelID;
                    assert(ch.ID(1) == ch_prex);
                end
            end
            
        end
        function ter = Terminal(ch)
            ter = ch.ID;
        end
        function makeChannelTableDispaly(objs)
            nch = length(objs);
            fprintf('   Number of channels: %.0f\n', nch);
            fprintf('\t%-6s %-6s %-8s %-8s %-20s %-5s %-10s\n','index', 'Type', 'Device', 'Channel', 'MeasurementType', 'Range', 'Name');
            fprintf(strrep(sprintf('\t%06s %06s %08s %08s %#020s %05s %010s\n','0', '0', '0', '0', '0', '0', '0'), '0', '-'));
            for i=1:nch
                ch = objs(i);
                rec = {i, ch.Type, 'Arduino', ch.ID, ch.MeasurementType, 'n/a', ch.Name};
                fprintf('\t%-6d %-6s %-8s %-8s %-20s %-5s %-10s\n', rec{:})
            end
        end
        function strl = getloggingstring(ch)
            switch ch.functioname
                case 'addCounterOutputChannel'
                    strl = sprintf('addCO(%s, %s, %s, %s)', ...
                                    ch.ID(2:end), num2str(ch.Frequency), num2str(ch.InitialDelay), num2str(ch.DutyCycle));
                case 'addAnalogInputChannel'
                    strl = sprintf('addAI(%s)', ch.ID(2:end));
                otherwise
                    ;
            end
        end
    end
    
end