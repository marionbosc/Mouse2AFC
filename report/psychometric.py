import matplotlib.pyplot as plt
import pandas as pd

from analysis import psychAxes, psychByAnimal, psychAll, ExpType, savePlot
from utils import grpBySess

def _psychAllAnimalsVariation(df, *, title_comment, min_ssn_len,
                              list_animals_individually, list_animals_in_legend,
                              color_rdk='r', color_lc='b', save_prefix="",
                              save_suffix=""):
  PsycStim_axes = psychAxes(title_comment)
  li_rdk, li_lc = psychByAnimal(df, use_chosen_days=None,
                            PsycStim_axes=PsycStim_axes,
                            min_session_len=min_ssn_len,
                            color_rdk=color_rdk, color_lc=color_lc,
                            list_animals_individually=list_animals_individually,
                            list_animals_in_legend=list_animals_in_legend)

  if len(li_rdk) or len(li_lc):
    num_animals = len(li_rdk) + len(li_lc)
    num_sessions = 0 if not len(df) else len(
                                     df.groupby(["Name", "Date", "SessionNum"]))
    label = "All - {:,} animals - {:,} sessions".format(num_animals,
                                                        num_sessions)
    psychAll(df, PsycStim_axes, color='k', legend_name=label, linestyle="solid")
    if not list_animals_individually:
      for li, li_name, color in [(li_rdk, "RDK", color_rdk),
                                 (li_lc, "Light-Chasing", color_lc)]:
        num_animals = len(li)
        if num_animals:
          df_exp_type = pd.concat(li)
          num_sessions = len(
                            df_exp_type.groupby(["Name", "Date", "SessionNum"]))
          label = "All {} - {:,} Animals - {:,} sessions".format(li_name,
                                                                 num_animals,
                                                                 num_sessions)
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

def psychAllAnimals(df, *, min_total_trials, fltrFn, save_prefix):
  print(df.SessionPerformance.notnull().describe())
  # Attempt to reduce memory usage

  df_lc = df[df.GUI_ExperimentType == ExpType.LightIntensity]
  df_rdk = df[df.GUI_ExperimentType == ExpType.RDK]
  for sub_df, exp_type, title_comment, save_suffix in [
           (df,     None,                   "",                "_all_exps"),
           (df_lc,  ExpType.LightIntensity, " Light-Chasing ", "_LightChasing"),
           (df_rdk, ExpType.RDK,            " RDK ",           "_RDK")]:
    #df = df[df.Date >= dt.date(2019,3,1)]
    #df = df[(df.FeedbackTime > 0.5)]
    #df = df[(df.GUI_CatchError == 1) & (df.GUI_PercentCatch > 0)]
    #df = df[df.GUI_FeedbackDelayMax == 4]
    # Filter animals with few trials
    sub_df = sub_df.groupby(sub_df.Name).filter(
                                         lambda grp:len(grp) > min_total_trials)

    title = "(All {}Animals)".format(title_comment)
    _psychAllAnimalsVariation(sub_df, title_comment=title,
                              min_ssn_len=0, # TODO Remove this
                              list_animals_individually=False,
                              list_animals_in_legend=False,
                              save_prefix=save_prefix, save_suffix=save_suffix,)
    # Filter animals with few trials
    sub_df = grpBySess(sub_df).filter(fltrFn, exp_type=exp_type)
    sub_df = sub_df.groupby(sub_df.Name).filter(
                                         lambda grp:len(grp) > min_total_trials)
    if not len(sub_df):
      continue
    title = "(All {}Animals - Filtered)".format(title_comment)
    save_suffix += "_filtered"
    colors = [None]*len(sub_df.groupby(sub_df.Name))
    _psychAllAnimalsVariation(sub_df, title_comment=title,
                              min_ssn_len=0, color_lc=colors, color_rdk=colors,
                              list_animals_individually=True,
                              list_animals_in_legend=False,
                              save_prefix=save_prefix, save_suffix=save_suffix)
