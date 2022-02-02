import locks

type
  MouseHandler* = ref object of RootObj
    mouse_lock: Lock

method activateMouseless*(self: MouseHandler) {.base, async.} =
  ## Activates the mouseless hook
  discard

method deactivateMouseless*(self: MouseHandler) {.base, async.} =
  ## Deactivates the mouseless hook
  discard

method click*(self: MouseHandler) {.base, async.} =
  ## Click an x, y position
  discard