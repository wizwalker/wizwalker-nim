import std/options
import std/strformat
import std/strutils

include common_imports
import render_context
import spell
import combat_participant
import wiz_enums

type
  Window* = ref object of PropertyClass
  CurrentRootWindow* = ref object of Window

method readBaseAddress*(self: CurrentRootWindow): ByteAddress =
  self.hook_handler.readCurrentRootWindowHookBase()

buildReadWriteBuilders(Window)

buildStringReadWrite(name, 80)
buildValueReadWrite(alpha, float32, 208)
buildValueReadWrite(targetAlpha, float32, 212)
buildValueReadWrite(disabledAlpha, float32, 216)
buildStringReadWrite(help, 248)
buildStringReadWrite(script, 352)
buildStringReadWrite(tip, 392)

proc offset*(self: Window): (int32, int32) = 
  let v = self.readVectorFromOffset(192, 2, int32)
  (v[0], v[1])

proc writeOffset*(self: Window, v: (int32, int32)) = 
  self.writeVectorToOffset(192, @[v[0], v[1]])

proc scale*(self: Window): (float32, float32) = 
  let v = self.readVectorFromOffset(200, 2, float32)
  (v[0], v[1])

proc writeScale*(self: Window, v: (float32, float32)) = 
  self.writeVectorToOffset(200, @[v[0], v[1]])

proc parentOffset*(self: Window): (int32, int32, int32, int32) = 
  let v = self.readVectorFromOffset(176, 4, int32)
  (v[0], v[1], v[2], v[3])

proc writeParentOffset*(self: Window, v: (int32, int32, int32, int32)) = 
  self.writeVectorToOffset(176, @[v[0], v[1], v[2], v[3]])

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

proc getParents*(self: Window): seq[Window] =
  var p = self.parent()
  while p.isSome():
    result.add(p.unsafeGet())
    p = p.unsafeGet().parent()

proc scaleToClient*(self: Window): Rectangle =
  let rect = self.windowRectangle()
  var parentRects: seq[Rectangle]
  for parent in self.getParents():
    parent_rects.add(parent.windowRectangle())

  # Could be improved
  let
    ctx = CurrentRenderContext(memory_handler : self.memory_handler, hook_handler : self.hook_handler)
    uiScale = ctx.uiScale()

  rect.scaleToClient(parent_rects, ui_scale)

proc debugPaint*(self: Window) =
  let rect = self.scaleToClient()
  rect.paintOnScreen(self.memory_handler.window_handle)

proc children*(self: Window): seq[Window] =
  var pointers = self.readSharedVectorFromOffset(112)

  for address in pointers:
    if address != 0:
      result.add(self.createDynamicMemoryObject(Window, address))

proc getChildByName*(self: Window, name: string): Window =
  for child in self.children():
    if child.name() == name:
      return child

  raise newException(ValueError, &"No child named {name}")

proc debugPrintUITree*(self: Window, depth: int = 0) =
  var
    name = self.name()
    typename = self.readTypeName()

  echo &"{'-'.repeat(depth)} [{name}] {typename}"

  for child in self.children():
    child.debugPrintUITree(depth + 1)

# Maybe this should take async?
proc getWindowsWithPredicate*(self: Window, predicate: proc (win: Window): bool): seq[Window] =
  for child in self.children():
    if predicate(child):
      result.add(child)
    result.add(child.getWindowsWithPredicate(predicate)) # WW-py used a proxy for some reason

proc getWindowsWithName*(self: Window, name: string): seq[Window] = 
  proc pred(win: Window): bool =
    return win.name() == name

  self.getWindowsWithPredicate(pred)

proc getWindowsWithType*(self: Window, type_name: string): seq[Window] =
  proc pred(win: Window): bool =
    win.readTypeName() == type_name

  self.getWindowsWithPredicate(pred)

template checkWindowType(self: Window, name: string) =
  let type_name = self.readTypeName()
  if type_name != name:
    raise newException(ValueError, "This object is a " & type_name & " not a " & name)

proc maybeGraphicalSpell*(self: Window, check_type: bool = false): Option[GraphicalSpell] =
  if check_type:
    self.checkWindowType("SpellCheckBox")

  let address = self.readValueFromOffset(952, ByteAddress)
  if address != 0:
    return some(self.createDynamicMemoryObject(GraphicalSpell, address))

proc maybeSpellGrayed*(self: Window, check_type: bool = false): bool =
  if check_type:
    self.checkWindowType("SpellCheckBox")

  self.readValueFromOffset(1024, bool)

proc maybeCombatParticipant*(self: Window, check_type: bool = false): CombatParticipant =
  if check_type:
    self.checkWindowType("CombatantDataControl")

  let address = self.readValueFromOffset(1656, ByteAddress)
  if address != 0:
    return self.createDynamicMemoryObject(CombatParticipant, address)

proc text*(self: Window): string =
  self.readWideStringFromOffset(584)

proc writeText*(self: Window, text: string) =
  self.writeWideStringToOffset(584, text)

proc style*(self: Window): WindowStyles =
  let val = self.readValueFromOffset(152, int32)
  cast[WindowStyles](val)

proc writeStyle*(self: Window, val: WindowStyles) =
  self.writeValueToOffset(152, cast[int32](val))

proc flags*(self: Window): WindowFlags =
  let val = self.readValueFromOffset(156, int32)
  cast[WindowFlags](val)

proc writeFlags*(self: Window, val: WindowFlags) =
  self.writeValueToOffset(156, cast[int32](val))

proc isVisible*(self: Window): bool =
  WindowFlag.visible in self.flags()
