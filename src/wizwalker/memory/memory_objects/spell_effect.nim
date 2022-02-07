import strformat

include common_imports
import wiz_enums

type SpellEffect* = ref object of PropertyClass

buildReadWriteBuilders(SpellEffect)

buildEnumReadWrite(effectType, SpellEffects, 72)
buildEnumReadWrite(disposition, HangingDisposition, 80)
buildEnumReadWrite(effectTarget, EffectTarget, 140)

buildValueReadWrite(effectParam, int32, 76)
buildStringReadWrite(stringDamageType, 88)
buildValueReadWrite(damageType, uint32, 84)
buildValueReadWrite(pipNum, int32, 128)
buildValueReadWrite(actNum, int32, 132)
buildValueReadWrite(numRounds, int32, 144)
buildValueReadWrite(paramPerRound, int32, 148)
buildValueReadWrite(healModifier, float32, 152)
buildValueReadWrite(spellTemplateId, uint32, 120)
buildValueReadWrite(enchantmentSpellTemplateId, uint32, 124)
buildValueReadWrite(act, bool, 136)
buildValueReadWrite(cloaked, bool, 157)
buildValueReadWrite(armorPiercingParam, int32, 160)
buildValueReadWrite(chancePerTarget, int32, 164)
buildValueReadWrite(protected, bool, 168)
buildValueReadWrite(converted, bool, 169)
buildValueReadWrite(rank, int32, 208)

proc maybeEffectList*(self: SpellEffect, check_type: bool = false): seq[SpellEffect] =
  if check_type:
    let type_name = self.readTypeName()
    if not ["RandomSpellEffect", "RandomPerTargetSpellEffect"].contains(type_name):
      raise newException(ValueError, &"This object is a {type_name} not a RandomSpellEffect/RandomPerTargetSpellEffect.")

  for address in self.readSharedLinkedListFromOffset(224):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))
