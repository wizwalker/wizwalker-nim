import math
import options
import os
import strformat
import osproc
import asyncdispatch
import strutils

import fusion/matching
{.experimental: "caseStmtMacros".}

import winim
import winregistry

import constants

const
  default_install* = "C:/ProgramData/KingsIsle Entertainment/Wizard101"

var
  override_path* {.global.} = default_install

type
  XYZ* = object
    x*, y*, z*: float32

  Rectangle* = object
    x1*, y1*, x2*, y2*: int32

  PathError* = object of CatchableError

proc initXYZ*(x, y, z: float32): XYZ = XYZ(x : x, y : y, z : z)

template square(a: untyped): untyped = a * a

func distance(self, other: (float32, float32)): float =
  ((other[0] - self[0]).square() + (other[1] - self[1])).sqrt()

func distanceSquared*(self, other: XYZ): float32 =
  (other.x - self.x).square() + (other.y - self.y).square() + (other.z - self.z).square()

func distance*(self, other: XYZ): float32 =
  ## Calculates the distance between two points.
  ## This does not account for z axis
  self.distanceSquared(other).sqrt()

proc calculatePerfectYaw*(current_xyz, target_xyz: XYZ): float32 =
  ## Calculates the perfect yaw to reach an xyz in a straight line
  let
    target_line = distance(
      (current_xyz.x, current_xyz.y),
      (target_xyz.x, target_xyz.y)
    )
    origin_line = distance(
      (current_xyz.x, current_xyz.y),
      (current_xyz.x, current_xyz.y - 1)
    )
    target_to_origin_line = distance(
      (target_xyz.x, target_xyz.y),
      (current_xyz.x, current_xyz.y - 1)
    )
    target_angle = arccos(
      (target_line.square() + origin_line.square() - target_to_origin_line.square()) /
      (2 * origin_line * target_line)
    )

  if target_xyz.x > current_xyz.x:
    # outside
    let target_angle_degrees = radToDeg(target_angle)
    result = degToRad(360.0 - target_angle_degrees)
  else:
    # inside
    result = target_angle

func yaw*(self, other: XYZ): float =
  ## Calculate perfect yaw to reach another xyz
  calculatePerfectYaw(self, other)

func relativeYaw*(self: XYZ, x, y=none(float)): float =
  ## Calculate relative yaw to reach another x and/or y relative to current
  let
    x = if x.isNone(): self.x else: x.get()
    y = if y.isNone(): self.y else: y.get()

  result = self.yaw(initXYZ(x, y, self.z))

func scaleToClient*(self: Rectangle, parents: seq[Rectangle], factor: float): Rectangle =
  ## Scale this rectangle base on parents and a scale factor
  result.x1 = self.x1
  result.x2 = self.y1

  for rect in parents:
    result.x1 += rect.x1
    result.x2 += rect.y1

  result.x2 = (((self.x2 - self.x1).float * factor) + (result.x1.float * factor)).int32
  result.y2 = (((self.y2 - self.y1).float * factor) + (result.y1.float * factor)).int32
  result.x1 = (result.x1.float * factor).int32
  result.y1 = (result.y1.float * factor).int32

func center*(self: Rectangle): (int32, int32) =
  ## Get the center point of this rectangle
  (
    (self.x2 - self.x1) div 2 + self.x1,
    (self.y2 - self.y1) div 2 + self.y1
  )

proc paintOnScreen*(self: Rectangle, window_handle: HANDLE, rgb=RGB(255, 0, 0)) =
  ## Paint this rectangle to the screen for debugging
  var
    paint_struct: PAINTSTRUCT
    device_context = window_handle.GetDC()
    brush = rgb.CreateSolidBrush()
    draw_rect = RECT(
      left : self.x1.int32,
      right : self.x2.int32,
      top : self.y1.int32,
      bottom : self.y2.int32
    )
    region = CreateRectRgnIndirect(addr(draw_rect))
  
  window_handle.BeginPaint(addr(paint_struct))
  device_context.FillRgn(region, brush)
  window_handle.EndPaint(addr(paint_struct))

  window_handle.ReleaseDC(device_context)
  brush.DeleteObject()
  region.DeleteObject()

# TODO
func orderClients*() = discard

proc overrideWizInstallLocation*(path: string) =
  ## Override the path returned 
  override_path = path

proc getWizInstall*(): Option[string] = 
  ## Get the game install root dir
  if override_path.dirExists():
    return some(override_path)

  try:
    var handle = open(
      "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{A9E27FF5-6294-46A8-B8FD-77B1DECA3021}",
      samRead
    )
    defer: handle.close()

    result = some(handle.readString("InstallLocation"))
  except RegistryError:
    discard

proc startInstance*() = 
  ## Starts a wizard101 instance
  case getWizInstall()
  of Some(@path):
    discard startProcess(
      &"{path}/Bin/WizardGraphicalClient.exe",
      &"{path}/Bin",
      args=["-L", "login.us.wizard101.com", "12000"]
    )
  else:
    raise newException(PathError, "No wizard101 path found")

proc instanceLogin*(window_handle: HWND, username, password: string) =
  ## Login to an instance on the login screen
  proc sendChars(chars: string) =
    for c in chars:
      window_handle.SendMessage(0x102, c.int32, 0)

  sendChars(username)
  window_handle.SendMessage(0x102, 9, 0) # tab
  sendChars(password)
  window_handle.SendMessage(0x102, 13, 0) # enter

# TODO
proc startInstancesWithLogin*(instance_number: int, logins: seq[string]) =
  discard

proc waitForValue*[T](coro: proc(): Future[T], want: T, sleep_time: float = 0.5, ignore_errors: bool = true): Future[T] {.async.} =
  ## Wait for a coro to return a value
  while true:
    try:
      let val = await coro()
      if val == want:
        return val
    except Exception as e:
      if ignore_errors:
        await sleepAsync((sleep_time * 1000).int)
      else:
        raise e

proc getWindowTitle*(handle: HWND, max_size: static[int] = 100): string =
  ## Get a window's title bar text.
  var buff = newWString(max_size)
  handle.GetWindowText(buff, max_size)
  return $buff

proc setWindowTitle*(handle: HWND, title: string) =
  ## Set a window's title bar text
  handle.SetWindowText(title)

proc getWindowRectangle*(handle: HWND): Rectangle =
  ## Get a window's `Rectangle`_
  var rect = RECT()
  handle.GetWindowRect(addr(rect))
  # TODO: Order was different in WW. Which is correct?
  result = Rectangle(
    x1 : rect.left,
    x2 : rect.right,
    y1 : rect.top,
    y2 : rect.bottom
  )

proc getPidFromHandle*(handle: HWND): int32 =
  ## Get process id from a window handle
  discard handle.GetWindowThreadProcessId(addr(result))

proc checkIfProcessRunning*(process_handle: HANDLE): bool =
  ## Returns true if process is still running
  var exit_code: int32
  discard process_handle.GetWindowThreadProcessId(addr(exit_code))
  result = exit_code == 259 # IS_ALIVE

proc sendKeydownForever(handle: HWND, key: Keycode) {.async.} =
  while true:
    handle.SendMessage(0x100, key.int32, 0)
    await sleepAsync(50)

proc timedSendKey*(handle: HWND, key: Keycode, seconds: float) {.async.} =
  ## Send a key for a number of seconds
  discard await handle.sendKeydownForever(key).withTimeout((seconds * 1000).int)

proc getWindowsFromPredicate*(predicate: proc(handle: HWND): bool): seq[HWND] =
  ## Get all windows that match a predicate

  # trickery to make callback work
  var handles {.global.}: seq[HWND]
  var pred {.global.}: proc(handle: HWND): bool
  pred = predicate

  proc callback(handle: HWND, a: LPARAM): WINBOOL {.stdcall.} =
    if pred(handle):
      handles.add(handle)
    return 1

  EnumWindows(callback, 0)
  result = handles
  handles = @[]

proc getAllWizardHandles*(): seq[HWND] =
  ## Get handles to all currently open wizard clients
  const target_class = "Wizard Graphical Client"

  proc callback(handle: HWND): bool =
    var class_name = newWString(target_class.len())
    GetClassName(handle, class_name, target_class.len() + 1)
    if +$target_class == class_name:
      return true

  result = getWindowsFromPredicate(callback)

proc toString*[S](bytes: array[S, byte]): string =
  ## Helper to convert static byte arrays to byte string
  result = newString(bytes.len())
  copyMem(addr(result[0]), unsafeAddr(bytes[0]), bytes.len())

template toBytes*[T](v: T): untyped =
  ## Helper to convert "flat" types to bytes
  cast[array[sizeof(T), byte]](v)

proc escapeByteRegex*(v: string): string = 
  ## Helper to escape bytes that happen to have a meaning in pcre regex.
  ## This should be prime suspect #1 if patterns don't work for no reason
  v.multiReplace(
    ("+", "\\+"),
    ("*", "\\*"),
    ("?", "\\?"),
    ("^", "\\^"),
    ("$", "\\$"),
    ("(", "\\("),
    (")", "\\)"),
    ("{", "\\{"), # only opening one is evil
    ("[", "\\["), # same here
    ("|", "\\|"), # TODO: Think about this some more
  )

proc all*[T](fs: seq[Future[T]]): Future[seq[T]] =
  ## Helper to deal with multiple futures at once
  result = newFuture[seq[T]](fromProc = "all")
  var
    items = newSeq[A](fs.len)
    count = 0
  
  for i, f in fs:
    f.callback = proc(g: Future[T]) =
      items[i] = g.read
      count += 1
      if count == fs.len:
        result.complete(items)
