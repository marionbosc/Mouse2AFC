function [Trial, DV] = CalcAudClickTrain(Trial, StimulusOmega)
global TaskParameters;
% If a SumRates is 100, then click rate will a value between 0 and 100.
% The click rate is mean click rate in Hz to be used to generate Poisson
% click train.
% The sum of LeftClickRate + RightClickRate should be = SumRates
%TODO: Create LeftClickRate and RightClickRate as presistent variables
LeftClickRate = round(StimulusOmega.*TaskParameters.GUI.SumRates);
RightClickRate = round((1-StimulusOmega).*TaskParameters.GUI.SumRates);
% Generate an array of time points at which pulse pal will generate a tone.
LeftClickTrain = GeneratePoissonClickTrain(LeftClickRate, TaskParameters.GUI.StimulusTime);
RightClickTrain = GeneratePoissonClickTrain(RightClickRate, TaskParameters.GUI.StimulusTime);
%correct left/right click train
if ~isempty(LeftClickTrain) && ~isempty(RightClickTrain)
    LeftClickTrain(1) = min(LeftClickTrain(1),RightClickTrain(1));
    RightClickTrain(1) = min(LeftClickTrain(1),RightClickTrain(1));
elseif  isempty(LeftClickTrain) && ~isempty(RightClickTrain)
    % No left clicks train found. Use the first click from the right click train
    LeftClickTrain(1) = RightClickTrain(1);
elseif ~isempty(LeftClickTrain) &&  isempty(RightClickTrain)
    % No right clicks train found. Use the first click from the left click train
    RightClickTrain(1) = LeftClickTrain(1);
else
    % Both are empty, use the rate as a first click?
    LeftClickTrain = round(1/LeftClickRate*10000)/10000;
    RightClickTrain = round(1/RightClickRate*10000)/10000;
end

Trial.LeftClickTrain = LeftClickTrain;
Trial.RightClickTrain = RightClickTrain;
%  0 <= (left - right) / (left + right) <= 1
DV = (length(LeftClickTrain) - length(RightClickTrain))./(length(LeftClickTrain) + length(RightClickTrain));

end
