import options

include common_imports
import behavior_template

type BehaviorInstance* = ref object of PropertyClass

proc behaviorTemplateNameId*(self: BehaviorInstance): uint32 =
  ## The id of this name
  self.readValueFromOffset(104, uint32)

proc writeBehaviorTemplateNameId*(self: BehaviorInstance, val: uint32) =
  ## Write a new name id
  self.writeValueToOffset(104, val)

proc behaviorTemplate*(self: BehaviorInstance): Option[BehaviorTemplate] =
  ## Associated behavior template
  let address = self.readValueFromOffset(0x58, ByteAddress)

  if address == 0:
    return none(BehaviorTemplate)

  some(BehaviorTemplate().init(memory_handler=self.memory_handler, hook_handler=self.hook_handler, base_address=some(address)))
