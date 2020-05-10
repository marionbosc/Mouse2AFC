import matplotlib.pyplot as plt
import pandas as pd

from analysis import psychAxes, psychByAnimal, psychAll, ExpType, savePlot

def _psychAllAnimalsVariation(df, *, title_comment, min_ssn_len,
                              list_animals_individually, color_rdk='r',
                              color_lc='b', save_prefix="", save_suffix=""):
  PsycStim_axes = psychAxes(title_comment)
  li_rdk, li_lc = psychByAnimal(df, use_chosen_days=None,
                            PsycStim_axes=PsycStim_axes,
                            min_session_len=min_ssn_len,
                            color_rdk=color_rdk, color_lc=color_lc,
                            list_animals_individually=list_animals_individually)

  if len(li_rdk) or len(li_lc):
    psychAll(df, PsycStim_axes, color='k', legend_name="All", linestyle="solid")
    if not list_animals_individually:
      for li, li_name, color in [(li_rdk, "RDK", color_rdk),
                                 (li_lc, "Light-Chasing", color_lc)]:
        num_sessions = len(li)
        if num_sessions:
          df_exp_type = pd.concat(li)
          label = "All {} - {:,} sessions".format(li_name, num_sessions)
          psychAll(df_exp_type, PsycStim_axes, color=color, legend_name=label,
                   linestyle="dotted")
  bbox_to_anchor = (0.5, -0.125)
  PsycStim_axes.legend(loc='upper center',
            bbox_to_anchor=bbox_to_anchor,ncol=1,fancybox=True,
            prop={'size': 6})
  if save_suffix:
    save_fp = save_prefix + "AllPsychometric_" + save_suffix
    savePlot(save_fp)
  plt.show()

def psychAllAnimals(df, *, min_ssn_trials, min_total_trials, save_prefix):
  print(df.SessionPerformance.notnull().describe())
  # Attempt to reduce memory usage
  def dfGenerator():
    count = 0
    for descrp, save_suffix, exp_type in [
                    ("", "_all_exps", None),
                    ("RDK", "_RDK", ExpType.RDK),
                    ("Light-Chasing", "_LightChasing", ExpType.LightIntensity)]:
      sub_df = df[df.GUI_ExperimentType == exp_type] if exp_type else df[:]
      # Filter animals with few trials
      sub_df = sub_df.groupby([sub_df.Name]).filter(lambda grp:len(grp) > 5000)
      title = "(All {}Animals)".format(" "+descrp+" " if len(descrp) else "")
      yield (sub_df, title, save_suffix)

      sub_df = sub_df[sub_df.SessionPerformance > 65]
      title = "(All {}Animals - Perf. > 65%)".format(
                                      " " + descrp + " " if len(descrp) else "")
      yield (sub_df, title, save_suffix + "_above_65_percent")

  df_lc = df[df.GUI_ExperimentType == ExpType.LightIntensity]
  df_rdk = df[df.GUI_ExperimentType == ExpType.RDK]
  for sub_df, title_comment, save_suffix in [#dfGenerator():
                                    (df, "", "_all_exps"),
                                    (df_lc, " Light-Chasing ", "_LightChasing"),
                                    (df_rdk, " RDK ", "_RDK")]:
    #df = df[df.Date >= dt.date(2019,3,1)]
    #df = df[(df.FeedbackTime > 0.5)]
    #df = df[(df.GUI_CatchError == 1) & (df.GUI_PercentCatch > 0)]
    #df = df[df.GUI_FeedbackDelayMax == 4]
    # Filter animals with few trials
    sub_df = sub_df.groupby(sub_df.Name).filter(
                                         lambda grp:len(grp) > min_total_trials)
    title = "(All {}Animals)".format(title_comment)

    _psychAllAnimalsVariation(sub_df, title_comment=title,
                              min_ssn_len=min_ssn_trials,
                              list_animals_individually=False,
                              save_prefix=save_prefix, save_suffix=save_suffix)
    # Filter animals with few trials
    sub_df = sub_df[sub_df.SessionPerformance > 65]
    title = "(All {}Animals - Perf. > 65%)".format(title_comment)
    _psychAllAnimalsVariation(sub_df, title_comment=title_comment,
                              min_ssn_len=min_ssn_trials,
                              list_animals_individually=False,
                              save_prefix=save_prefix, save_suffix=save_suffix)
