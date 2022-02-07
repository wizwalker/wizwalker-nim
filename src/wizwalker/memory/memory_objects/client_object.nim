import options

include common_imports
import behavior_instance
import game_object_template
import client_zone
import game_stats

type
  ClientObject* = ref object of PropertyClass
  CurrentClientObject* = ref object of ClientObject

method readBaseAddress*(self: CurrentClientObject): ByteAddress =
  self.hook_handler.readCurrentClientHookBase()

proc inactiveBehaviors*(self: ClientObject): seq[BehaviorInstance] =
  ## This client object's inactive behaviors(?)
  for address in self.readSharedVectorFromOffset(224):
    if address != 0:
      result.add(self.createDynamicMemoryObject(BehaviorInstance, address))

proc objectTemplate*(self: ClientObject): Option[WizGameObjectTemplate] =
  let address = self.readValueFromOffset(88, ByteAddress)
  if address == 0:
    return none(WizGameObjectTemplate)

  some(self.createDynamicMemoryObject(WizGameObjectTemplate, address))

proc objectName*(self: ClientObject): Option[string] =
  let obj_template = self.objectTemplate()
  if obj_template.isSome():
    return some(obj_template.get().objectName())

proc parent*(self: ClientObject): Option[ClientObject] =
  let address = self.readValueFromOffset(208, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(ClientObject, address))

proc children*(self: ClientObject): seq[ClientObject] =
  for address in self.readSharedVectorFromOffset(384):
    if address != 0:
      result.add(self.createDynamicMemoryObject(ClientObject, address))

proc clientZone*(self: ClientObject): Option[ClientZone] =
  let address = self.readValueFromOffset(304, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(ClientZone, address))

buildReadWriteBuilders(ClientObject)

buildValueReadWrite(globalIdFull, uint64, 72)
buildValueReadWrite(permId, uint64, 80)
buildXYZReadWrite(location, 168)
buildXYZReadWrite(orientation, 180)
buildValueReadWrite(scale, float32, 196)
buildValueReadWrite(templateIdFull, uint64, 196)
buildStringReadWrite(debugName, 104)
buildStringReadWrite(displayKey, 136)
buildValueReadWrite(zoneTagId, uint32, 344)
buildValueReadWrite(speedMultiplier, int16, 192)
buildValueReadWrite(mobileId, uint16, 194)
buildValueReadWrite(characterId, uint64, 440)

proc gameStats*(self: ClientObject): Option[GameStats] =
  let address = self.readValueFromOffset(544, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(GameStats, address))
