import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from analysis import splitByDV, savePlot

def trimSessions(df, offset_from_start, offset_from_end,
                 use_MaxTrial=True):
  filtered_dfs = []
  for (data, sess_num, animal_name), sess_df in df.groupby(
                          [df.Date, df.SessionNum, df.Name]):
    max_trial = sess_df.MaxTrial if use_MaxTrial else sess_df.TrialNumber.max()
    sess_df = sess_df[(offset_from_start <= sess_df.TrialNumber) &
                      (sess_df.TrialNumber <= max_trial)]
    filtered_dfs.append(sess_df)
  return pd.concat(filtered_dfs)

def metricByOpto(df, *, trim_start, trim_end, min_count_per_animal_group,
                 save_figs, save_prefix=""):
  from definitions import BrainRegion, MatrixState
  res_dict = {"Name":[], "Metric":[], "BrainRegion": [], "StartState":[],
              "DV":[]}
  for category_type in ("All", "Correct", "Incorrect"):
    for stat_name in ("Mean", "SEM", "Count"):
      res_dict[f"Control{category_type}{stat_name}"] = []
      res_dict[f"Opto{category_type}{stat_name}"] = []

  df = trimSessions(df, trim_start, trim_end)
  BinaryFlag = 1
  NotBinaryFlag = 0
  df_cols = [("calcReactionTime", NotBinaryFlag, ("ChoiceLeft",)),
             ("EarlyWithdrawal", BinaryFlag, ("FixBroke", 0))]
  for (brain_region, start_state), region_df in df.groupby(
                          [df.GUI_OptoBrainRegion, df.GUI_OptoStartState1]):
    brain_region = str(BrainRegion(brain_region))
    start_state = str(MatrixState(start_state))
    for dv_range, single_dv, dv_df  in splitByDV(region_df, combine_sides=True):
      _optoCalcMetricsRates(res_dict=res_dict, brain_region=brain_region,
                            start_state=start_state, single_dv=single_dv,
                            animal_name="All Animals", animal_df=dv_df,
                            df_cols=df_cols,
                          min_count_per_animal_group=min_count_per_animal_group)
      for animal_name, animal_df in dv_df.groupby(dv_df.Name):
        _optoCalcMetricsRates(res_dict=res_dict, brain_region=brain_region,
                              start_state=start_state, single_dv=single_dv,
                              animal_name=animal_name, animal_df=animal_df,
                              df_cols=df_cols,
                          min_count_per_animal_group=min_count_per_animal_group)
  #print(f"{brain_region, start_state} - Single dv:", single_dv)
  #print(f"{brain_region, start_state} - Df range:", dv_range)
  #print(f"{brain_region, start_state} - Mean:", dv_df.EarlyWithdrawal.mean())
  res_df = pd.DataFrame(res_dict)
  for metric, metric_df in res_df.groupby(res_df.Metric):
    if metric != "calcReactionTime":
      continue
    #optoPlotOptoMetric(metric, metric_df)
    optoPlotOptoMetricRaw(col_name=metric, df=metric_df, save_figs=save_figs,
                          save_prefix=save_prefix)

def _optoCalcMetricsRates(*, res_dict, brain_region, start_state, single_dv,
                          animal_name, animal_df, df_cols,
                          min_count_per_animal_group):
    def calcRate(df, df_col, is_binary, condition, dict_prefix):
        ret_dict = {}
        for category in ["All", "Correct", "Incorrect"]:
          for key in ["Mean", "SEM", "Count"]:
            ret_dict[f"{dict_prefix}{category}{key}"] = None
        if len(condition) > 1:
            df = df[df[condition[0]] == condition[1]]
        else:
            df = df[~df[condition[0]].isnull()]
        if is_binary:
          total_cond = len(df[df[df_col] == 1])
          # Exclude broke-fixation trials
          total_len = len(df)
          #print(f"EWD: {EWD} - Total len: {total_len}")
          mean = total_cond/total_len if total_len else None
          ret_dict[f"{dict_prefix}AllMean"] = mean
          ret_dict[f"{dict_prefix}AllCount"] = total_len
        else:
          col = df[df_col]
          col_correct = col[df.ChoiceCorrect == 1]
          col_incorrect = col[df.ChoiceCorrect == 0]
          for cat, cat_df in [("All", col), ("Correct", col_correct),
                              ("Incorrect", col_incorrect)]:
            key_start = f"{dict_prefix}{cat}"
            for stat_name, stat_val in [("Mean", cat_df.mean()),
                                        ("SEM", cat_df.sem()),
                                        ("Count", len(cat_df))]:
              key = f"{key_start}{stat_name}"
              if key not in ret_dict:
                raise ValueError(f"Wrong key: {key} - Keys are: "
                                 f"{ret_dict.key()}")
              ret_dict[key] = stat_val
        return ret_dict

    for col_name, is_binary, filter_cond in df_cols:
      control_trials = animal_df[animal_df.OptoEnabled == 0]
      opto_trials = animal_df[animal_df.OptoEnabled == 1]
      control_res = calcRate(control_trials, col_name, is_binary, filter_cond,
                             "Control")
      opto_res = calcRate(opto_trials, col_name, is_binary, filter_cond, "Opto")
      col_res = {}
      col_res.update(control_res)
      col_res.update(opto_res)
      if col_res["OptoAllMean"] is None or col_res["ControlAllMean"] is None:
        continue
      elif col_res["OptoAllCount"] < min_count_per_animal_group or \
          col_res["ControlAllCount"] < min_count_per_animal_group:
        continue
      res_dict["Metric"].append(col_name)
      res_dict["Name"].append(animal_name)
      res_dict["BrainRegion"].append(brain_region)
      res_dict["StartState"].append(start_state)
      res_dict["DV"].append(single_dv)
      for key, val in col_res.items():
        res_dict[key].append(val) # It'll break if the key doesn't exist

def optoPlotOptoMetricRaw(*, col_name, df, save_figs, save_prefix):
  for (brain_region, start_state), region_df in  df.groupby(
                                    [df.BrainRegion, df.StartState]):
    if start_state != "stimulus_delivery":
      continue
    for animal_name, animal_df in region_df.groupby(region_df.Name):
      # TODO: See a better way to created the repeated lists
      Xs = {"ControlCorrect": [], "ControlIncorrect": [], "OptoCorrect":[],
            "OptoIncorrect":[]}
      Ys = {"ControlCorrect": [], "ControlIncorrect": [], "OptoCorrect":[],
            "OptoIncorrect":[]}
      YSem = {"ControlCorrect": [], "ControlIncorrect": [], "OptoCorrect":[],
              "OptoIncorrect":[]}
      annotations = {"ControlCorrect": [], "ControlIncorrect": [],
                    "OptoCorrect":[], "OptoIncorrect":[]}
      def checkSingleVal(series, key):
        if len(series) != 1:
          raise RuntimeError(f"Found {len(series)} for key: {key} in "
                             f"{animal_name}")
        return series.iloc[0]
      for dv, dv_df in animal_df.groupby(animal_df.DV):
        for metric_name in ("Correct", "Incorrect"):
          for prefix in ("Control", "Opto"):
            key = f"{prefix}{metric_name}"
            Xs[key].append(dv)
            Ys[key].append(checkSingleVal(dv_df[f"{key}Mean"], key))
            YSem[key].append(checkSingleVal(dv_df[f"{key}SEM"], key))
            pts_total = int(checkSingleVal(dv_df[f"{key}Count"], key))
            annotations[key].append(pts_total)
      #if len(Xs) < 3:
      #    return
      ax = plt.axes()
      for cat_name, cat_color in [("Correct", 'g'), ("Incorrect", 'r')]:
        for group_name, linestyle, marker in [("Control", '-', '.'),
                                              ("Opto", '--', 'x')]:
          key = f"{group_name}{cat_name}"
          # print("Animal name:", animal_name)
          # print("Ys type:", type(Ys[key]), "Key:", key)
          # for idx, item in enumerate(Ys[key]):
          #  print(f"Ys[{key}][{idx}]:", type(item), " - val:", item)
          # print("Ys:", list(Ys[key]))
          xs = Xs[key]
          ys = np.array(Ys[key])
          counts = annotations[key]
          label=f"{key} - {np.sum(counts)} Trials"
          ax.plot(xs, ys, label=label, color=cat_color, linestyle=linestyle,
                  marker=marker)
          y_sem_upper = ys + YSem[key]
          y_sem_lower = ys - YSem[key]
          # print("Y sem upper:", y_sem_upper)
          # print("Y sem lower:", y_sem_lower)
          ax.fill_between(xs, y_sem_upper, y_sem_lower, alpha=0.2,
                          color=cat_color)
          for x, y, single_pt_count in zip(xs, ys, counts):
            ax.annotate(str(single_pt_count), (x+0.02, y), fontsize=10)
      ax.legend(handlelength=3, prop={'size':'x-small'})
      descr = col_name[4:] if col_name.startswith("calc") else col_name
      ax.set_title(f"{animal_name} {descr} - {brain_region} {start_state}")
      if save_figs:
        savePlot(save_prefix + f"{animal_name}/{brain_region}/{descr}_" +
                 f"{start_state}_{brain_region}_{animal_name}_raw")
      plt.show()

def optoPlotOptoMetric(col_name, df):
  #print("res_df.ControlRate unique:", res_df.OptoRate.unique())
  for (brain_region, start_state), region_df in  df.groupby(
                                    [df.BrainRegion, df.StartState]):
    if start_state != "stimulus_delivery":
      continue
    ax = plt.axes()
    ax.set_title(f"{col_name} - {brain_region}")
    for animal_name, animal_df in region_df.groupby(region_df.Name):
      _optoPlotOptoMetricAnimal(animal_name, df=animal_df, ax=ax, marker='.',
                                annotate=True, alpha=0.3)
    region_df = region_df[region_df.Name != "All Animals"]
    _optoPlotOptoMetricAnimal("All Animals", df=region_df, ax=ax, marker='x',
                              annotate=True, color='k', linewidth=3)
    ax.legend()
    plt.show()

def _optoPlotOptoMetricAnimal(animal_name, df, ax, annotate, **plot_kwargs):
  Xs = []
  Ys = []
  YSem = []
  annotations = []
  for dv, dv_df in df.groupby(df.DV):
    pts_total = f"Control: {dv_df.ControlCount.sum():,} - " +\
                f"Opto: {dv_df.OptoCount.sum():,}"
    Xs.append(dv)
    Ys.append(dv_df.OptoMean.mean() / dv_df.ControlMean.mean())
    #   YSem.append(dv_df.OptoSEM)
    annotations.append(pts_total)
  if len(Xs) < 3:
      return
  print("Animal name:", animal_name)
  print("Xs:", Xs)
  print("Ys:", Ys)
  # print("Pts-Total:", pts_total)
  ax.plot(Xs, Ys, label=animal_name, **plot_kwargs)
  # y_sem_lower = np.array(Ys) - y.sem()
  # y_sem_upper = np.array(Ys) + y.sem()
  # ax.fill_between(Xs, y_sem_upper, y_sem_lower, alpha=0.2)
  if annotate:
    for x, y, _str in zip(Xs, Ys, annotations):
      ax.annotate(_str, (x+0.02, y), fontsize=10)
  #print(res_df)
  #np.array(list(leftDVBins) + [0] + list(rightDVBins))
