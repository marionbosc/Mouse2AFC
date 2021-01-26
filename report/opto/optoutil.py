import builtins
from definitions import BrainRegion, MatrixState

class ChainedGrpBy:
  def __init__(self, df, descr=None):
    if not isinstance(df, (tuple, list)):
      self._df_tups = df
      self.descr = ((),)[0]
    else:
      self._df_tups = tuple(df)
      self.descr = descr

  def __iter__(self):
    return ChainedGrpBy.Iterator(self)

  class Iterator:
    def __init__(self, outer):
      self._outer = outer
      self._idx = -1

    def __next__(self):
      self._idx += 1
      if self._idx == len(self._outer._df_tups):
        raise StopIteration
      # Weill return info, df
      key, val = self._outer._df_tups[self._idx]
      if len(key) == 1: key = key[0]
      return key, val

  def _processBy(self, processFn, descr_str):
    #TODO: This pattern is probably over complicated, find a simpler solution
    res_list = []
    df_info = None # Will be changed down
    def addGrpByTupFn(grp_key, grp_df):
      final_key = *df_info, grp_key
      res_list.append((final_key, grp_df))

    if not isinstance(self._df_tups, tuple):
      df_info = ((),)[0]
      processFn(self._df_tups, addGrpByTupFn)
    else:
      for _df_info, sub_df in self._df_tups:
        df_info = _df_info
        processFn(sub_df, addGrpByTupFn)

    new_descr = *self.descr, descr_str
    return ChainedGrpBy(df=res_list, descr=new_descr)

  # def _by(self, grpbyCriteriaFn, infoConvertFn, descr_str):
  #   def processComb(_df, addGrpByTupFn):
  #     for grpby_info, grpby_df in _df.groupby(grpbyCriteriaFn(_df)):
  #       addGrpByTupFn(infoConvertFn(grpby_info), grpby_df)
  #   return self._processBy(processComb, descr_str)

  def bySess(self):
    def processComb(_df, addGrpByTupFn):
      for grpby_info, grpby_df in _df.groupby(["Name", "Date", "SessionNum"]):
        date = grpby_info[1].strftime(r"%y-%m-%d")
        info = f"{grpby_info[0]} - {date} /{grpby_info[2]}"
        addGrpByTupFn(info, grpby_df)
    return self._processBy(processComb, descr_str="Session")

  def byBrainRegion(self):
    def processComb(_df, addGrpByTupFn):
      for grpby_info, grpby_df in _df.groupby(["GUI_OptoBrainRegion"]):
        addGrpByTupFn(BrainRegion(grpby_info), grpby_df)
    return self._processBy(processComb, descr_str="BrainRegion")

  # def byState(self):
  #   def processComb(_df, addGrpByTupFn):
  #     for grpby_info, grpby_df in _df.groupby(["GUI_OptoStartState1"]):
  #       addGrpByTupFn(MatrixState(grpby_info), grpby_df)
  #   return self._processBy(processComb, descr_str="StartState")

  def byOptoConfig(self):
    # We need to call splitByOptoTiming() to get us the results
    def processComb(_df, addGrpByTupFn):
      for config_tup, grpby_df in splitByOptoTiming(_df):
        dur = "Full" if config_tup[2] == -1 else f"{config_tup[2]}s"
        info = f"{MatrixState(config_tup[0])} S={config_tup[1]}s, T={dur}"
        addGrpByTupFn(info, grpby_df)
    return self._processBy(processComb, "OptoConfig")

  def byOptoTrials(self):
    def processComb(_df, addGrpByTupFn):
      for is_opto_enabled, grpby_df in _df.groupby(["OptoEnabled"]):
        grpby_info = "Opto" if is_opto_enabled == True else "Control"
        addGrpByTupFn(grpby_info, grpby_df)
    return self._processBy(processComb, descr_str="OptoTrials")

  def byAnimal(self):
    def processComb(_df, addGrpByTupFn):
      for grpby_info, grpby_df in _df.groupby(["Name"]):
        addGrpByTupFn(grpby_info, grpby_df)
    return self._processBy(processComb, descr_str="Animal")


  def filter(self, filterFn):
    new_list = []
    def processDf(_df_info, _df):
      if filterFn(_df):
        new_list.append((_df_info, _df))

    if not isinstance(self._df_tups, tuple):
      empty_tup = ((),)[0]
      processDf(empty_tup, self._df_tups)
    else:
      for df_info, sub_df in self._df_tups:
        processDf(df_info, sub_df)
    return ChainedGrpBy(df=new_list, descr=self.descr)


def splitToControOpto(df):
  df_opto = df[df.OptoEnabled == 1]
  df_control = df[df.OptoEnabled == 0]
  return df_control, df_opto


def filterNonOptoSessions(df):
  # Turn opto trials with zero light-time into non-opto trials
  df.loc[(df.OptoEnabled == True) & (df.GUI_OptoMaxTime == 0),
         'OptoEnabled'] = False
  opto_sessions = df[df.OptoEnabled == True]
  opto_sessions = opto_sessions[['Date','SessionNum']].drop_duplicates()
  opto_sessions_tuples = [tuple(x) for x in opto_sessions.to_numpy()]
  # print("Opto sessions dates:", opto_sessions_tuples)
  # Filter on sessions matching Data/Session Num combination:
  # https://stackoverflow.com/a/53945974/11996983
  idx_bool = df[["Date", "SessionNum"]].apply(tuple, axis=1).isin(
                                                           opto_sessions_tuples)
  return df[idx_bool]


def grpByOptoConfig(df):
  opto_config_cols = ['GUI_OptoStartState1', 'GUI_OptoStartDelay',
                      'GUI_OptoMaxTime']
  return df.groupby(opto_config_cols)

def optoCOnfigsCounts(df):
  grp_by_opto = grpByOptoConfig(df).size()
  # grp_by_opto is currently a multi-index series, convert to single-index
  # dataframe
  df_grp_by_opto_count = grp_by_opto.to_frame("Count").reset_index()
  return df_grp_by_opto_count


def filterFewTrialsCombinations(df, *, config_min_num_trials, _second_df=None):
  if _second_df is None:
    _second_df = df
  df_opto_configs_counts = optoCOnfigsCounts(_second_df)
  df_opto_configs_counts = df_opto_configs_counts[
                  df_opto_configs_counts.Count > config_min_num_trials]
  opto_config_cols = list(df_opto_configs_counts.columns)
  opto_config_cols.remove("Count") # Remove the irrelevant count column
  # Use the trick here: https://stackoverflow.com/a/33282617/11996983
  i1 = df.set_index(opto_config_cols).index
  i2 = df_opto_configs_counts.set_index(opto_config_cols).index
  return df[i1.isin(i2)]


def filterNoOptoConfigs(df):
  df_opto = df[df.OptoEnabled == True]
  # Should we do it here by brain region and animal as well?
  # Use a workaround
  return filterFewTrialsCombinations(df, config_min_num_trials=0,
                                     _second_df=df_opto)

def splitByOptoTiming(df):
  # Get all opto trials during sampling phase
  from definitions import MatrixState
  df_stim_delv = df[df.GUI_OptoStartState1 ==
                    int(MatrixState.stimulus_delivery)]
  # Filter for trials where opto was triggered after 0 second or was triggered
  # at zero second but didn't last the whole of sampling period. Here,
  # min-sampling should be the same as max allowed sampling.
  df_partial_sampling = \
         df_stim_delv[(df_stim_delv.GUI_OptoStartDelay > 0) |
                      ((df_stim_delv.GUI_OptoStartDelay == 0) &
                       (df_stim_delv.GUI_OptoMaxTime < df_stim_delv.MinSample))]
  # All the other trials that had opto throughout the whole epoch
  df_full_sampling = df[~df.index.isin(df_partial_sampling.index)]
  # if hasattr(builtins, "display"):
  #   print("Partial sampling df:")
  #   display(optoCOnfigsCounts(df_partial_sampling))
  #   print("Full Sampling df:")
  #   display(optoCOnfigsCounts(df_full_sampling))
  grps_concat = []
  START_DELAY=0
  MAX_DUR=-1
  for grp_key, grp_df in df_full_sampling.groupby("GUI_OptoStartState1"):
    grp_key = (grp_key, START_DELAY, MAX_DUR,)
    grps_concat.append((grp_key, grp_df,))
  for grp_key, grp_df in grpByOptoConfig(df_partial_sampling):
    grps_concat.append((grp_key, grp_df,))
  grps_concat.sort() #lambda entry:entry[0][1])
  # print( [key for key, _ in grps_concat])
  return grps_concat


def filterIfNotMinOpto(control_trials, opto_trials, min_num_trials):
  control_trials = [(grp_info, grp_df,) for grp_info, grp_df in control_trials
                    if len(grp_df) > min_num_trials]
  opto_trials =  [(grp_info, grp_df,) for grp_info, grp_df in opto_trials
                  if len(grp_df) > min_num_trials]

  def filterIfNotExist(dst_trials, src_trials):
    new_dst = []
    grp_infos_src = set([grp_info for grp_info, _ in src_trials])
    [new_dst.append((dst_grp_info, dst_df,))
     for dst_grp_info, dst_df in dst_trials  if dst_grp_info in grp_infos_src]
    return new_dst
  control_trials = filterIfNotExist(control_trials, opto_trials)
  opto_trials = filterIfNotExist(opto_trials, control_trials)
  return control_trials, opto_trials
