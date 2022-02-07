import std/asyncdispatch
import std/algorithm
import std/[strformat, strutils]
import std/sequtils

import ../memory/memory_objects/duel
import ../memory/memory_objects/spell_effect
import ../memory/memory_objects/window
import ../memory/memory_objects/wiz_enums
import ../memory/memory_objects/client_object
import ../memory/memory_objects/combat_participant
import ../memory/memory_object
import ../mouse_handler
import ../utils
import member
import card

type
  CombatHandler* = ref object of RootObj
    mouse_handler: MouseHandler
    duel_obj: Duel
    root_window: Window
    client_obj: ClientObject

proc initCombatHandler*(mouse_handler: MouseHandler, duel: Duel, root_window: Window, client_obj: ClientObject): CombatHandler =
  new(result)
  result.mouse_handler = mouse_handler
  result.duel_obj = duel
  result.root_window = root_window
  result.client_obj = client_obj

method handleRound*(self: CombatHandler) {.base, async.} =
  raise newException(AssertionDefect, "handleRound is unimplemented")

method inCombat*(self: CombatHandler): bool {.base.} = 
  self.duel_obj.duelPhase() != DuelPhase.ended

method waitForPlanningPhase*(self: CombatHandler, sleep_time: float = 0.1) {.base, async.} =
  waitOnValue(self.duel_obj.duelPhase(), DuelPhase.planning, sleep_time)

method roundNumber*(self: CombatHandler): int32 {.base.} =
  self.duel_obj.roundNum()

method waitUntilNextRound*(self: CombatHandler, cur_round: int, sleep_time: float = 0.1) {.base, async.} =
  while self.inCombat():
    let new_round_num = self.roundNumber()
    if new_round_num > cur_round:
      return
    await sleepAsync((sleep_time * 1000).int)

method handleCombat*(self: CombatHandler) {.base, async.} = 
  while self.inCombat():
    await self.waitForPlanningPhase()
    let round_num = self.roundNumber()
    await self.handleRound()
    await self.waitUntilNextRound(round_num)

method getCardWindows*(self: CombatHandler): seq[Window] {.base.} = 
  ## WW-py cached these. Not gonna do that for now
  self.root_window.getWindowsWithType("SpellCheckBox")

proc getCards*(self: CombatHandler): seq[CombatCard] =
  if self == nil:
    return
  for checkbox in self.getCardWindows():
    if WindowFlag.visible in checkbox.flags():
      let card = initCombatCard(
        self.mouse_handler,
        (proc (): seq[CombatCard] =
          self.getCards()
        ),
        checkbox
      )
      result.add(card)

proc getCardsWithPredicate*(self: CombatHandler, pred: proc (card: CombatCard): bool): seq[CombatCard] =
  for card in self.getCards():
    if pred(card):
      result.add(card)

method getCardNamed*(self: CombatHandler, name: string): CombatCard {.base.} =
  proc pred(card: CombatCard): bool =
    name.toLowerAscii() == card.displayName().toLowerAscii()

  for c in self.getCardsWithPredicate(pred):
    return c

  raise newException(ValueError, &"Couldn't find a card named {name}")

proc getDamagingAoes*(self: CombatHandler, check_enchanted: bool = false): seq[CombatCard] =
  proc pred(card: CombatCard): bool =
    if check_enchanted and not card.isEnchanted():
      return false
    if not check_enchanted and card.isEnchanted():
      return false
    
    if card.typeName() != "AOE":
      return false

    for effect in card.spellEffects():
      let effect_type = effect.readTypeName().toLowerAscii()

      if ["variable", "random"].any(
        (proc (s: string): bool =
          effect_type.contains(s)
        )
      ):
        for sub_effect in effect.maybeEffectList():
          let target = sub_effect.effectTarget()
          if target in [EffectTarget.enemy_team, EffectTarget.enemy_team_all_at_once]:
            return true

      else:
        let target = effect.effectTarget()
        if target in [EffectTarget.enemy_team, EffectTarget.enemy_team_all_at_once]:
          return true
  self.getCardsWithPredicate(pred)

method getDamageEnchants*(self: CombatHandler, sort_by_damage: bool = false): seq[CombatCard] {.base.} = 
  proc pred(card: CombatCard): bool =
    if card.typeName() != "Enchantment":
      return false

    for effect in card.spellEffects():
      if effect.effectType() == SpellEffects.modify_card_damage:
        return true
  result = self.getCardsWithPredicate(pred)

  if sort_by_damage:
    result.sort(
      (proc (x, y: CombatCard): int =
        x.spellEffects()[0].effectParam().cmp(y.spellEffects()[0].effectParam())
      ),
      SortOrder.Descending
    )

iterator getMembers*(self: CombatHandler): CombatMember = 
  let wins = self.root_window.getWindowsWithName("CombatantControl")

  for win in wins:
    yield initCombatMember(win, self.client_obj)

iterator getMembersWithPredicate*(self: CombatHandler, pred: proc (mem: CombatMember): bool): CombatMember =
  for mem in self.getMembers():
    if pred(mem):
      yield mem

proc getClientMember*(self: CombatHandler): CombatMember =
  for member in self.getMembers():
    if member.isClient():
      return member
  raise newException(ValueError, "Could not find the client's member")

proc getAllMonsterMembers*(self: CombatHandler): seq[CombatMember] =
  for member in self.getMembers():
    if member.isMonster():
      result.add(member)

proc getAllPlayerMembers*(self: CombatHandler): seq[CombatMember] =
  for member in self.getMembers():
    if member.isPlayer():
      result.add(member)

proc getMembersOnTeam*(self: CombatHandler, same_as_client: bool = true): seq[CombatMember] =
  let
    client_member = self.getClientMember()
    part = client_member.getParticipant()
    client_team_id = part.teamId()

  proc pred(mem: CombatMember): bool =
    let
      member_part = mem.getParticipant()
      member_team_id = member_part.teamId()
    (member_team_id == client_team_id and same_as_client) or
    (member_team_id != client_team_id and not same_as_client)
  for p in self.getMembersWithPredicate(pred):
    result.add(p)
