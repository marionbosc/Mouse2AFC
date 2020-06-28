from functools import partialmethod
import asyncio

class BpodCommMock():
  def __init__(self, decider):
    self._decider = decider
    self._queue = asyncio.Queue()
    self._keep_running = True
    self._async_listening = False

  def startSession(self, animal_name, protocol, config, num_trials):
    print(f"Decider asked to start {animal_name} with protocol: {protocol} and "
          f"config: {config} for {num_trials}")
    if not self._async_listening:
      raise RuntimeError("You should await call first endSessionsWhenStarted()")
    self._queue.put_nowait("Trigger")

  async def endSessionsWhenStarted(self):
    self._async_listening = True
    while self._keep_running:
      if not self._queue.empty():
        _ = self._queue.get_nowait()
        self._decider.bpodSessionStarted()
        await asyncio.sleep(0.5)
        self._decider.bpodSessionFinished()
      else:
        await asyncio.sleep(0.5)

  def closeConn(self):
    self._keep_running = False

class DeciderMock():
  def _tmpltCall(self, *args, **kargs):
    print("tmplt call called")
    import inspect
    # Use index 1 rather than server as we are wrapped for our parent caller
    wrapping_method = getattr(self, inspect.stack()[1][3])
    print("Starting acknowledgment from", wrapping_method)
    if self._expected_call != wrapping_method:
      raise RuntimeError("Expected " + str(self._expected_call) + " to be "
                         "called but " + str(wrapping_method) + " was called "
                         "instead")
    self._ackCb()
    print("Finished acknowledgment from", wrapping_method)

  def sorterStopping(self, *args, **kargs): self._tmpltCall(*args, **kargs)
  def animalWeight(self, *args, **kargs): self._tmpltCall(*args, **kargs)
  def isFirstDoorAllowed(self, *args, **kargs): self._tmpltCall(*args, **kargs)
  def firstDoorFailed(self, *args, **kargs): self._tmpltCall(*args, **kargs)
  def isSecondDoorAllowed(self, *args, **kargs): self._tmpltCall(*args, **kargs)
  def animalExitedFirstDoor(self, *args, **kargs): self._tmpltCall(*args,
                                                                   **kargs)
  def bpodSessionFinished(self, *args, **kargs): self._tmpltCall(*args, **kargs)

  def setExpectedCall(self, cb, ackCb):
    self._expected_call = cb
    self._ackCb = ackCb

class SorterMock():
  def __init__(self, decider_mock, *, real_decider):
    self._decider = decider_mock
    self._is_real_decider = real_decider
    self._pause = False

  def responseArrived(self):
    '''It's a private function that's being passed as call back to external
    functions'''
    self._pause = False
    self._wait_task.cancel()

  async def _checkResp(self, line_content, expected_cb):
    if self._is_real_decider:
      self._writer.write(f"{line_content}\r\n".encode())
      await asyncio.sleep(self._wait_time)
    else:
      assert self._pause == False
      self._pause = True
      self._decider.setExpectedCall(expected_cb, self.responseArrived)
      print("Sending", line_content)
      self._writer.write(f"{line_content}\r\n".encode())
      # await self._writer.drain()
      self._wait_task = asyncio.create_task(asyncio.sleep(self._wait_time))
      try:
        await self._wait_task
      except asyncio.CancelledError:
        pass # Will happen if responseArrived() canceled this task
      if self._pause:
        raise RuntimeError("Response never arrived for " + line_content)


  async def _establishConn(self, srvr_ip, srvr_port, srvr_start_msg_wait):
    import socket
    self._reader, self._writer = await asyncio.open_connection(srvr_ip,
                                                               srvr_port)
    buf = await asyncio.wait_for(self._reader.readline(), srvr_start_msg_wait)
    assert buf.decode().strip() == "start"

  async def start(self, wait_time, srvr_ip, srvr_port, srvr_start_msg_wait):
    await self._establishConn(srvr_ip, srvr_port, srvr_start_msg_wait)
    self._wait_time = wait_time
    name = "DummyAnimal"
    weight_initial = 23.7
    weight_final = 24.7
    # Simulate a failed access
    await self._checkResp(f"in {name}", self._decider.isFirstDoorAllowed)
    await self._checkResp(f"abort entry", self._decider.firstDoorFailed)
    # Simulate complete access
    await self._checkResp(f"in {name}", self._decider.isFirstDoorAllowed)
    await self._checkResp(f"{weight_initial}", self._decider.animalWeight)
    await self._checkResp(f"entry completed", self._decider.isSecondDoorAllowed)
    # Wait for MockBpod to finish - TODO: Find better design
    await asyncio.sleep(2)
    # TODO: Real server is allowed to wait for weight in one line with entry/out
    # TODO: Check here that openDoor2() was called
    await self._checkResp(f"{weight_final}", self._decider.animalWeight)
    await self._checkResp(f"out {name}", self._decider.animalExitedFirstDoor)
    await self._checkResp(f"abort run", self._decider.sorterStopping)


async def main():
  from Tk_gui import SorterComm, Decider
  server_ip, server_port = "127.0.0.1", 5000
  decider_mock = DeciderMock()
  sorter_comm = SorterComm(decider_mock, reportFn=print)
  await sorter_comm.start(server_ip, server_port)
  sorter_mock = SorterMock(decider_mock, real_decider=False)
  await sorter_mock.start(1, server_ip, server_port, 10)
  print("Closing connection")
  await sorter_comm.closeConn()

  print("**********\n"*3)

async def main2():
  from Tk_gui import SorterComm, Decider
  server_ip, server_port = "127.0.0.1", 5000
  decider = Decider('etc/animals_conf.csv', 'etc/entry_log.csv')
  sorter_comm = SorterComm(decider, reportFn=print)
  bpod_comm = BpodCommMock(decider)
  asyncio.create_task(bpod_comm.endSessionsWhenStarted())
  decider.setComms(sorter_comm, bpod_comm)
  await sorter_comm.start(server_ip, server_port)
  sorter_mock = SorterMock(decider, real_decider=True)
  await sorter_mock.start(1, server_ip, server_port, 10)

if __name__ == "__main__":
  asyncio.run(main())
  asyncio.run(main2())
