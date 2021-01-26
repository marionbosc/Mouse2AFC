import numpy as np
import matplotlib.pyplot as plt
from scipy import stats
import analysis
from clr import BrainRegion as BRC
from .optoutil import ChainedGrpBy, splitToControOpto, filterIfNotMinOpto

def psychGroups(ax, trials_groups, _plot_kargs, _psych_kargs, plot_inc=2,
                err_xoffset=0):
  Xs_to_ys = {}
  #Ys = []
  #Yerr = []
  for group_name, group_df in trials_groups:
    group_df = group_df[group_df.ChoiceLeft.notnull()]
    analysis._psych(group_df, ax, legend_name=group_name, nfits=nfits(group_df),
                    **_psych_kargs, **_plot_kargs, alpha=0.3)

    for dv_interval, dv_single, dv_df in analysis.splitByDV(group_df,periods=5):
      x = dv_single
      if len(dv_df) < 10:
        continue
      y = dv_df.ChoiceLeft.mean()
      if np.isnan(y):
        print("Nan for: ", dv_df.ChoiceLeft)
      x_arr = Xs_to_ys.get(x, [])
      x_arr.append(y)
      Xs_to_ys[x] = x_arr

  if not len(Xs_to_ys):
    return

  Xs = []
  Ys = []
  Ys_count = []
  # Yerr = []
  color = _plot_kargs.get("color", None)
  if 'linewidth' in _plot_kargs:
    _plot_kargs['linewidth'] += plot_inc
  markersize = _plot_kargs.get('markersize', None)
  if markersize: markersize += plot_inc*2

  for x, x_arr in Xs_to_ys.items():
    y = np.array(x_arr)
    #ax.plot([x]*len(y), y,color=color)
    y_mean = y.mean()
    y_sem = stats.sem(y)
    Xs.append(x)
    Ys.append(y_mean)
    Ys_count.append(len(y))
    x += err_xoffset
    l, caps, c = ax.errorbar(x, y_mean*100, yerr=y_sem*100, color=color,
                             marker=_plot_kargs.get('marker', None), capsize=5,
                             markersize=markersize) #uplims=True, lolims=True)
    # c is the LineCollection objects of the errorbar lines
    c[0].set_linestyle(_plot_kargs.get('linestyle', None))
    [cap.set_marker('_') for cap in caps]

  from analysis import psychFitBasic
  # Not fit and plot the current Xs and Ys
  stims = Xs
  stim_count = Ys_count
  stim_ratio_correct = Ys
  # print("stims:", stims)
  # print("stim_ratio_correct:", stim_ratio_correct)
  pars, fitFn = psychFitBasic(stims=stims, stim_count=stim_count,
                              nfits=nfits(np.sum(stim_count)),
                              stim_ratio_correct=stim_ratio_correct)
  _range = np.arange(-1,1,0.02)
  y_fit = fitFn(_range) * 100
  _plot_kargs['marker'] = None
  print("_plot_kargs:", _plot_kargs)
  ax.plot(_range, y_fit, **_plot_kargs)
  # intercept, slope = pars[0], pars[1]

def optoPsychPlot(animal_name, df, *, save_figs, save_prefix,
                  brain_region=None, start_state=None, by_animal=False,
                  by_session=False):
  MIN_NUM_TRIALS = 50
  # Get rid of no-choice trials
  df = df[df.ChoiceCorrect.notnull()]
  if brain_region:
    region_legend_str = f"{brain_region} - "
    color = BRC[brain_region]
  else:
    region_legend_str = "(N/A region) - "
    color = "gray"
  state_str = f"{start_state}" if start_state else "(N/A state)"
  part_legend_str = f"{region_legend_str}{state_str}"

  control_trials, opto_trials = splitToControOpto(df)
  def conv(trials_df):
    trials_df = ChainedGrpBy(trials_df)
    if by_animal:
      trials_df = trials_df.byAnimal()
    if by_session:
      trials_df = trials_df.bySess()
    return trials_df
  control_trials, opto_trials = conv(control_trials), conv(opto_trials)
  control_trials, opto_trials = filterIfNotMinOpto(control_trials, opto_trials,
                                                  min_num_trials=MIN_NUM_TRIALS)
  if not len(control_trials): # Opto trials should also match in length
    print("No valid sessions found. Returning")
    return

  PsycStim_axes = analysis.psychAxes(f"{animal_name} - {part_legend_str} Opto")

  for trial_type_str, linestyle, marker, trials_df, err_xoffset in [
                                   ("Control", "-", "o", control_trials, -0.02),
                                   ("Opto", "--", 'x', opto_trials, 0.02)]:
    legend_name = f"{part_legend_str} {trial_type_str}"
    _plot_kargs = dict(linestyle=linestyle, linewidth=2, color=color,
                       marker=marker, markersize=5)
    _psych_kargs = dict(plot_points=True, SEM=False, annotate_pts=True)
    df_groups = []
    for grp_info, grp_df in trials_df:
      info_str = f"{grp_info} - {legend_name}"
      df_groups.append((info_str, grp_df))
    psychGroups(PsycStim_axes, df_groups, _plot_kargs, _psych_kargs,
                err_xoffset=err_xoffset)
  # Sort legend by labels
  handles, labels = PsycStim_axes.get_legend_handles_labels()
  handles_labels = sorted(zip(handles, labels), key=lambda hndl_lbl:hndl_lbl[1])
  handels, labels = zip(*handles_labels)
  PsycStim_axes.legend(handels, labels,
                       prop={'size':'x-small'}, loc='lower left',
                       bbox_to_anchor=(1.01, 0))
  if save_figs:
    analysis.savePlot(save_prefix + f"psych_{part_legend_str}_{animal_name}")
  plt.show()

def optoPsychByAnimal(animal_name, df, *, by_animal, by_session,
                      save_figs, save_prefix):
  save_prefix += f"{animal_name}/"
  for info, df in ChainedGrpBy(df).byBrainRegion().byOptoConfig():#byState():
    brain_region, state = info[-2], info[-1]
    print(f"brain_region: {brain_region} - state: {state}")
    save_prefix_cur = f"{save_prefix}/{brain_region}/"
    optoPsychPlot(animal_name, df,
                  brain_region=brain_region, start_state=state,
                  by_animal=by_animal, by_session=by_session,
                  save_figs=save_figs, save_prefix=save_prefix_cur)

def nfits(df_or_len):
  if hasattr(df_or_len, "__len__"): df_or_len = len(df_or_len)
  _nfits = int(50000/df_or_len)
  _nfits = max(20, min(200, _nfits))
  print(f"nfits for len: {df_or_len} = {_nfits}")
  return 10 #_nfits

