include common_imports

type
  GameStats* = ref object of PropertyClass
  CurrentGameStats* = ref object of GameStats

method readBaseAddress*(self: CurrentGameStats): ByteAddress =
  self.hook_handler.readCurrentPlayerStatHookBase()

buildReadWriteBuilders(GameStats)

buildValueReadWrite(baseHitpoints, int32, 80)
buildValueReadWrite(baseMana, int32, 84)
buildValueReadWrite(baseGoldPouch, int32, 88)
buildValueReadWrite(baseEventCurrency1Pouch, int32, 92)
buildValueReadWrite(baseEventCurrency2Pouch, int32, 96)
buildValueReadWrite(energyMax, int32, 100)
buildValueReadWrite(currentHitpoints, int32, 104)
buildValueReadWrite(currentGold, int32, 108)
buildValueReadWrite(currentEventCurrency1, int32, 112)
buildValueReadWrite(currentEventCurrency2, int32, 116)
buildValueReadWrite(currentMana, int32, 120)
buildValueReadWrite(currentArenaPoints, int32, 124)

proc spellChargeBase*(self: GameStats): seq[int32] =
  self.readDynamicVectorFromOffset(128, int32)

buildValueReadWrite(potionMax, float32, 152)
buildValueReadWrite(potionCharge, float32, 156)
buildValueReadWrite(bonusHitpoints, int32, 208)
buildValueReadWrite(bonusMana, int32, 212)
buildValueReadWrite(bonusEnergy, int32, 228)
buildValueReadWrite(criticalHitPercentAll, float32, 232)
buildValueReadWrite(blockPercentAll, float32, 236)
buildValueReadWrite(criticalHitRatingAll, float32, 240)
buildValueReadWrite(blockRatingAll, float32, 244)
buildValueReadWrite(referenceLevel, int32, 308)
buildValueReadWrite(highestCharacterLevelOnAccount, int32, 312)
buildValueReadWrite(petActChance, int32, 316)

buildVecRead(dmgBonusPercent, float32, 320)
buildVecRead(dmgBonusFlat, float32, 344)
buildVecRead(accBonusPercent, float32, 368)
buildVecRead(apBonusPercent, float32, 392)
buildVecRead(dmgReducePercent, float32, 416)
buildVecRead(dmgReduceFlat, float32, 440)
buildVecRead(accReducePercent, float32, 464)
buildVecRead(healBonusPercent, float32, 488)
buildVecRead(healIncBonusPercent, float32, 512)
buildVecRead(spellChargeBonus, int32, 560)

buildValueReadWrite(dmgBonusPercentAll, float32, 680)
buildValueReadWrite(dmgBonusFlatAll, float32, 684)
buildValueReadWrite(accBonusPercentAll, float32, 688)
buildValueReadWrite(apBonusPercentAll, float32, 692)
buildValueReadWrite(dmgReducePercentAll, float32, 696)
buildValueReadWrite(dmgReduceFlatAll, float32, 700)
buildValueReadWrite(accReducePercentAll, float32, 704)
buildValueReadWrite(healBonusPercentAll, float32, 708)
buildValueReadWrite(healIncBonusPercentAll, float32, 712)
buildValueReadWrite(spellChargeBonusAll, int32, 720)
buildValueReadWrite(powerPipBase, float32, 724)
buildValueReadWrite(powerPipBonusPercentAll, float32, 760)
buildValueReadWrite(xpPercentIncrease, float32, 768)

buildVecRead(criticalHitPercentBySchool, float32, 584)
buildVecRead(blockPercentBySchool, float32, 608)
buildVecRead(criticalHitRatingBySchool, float32, 632)
buildVecRead(blockRatingBySchool, float32, 656)

buildValueReadWrite(balanceMastery, int32, 792)
buildValueReadWrite(deathMastery, int32, 796)
buildValueReadWrite(fireMastery, int32, 800)
buildValueReadWrite(iceMastery, int32, 804)
buildValueReadWrite(lifeMastery, int32, 808)
buildValueReadWrite(mythMastery, int32, 812)
buildValueReadWrite(stormMastery, int32, 816)
buildValueReadWrite(maximumNumberOfIslands, int32, 820)
buildValueReadWrite(gardeningLevel, int32, 824)
buildValueReadWrite(gardeningXp, int32, 828)
buildValueReadWrite(invisibleToFriends, bool, 832)
buildValueReadWrite(showItemLock, bool, 833)
buildValueReadWrite(questFinderEnabled, bool, 834)
buildValueReadWrite(buddyListLimit, int32, 836)
buildValueReadWrite(dontAllowFriendFinderCodes, bool, 844)
buildValueReadWrite(stunResistancePercent, float32, 840)
buildValueReadWrite(shadowMagicUnlocked, bool, 852)
buildValueReadWrite(shadowPipMax, int32, 848)
buildValueReadWrite(fishingLevel, byte, 853)
buildValueReadWrite(fishingXp, int32, 856)

buildVecRead(fishingLuckBonusPercent, float32, 536)

buildValueReadWrite(fishingLuckBonusPercentAll, float32, 716)
buildValueReadWrite(subscriberBenefitFlags, uint32, 860)
buildValueReadWrite(elixirBenefitFlags, uint32, 864)
buildValueReadWrite(shadowPipBonusPercent, float32, 764)
buildValueReadWrite(wispBonusPercent, float32, 784)
buildValueReadWrite(pipConverstionRatingAll, float32, 272)
buildValueReadWrite(pipConversionPercentAll, float32, 604)

buildVecRead(pipConversionRatingPerSchool, float32, 248)
buildVecRead(pipConversionPercentPerSchool, float32, 280)

buildValueReadWrite(monsterMagicLevel, byte, 868)
buildValueReadWrite(monsterMagicXp, int32, 872)
buildValueReadWrite(playerChatChannelIsPulic, bool, 876)
buildValueReadWrite(extraInventorySpace, int32, 880)
buildValueReadWrite(rememberLastRealm, bool, 884)
buildValueReadWrite(newSpellbookLayoutWarning, bool, 885)
buildValueReadWrite(pipConversionBaseAllSchools, int32, 728)

buildVecRead(pipConversionBasePerSchool, int32, 736)

buildValueReadWrite(purchasedCustomEmotes1, uint32, 888)
buildValueReadWrite(purchasedCustomTeleportEffects1, uint32, 892)
buildValueReadWrite(equippedTeleportEffect, uint32, 896)
buildValueReadWrite(highestWorld1Id, uint32, 900)
buildValueReadWrite(highestWorld2Id, uint32, 904)
buildValueReadWrite(activeClassProjectList, uint32, 912)
buildValueReadWrite(disabledItemSlotIds, uint32, 928)
buildValueReadWrite(adventurePowerCooldownTime, uint32, 944)
buildValueReadWrite(purchasedCustomEmotes2, uint32, 948)
buildValueReadWrite(purchasedCustomTeleportEffects2, uint32, 952)
buildValueReadWrite(purchasedCustomEmotes3, uint32, 956)
buildValueReadWrite(purchasedCustomTeleportEffects3, uint32, 960)
buildValueReadWrite(shadowPipRating, float32, 964)
buildValueReadWrite(bonusShadowPipRating, float32, 968)
buildValueReadWrite(bonusShadowPipRateAccumulated, float32, 972)
buildValueReadWrite(shadowPipRateThreshold, float32, 976)
buildValueReadWrite(shadowPipRatePercentage, int32, 980)
buildValueReadWrite(friendlyPlayer, bool, 984)
buildValueReadWrite(emojiSkinTone, int32, 988)
buildValueReadWrite(showPvpOption, uint32, 992)
buildValueReadWrite(favoriteSlot, int32, 996)

proc maxHitpoints*(self: GameStats): int32 =
  discard

proc maxMana*(self: GameStats): int32 =
  discard
