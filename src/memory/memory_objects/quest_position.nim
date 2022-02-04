include common_imports

type CurrentQuestPosition* = ref object of MemoryObject

method readBaseAddress*(self: CurrentQuestPosition): ByteAddress =
  self.hook_handler.readCurrentQuestHookBase()

proc position*(self: CurrentQuestPosition): XYZ =
  ## Position of quest
  self.readXYZFromOffset(0)

proc writePosition*(self: CurrentQuestPosition, val: XYZ) =
  ## Write quest position. This is useless
  self.writeXYZToOffset(0, val)
