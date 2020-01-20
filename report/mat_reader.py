import calendar
from collections import defaultdict, deque
import datetime as dt
import glob
import itertools as it
import numpy as np
from scipy.io import loadmat
import pandas as pd
from states import States, StartEnd

def loadFiles(files_patterns=["*.mat"], stop_at=10000):
    #columns=["TrialNum","File","DV","ChoiceLeft","ChoiceCorrect","Feedback",
    #        "FeedbackTime","FeedbackDelay","FeedbackTrialSettings","CatchTrial",
    #        "CatchError"]
    if type(files_patterns) == str:
        files_patterns = [files_patterns]
    elif type(files_patterns) != list:
        raise Exception("File patterns argument must be of type list of " +
                        "strings, not " + str(type(files_patterns)))
    df = pd.DataFrame()

    months_3chars = list(calendar.month_abbr)
    count=1
    bad_files=[]
    import os
    chained_globs=it.chain.from_iterable(
                              glob.iglob(pattern) for pattern in files_patterns)
    #print("File patterns:", files_patterns)
    #chained_globs=list(chained_globs); print("Globs:", chained_globs)
    for fp in  chained_globs:
        print("Processing: " + fp)
        # Check the file is not a repeated file from one-drive
        # Good name e.g: M5_Mouse2AFC_Oct30_2018_Session1.mat
        should_only_num = fp.rsplit(".",1)[0].rsplit("Session",1)[1]
        try:
            int(should_only_num)
        except ValueError:
            print("Skipping badly formatted filename:", fp)
            bad_files.append(fp)
            continue
        mat = loadmat(fp, struct_as_record=False, squeeze_me=True)
        data = mat['SessionData']
        try:
            gui_dict = defaultdict(list)
            def extractGUI(trial_gui, gui_dict):
                for param_name in dir(trial_gui.GUI):
                    if not param_name.startswith("__") and "field_names" not in param_name:
                        gui_dict["GUI_" + param_name].append(
                                             getattr(trial_gui.GUI, param_name))

            deque(map(lambda trial_gui: extractGUI(trial_gui, gui_dict),
                     data.TrialSettings))
            #print("GUI dict:", gui_dict)
            #feedback_type = list(map(lambda param:param.GUI.FeedbackDelaySelection,
            #                        data.TrialSettings))
            #catch_error = list(map(lambda param:param.GUI.CatchError,
            #                    data.TrialSettings))

            new_dict = {}
            filter_vals=["PulsePalParamStimulus","PulsePalParamFeedback",
                         "RewardMagnitude","_fieldnames","CatchCount",
                         "TrialStart","GracePeriod"]
            max_trials = len(data.Custom.ChoiceLeft)
            for field_name in dir(data.Custom):
                if field_name in filter_vals or field_name.startswith("__"):
                    continue
                field_val = getattr(data.Custom, field_name)
                if hasattr(field_val, "__len__"):
                    field_val = field_val[:max_trials]
                if field_name in ["GratingOrientation", "LightIntensityLeft",
                                  "LightIntensityRight", "DotsCoherence"] and \
                   len(field_val) == 0:
                    field_val = [None] * max_trials
                new_dict[field_name] = field_val

            found_ReactionTime = "ReactionTime" in new_dict
            if not found_ReactionTime:
              reaction_times = []
            #print("Found ReactionTime:", found_ReactionTime)
            new_dict["TrialStartTimestamp"] = data.TrialStartTimestamp
            # Modifying a dictionary while looping on it is dangerous, however
            # hopefully it should be okay because we are just reassigning values
            for key in gui_dict.keys():
                gui_dict[key] = gui_dict[key][:max_trials]
            new_dict.update(gui_dict)
            #new_dict["CatchError"] = catch_error[:max_trials]
            #new_dict["FeedbackTrialSettings"] = feedback_type[:max_trials]
            def extractStates(trial):
                states = States()
                added=False
                for state_name in dir(trial.States):
                    if not state_name.startswith('_'):
                        start_end = StartEnd(getattr(trial.States, state_name))
                        setattr(states, state_name, start_end)
                        added=True
                        if not found_ReactionTime and state_name == 'WaitCenterPortOut':
                            if not np.isnan(start_end.end):
                                reaction_times.append(start_end.end - start_end.start)
                            else:
                                reaction_times.append(-1) # Match what we write in MATLAB
                if not added:
                    print("States:", dir(trial.States))
                return states
            if "GUI_AllPerformance" in new_dict:
                session_all_performance = new_dict["GUI_AllPerformance"][max_trials-1].split('%')[0]
                new_dict['SessionAllPerformance'] = float(session_all_performance)
            if "GUI_Performance" in new_dict:
                session_performance = new_dict["GUI_Performance"][max_trials-1].split('%')[0]
            else:
                session_performance = float('nan')
            new_dict['SessionPerformance'] = float(session_performance)
            new_dict["MaxTrial"] = max_trials
            trials_states = list(map(extractStates, data.RawEvents.Trial))
            if len(trials_states) == max_trials + 1: # Needed for old files
                trials_states = trials_states[:-1]
            new_dict["States"] = trials_states
            if not found_ReactionTime:
                new_dict["ReactionTime"] = reaction_times if len(reaction_times) else [None] * max_trials
            new_dict["File"] = fp
            mouse, protocol, month_day, year, session_num = fp.rsplit("_",4)
            new_dict["Name"] = data.Custom.Subject
            month, day = month_day[:-2], int(month_day[-2:])
            date = dt.date(int(year), months_3chars.index(month), day)
            new_dict["Date"] = date
            new_dict["SessionNum"] = int(session_num[7]) # Session1.mat
            protocol = data.Protocol if hasattr(data, "Protocol") else protocol
            print("Assigning protocol:", protocol)
            new_dict["Protocol"] = protocol
            if False:
                for key, val in new_dict.items():
                    if hasattr(val,"__len__"):
                        if len(val) != max_trials:
                            print("Key:", key, " - val.shape: ", len(val),
                                "- type:", type(val), "- expected?: ", max_trials)
            df2 = pd.DataFrame(new_dict)
        except Exception as e:
            print("Didn't process " + fp + " due to: " + str(e))
            import traceback
            traceback.print_exc()
            bad_files.append(fp)
            continue

        df = pd.concat([df,df2],ignore_index=True)
        count+=1
        if count == stop_at:
            break

    if len(bad_files):
        print("Didn't processing the following files as they looked different:")
        for fp in bad_files:
            print("- ", fp)
        print()

    return df

if __name__ == "__main__":
    import sys
    import time
    name = sys.argv[1] + time.strftime("_%Y_%m_%d.dump")
    print("Potential Resulting name:", name)
    # python mat_reader.py AnimalName "*_Thy[1-3]*.mat" "*WT[1-9]_*.mat" "N[1-4]_Mouse2AFC_[Ja,Fe,Ma,Ap,Ma,Ju,Ju]*.mat"
    # DATA1="../BpodUser/Data/"; DATA2="/Mouse2AFC/Session Data/"; python mat_reader.py RDK_conf_evd_accum_2019_11_20 "${DATA1}/*RDK_Thy2/${DATA2}*.mat" "${DATA1}/*RDK_WT [1,4,6]/${DATA2}*.mat" "${DATA1}/wfThy*/${DATA2}*.mat
    df = loadFiles(sys.argv[2:])

    name = sys.argv[1] + df.Date.min().strftime("_%Y_%m_%d_to_") + df.Date.max().strftime("%Y_%m_%d.dump")
    print("Final name:", name)
    df.to_pickle(name)
    sys.exit(0)
    #df.to_pickle("all_rdk_2019_08_06.dump")
    import code
    try:
        import readline
    except ImportError:
      import pyreadline as readline
    import rlcompleter
    vars = dict(globals(), **locals())
    readline.set_completer(rlcompleter.Completer(vars).complete)
    readline.parse_and_bind("tab: complete")
    code.InteractiveConsole(vars).interact()