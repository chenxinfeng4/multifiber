function varargout = fipgui(varargin)
% FIPGUI MATLAB code for fipgui.fig
%      FIPGUI, by itself, creates a new FIPGUI or raises the existing
%      singleton*.
%
%      H = FIPGUI returns the handle to a new FIPGUI or the handle to
%      the existing singleton*.
%
%      FIPGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in FIPGUI.M with the given input arguments.
%
%      FIPGUI('Property','Value',...) creates a new fipgui or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before fipgui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to fipgui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help fipgui

% Last Modified by GUIDE v2.5 05-Apr-2023 22:38:46

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @fipgui_OpeningFcn, ...
                   'gui_OutputFcn',  @fipgui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before fipgui is made visible.
function fipgui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to fipgui (see VARARGIN)

% Parameters
handles.computer_dependent_delay = 0.00015; % seconds
handles.sample_rate_factor = 10; % how much faster DAQ samples than camera
handles.plotLookback = 20;
handles.rate_txt_double = 30;
handles.settingsGroup = 'FIPGUI';

% Defaults
handles.masks = false;
handles.savepath = '.';
handles.savefile = get(handles.save_txt, 'String');
handles.callback_path = false;
handles.callback = @(x,y) false;
handles.calibColors = 'k';
handles.calibImg.cdata = false;


% Populate dropdowns
imaqreset();
[adaptors, devices, formats, IDs] = getCameraHardware();
nDevs = length(adaptors);
if nDevs == 0
    error('MATLAB IMAQ detected no available Orca camera devices to connect to. Fix this and restart MATLAB.');
end
options = {};
for i = 1:nDevs
        options{i} = [adaptors{i} ' ' devices{i} ' ' formats{i}];
end
set(handles.cam_pop, 'String', options);

% Recover settings from last time
grp = handles.settingsGroup;


set(handles.cam_pop, 'Value', getpref(grp, 'cam_pop', get(handles.cam_pop, 'Value')));
set(handles.cam_pop, 'Value', getpref(grp, 'cam_pop', get(handles.cam_pop, 'Value')));
save_txt =  getpref(grp, 'save_txt', get(handles.save_txt, 'String'));
if numel(save_txt) > 1 && save_txt(1) == '0' 
    save_txt = ''; 
    warning(['Invalid save text, setting to default value of ' save_txt]);
end
set(handles.save_txt, 'String',save_txt);
set(handles.callback_txt, 'String', getpref(grp, 'callback_txt', get(handles.callback_txt, 'String')));

% Setup DAQ
rate = handles.rate_txt_double;
fs = rate * handles.sample_rate_factor;
% devices = daq.getDevices();
% device = devices(1);
handles.dev.ID = 0;

if true
    s = arduinodaq.createSession('com3');
else
    s = daq.createSession('ni');
end
s.Rate = fs;
s.IsContinuous = true;
device.ID=0;
handles.cam_port='ctr0';
handles.ref_port='ctr1';
handles.sig_port='ctr2';
handles.sig2_port='ctr3';
handles.cam_expo = 0.024;
try
    camCh = s.addCounterOutputChannel(device.ID, handles.cam_port, 'PulseGeneration');
    camCh.Frequency = rate;
    camCh.InitialDelay = 0.004;
    camCh.DutyCycle = 0.1;
    disp(['Camera should be connected to ' camCh.Terminal]);

    refCh = s.addCounterOutputChannel(device.ID, handles.ref_port, 'PulseGeneration');
    refCh.Frequency = rate / 3;
    refCh.InitialDelay = 0 / rate + 0.000;
    refCh.DutyCycle = 0.30;
%     refCh.DutyCycle = 0.032/(1/refCh.Frequency);
    disp(['Reference (405) LED should be connected to ' refCh.Terminal]);

    sigCh = s.addCounterOutputChannel(device.ID, handles.sig_port, 'PulseGeneration');
    sigCh.Frequency = refCh.Frequency;
    sigCh.InitialDelay = 1 / rate + 0.000;
    sigCh.DutyCycle = refCh.DutyCycle;
    disp(['Signal (470) LED should be connected to ' sigCh.Terminal]);
    
    sigCh2 = s.addCounterOutputChannel(device.ID, handles.sig2_port, 'PulseGeneration');
    sigCh2.Frequency = refCh.Frequency;
    sigCh2.InitialDelay = 2 / rate + 0.000;
    sigCh2.DutyCycle = refCh.DutyCycle;
    disp(['Signal (565) LED should be connected to ' sigCh2.Terminal]);
    
catch e
    disp(e);
    error('Restart MATLAB');
end

% Enable analog input logging

% Enable analog output
 

% Workaround for s.IsRunning bug. (see main acquisition for details)
% Load and send a short AO waveform.
s.startBackground();
stop(s);

handles.camCh = camCh;
handles.refCh = refCh;
handles.sigCh = sigCh;
handles.sigCh2 = sigCh2;
handles.s = s;

% Setup camera
camDeviceN = get(handles.cam_pop, 'Value');
vid = videoinput(adaptors{camDeviceN}, IDs(camDeviceN), formats{camDeviceN});
src = getselectedsource(vid);
src.PixelType = 'mono16';
vid.FramesPerTrigger = 1; 
vid.TriggerRepeat = Inf;
vid.ROIPosition = [0 0 vid.VideoResolution];

handles.vid = vid;
handles.src = src;

% Some more updates based on the defaults loaded earlier
% Update save file information
[pathname, filename, ext] = fileparts(get(handles.save_txt, 'String'));
handles.savepath = pathname;
handles.savefile = [filename ext];

% Update callback file information
[pathname, filename] = fileparts(get(handles.callback_txt, 'String'));
addpath(pathname);
handles.callback_path = pathname;
[~, basename, ext] = fileparts(filename);
if strcmp(basename, '<None>')
    handles.callback = @(x,y) false;
else
    handles.callback = str2func(basename);
end

% Disable acquisition until calibration is run
set(handles.acquire_tgl, 'Enable', 'off');

% Choose default command line output for fipgui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);


% UIWAIT makes fipgui wait for user response (see UIRESUME)
% uiwait(handles.fipgui);


% --- Outputs from this function are returned to the command line.
function varargout = fipgui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in snap_btn.
function snap_btn_Callback(hObject, eventdata, handles)
% hObject    handle to snap_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
src = getselectedsource(handles.vid);
src.ExposureTime= handles.cam_expo;
src.TriggerSource = 'internal';
snapframe = getsnapshot(handles.vid);


% Display the frame
figure();
imagesc(snapframe);
colorbar();

% --- Executes on button press in calibframe_btn.
function calibframe_btn_Callback(hObject, eventdata, handles)
% hObject    handle to calibframe_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Run the camera and LED commands briefly to get illuminated frames
nFrames = 6;
i = 0;
res = get(handles.vid, 'VideoResolution');

roi_rough = round([res*0.32  res*0.32]);
frames = zeros(roi_rough(4), roi_rough(3), nFrames);
set(handles.vid, 'ROIPosition', roi_rough);


%triggerconfig(handles.vid, 'hardware', 'RisingEdge', 'EdgeTrigger');
src = getselectedsource(handles.vid);
src.TriggerSource = 'external';
src.TriggerActive = 'edge';
src.ExposureTime=handles.cam_expo*0.8;
disp(src.ExposureTime);
src.TriggerPolarity = 'positive';
triggerconfig(handles.vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');


% begin cxf
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
hpoints = matlab.graphics.chart.primitive.Line.empty(3,0);
for i=1:3
    axes(haxs(i)); hold on;
    hims(i) = imshow(uint16(zeros(512)));
    hpoint(i) = plot([nan, nan], [nan, nan], 'r.');
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
        [y_tick, x_tick] = find(image_sub{i} > 65000);
        if isvalid(hpoint(i)); set(hpoint(i), 'XData', x_tick, 'YDATA', y_tick);end
    end
    et = toc(); tsum = toc(tStart);
    if isvalid(htFPS);set(htFPS, 'string', sprintf('%5.2f FPS / color', 1/et));end
    if isvalid(htTIME);set(htTIME, 'string', sprintf('%5.1f sec', tsum));end
end
% end cxf

while i < nFrames
    i = i + 1;
    frames(:,:,i) = getdata(handles.vid, 1, 'uint16');
end

stop(handles.vid);
stop(handles.s);

calibframe = max(frames, [], 3);

% Fiber ROI GUI
calibOut = calibrationgui(calibframe);
masks = calibOut.masks;
handles.calibColors = calibOut.colors;
handles.calibImg = calibOut.figImg;
handles.labels = calibOut.labels;

% Use masks to determine how much we can crop
all_masks = any(masks, 3);
[rows, cols] = ind2sub(size(all_masks), find(all_masks));
roi_x =roi_rough(1); roi_y = roi_rough(2);
crop_roi = [min(cols)+roi_x, min(rows)+roi_y, max(cols) - min(cols) + 1, max(rows) - min(rows) + 1];
masks = masks(min(rows):max(rows), min(cols):max(cols), :);
handles.masks = logical(masks);
handles.vid.ROIPosition = crop_roi;
guidata(hObject, handles);

set(handles.acquire_tgl, 'Enable', 'on');
set(handles.calibframe_lbl, 'Visible', 'off');

% Update handles structure
guidata(hObject, handles);

% Get file paths for saving out put (auto-increment the file counter).
function [saveFile, calibFile, logAIFile] = get_save_paths(handles)
[~, basename, ext] = fileparts(handles.savefile);
datetimestr = char(string(datetime('now'), "yyyy-MM-dd_hh-mm-ss"));
saveFile = fullfile(handles.savepath, [datetimestr basename '.mat']);
calibFile = fullfile(handles.savepath, [datetimestr basename '_calibration.jpg']);
logAIFile = fullfile(handles.savepath, [datetimestr basename '_logAI.csv']);

% Validate settings
 
% --- Executes on button press in acquire_tgl.
function acquire_tgl_Callback(hObject, eventdata, handles)
% hObject    handle to acquire_tgl (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of acquire_tgl
state = get(hObject,'Value');
if state
    % Pre-check for valid analog output waveform 
    verify_callback_function(handles);    
    
    % Disable all settings
    confControls = [
        handles.snap_btn
        handles.calibframe_btn
        handles.save_txt
        handles.callback_txt
        handles.callback_clear_btn
        handles.callback_btn
        handles.save_btn];
    for control = confControls
        set(control, 'Enable', 'off');
    end
    
    % Re-label button
    set(hObject, 'String', 'Stop acquisition');

    % Snap a quick dark frame
    src = getselectedsource(handles.vid);
%     src.TriggerSource = 'internal';
%     darkframe = getsnapshot(handles.vid);

%     if ~any(handles.masks(:))
%         handles.masks = ones(handles.vid.VideoResolution);
%         darkOffset = mean(darkframe(:));
%     else
%         darkOffset = applyMasks(handles.masks, darkframe);
%     end

    nMasks = size(handles.masks, 3);
    ref = zeros(100, nMasks); sig = zeros(100, nMasks); sig2 = zeros(100, nMasks);
    rate = handles.rate_txt_double;
    lookback = handles.plotLookback;
    framesback = lookback * rate / 3;
    vid = handles.vid;
    s = handles.s;

    % Set up plotting
    if isfield(handles, 'plot_fig') && isvalid(handles.plot_fig)
        plot_fig = handles.plot_fig;
        clf(plot_fig);
    else
        plot_fig = figure('CloseRequestFcn', @uncloseable, ...
                        'pos',[855, 442, 802, 516], ...
                        'color', 'k', 'MenuBar', 'none', ...
                        'ToolBar', 'none');
        handles.plot_fig = plot_fig;
    end
    
    ha = tightSubplot(nMasks*2, 1, 0.02, 0.05, 0.10, plot_fig);
    hasig2 = ha(2:2:end);
    ha = ha(1:2:end);
    yyaxes = zeros(nMasks, 3);
    lyy = zeros(nMasks, 3);
    t = linspace(-lookback, 0, framesback);
    for k = 1:nMasks
        [yyax, lsigs, lref] = plotyy(ha(k), [0 0], [0 0], 0, 0);
        xlim(yyax(1), [-lookback 0]);
        xlim(yyax(2), [-lookback 0]);
        yyax(end+1) = hasig2(k);
        lsigs(2,1) = plot(hasig2(k),[0 0], [0 0]);
        linkprop(yyax,{'Xlim'});
        
        set(yyax([1,3]), 'Color', [0.1, 0.1, 0.1]);
        set(yyax(1:2), 'xtick', []);
        set(lsigs(1), 'Color', [0.47,0.67,0.19]); %green
        set(lsigs(2), 'Color', [0.85,0.33,0.10]); %red
        set(lref, 'Color', [0,0.45,0.74], 'LineWidth', 2);  %blue
        set(lsigs, 'LineWidth', 2);
%             set(l2, 'LineStyle', '--');

        set(yyax, {'ycolor'},{'w';'w';'w'});
        set(yyax, {'xcolor'},{'w';'w';'w'});
        ylabel(yyax(1), 'Signals 488', 'color', [0.47,0.67,0.19], 'fontsize',16);
        ylabel(yyax(2), 'Ref 405', 'color', [0,0.45,0.74], 'fontsize',16);
        ylabel(hasig2(k), 'Signal 565', 'color', [0.85,0.33,0.10], 'fontsize',16);
        setappdata(gca, 'LegendColorbarManualSpace' ,1);
        setappdata(gca, 'LegendColorbarReclaimSpace', 1);
        yyaxes(k,:) = yyax;
        lyy(k,:) = [lref; lsigs;];
        xlim(hasig2(k),  [-lookback 0]);
    end

%       triggerconfig(vid, 'hardware', 'RisingEdge', 'EdgeTrigger');
    src = getselectedsource(vid);
    src.TriggerSource = 'external';
    src.TriggerActive = 'edge';
    src.TriggerPolarity = 'positive';
    handles.cam_expo = 0.022;  %²É¼¯Ê±
    src.ExposureTime=handles.cam_expo;
    triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');

    start(vid);
    % Get save paths
    [saveFile, calibFile, logAIFile] = get_save_paths(handles);
    handles.startTime = now();

    % f2_sync_hook begin
    if handles.f2_sync_hook.Value
        write(handles.tcpc, uint8('start_record'));
    end
    
    iframe=0;
    guidata(hObject, handles);
    s.startBackground();
    
    while get(hObject,'Value') 
        if ~ s.IsRunning                
            set(hObject,'Value', false); % Exit loop if AO output just finished                
            break            
        end 

        try
            img_mult = permute(squeeze(getdata(vid, 3, 'uint16')),[3,1,2]);
        catch e
            % Most likely cause for getting here is the s.IsRunning bug: 
            %   without the workaround implemented above in init, the very
            %   first acquisition, if AO is enabled, will fail to stop 
            %   (s.IsRunning is True indefinitely despite the waveform
            %   having stopped). As a side effect, the synchronization
            %   of the AO waveform and digital counter channels appears
            %   to be consistently different.
            if iframe > 0
                disp('ERROR: AO and counters may not be synced. See s.IsRunning bug comments');
                warning('See s.IsRunning bug comments'); beep;
            end
            set(hObject,'Value', false); % Exit loop if AO output just finished
            break
        end

        iframe = iframe + 1;      % frame number 
        [M, N, D] = size(handles.masks);
        avgs = zeros(3, D);
        for i=1:3
            img = img_mult(i,:,:);
            avgs(i,:) = applyMasks(handles.masks, img);
        end
%             avgs = avgs - darkOffset;
        avgs = avgs * 10 / 65000;

        % Exponentially expanding matrix as per std::vector
        if iframe > size(ref, 1)
            szr = size(ref); 
            ref = [ref; zeros(szr)]; 
            sig = [sig; zeros(szr)]; 
            sig2 = [sig2; zeros(szr)];
        end

        ref(iframe,:) = avgs(1,:);
        sig(iframe,:) = avgs(2,:);
        sig2(iframe,:) = avgs(3,:);
        
        % Plotting
        ind = max(1, iframe-framesback+1):iframe;
        tlen = length(ind)-1;
        tnow = t(end-tlen:end);
        for k = 1:nMasks
            ref_wave= ref(ind,k);
            sig_wave= sig(ind,k);
            sig2_wave= sig2(ind,k);
            refmin = min(ref_wave);
            refmax = max(ref_wave); 
            sigmin = min(sig_wave);
            sigmax = max(sig_wave);
            sig2min = min(sig2_wave);
            sig2max = max(sig2_wave);

            % put axes on same scale, but allow zero to float
%             sigmin = max(min(sigmin, sig2min),0.001);
%             sigmax = max(max(sigmax, sig2max),0.002);

            % if max = min, don't try to update bounds
            ylim1 = min((refmin+refmax)/2 * 0.99, refmin);
            ylim2 = max((refmin+refmax)/2 * 1.01, refmax);
            ylim(yyaxes(k,2), [ylim1, ylim2]);
            set(yyaxes(k,2), 'ytick', linspace(ylim1, ylim2,5));
            
            ylim1 = min((sigmin+sigmax)/2 * 0.99, sigmin);
            ylim2 = max((sigmin+sigmax)/2 * 1.01, sigmax);
            ylim(yyaxes(k,1), [ylim1, ylim2]);
            set(yyaxes(k,1), 'ytick', linspace(ylim1, ylim2,5));
            
            ylim1 = min((sig2min+sig2max)/2 * 0.99, sig2min);
            ylim2 = max((sig2min+sig2max)/2 * 1.01, sig2max);
            ylim(hasig2(k), [ylim1, ylim2]);
            set(hasig2(k), 'ytick', linspace(ylim1, ylim2,5));
            
            set(lyy(k,1), 'XData', tnow, 'YData', ref_wave);
            set(lyy(k,2), 'XData', tnow, 'YData', sig_wave);
            set(lyy(k,3), 'XData', tnow, 'YData', sig2_wave);
        end

            % Check to make sure camera acquisition is keeping up.
        elapsed_time = (now() - handles.startTime);
        rate = handles.rate_txt_double;            
        if abs(elapsed_time*24*3600 - (iframe*3)/rate) > 2 % if camera acquisition falls behind more than 1 s...
            fraction_frames_acquired = iframe/(elapsed_time*24*3600*rate);                
            if iframe > 0
                disp(['fraction of frames acquired: ' num2str(fraction_frames_acquired)]);
                if abs(fraction_frames_acquired - 0.5) < 0.04
                    warning('ERROR: Only got half as many frames as expected. Most likely check trigger connections; less likely: select a smaller ROI or lower speed and try again. Last resort: increase handles.computer_dependent_delay');
                else
                    warning('ERROR: Camera acquisition fell behind! Select a smaller ROI or lower speed and try again. Last resort: increase handles.computer_dependent_delay'); beep;
                end
            end
            set(hObject,'Value', false);
            break
        end
        set(handles.elapsed_txt, 'String', datestr(elapsed_time, 'HH:MM:SS'));
    end
    disp('...acquisition complete.');
         
        % Stop acquisition
    stop(vid);
    s.stop();
    
    % f2_sync_hook stop
    if handles.f2_sync_hook.Value
        write(handles.tcpc, uint8('stop_record'));
    end
    
    set(handles.elapsed_txt, 'String', datestr(0, 'HH:MM:SS'));

    % Save data
    if iframe > 1
        save_data(ref(1:iframe,:), sig(1:iframe,:), sig2(1:iframe,:), handles.labels, rate, handles.calibImg.cdata, saveFile, calibFile);
    else            
        warning(['No frames captured or saved! Check camera trigger connection is ' handles.camCh.Terminal '. Then restart MATLAB.']); beep;
    end

    % Make the old plots closeable
    set(plot_fig, 'CloseRequestFcn', @closeable);
    
    % Re-enable all controls
    for control = confControls
        set(control, 'Enable', 'on');
    end
    
    % Re-label button
    set(hObject, 'String', 'Acquire data');
end

function  save_data(ref, sig, sig2, labels, framerate, cdata, saveFile, calibFile)
save(saveFile, 'sig', 'sig2', 'ref', 'labels', 'framerate', '-v7.3');
if any(cdata(:))
    imwrite(cdata, calibFile, 'JPEG');
end

   
function cam_pop_Callback(hObject, eventdata, handles)
% hObject    handle to cam_pop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cam_pop as text
%        str2double(get(hObject,'String')) returns contents of cam_pop as a double
% Setup camera
[adaptors, devices, formats, IDs] = getCameraHardware();
camDeviceN = get(hObject, 'Value');
vid = videoinput(adaptors{camDeviceN}, IDs(camDeviceN), formats{camDeviceN});
src = getselectedsource(vid);
vid.FramesPerTrigger = 1; 
vid.TriggerRepeat = Inf;

handles.vid = vid;
handles.src = src;

% Choose default command line output for fipgui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% Disable acquisition until calibration is run
set(handles.acquire_tgl, 'Enable', 'off');
set(handles.calibframe_lbl, 'Visible', 'on');


% --- Executes during object creation, after setting all properties.
function cam_pop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cam_pop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function save_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to save_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function callback_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to callback_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in save_btn.
function save_btn_Callback(hObject, eventdata, handles)
% hObject    handle to save_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[filename, pathname] = uiputfile('experiment.mat', 'Save experiment .mat file');
handles.savepath = pathname;
handles.savefile = filename;
set(handles.save_txt, 'String', fullfile([pathname filename]));

% Update handles structure
guidata(hObject, handles);


% --- Executes on button press in callback_btn.
function callback_btn_Callback(hObject, eventdata, handles)
% hObject    handle to callback_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[filename, pathname] = uigetfile('', 'Select a .m function file');
if handles.callback_path
    rmpath(handles.callback_path);
end
addpath(pathname);
handles.callback_path = pathname;
[~, basename, ext] = fileparts(filename);
handles.callback = str2func(basename);
set(handles.callback_txt, 'String', fullfile([pathname filename]));

% Update handles structure
guidata(hObject, handles);
verify_callback_function(handles);

function save_txt_Callback(hObject, eventdata, handles)
% hObject    handle to save_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of save_txt as text
%        str2double(get(hObject,'String')) returns contents of save_txt as a double
[path, file, ext] = fileparts(get(hObject,'String'));
handles.savepath = path;
handles.savefile = [file ext];

% Update handles structure
guidata(hObject, handles);

function callback_txt_Callback(hObject, eventdata, handles)
% hObject    handle to callback_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of callback_txt as text
%        str2double(get(hObject,'String')) returns contents of callback_txt as a double
[path, file, ext] = fileparts(get(hObject, 'String'));
if handles.callback_path
    rmpath(handles.callback_path);
end
addpath(path);
handles.callback_path = path;
handles.callback = str2func(file);

% Update handles structure
guidata(hObject, handles);

function verify_callback_function(handles)
    if handles.callback_path
        handles.callback(0,'test');
    end
    
% --- Executes on button press in callback_clear_btn.
function callback_clear_btn_Callback(hObject, eventdata, handles)
% hObject    handle to callback_clear_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.callback_path = false;
handles.callback = @(x,y) false;
set(handles.callback_txt, 'String', '<None>');

% Update handles structure
guidata(hObject, handles);


% --- Executes when user attempts to close fipgui.
function fipgui_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to fipgui (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Save settings for next time
grp = handles.settingsGroup;
setpref(grp, 'save_txt', get(handles.save_txt, 'String'));
setpref(grp, 'callback_txt', get(handles.callback_txt, 'String'));

% Hint: delete(hObject) closes the figure
delete(hObject);

function uncloseable(src, callbackdata)
% A dummy function that makes it impossible to close if used as the
% CloseRequestFcn
return

function closeable(src, callbackdata)
% Does the right thing (closes the figure) if used as the CloseRequestFcn
delete(src);

function f2_sync_hook_Callback(hObject, eventdata, handles)
tcpport = 20169;
if hObject.Value
    try
        tcpc = tcpclient("127.0.0.1",tcpport,'ConnectTimeout',1);
        handles.tcpc = tcpc;
    catch
        hObject.Value = false;
        warning('No f2_sync server is running.')
    end
end
guidata(hObject, handles);
