
class AttrDict(dict):
  '''Copied from: https://stackoverflow.com/questions/4984647/accessing-dict-keys-like-an-attribute
  '''
  def __init__(self, *args, **kwargs):
    super(AttrDict, self).__init__(*args, **kwargs)
    self.__dict__ = self