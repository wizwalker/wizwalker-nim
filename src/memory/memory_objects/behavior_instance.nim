import options

include common_imports
import behavior_template

type BehaviorInstance* = ref object of PropertyClass

buildReadWriteBuilders(BehaviorInstance)

buildValueReadWrite(behaviorTemplateId, uint32, 104)

proc behaviorTemplate*(self: BehaviorInstance): Option[BehaviorTemplate] =
  ## Associated behavior template
  let address = self.readValueFromOffset(0x58, ByteAddress)

  if address == 0:
    return none(BehaviorTemplate)
  
  some(self.createDynamicMemoryObject(BehaviorTemplate, address))
