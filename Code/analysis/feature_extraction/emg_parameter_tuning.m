function emg_parameter_tuning_gui()

fs = 10000;
P = default_emg_parameters();

[file,path] = uigetfile('*.mat','Select recording');
if file==0
    return
end

fullFile = fullfile(path,file);

fig = uifigure('Name','EMG Parameter Tuning','Position',[100 100 1200 700]);

ax = uiaxes(fig,'Position',[350 100 800 550]);

%% Parameter controls

uilabel(fig,'Position',[20 600 200 20],'Text','Envelope window (ms)');
envSlider = uislider(fig,'Position',[20 580 250 3],'Limits',[1 20],'Value',P.envWindowMs);

uilabel(fig,'Position',[20 540 200 20],'Text','Active percentile TA');
actSlider = uislider(fig,'Position',[20 520 250 3],'Limits',[10 95],'Value',P.act_prc);

uilabel(fig,'Position',[20 480 200 20],'Text','Active percentile MG');
actMGSlider = uislider(fig,'Position',[20 460 250 3],'Limits',[10 95],'Value',P.act_prc_MG);

uilabel(fig,'Position',[20 420 200 20],'Text','Fuse gap (ms)');
fuseSlider = uislider(fig,'Position',[20 400 250 3],'Limits',[1 100],'Value',P.fuse_gap_ms);

runButton = uibutton(fig,'Text','Run Pipeline','Position',[20 350 200 40]);

saveButton = uibutton(fig,'Text','Save Parameters','Position',[20 300 200 40]);

%% Callbacks

runButton.ButtonPushedFcn = @(~,~) run_pipeline();
saveButton.ButtonPushedFcn = @(~,~) save_params();

run_pipeline()

%% ---- pipeline execution ----

function run_pipeline()

P.envWindowMs = envSlider.Value;
P.act_prc = actSlider.Value;
P.act_prc_MG = actMGSlider.Value;
P.fuse_gap_ms = fuseSlider.Value;

[TT, snr, meta] = preprocess_and_label(fs,P, ...
    'fullFile', fullFile, ...
    'plot_figures', false);

t = seconds(TT.tDur);

cla(ax)
hold(ax,'on')

plot(ax,t,TT.TA_env,'b')
plot(ax,t,TT.MG_env,'r')

scatter(ax,t(snr.is_act),TT.TA_env(snr.is_act),10,'cyan','filled')
scatter(ax,t(snr.is_act_MG),TT.MG_env(snr.is_act_MG),10,'magenta','filled')

title(ax,'Pipeline output')
xlabel(ax,'Time (s)')
ylabel(ax,'Amplitude')

end

%% ---- save parameters ----

function save_params()

[file,path] = uiputfile('*.mat','Save parameter set');
if file==0
    return
end

params = P;
save(fullfile(path,file),'params')

end

end