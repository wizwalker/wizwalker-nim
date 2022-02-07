import options

include common_imports
import spell_template
import spell_effect
import wiz_enums

type
  RankStruct* = object
    regular_rank: byte
    shadow_rank: byte

  Spell* = ref object of PropertyClass
  GraphicalSpell* = ref object of Spell
  
  Hand* = ref object of PropertyClass

buildReadWriteBuilders(Spell)

buildValueReadWrite(templateId, uint32, 128)

proc spellTemplate*(self: Spell): Option[SpellTemplate] =
  let address = self.readValueFromOffset(120, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(SpellTemplate, address))

buildValueReadWrite(enchantment, uint32, 80)
buildValueReadWrite(rank, RankStruct, 176+72) # Does this work? Maybe.
buildValueReadWrite(regularAdjust, int32, 256)
buildValueReadWrite(shadowAdjust, int32, 260)
buildValueReadWrite(magicSchoolId, uint32, 136)
buildValueReadWrite(accuracy, byte, 132)

proc spellEffects*(self: Spell): seq[SpellEffect] =
  for address in self.readSharedVectorFromOffset(88):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))

buildValueReadWrite(treasureCard, bool, 265)
buildValueReadWrite(battleCard, bool, 266)
buildValueReadWrite(itemCard, bool, 267)
buildValueReadWrite(sideBoard, bool, 268)
buildValueReadWrite(spellId, uint32, 272)
buildValueReadWrite(leavesPlayWhenCastOverride, bool, 284)
buildValueReadWrite(cloaked, bool, 264)
buildValueReadWrite(enchantmentSpellIsItemCard, bool, 76)
buildValueReadWrite(premutationSpellId, uint32, 112)
buildValueReadWrite(enchantedThisCombat, bool, 77)
buildValueReadWrite(delayEnchantment, bool, 321)
buildValueReadWrite(pve, bool, 328)
buildEnumReadWrite(delayEnchantmentOrder, DelayOrder, 72)
buildValueReadWrite(roundAddedTc, int32, 324)

proc spellList*(self: Hand): seq[Spell] =
  for address in self.readSharedLinkedListFromOffset(72):
    result.add(self.createDynamicMemoryObject(Spell, address))
