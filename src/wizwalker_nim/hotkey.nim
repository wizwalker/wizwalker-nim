import asyncdispatch
import sequtils
import tables
import winim
import strformat

import constants

const max_hotkey_id = 0xBFFF

type
  GlobalHotkeyIdentifierManager = ref object
    hotkey_id_list: seq[bool]

  GlobalHotkeyMessageLoop = ref object
    messages: seq[(int32, ModifierFlags)]
    connected_instances: int
    message_loop_delay: float
    running: bool

  HotkeyListener* = ref object
    ## The thing that allows you to register hotkeys
    sleep_time: float
    hotkeys: Table[(int32, ModifierFlags), int32]
    callbacks: Table[(int32, ModifierFlags), proc () {.async.}]
    running: bool
    # TODO: Maybe switch to chronos async backend so cancellation exists

proc getId(self: GlobalHotkeyIdentifierManager): int32 =
  let list_len = self.hotkey_id_list.len().int32
  if list_len == max_hotkey_id:
    raise newException(ResourceExhaustedError, "Ran out of available hotkey slots")

  # at least one false
  if self.hotkey_id_list.any(proc (x: bool): bool = not x):
    let idx = self.hotkey_id_list.find(false).int32
    self.hotkey_id_list[idx] = true
    return idx + 1
  # all true
  else:
    self.hotkey_id_list.add(true)
    return list_len + 1

proc freeId(self: GlobalHotkeyIdentifierManager, hotkey_id: int) =
  self.hotkey_id_list[hotkey_id - 1] = false

  ## all false
  if self.hotkey_id_list.all(proc (x: bool): bool = not x):
    self.hotkey_id_list = @[]

var hotkey_id_manager {.global.} = GlobalHotkeyIdentifierManager(hotkey_id_list: @[])


proc checkForMessage(self: GlobalHotkeyMessageLoop, keycode: int32, modifiers: ModifierFlags): bool =
  if (keycode, modifiers) in self.messages:
    let idx = self.messages.find((keycode, modifiers))
    self.messages.del(idx)
    return true

proc messageLoop(self: GlobalHotkeyMessageLoop) {.async.} =
  while self.running:
    var message = MSG()
    let is_message = PeekMessage(addr(message), 0, 0x311, 0x314, 1)
    if is_message:
      let
        modifiers = (message.lParam and 0b1111111111111111).int32
        keycode = (message.lParam shr 16).int32

      self.messages.add((keycode, cast[ModifierFlags](modifiers)))

    await sleepAsync((self.message_loop_delay * 1000).int)

proc connect(self: GlobalHotkeyMessageLoop) =
  if not self.running:
    self.running = true
    asyncCheck self.messageLoop()

  inc self.connected_instances

proc disconnect(self: GlobalHotkeyMessageLoop) =
  dec self.connected_instances

  if self.connected_instances == 0:
    self.running = false

proc setMessageLoopDelay(self: GlobalHotkeyMessageLoop, new_delay: float) =
  self.message_loop_delay = new_delay

var hotkey_message_loop {.global.} = GlobalHotkeyMessageLoop(message_loop_delay : 0.1)


proc handleHotkey(self: HotkeyListener, keycode: int32, modifiers: ModifierFlags) =
  asyncCheck self.callbacks[(keycode, modifiers)]()

proc messageLoop(self: HotkeyListener) {.async.} =
  while self.running:
    for key in self.callbacks.keys():
      var mods = key[1]
      mods.excl(Modifier.NOREPEAT)
      if hotkey_message_loop.checkForMessage(key[0], mods):
        self.handleHotkey(key[0], key[1])

    await sleepAsync((self.sleep_time * 1000).int)

proc start*(self: HotkeyListener) =
  ## Start the hotkey listener
  if self.running:
    raise newException(ValueError, "Hotkey listener has already been started")

  self.running = true
  hotkey_message_loop.connect()

  asyncCheck self.messageLoop()

proc stop*(self: HotkeyListener) =
  ## Stop the hotkey listener
  hotkey_message_loop.disconnect()

  for hotkey_id in self.hotkeys.values:
    UnregisterHotKey(0, hotkey_id)

  self.running = false

proc registerHotkey(self: HotkeyListener, key: int32, modifiers: ModifierFlags = {}): bool =
  let
    hotkey_id = hotkey_id_manager.getId()
  result = RegisterHotKey(0, hotkey_id, cast[int32](modifiers), key).bool

  if result:
    self.hotkeys[(key, modifiers)] = hotkey_id
  else:
    hotkey_id_manager.freeId(hotkey_id)

proc addHotkey*(self: HotkeyListener, key: int32, callback: proc () {.async.}, modifiers: ModifierFlags = {}) = 
  ## Register a new hotkey
  if self.registerHotkey(key, modifiers):
    var no_norepeat = modifiers
    no_norepeat.excl(Modifier.NOREPEAT)
    self.callbacks[(key, modifiers)] = callback
  else:
    raise newException(ValueError, &"{key} with modifiers {modifiers} already registered")

proc unregisterHotkey(self: HotkeyListener, key: int32, modifiers: ModifierFlags = {}): bool =
  let hotkey_id = self.hotkeys[(key, modifiers)]
  result = UnregisterHotKey(0, hotkey_id).bool
  if result:
    hotkey_id_manager.freeId(hotkey_id)

proc removeHotkey*(self: HotkeyListener, key: int32, modifiers: ModifierFlags = {}) =
  ## Unregister a hotkey
  if not ((key, modifiers) in self.hotkeys):
    raise newException(ValueError, &"No hotkey registered for key {key} with modifiers {modifiers}")

  if not self.unregisterHotkey(key, modifiers):
    raise newException(ValueError, &"Unregistering hotkey failure for key {key} with modifiers {modifiers}")

  self.hotkeys.del((key, modifiers))

proc clear(self: HotkeyListener) =
  ## Removes all hotkeys from listener
  for hotkey_id in self.hotkeys.values():
    let res = UnregisterHotkey(0, hotkey_id)
    if res != 0:
      hotkey_id_manager.freeId(hotkey_id)

  self.hotkeys.clear()
  self.callbacks.clear()

proc setGlobalMessageLoopDelay*(delay: float) =
  hotkey_message_loop.setMessageLoopDelay(delay)
