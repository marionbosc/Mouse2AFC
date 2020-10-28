# Call from MATLAB:
# !python -c "import sys; sys.path.append(r'C:\Users\hatem\OneDrive\Documents\BpodUser\Protocols\Mouse2AFC\report'); import sessionreport; sessionreport.showAndSaveReport(r'dummy')"
#
# You need to have the following libraries:
# pip install numpy scipy matplotlib pandas scikit-learn statsmodels colour

import os
import pathlib
import sys
import shutil
import time
import traceback
import matplotlib.pyplot as plt
import analysis
import mat_reader_core


class PlotHandler():
  def __init__(self):
    self._should_close = None # It will be set later
    self._plot_showing = None
    self._cur_running_fig = None
    analysis.setMatplotlibParams(silent=True)

  def _closeWindow(self):
    assert self._should_close is not None
    # If the user click on the figure then this method is called twice, once for
    # th timer but the if statement below is not executed, and a second time
    # when the user actually click the close button. This second time also the
    # the if statement doesn't execute but the window is closed anyway.
    if self._should_close:
      self._should_close = None
      plt.close(self._cur_running_fig)

  def _disableAutoClose(self, event):
    assert self._should_close is not None
    self._should_close = False

  def _closeHandler(self, event):
    assert self._plot_showing == True
    self._plot_showing = False

  def pltInBgnd(self, *, fig, auto_close_after_ms):
    self.waitForCurFig()
    self._cur_running_fig = fig
    self._plot_showing = True
    self._should_close = True
    fig.canvas.mpl_connect('button_press_event', self._disableAutoClose)
    #fig.canvas.mpl_connect('resize_event', self._disableAutoClose)
    fig.canvas.mpl_connect('close_event', self._closeHandler)
    # We don't use the _timer instance but we need to keep a reference to it,
    # otherwise the timer won't run
    self._timer = fig.canvas.new_timer(interval = auto_close_after_ms)
    self._timer.add_callback(self._closeWindow)
    self._timer.start()
    plt.show(block=False)

  def waitForCurFig(self):
    start = time.time()
    while self._plot_showing:
      time.sleep(0.00001)
      self._cur_running_fig.canvas.flush_events()


class MakeAndSavePlots():
  def run(self, session_df, save_dir):
    date_str = session_df.Date.unique()[0].strftime("%Y_%m_%d_%a")
    session_num = session_df.SessionNum.unique()[0]
    animal_name = session_df.Name.unique()[0]
    protocol_name = session_df.Protocol.unique()[0]
    pathlib.Path(save_dir).mkdir(parents=True, exist_ok=True)

    copy_to_daily_sessions = False
    onedrive_root_dir = os.getenv("OneDrive")
    if onedrive_root_dir:
      # "OneDrive/Figures/{ProtocolName}/" must exists
      daily_figures = "{}{}{}{}{}".format(onedrive_root_dir, os.path.sep,
                                         "Figures", os.path.sep, protocol_name)
      if os.path.exists(daily_figures):
        onedrive_todays_dir = "{}{}{}".format(daily_figures, os.path.sep,
                                              date_str)
        print("Todays dir:", onedrive_todays_dir)
        pathlib.Path(onedrive_todays_dir).mkdir(parents=False, exist_ok=True)
        copy_to_daily_sessions = True


    plot_handler = PlotHandler()
    try:
      fig = self._mainPlot(session_df)
      plot_handler.pltInBgnd(fig=fig, auto_close_after_ms=60000)
    except Exception as err:
      print("An exception occurred in main fig:\n", traceback.format_exc(),
            file=sys.stderr)
    else:
      filename = "{}_Sess{}_{}_{}.png".format(date_str, session_num, "perf",
                                              animal_name)
      dst_path = "{}{}{}".format(save_dir, os.path.sep,filename)
      fig.savefig(dst_path)
      if copy_to_daily_sessions:
        daily_path = "{}{}{}.png".format(onedrive_todays_dir, os.path.sep,
                              "{}_Sess{}_perf".format(animal_name, session_num))
        shutil.copyfile(src=dst_path, dst=daily_path)

    if session_df.FeedbackTime.max() > 1 and \
     len(session_df[session_df.GUI_FeedbackDelaySelection == 3]) > 10:
      try:
        fig = self._confidencePlot(session_df)
        plot_handler.pltInBgnd(fig=fig, auto_close_after_ms=6000)
      except:
        print("An exception occurred in confidence fig:\n",
              traceback.format_exc(), file=sys.stderr)
      else:
        filename = "{}_Sess{}_{}_{}.png".format(date_str, session_num, "veva",
                                                animal_name)
        fig.savefig("{}{}{}".format(save_dir, os.path.sep,filename))
        if copy_to_daily_sessions:
          daily_path = "{}{}{}.png".format(onedrive_todays_dir, os.path.sep,
                              "{}_Sess{}_veva".format(animal_name, session_num))
          shutil.copyfile(src=dst_path, dst=daily_path)

    plot_handler.waitForCurFig()

  def _mainPlot(self, session_df):
    fig, axs = self._createSubplots(rows=2, cols=2,
                                    bottom=0.15, top=0.95,
                                    left=0.06, right=0.95,
                                    hspace=0.6, wspace=0.16,
                                    width_ratios=[1,2])

    animal_name = session_df.Name.unique()[0]
    psych_axes = analysis.psychAxes(animal_name, axes=axs[0][0])
    analysis.psychAnimalSessions(session_df, animal_name, psych_axes,
                                 analysis.METHOD)

    Plot = analysis.PerfPlots
    analysis.performanceOverTime(session_df, single_session=True, axes=axs[0][1],
                                 draw_plots=[Plot.Performance,
                                             Plot.DifficultiesCount,
                                             Plot.Bias,
                                             Plot.EarlyWD,
                                             Plot.MovementT,
                                             Plot.ReactionT,
                                             Plot.StimAPO])
    analysis.performanceOverTime(session_df, single_session=True, axes=axs[1][1],
                                 draw_plots=[Plot.Performance,
                                             Plot.Difficulties,
                                             Plot.SamplingT,
                                             Plot.CatchWT,
                                             Plot.MaxFeedbackDelay])

    analysis.trialRate(session_df, ax=axs[1][0], max_sess_time_lim_bug=3600*10,
                       IQR_filter=False, num_days_per_clr=None)
    return fig

  def _confidencePlot(self, session_df):
    fig, axs = self._createSubplots(rows=2, cols=2,
                                    bottom=0.07, top=0.92,
                                    left=0.06, right=0.98,
                                    hspace=0.31, wspace=0.19)

    analysis.accuracyWT(session_df, analysis.noFilter, axs[0][0],
                          how=analysis.AccWTMethod.Group0point15)
    analysis.trialsDistrib(session_df, analysis.noFilter, axs[0][1])

    max_feedbacktime=15
    analysis.vevaiometric(session_df, analysis.noFilter, axs[1][0],
                          max_feedbacktime)
    analysis.catchWTDistrib(session_df, analysis.noFilter, axs[1][1],
                            cumsum=True)
    return fig

  def _createSubplots(self, *,rows, cols, bottom, top, left, right, hspace,
                      wspace, width_ratios=None):
    if width_ratios:
      fig, axs = plt.subplots(rows, cols,
                              gridspec_kw={'width_ratios': width_ratios})
    else:
      fig, axs = plt.subplots(rows, cols)

    fig.set_size_inches(cols*analysis.SAVE_FIG_SIZE[0],
                        rows*analysis.SAVE_FIG_SIZE[1])
    fig.subplots_adjust(bottom=bottom, top=top, left=left, right=right,
                        hspace=hspace, wspace=wspace)
    return fig, axs

def showAndSaveReport():
  data_flie = sys.argv[1]
  save_dir = sys.argv[2]
  print("Data file:", data_flie)
  print("Save dir:", save_dir)
  temp_path = r"C:\Users\hatem\OneDrive\Documents\py_matlab\\"+ \
              r"wfThy2_Mouse2AFC_Dec05_2019_Session1.mat"
              #r"vgat4_Mouse2AFC_Dec09_2019_Session2.mat"
              #r"RDK_WT1_Mouse2AFC_Dec04_2019_Session1.mat"

  session_df, _bad_ssns, _df_updated = mat_reader_core.loadFiles(data_flie)
  print("Session df length:", len(session_df))
  MakeAndSavePlots().run(session_df, save_dir)

if __name__ == "__main__":
  showAndSaveReport()
