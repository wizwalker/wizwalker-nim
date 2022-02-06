include common_imports

type
  Window* = ref object of PropertyClass
  CurrentRootWindow* = ref object of Window

proc readBaseAddress*(self: CurrentRootWindow): ByteAddress =
  self.hook_handler.readCurrentRootWindowHookBase()

# TODO: Is the rectangle order correct?
proc windowRectangle*(self: Window): Rectangle = 
  let rect = self.readVectorFromOffset(160, 4, int32)
  Rectangle(x1 : rect[0], y1 : rect[1], x2 : rect[2], y2 : rect[3])

proc writeWindowRectangle*(self: Window, val: Rectangle) = 
  self.writeVectorToOffset(160, @[val.x1, val.y1, val.x2, val.y2])

