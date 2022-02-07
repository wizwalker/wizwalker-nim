import asyncdispatch
import options
import algorithm

import winim

import utils
import client
import interrupt_handler

type
  ClientHandler* = ref object of RootObj
    client_cls: proc(handle: HWND): Client ## Client constructor
    managed_handles: seq[HWND]
    clients*: seq[Client]

  KeyboardInterruptError* = object of CatchableError

proc initClientHandler*(run_default_interrupt_handler: bool = true, client_cls: proc(handle: HWND): Client = initClient): ClientHandler =
  ## Constructor for ClientHandler. Should use this instead of using type directly
  new(result)
  result.client_cls = client_cls

  if run_default_interrupt_handler:
    registerInterruptHandler:
      raise newException(KeyboardInterruptError, "")
    startConsoleInterruptLoop()

method installLocation*(self: ClientHandler): Option[string] {.base.} =
  ## Wizard101 install location
  getWizInstall()

method startWizClient*(self: ClientHandler) {.base.} =
  ## Start a new client
  startInstance()

method getForegroundClient*(self: ClientHandler): Option[Client] {.base.} =
  ## Get the client in the foreground, if one of them is
  for client in self.clients:
    if client.is_foreground:
      return some(client)

method getNewClients*(self: ClientHandler): seq[Client] {.base.} =
  ## Get all new clients currently unmanaged
  for handle in getAllWizardHandles():
    if not self.managed_handles.contains(handle):
      self.managed_handles.add(handle)

      var new_client = self.client_cls(handle)
      self.clients.add(new_client)
      result.add(new_client)

method removeDeadClients*(self: ClientHandler): seq[Client] {.base.} =
  ## Remove and return clients that are no longer running
  for i in 0 ..< self.clients.len():
    if not self.clients[i].is_running:
      result.add(self.clients[i])
      self.clients.delete(i)

proc orderClients*(clients: seq[Client]): seq[Client] =
  ## Sort clients based on their screen position
  result = clients
  result.sort(
    proc (x, y: Client): int =
      let
        x_rect = x.window_rectangle()
        y_rect = y.window_rectangle()
      if x_rect.y1 > y_rect.y1:
        return 1
      elif x_rect.y1 < y_rect.y1:
        return -1
      else:
        if x_rect.x1 > y_rect.x1:
          return 1
        elif x_rect.x1 < y_rect.x1:
          return -1
  )

method getOrderedClients*(self: ClientHandler): seq[Client] {.base.} =
  ## Get clients ordered by their position on screen
  orderClients(self.clients)

method activateAllClientHooks*(self: ClientHandler, wait_for_ready: bool = true) {.base, async.} =
  var awaitables: seq[Future[void]]
  for c in self.clients:
    awaitables.add(c.activateHooks(wait_for_ready=wait_for_ready))

  await all(awaitables)

# TODO
# method activateAllClientMouseless*(self: ClientHandler)

method close*(self: ClientHandler) {.base, async.} =
  for c in self.clients:
    await c.close()

