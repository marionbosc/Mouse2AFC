function PlotListener()

file_size = 40*1024*1024; % 40 MB mem-mapped file
m = createMMFile(tempdir, 'mmap_matlab_plot.dat', file_size);

last_iTrial = -1;
initialized_before=false;
while true
    iTrial = typecast(m.Data(1:4), 'uint32');
    if iTrial == last_iTrial
        pause(.1);
    else
        if last_iTrial + 1 ~= iTrial
            warning("Last iTrial: " + string(last_iTrial) + ...
                    " does't preceed current iTrial: ", string(iTrial));
        else
            disp("Processing iTrial: " + string(iTrial));
        end
        tic;
        [next_data_start, DataCustom] = loadSerializedData(m, 5);
        [next_data_start, TaskParametersGUI] = loadSerializedData(m, next_data_start);
        [next_data_start, TrialStartTimestamp] = loadSerializedData(m, next_data_start);
        deserialize_dur = toc;
        fprintf('Took %.3fs to deserialize string', deserialize_dur);

        if iTrial == 0 || ~initialized_before % First run
            % TODO: See if you need to disable the graphs again
            GUIHandles = initializeFigures();
            GUIHandles.OutcomePlot = MainPlot2(GUIHandles.OutcomePlot,'init',DataCustom,TaskParametersGUI,TrialStartTimestamp);
            initialized_before = true;
            % if ~initialized_before and iTrial ~= 0, then the loop will
            % repeate again now and will go to the else part
        else
            GUIHandles.OutcomePlot = MainPlot2(GUIHandles.OutcomePlot,'update',DataCustom,TaskParametersGUI,TrialStartTimestamp,iTrial);
        end
        last_iTrial = iTrial;
    end
end
end

function GUIHandles = initializeFigures()
close all;
Figures.OutcomePlot.Position = [200, 200, 1000, 400];
Figures.ParameterGUI.Position =  [9, 454, 1474, 562];

ProtocolFigures.SideOutcomePlotFig = figure('Position', Figures.OutcomePlot.Position,'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
GUIHandles.OutcomePlot.HandleOutcome = axes('Position',    [  .055          .15 .91 .3]);
GUIHandles.OutcomePlot.HandlePsycStim = axes('Position',    [2*.05 + 1*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleTrialRate = axes('Position',  [3*.05 + 2*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleFix = axes('Position',        [4*.05 + 3*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleST = axes('Position',         [5*.05 + 4*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleFeedback = axes('Position',   [6*.05 + 5*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleVevaiometric = axes('Position',   [7*.05 + 6*.08   .6  .1  .3], 'Visible', 'off');
end
