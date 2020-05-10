

def lightenColor(color, amount):
  """Lightens the given color by multiplying (1-luminosity) by the given amount.
  Input can be matplotlib color string, hex string, or RGB tuple.

  Examples:
  >> lighten_color('g', 0.3)
  >> lighten_color('#F034A3', 0.6)
  >> lighten_color((.3,.55,.1), 0.5)

  Copied from: https://stackoverflow.com/a/49601444/11996983
  """
  import matplotlib.colors as mc
  import colorsys
  try:
    c = mc.cnames[color]
  except:
    c = color
  c = colorsys.rgb_to_hls(*mc.to_rgb(c))
  return colorsys.hls_to_rgb(c[0], 1 - amount * (1 - c[1]), c[2])


def chunks(lst, n):
  """Yield successive n-sized chunks from lst.
  Copied from: https://stackoverflow.com/a/312464
  """
  for i in range(0, len(lst), n):
      yield lst[i:i + n]

def sideBySideCmp(df):
  '''This examples detects repeated TrialNumber for same sessions (i.e bug)'''
  dup_df = df[df.duplicated(subset=("Name","Date", "SessionNum", "TrialNumber"),
                            keep=False)]
  #print("Duplicated len:", dup_df.Name.unique(), dup_df.Date.unique())
  for (name, date, session_num, trial_num), dup_entry in \
                  dup_df.groupby(["Name", "Date", "SessionNum", "TrialNumber"]):
    diff = dup_entry.iloc[0] == dup_entry.iloc[1]
    mismatch_col = diff[~diff].index.to_numpy()
    side_by_side = dup_entry[mismatch_col].transpose()
    side_by_side.dropna(how="all", inplace=True)
    print("Name:", name, "Date:", date, "Trial num:", trial_num,
          "\n", dup_entry.File.iloc[0], "\n", dup_entry.File.iloc[1])
          #side_by_side)
