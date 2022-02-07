import asyncdispatch
import strformat

import winim

import utils
import memory/handler
import memory/memory_objects/window

type
  MouseHandler* = ref object of RootObj
    hook_handler*: HookHandler
    window_handle*: HWND
    root_window*: Window
    # Maybe add a lock like in original WW?

method activateMouseless*(self: MouseHandler) {.base, async.} =
  ## Activates the mouseless hook
  await self.hook_handler.activateMouselessHook()

method deactivateMouseless*(self: MouseHandler) {.base, async.} =
  ## Deactivates the mouseless hook
  await self.hook_handler.deactivateMouselessHook()

method setMousePosition*(self: MouseHandler, x, y: int, convert_from_client: bool = true, use_post: bool = false) {.base.} =
  var
    new_x = 0
    new_y = 0
  if convert_from_client:
    var point = POINT(x : x.int32, y : y.int32)
    if not ClientToScreen(self.window_handle, addr(point)).bool:
      raise newException(ValueError, "Client to screen conversion failed")
    new_x = point.x.int
    new_y = point.y.int

  paintOnScreen(
    Rectangle(x1 : x.int32, x2: x.int32 + 4, y1 : y.int32, y2 : y.int32 + 4),
    self.window_handle
  )

  self.hook_handler.writeMousePosition(new_x, new_y)
  if use_post:
    discard PostMessageW(self.window_handle, 0x200, 0, 0)
  else:
    discard SendMessageW(self.window_handle, 0x200, 0, 0)

method setMousePositionToWindow*(self: MouseHandler, window: Window) {.base.} =
  let
    scaled_rect = window.scaleToClient()
    center = scaled_rect.center()

  self.setMousePosition(center[0], center[1])

method click*(self: MouseHandler, x, y: int, right_click: bool = false, sleep_duration: float = 0.05, use_post: bool = false) {.base, async.} =
  ## Click an x, y position
  let message = if right_click: 0x204i32 else: 0x201i32

  self.setMousePosition(x, y)
  if use_post:
    discard PostMessageW(self.window_handle, message, 1, 0)
  else:
    discard SendMessageW(self.window_handle, message, 1, 0)

  if sleep_duration > 0:
    await sleepAsync((sleep_duration * 1000).int)

  if use_post:
    discard PostMessageW(self.window_handle, message + 1, 0, 0)
  else:
    discard SendMessageW(self.window_handle, message + 1, 0, 0)

  if sleep_duration > 0:
    await sleepAsync((sleep_duration * 1000).int)

  self.setMousePosition(-100, -100)

method clickWindow*(self: MouseHandler, window: Window, right_click: bool = false, sleep_duration: float = 0.05, use_post: bool = false) {.base, async.} =
  let
    scaled_rect = window.scaleToClient()
    center = scaled_rect.center()

  await self.click(center[0], center[1], right_click, sleep_duration, use_post)

method clickWindowWithName*(self: MouseHandler, name: string, right_click: bool = false, sleep_duration: float = 0.05, use_post: bool = false) {.base, async.} =
  let possible_window = self.root_window.getWindowsWithName(name)
  if possible_window.len() == 0:
    raise newException(ValueError, &"Window with name {name} not found")
  elif possible_window.len() > 1:
    raise newException(ValueError, &"Multiple windows with name {name} found")

  await self.clickWindow(possible_window[0], right_click, sleep_duration, use_post)
