import asyncdispatch
import tables
import re
import strformat
import strutils

import memory_handler
import hooks

type
  HookHandler* = ref object of RootObj
    autobot_address: ByteAddress
    autobot_original_bytes: string
    autobot_pos: int
    memory_handler: MemoryHandler
    active_hooks: seq[MemoryHook]
    base_addrs: Table[string, ByteAddress]

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

proc close*(self: HookHandler) {.async.} = 
  ## Closes the HookHandler instance
  for h in self.active_hooks:
    h.unhook()
  self.active_hooks = @[]
  await sleepAsync(1000) # So hooks have time to escape
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
        await sleepAsync(0.1)
  if timeout_seconds != -1.0:
    if not await value_task().withTimeout((timeout_seconds * 1000).int):
      raise newException(ResourceExhaustedError, "Hook value took too long")
  else:
    await value_task()

proc activatePlayerHook*(self: HookHandler, wait_for_ready: bool = true, timeout: float = -1.0) {.async.} =
  ## Activate the player hook
  if self.checkIfHookActive(PlayerHook):
    raise newException(ValueError, "Player hook activated twice")

  proc autobotAllocator(size: int): ByteAddress =
    self.allocateAutobotBytes(size)

  let player_hook = initPlayerHook(self.memory_handler, autobotAllocator)
  player_hook.hook()
  self.active_hooks.add(player_hook)
  self.base_addrs["player_struct"] = player_hook.export_addrs["player_struct"]

  if wait_for_ready:
    await self.waitForValue(player_hook.export_addrs["player_struct"], timeout)

proc deactivatePlayerHook*(self: HookHandler) {.async.} =
  if not self.checkIfHookActive(PlayerHook):
    raise newException(ValueError, "Tried disabling inactive player hook")

  let hook = self.getHookByType(PlayerHook)
  self.active_hooks.del(self.active_hooks.find(hook))
  hook.unhook()

  self.base_addrs.del("player_struct")

proc readCurrentPlayerBase*(self: HookHandler): ByteAddress =
  self.readHookBaseAddr("player_struct")
