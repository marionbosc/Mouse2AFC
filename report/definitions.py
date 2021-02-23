from numpy import nan as np_nan
from enum import Enum, IntEnum

class _EnumShortStrMixin:
  def __str__(self):
    return self.name

  def __format__(self, fmt):
    return self.__str__()

class FloatEnumShortStr(_EnumShortStrMixin, float, Enum):
  pass

class IntEnumShortStr(_EnumShortStrMixin, IntEnum):
  pass


class ExperimentType(IntEnumShortStr):
  Auditory = 1
  LightIntensity = 2
  GratingOrientation = 3
  RDK = 4
  SoundIntensity = 5
  NoStimulus = 6

ExpType = ExperimentType

class MouseState(FloatEnumShortStr):
  Unkown = np_nan
  FreelyMoving = 1
  HeadFixed = 2

class BrainRegion(IntEnumShortStr):
  V1_L = 1
  V1_R = 2
  V1_Bi = 3
  ALM_L = 4
  ALM_R = 5
  ALM_Bi = 6
  PPC_L = 7
  PPC_R = 8
  PPC_Bi = 9
  POR_L = 10
  POR_R = 11
  POR_Bi = 12
  M2_L = 13
  M2_R = 14
  M2_Bi = 15
  RSP_L = 16
  RSP_R = 17
  RSP_Bi = 18

class MatrixState(IntEnumShortStr):
  ITI_Signal = 1
  WaitForCenterPoke = 2
  PreStimReward = 3
  TriggerWaitForStimulus = 4
  WaitForStimulus = 5
  StimDelayGrace = 6
  broke_fixation = 7
  stimulus_delivery = 8
  early_withdrawal = 9
  BeepMinSampling = 10
  CenterPortRewardDelivery = 11
  TriggerWaitChoiceTimer = 12
  WaitCenterPortOut = 13
  WaitForChoice = 14
  WaitForRewardStart = 15
  WaitForReward = 16
  RewardGrace = 17
  Reward = 18
  WaitRewardOut = 19
  RegisterWrongWaitCorrect = 20
  WaitForPunishStart = 21
  WaitForPunish = 22
  PunishGrace = 23
  Punishment = 24
  timeOut_EarlyWithdrawal = 25
  timeOut_EarlyWithdrawalFlashOn = 26
  timeOut_IncorrectChoice = 27
  timeOut_SkippedFeedback = 28
  timeOut_missed_choice = 29
  ITI = 30
  ext_ITI = 31

  def __format__(self, fmt):
    _str = self.__str__()
    if _str == "stimulus_delivery":
      return "Sampling"
    elif _str == "CenterPortRewardDelivery":
      return "WaitDecision"
    else:
      return _str
