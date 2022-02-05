import options

include common_imports
import spell

type CombatAction* = ref object of MemoryObject

buildReadWriteBuilders(CombatAction)

buildValueReadWrite(spellCaster, int32, 72)

proc spell*(self: CombatAction): Option[Spell] =
  let address = self.readValueFromOffset(96, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(Spell, address))

buildValueReadWrite(spellHits, char, 112)
buildValueReadWrite(effectChosen, uint32, 212)
buildValueReadWrite(interrupt, bool, 113)
buildValueReadWrite(showCast, bool, 115)
buildValueReadWrite(criticalHitRoll, byte, 116)
buildValueReadWrite(stunResistRoll, byte, 117)
buildValueReadWrite(blocksCalculated, bool, 152)
buildStringReadWrite(serializedBlocks, 160)
buildStringReadWrite(stringKeyMessage, 216)
buildStringReadWrite(soundFileName, 248)
buildValueReadWrite(durationModifier, float32, 280)
buildStringReadWrite(serializedTargetsAffected, 288)
buildValueReadWrite(targetSubcircleList, int32, 80)
buildValueReadWrite(pipConversionRoll, int32, 120)
buildValueReadWrite(randomSpellEffectPerTargetRolls, int32, 128)
buildValueReadWrite(handledRandomSpellPerTarget, bool, 124)
buildValueReadWrite(confusedTarget, bool, 208)
buildValueReadWrite(forceSpell, bool, 336)
buildValueReadWrite(afterDied, bool, 209)
buildValueReadWrite(delayed, bool, 337)
buildValueReadWrite(delayedEnchantment, bool, 338)
buildValueReadWrite(petCast, bool, 339)
buildValueReadWrite(petCasted, bool, 340)
buildValueReadWrite(petCastTarget, int32, 344)
