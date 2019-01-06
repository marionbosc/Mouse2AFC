classdef Const
   properties (Constant)
       % The number of trials that are automatically generated when the
       % protocol starts. These trials are built as easy trials.
       NUM_EASY_TRIALS = 2;
       % When a trial is a catch trial, the variable is the the time to
       % allow the animal to poke (if the animal poked into the correct
       % port) before signaling  a new trial
       FEEDBACK_CATCH_CORRECT_SEC = 20;
       % When a trial is a catch trial, the variable is the the time to
       % allow the animal to poke (if the animal poked into the incorrect
       % port) before signaling  a new trial
       FEEDBACK_CATCH_INCORRECT_SEC = 20;
       % When min. sampling time increment is enabled, the variable
       % defines how many last trials should be considered when calculating
       % the new sampling time.
       SAMPLE_LEARN_HISTORY = 50; % TODO: Use this variable
       % If bias correction is enabled, the value is the minimum numbers of
       % rewarded trials that must exist before we start making any
       % bias-correction
       BIAS_CORRECT_MIN_RWD_TRIALS = 10;
       % The number of trials that will be pre-generated ahead
       % Choose this number as even to guarantee equal distribution of
       % trials direction to left and right
       PRE_GENERATE_TRIAL_COUNT = 6;
       % The minimum number of trials that are left before we generate new
       % ones.
       % E.g, if iTrial = 10, PRE_GENERATE_TRIAL_CHECK = 2 and
       % PRE_GENERATE_TRIAL_COUNT = 6 and number of pre-generated trials
       % are 13. Then if iTrial (10) + PRE_GENERATE_TRIAL_CHECK(2) >= 13?,
       % if not (as in this case), then no pre-generated will be created.
       % When iTrial is = 13, then more pre-generated will be pre-generated
       % to reach (iTrial(13) + PRE_GENERATE_TRIAL_COUNT(6)) = 18,
       PRE_GENERATE_TRIAL_CHECK = 1;
   end
end
