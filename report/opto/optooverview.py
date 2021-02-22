import numpy as np
import matplotlib.pyplot as plt
import analysis
from utils import grpBySess
from psychofit import psychofit as psyfit
from .optoutil import ChainedGrpBy


def obtainOptoTrials(animal_df):
  opto_sessions = animal_df[animal_df.OptoEnabled == True]
  opto_sessions = opto_sessions[['Date','SessionNum']].drop_duplicates()
  opto_sessions_tuples = [tuple(x) for x in opto_sessions.to_numpy()]
  # print("Opto sessions dates:", opto_sessions_tuples)
  # Filter on sessions matching Data/Session Num combination:
  # https://stackoverflow.com/a/53945974/11996983
  idx_bool = animal_df[["Date", "SessionNum"]].apply(tuple, axis=1).isin(
                                                           opto_sessions_tuples)
  return animal_df[idx_bool]


def optogenetics(df, *, opto_by_state, save_figs, save_prefix=""):
  # _optoSingleDF(animal_name="All Animals", animal_df=df,
  #               single_sess_psych=False, opto_by_state=opto_by_state,
  #               save_figs=save_figs, save_prefix=save_prefix)
  # for animal_name, animal_df in df.groupby(df.Name):
  #   _optoSingleDF(animal_name=animal_name, animal_df=animal_df,
  #                 single_sess_psych=False, opto_by_state=opto_by_state,
  #                 save_figs=save_figs, save_prefix=save_prefix)
  # This shouldn't be necessary as the df should already be filtered out
  # print("Opto sessions before:", len(df))
  # opto_ssns_df = obtainOptoTrials(df)
  # print("Opto sessions after:", len(opto_ssns_df))
  opto_chain = ChainedGrpBy(df)
  # opto_chain = opto_chain.filter(lambda ssn_df:
  #                      len(ssn_df[ssn_df.OptoEnabled==True])/len(ssn_df) > 0.05)
  from .optometrics import optoMetrics
  optoMetrics(opto_chain, save_figs=save_figs, save_prefix=save_prefix)

# def _optoSingleDF(*, animal_name, animal_df, single_sess_psych, opto_by_state,
#                    save_figs, save_prefix):


def _optoSingleDF2(*, animal_name, animal_df, single_sess_psych, opto_by_state,
                   save_figs, save_prefix):
  opto_ssns_df = obtainOptoTrials(animal_df)
  opto_ssns_df = grpBySess(opto_ssns_df).filter(lambda ssn_df:
                       len(ssn_df[ssn_df.OptoEnabled==True])/len(ssn_df) > 0.05)
  if not len(opto_ssns_df):
    print(f"* * * * * * SKippping {animal_name} as it has no opto sessions")
    return
  #opto_ssns_df = grpBySess(opto_ssns_df).filter(lambda ssn_df:len(ssn_df) > 20)
  print(f"Processing: {animal_name} - Num trials: {len(opto_ssns_df)}")
  opto_exprs_data = []
  def appendOptoGroup(brain_region, start_state, expr_df):
    opto_trials = expr_df[expr_df.OptoEnabled == True]
    control_trials = expr_df[~expr_df.index.isin(opto_trials.index)]
    opto_exprs_data.append((control_trials, opto_trials, brain_region, start_state))

  for brain_region, expr_df in opto_ssns_df.groupby(["GUI_OptoBrainRegion"]):
    #opto_trials = area_df[animal_df.OptoEnabled == True]
    #non_opto_trials = area_df[~area_df.index.isin(opto_trials.index)]
    # brain_region_str = str(BrainRegion(brain_region))
    brain_region = BrainRegion(brain_region)
    if opto_by_state:
      for start_state, sub_expr_Df in expr_df.groupby(["GUI_OptoStartState1"]):
        start_state = MatrixState(start_state)
        appendOptoGroup(brain_region=brain_region, start_state=start_state,
                        expr_df=sub_expr_Df)
    else:
      appendOptoGroup(brain_region=brain_region, start_state=None,
                      expr_df=sub_expr_Df)
    #brain_regions_data.append((non_opto_trials, opto_trials, brain_region_str,
    #                           colors[idx]))

  # optoPsych(animal_name, opto_exprs_data, single_sess_psych=single_sess_psych,
  #           opto_by_state=opto_by_state, save_figs=save_figs,
  #           save_prefix=save_prefix)
  optoMovReactTime(animal_name, opto_exprs_data, save_figs=save_figs,
                   save_prefix=save_prefix)


def optoMovReactTime2(animal_name, opto_trials_tuples, *,save_figs, save_prefix):
  STEP=2
  BAR_WIDTH=0.5
  second, percent = "Seconds", "%"
  for df_col_name, display_name, unit in [
                        ("calcReactionTime","Reaction Time", second),
                        ("calcMovementTime", "Movement Time", second),
                        ("EarlyWithdrawal", "Early-Withdrawal", percent),
                        ("ChoiceCorrect", "Overall Performance", percent)]:
    ax = plt.axes()
    Xs = []
    Ys = []
    Yerr = []
    colors = []
    x_ticks_labels = []
    x_ticks_pos = []
    last_brain_region = None
    cur_x_pos = 0
    for control_trials, opto_trials, brain_region, start_state in opto_trials_tuples:
      cur_x_pos += STEP if last_brain_region != brain_region else BAR_WIDTH*2
      last_brain_region = brain_region

      Xs +=   [cur_x_pos,                          cur_x_pos + BAR_WIDTH]
      Ys +=   [control_trials[df_col_name].mean(), opto_trials[df_col_name].mean()]
      Yerr += [control_trials[df_col_name].sem(),  opto_trials[df_col_name].sem()]
      # if unit == percent:
      #   grps_control_mean = grpBySess(control_trials)[df_col_name].mean()
      #   grps_opto_mean = grpBySess(control_trials)[df_col_name].mean()
      #   Ys_means_mean += [grps_control_mean.mean(), grps_opto_mean.mean()]
      #   Yerr += [grps_control_mean.sem(), grps_opto_mean.sem()]

      # Should write, e.g: V1Bi - Stimulus_deliver (305 C/135 Opto trials)
      x_ticks_labels.append(r"%s%s (%d $\bf{C}$/%d $\bf{Opto}$ trials)" % (
                            brain_region, f" - {start_state}" if start_state else "",
                            len(control_trials), len(opto_trials)))
      x_ticks_pos.append(cur_x_pos)
      color = BRC[brain_region]
      colors += [adjustColorLightness(color, amount=0.6),
                 adjustColorLightness(color, amount=1.4)]
      #print(f"expr_id: {expr_id} - Xs: {Xs[-2:]} - Ys: {Ys[-2:]} - Color: {colors[-2:]}")

    if unit == percent:
      Ys = np.array(Ys) * 100
    ax.bar(Xs, Ys, width=BAR_WIDTH, yerr=Yerr, color=colors)
    ax.set_xticks(x_ticks_pos)
    ax.set_xticklabels(x_ticks_labels, ha='right', rotation=25)
    ax.tick_params(axis='x', which='major', labelsize=10)
    ax.set_title(f"{animal_name} - {display_name} Optogentics Trials")
    ax.set_ylabel(f"Mean {display_name} ({unit})")
    from matplotlib.lines import Line2D
    custom_lines = [
          Line2D([0],[0], color=adjustColorLightness("gray", amount=0.6), lw=4),
          Line2D([0],[0], color=adjustColorLightness("gray", amount=1.4), lw=4)]
    ax.legend(custom_lines,
              ['Control Trials (dark shade)', 'Opto Trials (light shade)'],
              loc='lower right')
    if save_figs:
      analysis.savePlot(save_prefix + f"{animal_name}_{display_name}")
    plt.show()

def optoPsych2(animal_name, opto_trials_tuples, *, single_sess_psych,
              opto_by_state, save_figs, save_prefix):
  _psych_kargs = dict(linewidth=2, plot_points=True, SEM=False)
  if single_sess_psych:
    singleSessPsych(animal_name=animal_name,
                    opto_trials_tuples=opto_trials_tuples,
                    opto_by_state=opto_by_state, save_figs=save_figs,
                    save_prefix=save_prefix, _psych_kargs=_psych_kargs)

  for control_trials, opto_trials, brain_region, start_state in opto_trials_tuples:
    PsycStim_axes = analysis.psychAxes(f"{animal_name} Optogenetics")
    part_legend_str = f"{brain_region}"
    if part_legend_str: part_legend_str += f"- {start_state}"
    color = BRC[brain_region]
    if len(control_trials) > 50:
      legend_name = f"{part_legend_str} Control"
      analysis._psych(control_trials, PsycStim_axes, color=color, markersize=5,
                      legend_name=legend_name, annotate_pts=True,
                      nfits=nfits(control_trials), **_psych_kargs)
    if len(opto_trials) > 50:
      print("opto trials len():", len(opto_trials))
      legend_name = f"{part_legend_str} Opto"
      analysis._psych(opto_trials, PsycStim_axes, color=color, linestyle="--",
                      legend_name=legend_name, marker='x', markersize=5,
                      annotate_pts=True, nfits=nfits(opto_trials),
                      **_psych_kargs)
    PsycStim_axes.legend(prop={'size':'x-small'}, loc='lower left',
                         bbox_to_anchor=(1.01, 0))
    if save_figs:
      expr_id_str = "_".join(expr_id)
      analysis.savePlot(save_prefix + f"psych_{expr_id_str}_{animal_name}")
    plt.show()

def singleSessPsych2(*, animal_name, opto_trials_tuples, opto_by_state,
                    save_figs, save_prefix, _psych_kargs):
  all_control = list(map(lambda tup: tup[0], opto_trials_tuples))
  all_opto = list(map(lambda tup: tup[1], opto_trials_tuples))
  print(len(opto_trials_tuples[0]), len(all_control), len(all_opto))
  all_control, all_opto = pd.concat(all_control), pd.concat(all_opto)
  from matplotlib import cm
  import numpy as np
  c_cycle=cm.rainbow(np.linspace(0,1,len(grpBySess(all_control))))
  for (ssn_date1, ssn_control), (ssn_date2, ssn_opto), c in \
                      zip(grpBySess(all_control), grpBySess(all_opto), c_cycle):
    assert ssn_date1 == ssn_date2
    least_control = ssn_control.TrialNumber.min()
    max_control = ssn_control.TrialNumber.max()
    least_opt = ssn_opto.TrialNumber.min()
    max_opto = ssn_opto.TrialNumber.max()
    from definitions import BrainRegion, MatrixState
    brain_regions = " ".join(list(map(lambda r:str(BrainRegion(r)).replace("BrainRegion.",''), ssn_opto.GUI_OptoBrainRegion.unique())))
    if opto_by_state:
      start_trial = " ".join(list(map(lambda r:str(MatrixState(r)).replace("MatrixState.",''), ssn_opto.GUI_OptoStartState1.unique())))
    else:
      state_trial = ""
    PsycStim_axes = analysis.psychAxes(f"{animal_name} Optogenetics - {ssn_date1[0]} Ssn: {ssn_date1[1]} - {brain_regions} {start_trial}")
    if len(ssn_control) > 10:
      try:
        legend_name = f"Control (T: {least_control} -> {max_control})"
        analysis._psych(ssn_control, PsycStim_axes, alpha=0.3, color=c,
                        nfits=nfits(ssn_control), legend_name=legend_name,
                        **_psych_kargs)
      except:
        pass
    if len(ssn_opto) > 10:
      try:
        legend_name = f"Opto (T: {least_opt} -> {max_opto})"
        analysis._psych(ssn_opto, PsycStim_axes, alpha=0.3, color=c,
                        nfits=nfits(ssn_opto), legend_name=legend_name,
                        linestyle="--", marker='x', **kargs)
      except:
        pass
    PsycStim_axes.legend(prop={'size':'x-small'},loc='lower right')
    if save_figs:
      analysis.savePlot(save_prefix + f"psych_{brain_regions}_{start_trial}_"
                        f"{animal_name}_{ssn_date1[0]}_ssn_{ssn_date1[1]}")
    #plt.show()
    plt.close(plt.gcf())
