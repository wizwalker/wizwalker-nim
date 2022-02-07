import tables

import ../constants
import ../utils
import memory_handler

const 
  get_type_name_pattern = escapeByteRegex(
    "\x48\x89\x5C\x24\x10\x57\x48\x83\xEC\x20\xE8....\xBF\x02\x00\x00\x00\x48\x8B\xD8\x8B\xC7\xF0\x0F\xB1\x3D....\x74\x54\x48\x89\x74\x24\x30\xBE\x01\x00\x00\x00\x0F\x1F\x00\x33\xC0",
  )

type InstanceFinder* = ref object
  memory_handler*: MemoryHandler
  class_name*: string
  all_jmp_instructions: seq[ByteAddress]
  all_type_name_functions: seq[ByteAddress]
  type_name_function_map: Table[string, seq[ByteAddress]]
  jmp_functions: seq[ByteAddress]

proc scanForPointer*(self: InstanceFinder, address: ByteAddress): seq[ByteAddress] =
  let pattern = escapeByteRegex(address.toBytes().toString())
  try:
    return self.memory_handler.patternScan(pattern, return_multiple=true)
  except ResourceExhaustedError:
    discard

proc getAllJmpInstructions*(self: InstanceFinder): seq[ByteAddress] =
  if self.all_jmp_instructions.len() > 0:
    return self.all_jmp_instructions

  self.all_jmp_instructions = self.memory_handler.patternScan("\xE9", module=wiz_exe_name, return_multiple=true)
  result = self.all_jmp_instructions

proc getAllTypeNameFunctions*(self: InstanceFinder): seq[ByteAddress] =
  if self.all_type_name_functions.len() > 0:
    return self.all_type_name_functions

  self.all_type_name_functions = self.memory_handler.patternScan(get_type_name_pattern, module=wiz_exe_name, return_multiple=true)
  result = self.all_type_name_functions

proc getTypeNameFunctionMap*(self: InstanceFinder): Table[string, seq[ByteAddress]] =
  if self.type_name_function_map.len() > 0:
    return self.type_name_function_map

  for function in self.getAllTypeNameFunctions():
    let
      lea_instruction = function + 63
      lea_target = function + 66
      rip_offset = self.memory_handler.read(lea_target, int32)
      type_name_addr = lea_instruction + rip_offset + 7
      type_name = self.memory_handler.readNullTerminatedString(type_name_addr, 60)
    if not result.contains(type_name):
      result[type_name] = @[]
    result[type_name].add(function)

  self.type_name_function_map = result

proc getTypeNameFunctions*(self: InstanceFinder): seq[ByteAddress] =
  self.getTypeNameFunctionMap()[self.class_name]

proc getJmpFunctions*(self: InstanceFinder): seq[ByteAddress] = 
  if self.jmp_functions.len() > 0:
    return self.jmp_functions

  let
    all_jmps = self.getAllJmpInstructions()
    type_name_funcs = self.getTypeNameFunctions()

  for jmp in all_jmps:
    if result.len() == type_name_funcs.len():
      break

    let offset = self.memoryHandler.read(jmp + 1, int32)

    for poss in type_name_funcs:
      if offset + 5 == poss - jmp:
        result.add(jmp)

  self.jmp_functions = result

proc getInstances*(self: InstanceFinder): seq[ByteAddress] =
  ## This uses the worst algorithm it could have
  for jmp_function in self.getJmpFunctions():
    let vtable_fn_pointers = self.scanForPointer(jmp_function)
    for vtable_fn in vtable_fn_pointers:
      let vtable_pointers = self.scanForPointer(vtable_fn)
      result.add(vtable_pointers)

  for type_name_function in self.getTypeNameFunctions():
    let vtable_fn_pointers = self.scanForPointer(type_name_function)
    for vtable_fn in vtable_fn_pointers:
      let vtable_pointers = self.scanForPointer(vtable_fn)
      result.add(vtable_pointers)
