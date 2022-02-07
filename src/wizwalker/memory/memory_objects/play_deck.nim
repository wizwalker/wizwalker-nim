include common_imports

type
  PlayDeck* = ref object of PropertyClass
  PlaySpellData* = ref object of PropertyClass

proc deckToSave*(self: PlayDeck): seq[PlaySpellData] =
  for address in self.readSharedVectorFromOffset(72):
    result.add(self.createDynamicMemoryObject(PlaySpellData, address))

proc graveyardToSave*(self: PlayDeck): seq[PlaySpellData] =
  for address in self.readSharedVectorFromOffset(96):
    result.add(self.createDynamicMemoryObject(PlaySpellData, address))

proc templateId(self: PlaySpellData): uint32 =
  self.readValueFromOffset(72, uint32)

proc enchantment(self: PlaySpellData): uint32 =
  self.readValueFromOffset(76, uint32)
