import asyncdispatch
import options
import locks

import winim

import utils
import constants

type
  Client* = ref object of RootObj
    ## Represents a connected wizard101 client
    window_handle*: HWND
    process_handle: HANDLE # TODO: Make this a thing

proc newClient*(window_handle: HWND): Client =
  result = Client(
    window_handle : window_handle
  )

method title*(self: Client): string {.base.} =
  ## Get the window title
  self.window_handle.getWindowTitle()

method `title=`*(self: Client, title: string) {.base.} =
  ## Allow for `client.title = "Your title"` syntax
  self.window_handle.setWindowTitle(title)

method is_foreground*(self: Client): bool {.base.} =
  ## If this client is the foreground window
  GetForegroundWindow() == self.window_handle

method `is_foreground=`*(self: Client, val: bool) {.base.} =
  ## Allow for `client.is_foreground = true` syntax
  if val:
    self.window_handle.SetForegroundWindow()

method window_rectangle*(self: Client): Rectangle {.base.} =
  ## Get this client's window rectangle
  self.window_handle.getWindowRectangle()

method process_id*(self: Client): int {.base.} =
  ## Client's process id
  self.window_handle.getPidFromHandle()

method is_running*(self: Client): bool {.base.} =
  ## If this client is still running
  self.process_handle.checkIfProcessRunning()

method login*(self: Client, username, password: string) {.base.} =
  ## Login this client
  self.process_handle.instanceLogin(username, password)

method sendKey*(self: Client, key: Keycode, seconds: float = 0.0) {.base, async.} =
  ## Send a key
  await timedSendKey(self.window_handle, key, seconds)

method sendHotkey*(self: Client, modifiers: set[Keycode], key: Keycode) {.base, async.} =
  ## Send a hotkey
  await sendHotkey(self.window_handle, modifiers, key)
