import calendar
from collections import defaultdict, deque
import datetime as dt
import glob
import itertools as it
import numpy as np
from scipy.io import loadmat
import pandas as pd
from states import States, StartEnd
import sys

MIN_DF_COLS_DROP = ["States","drawParams","rDots", "visual", "Subject", "File",
                    "Protocol", ]

def loadFiles(files_patterns=["*.mat"], stop_at=10000, mini_df=False):
    # GUI_OmegaTable is important but has an a special a treatment.
    # See the extractGUI() function for more details.
    IMP_GUI_COLS = ["GUI_ExperimentType", "GUI_StimAfterPokeOut",
        "GUI_CatchError", "GUI_PercentCatch", "GUI_FeedbackDelayMax",
        "GUI_MinSampleType", "GUI_MinSample", "GUI_MinSampleMin",
        "GUI_MinSampleMax", "GUI_RewardAfterMinSampling", "GUI_StimulusTime",
        "GUI_FeedbackDelaySelection", "GUI_CalcLeftBias", "GUI_MouseState",
        "GUI_MouseWeight", "GUI_OptoBrainRegion", "GUI_OptoStartState1",
        ]

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
        diff_arrs = {"Difficulty1": [], "Difficulty2":[], "Difficulty3":[],
                     "Difficulty4": []}
        try:
            if isinstance(data.Custom.ChoiceLeft, (int, float, complex)) or \
               len(data.Custom.ChoiceLeft) <= 10:
                continue
            max_trials = np.uint16(len(data.Custom.ChoiceLeft))
            gui_dict = defaultdict(list)
            def extractGUI(trial_gui, gui_dict):
                for param_name in dir(trial_gui.GUI):
                    if param_name.startswith("__") or "field_names" in param_name:
                        continue
                    if param_name == "OmegaTable":
                        table = getattr(trial_gui.GUI, param_name)
                        # Non-zero omega-probailities entries are the ones that
                        # user chose to activate
                        if trial_gui.GUI.ExperimentType == 4:
                            if hasattr(table, "RDK"):
                                src_table = table.RDK
                            else:
                                src_table = table.Omega
                                table.Omega = (table.Omega - 50)*2
                        else:
                            src_table = table.Omega
                        diffs = src_table[np.where(table.OmegaProb)[0]]
                        # Ensure it's sorted in descending order
                        diffs = -np.sort(-diffs)
                        for i in range(4): # 0 -> 3
                            diff_val = diffs[i] if i < len(diffs) else np.nan
                            diff_arrs["Difficulty{}".format(i+1)].append(
                                                                       diff_val)
                    if mini_df and ("GUI_" + param_name) not in IMP_GUI_COLS:
                        continue
                    else:
                        gui_dict["GUI_" + param_name].append(
                                             getattr(trial_gui.GUI, param_name))

            deque(map(lambda trial_gui: extractGUI(trial_gui, gui_dict),
                      data.TrialSettings[:max_trials]))
            #print("GUI dict:", gui_dict)
            #feedback_type = list(map(lambda param:param.GUI.FeedbackDelaySelection,
            #                        data.TrialSettings))
            #catch_error = list(map(lambda param:param.GUI.CatchError,
            #                    data.TrialSettings))

            new_dict = {}
            filter_vals=["PulsePalParamStimulus","PulsePalParamFeedback",
                         "RewardMagnitude","_fieldnames","CatchCount",
                         "TrialStart","GracePeriod"]
            for field_name in dir(data.Custom):
                if field_name in filter_vals or field_name.startswith("__"):
                    continue
                field_val = getattr(data.Custom, field_name)
                if hasattr(field_val, "__len__"):
                    field_val = field_val[:max_trials]
                if field_name in ["GratingOrientation", "LightIntensityLeft",
                                  "LightIntensityRight", "DotsCoherence"] and \
                   len(field_val) == 0:
                    field_val = [np.nan] * max_trials
                new_dict[field_name] = field_val

            found_ReactionTime = "ReactionTime" in new_dict
            if not found_ReactionTime:
              reaction_times = []
            #print("Found ReactionTime:", found_ReactionTime)
            new_dict["TrialStartTimestamp"] = \
                                           data.TrialStartTimestamp[:max_trials]
            # Modifying a dictionary while looping on it is dangerous, however
            # hopefully it should be okay because we are just reassigning values
            for key in gui_dict.keys():
                gui_dict[key] = gui_dict[key][:max_trials]
            new_dict.update(gui_dict)
            new_dict.update(diff_arrs)
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

            def calcReactionAndMovementTimes(raw_events_li, trials_settings):
                reaction_times = []
                movement_times = []
                for idx, trial_states_events in enumerate(raw_events_li):
                  trial_states = trial_states_events.States
                  trial_events = trial_states_events.Events
                  # print("Matlab trial:", idx+1)
                  # Okay, ideally states and events should exist in certain
                  # sequences that we can even assert on. However, given enough
                  # animals and trials, eventually some wires get loose and some
                  # port{in/out} never get registered. So asserts are treated
                  # as warnings instead with Matlab trial number and filename.
                  if not np.isnan(trial_states.WaitForChoice[0]):
                    trial_ports = trials_settings[idx].GUI.Ports_LMRAir
                    l_port = (trial_ports//1000) % 10
                    c_port = (trial_ports//100) % 10
                    r_port = (trial_ports//10) % 10
                    center_outs = getattr(trial_events,
                                          "Port{}Out".format(c_port),
                                          # Get -1 val as missing portout should
                                          # indicate a timeout_misside_choice.
                                          -1)
                    if isinstance(center_outs, (int, float, complex)):
                      center_outs = np.array([center_outs])
                    # In some very rare cases, the animal would go out during
                    # BeepMinSampling ad we would never have a
                    # CenterPortRewardDeliver state.
                    reaction_start =  trial_states.CenterPortRewardDelivery[-1]
                    if np.isnan(reaction_start):
                      reaction_start = trial_states.BeepMinSampling[-1]
                    post_stim_out = center_outs[center_outs >= reaction_start]
                    if len(post_stim_out) is 0:
                      if np.isnan(trial_states.timeOut_missed_choice[0]):
                        print("Unexpected states (2) found in Matlab trial: {} "
                              "- file: {}".format(idx+1, fp), file=sys.stderr)
                      reaction_times.append(np.nan)
                      movement_times.append(np.nan)
                      # No need to continue here, but for verbosity
                      continue
                    else:
                      reaction_end = post_stim_out[0]
                      reaction_times.append(reaction_end - reaction_start)
                      if np.isnan(trial_states.timeOut_missed_choice[0]):
                        lr_ins = np.array([])
                        for port in [l_port, r_port]:
                          ins = getattr(trial_events, "Port{}In".format(port),
                                        [])
                          if type(ins) == float:
                            ins = [ins]
                          lr_ins = np.append(lr_ins, ins)
                        lr_ins = np.array(lr_ins)
                        first_post_stim_in = lr_ins[lr_ins > reaction_end]
                        if len(first_post_stim_in) < 1:
                          print("Unexpected states (3) found in Matlab "
                                "trial: {} - file: {}".format(idx+1, fp),
                                file=sys.stderr)
                          movement_times.append(np.nan)
                          continue
                        else:
                          first_post_stim_in = first_post_stim_in[0]
                          movement_times.append(first_post_stim_in - reaction_end)
                      else:
                        movement_times.append(np.nan)
                  else:
                    if not np.isnan(trial_states.early_withdrawal[0]) and \
                       not np.isnan(trial_states.broke_fixation[0]):
                      print("Unexpected states (1) found in Matlab trial: {} - "
                            "file: {}".format(idx+1, fp), file=sys.stderr)
                    reaction_times.append(np.nan)
                    movement_times.append(np.nan)
                assert len(reaction_times) == max_trials
                assert len(movement_times) == max_trials
                return reaction_times, movement_times

            for perf_key, dest_key in [("AllPerformance", "SessionAllPerformance"),
                                       ("Performance", "SessionPerformance")]:
                perf_exists = hasattr(data.TrialSettings[max_trials-1].GUI,
                                      perf_key)
                if perf_exists:
                    perf_str = getattr(data.TrialSettings[max_trials-1].GUI,
                                       perf_key)
                    perf = float(perf_str.split('%')[0])
                else:
                    perf = float('nan')
                new_dict[dest_key] = perf

            new_dict["MaxTrial"] = max_trials
            if not mini_df:
                trials_states = list(map(extractStates,
                                     data.RawEvents.Trial[:max_trials]))
                if len(trials_states) == max_trials + 1: # Needed for old files
                    trials_states = trials_states[:-1]
                new_dict["States"] = trials_states
            if not found_ReactionTime:
                new_dict["ReactionTime"] = [np.nan] * max_trials
            calcRT, calcMT = calcReactionAndMovementTimes(
                                              data.RawEvents.Trial[:max_trials],
                                              data.TrialSettings[:max_trials])
            new_dict["calcReactionTime"] = calcRT
            new_dict["calcMovementTime"] = calcMT
            new_dict["File"] = fp
            # In couple of cases, I found some strange behavior where
            # data.Filename didn't match filepath. Probably due to human error
            # while handling OneDrive sync conflicts
            if not hasattr(data, "Filename") or \
              fp.rstrip(".mat").endswith(data.Filename):
                data.Filename = \
                           fp.rstrip("*.mat").replace('\\', '/').rsplit('/')[-1]
                print("Filename:", data.Filename)
            mouse, protocol, month_day, year, session_num = \
                                                     data.Filename.rsplit("_",4)
            # data.Custom.Subject can incorrectly computed (e.g name, vgat2.1 is
            # computed as just vgat2). We compute it from fileame instead.
            new_dict["Name"] = mouse
            month, day = month_day[:-2], int(month_day[-2:])
            date = dt.date(int(year), months_3chars.index(month), day)
            new_dict["Date"] = date
            session_num = session_num.lower() # e.g: Session1
            assert session_num.startswith("session")
            session_num = session_num.lstrip("session")
            assert session_num.isdigit()
            new_dict["SessionNum"] = np.uint8(session_num)
            if hasattr(data, "Protocol") and len(data.Protocol):
                protocol = data.Protocol
            # else use the older value of protocol we computed above
            print("Assigning protocol:", protocol)
            new_dict["Protocol"] = protocol
            if False:
                for key, val in new_dict.items():
                    if hasattr(val,"__len__"):
                        if len(val) != max_trials:
                            print("Key:", key, " - val.shape: ", len(val),
                                "- type:", type(val), "- expected?: ", max_trials)
            df2 = pd.DataFrame(new_dict)
            df2 = reduceTypes(df2)
            if mini_df:
                cols_to_keep = list(filter(lambda col:col not in MIN_DF_COLS_DROP,
                                           df2.columns))
                dropped_cols = set(df2.columns) - set(cols_to_keep)
                print("Dropping", dropped_cols, "columns. Remaining cols:",
                      len(cols_to_keep))#,":", df2.columns)
                #df2.drop(columns=cols_to_drop)
                df2 = df2[cols_to_keep]
        except Exception as e:
            print("Didn't process " + fp + " due to: " + str(e))
            import traceback
            traceback.print_exc()
            bad_files.append(fp)
            continue

        if len(df2) <= 5:
            print("Skipping short session", fp)
            continue

        df = pd.concat([df,df2],ignore_index=True,sort=False)
        count+=1
        if count == stop_at:
            break

    if len(bad_files):
        print("Didn't processing the following files as they looked different:")
        for fp in bad_files:
            print("- ", fp)
        print()

    df = reduceTypes(df)
    return df

def reduceTypes(df, debug=False):
    for col_name in df.select_dtypes(include=['object']):
        if col_name in ["States", "Date", "GUI_OmegaTable"]: continue
        df[col_name] = df[col_name].astype(str)
    for col_name in df.columns:
        # print("Col:", col_name, "- type:", str(df[col_name].dtype))
        if str(df[col_name].dtype) == 'object':
            try:
                temp = df[col_name].copy()
                temp[temp == 'nan'] = np.nan
                df[col_name] = pd.to_numeric(temp, downcast='float',
                                             errors='raise')
            except Exception as e:
                # print("Failed with:" + str(e))
                pass
            else:
                if debug:
                    print("Converted str '"+str(col_name)+"' to float")
    # Ignore converting floats, we get bigger files but at least we don't
    # introduce potetial rounding errors
    # for col_name in df.select_dtypes(include=['float64']):
    #     # Leave DV and StimulusOmega as they are sensitive to rounding
    #     if col_name in ["StimulusOmega", "DV", "LeftClickTrian",
    #                     "RightClickTrian"]:
    #         continue
    #     df[col_name] = df[col_name].astype('float32')

    # We would like to have boolean values with null entries, this is easier
    # said than done. We can either leave them as float32 (but we should makes
    # sure it is not string of floats) or convert them to a pandas Nullable
    # Integer type. The problem with the latter is that they seem not to play
    # nicely with matploblib or rather less known libraries like statsmodels.
    # For now, I'll leave them as float32.
    # for col_name in df.columns:
    #     unique_vals = df[col_name].unique()
    #     for val in unique_vals:
    #         # Simple try/except float casting won't work in cases where it's
    #         # empty string or empty brackets. Do this semi=manual check instead.
    #         if (type(val) == str and (val.upper() == "NAN" or
    #                                   val.replace('.','').isdigit())) \
    #            or isinstance(val,(np.floating, float)):
    #             #str_val = str(val).upper()
    #             #if str_val != "NAN" and not str_val.replace(".","").isdigit():
    #             #    continue
    #             float_val = float(val)
    #             if float_val in [0, 1] or np.isnan(float_val):
    #                 continue
    #         # If we reached here then we've fallen out of the nested if-s
    #         if debug:
    #             print("Not converting '"+str(col_name)+"' because of", val,
    #                 "of type", type(val), "- Unique values:",
    #                 "{}".format(unique_vals if len(unique_vals) < 10 else "{Many}"))
    #         break # It's not a boolean type
    #     else:
    #         # Don't use 'bool' or normal int values because they don't maintain
    #         # NaN values. Use instead one of pandas "Nullable Integer" classes,
    #         # If you are usig pandas > v1.0.x the new 'boolean' pandas type.
    #         if debug:
    #             print("Converting '"+str(col_name)+ "' with unique values:",
    #                   unique_vals)
    #         # Do it on two steps, else it sometimes complain it can't jump from
    #         # String to Int8
    #         df[col_name] = df[col_name].astype(np.float32)
    #         df[col_name] = df[col_name].astype('Int8')
    for col_name in df.select_dtypes(include=['int64']):
        if 0 <= df[col_name].min() and df[col_name].max() <= 255:
            df[col_name] = df[col_name].astype(np.uint8)
        else:
            df[col_name] = df[col_name].astype(np.int16)
    return df

if __name__ == "__main__":
    import sys
    import time
    name = sys.argv[1] + time.strftime("_%Y_%m_%d.dump")
    print("Potential Resulting name:", name)
    # python mat_reader.py AnimalName "*_Thy[1-3]*.mat" "*WT[1-9]_*.mat" "N[1-4]_Mouse2AFC_[Ja,Fe,Ma,Ap,Ma,Ju,Ju]*.mat"
    # DATA1="../BpodUser/Data/"; DATA2="/Mouse2AFC/Session Data/"; python mat_reader.py RDK_conf_evd_accum_2019_11_20 "${DATA1}/*RDK_Thy2/${DATA2}*.mat" "${DATA1}/*RDK_WT [1,4,6]/${DATA2}*.mat" "${DATA1}/wfThy*/${DATA2}*.mat
    df = loadFiles(sys.argv[2:], mini_df=True)

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