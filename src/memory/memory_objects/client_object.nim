import options

include common_imports
import behavior_instance
import game_object_template

type
  ClientObject* = ref object of PropertyClass
  CurrentClientObject* = ref object of ClientObject

method readBaseAddress*(self: ClientObject): ByteAddress =
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
  let address = self.readValueFromOffset(208, ByteAddress)
  for address in self.readSharedVectorFromOffset(384):
    if address != 0:
      result.add(self.createDynamicMemoryObject(ClientObject, address))

# TODO: Finish
