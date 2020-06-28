import asyncio
from enum import Enum, auto
import logging
import sys
import time
import pandas as pd


class _Status(Enum):
  SorterWaitFirstDoorMice = auto()
  SorterEntryWeightOrAbort = auto()
  SorterWaitSecondDoor = auto()
  SorterExitWeight = auto()
  SorterWaitFinalExit = auto()
  BpodWaitSessionStartedOrFinished = auto()

class _EnterOrExit:
  Enter = "Enter"
  Exit = "Exit"

log = logging.Logger("Decider", level=logging.DEBUG)
_handler = logging.StreamHandler(sys.stdout)
_handler.setLevel(logging.DEBUG)
_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
_handler.setFormatter(_formatter)
_file_handler = logging.FileHandler("debug.log")
_file_handler.setFormatter(_formatter)
log.addHandler(_handler)
log.addHandler(_file_handler)

class Decider():
  # TODO: Reset internal states if we have't seen activity for long time?
  def __init__(self, csv_conf_path, csv_entry_logger_path):
    self._reloadAnimalsConf(csv_conf_path)
    self._entrylog_fp = csv_entry_logger_path
    self._entrylog = pd.read_csv(self._entrylog_fp)
    self._entrylog.set_index(self._entrylog.columns.tolist())
    self._initStates()

  def _reloadAnimalsConf(self, csv_conf_path):
    REALOD_EVERY = 30
    try:
      self._all_animals_conf = pd.read_csv(csv_conf_path)
    except Exception as e:
      log.warning(f"Failed to load Animal configration {csv_conf_path} at time "
                  f"{time.asctime()} due to error: {e}. Next reload is in "
                  f"{REALOD_EVERY}s")
    else:
      log.debug(f"Reloaded csv file {csv_conf_path} at time {time.asctime()}")
    asyncio.get_event_loop().call_later(REALOD_EVERY, self._reloadAnimalsConf,
                                        csv_conf_path)

  def _initStates(self):
    log.debug("Initializing decider states to receive new animal")
    self._cur_animal_conf = None
    self._bypass_weight = False
    self._status = _Status.SorterWaitFirstDoorMice

  def setComms(self, sorter_comm, bpod_comm):
    self._sorter = sorter_comm
    self._bpod = bpod_comm

  def sorterStopping(self):
    log.warning("Sorter is stopping. Trying not to stop")
    self._sorter.ackSystemStopping(False, '90:"Not designed to stop"')

  def isFirstDoorAllowed(self, animal_name):
    if self._status != _Status.SorterWaitFirstDoorMice:
      log.warning(f"Unexpected status. Currently {self._status} - "
               "got: isFirstDoorAllowed()")
      self._sorter.allowFirstDoor(animal_name, False,
                                  f'10:"Currently at status {self._status!r}"')
      return
    # Check if we know that animal
    animal_df = self._all_animals_conf[
                                     self._all_animals_conf.Name == animal_name]
    if not len(animal_df):
      log.warning(f"Found unknown animal: {animal_name}")
      self._sorter.allowFirstDoor(animal_name, False,
                                  '11:"Don\'t know animal"')
      return
    if len(animal_df) > 1:
      log.warning(f"Found more than config entry for animal {animal_name}. "
                "Using first entry")
    animal_conf = animal_df.iloc[0]
    entries = self._entrylog[(self._entrylog.Name == animal_name) &
                              (self._entrylog.EnterOrExit == _EnterOrExit.Exit)]
    if not len(entries):
      last_entry_time = 0
    else:
      last_entry_time = entries.tail(1).UnixTime
    dur_outside = time.time() - last_entry_time
    if dur_outside < animal_conf.MinInterSessionTrial:
      self._sorter.allowFirstDoor(animal_name, False,
                                  '12:"Not enough time spent outside"')
    else:
      self._status = _Status.SorterWaitSecondDoor
      self._cur_animal_conf =  animal_conf
      # We can either check for last entry time here or store last_entry_time
      # and check for it when we receive the weight
      last_entry_time_asc = time.ctime(last_entry_time)
      log.debug(f"Animal {animal_name} last entry time: {last_entry_time_asc} -"
                f" Dur outside: {dur_outside}s")
      if dur_outside > animal_conf.MaxTimeOutsideIgnoreWeight:
        self._bypass_weight = True
      self._sorter.allowFirstDoor(animal_name, True)

  def firstDoorFailed(self): #TODO: Rename abortCurAnimal
    if self._status != _Status.SorterWaitSecondDoor:
      log.warning(f"Unexpected status. Currently {self._status} - "
                  "got: entryAborted()")
      self._sorter.ackFirstDoorFailed(True)#, '40:"Didn\'t expect entry abort"')
      return
    # elif self._cur_animal_conf is None:
    #   self._sorter.ackFirstDoorFailed(True)#, '41:"Unkown/unexpected animal"')
    #   return
    self._status = _Status.SorterWaitFirstDoorMice
    self._sorter.ackFirstDoorFailed(False, "Testing no for an answer")

  def isSecondDoorAllowed(self):
    name = "_None_" if self._cur_animal_conf is None \
                    else self._cur_animal_conf.Name
    # We should decide here whether to let animal or not?
    if self._status != _Status.SorterWaitSecondDoor:
      log.warning(f"Unexpected status. Currently {self._status} - got: "
                  "isSecondDoorAllowed()")
      self._sorter.ackAnimalExited(name, False,
                                   '50:"Unexpected entry completed msg"')
      return

    min_weight = self._cur_animal_conf.MinWeight
    cur_weight = "_UNKOWN_" #self._cur_animal_initial_weight # Short-hand
    if True:# self._bypass_weight or cur_weight <= min_weight:
      if self._bypass_weight:
        log.info(f"Animal {name} allowed due to long time of inactive training."
                 f" Current weight: {cur_weight} (min. weight: {min_weight})")
      else:
        log.info(f"Animal {name} allowed entry with current weight "
                 "{self._cur_animal_initial_weight} (< min. weight "
                 f"{min_weight})")
      self._sorter.allowSecondDoor(True)
      self._status = _Status.BpodWaitSessionStartedOrFinished
      self._triggerBpodSess()
    else:
      log.info(f"Animal {name} not allowed as current weight: {cur_weight} is "
               f"more than min. weight: {min_weight}.")
      self._sorter.allowSecondDoor(False,  f'20:"Animal {name} current'
                                   f'weight={cur_weight} is more than '
                                   f'configured min_weight={min_weight}"')
      self._initStates()

  def _triggerBpodSess(self):
    log.info(f"Asking bpod to start session for {self._cur_animal_conf.Name}")
    self._bpod.startSession(self._cur_animal_conf.Name,
                            self._cur_animal_conf.Protocol,
                            self._cur_animal_conf.Config,
                            self._cur_animal_conf.MaxRewardAmount,
                            self._cur_animal_conf.MaxDuration)

  def animalWeight(self, animal_name, weight_str):
    weight = float(weight_str)
    if self._status == _Status.BpodWaitSessionStartedOrFinished:
      self._cur_animal_initial_weight = weight
      self._logCurEnterance(animal_name, _EnterOrExit.Enter, weight)
      self._status = _Status.BpodWaitSessionStartedOrFinished
    # elif self._status == _Status.SorterExitWeight:
    #   self._cur_animal_final_weight = weight
    #   self._status = _Status.SorterWaitFinalExit
    else:
      log.warning(f"Unexpected status. Currently {self._status} - "
                  "got: animalWeight()")

  def bpodSessionStarted(self):
    if self._status != _Status.BpodWaitSessionStartedOrFinished:
      log.warning(f"Unexpected status. Currently {self._status} - got: "
                  "bpodSessionStarted()")
      return
    # We are sure now that the animal is at the training rig and away from the
    # 2nd door.
    self._status = _Status.BpodWaitSessionStartedOrFinished # Redandant
    self._sorter.closeDoor2()
    # TODO: Put a timeout that we should force opening the door within if the
    # didn't hear back from bpod

  def bpodSessionFinished(self):
    if self._status != _Status.BpodWaitSessionStartedOrFinished:
      log.warning(f"Unexpected status. Currently {self._status} - got: "
                  "bpodSessionFinished()")
      return
    self._sorter.openDoor2(f'30:"Animal {self._cur_animal_conf.Name} finished '
                           'session"')
    self._status = _Status.SorterWaitFinalExit

  def animalExitedFirstDoor(self, animal_name):
    if self._status != _Status.SorterWaitFinalExit:
      log.warning(f"Unexpected status. Currently {self._status} - "
                  f"got: animalExitedFirstDoor() for animal {animal_name}")
      self._sorter.ackAnimalExited(animal_name, False,
                                   '50:"Unexpected exit animal message"')
      self._initStates() # Better to reset?
      return
    #self._logCurEnterance(animal_name, _EnterOrExit.Exit,
    #                      self._cur_animal_final_weight)
    self._initStates()
    self._sorter.ackAnimalExited(animal_name, True)

  def _logCurEnterance(self, animal_name, enter_or_exit, weight):
    new_row = {"Name":animal_name, "EnterOrExit":enter_or_exit,
               "Weight":weight, "UnixTime":time.time(),
               "Time":time.asctime()}
    log.debug("Updating entries-log with:" + str(new_row))
    self._entrylog = self._entrylog.append(new_row, ignore_index=True)
    try:
      self._entrylog.to_csv(self._entrylog_fp, index=False)
    except Exception:
      log.warning(f"Failed to save updated entry log to {self._entrylog_fp}")

class BpodComm:
  def __init__(self, decider):
    self._decider = decider
    self._reader_running = False

  async def connectBpodServer(self, bpod_srv_ip, bpod_srv_port):
    self._reader, self._writer = await asyncio.open_connection(bpod_srv_ip,
                                                               bpod_srv_port)
    log.info("Connected to bpod server")

  def startSession(self, animal_name, protocol, config, reward_amount, max_dur):
    if not self._reader_running:
      raise RuntimeError("Reader must be already listening")
    msg = f"{animal_name} {protocol} {config} {reward_amount} {max_dur}"
    log.debug("Sending to bpod server: " + msg)
    self._writer.write(f"{msg}\r\n".encode())

  async def routeBpodMsgs(self):
    self._reader_running = True
    while True:
      print("Reading bpod server messages")
      data = await self._reader.readline()
      data = data.decode().strip()
      if not len(data) and self._reader.at_eof():
        log.warning("Bpod conn terminated")
        self._decider.bpodSessionFinished()
        break
      log.debug(f"Bpod server said: {data}")
      msg = data.split(maxsplit=1)[0]
      if msg == "pulsecheck":
        continue
      elif msg == "animal_inside":
        self._decider.bpodSessionStarted()
      elif msg == "animal_done":
        self._decider.bpodSessionFinished()
      else:
        log.warning(f"Bpod server sent unknown message: {data}")



class SorterComm:
  _NO_COMMAND_RESP = 123456789 # Create a unique value for if-comparison

  def __init__(self, decider):
    self._decider = decider
    self._reply2Func = {
      "abort run": self._decider.sorterStopping,
      "weight": self._decider.animalWeight,
      "in": self._decider.isFirstDoorAllowed,
      "abort entry": self._decider.firstDoorFailed,
      "entry completed": self._decider.isSecondDoorAllowed,
      "out": self._decider.animalExitedFirstDoor,
    }

  async def start(self, srvr_ip, srvr_port):
    #self._server_socket = s
    log.info(f"Starting to {time.asctime()} listen on address "
             f"{srvr_ip}:{srvr_port}")
    self._srvr = await asyncio.start_server(self._handleConn, srvr_ip,
      srvr_port, reuse_address=True, backlog=10) # Should we set it 1?

  async def _handleConn(self, conn_reader, conn_writer):
    remote_addr = conn_writer.get_extra_info('peername')
    log.info(f"Received connection from: {remote_addr[0]}:{remote_addr[1]}")
    self._reader = conn_reader
    self._writer = conn_writer
    log.debug("Writing: start")
    self._writer.write(b'start\r\n')
    await self._writer.drain()
    while True:
      data = await self._reader.readline()
      data = data.decode().strip()
      if not len(data) and self._reader.at_eof():
        # TODO: Handle this case
        log.warning("Sorter conn terminated")
        break
      log.debug(f'Received from sorter: {data}')
      splitted = data.split()
      command = splitted[0]
      other = splitted[1:] if len(splitted) > 1 else []
      if command in ["abort", "entry"]:
        command += " " + other[0]
        other = other[1:]
      method = self._reply2Func[command]
      log.debug("Calling method:", method)
      method(*other)

  def _resp(self, keyword, animal_name, is_allowed, reason_if_no):
    # We can combine is_allowed and reason_if_no in one variable but they are
    # left separately for clarity
    # Add extra space if we have argument isn't empty
    if animal_name: animal_name = f" {animal_name}"
    if reason_if_no: reason_if_no = f" {reason_if_no}"
    if is_allowed == SorterComm._NO_COMMAND_RESP: # Special value
      response = f'{keyword}{reason_if_no}\r\n'
    elif is_allowed == True:
      response = f'{keyword} yes{animal_name}\r\n'
    else:
      response = f'{keyword} no{animal_name}{reason_if_no}\r\n'
    async def delayedDo():
      log.debug("Writing to sorter: " + response)
      await asyncio.sleep(5)
      self._writer.write(response.encode())
    asyncio.create_task(delayedDo())

  def ackSystemStopping(self, is_allowed, reason_if_no=None):
    animal_name = ''
    self._resp("abort", animal_name, is_allowed, reason_if_no)

  def allowFirstDoor(self, animal_name, is_allowed, reason_if_no=None):
    self._resp("in", animal_name, is_allowed, reason_if_no)

  def ackFirstDoorFailed(self, is_allowed, reason_if_no=None):
    animal_name = ''
    self._resp("abort", animal_name, is_allowed, reason_if_no)

  def allowSecondDoor(self, is_allowed, reason_if_no=None):
    animal_name = ''
    self._resp("entry", animal_name, is_allowed, reason_if_no)

  def closeDoor2(self):
    animal_name = ''
    is_allowed = SorterComm._NO_COMMAND_RESP
    reason_if_no = '' # This hack will cause an empty reason to be written
    self._resp("close door2", animal_name, is_allowed, reason_if_no)

  def openDoor2(self, reason):
    animal_name = ''
    is_allowed = SorterComm._NO_COMMAND_RESP
    self._resp("end", animal_name, is_allowed, reason)

  def ackAnimalExited(self, animal_name, is_allowed, reason_if_no=None):
    self._resp("out", animal_name, is_allowed, reason_if_no)

  async def closeConn(self):
    self._writer.close()
    await self._writer.wait_closed()

def interruptWakeup(loop):
  # STill exists as of 3.7: https://stackoverflow.com/a/24775107/11996983
  loop.call_later(0.1, interruptWakeup, loop)

async def main(loop):
  bpod_srv_ip, bpod_srv_port = "127.0.0.1", 30000
  server_ip, server_port = "127.0.0.1", 5555
  decider = Decider('etc/animals_conf.csv', 'etc/entry_log.csv')
  bpod_comm = BpodComm(decider)
  await bpod_comm.connectBpodServer(bpod_srv_ip, bpod_srv_port)
  asyncio.create_task(bpod_comm.routeBpodMsgs())
  #def triggerBpodSess():
  #  bpod_comm.startSession("DummySubject", "Mouse2AFC", "DefaultSettings", 0.5,
  #                         60)
  #loop.call_later(3, triggerBpodSess)
  #return
  sorter_comm = SorterComm(decider)
  #from mocktest import BpodCommMock
  #asyncio.create_task(bpod_comm.endSessionsWhenStarted())
  decider.setComms(sorter_comm, bpod_comm)
  asyncio.create_task(sorter_comm.start(server_ip, server_port))

if __name__ == "__main__":
  loop = asyncio.get_event_loop()
  loop.call_later(0.1, interruptWakeup, loop)
  loop.create_task(main(loop))
  loop.run_forever()