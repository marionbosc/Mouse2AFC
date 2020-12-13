function DV = CalcGratingOrientation(trialNum, StimulusOmega)
global BpodSystem;
% We need to calculate a value between 0 and 360, the value will depend on
% the parameters in the GUI. We don't want to calculate it now as this
% function is called to pre-generate trials, so with each change the user
% will have to wait for multiple trials to see an effect. So for now, we
% just store the -ve value of the stimulus omega to denote that a stimulus
% should be drawn.
BpodSystem.Data.Custom.Trials(trialNum).GratingOrientation = -StimulusOmega;
DV = (StimulusOmega * 2) - 1;
end
