import options

include common_imports

type CombatAction* = ref object of MemoryObject

buildReadWriteBuilders(CombatAction)

buildValueReadWrite(spellCaster, int32, 72)

# TODO: Complete

