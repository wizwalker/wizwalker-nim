import asyncdispatch
import options
import os
import algorithm

import winim

import utils
import client

type
  ClientHandler* = ref object of RootObj
    client_cls: proc(handle: HWND): Client ## Client constructor
    managed_handles: seq[HWND]
    clients: seq[Client]

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

# TODO
# method activateAllClientHooks*(self: ClientHandler) = discard

# TODO
# method activateAllClientMouseless*(self: ClientHandler)

# TODO
# method close

import times
when isMainModule:
  var client_handler = ClientHandler(client_cls : initClient)
  var c = client_handler.getNewClients()[0]
  let start = cpuTime()
  waitFor c.activateHooks(wait_for_ready=false)
  echo "hooked"
  echo "closing"
  waitFor c.close()
