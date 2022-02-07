import asyncdispatch
import options

import ../memory/memory_objects/window
import ../memory/memory_objects/spell
import ../memory/memory_objects/spell_effect
import ../memory/memory_objects/spell_template
import ../mouse_handler
import ../file_handlers/filesystem
import member

type
  CombatCard* = ref object
    mouse_handler*: MouseHandler
    card_getter*: proc (): seq[CombatCard] # Avoid cyclic dependency
    spell_window: Window

    stored_graphical_spell: GraphicalSpell

proc initCombatCard(mouse_handler: MouseHandler, card_getter: proc (): seq[CombatCard], spell_window: Window): CombatCard =
  new(result)
  result.mouse_handler = mouse_handler
  result.card_getter = card_getter
  result.spell_window = spell_window

proc castSpell*(self: CombatCard, target: Option[CombatCard] or Option[CombatMember] = none(CombatCard), sleep_time: float = 0.2) {.async.} =
  if target.isNone():
    await self.mouse_handler.clickWindow(self.spell_window)
  elif target is Option[CombatCard]:
    let old_len = self.card_getter().len()
    await self.mouse_handler.clickWindow(self.spell_window)
    await sleepAsync((sleep_time * 1000).int)
    await self.mouse_handler.setMousePositionToWindow(target.unsafeGet().spell_window)
    await sleepAsync((sleep_time * 1000).int)
    await self.mouse_handler.clickWindow(target.unsafeGet().spell_window)
    while self.card_getter().len() == old_len:
      await sleepAsync(50)
    if sleep_time > 0.0:
      await sleepAsync((sleep_time * 1000).int)
  elif target is Option[CombatMember]:
    await self.mouse_handler.clickWindow(self.spell_window)
    if sleep_time > 0.0:
      await self.sleepAsync((sleep_time * 1000).int)
    await self.mouse_handler.clickWindow(target.unsafeGet().getHealthTextWindow())

proc discardSpell*(self: CombatCard, sleep_time: float = 0.2) {.async.} =
  let old_len = self.card_getter().len()
  await self.mouse_handler.clickWindow(self.spell_window, right_click=true)
  while old_len == self.card_getter().len():
    await sleepAsync(50)
  if sleep_time > 0.0:
    await sleepAsync((sleep_time * 1000).int)

proc getGraphicalSpell*(self: CombatCard): GraphicalSpell =
  ## Gets a cached graphical spell. Might technically be unsafe
  if self.stored_graphical_spell == nil:
    let gs = self.spell_window.maybeGraphicalSpell()
    if gs.isNone():
      raise newException(ValueError, "No graphical spell found")
    self.stored_graphical_spell = gs.unsafeGet()
  result = self.stored_graphical_spell

proc spellEffects*(self: CombatCard): seq[SpellEffect] =
  self.getGraphicalSpell().spellEffects()

proc getSpellTemplate*(self: CombatCard): SpellTemplate =
  let temp = self.getGraphicalSpell().spellTemplate()
  if temp.isNone():
    raise newException(ValueError, "Could not get a spell template")
  temp.unsafeGet()

proc name*(self: CombatCard): string =
  self.getSpellTemplate().name()

proc displayNameKey*(self: CombatCard): string =
  self.getSpellTemplate().displayName()

proc displayName*(self: CombatCard): string =
  global_wiz_file_system.getLangValueByCode(self.displayNameKey())

proc typeName*(self: CombatCard): string =
  self.getSpellTemplate().typeName()

proc templateId*(self: CombatCard): uint32 =
  self.getGraphicalSpell().templateId()

proc spellId*(self: CombatCard): uint32 =
  self.getGraphicalSpell.spellId()

proc accuracy*(self: CombatCard): byte =
  self.getGraphicalSpell().accuracy()

proc isCastable*(self: CombatCard): bool =
  not self.spell_window.maybeSpellGrayed()

proc isEnchanted*(self: CombatCard): bool =
  self.getGraphicalSpell().enchantment() != 0

proc isTreasureCard*(self: CombatCard): bool =
  self.getGraphicalSpell().treasureCard()

proc isItemCard*(self: CombatCard): bool =
  self.getGraphicalSpell().itemCard()

proc isSideBoard*(self: CombatCard): bool =
  self.getGraphicalSpell().sideBoard()

proc isCloaked*(self: CombatCard): bool =
  self.getGraphicalSpell().cloaked()

proc isEnchantedFromItemCard*(self: CombatCard): bool =
  self.getGraphicalSpell().enchantmentSpellIsItemCard()

proc isPveOnly*(self: CombatCard): bool =
  self.getGraphicalSpell().pve()
