import matplotlib.pyplot as plt
from analysis import savePlot
from utils import chunks, lightenColor

ANIMALS_COLORS=['r', 'b', 'g', 'orange', 'gray', 'black', 'yellow', 'purple',
                'brown', 'cyan']

def _createAxes(title, title_prefix=""):
  fig, (ax_raw, ax_avg) = plt.subplots(2,1)
  from analysis import SAVE_FIG_SIZE
  fig.set_size_inches(1*1.5*SAVE_FIG_SIZE[0], 2*1.5*SAVE_FIG_SIZE[1])
  fig.tight_layout(pad=7.5)
  ax_raw.set_title("{}Raw {}".format(title_prefix, title))
  ax_avg.set_title("{}Mean {}".format(title_prefix, title))
  return ax_raw, ax_avg

def _ssnLenByAnimalHist(df, *, save_figs, save_prefix="", save_suffix="",
                        df_filtered=None):
  ax_trials = plt.axes()
  SESSIONS_LEN_BIN_SIZE=50
  name_to_clr = {}
  for idx, (animal_name, animal_df) in enumerate(df.groupby(df.Name)):
    max_trials = animal_df.groupby(["Date", "SessionNum"]).MaxTrial.head(1)
    # print("Animal name:", animal_name, "max_trials:", max_trials)
    name_to_clr[animal_name] = ANIMALS_COLORS[idx]
    # TODO: Handle case where df_filtered is provided and print the number
    # before and after trimming.
    num_ssns = len(animal_df.groupby(["Date", "SessionNum"]))
    label = "{} ({} sessions)".format(animal_name, num_ssns)
    ax_trials.hist(max_trials, label=label, density=True,
                   bins=int(max_trials.max()/SESSIONS_LEN_BIN_SIZE)+1,
                   color=name_to_clr[animal_name], histtype='step')

  if df_filtered:
    for animal_name, animal_df in df.groupby(df.Name):
      # Can't use max trials as trials are already cut
      max_max_trial = animal_df.groupby(["Date", "SessionNum"]).size().max()
      # print(animal_name, "- Max trial max:", max_max_trial)
      ax_trials.axvline(max_max_trial, linestyle='dashed',
                        color=name_to_clr[animal_name], zorder=-10, alpha=0.5)

  ax_trials.set_title("Sessions Length Histogram: [Bin size: {}]".format(
                                                         SESSIONS_LEN_BIN_SIZE))
  ax_trials.legend()
  if save_figs:
    savePlot(save_prefix + "sessions_length_hist" + save_suffix)
  plt.show()


def _filterOutliers(df, df_col_name, display_name, *, save_figs, save_prefix,
                    save_suffix):
  from scipy import stats
  import numpy as np

  color_counter = 0
  ZSCORE_TRUE_PERCENTILE_FALSE = False
  if ZSCORE_TRUE_PERCENTILE_FALSE:
    ax_hist, ax_hist_log = _createAxes(display_name)
    zscore_rank = 2
  else:
    ax_hist = plt.axes()
    percentile_low, percentile_high = 5, 95

  def filterGrp(group_df):
    nonlocal color_counter
    # We need to make sure the value is not null and bigger than zero as
    # we will calculate the log of these values
    group_df = group_df[group_df[df_col_name] > 0] #.notnull() ]
    col_vals = group_df[df_col_name]
    num_bins = int(col_vals.max() * 10)
    ax_hist.hist(col_vals, color=ANIMALS_COLORS[color_counter], density=True,
                 label=group_df.Name.iloc[0], histtype='step',
                 bins=num_bins)
    if ZSCORE_TRUE_PERCENTILE_FALSE:
      log_col_vals = np.log(col_vals)
      ax_hist_log.hist(log_col_vals, color=ANIMALS_COLORS[color_counter],
                       density=True, label=group_df.Name.iloc[0],
                       histtype='step')
      z_scores = stats.zscore(log_col_vals)
      # print("Z-scores:", z_scores)
      group_df = group_df[np.absolute(z_scores)  <= zscore_rank]
      filtered_col_vals = group_df[df_col_name]
      filtered_log_vals = np.log(filtered_col_vals)
      for limit in [np.min(filtered_log_vals), np.max(filtered_log_vals)]:
        ax_hist_log.axvline(limit, linestyle='dashed', alpha=0.5,
                            color=ANIMALS_COLORS[color_counter], zorder=-10)
    else:
      group_df = group_df[(np.percentile(col_vals, percentile_low) < col_vals) &
                          (col_vals < np.percentile(col_vals, percentile_high))]
      filtered_col_vals = group_df[df_col_name]
    ax_hist.axvline(x=filtered_col_vals.max(), linestyle='dashed',
                    color=ANIMALS_COLORS[color_counter], zorder=-10, alpha=0.5)
    color_counter += 1
    return group_df

  filtered_df =  df.groupby(df.Name).apply(filterGrp)
  filtered_df = filtered_df.reset_index(level=0, drop=True)
  #display(filtered_df)
  print("Diff in length: {:,}".format(len(df) - len(filtered_df)))
  if ZSCORE_TRUE_PERCENTILE_FALSE:
    sub_title =  "Z-Score rank: {}".format(zscore_rank)
  else:
    sub_title = "Percentie: {}% Low - {}% High".format(percentile_low,
                                                       percentile_high)
  ax_hist.set_title("{} Histogram - {}".format(display_name, sub_title))
  ax_hist.set_xlim(0, 5)
  ax_hist.legend(loc="upper right")
  if ZSCORE_TRUE_PERCENTILE_FALSE:
    ax_hist_log.set_title("{} Log-Histogram".format(display_name))
    ax_hist_log.legend(loc="upper right")
  if save_figs:
    savePlot(save_prefix + display_name + "_hist" + save_suffix)
  plt.show()
  return filtered_df

def _reactionTimeHist(df, *, df_col_name, save_figs, save_prefix, save_suffix):
  BIN_WIDTH=5
  diff_bins= list(range(50, 100 + BIN_WIDTH, BIN_WIDTH))
  print("Diff bins:", diff_bins)
  for animal_name, animal_df in df.groupby(df.Name):
    ax_difficulty, ax_reaction_time = _createAxes("Will Overwrite Title Later")
    for (difficulty, color) in [("Difficulty1", 'g'),
                                ("Difficulty2", 'b'),
                                ("Difficulty3", 'r')]:
      diff_df = animal_df[animal_df.DV.abs() * 100 == animal_df[difficulty]]
      label = "{} ({:,} trials)".format(difficulty, len(diff_df))
      print("Animal:", animal_name, "- Diff_df:", difficulty,
            "- Length:", len(diff_df))
      if len(diff_df):
        ax_difficulty.hist(diff_df[difficulty], bins=diff_bins, density=True,
                           color=color, histtype="step", label=label)
        num_bins = int(diff_df[df_col_name].max() * 10)
        ax_reaction_time.hist(diff_df[df_col_name], bins=num_bins,
                              color=color, histtype="step", density=True,
                              label=label)
    #ax_difficulty.set_xlim(50, 100)
    ax_difficulty.legend()
    ax_difficulty.set_title(
                     "{} Normalized Difficulties histogram".format(animal_name))
    ax_reaction_time.set_xlim(0, 5)
    ax_reaction_time.set_title(
         "{} Normalized Reaction-time/Difficulty histogram".format(animal_name))
    ax_reaction_time.legend()
    if save_figs:
      savePlot(save_prefix + "reaction_time_hist_" + animal_name)
    plt.show()

def _metricByCategoryByAnimal(df, df_col_name, *, metric_type, display_name,
                              min_session_len, limit_session_at_max_trials,
                              trials_groupping_bin_size,
                              min_num_pts_per_animal_bin, save_figs,
                              save_prefix, save_suffix):
  for animal_name, animal_df in df.groupby(df.Name):
    df_correct = animal_df[animal_df.ChoiceCorrect == 1]
    df_incorrect = animal_df[animal_df.ChoiceCorrect == 0]
    df_left = animal_df[animal_df.ChoiceLeft == 1]
    df_right = animal_df[animal_df.ChoiceLeft == 0]
    ax_raw, ax_avg = _createAxes(display_name,
                                 title_prefix="{} ".format(animal_name))
    for idx, (df_for_cat, color, label) in enumerate([
                                              (df_correct, 'g', "Correct"),
                                              (df_incorrect, 'r', "Incorrect"),
                                              (df_left, 'y', "Left"),
                                              (df_right, 'b', "Right")]):
      #med_diff = used_df_.DV.abs().median()
      import pandas as pd
      group_bins = pd.cut(df_for_cat.DV.abs(), [0, 0.5, 1])
      #print("Group bins:", group_bins)
      idxs = list(range(2))
      grp_by_obj = df_for_cat.groupby(group_bins)
      colors = (lightenColor(color, 1.2), lightenColor(color, 0.8))
      labels = (label + " difficult", label + " easy")
      for j, (intrvl, used_df), color, label in \
                                          zip(idxs, grp_by_obj, colors, labels):
        _min_session_len = int(min_session_len*len(used_df)/len(animal_df))
        print("Interval:", intrvl, "- label:", label)
        #[print("Intrvl:", i, " --", intrvl[i]) for i in range(len(intrvl))]
        from analysis import stackMetric
        stackMetric(df_col_name, used_df, axes_raw=ax_raw, axes_avg=ax_avg,
                    stack_metric_unit=metric_type,
                    animals_colors=[color], min_session_len=_min_session_len,
                    limit_session_at_max_trials=limit_session_at_max_trials,
                    trials_groupping_bin_size=trials_groupping_bin_size,
                    min_num_pts_per_animal_bin=min_num_pts_per_animal_bin,
                    alt_labels=[label])
        used_df = used_df[used_df[df_col_name].notnull()]
        height = used_df[df_col_name].mean()
        var = used_df[df_col_name].sem()
        ax_avg.set_ylim(top=2)
        ax_raw.set_ylim(top=2)
        x = 37.5 + (idx*30) + (j*7.5)
        print(label,"- df(len):", len(used_df))
        ax_raw.bar(x, height, width=7.5, color=color, alpha=0.6, yerr=var)
    if save_figs:
      savePlot(save_prefix + "animal_" + display_name + "_" + animal_name +
               save_suffix)
    plt.show()

def stackedPerformance(df, *, min_session_len, limit_session_at_max_trials,
                       trials_groupping_bin_size, min_num_pts_per_animal_bin,
                       save_figs=False, save_prefix="", save_suffix=""):
  _ssnLenByAnimalHist(df, save_figs=save_figs, save_prefix=save_prefix,
                      save_suffix=save_suffix)
  df = df[df.acceptedTrials]
  print("Num. of trials after filtering out trials not meeting criteria from "
        "sessions: {}".format(len(df)))
  if not len(df):
    print("Skipping rest of the plots due to empty dataframe")
    return

  psy_save_suff = "used_animals" + save_suffix if save_figs else ""
  from psychometric import _psychAllAnimalsVariation
  _psychAllAnimalsVariation(df, title_comment="Chosen Animals Psychometric",
                            min_ssn_len=min_session_len,
                            list_animals_individually=True,
                            color_rdk=ANIMALS_COLORS, color_lc=ANIMALS_COLORS,
                            save_prefix=save_prefix, save_suffix=psy_save_suff)

  from analysis import StackMetricUnit as Unit
  for df_col_name, display_name, metric_type in [
                      ("calcMovementTime", "Movement Time", Unit.Seconds),
                      ("calcReactionTime","Reaction Time", Unit.Seconds),
                      ("ChoiceCorrect", "Accuracy Rate", Unit.Percent),
                      ("GUI_CalcLeftBias", "Bias Rate", Unit.Ratio),
                      ("EarlyWithdrawal", "Early Withdrawal Rate", Unit.Ratio)]:

    if df_col_name == "calcReactionTime":
      _reactionTimeHist(df, df_col_name=df_col_name, save_figs=save_figs,
                        save_prefix=save_prefix, save_suffix=save_suffix)

    if metric_type == Unit.Seconds:
      filtered_df = _filterOutliers(df, df_col_name, display_name,
                                    save_figs=save_figs,
                                    save_prefix=save_prefix,
                                    save_suffix=save_suffix)
    else:
      filtered_df = df

    ax_raw, ax_avg = _createAxes(display_name)
    if df_col_name == "GUI_CalcLeftBias":
      for ax in [ax_raw, ax_avg]:
        ax.axhline(y=0.5, color='gray',linestyle='dashed')

    from analysis import stackMetric
    stackMetric(df_col_name, filtered_df, axes_raw=ax_raw, axes_avg=ax_avg,
                stack_metric_unit=metric_type, animals_colors=ANIMALS_COLORS,
                min_session_len=min_session_len,
                limit_session_at_max_trials=limit_session_at_max_trials,
                trials_groupping_bin_size=trials_groupping_bin_size,
                min_num_pts_per_animal_bin=min_num_pts_per_animal_bin)
    if save_figs:
      savePlot(save_prefix + display_name + "_stacked_performance" +
               save_suffix)
    plt.show()

    if metric_type == Unit.Seconds:
      _metricByCategoryByAnimal(filtered_df, df_col_name,
                metric_type=metric_type, display_name=display_name,
                min_session_len=min_session_len,
                limit_session_at_max_trials=limit_session_at_max_trials,
                trials_groupping_bin_size=trials_groupping_bin_size,
                min_num_pts_per_animal_bin=min_num_pts_per_animal_bin,
                save_figs=save_figs, save_prefix=save_prefix,
                save_suffix=save_suffix)


def isAcceptedSessionHeadFixed(sess_df):
  '''A session filter function for head-fixed animals'''
  from definitions import MouseState
  if len(sess_df[sess_df.GUI_MouseState == MouseState.FreelyMoving]):
    is_accepted = False
  else:
    no_cr_df = sess_df
    #  no_cr_df = sess_df[(sess_df.GUI_RewardAfterMinSampling == 0) |
    #                     (sess_df.CenterPortRewAmount <= 0.3)]
    diff_cols = \
          no_cr_df.dropna(subset=["Difficulty1", "Difficulty2", "Difficulty3"],
                           how="any")
    if len(diff_cols) < 50:
      is_accepted = False
    else:
      easiest_diff = sess_df[sess_df.ChoiceCorrect.notnull() &
                             (sess_df.DV.abs() * 100 == sess_df.Difficulty1)]
      easiest_perf = \
          len(easiest_diff[easiest_diff.ChoiceCorrect == 1]) / len(easiest_diff)
      easiest_perf *= 100
      is_accepted = easiest_perf > 80
  sess_df["acceptedSession"] = is_accepted
  sess_df["acceptedTrials"] = True
  # sess_df.acceptedTrials &= ((sess_df.GUI_RewardAfterMinSampling == 0) |
  #                            (sess_df.CenterPortRewAmount <= 0.3))
  sess_df.acceptedTrials &= sess_df.GUI_StimAfterPokeOut == 0
  # sess_df.acceptedTrials &= (sess_df.GUI_MinSampleType.isnull() |
  #                            (sess_df.GUI_MinSampleType == 1))
  sess_df.acceptedTrials &= sess_df.TrialNumber < sess_df.MaxTrial - 30
  return sess_df

def isAcceptedSessionFreelyMoving(sess_df):
  '''A session filter function for head-fixed animals'''
  from analysis import MouseState
  if MouseState.FreelyMoving not in sess_df.GUI_MouseState.unique():
    is_accepted = False
  else:
    #print("Caught animal:", sess_df.Name.unique()[0], "- Mouse states:",
    #      sess_df.GUI_MouseState.unique())
    no_cr_df = sess_df
    #  no_cr_df = sess_df[(sess_df.GUI_RewardAfterMinSampling == 0) |
    #                     (sess_df.CenterPortRewAmount <= 0.3)]
    if len(no_cr_df) < 50:
      is_accepted = False
    else:
      easiest_diff = no_cr_df[no_cr_df.ChoiceCorrect.notnull() &
                              (no_cr_df.DV.abs() * 100 == no_cr_df.Difficulty1)]
      easiest_perf = \
          len(easiest_diff[easiest_diff.ChoiceCorrect == 1]) / len(easiest_diff)
      easiest_perf *= 100
      is_accepted =  easiest_perf > 80
  sess_df["acceptedSession"] = is_accepted
  sess_df["acceptedTrials"] = True
  # sess_df.acceptedTrials &= ((sess_df.GUI_RewardAfterMinSampling == 0) |
  #                            (sess_df.CenterPortRewAmount <= 0.3))
  sess_df.acceptedTrials &= sess_df.GUI_StimAfterPokeOut == 0
  # sess_df.acceptedTrials &= (sess_df.GUI_MinSampleType.isnull() |
  #                            (sess_df.GUI_MinSampleType == 1))
  sess_df.acceptedTrials &= sess_df.TrialNumber < sess_df.MaxTrial - 30
  return sess_df

def batchProcessStackedPerformance(df, *, batch_size, ssnFilterFn,
      min_session_len, limit_session_at_max_trials, trials_groupping_bin_size,
      min_num_pts_per_animal_bin, save_figs, save_prefix=""):
  names = df.Name.unique()
  for i, few_animals in enumerate(chunks(names, batch_size)):
    sub_df = df[df.Name.isin(few_animals)]
    print("Processing", few_animals)
    sub_df = sub_df.groupby(["Name", "Date", "SessionNum"]).apply(ssnFilterFn)
    print("Done filtering...")
    sub_df = sub_df[sub_df.acceptedSession]
    print("Remaining df len: {:,}".format(len(sub_df)))
    if len(sub_df):
      save_suffix = "_batch_{}".format(i)
      stackedPerformance(sub_df, min_session_len=min_session_len,
                        limit_session_at_max_trials=limit_session_at_max_trials,
                        trials_groupping_bin_size=trials_groupping_bin_size,
                        min_num_pts_per_animal_bin=min_num_pts_per_animal_bin,
                        save_figs=save_figs, save_prefix=save_prefix,
                        save_suffix=save_suffix)