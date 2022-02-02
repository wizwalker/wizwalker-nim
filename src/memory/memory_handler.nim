import tables
import regex
import options
import strutils
import asyncdispatch

import winim

import ../utils

type MemoryHandler = ref object of RootObj
  symbol_table: Table[string, Table[string, ByteAddress]]
  process_handle: HANDLE

method is_running*(self: MemoryHandler): bool {.base.} =
  ## If the process we're reading/writing to/from is running
  checkIfProcessRunning(self.process_handle)

proc scanPageReturnAll(handle: HANDLE, address: ByteAddress, pattern: Regex): (ByteAddress, seq[ByteAddress]) =
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
  for match in findAllBounds(buffer, pattern):
    let found_address = address + match.a
    found.add(found_address)

  return (next_region, found)

method scanAll(self: MemoryHandler, pattern: Regex, return_multiple: bool = false): seq[ByteAddress] {.base.} =
  var
    next_region: ByteAddress

  while next_region < 0x7FFFFFFF0000:
    let scan_res = self.process_handle.scanPageReturnAll(next_region, pattern)
    next_region = scan_res[0]
    result.add(scan_res[1])
    if not return_multiple and result.len() > 0:
      break

method scanEntireModule(self: MemoryHandler, module: MODULEINFO, pattern: Regex): seq[ByteAddress] {.base.} =
  let
    base_address = cast[ByteAddress](module.lpBaseOfDll)
    max_address = base_address + module.SizeOfImage

  var page_address = base_address

  while page_address < max_address:
    let scan_res = self.process_handle.scanPageReturnAll(page_address, pattern)
    result.add(scan_res[1])

iterator enumProcessModules(handle: HANDLE): MODULEINFO =
  var buff: array[1024, HMODULE]
  let success = EnumProcessmodulesEx(
    handle,
    addr buff[0],
    sizeof(buff).int32,
    nil,
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

method getModuleName(self: MemoryHandler, info: MODULEINFO): string {.base.} =
  result = newString(MAX_PATH)
  discard GetModuleBaseNameA(
    self.process_handle,
    cast[HMODULE](info.lpBaseOfDll),
    addr result[0],
    result.len().int32
  )

method moduleFromName(self: MemoryHandler, module_name: string): MODULEINFO {.base.} =
  let modname = module_name.toLowerAscii()
  for module in enumProcessModules(self.process_handle):
    if modname == self.getModuleName(module).toLowerAscii():
      return module

method patternScan*(self: MemoryHandler, pattern: Regex, module: string = "", return_multiple: bool = false): seq[ByteAddress] {.base.} =
  ## Scan for a pattern
  let found =
    if module.len() > 0:
      let modinfo = self.moduleFromName(module)
      self.scanEntireModule(modinfo, pattern)
    else:
      self.scanAll(pattern, return_multiple)

  if found.len() == 0:
    raise newException(ResourceExhaustedError, "Could not find pattern: " & $pattern)
  elif found.len() > 1 and not return_multiple:
    raise newException(ResourceExhaustedError, "Got too many results for pattern: " & $pattern)
  elif return_multiple:
    return found
  else:
    result.add(found[0])

method allocate*(self: MemoryHandler, size: int): ByteAddress {.base.} =
  ## Allocate memory in process
  cast[ByteAddress](self.process_handle.VirtualAllocEx(nil, size, MEM_COMMIT, PAGE_EXECUTE_READWRITE))

method free*(self: MemoryHandler, address: ByteAddress) {.base.} =
  ## Free memory
  self.process_handle.VirtualFreeEx(cast[pointer](address), 0, MEM_RELEASE)

method readBytes*(self: MemoryHandler, address: ByteAddress, size: int): string {.base.} =
  ## Read bytes from memory
  if not address > 0 or address >= 0x7FFFFFFFFFFFFFFF:
    raise newException(ResourceExhaustedError, "Address out of range: " & address.toHex())
  
  result = newString(size)
  let success = self.process_handle.ReadProcessMemory(cast[pointer](address), addr(result[0]), size, nil)
  if success == 0:
    raise newException(OSError, "Failed to read from address " & address.toHex())

method writeBytes*(self: MemoryHandler, address: ByteAddress, value: string) {.base.} =
  ## Write bytes to memory
  var buff = value # can probably avoid copy
  let success = self.process_handle.WriteProcessMemory(cast[pointer](address), addr(buff[0]), value.len(), nil)
  if success == 0:
    raise newException(OSError, "Failed to write to address " & address.toHex())

method read*[T](self: MemoryHandler, address: ByteAddress, t: typedesc[T]): T {.base.} =
  ## Read typed value from memory. Does not work for strings/containers
  let data = self.readBytes(address, sizeof(T))
  cast[T](data[0])

method write*[T](self: MemoryHandler, address: ByteAddress, val: T) {.base.} =
  ## Write typed value to memory. Does not work for strings/containers
  var buff = newString(sizeof(T))
  cast[ptr T](buff[0])[] = val
  self.writeBytes(address, buff)

method readNullTerminatedString*(self: MemoryHandler, address: ByteAddress, max_size: int = 20): string {.base.} =
  ## Read a null-terminated string from memory
  let 
    bytes = self.readBytes(address, max_size)
    string_end = bytes.find("\x00")
  if string_end == 0:
    return ""
  elif string_end == -1:
    raise newException(ResourceExhaustedError, "Missing end byte for string at " & $address.toHex())

  bytes[0 ..< string_end]

method readWideString*(self: MemoryHandler, address: ByteAddress): string {.base.} =
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

method writeWideString*(self: MemoryHandler, address: ByteAddress, value: string) {.base.} =
  ## Write a wide string to memory
  # TODO: Check if this works
  let
    string_len_addr = address + 16
    old_len = self.read(string_len_addr, int32)

  if value.len() >= 7 or old_len < 8:
    let pointer_address = self.allocate(value.len())
    self.writeBytes(pointer_address, value & "\x00")
    self.write(address, pointer_address)
  elif value.len() >= 7 and old_len >= 8:
    let pointer_address = self.read(address, ByteAddress)
    self.writeBytes(pointer_address, value & "\x00")
  else:
    self.writeBytes(address, value & "\x00")

  self.write(string_len_addr, value.len(), int32)
