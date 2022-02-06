import std/asyncdispatch
import std/options
import std/strformat
import std/strutils
import std/encodings

include common_imports

type
  Window* = ref object of PropertyClass
  CurrentRootWindow* = ref object of Window

method readBaseAddress*(self: CurrentRootWindow): ByteAddress =
  self.hook_handler.readCurrentRootWindowHookBase()

buildReadWriteBuilders(Window)

buildStringReadWrite(name, 80)

# TODO: Is the rectangle order correct?
proc windowRectangle*(self: Window): Rectangle = 
  let rect = self.readVectorFromOffset(160, 4, int32)
  Rectangle(x1 : rect[0], y1 : rect[1], x2 : rect[2], y2 : rect[3])

proc writeWindowRectangle*(self: Window, val: Rectangle) = 
  self.writeVectorToOffset(160, @[val.x1, val.y1, val.x2, val.y2])

proc parent*(self: Window): Option[Window] =
  let address = self.readValueFromOffset(136, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(Window, address))

proc children*(self: Window): seq[Window] =
  var pointers = self.readSharedVectorFromOffset(112)

  for address in pointers:
    if address != 0:
      result.add(self.createDynamicMemoryObject(Window, address))

proc debugPrintUITree*(self: Window, depth: int = 0) =
  var
    name = self.name()
    typename = self.readTypeName()

  echo &"{'-'.repeat(depth)} [{name}] {typename}"

  for child in self.children():
    child.debugPrintUITree(depth + 1)

