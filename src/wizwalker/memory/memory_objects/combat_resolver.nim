import options

include common_imports
import spell_effect

type CombatResolver* = ref object of PropertyClass

buildReadWriteBuilders(CombatResolver)

buildValueReadWrite(boolGlobalEffect, bool, 112)

proc globalEffect*(self: CombatResolver): Option[SpellEffect] =
  let address = self.readValueFromOffset(120, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(SpellEffect, address))

proc battlefieldEffects*(self: CombatResolver): seq[SpellEffect] =
  for address in self.readSharedVectorFromOffset(136):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))
