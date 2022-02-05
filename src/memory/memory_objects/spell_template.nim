include common_imports
import spell_effect
import wiz_enums

type SpellTemplate* = ref object of PropertyClass

buildReadWriteBuilders(SpellTemplate)

buildStringReadWrite(name, 96)
buildStringReadWrite(description, 168)
buildStringReadWrite(displayName, 136)
buildStringReadWrite(spellBase, 208)

proc effects*(self: SpellTemplate): seq[SpellEffect] =
  for address in self.readSharedVectorFromOffset(240):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))

buildStringReadWrite(magicSchoolName, 272)
buildStringReadWrite(typeName, 312)
buildValueReadWrite(trainingCost, int32, 344)
buildValueReadWrite(accuracy, int32, 348)
buildValueReadWrite(baseCost, int32, 200)
buildValueReadWrite(creditsCost, int32, 204)
buildStringReadWrite(boosterPackIcon, 456)
buildValueReadWrite(validTargetSpell, uint32, 352)
buildValueReadWrite(pvp, bool, 368)
buildValueReadWrite(pve, bool, 369)
buildValueReadWrite(noPvpEnchant, bool, 370)
buildValueReadWrite(noPveEnchant, bool, 371)
buildValueReadWrite(battlegroundsOnly, bool, 372)
buildValueReadWrite(treasure, bool, 373)
buildValueReadWrite(noDiscard, bool, 374)
buildValueReadWrite(leavesPlayWhenCast, bool, 492)
buildValueReadWrite(imageIndex, int32, 376)
buildStringReadWrite(imageName, 384)
buildValueReadWrite(cloaked, bool, 449)
buildValueReadWrite(casterInvisible, bool, 450)
buildStringReadWrite(adjectives, 536)

buildEnumReadWrite(spellSourceType, SpellSourceType, 488)
buildStringReadWrite(cloakedName, 496)
buildStringReadWrite(descriptionTrainer, 576)
buildStringReadWrite(descriptionCombatHud, 608)
buildValueReadWrite(displayIndex, int32, 640)
buildValueReadWrite(hiddenFromEffectsWindow, bool, 644)
buildValueReadWrite(ignoreCharms, bool, 645)
buildValueReadWrite(alwaysFizzle, bool, 646)
buildStringReadWrite(spellCategory, 648)
buildValueReadWrite(showPolymorphedName, bool, 680)
buildValueReadWrite(skipTruncation, bool, 681)
buildValueReadWrite(maxCopies, uint32, 684)
buildValueReadWrite(levelRestriction, int32, 688)
buildValueReadWrite(delayEnchantment, bool, 692)
buildEnumReadWrite(delayEnchantmentOrder, DelayOrder, 696)
buildStringReadWrite(previousSpellName, 704)
buildStringReadWrite(cardFront, 416)
buildValueReadWrite(useGloss, bool, 448)
buildValueReadWrite(ignoreDispel, bool, 736)
buildValueReadWrite(backrowFriendly, bool, 737)
