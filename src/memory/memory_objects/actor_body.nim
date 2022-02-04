import ../memory_object
import ../memory_handler
import ../handler
import ../../utils

type
  ActorBody* = ref object of PropertyClass
  CurrentActorBody* = ref object of ActorBody

method readBaseAddress*(self: ActorBody): ByteAddress =
  raise newException(ValueError, "Non-dynamic ActorBody does not support memory operations")

method readBaseAddress*(self: CurrentActorBody): ByteAddress =
  result = self.hook_handler.readCurrentPlayerHookBase()

proc position*(self: ActorBody): XYZ =
  ## This body's position
  self.readXYZFromOffset(88)

proc writePosition*(self: ActorBody, val: XYZ) =
  ## Write to this body's position
  self.writeXYZToOffset(88, val)

proc pitch*(self: ActorBody): float32 =
  ## This body's pitch
  result = self.readValueFromOffset(100, float32)

proc writePitch*(self: ActorBody, val: float32) =
  ## Write to this body's pitch
  self.writeValueToOffset(100, val)

proc roll*(self: ActorBody): float32 =
  ## This body's roll
  result = self.readValueFromOffset(104, float32)

proc writeRoll*(self: ActorBody, val: float32) =
  ## Write to this body's roll
  self.writeValueToOffset(104, val)

proc yaw*(self: ActorBody): float32 =
  ## This body's yaw
  result = self.readValueFromOffset(108, float32)

proc writeYaw*(self: ActorBody, val: float32) =
  ## Write to this body's yaw
  self.writeValueToOffset(108, val)

proc height*(self: ActorBody): float32 =
  ## This body's height
  result = self.readValueFromOffset(132, float32)

proc writeHeight*(self: ActorBody, val: float32) =
  ## Write to this body's height
  self.writeValueToOffset(132, val)

proc scale*(self: ActorBody): float32 =
  ## This body's scale
  result = self.readValueFromOffset(112, float32)

proc writeScale*(self: ActorBody, val: float32) =
  ## Write to this body's scale
  self.writeValueToOffset(112, val)

proc moduleUpdateScheduled*(self: ActorBody): bool =
  ## If body should be updated
  result = self.readValueFromOffset(136, bool)

proc writeModuleUpdateScheduled*(self: ActorBody, val: bool) =
  ## Write if this body should be updated
  self.writeValueToOffset(136, val)
