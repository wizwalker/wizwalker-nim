import std/options

import ../memory/memory_objects/window
import ../memory/memory_objects/client_object
import ../memory/memory_objects/combat_participant
import ../memory/memory_objects/game_stats

type CombatMember* = ref object
  combatant_control*: Window
  client_obj*: ClientObject

  stored_combat_participant*: CombatParticipant

proc initCombatMember*(combatant_control: Window, client_obj: ClientObject): CombatMember =
  new(result)
  result.combatant_control = combatant_control
  result.client_obj = client_obj

proc getParticipant*(self: CombatMember): CombatParticipant =
  if self.stored_combat_participant == nil:
    self.stored_combat_participant = self.combatant_control.maybeCombatParticipant()
  result = self.stored_combat_participant

proc getStats*(self: CombatMember): GameStats =
  let stats = self.getParticipant().gameStats()
  if stats.isNone():
    raise newException(ValueError, "Participant without stats")
  stats.unsafeGet()

proc getHealthTextWindow*(self: CombatMember): Window =
  # TODO: Maybe wrap in a waitFor thing
  let possible = self.combatant_control.getWindowsWithName("Health")
  if possible.len() > 0:
    return possible[0]
  raise newException(ValueError, "Couldn't find health child")

proc getNameTextWindow*(self: CombatMember): Window = 
  let possible = self.combatant_control.getWindowsWithName("Name")
  if possible.len() > 0:
    return possible[0]
  raise newException(ValueError, "Couldn't find name child")

proc isDead*(self: CombatMember): bool =
  self.getStats().currentHitpoints() == 0

proc ownerId*(self: CombatMember): uint64 =
  self.getParticipant().ownerIdFull()

proc isClient*(self: CombatMember): bool =
  self.ownerId() == self.client_obj.globalIdFull()

proc isPlayer*(self: CombatMember): bool =
  self.getParticipant().isPlayer()

proc isMinion*(self: CombatMember): bool =
  self.getParticipant().isMinion()

proc isMonster*(self: CombatMember): bool =
  not self.isPlayer() and not self.isMinion()

proc isBoss*(self: CombatMember): bool =
  self.getParticipant().bossMob()

proc isStunned*(self: CombatMember): bool =
  self.getParticipant().stunned != 0

proc name*(self: CombatMember): string =
  self.getNameTextWindow().text()

proc templateId*(self: CombatMember): uint64 =
  self.getParticipant().templateIdFull()

proc normalPips*(self: CombatMember): byte =
  self.getParticipant().numPips()

proc powerPips*(self: CombatMember): byte =
  self.getParticipant().numPowerPips()

proc shadowPips*(self: CombatMember): byte =
  self.getParticipant().numShadowPips()

proc health*(self: CombatMember): int32 =
  self.getParticipant().playerHealth()

proc maxHealth*(self: CombatMember): int32 =
  self.getStats().maxHitpoints()

proc mana*(self: CombatMember): int32 =
  self.getStats().currentMana()

proc maxMana*(self: CombatMember): int32 =
  self.getStats().maxMana()

proc level*(self: CombatMember): int32 =
  self.getStats().referenceLevel()
