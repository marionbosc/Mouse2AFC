'''Named clr to avoid conflict with any global color module'''
# I try to use a color-wheel to generate contrast colors, use this link if it
# still works: https://www.sessions.edu/color-calculator/

# Enum members give errors when passed to matplotlib as colors, so we use plain
# classes.

class Choice:
  Correct = "lime"
  Incorrect = "red"
  All = "blue"

class Difficulty:
  Easy = "#ff9900"
  Med = "#14a5ff"
  Hard = "#be31ff"

class Duration:
  Short = "#ff8903"
  Long = "#1403ff"

class BrainRegion:
  V1_L = "green"
  V1_R = "green"
  V1_Bi = "green"
  ALM_L = "red"
  ALM_R = "red"
  ALM_Bi = "red"
  PPC_L = "purple"
  PPC_R = "purple"
  PPC_Bi = "purple"
  POR_L = "cyan"
  POR_R = "cyan"
  POR_Bi = "cyan"
  M2_L = "blue"
  M2_R = "blue"
  M2_Bi = "blue"
  RSP_L = "brown"
  RSP_R = "brown"
  RSP_Bi = "brown"

  def __getitem__(self, brain_region):
    from definitions import BrainRegion as BR
    if isinstance(brain_region, BR):
      brain_region = str(BR(brain_region))
    return getattr(self, brain_region, "gray")
BrainRegion = BrainRegion()

def Age(idx, max_idx):
  START_COLOR = [0, 238, 255]
  END_COLOR = [134, 0, 255]
  STEP = \
         ((START_COLOR[1]-END_COLOR[1]) - (START_COLOR[0]-END_COLOR[0]))/max_idx
  color = START_COLOR
  UP_LIM, LOW_LIM= True, False
  remaining = STEP*idx
  for color_idx, is_up_lim in [(1, LOW_LIM), (0, UP_LIM)]:#, (2, UP_LIM)]:
    color_buffer = (255 - color[color_idx]) if is_up_lim else color[color_idx]
    while remaining and color_buffer > 0:
      add_val = min(remaining, color_buffer, STEP)
      color[color_idx] += add_val if is_up_lim else -add_val
      color_buffer = (255 - color[color_idx]) if is_up_lim else color[color_idx]
      remaining -= add_val
    idx -= 1
  return (color[0]/255, color[1]/255, color[2]/255)

def adjustColorLightness(color, amount): # e.g, amount=0.5, amount=1.2
  # https://stackoverflow.com/a/49601444/11996983
  import matplotlib.colors as mc
  import colorsys
  try:
      c = mc.cnames[color]
  except:
      c = color
  c = colorsys.rgb_to_hls(*mc.to_rgb(c))
  return colorsys.hls_to_rgb(c[0], max(0, min(1, amount * c[1])), c[2])
