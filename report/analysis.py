#!/usr/bin/env python
# coding: utf-8

import math
import datetime as dt
import pathlib
import os
import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
from matplotlib.font_manager import FontProperties
from matplotlib.lines import Line2D
import numpy as np
import pandas as pd
from enum import Enum, auto, unique

class ExpType(): # Don't create as enum as we will compare with real integers
  LightIntensity = 2
  RDK = 4

  @staticmethod
  def toStr(exp_type):
    if exp_type == ExpType.LightIntensity:
      return "LightIntensity"
    elif exp_type == ExpType.RDK:
      return "RDK"
    else:
      raise ValueError("Unknown exp_type: " + str(exp_type))

#analysis_for = ExpType.LightIntensity if "lightchasing" in DF_FILE.lower() \
#                                      else ExpType.RDK
analysis_for = ExpType.RDK
SCALE_X = None
SCALE_Y = None
SAVE_FIG_SIZE = None
FORMATS = None
DPI = None

def setMatplotlibParams(silent=False):
    global SCALE_X, SCALE_Y, SAVE_FIG_SIZE, FORMATS, DPI

    rc_params = ['figure.figsize','font.size','lines.linewidth',
                 'lines.dashed_pattern','lines.dashdot_pattern',
                 'lines.dotted_pattern']
    if "original_rc" not in locals():
      original_rc = {}
    for attr_name in rc_params:
      if attr_name not in original_rc:
        original_rc[attr_name] = mpl.rcParams[attr_name]

    SAVE_FIG_SIZE = (6.4, 4.8) # original mpl.rcParams['figure.figsize'] is [6.4, 4.8]
    SCALE_X = SAVE_FIG_SIZE[0]/(original_rc['figure.figsize'][0])
    SCALE_Y = SAVE_FIG_SIZE[1]/(original_rc['figure.figsize'][1])
    for attr_name, attr_val in original_rc.items():
      if not hasattr(attr_val, "__len__"):
        new_attr_val = attr_val*SCALE_X
      elif len(attr_val) == 2 or len(attr_val) == 4:
        new_attr_val = (attr_val[0]*SCALE_X, attr_val[1]*SCALE_Y)
        if len(attr_val) == 4:
          new_attr_val = new_attr_val + (attr_val[2]*SCALE_X,
                                         attr_val[3]*SCALE_Y,)
      else:
        new_attr_val = list(map(lambda el:el*SCALE_X, attr_val))
      if not silent:
        print("Updating rcParam[{}] from {} to {}".format(attr_name, attr_val,
                                                          new_attr_val))
      mpl.rcParams[attr_name] = new_attr_val

    DPI = 600
    FORMATS = [".png"]#,".tiff",".pdf",".svg"]
    mpl.rcParams['pdf.fonttype'] = 42
    mpl.rcParams['ps.fonttype'] = 42


def savePlot(title, confd=False, legend=None, animal_name=None):
  titles = []
  #for axis in plt.gcf().axes:
  # titles.append(axis.get_title())
  # axis.set_title("")

  assert "QUICK_RUN" in globals() if confd else True

  if confd and not QUICK_RUN:
    _dir = "cdfc/" + os.path.dirname(title) + "/" + animal_name + "/"
    path = _dir + os.path.basename(title)
  else:
    _dir = "figs/{}".format("sqr/" if (SAVE_FIG_SIZE[0] == SAVE_FIG_SIZE[1]) else "")
    path = "{}{}{}{}".format(_dir, "cdfc_" if confd else "",
                             (animal_name + "_") if animal_name else "",
                             os.path.basename(title))
  pathlib.Path(_dir).mkdir(parents=True, exist_ok=True)

  for f_format in FORMATS:
    final_path = path + f_format
    print("Save path:", final_path)
    plt.savefig(final_path,
                dpi=DPI, bbox_inches='tight',
                bbox_extra_artists=(legend,) if legend else None,
               )#transparent=True)

  #for axis, title in zip(plt.gcf().axes, titles):
  #  axis.set_title(title)

@unique
class PerfPlots(Enum):
  Performance = auto()
  Difficulties = auto()
  DifficultiesCount = auto()
  Bias = auto()
  EarlyWD = auto()
  SamplingT = auto()
  MovementT = auto()
  ReactionT = auto()
  CatchWT = auto()
  MaxFeedbackDelay = auto()
  StimAPO = auto() # Stimulus after poke out
  PortLEDCueRwrd = auto()
  HeadFixDate = auto()

MIN_NUM_SESSION_TRIALS=50
SINGLE_SESSION_BIN_SIZE=20

def performanceOverTime(df, head_fixation_date=None, single_session=None,
                        draw_plots=list(PerfPlots), axes=None, axes_legend=True,
                        reverse_alphas=False):
  animal_name = df.Name.unique()
  assert len(animal_name) == 1 # Assure that we only have one mouse
  if "NameRemapping" in globals():
    animal_name = NameRemapping[animal_name[0]]
  else:
    animal_name = animal_name[0]

  #print("Animal name:", animal_name)
  title = "Session performance " if single_session else 'Performance over time '
  title += animal_name
  if single_session:
    title += df.Date.unique()[0].strftime(" - %Y-%m-%d")
  if not axes:
    axes = plt.axes()
  axes.set_xlabel(xlabel="Trial Num" if single_session else "Session Num")
  axes.set_ylim(0, 105)
  axes.yaxis.set_major_formatter(
                         FuncFormatter(lambda y, _: '{}%'.format(int(y))))
  axes.set_ylabel("Rate (%)")
  axes.set_title(title)

  df = df.sort_values(["Date","SessionNum","TrialNumber"])
  if single_session:
    sessions = df.groupby(df.index//SINGLE_SESSION_BIN_SIZE) # Group every 10 trials
  else:
    sessions = df.groupby([df.Date,df.SessionNum])
  def calcLeftBias(block):
    left_correct_count = block.ChoiceCorrect[block.LeftRewarded == 1].sum()
    right_correct_count = block.ChoiceCorrect[block.LeftRewarded == 0].sum()
    left_count = block.LeftRewarded.sum()
    right_count = num_trials-left_count
    perf_l = 0 if left_count == 0 else left_correct_count/left_count
    perf_r = 0 if right_count == 0 else right_correct_count/right_count
    return (perf_l-perf_r)/2+0.5

  x_data = []
  performance = []
  EWD = []
  left_bias = []
  sampling_time = []
  sampling_std = []
  stim_poke_out = []
  port_cue_led = []
  MT = []
  MT_std = []
  reaction_time = []
  reaction_time_std = []
  num_difficulties = []
  difficulties = [] # This will be array of arrays
  catch_wt_correct = []
  catch_wt_error = []
  used_feedback_delay = []
  head_fixation_session=None
  num_sessions = 0
  for date_sessionnum, block in sessions:
    if single_session:
      #print("date_sessionnum:",date_sessionnum, "Block:", block.TrialNumber)
      bin_idx = date_sessionnum
      num_trials = len(block)
      if num_trials < 2: # Should happen only with last bin
        continue
      choice_made = block[block.ChoiceLeft.notnull()]
      if len(choice_made):
        block_performance = (len(choice_made[choice_made.ChoiceCorrect==1])/
                             len(choice_made))
      else:
        block_performance = 0
    else:
      date, session_num = date_sessionnum
      #print("Session:",date,session_num)
      num_trials = block.MaxTrial.unique()[0]
      if num_trials < MIN_NUM_SESSION_TRIALS:
        continue
      block_performance = block.SessionPerformance.unique()[0]/100.0
    #print("Session num:", date_sessionnum, "- performance:", block_performance)
    performance.append(block_performance)
    x_data.append(block.TrialNumber.max() if single_session
                  else len(performance))
    EWD.append(block.EarlyWithdrawal.sum()/num_trials)
    left_bias.append(calcLeftBias(block))
    sampling_time.append(block.ST.mean())
    sampling_std.append(block.ST.std())
    stim_poke_out.append(round(block.GUI_StimAfterPokeOut.sum()/num_trials))
    port_cue_led.append(round(block.ForcedLEDTrial.sum()/num_trials))
    MT.append(block.MT.mean())
    MT_std.append(block.MT.std())
    valid_reaction_time = block.ReactionTime[block.ReactionTime != -1]
    reaction_time.append(valid_reaction_time.mean())
    reaction_time_std.append(valid_reaction_time.std())
    used_feedback_delay.append(block.GUI_FeedbackDelayMax.mean())
    catch_error_trials = block[(block.GUI_CatchError == True) &
                               (block.ChoiceCorrect == 0)]
    if len(catch_error_trials):
        catch_wt_error.append(catch_error_trials.FeedbackTime.mean())
    else:
        catch_wt_error.append(np.NaN)
    catch_correct = block[(block.CatchTrial == 1) & (block.ChoiceCorrect == 1)]
    if len(catch_correct):
        catch_wt_correct.append(catch_correct.FeedbackTime.mean())
    else:
        catch_wt_correct.append(np.NaN)

    used_difficulties = []
    num_points = 0
    for diff in [block.Difficulty1, block.Difficulty2,
                 block.Difficulty3, block.Difficulty4]:
      valid_diff = diff[diff.notnull()]
      # Was used for more 10% of the block, and discard parts where the
      # experimenter temporarily had multiple values while updating table
      if len(valid_diff) >= 5 and len(valid_diff) > len(block)/10:
        mean_valid_diff = valid_diff.mean()
        exp_type = block.GUI_ExperimentType.unique()
        if len(exp_type) == 1 and exp_type[0] == ExpType.RDK:
          mean_valid_diff = (mean_valid_diff - 50)*2 # Convert to RDK coherence
        used_difficulties.append(mean_valid_diff)
        num_points += 1
      else:
        used_difficulties.append(np.nan)
    difficulties.append(used_difficulties)
    num_difficulties.append(min(3,num_points))

    if head_fixation_date is not None and head_fixation_session is None and \
     date >= head_fixation_date:
      # The length of any list will do
      head_fixation_session =  len(performance) -1

    num_sessions += 1
  # Convert difficulties to list of each difficulty
  difficulties = list(zip(*difficulties))
  MAX_COUNT_DIFFICULTY= len(difficulties) # i.e == 4
  #print("Difficulties:", difficulties)

  x_data=np.array(x_data,dtype=np.int)
  #TODO: Do session all performance
  axes.set_xlim(x_data[0],x_data[-1])
  plots=[PerfPlots.Performance, PerfPlots.EarlyWD, PerfPlots.Bias] + \
        [PerfPlots.Difficulties]*MAX_COUNT_DIFFICULTY
  from colour import Color as ColorLib
  green=ColorLib("green")
  color=['k','b','c'] + \
        list(map(lambda c: c.hex,
             green.range_to(ColorLib("orange"),MAX_COUNT_DIFFICULTY)))
  label=["Performance Rate","Early-Withdrawal Rate","Left Bias Rate"] + \
        ["Difficulty {}".format(i+1) for i in range(MAX_COUNT_DIFFICULTY)]
  alpha=[1.0,1.0,0.6] + [0.8]*MAX_COUNT_DIFFICULTY
  # Multiply rates by 100 to convert to percentages
  metrics=[np.array(metric)*100 for metric in [performance, EWD, left_bias]] + \
          difficulties
  for i, metric in enumerate(metrics):
    if plots[i] not in draw_plots or np.nansum(metric) == 0:
      continue
    #print("Label:", label[i], "x_data:", len(x_data), "- metric:", len(metric))
    axes.plot(x_data,metric,color=color[i],label=label[i],alpha=alpha[i])

  if PerfPlots.DifficultiesCount in draw_plots:
    color_map=plt.cm.get_cmap('gist_gray')
    def colorMapIdx(num_difficulties): # Map 1-->3 to 0-->1.0
      #return 3 if num_difficulties == 3 else 1 - ((num_difficulties-1)/3)
      return 0 if num_difficulties == 1 else num_difficulties/3

    for i in range(len(x_data)):
      axes.scatter(x_data[i], performance[i]*100,
                   color=color_map(colorMapIdx(num_difficulties[i])),
                   edgecolors='k', marker='o',zorder=10,
                   s=max(20*SCALE_X, min(50*SCALE_X, SCALE_X*7500/num_sessions)))

  if PerfPlots.StimAPO in draw_plots:
    arr_stim_poke_out = np.ones(len(stim_poke_out)) * 100
    arr_stim_poke_out[(np.where(np.array(stim_poke_out) == 0)[0])] = np.nan
    axes.step(x_data,arr_stim_poke_out,color='g',linestyle='-',
              label='Stim-After-Poke',alpha=0.5,where="mid")


  if any(perf_plot in draw_plots for perf_plot in [PerfPlots.SamplingT,
                                                   PerfPlots.MovementT,
                                                   PerfPlots.ReactionT,
                                                   PerfPlots.MaxFeedbackDelay,
                                                   PerfPlots.CatchWT]):
    axes2 = axes.twinx()
    axes2.tick_params(axis='y', labelcolor='k')
    axes2.set_ylabel('Time (s)', color='k')
    axes2.set_ylim(0, max(4,max(catch_wt_correct),max(catch_wt_error)))
    plots = [PerfPlots.SamplingT, PerfPlots.MovementT,
             PerfPlots.ReactionT, PerfPlots.MaxFeedbackDelay,
             PerfPlots.CatchWT, PerfPlots.CatchWT]
    color=['r','m',"gray","orange",'g','r']
    if not reverse_alphas:
        alpha=[1.0, 0.6, 0.8, 0.5, 1.0, 1.0]
        shaded_alpha=[0.1, 0.15, 0.1, None, None, None]
    else:
        alpha=[0.2, 0.8, 0.8, 0.5, 1.0, 1.0]
        shaded_alpha=[0.04, 0.1, 0.1, None, None, None]
    linestyle=['-', '-','-','-',"None","None"]
    marker=[None,None,None,None,'+','+']
    label=["Sampling Time (s)", "Movement Time (s)", "Reaction Time (s)",
           "Used Feedback Delay (s)", "Catch Correct (s)", "Catch Error (s)"]
    stds = [sampling_std, MT_std, reaction_time_std, None, None, None]
    for i, metric_data in enumerate([sampling_time, MT, reaction_time,
                                     used_feedback_delay, catch_wt_correct,
                                     catch_wt_error]):
      if plots[i] not in draw_plots or np.nansum(metric_data) == 0:
        continue
      axes2.plot(x_data,metric_data,color=color[i],linestyle=linestyle[i],
                 label=label[i],alpha=alpha[i],markeredgecolor=color[i],
                 marker=marker[i])
      if stds[i]:
        metric_data=np.array(metric_data)
        axes2.fill_between(x_data,metric_data-stds[i],metric_data+stds[i],
                           color=color[i],alpha=shaded_alpha[i])

  lines, labels = axes.get_legend_handles_labels()
  # Add horizontal and vertical now after we got the labels, and add them later
  # to the legend manually otherwise verticla lines doesn't show up in the
  # legend correctly.
  axes.axhline(y=0.5*100, color='gray',linestyle='dashed',zorder=-1)
  if (PerfPlots.HeadFixDate in draw_plots) and head_fixation_date \
   and head_fixation_session:
    axes.axvline(x=head_fixation_session,color='gray',linestyle='-',alpha=1,
                 zorder=-1)
    lines.append(Line2D([], [], marker='|',linestyle='None',color='gray',
                 alpha=0.8, markersize=10*SCALE_X))
    labels.append("$1^{st}$ head-fixed session")

  if not axes_legend:
    return

  # Continue getting the rest of the labels
  lines2, labels2 = axes2.get_legend_handles_labels()
  lines3=[]  # For difficulties  markers
  labels3=[] # Also for difficulties markers
  if PerfPlots.DifficultiesCount in draw_plots:
    for i in range(1,4):
      # Don't create entry in legend if difficulty count was not used
      if i not in num_difficulties:
        continue
      lines3.append(Line2D([], [], color=color_map(colorMapIdx(i)), marker='o',
                    linestyle='None',markersize=7.5*SCALE_X,markeredgecolor='k'))
      labels3.append('{} difficult{}'.format(i, 'y' if i == 1 else 'ies'))

  fontP = FontProperties()
  fontP.set_size('small')
  #bbox_to_anchor=(1.5, 1.05)
  #bbox_to_anchor=(1*6.0/SAVE_FIG_SIZE[0], -0.15*4.0/SAVE_FIG_SIZE[1])
  bbox_to_anchor=(0.5,-0.18)
  legend = axes2.legend(lines + lines2 + lines3,labels + labels2 + labels3,
               loc='upper center',
               bbox_to_anchor=bbox_to_anchor,ncol=3,fancybox=True,#shadow=True)
               prop=fontP)
  return legend


def initialTraining(df, animal_name, max_num_sessions):
  title = 'Stimulus  used - '+ NameRemapping[animal_name]
  axes = plt.axes(ylim=[0, 1.05],xlim=[1,max_num_sessions],xlabel="Session Num",
                  ylabel="Rate",title=title)
  assert len(df.Name.unique()) == 1 # Assure that we only have one mouse
  df = df.sort_values(["Date","SessionNum","TrialNumber"])
  sessions = df.groupby([df.Date,df.SessionNum])
  exp_types = []
  led_cue_rate = []
  stim_poke_out=[]
  performance=[]
  count=0

  for (date, session_num), session in sessions:
    #print("Session:",date,session_num)
    num_trials = session.MaxTrial.unique()[0]
    if num_trials < 50:
      continue
    performance.append(session.SessionPerformance.unique()[0]/100.0)
    exp_type = session.GUI_ExperimentType.unique()
    if len(exp_type) > 1: print("*Found many experiment-types for ",animal_name)
    exp_str = ExpType.toStr(exp_type[0])
    exp_types.append(exp_str)
    if exp_type[0] == ExpType.LightIntensity:
      led_cue_rate.append(np.nan)
    else:
      led_cue_rate.append(session.ForcedLEDTrial.sum()/num_trials)
    stim_poke_out.append(session.GUI_StimAfterPokeOut.sum()/num_trials)
    count += 1
    if count == max_num_sessions:
      break

  color=['r','b']
  for i, exp_type in enumerate([ExpType.toStr(ExpType.LightIntensity),
                                ExpType.toStr(ExpType.RDK)]):
    indices_x = np.where(np.array(exp_types) == exp_type)[0]
    if not len(indices_x):
      continue
    # Start from trial 1
    indices_x += 1
    # Plot every consecutive range
    start_idx = 0
    while start_idx < len(indices_x):
        end_idx = start_idx
        #print("Start idx:", start_idx,"- end_idx:", end_idx)
        while end_idx + 1 < len(indices_x) and               indices_x[end_idx] + 1 == indices_x[end_idx+1]:
            end_idx += 1
        gap = [indices_x[start_idx], indices_x[end_idx] + 1]
        #print("Final gap:",gap)
        axes.fill_between(gap,0,1,color=color[i],alpha=0.05,label=exp_type)
        start_idx = end_idx + 1

  x_data = np.arange(1,len(performance)+1)
  print("Nan at: ", led_cue_rate)
  print("x_data:", x_data)
  label=["Performance Rate","LED Cue Reward"]#,"Stim-After-Poke"]
  alpha=[1.0, 0.5]#,0.5]
  color=['k','r']#,'g']
  kargs=[{},{"where":"post"}]
  func=[axes.plot, axes.step]#, axes.step]
  for i, metric in enumerate([performance, led_cue_rate]):#, stim_poke_out]):
    func[i](x_data,metric,color=color[i],linestyle='-',label=label[i],
            **kargs[i])

  axes.axhline(y=0.5, color='gray',linestyle='dashed',zorder=-1)
  axes.legend(loc='lower right')
  fig = plt.gcf()
  exp_str = "LightChasing" if analysis_for==ExpType.LightIntensity else "RDK"
  fig.savefig("Initial_{}_{}_sessions_{}.png".format(exp_str,max_num_sessions,
                                                     animal_name), dpi=400)

@unique
class StackMetricUnit(Enum):
  Ratio = auto()
  Percent = auto()
  Seconds = auto()

def stackMetric(metric_col_name, df, axes_raw, axes_avg, *,
                limit_session_at_max_trials, trials_groupping_bin_size,
                stack_metric_unit,  min_num_pts_per_animal_bin,
                min_session_len=None, animals_colors=[]):
  for color_idx, (animal_name, animal_df) in enumerate(df.groupby(df.Name)):
    print("Processing animal:", animal_name)
    metric_avgs = []
    sessions_count = 0
    trials_count = 0
    for (date, sess_num), sess_df in animal_df.groupby([animal_df.Date,
                                                        animal_df.SessionNum]):
      if min_session_len and sess_df.MaxTrial.iloc[0] <= min_session_len:
        continue
      sess_df = sess_df[sess_df.TrialNumber < limit_session_at_max_trials]
      sess_df = sess_df.reset_index()
      sessions_count += 1 # TODO: Remove session if none of its values were used
      #print("Max tria:", sess_df.TrialNumber.max())
      # We can also cut using np.linspace()
      #group_by_arg = pd.cut(sess_df.TrialNumber, trials_groupping_bin_size,
      #                      labels=False, include_lowest=True)
      for bin_idx, trials_block_df in sess_df.reset_index().groupby(
                                      sess_df.index//trials_groupping_bin_size):
        # print("Date:",date,"Session num:",sess_num,"Trials bin df:",bin_idx)
        col = trials_block_df[metric_col_name]
        col = col[col.notnull()]
        if not len(col):
          continue
        trials_count += len(col)
        mean_val = col.mean()
        if len(metric_avgs) <= bin_idx:
          metric_avgs.append([])
        metric_avgs[bin_idx].append(mean_val)
        # We can also draw the raw axes here, but we can combine it with the
        # other plotting few lines below
    print("Calculating sessions mean and sem for", animal_name)
    print("Metric avg len:", len(metric_avgs))
    # The next variable holds the mean of means for each bin, however we might
    # skip some bins if they don't have eough points. Logic entails that if we
    # skip bin_idx = x then we will skip all bin_idx > x. So array will be
    # suffice, and to be sure, we will use np.nan for skipped entries
    metric_mean_of_means = []
    metric_sem = []
    detected_skip=False
    label = "{} ({} sessions - {:,} trials)".format(animal_name, sessions_count,
                                                    trials_count)
    color = animals_colors[color_idx] if len(animals_colors) else None
    for x_tick, means_array in enumerate(metric_avgs):
      if len(means_array) < min_num_pts_per_animal_bin:
        metric_mean_of_means.append(np.nan)
        metric_sem.append(np.nan)
        detected_skip = True
        continue
      assert not detected_skip # We shouldn't reach this point if we skipped a
                               # bin earlier
      x_val = (1+x_tick) * trials_groupping_bin_size
      if stack_metric_unit == StackMetricUnit.Percent:
        means_array = np.array(means_array)*100
      axes_raw.scatter([x_val]*len(means_array), means_array, color=color,
                       s=2, label=label if x_tick is 0 else None)
      metric_mean_of_means.append(np.mean(means_array))
      from scipy.stats import sem # Could also just create a pandas series
      metric_sem.append(sem(means_array))
    Xs = range(trials_groupping_bin_size,
               (len(metric_avgs)+1)*trials_groupping_bin_size,
               trials_groupping_bin_size)
    Xs = np.array(Xs)
    Ys = np.array(metric_mean_of_means)
    metric_sem = np.array(metric_sem)
    #if stack_metric_unit == StackMetricUnit.Percent:
    # Mean arrays was already multiplied by 100 when calculating raw values
    # above for percent
    axes_avg.plot(Xs, Ys, color=color, label=label)
    axes_avg.fill_between(Xs, Ys + metric_sem, Ys - metric_sem, color=color,
                          alpha=0.2)
  fontP = FontProperties()
  fontP.set_size('small')
  bbox_to_anchor=(0.5,-0.07)
  for axes in [axes_raw, axes_avg]:
    axes.legend(loc='upper center', bbox_to_anchor=bbox_to_anchor, ncol=2,
                fancybox=True, prop=fontP)
    axes.set_xlabel("Trial Number")
    axes.set_xlim(xmin=0)
    axes.set_ylim(bottom=0)
    if stack_metric_unit == StackMetricUnit.Percent:
      #axes.set_ylabel("(%)")
      axes.yaxis.set_major_formatter(
                         FuncFormatter(lambda y, _: '{}%'.format(int(y))))
      axes.set_ylim(ymax=100)
    elif stack_metric_unit == StackMetricUnit.Seconds:
      axes.set_ylabel("Seconds")
    elif stack_metric_unit == StackMetricUnit.Ratio:
      axes.set_ylabel("Ratio")
      axes.set_ylim(ymax=1)

def trialRate(df, axes):
  axes.set_title("Trial Rate - {}".format(" ".join(df.Name.unique())))
  groups = df.groupby([df.Date, df.SessionNum])
  if not len(groups):
    return
  # Our sessions doesn't go generally beyond 1.5 hours. I found an instance
  # where TrialStartTimeStamp give strange times (e.g vgat2)
  MAX_SESSION_TIME = 3*60*60
  # Get each session time total time
  sessions_times = []
  for (date, session_num), session_df in groups:
    session_time = session_df.TrialStartTimestamp.max() - \
                   session_df.TrialStartTimestamp.min()
    if session_time > MAX_SESSION_TIME:
      continue
    sessions_times.append(session_time)
    continue # Comment this line for debuggig info
    from time import asctime, localtime
    print("session date:", date, session_num,
          "session time: {:,.2f}".format(sessions_times[-1]/60),
          "- Num. trials:", session_df.TrialNumber.max(),
          "- Min:", asctime(localtime(session_df.TrialStartSysTime.min())),
          "- Max:", asctime(localtime(session_df.TrialStartSysTime.max())))
  # Calculate the sessions times and IQR so we can filter later based on them
  Q1 = np.quantile(sessions_times, 0.25)
  Q3 = np.quantile(sessions_times, 0.75)
  IQR = Q3 - Q1
  print("Num. Sessions: {}".format(len(groups)))
  print("Sessions Time: IQR: {} - Q1: {} - Q3: {} - Lower-bound: {} - "
        "Upper-bound: {}".format(IQR//60, Q1//60, Q3//60, (Q1-1.5*IQR)//60,
                                 (Q3+1.5*IQR)//60))

  done_once = False
  incl_sessions = []
  for (date, session_num), session_df in groups:
    x_data = session_df.TrialStartTimestamp - \
             session_df.TrialStartTimestamp.min()
    session_max_time = x_data.max()
    if session_max_time > MAX_SESSION_TIME:
      print("Skipping {}-SessNum:{} - unrealistic max time: {:,}".format(date,
            session_num, session_max_time))
      continue
    elif session_max_time < Q1-1.5*IQR or session_max_time > Q3 + 1.5*IQR:
      print("Skipping {}-SessNum:{} - max time: {:,} - num. trials: {}".format(
            date, session_num, int(session_max_time//60),
            session_df.TrialNumber.max()))
      continue
    label = "Single Session ({} sessions)".format(len(groups)) if not done_once\
                                                               else None
    done_once = True
    x_data_min = x_data / 60 # Convert to minutes
    axes.plot(x_data_min, session_df.TrialNumber, color="gray", label=label)
    incl_sessions.append(pd.DataFrame({"Time":x_data,
                                       "TrialNumber":session_df.TrialNumber}))

  # Draw the average curve only if we have more than one session
  if len(incl_sessions) > 1:
    max_sessions_time, max_sessions_trials = list(zip(*map(
      lambda grp: (grp.Time.max(), grp.TrialNumber.max()), incl_sessions)))
    median_session_time = np.median(max_sessions_time)
    median_session_trials_num = np.median(max_sessions_trials)
    print("Median session time:", median_session_time/60)
    print("Median session trial nums:", median_session_trials_num)
    # Get 95% of the max times that exists in all the sessions, such that we
    # discard unusually long sessions when we plot the fitting function
    max_session_time_lim = np.percentile(max_sessions_time, 95)
    print("Max session time limit:", max_session_time_lim)
    incl_sessions = pd.concat(incl_sessions)
    incl_sessions = incl_sessions[incl_sessions.Time < max_session_time_lim]
    incl_sessions.sort_values("Time", inplace=True)
    def fitFunc(data, c0, c1):
     return  c0*data + c1*np.sqrt(data)
    # Using qcut value of 1 has no effect
    for bin, bin_df in incl_sessions.groupby(pd.qcut(incl_sessions.Time, 1)):
      x_data = bin_df.Time.values
      # We need to interpolate the average curve from the other curves
      from scipy.optimize import curve_fit
      optimized_Cs, optimize_covar = curve_fit(fitFunc, x_data,
                                               bin_df.TrialNumber.values)
      # print("Bin:", bin, "x-len:", np.min(x_data), np.max(x_data),
      #       "Optimized Cs:", optimized_Cs)
      y_data = fitFunc(x_data, *optimized_Cs)
      x_data_min = x_data / 60
      axes.plot(x_data_min, y_data, color="k", label="Sessions Average",
                linewidth=3*SCALE_X, alpha=0.8)

    axes.axvline(median_session_time/60, linestyle="dashed", color='k',
                 label="Median Session Time", alpha=0.8,
                 zorder=len(max_sessions_time)) # Draw below average line
    axes.axhline(median_session_trials_num, linestyle="dashed", color='k',
                 label="Median Session Trials Count", alpha=0.8,
                 zorder=len(max_sessions_time))

  axes.xaxis.set_major_formatter(FuncFormatter(lambda x, _:'{}'.format(int(x))))
  #axes.yaxis.tick_right()
  #axes.yaxis.set_label_position("right")
  axes.set_xlabel("Time (Minutes)")
  axes.set_ylabel("Trial Number")
  axes.set_xlim(xmin=0)
  axes.set_ylim(ymin=0)

  if len(groups) > 1:
    pass # TODO: Implement this
    #groups.aggregate
    axes.legend(loc="upper left")


def interceptSlope(df):
  ndxNan = df.ChoiceLeft.isnull()
  ndxChoice = df.ForcedLEDTrial == 0
  StimDV = df.DV
  x = StimDV[(~ndxNan) & ndxChoice]
  y = df.ChoiceLeft[(~ndxNan) & ndxChoice]
  import statsmodels.formula.api as smf
  import statsmodels.api as sm
  import statsmodels.tools.sm_exceptions as sm_exceptions
  #print("Len(y):", len(y))
  if not len(y):
    return None, None
  glm_df = pd.DataFrame({'DV':x, 'ChoiceLeft':y})
  mod1 = smf.glm('ChoiceLeft~DV', data=glm_df,
                 family=sm.families.Binomial(sm.families.links.logit()))
  try:
    glm_res = mod1.fit()
  except sm_exceptions.PerfectSeparationError:
    print("skipping GLM fit for for session(s):", df.Date.unique())
    print("PsycX len: ", len(x), len(y))
    return None, None
  #print(glm_res.summary())
  intercept, slope = glm_res.params
  return intercept, slope

def psychAxes(animal_name="", axes=None):
    title="Psychometric Stim{}".format(
                                  " " + animal_name if len(animal_name) else "")
    x_label= "RDK Coherence"  if analysis_for == ExpType.RDK else "Light Intensity"
    if not axes:
        axes = plt.axes()
    #axes.set_ylim(-.05, 1.05)
    axes.set_ylim(-5, 105)
    axes.set_xlim(-1.05, 1.05)
    axes.set_xlabel(x_label)
    axes.set_ylabel("Choice Left (%)")
    axes.yaxis.set_major_formatter(
                         FuncFormatter(lambda y, _: '{}%'.format(int(y))))
    axes.set_title(title)

    x_ticks=np.arange(-1,1.1,0.4)
    def cohrStr(tick):
      cohr = int(round(100*tick))
      return "{}%{}".format(abs(cohr),'R' if cohr<0 else "" if cohr==0 else 'L')
    x_labels=list(map(cohrStr, x_ticks))
    axes.set_xticks(x_ticks)
    axes.set_xticklabels(x_labels)
    axes.axvline(x=0, color='gray', linestyle='dashed', zorder=-10)
    axes.axhline(y=50, color='gray', linestyle='dashed', zorder=-10)
    return axes

def psychAll(df, PsycStim_axes):
    _psych(df, PsycStim_axes, 'k', 3, "All")

def _psych(df, PsycStim_axes, color, linewidth, legend_name, plot_points=True,
           offset=False, SEM=False, GLM=True, min_slope=None):
    '''Do the actual plotting'''
    #ndxNan = isnan(DataCustom.ChoiceLeft);
    ndxNan = df.ChoiceLeft.isnull()
    ndxChoice = df.ForcedLEDTrial == 0
    StimDV = df.DV
    if plot_points:
      StimBin = 10
      EXTRA_BIN=2
      BinIdx = pd.cut(StimDV,np.linspace(StimDV.min(), StimDV.max(),
                      StimBin+EXTRA_BIN), labels=False, include_lowest=True)
      # Choice trials
      PsycY = df.ChoiceLeft[(~ndxNan) & ndxChoice].groupby(
                                             BinIdx[~ndxNan & ndxChoice]).mean()
      PsycY *= 100 # Convert to percentile
      PsycX = (((np.unique(BinIdx[(~ndxNan) & ndxChoice])+1)/StimBin)*2)-1-(
                                                          EXTRA_BIN*(1/StimBin))
      if offset: # Shift points a little bit to the right/light so that their center
                 # would overlap with the histogram bar's center, that's all
        lt_zero = PsycX[PsycX<0]
        gt_zero = PsycX[PsycX>0]
        lt_zero += 0.5/(StimBin/2)
        gt_zero -= 0.5/(StimBin/2)
        PsycX = np.concatenate([lt_zero,gt_zero])

      # WTerr = df.FeedbackTime[ndxError & ndxMinWT].groupby(
                                            #BinIdx[ndxError & ndxMinWT]).mean()
      # Xerr = (((np.unique(BinIdx[ndxError & ndxMinWT])+1)/DVNBin)*2)-1-(
                                                          #EXTRA_BIN*(1/DVNBin))
      PsycStim_axes.plot(PsycX, PsycY, linestyle='none', marker='o',
                         markeredgecolor=color, markerfacecolor=color,
                         markerSize=1.5*linewidth*SCALE_X)

    if np.sum((~ndxNan) & ndxChoice) > 1:
        x = StimDV[(~ndxNan) & ndxChoice]
        y = df.ChoiceLeft[(~ndxNan) & ndxChoice]

        x_sampled = np.linspace(StimDV.min(),StimDV.max(),50)
        if GLM:
          import statsmodels.formula.api as smf
          import statsmodels.api as sm
          import statsmodels.tools.sm_exceptions as sm_exceptions

          glm_df = pd.DataFrame({'DV':x, 'ChoiceLeft':y})
          mod1 = smf.glm('ChoiceLeft~DV', data=glm_df,
                         family=sm.families.Binomial(sm.families.links.logit()))
          try:
            glm_res = mod1.fit()
          except sm_exceptions.PerfectSeparationError:
            print("skipping GLM fit for for session(s):", df.Date.unique())
            print("PsycX len: ", len(x), len(y))
            return None, None
          #print(glm_res.summary())
          intercept, slope = glm_res.params
          if min_slope != None and slope < min_slope:
            return intercept, slope
          #print("Intercept:", intercept, "- Slope:", slope)
          from scipy.special import logit
          y_points = glm_res.predict(pd.DataFrame({'DV':x_sampled}))
          conf_df = glm_res.conf_int()
          int_low, int_upper = conf_df.iloc[0,0], conf_df.iloc[0,1]
          #print("conf df :", conf_df)
          conf_df = glm_res.get_prediction(pd.DataFrame({'DV':x_sampled})).conf_int(alpha=0.05)
          #print("2. conf df :", conf_df.shape)
          int_low = conf_df[:,0]
          int_upper = conf_df[:,1]
          #print("Using int_low:", int_low)
          #print("Using int upper:", int_upper)
        else:
          def fsigmoid(x, a, b):
              return 1.0 / (1.0 + np.exp(-a*(x-b)))
          #y_ind = fsigmoid(np.linspace(-1,1,len(PsycX)), 2, 0)
          from scipy.optimize import curve_fit
          try:
            popt, pcov = curve_fit(fsigmoid, x, y, maxfev=1000)# , method='dogbox',
                                   # bounds=([0, 0.],[100, 1.]))
          except RuntimeError:
            print("skipping sigmoidal fit for for session(s):", df.Date.unique())
            print("PsycX len: ", len(x), len(y))
            return None, None
          else:
            y_points = fsigmoid(x_sampled, *popt)

        #print("Sigmoid: ", fsigmoid(PsycX, *popt))
        if len(legend_name):
          legend_name="{}{}".format(legend_name,
                    "" if not plot_points else " ({:,} trials)".format(len(df)))
        else:
          legend_name=None
        PsycStim_axes.plot(x_sampled, y_points * 100, # Convert y to percentile
                           color=color, linewidth=linewidth*SCALE_X,
                           label=legend_name)

        # print("label: {} - len data: {}".format(legend_name, len(y)))
        if SEM:
          #sem_lower, sem_upper = (int_low, int_upper) if GLM else (-y.sem(), y.sem())
          y_sem_lower = (int_low * 100) if GLM else y_points - (y.sem() * 100)
          y_sem_upper = (int_upper * 100) if GLM else y_points +  (y.sem() * 100)
          PsycStim_axes.fill_between(x_sampled, y_sem_upper, y_sem_lower, color=color,
                                     alpha=0.2)
        if GLM:
          #print("Intercept:", intercept, "- Slope:", slope)
          return intercept, slope
        else:
          return None, None


#chosen_days = RDK_days if analysis_for == ExpType.RDK else lightintensity_days

def psychByAnimal(df, use_chosen_days, PsycStim_axes):
    df_by_anumal = df.groupby(df.Name)
    color_gen=plt.cm.rainbow(np.linspace(0,1,len(df_by_anumal)))
    used_sessions=[]
    for (animal_name, animal_df), color in zip(df_by_anumal, color_gen):
      if use_chosen_days:
        animal_days = chosen_days.get(animal_name, None)
        if animal_days:
          animal_df = animal_df[animal_df.Date.isin(animal_days)]
        else:
          continue
      animal_df = animal_df[animal_df.MaxTrial > 20]
      if animal_df.empty:
        continue
      LINE_WIDTH=1.5
      _psych(animal_df, PsycStim_axes, color, LINE_WIDTH,
             NameRemapping[animal_name])
      used_sessions.append(animal_df)
    return pd.concat(used_sessions)


ChooseDays=True
# Attempt to reduce memory usage
def dfGenerator():
  count = 0
  while True:
    if count == 0:
      yield (df,"","all", not ChooseDays)
    elif count == 1:
      yield (df[df.Name.isin(AnimalsOldBatch)],"","all_old_batch", not ChooseDays)
    elif count == 2:
      yield (df,"(selected days)","chosen_days", ChooseDays)
    elif count == 3:
      yield (df[df.SessionPerformance > 70],"(Perf. > 70%)","above_70_percent",
             not ChooseDays)
    elif count == 4:
      yield (df[df.Name.isin(AnimalsOldBatch) & (df.SessionPerformance > 70)],
             "(Perf. > 70%)","above_70_percent_old_batch", not ChooseDays)
    else:
        break
    count += 1


METHOD="sum"
def psychAnimalSessions(df,ANIMAL,PsycStim_axes,METHOD):
    if not len(df):
        return
    assert len(df.Name.unique()) == 1 # Assure that we only have one mouse
    df = df.sort_values(["Date","SessionNum","TrialNumber"])
    sessions = df.groupby([df.Date, df.SessionNum])
    used_sessions = []
    done_once = False
    for i, (date_sessionnum, session) in enumerate(sessions):
      date, session_num = date_sessionnum
      #print("Session:",date,session_num)
      num_trials = session.MaxTrial.unique()[0]
      title="Single Session Performance" if not done_once else ""
      LINE_WIDTH=0.5
      ret = _psych(session,PsycStim_axes,"gray",LINE_WIDTH,title,
                   plot_points=False)
      if ret != (None, None):
        done_once = True
        used_sessions.append(session)
    # Merge used sessions
    sessions = pd.concat(used_sessions)
    LINE_WIDTH=3
    _psych(sessions, PsycStim_axes,'k',LINE_WIDTH,"Avg. Session Performance",
           offset=True)
    plotNormTrialDistrib(sessions,PsycStim_axes,METHOD)
    handles, labels = PsycStim_axes.get_legend_handles_labels()
    labels[0] = labels[0] + " ({:,} sessions)".format(len(used_sessions))
    #PsycStim_axes.legend(handles, labels, loc='upper left', prop={'size': 'x-small'})
    bbox_to_anchor = (0.5, -0.2)
    PsycStim_axes.legend(handles, labels, loc='upper center',
              bbox_to_anchor=bbox_to_anchor,ncol=2,fancybox=True,
              prop={'size': 'x-small'})

def plotNormTrialDistrib(df,axes,METHOD):
    ndxNan = df.ChoiceLeft.isnull()
    ndxChoice = df.ForcedLEDTrial == 0
    difficulties = df.DV[(~ndxNan) & ndxChoice]
    counts, bins = np.histogram(difficulties,bins=10)
    counts = counts.astype(np.float)
    if METHOD == "max":
      counts /= counts.max()
    elif METHOD == "sum":
      counts /= sum(counts)
    else:
      raise ("Unknown METHOD " + METHOD)
    axes.bar(bins[:-1],counts*100,width=0.2,align='edge',zorder=-1,color='pink',
             edgecolor='k',label="Norm. difficulty distribution")


def filterSession(df,skip_first,skip_last,min_date,min_perf):
    all_sessions = df.groupby([df.Date,df.SessionNum])
    used_sessions = []
    for (date, session_num), session in all_sessions:
      if date < min_date or session.SessionPerformance.unique()[0] < min_perf:
        continue

      num_points = 0
      for diff in [session.Difficulty1, session.Difficulty2,
                   session.Difficulty3, session.Difficulty4]:
        valid_diff = diff[diff.notnull()]
        # Was used for more 10% of the block, and discard parts where the
        # experimenter temporarily had multiple values while updating table
        if len(valid_diff) >= 5 and len(valid_diff) > len(block)/10:
          num_points += 1

      if num_points < 3:
        continue
      used_sessions.append(session[(skip_first < session.TrialNumber) &
                           (session.TrialNumber < len(session) - skip_last)])
    if not len(used_sessions):
      print("Not enough sessions matching criteria found for:",
            df.Name.unique()[0])
      return None
    return pd.concat(used_sessions)

def plotMT(df, color, axes, normalize):
    #df = filterSession(df,10,10,dt.date(2019,4,1),70)
    df = filterSession(df,20,50,dt.date(2019,1,1),0)
    if df is None:
      return
    ndxNan = df.ChoiceLeft.isnull()
    ndxChoice = df.ForcedLEDTrial == 0
    df = df[(~ndxNan) & ndxChoice & (df.ChoiceCorrect == 1)]
    groups = df.groupby(df.DV)
    Xs=[]
    Ys=[]
    min_rt, max_rt = 100, 0
    for group_name, group in groups:
      if len(group) < 100:
        continue
      Xs.append(group_name)
      Ys.append(group.ReactionTime.median())
      min_rt = min(min_rt, group.ReactionTime.median())
      max_rt = max(max_rt, group.ReactionTime.median())
      #print("Group:", group.MT.mean(), "Group_name:", group_name)
    Xs=np.array(Xs,dtype=np.float)
    Ys=np.array(Ys,dtype=np.float)
    if normalize:
      print("Ys:",Ys)
      Ys/=Ys.max()
    else:
      axes.set_ylim([min_rt,max_rt])
    axes.plot(Xs,Ys,color=color,marker='o',label=df.Name.unique()[0])

def plotEWD(df, color, axes):
    #df = filterSession(df,30,50,dt.date(2019,4,1),70)
    df = filterSession(df,30,50,dt.date(2019,1,1),0)
    if df is None:
      return
    ndxNan = df.ChoiceLeft.isnull()
    groups = df.groupby(df.DV)
    difficulties_all_count=pd.Series()
    difficulties_EWD_count=pd.Series()
    for group_name, group in groups:
      difficulties_all_count = difficulties_all_count.append(group.DV)
      difficulties_EWD_count = difficulties_EWD_count.append(group[
                                                   group.EarlyWithdrawal==1].DV)
    counts_EWD,bins=np.histogram(difficulties_EWD_count,bins=10)
    counts_all,bins=np.histogram(difficulties_all_count,bins=10)
    counts=counts_EWD/counts_all
    np.nan_to_num(counts,copy=False) # Convert nan to zero
    counts /= counts.max()
    axes.bar(bins[:-1],counts,width=0.2,align='edge',color=color,
             edgecolor='k')

#chosen_days = RDK_days if analysis_for == ExpType.RDK else lightintensity_days


def chronometry(df, axes):
  df = df[df.ChoiceCorrect.notnull()]

  df['DVabs'] = df.DV.abs()
  #color_gen=iter(plt.cm.rainbow(np.linspace(0,1,len(df.DVabs.unique()))))
  color_gen=iter(['r','g','b'])

  COHRS=[10,50,100]
  df = df[(df.MinSample <= 1.2) | (df.MinSample == 1.5)]
  all_x_points = set()
  if not len(df.DVabs.unique()):
    return
  for idx, (DV_val, DV_data) in enumerate(df.groupby(pd.cut(df.DVabs,3))):
    x_data = []
    y_data = []
    y_data_sem = []
    num_points = 0
    #for min_sampling, ms_data in DV_data.groupby(DV_data.MinSample):
    min_sampling_pts = [0.3, 0.6, 0.9, 1.2, 1.5]
    for min_sampling in min_sampling_pts:
      ms_data = DV_data[DV_data.MinSample.between(min_sampling - 0.001, min_sampling + 0.001)]
      x_data.append(min_sampling)
      all_x_points.add(min_sampling)
      #perf = len(ms_data[ms_data.ChoiceCorrect == 1])/len(ms_data)
      #y_data.append(perf)
      num_points += len(ms_data.ChoiceCorrect)
      y_data.append(ms_data.ChoiceCorrect.mean()*100)
      y_data_sem.append(ms_data.ChoiceCorrect.sem()*100)
    color=next(color_gen)
    min_DV, max_DV = DV_data.DVabs.min(), DV_data.DVabs.max()
    axes.errorbar(x_data, y_data, yerr=y_data_sem, color=color,
                  label="{}% Coherence ({:,} trials)".format(COHRS[idx], num_points))
  axes.set_title("Chronometry - {}".format(" ".join(df.Name.unique())))
  axes.set_xlabel("Sampling Duration (s)")
  axes.set_ylabel("Performance %")
  axes.set_xticks(sorted(list(all_x_points)))
  axes.legend(loc="upper left", prop={'size': 'x-small'})


def samplingVsDiff(df, axes, overlap_sides = False):
  df = df[df.ChoiceCorrect.notnull()]
  # Should we limit just to correct decisions?
  if overlap_sides:
    df['DVabs'] = df.DV.abs()
    groupby_on = df.DVabs
  else:
    groupby_on = df.DV
  x_data = []
  y_data = []
  y_data_sem = []
  for dv_abs, cohr_data in df.groupby(groupby_on):
    cohr = round(dv_abs* 100)
    print("Cohr:", cohr, "Cohr len:", len(cohr_data), "St mean:", cohr_data.ST.mean())
    x_data.append(cohr)
    y_data.append(cohr_data.ST.mean())
    y_data_sem.append(cohr_data.ST.sem())

  print("X data:", x_data, "y_data:", y_data)
  axes.errorbar(x_data, y_data, yerr=y_data_sem,
                label="Sampling Time ({} pts)".format(len(df)))
  axes.set_title("Samplin vs Difficulty - {} ({} pts)".format(
                 " ".join(df.Name.unique()),len(df)))
  axes.set_xlabel("Coherence %")
  axes.set_ylabel("Sampling Time (S)")
  axes.legend(loc="upper right", prop={'size': 'small'})




def vevaiometric(df, filterGroupFn, vevaiometric_axes, max_feedbacktime):
  df = df[(df.GUI_FeedbackDelaySelection == 3) & (df.GUI_CatchError == True)]
  df = df[(df.FeedbackTime < max_feedbacktime)]
  df = df[(df.FeedbackTime > 0.5)]

  used_data=[]
  FILTER_EARLY=True
  if FILTER_EARLY:
    filtered_df = df[(df.ChoiceCorrect == 0) | (df.CatchTrial == 1)]
    filtered_df = filterGroupFn(filtered_df)
    used_data.append(pd.concat([filtered_df, df[~df.index.isin(filtered_df.index)]])) # This will be the only entry in the array
    df = filtered_df # We no longer need the original df data

  VevaiometricNBin=6
  step=1/(VevaiometricNBin/2)
  #print("Step",step)
  DV_binned = pd.cut(df.DV,VevaiometricNBin)#,labels=np.concatenate(
                    #[np.arange(-1,0,step),np.arange(step,1 + (step/2),step)]))
  #print("DV_binned:",DV_binned.cat.categories)
  df_grouped_by_DV = df.groupby(DV_binned)

  error_groups=[]
  catch_groups=[]
  for group_DV, group_df in df_grouped_by_DV:
    #print("Group_DV", group_DV)
    if not FILTER_EARLY:
      used_data.append(filterGroupFn(group_df))
    error_trials = group_df[group_df.ChoiceCorrect == 0]
    catch_trials = group_df[(group_df.ChoiceCorrect == 1) &
                            (group_df.CatchTrial == 1)]
    for group_type, group_list, name in [(catch_trials, catch_groups, "catch"),
                                         (error_trials, error_groups, "error")]:
      filtered = group_type if FILTER_EARLY else filterGroupFn(group_type)
      group_list.append(filtered)
      #print("Rejected",name,"trials:",
      #      group_type.drop(filtered.index).FeedbackTime)

  #for group_list, name in [(error_groups,"Error"),(catch_groups,"Catch")]:
  #  print(name,"groups:",pd.Series(group_list).apply(
  #      lambda group:(group.FeedbackTime.mean(),group.FeedbackTime.std())))

  #vevaiometric_axes = plt.axes(xlim=[-1.05,1.05],xlabel="DV", ylabel="WT (S)",
  #                             title="Vevaiometric - " + df.Name.unique()[0])
  vevaiometric_axes.set_xlim(-1.05,1.05)
  #vevaiometric_axes.set_xlabel("DV")
  x_ticks=np.arange(-1,1.1,0.4)
  def cohrStr(tick):
    cohr = int(round(100*tick))
    return "{}%{}".format(abs(cohr),'R' if cohr<0 else "" if cohr==0 else 'L')
  x_labels=list(map(cohrStr, x_ticks))
  vevaiometric_axes.set_xticks(x_ticks)
  vevaiometric_axes.set_xticklabels(x_labels)
  vevaiometric_axes.set_xlabel("RDK Coherence")
  vevaiometric_axes.set_ylabel("Waiting Time (s)")
  vevaiometric_axes.set_title("Vevaiometric - " + " ".join(df.Name.unique()))

  min_fb=20 # Set initial high number
  max_fb=0
  DRAW_MEANS = True
  for group_list, color, label in [(error_groups,'r',"Error Trials"),
                                   (catch_groups,'g',"Catch Trials")]:
    all_group_points=pd.concat(group_list)
    if not DRAW_MEANS:
      vevaiometric_axes.plot(all_group_points.DV, all_group_points.FeedbackTime,
        linestyle='None', marker='o', markersize=2*SCALE_X, color=color,
        markerfacecolor=color, markeredgecolor=color)
      max_fb=max(max_fb,all_group_points.FeedbackTime.max() + 1)
      min_fb=min(min_fb,max(0,min_fb,all_group_points.FeedbackTime.min() - 1))

    for i in range(2):
      is_left = i==0
      points = all_group_points[all_group_points.DV < 0 if is_left else
                                all_group_points.DV >= 0]
      slope, intercept = np.polyfit(points.DV, points.FeedbackTime, 1)
      # groups_means = pd.Series(group_list).apply(lambda group:(
      #                               group.iloc[0].DV,group.FeedbackTime.mean()))
      # DVs, means = zip(*filter(lambda x:(x[0] < 0 and is_left) or
      #                                     (x[0] > 0 and not is_left),
      #                            groups_means))
      # slope, intercept = np.polyfit(DVs, means, 1)
      x_rng = np.arange(-1,0.1,0.2) if is_left else np.arange(0,1.1,0.2)
      linfit = [slope * i + intercept for i in x_rng]
      _label = "{} ({:,} pts)".format(label, len(all_group_points)) if i== 0 else None
      vevaiometric_axes.plot(x_rng,linfit,linestyle='-',color=color,
                             linewidth=2*SCALE_X, label=_label)
      # Draw SEM
      lower,upper=(0,int(VevaiometricNBin/2)) if not i else (int(VevaiometricNBin/2),VevaiometricNBin)
      #print("i: {} - lower: {} - upper: {}".format(i, lower, upper))
      x_data = []
      y_lower = []
      y_upper = []
      y_means = []
      for idx in range(lower,upper):
        sem = group_list[idx].FeedbackTime.sem()
        mean = group_list[idx].FeedbackTime.mean()
        y_means.append(mean)
        #print("Group:", label, "- i: ", i, "- idx: ", idx, "- Mean:", mean, "- SEM:", sem)
        val = DV_binned.cat.categories[idx].left if not i else DV_binned.cat.categories[idx].right
        DV_VAL = min(max(-1,val), 1)
        y_point = slope * DV_VAL + intercept
        y_upper.append(y_point + sem)
        y_lower.append(y_point - sem)
        x_data.append(DV_VAL)
      vevaiometric_axes.plot(x_data,y_lower,color=color,alpha=0.8)
      vevaiometric_axes.plot(x_data,y_upper,color=color,alpha=0.8)
      if DRAW_MEANS:
        vevaiometric_axes.plot(x_data,y_means,linestyle='None',
                               marker='o',markersize=8*SCALE_X,color=color,
                               markerfacecolor=color,markeredgecolor=color)
        max_fb=max(max_fb,max(y_means) + 1)
        min_fb=min(min_fb,max(0,min(y_means) - 1))

  vevaiometric_axes.set_ylim([min_fb,max_fb])
  vevaiometric_axes.legend(loc='upper right',prop={'size':'small'},ncol=1)
  return pd.concat(used_data)


def _splitByDifficultyDirection(df, filterGroupFn, max_feedback_time):
  df = df[(df.GUI_FeedbackDelaySelection == 3) & (df.GUI_CatchError == True)]
  df = df[(df.FeedbackTime < max_feedback_time)]
  df = df[(df.FeedbackTime > 0.5)]

  ln_space=np.linspace(50,100,4)
  easy=(ln_space[2],ln_space[3])
  medium=(ln_space[1],ln_space[2])
  # Use left=0 for hard to include < 50% perf, use <0 to include 0% as it's closed on the right
  hard=(-0.000001,ln_space[1])
  difficulties = pd.arrays.IntervalArray.from_tuples([easy,medium,hard],closed='right')
  difficulties_labels=["Easy","Medium","Hard"]
  # For DV from -1 to 1
  directions = pd.arrays.IntervalArray.from_tuples([(-1.001,0),(0,1)],closed='right')

  def assignDifficulty(trials):
    DV = trials.name
    #print("DV:", DV)
    #trials = session[df.DV == DV]
    valid_trials=trials[trials.ChoiceCorrect.notnull()]
    if len(valid_trials) < 20: # This wouldn't work with continous DV
      #print("Skipping on:", trials.name)
      return pd.DataFrame(data=[],columns=trials.columns)
    perf = len(valid_trials[valid_trials.ChoiceCorrect==1])/len(valid_trials)
    perf *= 100
    #difficulty = int(difficulties.contains(perf).argmax())
    #direction = "Left" if int(directions.contains(DV).argmax()) == 0 else "Right"
    #print("DV: {:.2f} {} - Perf: {:.2f}% - Difficulty: {} ({}) - Date: {} - {}".format(DV, direction, perf,
    #  "Easy" if difficulty == 0 else "Medium" if difficulty == 1 else "Hard" if difficulty == 2 else ":(",
    #  difficulty, valid_trials.Date.unique(), valid_trials.SessionNum.unique()))
    valid_trials['DifficultyLevel'] = difficulties.contains(perf).argmax()
    valid_trials['DifficultyName'] = difficulties_labels[difficulties.contains(perf).argmax()]
    valid_trials['Direction'] = "Right" if int(directions.contains(DV).argmax()) else "Left"
    return valid_trials

  def splitSession(session):
    #DVs = session.DV.unique()
    return session.groupby(session.DV, group_keys=False).apply(assignDifficulty)

  df.Date = pd.to_datetime(df.Date) # Work around a pandas bug: https://github.com/pandas-dev/pandas/issues/21651
  #print("Date:", df.Date)
  import time
  start = time.time()
  new_df = df.groupby([df.Date,df.SessionNum], group_keys=False).apply(splitSession)
  print("Took:", time.time() - start, "to process data")
  #print("Difficulty:", new_df.Difficulty.unique())
  #print("Direction:", new_df.Direction.unique())
  # These 3 next lines can get out of this function but we keep them to do
  # do the common operations just once
  new_df = new_df[(new_df.ChoiceCorrect == 0) | (new_df.CatchTrial == 1)]
  new_df = filterGroupFn(new_df)
  filtered_df = pd.concat([new_df, df[~df.index.isin(new_df.index)]], sort=True)
  return new_df.sort_values("DifficultyLevel"), filtered_df


def vevaiometricByDiffifculty(difficulty_df, vevaiometric_axes):
  # difficulty_df is the output of _splitByDifficultyDirection()
  # Rename to match other functions
  df = difficulty_df

  vevaiometric_axes.set_xlim(-1.05,1.05)
  #vevaiometric_axes.set_xlabel("DV")
  x_ticks=np.arange(-1,1.1,0.4)
  def cohrStr(tick):
    cohr = int(round(100*tick))
    return "{}%{}".format(abs(cohr),'R' if cohr<0 else "" if cohr==0 else 'L')
  x_labels=list(map(cohrStr, x_ticks))
  vevaiometric_axes.set_xticks(x_ticks)
  vevaiometric_axes.set_xticklabels(x_labels)
  vevaiometric_axes.set_xlabel("RDK Coherence")
  vevaiometric_axes.set_ylabel("Waiting Time (s)")
  vevaiometric_axes.set_title("Vevaiometric by difficulty - "+" ".join(df.Name.unique()))

  difficulties_colors=["purple","cyan","orange"]
  min_WT = 20
  max_WT = 0

  for group_direction, group in df.groupby(df.Direction):
    err_trials=group[group.ChoiceCorrect==0]
    catch_trials=group[(group.ChoiceCorrect==1) & (group.CatchTrial==1)]

    USE_MEAN=True
    for trials_type, name, marker, line_color in [(err_trials,"Error",'s','r'),
                                                  (catch_trials,"Catch",'*','g')]:
      difficulties_WT = [] #np.array([], dtype=np.float)
      difficulties_DV = []
      for difficulty_level, difficulty_trials in trials_type.groupby(trials_type.DifficultyLevel):
        mean_WT = difficulty_trials.FeedbackTime.mean()
        sem_WT = difficulty_trials.FeedbackTime.sem()
        #print("{} {}: {} - {}: {} - mean_WT: {}".format(difficulty_level,
        #      group_direction,
        #      len(df[(df.DifficultyLevel == difficulty_level) & (df.Direction == group_direction)]),
        #      name, len(difficulty_trials), mean_WT))
        mean_DV = difficulty_trials.DV.mean()
        sem_DV = difficulty_trials.DV.sem()
        if USE_MEAN:
          difficulties_WT.append((mean_WT,difficulty_level,))
          difficulties_DV.append(int(difficulty_level))
        else:
          difficulties_WT.append((difficulty_trials.FeedbackTime.values, difficulty_level,))
          difficulties_DV.append(([difficulty_level] * len(difficulty_trials), difficulty_level,))
        #difficulties_WT.append((difficulty_trials.FeedbackTime.mean(), difficulty_level,))
        min_WT = min(min_WT, mean_WT)
        max_WT = max(max_WT, mean_WT)
        color = difficulties_colors[int(difficulty_level)]
        from matplotlib import colors as matplotlib_colors
        rgba = matplotlib_colors.to_rgba(color)
        rgba = rgba[0], rgba[1], rgba[2], 0.5
        if name == "Error":
          rgba =max(rgba[0]-0.2,0),max(rgba[1]-0.2,0),max(rgba[2]-0.2,0),rgba[3]
        #print("Rgba:", rgba)
        if group_direction == "Left": # Write the label once per direction
          difficulty_trials = df[df.DifficultyLevel == difficulty_level]
          if name == "Error":
            difficulty_trials = difficulty_trials[difficulty_trials.ChoiceCorrect == 0]
          else:
            difficulty_trials = difficulty_trials[(difficulty_trials.ChoiceCorrect == 1) &
                                                  (difficulty_trials.CatchTrial == 1)]
          label="{} {} ({:,} pts)".format(difficulty_trials.DifficultyName.unique()[0], name,
                                          len(difficulty_trials))
        else:
          label=None

        l, caps, c = vevaiometric_axes.errorbar(
                        [mean_DV],[mean_WT],xerr=sem_DV, yerr=sem_WT,
                        capsize=5,elinewidth=1*SCALE_X,marker=marker,
                        color=rgba,label=label)
        c[0].set_color('k')
        c[1].set_linestyle('--')
        c[1].set_color('k')

      difficulties_WT.sort(key=lambda elm:elm[1])
      rng = np.linspace(-1,0,3) if group_direction == "Left" else np.linspace(1,0,3)
      if USE_MEAN:
        difficulties_WT = list(map(lambda elm:elm[0], difficulties_WT))
        difficulties_DV.sort()
        print(difficulties_DV)
        difficulties_DV = list(map(lambda elm:rng[elm], difficulties_DV))
      else:
        difficulties_WT = np.concatenate(list(map(lambda elm:elm[0], difficulties_WT)))
        difficulties_DV.sort(key=lambda elm:elm[1])
        #original_dv=np.concatenate(list(map(lambda elm:elm[0], difficulties_DV)))
        difficulties_DV=np.concatenate(list(map(lambda elm:rng[elm[0]], difficulties_DV)))
        #print("difficulties_WT:",difficulties_WT)

      #print("Name:", name, group_direction, "difficulties_DV:",
      #      difficulties_DV, "Mean WT:", difficulties_WT)
      #      #list(zip(map(lambda dv:difficulties_labels[dv],original_dv),
      #      #                             difficulties_DV)))
      print("len(difficulties_DV):", difficulties_DV,
            "len(difficulties_WT):",difficulties_WT)
      slope, intercept = np.polyfit(difficulties_DV, difficulties_WT, 1)
      #slope, intercept = np.polyfit(rng, difficulties_WT, 1)
      x_rng = np.arange(-1,0.1,0.2) if group_direction == "Left" else np.arange(0,1.1,0.2)
      linfit = [slope * i + intercept for i in x_rng]
      if group_direction == "Left": # Write label once
        if name == "Error":
            num_pts = len(df[df.ChoiceCorrect==0])
        else:
            num_pts = len(df[(df.ChoiceCorrect==1) & (df.CatchTrial == 1)])
        label = "{} Trials ({:,} pts)".format(name , num_pts)
      else:
        label = None
      vevaiometric_axes.plot(x_rng, linfit, color=line_color, label=label)

  vevaiometric_axes.set_ylim(max(0,min_WT-2), min(20,max_WT+2))

  handles, labels = vevaiometric_axes.get_legend_handles_labels()
  # If it is bad data, then don't bother about properyly displaying it
  if len(labels) == 8:
    # Keep these together
    lbl_hndl = list(zip(labels, handles))
    # Manually split and sort
    lbl_err_all, lbl_catch_all,       lbl_err_easy, lbl_err_med, lbl_err_hard,       lbl_catch_easy, lbl_catch_med, lbl_catch_hard = lbl_hndl
    # Now manually sort
    labels, handles = zip(*[lbl_err_all,  lbl_catch_all,
                            lbl_err_easy, lbl_catch_easy,
                            lbl_err_med,  lbl_catch_med,
                            lbl_err_hard, lbl_catch_hard])

  lgnd = vevaiometric_axes.legend(handles, labels, loc='upper center',
                                  prop={'size':'xx-small'},ncol=4)
  #for i in range(2,6):
  #  lgnd.legendHandles[i].set_sizes([20])
  return

def filterZScore(zscore_rank, group):
  if type(group) == str and group == "text":
    return  "/zscore_{}/".format(zscore_rank)
  else:
    from scipy import stats
    return group[stats.zscore(np.log(group.FeedbackTime))<=zscore_rank]

def filterQuantile(quantile_low, quantile_high, group):
  if type(group) == str and group == "text":
    return "/quantile_{}_{}/".format(quantile_low, quantile_high)
  else:
    # This is reported to be faster: np.percentile(df.a,95)]
    #return group[(group.FeedbackTime.quantile(quantile_low) < group.FeedbackTime) &
    #             (group.FeedbackTime < group.FeedbackTime.quantile(quantile_high))]
    return group[(np.percentile(group.FeedbackTime,quantile_low*100.0) < group.FeedbackTime) &
                 (group.FeedbackTime < np.percentile(group.FeedbackTime,quantile_high*100.0))]

def filterIQR(group):
  if type(group) == str and group == "text":
    return "/IQR_1.5/"
  else:
    Q1 = group.FeedbackTime.quantile(0.25)
    Q3 = group.FeedbackTime.quantile(0.75)
    IQR = Q3 - Q1
    print("IQR: {} - Q1: {} - Q3: {} - Lower-bound: {} - Upper-bound: {}".format(IQR,
          Q1, Q3, Q1-1.5*IQR, Q3+1.5*IQR))
    # If multiplier is e.g 1.5,  filter Values between Q1-1.5IQR and Q3+1.5IQR
    return group[((Q1-1.5*IQR) < group.FeedbackTime) & (group.FeedbackTime < (Q3+1.5*IQR))]

def noFilter(group):
    if type(group) == str and group == "text":
        return "/data_filter_unused/"
    else:
        return group

def shortLongWT(df, quantile, filterGroupFn, GLM, axes, mirror=False):
  df = df[(df.GUI_FeedbackDelaySelection == 3) & (df.GUI_CatchError == True)]
  df = df[(df.FeedbackTime > 0.5)]
  df = filterGroupFn(df) # TODO: Check if we should do this
  animal_name = " ".join(df.Name.unique()).strip()

  # This would include catch trials (correct and incorrect)
  #catch_trials = df[(df.CatchTrial==1) &
  #                  ((df.ChoiceCorrect==0) | (df.ChoiceCorrect==1))]
  catch_trials = df[df.CatchTrial==1]
  print("Catch Trials: {:,} - ChoiceCorrect: {:,} - ChoiceIncorrect: {:,}".format(
        len(catch_trials),
        len(catch_trials[catch_trials.ChoiceCorrect==1]),
        len(catch_trials[catch_trials.ChoiceCorrect==0])))
  if len(catch_trials) < 10:
    print("Skipping ShortLW figure as there there are very few datapoints")
    return

  percentile_pt_low = np.percentile(catch_trials.FeedbackTime,quantile*100.0)
  if mirror:
    percentile_pt_high = np.percentile(catch_trials.FeedbackTime,(1-quantile)*100.0)
  else:
    percentile_pt_high = percentile_pt_low

  short_wt = catch_trials[catch_trials.FeedbackTime < percentile_pt_low]
  long_wt = catch_trials[percentile_pt_high <= catch_trials.FeedbackTime]

  axes_title = animal_name + " (Short-WT < {}{} quantile)".format(
      quantile,
      " / Long-WT > {} ".format(1-quantile) if mirror else "")
  PsycStim_axes = psychAxes(axes_title, axes=axes)
  for data, color, title in [(short_wt,'purple',"Short-WT"),
                             (long_wt,'blue',"Long-WT")]:
    title += " - {:,} pts (correct: {:,}, incorrect: {:,})".format(
      len(data), len(data[data.ChoiceCorrect==1]), len(data[data.ChoiceCorrect==0]))
    LINE_SIZE=2
    _psych(data,PsycStim_axes,color,LINE_SIZE,title,
           plot_points=False, SEM=True, GLM=GLM)
  PsycStim_axes.legend(prop={'size':'x-small'},loc='upper left')

def trialsDistrib(df, filterGroupFn, axes):
  df = df[(df.GUI_FeedbackDelaySelection == 3) & (df.GUI_CatchError == True)]
  df = df[(df.FeedbackTime > 0.5)]

  df = filterGroupFn(df) # TODO: Check if we should do this
  water_delivery = df[(df.Rewarded == 1) & (df.ChoiceCorrect == 1)] # No need for the choice correct check
  all_catch_trials = df[(df.ChoiceCorrect==0) | (df.CatchTrial==1)]

  lower, upper = df.FeedbackTime.min(), df.FeedbackTime.max()
  # NUM_BINS=int((upper-lower)*10)
  #axes.hist(water_delivery.FeedbackTime,range=(lower,upper),bins=NUM_BINS,
  #          histtype='step',label="Water Delivery", color='b')

  #axes.hist(all_catch_trials.FeedbackTime,range=(lower,upper),bins=NUM_BINS,
  #          histtype='step',label="Catch Trials", color='k')
  from scipy.stats import gaussian_kde
  from sklearn.neighbors.kde import KernelDensity
  for data, label, color in [(water_delivery, "Water delivery", 'b'),
                             (all_catch_trials, "Catch Trials", 'k')]:
    label += " ({:,} points)".format(len(data.FeedbackTime))
    if not len(data.FeedbackTime):
      continue
    num_bins = int((data.FeedbackTime.max()-data.FeedbackTime.min())*2)
    counts, bins, patches = axes.hist(data.FeedbackTime,
              range=(data.FeedbackTime.min(),data.FeedbackTime.max()),
              bins=num_bins, histtype='step',color=color,alpha=0.4)

    xs = np.linspace(data.FeedbackTime.min()-0.3,
                     data.FeedbackTime.max() + 2,
                     10000)
    BANDWIDTH=0.2
    if True:
      density = gaussian_kde(data.FeedbackTime)
      density.covariance_factor = lambda : BANDWIDTH
      density._compute_covariance()
      y_data = density(xs)
      y_data *= counts.max() / y_data.max() # Find a good scaling point
      axes.plot(xs,y_data,color=color,label=label)
    if False:
      kde = KernelDensity(kernel='exponential', bandwidth=BANDWIDTH).fit(
                               data.FeedbackTime.to_numpy().reshape(-1,1))
      # score_samples() returns the log-likelihood of the samples
      y_data = np.exp(kde.score_samples(xs.reshape(-1,1)))
      y_data *= counts.max() / y_data.max()
      axes.plot(xs,y_data,color=color,label=label)

  axes.legend(loc='upper right', prop={'size':'small'})
  axes.set_xlabel("Waiting Time (s)")
  axes.set_ylabel("Trial Count")
  axes.set_xlim(0, 15)

def catchWTDistrib(df, filterGroupFn, axes, cumsum=True, label_prefix=""):
  df = df[(df.GUI_FeedbackDelaySelection == 3) & (df.GUI_CatchError == True)]
  df = df[(df.FeedbackTime > 0.5)]

  df = df[(df.ChoiceCorrect==0) | (df.CatchTrial==1)] # Pick catch trials before filtering
  df = filterGroupFn(df) # TODO: Check if we should do this
  catch_trials = df[(df.ChoiceCorrect==0)]
  catch_correct = df[(df.ChoiceCorrect==1) & (df.CatchTrial==1)]


  from scipy.stats import gaussian_kde
  from sklearn.neighbors.kde import KernelDensity
  for data, type_label, color in [(catch_trials, "Incorrect", 'r'),
                                  (catch_correct, "Correct", 'g')]:
    label = "Norm. {}Catch {} ({:,} points)".format(
                label_prefix + "-" if len(label_prefix) else "",
                type_label, len(data.FeedbackTime))
    BIN_STEP_SEC = 0.5
    # Ensure that we have at least more tha one bin
    should_process = len(data.FeedbackTime) and \
              (data.FeedbackTime.max() - data.FeedbackTime.min()) > BIN_STEP_SEC
    if not should_process:
      bins = []
      counts = []
    else:
      if cumsum:
        sorted_data = data.sort_values("FeedbackTime")
        counts = sorted_data.FeedbackTime
        bins = sorted_data.FeedbackTime
        counts = np.cumsum(counts)
      else:
        #print("Num bins:", data.FeedbackTime.max(),"-|data.FeedbackTime.min())
        num_bins = int((data.FeedbackTime.max()-data.FeedbackTime.min())/BIN_STEP_SEC)
        counts, bins = np.histogram(data.FeedbackTime,bins=num_bins)
        bins = bins[:-1]
      counts = counts.astype(np.float)
      counts /= counts.max()

    axes.plot(bins,counts,zorder=-1,color=color,label=label if cumsum else None,
              alpha=1 if cumsum else 0.3)
    #counts, bins, patches = axes.hist(data.FeedbackTime,
    #          range=(data.FeedbackTime.min(),data.FeedbackTime.max()),
    #          bins=num_bins, histtype='step',color=color,alpha=0.4)

    if not cumsum and should_process:
      xs = np.linspace(data.FeedbackTime.min(),
                       data.FeedbackTime.max(),
                       10000)
      BANDWIDTH=0.2 # 0.5 is more smoothed, 0.05 is more detailed
      density = gaussian_kde(data.FeedbackTime)
      density.covariance_factor = lambda : BANDWIDTH
      density._compute_covariance()
      y_data = density(xs)
      y_data *= counts.max() / y_data.max() # Find a good scaling point, that would fit the already
                                            # plotted histogram. counts.max() should be 1
      axes.plot(xs - BANDWIDTH, y_data, color=color, label=label)

  if cumsum:
    txt = ""
  else:
    txt = " for " + "/".join(df.DifficultyName.unique()) + " trials"
  animal = " - ".join(df.Name.unique())
  axes.set_title("Accuracy vs WT" + txt + " - " + animal)
  axes.legend(loc='upper {}'.format('left' if cumsum else 'right'), prop={'size':'xx-small'})
  axes.set_ylabel("Normalied Trial Count")
  axes.set_xlabel("Waiting Time (s)")
  axes.set_xlim(0, 15)
  return axes.get_xlim()


from enum import Enum
class AccWTMethod(Enum):
    Hist = 1
    Every100 = 2
    Group0point15 = 3

def accuracyWT(df, filterGroupFn, axes, how=AccWTMethod.Hist):
  df = df[(df.GUI_FeedbackDelaySelection == 3) & (df.GUI_CatchError == True)]
  df = df[(df.FeedbackTime > 0.5)]
  catch_trials = df[(df.CatchTrial == 1) & # All valid catch trials
                    ((df.ChoiceCorrect == 0) | (df.ChoiceCorrect == 1))]
  catch_trials = filterGroupFn(catch_trials)

  y_data = []
  y_data_sem = []
  x_points = []
  x_points_sem = []
  count_correct = 0
  count_incorrect = 0

  from math import floor, ceil
  BIN_SIZE_SEC=1
  bins_range = np.arange(floor(catch_trials.FeedbackTime.min()),
                         ceil(catch_trials.FeedbackTime.max()) + 1, BIN_SIZE_SEC)
  print("Used bins:", bins_range)
  count_per_bin, hist_bins = np.histogram(catch_trials.FeedbackTime, bins=bins_range)
  count_per_bin = count_per_bin.astype(np.float)
  assert (hist_bins == bins_range).all(), "Hist bins should match bins_range"

  if how == AccWTMethod.Every100:
    num_bins = ceil(len(catch_trials)/100)
    buckets = pd.qcut(catch_trials.FeedbackTime, num_bins)
    buckets = catch_trials.groupby(buckets)
    #print("Buckets", buckets)
    data = buckets
  elif how == AccWTMethod.Hist or how == AccWTMethod.Group0point15:
    buckets = [] # It should be equal to count_per_bin but we want the dataframe of
                 # these FeedbackTime values, not just the FeedbackTime values alone
    for i in range(len(bins_range) - 1):
      buckets.append(catch_trials[catch_trials.FeedbackTime.between(bins_range[i],
                                                                    bins_range[i+1])])
    used_bins = bins_range + 0.5 # Add 0.5 to center it on top of the histogram
    data = list(zip(used_bins, buckets))
    if how == AccWTMethod.Group0point15:
      max_conut = count_per_bin.max()
      carry_to_next = []
      carry_to_next_bins = [] # Used for debugging
      last_used_bin_idx = -1

  def loopBody(bins_val, bucket):
    nonlocal count_correct, count_incorrect
    if how == AccWTMethod.Every100 or how == AccWTMethod.Group0point15:
      x_points.append(bucket.FeedbackTime.mean())
      x_points_sem.append(bucket.FeedbackTime.sem())
    else:
      x_points.append(bins_val)
    y_data.append(bucket.ChoiceCorrect.mean())
    y_data_sem.append(bucket.ChoiceCorrect.sem())
    len_correct = len(bucket[bucket.ChoiceCorrect == 1])
    count_correct += len_correct
    count_incorrect += len(bucket) - len_correct

  for bin_idx, (bins_val, bucket) in enumerate(data):
    if not len(bucket):
      continue
    #print("Bin val:", bins_val, "- How:", how, "Bucket len:", len(bucket))
    if how == AccWTMethod.Group0point15:
      if len(bucket) / max_conut < 0.15:
        #print("Skipping ", bins_val)
        carry_to_next.append(bucket)
        carry_to_next_bins.append(bins_val)
        continue
      else:
        last_used_bin_idx = bin_idx
        if len(carry_to_next): # If it's more than our threshol but we have carry over
          concat_list = carry_to_next + [bucket]
          bucket = pd.concat(concat_list)
          print("Adding to ", bins_val, len(carry_to_next), "other lists:",
                carry_to_next_bins)
          carry_to_next.clear()
          carry_to_next_bins.clear()
          # Restore this point in our data as we might recall it later when the loop
          # ends and we still have more data that we didn't process.
          data[bin_idx] = (bins_val, bucket)
    loopBody(bins_val, bucket)

  # Check if we have more data that we dind't process, if so, get the last
  # point, remove it first from our calculations, add the uncalculated points
  # on top of it, then recalculate the last point
  if how == AccWTMethod.Group0point15 and len(carry_to_next):
    bins_val, bucket = data[last_used_bin_idx]
    # Remove the last point in each of our data points
    x_points = x_points[:-1]
    x_points_sem = x_points_sem[:-1]
    y_data = y_data[:-1]
    y_data_sem = y_data_sem[:-1]
    len_correct = len(bucket[bucket.ChoiceCorrect == 1])
    count_correct -= len_correct
    count_incorrect -= len(bucket) - len_correct
    # Recalculate the bucket
    concat_list = carry_to_next + [bucket]
    bucket = pd.concat(concat_list)
    print("Adding to ", bins_val, len(carry_to_next), "other lists:",
          carry_to_next_bins)
    # Call the loop again on the new aggergated last point
    loopBody(bins_val, bucket)

  print("Y-data:", y_data)
  y_data = np.array(y_data)
  #y_data /= y_data.max()
  # print("Y-data sem:", y_data_sem)
  axes.errorbar(x_points, y_data, yerr=y_data_sem, linewidth=0.5*SCALE_X,
                color='k',marker='.',markerfacecolor='b',
                markersize=10*SCALE_X,fmt='-o')
  axes.tick_params(axis='y', labelcolor='b')
  axes.set_ylabel('Accuracy', color='b')
  axes.set_ylim(0.5, 1)
  axes.set_xlabel('Waiting Time (s)', color='k')
  how_txt = ""
  if how == AccWTMethod.Every100:
    how_txt = " (grouped in 100 trials)"
  elif how == AccWTMethod.Group0point15:
    how_txt = " (0.15 bins added to nearest)"
    print("X points:", x_points)
  axes.set_title("Accuracy vs WT{}: {}\n({:,} correct /{:,} incorrect pts)".format(
    how_txt, " - ".join(df.Name.unique()), count_correct, count_incorrect))

  axes2=axes.twinx()
  axes2.tick_params(axis='y', labelcolor='r')
  axes2.set_ylabel('Trials Count', color='r')
  axes2.bar(bins_range[:-1],count_per_bin,label="Waiting Time",
            color='pink', edgecolor='k',
            width=BIN_SIZE_SEC,align='edge')

  axes.set_zorder(axes2.get_zorder()+1)
  axes.set_facecolor("none")
  axes2.set_facecolor("white")

  axes.set_xlim(0, 15)
  axes2.set_xlim(0, 15)



def getDirName(arg):
  animal_name, min_slope,  max_slope,  min_max_intercept,  filterFn_Args,  bias,   min_performance,  max_enforced_fb,  session_min_num_trials,  session_ignore_last_x_trials = arg

  UNUSED="unused"
  operations = "min_slp_{}/max_slp_{}/intercept_{}".format(
    UNUSED if min_slope is None else min_slope,
    UNUSED if max_slope is None else max_slope,
    UNUSED if min_max_intercept is None else "{}_{}".format(-min_max_intercept,min_max_intercept))
  operations += "/bias_{}/".format("{}_{}".format(bias[0], bias[1]) if bias else UNUSED)
  operations += "/min_perf_{}".format(min_performance if min_performance else UNUSED)
  operations += "/max_fb_{}/".format("{}s".format(max_enforced_fb) if max_enforced_fb else UNUSED)
  operations += "/ssn_min_trls_{}/".format(session_min_num_trials if session_min_num_trials else UNUSED)
  operations += "/ignr_last_{}_trls/".format(session_ignore_last_x_trials) if session_ignore_last_x_trials else "ignr_last_trls" + UNUSED
  #operations += "/max_fb_time_{}s/".format(max_feedback_time)
  from functools import partial
  filterFn, filterFnArgs = filterFn_Args
  finalFilterFn = partial(filterFn, *filterFnArgs)
  operations += finalFilterFn("text")
  operations += '/' #+ animal_name + '/' # Animal name will be added by the save function
  return operations

from itertools import product
#elms = product(
#  animals_names, min_slopes, max_slopes, min_max_intercepts, filter_fns,     biases, min_performances, max_enforced_fbs, sessions_min_num_trials, sessions_ignore_last_x_trials)
def processCombination(arg):
  animal_name,   min_slope,  max_slope,  min_max_intercept,  filterFn_Args,  bias,   min_performance,  max_enforced_fb,  session_min_num_trials,  session_ignore_last_x_trials = arg

  operations = getDirName(arg)
  print("dir:", operations)
  if not QUICK_RUN and os.path.exists(operations) and len(os.listdir(operations)) >= NUM_FIGURES:
    print("Skipping already existing dir:", operations)
    return

  from functools import partial
  filterFn, filterFnArgs = filterFn_Args
  finalFilterFn = partial(filterFn, *filterFnArgs)

  df = getDF(animal_name)
  df = df[df.Name == animal_name]

  min_slope = min_slope if min_slope != None else -100
  max_slope = max_slope if max_slope != None else 100
  min_max_intercept = min_max_intercept if min_max_intercept else 100
  used_sessions = []
  num_sessions = 0
  for date_sessionnum, session in df.groupby([df.Date,df.SessionNum]):
    num_sessions += 1
    intercept, slope = interceptSlope(session)
    if slope != None and min_slope <= slope <= max_slope                      and -min_max_intercept <= intercept <= min_max_intercept:
      used_sessions.append(session)
      #print("Intecept: ", intercept)
      #print("Slope: ", slope)
  print("Min-max slope: original num sessions: ",num_sessions,"- after filtering:", len(used_sessions))
  if not len(used_sessions):
    print("Skipping empty df for ", animal_name, "- min slope:", min_slope, " - max slope:", max_slope)
    return
  df = pd.concat(used_sessions)

  print("DF length before bias filtering:", len(df))
  if bias != None:
    left_min, right_max = bias
    df = df[(left_min <= df.GUI_CalcLeftBias) & (df.GUI_CalcLeftBias <= right_max)]

  #print(RDK_confidence_days[animal_name])
  #df = df[df.Date.isin(RDK_confidence_days[animal_name])]
  print("DF length before min performance:", len(df))
  if min_performance != None:
      df = df[df.SessionPerformance > min_performance]

  print("DF length before dates filtering:", len(df))
  if animal_name == "RDK_Thy2":
    print("Processing", animal_name)
    df = df[df.Date >= dt.date(2019,5,22)]
    df = df[df.Date <= dt.date(2019,6,26)]
    df = df[df.Date != dt.date(2019,6,5)]
    df = df[df.Date != dt.date(2019,6,7)]
    df = df[df.Date != dt.date(2019,6,10)]
    df = df[df.Date != dt.date(2019,6,24)]
    #df = df[df.Date >= dt.date(2019,5,22)]
  elif animal_name == "RDK_Thy1":
    df = df[df.Date >= dt.date(2019,3,12)]
    df = df[df.Date <= dt.date(2019,5,31)]
  else:
    df = df[df.Date >= dt.date(2019,6,1)]

  #df = df[(df.FeedbackTime > 0.5)]
  #df = df[(df.GUI_CatchError == 1) & (df.GUI_PercentCatch > 0)]
  print("DF length before used GUI Feedbackack delay value :", len(df))
  print("Used max feedback values :", df.GUI_FeedbackDelayMax.value_counts())
  if max_enforced_fb != None:
    df = df[df.GUI_FeedbackDelayMax == max_enforced_fb]
  # Remove also any data that has maximum feedbacktime of
  # TODO: Add as a directory
  max_feedback_time = 19
  print("DF length before max feedbacktime filtering :", len(df))
  df = df[df.FeedbackTime <= max_feedback_time]

  print("DF length before Min Trial:", len(df))
  if session_min_num_trials:
    df = df[df.MaxTrial > session_min_num_trials]

  print("DF length before ignore last trials:", len(df))
  if session_ignore_last_x_trials != None:
    df = df[df.MaxTrial - df.TrialNumber > session_ignore_last_x_trials]

  #df = df[(df.MT <= 1.5)]
  #max_feedback_time = 1.5
  #process(df, max_feedback_time)
  print("Used dates:", df.Date.unique())
  '''Z
  animal_name = "RDK_WT4"
  df = df[df.Name == animal_name]
  df = df[df.Date >= dt.date(2019,6,1)]
  df = df[df.GUI_FeedbackDelayMax == 4]
  df = df[df.MaxTrial - df.TrialNumber > 50]
  No medians, no np.abs(stats.score) (with just stats.score())
  '''
  '''
  animal_name = "RDK_WT1"
  df = df[df.Name == animal_name]
  df = df[df.Date >= dt.date(2019,6,1)]
  df = df[df.GUI_FeedbackDelayMax == 4]
  df = df[df.MaxTrial - df.TrialNumber > 50]
  No medians, no np.abs(stats.score) (with just stats.score())
  '''
  SAVE=True and not QUICK_RUN
  SAVE=True
  num_sessions = len(df.Date.unique())
  num_sessions_txt = "No. of sessions:" + str(num_sessions)
  print(num_sessions_txt)
  if num_sessions is 0:
      print("Skipping:", operations, animal_name)
      return


  save_fp = operations + "Psyc_raw"
  if not SAVE or not os.path.exists(save_fp):
    PsycStim_axes = psychAxes(animal_name, axes=plt.axes())
    psychAnimalSessions(df,animal_name,PsycStim_axes,METHOD)
    if SAVE:
        print("Save fp:", save_fp)
        savePlot(save_fp, confd=True, animal_name=animal_name)
        plt.close()
    else:
      plt.show()

  save_fp = operations+"CatchWTDistrib"
  if not SAVE or not os.path.exists(save_fp):
    axes = plt.axes()
    catchWTDistrib(df, finalFilterFn, axes, cumsum=True)
    if SAVE:
        print("Save fp:", save_fp)
        savePlot(save_fp, confd=True, animal_name=animal_name)
        plt.close()
    else:
      plt.show()

  GLM=True
  for quantile_li, mirror in [([0.1, 0.2, 0.3, 0.5, 0.7], False),
                              ([0.3], True)]:
    for quantile in quantile_li:
      save_fp = operations+"SLWT_{}{}".format(quantile,
                                              "_mirrored" if mirror else "")
      if not SAVE or not os.path.exists(save_fp):
        axes = plt.axes()
        # Booo
        shortLongWT(df, quantile, finalFilterFn, GLM, axes,
                    mirror=mirror)
        if SAVE:
          print("Save fp:", save_fp)
          savePlot(save_fp, confd=True, animal_name=animal_name)
          plt.close()
        else:
          plt.show()

  save_fp = operations+"AccWT"
  if not SAVE or not os.path.exists(save_fp):
    axes = plt.axes()
    accuracyWT(df, finalFilterFn, axes, how=AccWTMethod.Hist)
    if SAVE:
      print("Save fp:", save_fp)
      savePlot(save_fp, confd=True, animal_name=animal_name)
      plt.close()
    else:
      plt.show()

  save_fp = operations+"AccWT_Every100"
  if not SAVE or not os.path.exists(save_fp):
    axes = plt.axes()
    accuracyWT(df, finalFilterFn, axes, how=AccWTMethod.Every100)
    if SAVE:
      print("Save fp:", save_fp)
      savePlot(save_fp, confd=True, animal_name=animal_name)
      plt.close()
    else:
      plt.show()

  save_fp = operations+"AccWT_Group0.15"
  if not SAVE or not os.path.exists(save_fp):
    axes = plt.axes()
    accuracyWT(df, finalFilterFn, axes, how=AccWTMethod.Group0point15)
    if SAVE:
      print("Save fp:", save_fp)
      savePlot(save_fp, confd=True, animal_name=animal_name)
      plt.close()
    else:
      plt.show()

  difficulty_df = None
  save_fp = operations+"AccWtByDiff"
  if not SAVE or not os.path.exists(save_fp):
    difficulty_df, filtered_df = _splitByDifficultyDirection(df, finalFilterFn,
                                                             max_feedback_time)
    fig, axs = plt.subplots(3,1)
    fig.set_size_inches(1*SAVE_FIG_SIZE[0], 3*SAVE_FIG_SIZE[1])
    min_x, max_x = (20,0)
    for difficulty_level, label in enumerate(["Easy", "Medium", "Hard"]):
      x_lim = catchWTDistrib(difficulty_df[difficulty_df.DifficultyLevel == difficulty_level],
                             noFilter, axs[2-difficulty_level], cumsum=False, label_prefix=label)
      min_x = min(min_x, x_lim[0])
      max_x = max(max_x, x_lim[1])
    for ax in axs:
      ax.set_xlim(min_x, max_x)

    if SAVE:
      # plt.figtext(0.125, 0.08, text, ha="left", va="top")
      print("Save fp:", save_fp)
      savePlot(save_fp, confd=True, animal_name=animal_name)
      plt.close()
    else:
      plt.show()

  save_fp = operations+"TrlsDistrib"
  if not SAVE or not os.path.exists(save_fp):
    axes = plt.axes()
    trialsDistrib(df, finalFilterFn, axes)
    if SAVE:
      print("Save fp:", save_fp)
      savePlot(save_fp, confd=True, animal_name=animal_name)
      plt.close()
    else:
      plt.show()

  save_fp = operations+"Vev"
  if not SAVE or not os.path.exists(save_fp):
    fig, axs = plt.subplots(1,2)
    fig.set_size_inches(2*SAVE_FIG_SIZE[0], 1*SAVE_FIG_SIZE[1])
    filtered_df = vevaiometric(df, finalFilterFn, axs[0], max_feedback_time)
    PsycStim_axes = psychAxes(animal_name, axes=axs[1])
    psychAnimalSessions(df,animal_name,PsycStim_axes,METHOD)
    if SAVE:
      # plt.figtext(0.125, 0.08, text, ha="left", va="top")
      print("Save fp:", save_fp)
      savePlot(save_fp, confd=True, animal_name=animal_name)
      plt.close()
    else:
      plt.show()

  save_fp = operations+"Vev_diff"
  if not SAVE or not os.path.exists(save_fp):
    if difficulty_df is None:
      difficulty_df, filtered_df = _splitByDifficultyDirection(df, finalFilterFn,
                                                               max_feedback_time)
    fig, axs = plt.subplots(1,2)
    fig.set_size_inches(2*SAVE_FIG_SIZE[0], 1*SAVE_FIG_SIZE[1]) # Reserve 2 slots
    vevaiometricByDiffifculty(difficulty_df, axs[0])
    #print("Creating psych plot:", filtered_df)
    PsycStim_axes = psychAxes(animal_name, axes=axs[1])
    psychAnimalSessions(df,animal_name,PsycStim_axes,METHOD)
    if SAVE:
      # plt.figtext(0.125, 0.08, text, ha="left", va="top")
      print("Save fp:", save_fp)
      savePlot(save_fp, confd=True, animal_name=animal_name)
      plt.close()
    else:
      plt.show()

