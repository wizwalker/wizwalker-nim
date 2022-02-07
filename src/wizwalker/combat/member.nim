import std/options

import ../memory/memory_objects/window
import ../memory/memory_objects/client_object
import ../memory/memory_objects/combat_participant
import ../memory/memory_objects/game_stats

type CombatMember* = ref object of RootObj
  combatant_control*: Window
  client_obj*: ClientObject

  stored_combat_participant*: CombatParticipant

proc initCombatMember(combatant_control: Window, client_obj: ClientObject): CombatMember =
  new(result)
  result.combatant_control = combatant_control
  result.client_obj = client_obj

method getParticipant*(self: CombatMember): CombatParticipant =
  if self.stored_combat_participant == nil:
    self.stored_combat_participant = self.combatant_control.maybeCombatParticipant()
  result = self.stored_combat_participant

method getStats*(self: CombatMember): GameStats =
  let stats = self.getParticipant().gameStats()
  if stats.isNone():
    raise newException(ValueError, "Participant without stats")
  stats.unsafeGet()

method getHealthTextWindow*(self: CombatMember): Window =
  # TODO: Maybe wrap in a waitFor thing
  let possible = self.combatant_control.getWindowsWithName("Health")
  if possible.len() > 0:
    return possible[0]
  raise newException(ValueError, "Couldn't find health child")

method getNameTextWindow*(self: CombatMember): Window = 
  let possible = self.combatant_control.getWindowsWithName("Name")
  if possible.len() > 0:
    return possible[0]
  raise newException(ValueError, "Couldn't find name child")

method isDead*(self: CombatMember): bool =
  self.getStats().currentHitpoints() == 0

method ownerId*(self: CombatMember): uint64 =
  self.getParticipant().ownerIdFull()

method isClient*(self: CombatMember): bool =
  self.ownerId() == self.client_obj.globalIdFull()

method isPlayer*(self: CombatMember): bool =
  self.getParticipant().isPlayer()

method isMinion*(self: CombatMember): bool =
  self.getParticipant().isMinion()

method isMonster*(self: CombatMember): bool =
  not self.isPlayer() and not self.isMinion()

method isBoss*(self: CombatMember): bool =
  self.getParticipant().bossMob()

method isStunned*(self: CombatMember): bool =
  self.getParticipant().stunned != 0

method name*(self: CombatMember): string =
  self.getNameTextWindow().text()

method templateId*(self: CombatMember): uint64 =
  self.getParticipant().templateIdFull()

method normalPips*(self: CombatMember): byte =
  self.getParticipant().numPips()

method powerPips*(self: CombatMember): byte =
  self.getParticipant().numPowerPips()

method shadowPips*(self: CombatMember): byte =
  self.getParticipant().numShadowPips()

method health*(self: CombatMember): int32 =
  self.getParticipant().playerHealth()

method maxHealth*(self: CombatMember): int32 =
  self.getStats().maxHitpoints()

method mana*(self: CombatMember): int32 =
  self.getStats().currentMana()

method maxMana*(self: CombatMember): int32 =
  self.getStats().maxMana()

method level*(self: CombatMember): int32 =
  self.getStats().referenceLevel()
