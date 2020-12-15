function [Trials, DVsAlreadyGenerated] = AssignFutureTrials(Trials, GUI,...
                            DVsAlreadyGenerated, NumTrialsToGenerate, LeftBias)

% make future trials
lastidx = DVsAlreadyGenerated;
% Generate guaranteed equal possibility of >0.5 and <0.5
IsLeftRewarded = [zeros(1, round(NumTrialsToGenerate*LeftBias)) ones(1, round(NumTrialsToGenerate*(1-LeftBias)))];
% Shuffle array and convert it
IsLeftRewarded = IsLeftRewarded(randperm(numel(IsLeftRewarded))) > LeftBias;
for a = 1:NumTrialsToGenerate
    % If it's a fifty-fifty trial, then place stimulus in the middle
    if rand(1,1) < GUI.Percent50Fifty && (lastidx+a) > GUI.StartEasyTrials % 50Fifty trials
        StimulusOmega = 0.5;
    else
        if GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.BetaDistribution
            % Divide beta by 4 if we are in an easy trial
            BetaDiv = iff((lastidx+a) <= GUI.StartEasyTrials, 4, 1);
            StimulusOmega = betarnd(GUI.BetaDistAlphaNBeta/BetaDiv,GUI.BetaDistAlphaNBeta/BetaDiv,1,1);
            StimulusOmega = iff(StimulusOmega < 0.1, 0.1, StimulusOmega); %prevent extreme values
            StimulusOmega = iff(StimulusOmega > 0.9, 0.9, StimulusOmega); %prevent extreme values
        elseif GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.DiscretePairs
            if (lastidx+a) <= GUI.StartEasyTrials
                index = find(GUI.OmegaTable.OmegaProb > 0, 1);
                StimulusOmega = GUI.OmegaTable.Omega(index)/100;
            else
                % Choose a value randomly given the each value probability
                StimulusOmega = randsample(GUI.OmegaTable.Omega,1,1,GUI.OmegaTable.OmegaProb)/100;
            end
        else
            assert(false, 'Unexpected StimulusSelectionCriteria');
        end
        % In case of beta distribution, our distribution is symmetric,
        % so prob < 0.5 is == prob > 0.5, so we can just pick the value
        % that corrects the bias
        if (IsLeftRewarded(a) && StimulusOmega < 0.5) || (~IsLeftRewarded(a) && StimulusOmega >= 0.5)
            StimulusOmega = -StimulusOmega + 1;
        end
    end

    Trial = Trials(lastidx+a);
    Trial.StimulusOmega = StimulusOmega;
    [Trial, DV] = CalcTrialDV(Trial, GUI.ExperimentType, StimulusOmega);
    Trial.DV = DV;
    if DV > 0
        Trial.LeftRewarded = 1;
    elseif DV < 0
        Trial.LeftRewarded = 0;
    else
        Trial.LeftRewarded = rand<0.5; % It's equal distribution
    end
    % cross-modality difficulty for plotting
    %  0 <= (left - right) / (left + right) <= 1
    Trial.DV = DV;
    Trials(lastidx+a) = Trial;
end%for a=1:5
DVsAlreadyGenerated = DVsAlreadyGenerated + NumTrialsToGenerate;

end
