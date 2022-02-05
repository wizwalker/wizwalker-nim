include common_imports
import wiz_enums
import ../../file_handlers/filesystem

type BuddyEntry* = ref object of PropertyClass

proc nameVector*(self: BuddyEntry): seq[byte] =
  ## Vector of name related bytes (gender, first, middle, last).
  ## This is actually .name in the type definitions
  self.readVectorFromOffset(72, 4, byte)

proc isFemale*(self: BuddyEntry): bool =
  ## Whether or not this friend is female. 
  ## `This is an undocumented property and may break`
  self.nameVector()[0] == 128

proc name*(self: BuddyEntry): string =
  ## The string representation of this buddy's name
  const lang_file = "CharacterNames"
  let
    name_vec = self.nameVector()
    first_mid = (if name_vec[0] == 128: "First_Girl_" else: "First_Boy_") & name_vec[1].char

  result = global_wiz_file_system.getLangValue(lang_file, first_mid)

  if name_vec[2] != 0:
    # Handle KI's typo
    if name_vec[2] < 49:
      result.add(" " & global_wiz_file_system.getLangValue(lang_file, "Middle_" & $(name_vec[2] - 1)))
    else:
      result.add(" " & global_wiz_file_system.getLangValue(lang_file, "Middle_" & $(name_vec[2])))
  
  if name_vec[3] != 0:
    result.add(" " & global_wiz_file_system.getLangValue(lang_file, "Last_" & $(name_vec[3] - 1)))

proc characterId*(self: BuddyEntry): uint64 =
  # CharID of this buddy
  self.readValueFromOffset(104, uint64)

proc gameObjectId*(self: BuddyEntry): uint64 =
  ## GID of this buddy
  self.readValueFromOffset(120, uint64)

proc status*(self: BuddyEntry): PlayerStatus =
  ## Status of this buddy
  self.readValueFromOffset(112, int32).PlayerStatus
