import asyncdispatch
import locks

type
  HookHandler = ref object of RootObj
    autobot_address: ByteAddress
    autobot_lock: Lock
    autobot_original_bytes: string
    autobot_pos: int

const autobot_size = 3900 ## rounded down

method getAvailableAutobotAddress(self: HookHandler, size: int): ByteAddress {.base, async.} =
  if self.autobot_pos + size > autobot_size:
    raise newException(ResourceExhaustedError, "Somehow went over autobot size")

  result = self.autobot_address + self.autobot_pos
  self.autobot_pos += size

method getAutobotAddress(self: HookHandler) =
  discard