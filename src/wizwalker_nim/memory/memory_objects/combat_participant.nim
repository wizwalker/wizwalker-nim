import options

include common_imports
import spell
import spell_effect
import play_deck
import game_stats

type CombatParticipant* = ref object of PropertyClass

buildReadWriteBuilders(CombatParticipant)

buildValueReadWrite(ownerIdFull, uint64, 112)
buildValueReadWrite(templateIdFull, uint64, 120)
buildValueReadWrite(isPlayer, bool, 128)
buildValueReadWrite(zoneIdFull, uint64, 136)
buildValueReadWrite(teamId, int32, 144)
buildValueReadWrite(primaryMagicSchoolId, int32, 148)
buildValueReadWrite(numPips, byte, 152)
buildValueReadWrite(numPowerPips, byte, 153)
buildValueReadWrite(numShadowPips, byte, 154)
buildValueReadWrite(pipsSuspended, bool, 176)
buildValueReadWrite(stunned, int32, 180)
buildValueReadWrite(mindcontrolled, int32, 208)
buildValueReadWrite(originalTeam, int32, 216)
buildValueReadWrite(auraTurnLength, int32, 228)
buildValueReadWrite(clue, int32, 220)
buildValueReadWrite(roundsDead, int32, 224)
buildValueReadWrite(polymorphTurnLength, int32, 232)
buildValueReadWrite(playerHealth, int32, 236)
buildValueReadWrite(maxPlayerHealth, int32, 240)
buildValueReadWrite(hideCurrentHp, bool, 244)
buildValueReadWrite(maxHandSize, int32, 248)

proc hand*(self: CombatParticipant): Option[Hand] =
  let address = self.readValueFromOffset(256, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(Hand, address))

proc savedHand*(self: CombatParticipant): Option[Hand] =
  let address = self.readValueFromOffset(264, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(Hand, address))

proc playDeck*(self: CombatParticipant): Option[PlayDeck] =
  let address = self.readValueFromOffset(272, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(PlayDeck, address))

proc savedPlayDeck*(self: CombatParticipant): Option[PlayDeck] =
  let address = self.readValueFromOffset(280, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(PlayDeck, address))

proc gameStats*(self: CombatParticipant): Option[GameStats] =
  let address = self.readValueFromOffset(312, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(GameStats, address))

proc savedGameStats*(self: CombatParticipant): Option[GameStats] =
  let address = self.readValueFromOffset(288, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(GameStats, address))

buildValueReadWrite(savedPrimaryMagicSchoolId, int32, 304)
buildValueReadWrite(rotation, float32, 332)
buildValueReadWrite(radius, float32, 336)
buildValueReadWrite(subcircle, int32, 340)
buildValueReadWrite(pvp, bool, 344)
buildValueReadWrite(accuracyBonus, float32, 388)
buildValueReadWrite(minionSubCircle, int32, 392)
buildValueReadWrite(isMinion, bool, 396)

proc hangingEffects*(self: CombatParticipant): seq[SpellEffect] =
  for address in self.readLinkedListFromOffset(408):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))

proc publicHangingEffects*(self: CombatParticipant): seq[SpellEffect] =
  for address in self.readLinkedListFromOffset(424):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))

proc auraEffects*(self: CombatParticipant): seq[SpellEffect] =
  for address in self.readLinkedListFromOffset(440):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))

proc shadowSpellEffects*(self: CombatParticipant): seq[SpellEffect] =
  for address in self.readLinkedListFromOffset(472):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))

proc deathActivatedEffects*(self: CombatParticipant): seq[SpellEffect] =
  for address in self.readSharedLinkedListFromOffset(504):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))

proc delayCastEffects*(self: CombatParticipant): seq[SpellEffect] =
  for address in self.readLinkedListFromOffset(520):
    result.add(self.createDynamicMemoryObject(SpellEffect, address))

