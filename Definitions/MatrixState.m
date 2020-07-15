classdef MatrixState
    properties (Constant)
        ITI_Signal = 1;
        WaitForCenterPoke = 2;
        PreStimReward = 3;
        TriggerWaitForStimulus = 4;
        WaitForStimulus = 5;
        StimDelayGrace = 6;
        broke_fixation = 7;
        stimulus_delivery = 8;
        early_withdrawal = 9;
        BeepMinSampling = 10;
        CenterPortRewardDelivery = 11;
        TriggerWaitChoiceTimer = 12;
        WaitCenterPortOut = 13;
        WaitForChoice = 14;
        WaitForRewardStart = 15;
        WaitForReward = 16;
        RewardGrace = 17;
        Reward = 18;
        WaitRewardOut = 19;
        RegisterWrongWaitCorrect = 20;
        WaitForPunishStart = 21;
        WaitForPunish = 22;
        PunishGrace = 23;
        Punishment = 24;
        timeOut_EarlyWithdrawal = 25;
        timeOut_EarlyWithdrawalFlashOn = 26;
        timeOut_IncorrectChoice = 27;
        timeOut_SkippedFeedback = 28;
        timeOut_missed_choice = 29;
        ITI = 30;
        ext_ITI = 31;
    end
    properties (Constant, Access = private)
        asStr = MatrixState.String();
    end
    methods(Static)
        function string = String(varargin)
            if isempty(varargin)
                string = properties(MatrixState)';
            else
                string = MatrixState.asStr{varargin{1}};
            end
        end
    end
end