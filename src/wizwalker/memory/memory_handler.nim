import tables
import options
import strutils
import strformat
import re

import winim

import ../utils

const max_string_len = 5000

type MemoryHandler* = ref object
  process_handle*: HANDLE
  window_handle*: HWND

proc initMemoryHandler*(process_handle: HANDLE, window_handle: HWND): MemoryHandler =
  ## Creates a new MemoryHandler. Only one should be active per wizard101 client
  MemoryHandler(process_handle : process_handle, window_handle : window_handle)

proc is_running*(self: MemoryHandler): bool =
  ## If the process we're reading/writing to/from is running
  checkIfProcessRunning(self.process_handle)

proc scanPageReturnAll(handle: HANDLE, address: ByteAddress, pattern: string): (ByteAddress, seq[ByteAddress]) =
  var mbi: MEMORY_BASIC_INFORMATION
  VirtualQueryEx(handle, cast[pointer](address), addr(mbi), sizeof(mbi))

  const allowed_protections = [
    PAGE_EXECUTE_READ,
    PAGE_EXECUTE_READWRITE,
    PAGE_READWRITE,
    PAGE_READONLY
  ]

  let next_region = cast[ByteAddress](cast[ByteAddress](mbi.BaseAddress) + mbi.RegionSize)

  if mbi.State != MEM_COMMIT or not (mbi.Protect in allowed_protections):
    return (next_region, newSeq[ByteAddress]())

  var
    buffer = newString(mbi.RegionSize)
    read_bytes: int64
  discard ReadProcessMemory(
    handle,
    cast[pointer](address),
    addr(buffer[0]),
    mbi.RegionSize,
    addr(read_bytes)
  )

  var found: seq[ByteAddress]
  var last_pos = 0
  while true:
    let pos = buffer.find(re(pattern), last_pos+pattern.len())
    if pos == -1:
      break
    found.add(cast[ByteAddress](mbi.BaseAddress) + pos)
    last_pos = pos

  return (next_region, found)

proc scanAll(self: MemoryHandler, pattern: string, return_multiple: bool = false): seq[ByteAddress] =
  var
    next_region: ByteAddress

  while next_region < 0x7FFFFFFF0000:
    let scan_res = self.process_handle.scanPageReturnAll(next_region, pattern)
    next_region = scan_res[0]
    result.add(scan_res[1])
    if not return_multiple and result.len() > 0:
      break

proc scanEntireModule(self: MemoryHandler, module: MODULEINFO, pattern: string): seq[ByteAddress] =
  var page_address = cast[ByteAddress](module.lpBaseOfDll)
  let max_address = page_address + module.SizeOfImage

  while page_address < max_address:
    let scan_res = self.process_handle.scanPageReturnAll(page_address, pattern)
    result.add(scan_res[1])
    page_address = scan_res[0]

iterator enumProcessModules(handle: HANDLE): MODULEINFO =
  var buff: array[1024, HMODULE]
  var a: int32
  let success = EnumProcessModulesEx(
    handle,
    addr buff[0],
    sizeof(buff).int32,
    addr a,
    LIST_MODULES_ALL
  )

  if success:
    for module in buff:
      if module == 0:
        break

      var mod_info: MODULEINFO
      GetModuleInformation(
        handle,
        module,
        addr mod_info,
        sizeof(mod_info).int32
      )

      yield mod_info
  else:
    discard # maybe error

proc getModuleName(self: MemoryHandler, info: MODULEINFO): string =
  result = newString(MAX_PATH)
  discard GetModuleBaseNameA(
    self.process_handle,
    cast[HMODULE](info.lpBaseOfDll),
    addr result[0],
    result.len().int32
  )
  result = result[0 ..< result.find("\x00")]

proc moduleFromName(self: MemoryHandler, module_name: string): MODULEINFO =
  let modname = module_name.toLowerAscii()
  for module in enumProcessModules(self.process_handle):
    if modname == self.getModuleName(module).toLowerAscii():
      return module

proc patternScan*(self: MemoryHandler, pattern: string, module: string = "", return_multiple: bool = false): seq[ByteAddress] =
  ## Scan for a pattern
  let found =
    if module.len() > 0:
      let modinfo = self.moduleFromName(module)
      self.scanEntireModule(modinfo, pattern)
    else:
      self.scanAll(pattern, return_multiple)

  if found.len() == 0:
    raise newException(ResourceExhaustedError, "Could not find pattern: " & pattern.toHex()) # TODO: This and the next toHex are horrendous
  elif found.len() > 1 and not return_multiple:
    raise newException(ResourceExhaustedError, "Got too many results for pattern: " & pattern.toHex())
  elif return_multiple:
    return found
  else:
    result.add(found[0])

proc allocate*(self: MemoryHandler, size: int): ByteAddress =
  ## Allocate memory in process
  cast[ByteAddress](self.process_handle.VirtualAllocEx(nil, size, MEM_COMMIT, PAGE_EXECUTE_READWRITE))

proc free*(self: MemoryHandler, address: ByteAddress) =
  ## Free memory
  self.process_handle.VirtualFreeEx(cast[pointer](address), 0, MEM_RELEASE)

proc readBytes*(self: MemoryHandler, address: ByteAddress, size: int): string =
  ## Read bytes from memory
  if not address > 0 or address >= 0x7FFFFFFFFFFFFFFF:
    raise newException(ResourceExhaustedError, "Address out of range: " & address.toHex())
  
  if size > 0:
    result = newString(size)
    let success = self.process_handle.ReadProcessMemory(cast[pointer](address), addr(result[0]), size, nil)
    if success == 0:
      raise newException(OSError, "Failed to read from address " & address.toHex())

proc writeBytes*(self: MemoryHandler, address: ByteAddress, value: string) =
  ## Write bytes to memory
  var buff = value # can probably avoid copy
  let success = self.process_handle.WriteProcessMemory(cast[pointer](address), addr(buff[0]), value.len(), nil)
  if success == 0:
    raise newException(OSError, "Failed to write to address " & address.toHex())

proc read*[T](self: MemoryHandler, address: ByteAddress, t: typedesc[T]): T =
  ## Read typed value from memory. Does not work for strings/containers
  var data = self.readBytes(address, sizeof(T))
  cast[ptr T](addr(data[0]))[]

proc write*[T](self: MemoryHandler, address: ByteAddress, val: T) =
  ## Write typed value to memory. Does not work for strings/containers
  var buff = newString(sizeof(T))
  cast[ptr T](addr buff[0])[] = val
  self.writeBytes(address, buff)

proc readNullTerminatedString*(self: MemoryHandler, address: ByteAddress, max_size: int = 20): string =
  ## Read a null-terminated string from memory
  let 
    bytes = self.readBytes(address, max_size)
    string_end = bytes.find("\x00")
  if string_end == 0:
    return ""
  elif string_end == -1:
    raise newException(ResourceExhaustedError, "Missing end byte for string at " & $address.toHex())

  bytes[0 ..< string_end].strip()

proc readWideString*(self: MemoryHandler, address: ByteAddress): string =
  ## Read a wide string from memory
  # TODO: Check if this works
  let string_len = self.read(address + 16, int32) * 2

  var string_address = address
  if string_len == 0:
    return ""
  elif string_len >= 8:
    # pointer
    string_address = self.read(address, ByteAddress)

  self.readBytes(string_address, string_len)

proc writeWideString*(self: MemoryHandler, address: ByteAddress, value: string) =
  ## Write a wide string to memory
  # TODO: Check if this works
  let
    string_len_addr = address + 16
    old_len = self.read(string_len_addr, int32)
    data = value

  if data.len() >= 7 and old_len < 8:
    let pointer_address = self.allocate(data.len())
    self.writeBytes(pointer_address, data & "\x00")
    self.write(address, pointer_address)
  elif data.len() >= 7 and old_len >= 8:
    let pointer_address = self.read(address, ByteAddress)
    self.writeBytes(pointer_address, data & "\x00")
  else:
    self.writeBytes(address, data & "\x00")

  self.write(string_len_addr, data.len().int32)

proc readString*(self: MemoryHandler, address: ByteAddress): string =
  ## Read a string from memory
  let string_len = self.read(address + 16, int32)
  if not string_len > 0 or string_len > max_string_len:
    return ""

  var string_address = address
  if string_len >= 16:
    string_address = self.read(address, ByteAddress)

  self.readBytes(string_address, string_len)

proc writeString*(self: MemoryHandler, address: ByteAddress, value: string) =
  ## Write a string to memory
  let
    string_len_addr = address + 16
    string_len = value.len()
    old_string_len = self.read(string_len_addr, int32)

  if string_len >= 15 and old_string_len < 16:
    let pointer_address = self.allocate(string_len + 1)
    self.writeBytes(pointer_address, value & "\x00")
    self.write(address, pointer_address)

proc readVector*[T](self: MemoryHandler, address: ByteAddress, size: int, data_type: typedesc[T]): seq[T] =
  ## Read a vector from memory
  # TODO: Check if this works. Uses some black magic
  var
    full_size = sizeof(T) * size
    buff = self.readBytes(address, full_size)
  var offset = 0
  while offset < full_size:
    result.add(cast[ptr T](addr buff[offset])[])
    offset += sizeof(T)

proc writeVector*[T](self: MemoryHandler, address: ByteAddress, values: seq[T]) =
  ## Writes a vector. A list of containers will not work, unless their size is known at compiletime.
  var offset = 0
  for val in values:
    self.write(address + offset, val)
    offset += sizeof(T)

proc readXYZ*(self: MemoryHandler, address: ByteAddress): XYZ =
  ## Read XYZ from memory as a vector
  let values = self.readVector(address, 3, float32)
  XYZ(x : values[0], y : values[1], z : values[2])

proc writeXYZ*(self: MemoryHandler, address: ByteAddress, value: XYZ) =
  ## Write XYZ to memory as a vector
  self.writeVector(address, @[value.x, value.y, value.z])

proc readSharedVector*(self: MemoryHandler, address: ByteAddress, max_count: int = 1000): seq[ByteAddress] =
  ## Read a shared vector from memory
  let
    start_address = self.read(address, ByteAddress)
    end_address = self.read(address + 8, ByteAddress)
    size = end_address - start_address
    element_count = size div 16

  if size <= 0:
    return @[]

  if element_count > max_count:
    raise newException(ResourceExhaustedError, &"Size of vector at {address.toHex()} was over max_count={max_count} (length is {element_count})")

  var data: string
  try:
    data = self.readBytes(start_address, size)
  except ResourceExhaustedError:
    return @[]

  var offset = 0
  while offset < size:
    result.add(cast[ptr ByteAddress](addr data[offset])[])
    offset += 16

proc readDynamicVector*[T](self: MemoryHandler, address: ByteAddress, t: typedesc[T]): seq[T] =
  ## Read a dynamic vector from memory
  let
    start_address = self.read(address, ByteAddress)
    end_address = self.read(address + 8, ByteAddress)
    size = (end_address - start_address) div sizeof(T)

  if size == 0:
    return @[]

  var current_address = start_address
  for _ in 0 ..< size:
    result.add(self.read(current_address, T))
    current_address += sizeof(T)

proc readSharedLinkedList*(self: MemoryHandler, address: ByteAddress): seq[ByteAddress] =
  ## Read a shared linked list
  let 
    list_addr = self.read(address, ByteAddress)
    list_size = self.read(address + 8, int32)

  var next_node_addr = list_addr
  for _ in 0 ..< list_size:
    let list_node = self.read(next_node_addr, ByteAddress)
    next_node_addr = self.read(list_node, ByteAddress)
    result.add(self.read(list_node + 16, ByteAddress))

proc readLinkedList*(self: MemoryHandler, address: ByteAddress): seq[ByteAddress] =
  ## Read a normal linked list
  let 
    list_addr = self.read(address, ByteAddress)
    list_size = self.read(address + 8, int32)

  var next_node_addr = list_addr
  for _ in 0 ..< list_size:
    let list_node = self.read(next_node_addr, ByteAddress)
    next_node_addr = self.read(list_node, ByteAddress)
    result.add(list_node + 16)
