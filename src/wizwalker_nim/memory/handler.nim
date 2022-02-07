import asyncdispatch
import tables
import strformat
import strutils

import memory_handler
import hooks
import ../utils

type
  HookHandler* = ref object of RootObj
    autobot_address: ByteAddress
    autobot_original_bytes: string
    autobot_pos: int
    memory_handler: MemoryHandler
    active_hooks: seq[MemoryHook]
    base_addrs: Table[string, ByteAddress]
    is_hooked: bool

proc initHookHandler*(memory_handler: MemoryHandler): HookHandler =
  HookHandler(memory_handler : memory_handler)

const
  autobot_size = 3900 ## rounded down
  autobot_pattern = "\x48\x8B\xC4\x55\x41\x54\x41\x55\x41\x56\x41\x57.......\x48......\x48.......\x48\x89\x58\x10\x48\x89\x70\x18\x48\x89\x78\x20.......\x48\x33\xC4.......\x4C\x8B\xE9.......\x80"

proc getAvailableAutobotAddress(self: HookHandler, size: int): ByteAddress =
  if self.autobot_pos + size > autobot_size:
    raise newException(ResourceExhaustedError, "Somehow went over autobot size")

  result = self.autobot_address + self.autobot_pos
  self.autobot_pos += size

proc getAutobotAddress(self: HookHandler) =
  let res = self.memory_handler.patternScan(autobot_pattern, module="WizardGraphicalClient.exe")
  if res.len() == 0:
    raise newException(ResourceExhaustedError, "Failed to find autobot codecave")
  self.autobot_address = res[0]

proc prepareAutobot*(self: HookHandler) =
  ## Prepare the autobot codecave for use
  if self.autobot_address == 0:
    self.getAutobotAddress()
    self.autobot_original_bytes = self.memory_handler.readBytes(self.autobot_address, autobot_pattern.len())

    self.memory_handler.writeBytes(self.autobot_address, newString(autobot_size))

proc restoreAutobot(self: HookHandler) =
  if self.autobot_address != 0:
    self.memory_handler.writeBytes(self.autobot_address, self.autobot_original_bytes)
    self.autobot_address = 0

proc allocateAutobotBytes(self: HookHandler, size: int): int =
  self.getAvailableAutobotAddress(size)

proc close*(self: HookHandler) = 
  ## Closes the HookHandler instance
  self.is_hooked = false
  for h in self.active_hooks:
    h.unhook()
  self.active_hooks = @[]
  self.restoreAutobot()
  self.autobot_pos = 0

proc checkIfHookActive[T](self: HookHandler, t: typedesc[T]): bool =
  for hook in self.active_hooks:
    if hook is T:
      return true

proc getHookByType[T](self: HookHandler, t: typedesc[T]): MemoryHook =
  for hook in self.active_hooks:
    if hook is T:
      return hook

proc readHookBaseAddr(self: HookHandler, addr_name: string): ByteAddress =
  let a = self.base_addrs.getOrDefault(addr_name, 0)
  if a == 0:
    raise newException(ValueError, "Tried reading base address of inactive hook: " & $addr_name)
  
  try:
    return self.memory_handler.read(a, ByteAddress)
  except ResourceExhaustedError:
    raise newException(ValueError, "Tried reading base address of broken hook: " & $addr_name)

proc waitForValue(self: HookHandler, address: ByteAddress, timeout_seconds: float = -1.0) {.async.} =
  proc value_task() {.async.} = 
    while true:
      try:
        let value = self.memory_handler.read(address, ByteAddress)
        if value != 0:
          break
      except CatchableError:
        await sleepAsync(100)
  if timeout_seconds != -1.0:
    if not await value_task().withTimeout((timeout_seconds * 1000).int):
      raise newException(ResourceExhaustedError, "Hook value took too long")
  else:
    await value_task()

template createHookToggles*(typename: typed, exported: string) {.dirty.} =
  proc `activate typename`*(self: HookHandler, wait_for_ready: bool = true, timeout: float = -1.0) {.async.} =
    if self.autobot_address == 0:
      self.prepareAutobot()
    self.is_hooked = true
    if self.checkIfHookActive(typename):
      let name = $typename
      raise newException(ValueError, &"{name} activated twice")
    proc autobotAllocator(size: int): ByteAddress =
      self.allocateAutobotBytes(size)
    let hook = `init typename`(self.memory_handler, autobotAllocator)
    hook.hook()
    self.active_hooks.add(hook)
    self.base_addrs[exported] = hook.export_addrs[exported]

    if wait_for_ready:
      await self.waitForValue(hook.export_addrs[exported], timeout)

  proc `deactivate typename`*(self: HookHandler) =
    if not self.checkIfHookActive(typename):
      let name = $typename
      raise newException(ValueError, &"Tried disabling {name} hook")

    let hook = self.getHookByType(typename)
    self.active_hooks.del(self.active_hooks.find(hook))
    hook.unhook()

    self.base_addrs.del(exported)

  proc `readCurrent typename Base`*(self: HookHandler): ByteAddress =
    self.readHookBaseAddr(exported)

createHookToggles(PlayerHook, "player_struct")
createHookToggles(DuelHook, "current_duel_addr")
createHookToggles(QuestHook, "cord_struct")
createHookToggles(PlayerStatHook, "stat_addr")
createHookToggles(ClientHook, "current_client_addr")
createHookToggles(RootWindowHook, "current_root_window_addr")
createHookToggles(RenderContextHook, "current_render_context_addr")

proc writeMousePosition*(self: HookHandler, x, y: int) =
  let address = self.base_addrs.getOrDefault("mouse_position", 0)
  if address == 0:
    raise newException(ValueError, "MouselessHook is not active")

  let packed_pos = (y shl 32) or (x and 0xFFFFFFFF)
  self.memory_handler.writeBytes(address, packed_pos.toBytes().toString())

proc activateMouselessHook*(self: HookHandler) {.async.} =
  if self.checkIfHookActive(MouselessHook):
    raise newException(ValueError, "MouselessHook is already active")

  let h = MouselessHook(memory_handler : self.memory_handler)
  h.hook()
  self.base_addrs["mouse_position"] = h.mouse_pos_addr
  self.active_hooks.add(h)
  self.writeMousePosition(0, 0)

proc deactivateMouselessHook*(self: HookHandler) =
  if not self.checkIfHookActive(MouselessHook):
    raise newException(ValueError, "MouselessHook is not active")

  let hook = self.getHookByType(MouselessHook)
  self.active_hooks.del(self.active_hooks.find(hook))
  hook.unhook()

  self.base_addrs.del("mouse_position")

proc activateAllHooks*(self: HookHandler, wait_for_ready: bool = true, timeout: float = -1.0) {.async.} =
  ## Activate all hooks but mouseless
  await self.activatePlayerHook(wait_for_ready=false)
  # duel is only written to on battle join
  await self.activateDuelHook(wait_for_ready=false)
  # quest hook is not written if quest arrow is off
  await self.activateQuestHook(wait_for_ready=false)
  await self.activatePlayerStatHook(wait_for_ready=false)
  await self.activateClientHook(wait_for_ready=false)
  await self.activateRootWindowHook(wait_for_ready=false)
  await self.activateRenderContextHook(wait_for_ready=false)

  if wait_for_ready:
    await all(@[
      self.waitForValue(self.base_addrs["player_struct"]),
      self.waitForValue(self.base_addrs["stat_addr"]),
      self.waitForValue(self.base_addrs["current_client_addr"]),
      self.waitForValue(self.base_addrs["current_root_window_addr"]),
      self.waitForValue(self.base_addrs["current_render_context_addr"]),
    ])
