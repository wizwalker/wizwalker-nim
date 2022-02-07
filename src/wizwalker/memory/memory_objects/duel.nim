import options

include common_imports
import combat_resolver
import combat_participant
import wiz_enums

type
  Duel* = ref object of PropertyClass
  CurrentDuel* = ref object of Duel

method readBaseAddress*(self: CurrentDuel): ByteAddress =
  self.hook_handler.readCurrentPlayerHookBase()

proc participantList(self: Duel): seq[CombatParticipant] =
  for address in self.readSharedVectorFromOffset(80):
    result.add(self.createDynamicMemoryObject(CombatParticipant, address))

buildReadWriteBuilders(Duel)

buildValueReadWrite(dynamicTurn, uint32, 120)
buildValueReadWrite(dynamicTurnSubcircles, uint32, 124)
buildValueReadWrite(dynamicTurnCounter, int32, 128)
buildValueReadWrite(duelIdFull, uint64, 72)
buildValueReadWrite(planningTimer, float32, 144)
buildXYZReadWrite(position, 148)
buildValueReadWrite(yaw, float32, 160)
buildValueReadWrite(disableTimer, bool, 178)
buildValueReadWrite(tutorialMode, bool, 179)
buildValueReadWrite(firstTeamToAct, int32, 180)

proc combatResolver(self: Duel): Option[CombatResolver] =
  let address = self.readValueFromOffset(136, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(CombatResolver, address))

buildValueReadWrite(pvp, bool, 176)
buildValueReadWrite(battleground, bool, 176)
buildValueReadWrite(roundNum, int32, 188)
buildValueReadWrite(executionPhaseTimer, float32, 196)
buildEnumReadWrite(duelPhase, DuelPhase, 192)
buildEnumReadWrite(initiativeSwitchMode, SigilInitiativeSwitchMode, 376)
buildValueReadWrite(initiativeSwitchRounds, int32, 380)
buildValueReadWrite(altTurnCounter, int32, 448)
buildValueReadWrite(originalFirstTeamToAct, int32, 184)
buildEnumReadWrite(executionOrder, DuelExecutionOrder, 488)
buildValueReadWrite(noHenchmen, bool, 492)
buildValueReadWrite(spellTruncation, bool, 493)
buildValueReadWrite(shadowThresholdFactor, float32, 500)
buildValueReadWrite(shadowPipRatingFactor, float32, 504)
buildValueReadWrite(defaultShadowPipRating, float32, 508)
buildValueReadWrite(shadowPipThresholdTeam0, float32, 512)
buildValueReadWrite(shadowPipThresholdTeam1, float32, 516)
buildValueReadWrite(scalarDamage, float32, 544)
buildValueReadWrite(scalarResist, float32, 548)
buildValueReadWrite(scalarPierce, float32, 552)
buildValueReadWrite(damageLimit, float32, 556)
buildValueReadWrite(d_k0, float32, 560) # what does this mean
buildValueReadWrite(d_n0, float32, 564) # what does this mean
buildValueReadWrite(resistLimit, float32, 568)
buildValueReadWrite(r_k0, float32, 572) # what does this mean
buildValueReadWrite(r_n0, float32, 576) # what does this mean
buildValueReadWrite(fullPartyGroup, bool, 580)
buildValueReadWrite(matchTimer, float32, 600)
buildValueReadWrite(bonusTime, float32, 604)
buildValueReadWrite(passPenalty, int32, 608)
buildValueReadWrite(yellowTime, int32, 612)
buildValueReadWrite(redTime, int32, 616)
buildValueReadWrite(isPlayerTimedDuel, bool, 581)
