import tables
import regex
import options
import strutils
import asyncdispatch

import winim

import ../utils

type MemoryReader = ref object of RootObj
  symbol_table: Table[string, Table[string, ByteAddress]]
  process_handle: HANDLE

method is_running*(self: MemoryReader): bool {.base.} =
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

proc scanAll(self: MemoryReader, pattern: Regex, return_multiple: bool = false): seq[ByteAddress] =
  var
    next_region: ByteAddress

  while next_region < 0x7FFFFFFF0000:
    let scan_res = self.process_handle.scanPageReturnAll(next_region, pattern)
    next_region = scan_res[0]
    result.add(scan_res[1])
    if not return_multiple and result.len() > 0:
      break

proc scanEntireModule(self: MemoryReader, module: MODULEINFO, pattern: Regex): seq[ByteAddress] =
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

proc getModuleName(self: MemoryReader, info: MODULEINFO): string =
  result = newString(MAX_PATH)
  discard GetModuleBaseNameA(
    self.process_handle,
    cast[HMODULE](info.lpBaseOfDll),
    addr result[0],
    result.len().int32
  )

proc moduleFromName(self: MemoryReader, module_name: string): MODULEINFO =
  let modname = module_name.toLowerAscii()
  for module in enumProcessModules(self.process_handle):
    if modname == self.getModuleName(module).toLowerAscii():
      return module

proc patternScan*(self: MemoryReader, pattern: Regex, module: string = "", return_multiple: bool = false): seq[ByteAddress] =
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

proc allocate*(self: MemoryReader, size: int): ByteAddress =
  cast[ByteAddress](VirtualAllocEx(self.process_handle, nil, size, MEM_COMMIT, PAGE_EXECUTE_READWRITE))