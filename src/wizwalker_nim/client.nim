import asyncdispatch
import options
import winim
import tables

import utils
import constants
import mouse_handler
import memory/memory_handler
import memory/handler
import memory/memory_objects/game_stats
import memory/memory_objects/actor_body
import memory/memory_objects/duel
import memory/memory_objects/quest_position
import memory/memory_objects/client_object
import memory/memory_objects/window
import memory/memory_objects/render_context

type
  Client* = ref object of RootObj
    ## Represents a connected wizard101 client
    window_handle*: HWND
    memory_handler*: MemoryHandler
    hook_handler*: HookHandler
    process_handle*: HANDLE

    mouse_handler*: MouseHandler

    stats*: CurrentGameStats
    body*: CurrentActorBody
    duel*: CurrentDuel
    quest_position*: CurrentQuestPosition
    client_object*: CurrentClientObject
    root_window*: CurrentRootWindow
    render_context*: CurrentRenderContext

    is_infinite_patched: bool

method process_id*(self: Client): int32 {.base.} =
  ## Client's process id
  self.window_handle.getPidFromHandle()

proc initClient*(window_handle: HWND): Client =
  result = Client(window_handle : window_handle)
  result.process_handle = OpenProcess(PROCESS_ALL_ACCESS, false, result.process_id())
  result.memory_handler = initMemoryHandler(result.process_handle, result.window_handle)
  result.hook_handler = initHookHandler(result.memory_handler)

  result.stats = CurrentGameStats(memory_handler : result.memory_handler, hook_handler : result.hook_handler)
  result.body = CurrentActorBody(memory_handler : result.memory_handler, hook_handler : result.hook_handler)
  result.duel = CurrentDuel(memory_handler : result.memory_handler, hook_handler : result.hook_handler)
  result.quest_position = CurrentQuestPosition(memory_handler : result.memory_handler, hook_handler : result.hook_handler)
  result.client_object = CurrentClientObject(memory_handler : result.memory_handler, hook_handler : result.hook_handler)
  result.root_window = CurrentRootWindow(memory_handler : result.memory_handler, hook_handler : result.hook_handler)
  result.render_context = CurrentRenderContext(memory_handler : result.memory_handler, hook_handler : result.hook_handler)
  
  result.mouse_handler = MouseHandler(window_handle : window_handle, hook_handler : result.hook_handler, root_window : result.root_window)

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

method is_running*(self: Client): bool {.base.} =
  ## If this client is still running
  self.process_handle.checkIfProcessRunning()

method login*(self: Client, username, password: string) {.base.} =
  ## Login this client
  self.process_handle.instanceLogin(username, password)

method sendKey*(self: Client, key: int, seconds: float = 0.0) {.base, async.} =
  ## Send a key
  await timedSendKey(self.window_handle, key, seconds)

method patchInfiniteLoading(self: Client) {.base.} =
  if self.is_infinite_patched:
    return

  let cmp_addr = self.memory_handler.patternScan(escapeByteRegex("\x80\x3D.....\x0F\x85...........\xE8....\x39"))
  if cmp_addr.len() == 0:
    raise newException(ValueError, "Could not find the infinite loading pattern")
  elif cmp_addr.len() > 1:
    raise newException(ValueError, "Found too many candidates for infinite loading pattern")

  let
    ac_flag_offset = self.memory_handler.read(cmp_addr[0] + 2, int32)
    ac_flag_addr = cmp_addr[0] + 7 + ac_flag_offset

  self.memory_handler.write(ac_flag_addr, true)
  self.is_infinite_patched = true

method teleport*(self: Client, pos: XYZ, yaw: Option[float32] = none(float32), move_after: bool = true) {.base, async.} =
  self.patchInfiniteLoading()

  self.body.writePosition(pos)

  if move_after:
    await self.sendKey(Keycode["D"], 0.1)

  if yaw.isSome():
    self.body.writeYaw(yaw.get())

method activateHooks*(self: Client, wait_for_ready: bool = true, timeout: float = -1) {.base, async.} =
  ## Activates all hooks for this client
  # TODO: Change this asap
  await self.hook_handler.activateAllHooks(wait_for_ready, timeout)

method close*(self: Client) {.base.} =
  ## Unhooks the client
  self.hook_handler.close()
