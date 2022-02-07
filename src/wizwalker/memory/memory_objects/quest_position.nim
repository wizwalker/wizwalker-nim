include common_imports

type CurrentQuestPosition* = ref object of MemoryObject

method readBaseAddress*(self: CurrentQuestPosition): ByteAddress =
  self.hook_handler.readCurrentQuestHookBase()

buildReadWriteBuilders(CurrentQuestPosition)

buildXYZReadWrite(position, 0)
