# requires: pip install click
import time
import click
import sys
from mat_reader_core import loadFiles

@click.command()
@click.option('--out', '-o', type=click.Path(),
              help="output file path of the pandas datafile")
@click.option('--input', '-i', multiple=True, type=click.Path(),
              help="filepath or filepath pattern of the sessions matlab files")
@click.option("--out-date-suffix/--no-date-suffix", default=False,
              show_default=True,
              help="Whether to append to output file name the start and end "
                   "dates of first ad last sessions.")
@click.option("--mini-df/--full-df", default=True, show_default=True,
              help="Whether to produce a stripped down dataframe")
@click.option("--append-df", type=click.Path(exists=True),
              help="If specified, should point to an existing dataframe. The "
                   "dataframe will be loaded and checked for the existing "
                   "sessions. Filenames in --input will be scanned and "
                   "compared to existing sessions in the dataframe. Only the "
                   "new sessions will be loaded. If --output argument is "
                   "specified, then the dataframe will written to a new "
                   "--output file, otherwise it will be saved in-place")
@click.option("--few-trials-save", type=click.Path(),
              help="Specify the save location for the list containing sessions "
                   "filenames that had few trials. Can be same as "
                   "--few-trials-load")
@click.option("--few-trials-load", type=click.Path(exists=True),
              help="Specify the file path for the list containing sessions "
                   "with very few trials. These sessions will be skipped.")
@click.option("--interactive", is_flag=True,
              help="After computing the pandas dataframe, don't save and " +
                   "drop instead into interactive prompt")
def main(out, input, out_date_suffix, mini_df, append_df, interactive,
         few_trials_save, few_trials_load):
  '''Convert one or multiple Mouse2AFC matlab session data files into a single
  pandas dataframe.

  Example:
    DATA1="../../../Data/"; DATA2="/Mouse2AFC/Session Data/"; python mat_reader.py -i "${DATA1}/*/${DATA2}*.mat" --few-trials-load="few_trials_AnimalName.txt" --few-trials-save="few_trials_AnimalName.txt" -o AnimalName

    python mat_reader.py -o AnimalName -i "*_Thy[1-3]*.mat" -i "*WT[1-9]_*.mat" -i "N[1-4]_Mouse2AFC_[Ja,Fe,Ma,Ap,Ma,Ju,Ju]*.mat" --full-df

    DATA1="../BpodUser/Data/"; DATA2="/Mouse2AFC/Session Data/"; python mat_reader.py -o RDK_conf_evd_accum_2019_11_20 -i "${DATA1}/*RDK_Thy2/${DATA2}*.mat" -i"${DATA1}/*RDK_WT [1,4,6]/${DATA2}*.mat" -i "${DATA1}/wfThy*/${DATA2}*.mat"
  '''
  suffix = time.strftime("_%Y_%m_%d") if out_date_suffix else ""
  if not append_df:
    if not out:
      raise ValueError("Neither --out nor --append were specified")
    name = f"{out}{suffix}.dump"
    print("Potential Resulting name:", name)
  if few_trials_load:
    with open(few_trials_load) as f:
      few_trials_fp = f.readlines()
    few_trials_fp = [f.strip() for f in few_trials_fp]
  else:
    few_trials_fp = []

  df, few_trials_fp, is_updated_df = loadFiles(input, mini_df=mini_df,
                         append_df=append_df, few_trials_sessions=few_trials_fp)
  if not len(df):
    print("Empty dataframe - probably wrong file path")
    sys.exit(-1)

  if not out and append_df:
    name = append_df
  else:
    if out_date_suffix:
      suffix = f"{df.Date.min().strftime('_%Y_%m_%d')}_to_" + \
               f"{df.Date.max().strftime('%Y_%m_%d')}"
    else:
      suffix = ""
    name = f"{out}{suffix}.dump"

  def saveMetaFiles():
    if few_trials_save:
      with open(few_trials_save, 'w') as f:
        print("Saving few trials sessions into:", few_trials_save)
        f.write('\n'.join(few_trials_fp))

  if not interactive:
    print("Final name:", name)
    if is_updated_df:
      df.to_pickle(name)
    else:
      print("Not saving as df hasn't changed")
    saveMetaFiles()
  else:
    saveMetaFiles()
    print("Loading interactive prompt")
    print("Hint:")
    print(f"   Use 'df.to_pickle(\"{name}\")' to save dataframe to disk")
    import code
    try:
        import readline
    except ImportError:
      import pyreadline as readline
    import rlcompleter
    vars = dict(globals(), **locals())
    readline.set_completer(rlcompleter.Completer(vars).complete)
    readline.parse_and_bind("tab: complete")
    code.InteractiveConsole(vars).interact()

if __name__ == "__main__":
    main()
