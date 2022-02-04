import common_imports

type BuddyEntry* = ref object of PropertyClass

proc nameVector*(self: BuddyEntry): seq[byte] =
  ## Vector of name related bytes (gender, first, middle, last)
  self.readVectorFromOffset(72, 4, byte)

proc isFemale*(self: BuddyEntry): bool =
  ## Whether or not this friend is female. 
  ## `This is an undocumented property and may break`
  self.nameVector()[0] == 128

proc name*(self: BuddyEntry): string =
  const langcode_prefix = "CharacterNames_"
  let
    name_vec = self.nameVector()
    first_mid = if name_vec[0] == 128: "First_Girl_" else: "First_Boy_"

  # TODO: FINISH THIS
