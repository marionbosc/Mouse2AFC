function DV = CalcAudClickTrain(trialNum)
global BpodSystem;
global TaskParameters;
% If a SumRates is 100, then click rate will a value between 0 and 100.
% The click rate is mean click rate in Hz to be used to generate Poisson
% click train.
% The sum of LeftClickRate + RightClickRate should be = SumRates
BpodSystem.Data.Custom.LeftClickRate(trialNum) = round(BpodSystem.Data.Custom.StimulusOmega(trialNum).*TaskParameters.GUI.SumRates);
BpodSystem.Data.Custom.RightClickRate(trialNum) = round((1-BpodSystem.Data.Custom.StimulusOmega(trialNum)).*TaskParameters.GUI.SumRates);
% Generate an array of time points at which pulse pal will generate a tone.
BpodSystem.Data.Custom.LeftClickTrain{trialNum} = GeneratePoissonClickTrain(BpodSystem.Data.Custom.LeftClickRate(trialNum), TaskParameters.GUI.StimulusTime);
BpodSystem.Data.Custom.RightClickTrain{trialNum} = GeneratePoissonClickTrain(BpodSystem.Data.Custom.RightClickRate(trialNum), TaskParameters.GUI.StimulusTime);
%correct left/right click train
if ~isempty(BpodSystem.Data.Custom.LeftClickTrain{trialNum}) && ~isempty(BpodSystem.Data.Custom.RightClickTrain{trialNum})
    BpodSystem.Data.Custom.LeftClickTrain{trialNum}(1) = min(BpodSystem.Data.Custom.LeftClickTrain{trialNum}(1),BpodSystem.Data.Custom.RightClickTrain{trialNum}(1));
    BpodSystem.Data.Custom.RightClickTrain{trialNum}(1) = min(BpodSystem.Data.Custom.LeftClickTrain{trialNum}(1),BpodSystem.Data.Custom.RightClickTrain{trialNum}(1));
elseif  isempty(BpodSystem.Data.Custom.LeftClickTrain{trialNum}) && ~isempty(BpodSystem.Data.Custom.RightClickTrain{trialNum})
    % No left clicks train found. Use the first click from the right click train
    BpodSystem.Data.Custom.LeftClickTrain{trialNum}(1) = BpodSystem.Data.Custom.RightClickTrain{trialNum}(1);
elseif ~isempty(BpodSystem.Data.Custom.LeftClickTrain{trialNum}) &&  isempty(BpodSystem.Data.Custom.RightClickTrain{trialNum})
    % No right clicks train found. Use the first click from the left click train
    BpodSystem.Data.Custom.RightClickTrain{trialNum}(1) = BpodSystem.Data.Custom.LeftClickTrain{trialNum}(1);
else
    % Both are empty, use the rate as a first click?
    BpodSystem.Data.Custom.LeftClickTrain{trialNum} = round(1/BpodSystem.Data.Custom.LeftClickRate*10000)/10000;
    BpodSystem.Data.Custom.RightClickTrain{trialNum} = round(1/BpodSystem.Data.Custom.RightClickRate*10000)/10000;
end

%  0 <= (left - right) / (left + right) <= 1
DV = (length(BpodSystem.Data.Custom.LeftClickTrain{trialNum}) - length(BpodSystem.Data.Custom.RightClickTrain{trialNum}))./(length(BpodSystem.Data.Custom.LeftClickTrain{trialNum}) + length(BpodSystem.Data.Custom.RightClickTrain{trialNum}));

end