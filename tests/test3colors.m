[adaptors, devices, formats, IDs] = getCameraHardware();
camDeviceN = 5;
handles.vid = videoinput(adaptors{camDeviceN}, IDs(camDeviceN), formats{camDeviceN});
handles.s = arduinodaq.createSession('com3');
handles.vid.FramesPerTrigger = 1; 
handles.vid.TriggerRepeat = Inf;
s= handles.s;
device.ID = ''; rate =15;
camCh = s.addCounterOutputChannel(device.ID, 'ctr0', 'PulseGeneration');
camCh.Frequency = rate;
camCh.InitialDelay = 0;
camCh.DutyCycle = 0.1;
disp(['Camera should be connected to ' camCh.Terminal]);

refCh = s.addCounterOutputChannel(device.ID, 'ctr1', 'PulseGeneration');
refCh.Frequency = rate / 3;
refCh.InitialDelay = 0 / rate + 0.005;
refCh.DutyCycle = 0.25;
disp(['Reference (405) LED should be connected to ' refCh.Terminal]);

sigCh = s.addCounterOutputChannel(device.ID, 'ctr2', 'PulseGeneration');
sigCh.Frequency = rate / 3;
sigCh.InitialDelay = 1 / rate + 0.005;
sigCh.DutyCycle = 0.25;
disp(['Signal (470) LED should be connected to ' sigCh.Terminal]);

sig2Ch = s.addCounterOutputChannel(device.ID, 'ctr3', 'PulseGeneration');
sig2Ch.Frequency = rate / 3;
sig2Ch.InitialDelay = 2 / rate + 0.005;
sig2Ch.DutyCycle = 0.25;
disp(['Signal (566) LED should be connected to ' sig2Ch.Terminal]);
%%
stop(handles.s); %cxf
stop(handles.vid);
%%
handles.s.IsContinuous = true;
src = getselectedsource(handles.vid);
src.TriggerSource = 'external';
src.TriggerActive = 'edge';
src.ExposureTime=0.02;
src.PixelType = 'mono16';
src.TriggerPolarity = 'positive';
triggerconfig(handles.vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');

start(handles.vid);

hfig = figure('position', [537 277 1257 460], 'menubar', 'none', 'visible', 'off');
haxs = [axes('position',[0.03 0.11 0.30 0.815]); ...
        axes('position',[0.36 0.11 0.30 0.815]); ...
        axes('position',[0.68 0.11 0.30 0.815]);
        ];
htFPS = uicontrol(hfig, 'style', 'text', 'position',[500 8 300 20],...
                  'ForegroundColor', [0 0 0], 'FontSize', 12);
htTIME = uicontrol(hfig, 'style', 'text', 'position',[100 8 300 20],...
                  'ForegroundColor', [0 0 0], 'FontSize', 12);
titlestr = {'Ref 405', 'Signal 470', 'Signal 565'};
hims = matlab.graphics.primitive.Image.empty(3,0);
for i=1:3
    axes(haxs(i));
    hims(i) = imshow(uint16(zeros(512)));
    title(titlestr{i});
end
axis(haxs, 'off')
axis(haxs, 'equal')
axis(haxs, 'ij')
set(hfig, 'visible', 'on')
image_sub = cell(3,1);

startBackground(handles.s);
tStart = tic();
while isvalid(hfig)
    tic
    for i=1:3
        image_sub{i} = getdata(handles.vid, 1, 'uint16');
    end
    for i=1:3
        if isvalid(hims(i)); set(hims(i), 'CData', image_sub{i}); end
    end
    et = toc(); tsum = toc(tStart);
    if isvalid(htFPS);set(htFPS, 'string', sprintf('%5.2f FPS / color', 1/et));end
    if isvalid(htTIME);set(htTIME, 'string', sprintf('%5.1f sec', tsum));end
end
% end cxf

%
stop(handles.vid);
stop(handles.s);
