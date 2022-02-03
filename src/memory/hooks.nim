import strformat
import strutils
import tables
import re

import ../utils
import memory_handler

type
  MemoryHook* = ref object of RootObj
    memory_handler*: MemoryHandler
    jump_original_bytecode*: string
    hook_address*, jump_address*: ByteAddress
    hook_bytecode*, jump_bytecode*: string

    allocated_addresses: seq[ByteAddress]

  AutobotBaseHook* = ref object of MemoryHook
    autobot_allocator*: proc (size: int): ByteAddress ## Needed to avoid circular dependency

  SimpleHook* = ref object of AutobotBaseHook
    pattern: string
    module: string
    instruction_length: int
    exports: seq[(string, int)]
    export_addrs*: Table[string, ByteAddress] # TODO: Maybe replace with a template to replicate what WW did
    noops: int

method alloc*(self: MemoryHook, size: int): ByteAddress {.base.} =
  ## Allocate memory
  result = self.memory_handler.allocate(size)
  self.allocated_addresses.add(result)

method prehook*(self: MemoryHook) {.base.} =
  ## Called before bytecode is written
  discard

method posthook*(self: MemoryHook) {.base.} =
  ## Called after bytecode is written
  discard

proc getJumpAddress*(self: MemoryHook, pattern: string, module: string = ""): ByteAddress =
  ## Gets the address to write jump at
  let scanres = self.memory_handler.patternScan(pattern, module=module)
  if scanres.len() == 0:
    raise newException(ResourceExhaustedError, &"Failed to get jump address for pattern {$pattern}")
  scanres[0]

template getHookAddress*(self: MemoryHook, size: int): ByteAddress =
  ## Get address to jump to
  self.alloc(size)

method getJumpBytecode*(self: MemoryHook): string {.base.} =
  ## Overridden by each hook
  quit "getJumpBytecode must be overridden"

method getHookBytecode*(self: MemoryHook): string {.base.} = 
  ## Overridden by each hook
  quit "getHookBytecode must be overridden"

method getPattern*(self: MemoryHook): (string, string) {.base.} =
  ## Returns the pattern and module name for hook
  quit "getPattern must be overridden"

method hook*(self: MemoryHook) {.base.} =
  ## Install the hook
  let pattern = self.getPattern()
  self.jump_address = self.getJumpAddress(pattern[0], module=pattern[1])
  self.hook_address = self.getHookAddress(50)

  self.hook_bytecode = self.getHookBytecode()
  self.jump_bytecode = self.getJumpBytecode()

  self.jump_original_bytecode = self.memory_handler.readBytes(self.jump_address, self.jump_bytecode.len())

  self.prehook()

  self.memory_handler.writeBytes(self.hook_address, self.hook_bytecode)
  self.memory_handler.writeBytes(self.jump_address, self.jump_bytecode)

  self.posthook()

method unhook*(self: MemoryHook) {.base.} =
  ## Uninstalls the hook
  self.memory_handler.writeBytes(self.jump_address, self.jump_original_bytecode)
  for a in self.allocated_addresses:
    self.memory_handler.free(a)

method alloc*(self: AutobotBaseHook, size: int): ByteAddress =
  ## Allocate using autobot codecave
  self.autobot_allocator(size)

# TODO: tell handler those bytes are free now? (comment inherited from WW-py)
method unhook*(self: AutobotBaseHook) =
  ## Unhook autobot-based hook
  procCall MemoryHook(self).unhook()
  self.memory_handler.writeBytes(self.jump_address, self.jump_original_bytecode)

method getPattern*(self: SimpleHook): (string, string) =
  (self.pattern, self.module)

method getJumpBytecode*(self: SimpleHook): string =
  ## Builds jump bytecode and returns it
  let
    distance = self.hook_address - self.jump_address
    relative_jump = (distance - 5).int32
  "\xE9" & relative_jump.toBytes().toString() & repeat('\x90', self.noops)

method generateBytecode*(self: SimpleHook, exports: seq[(string, ByteAddress)]): string {.base.} =
  ## Generates hook bytecode
  quit "generateBytecode must be overridden"

method getHookBytecode*(self: SimpleHook): string =
  ## Gets output from `SimpleHook.generateBytecode`_ and extends it slightly
  var exports: seq[(string, ByteAddress)]
  for exp in self.exports:
    let address = self.memory_handler.allocate(exp[1])
    self.export_addrs[exp[0]] = address
    exports.add((exp[0], address))

  result = self.generateBytecode(exports)

  let
    return_addr = self.jump_address + self.instruction_length
    relative_return_jump = (return_addr - (self.hook_address + len(result)) - 5).int32
  
  result.add("\xE9" & relative_return_jump.toBytes().toString())

method unhook*(self: SimpleHook) =
  procCall AutobotBaseHook(self).unhook()
  for exp in self.export_addrs.pairs():
    self.memory_handler.free(exp[1])

template buildSimpleHook*(name, exported: untyped, nops: int, reg: string, original_code: string, generator_body: untyped): untyped {.dirty.} =
  type name* = ref object of SimpleHook

  proc `init name`*(memory_handler: MemoryHandler, autobot_allocator: proc (size: int): ByteAddress): name =
    name(
      autobot_allocator : autobot_allocator,
      pattern : reg,
      exports : exported,
      noops : nops,
      instruction_length : original_code.len(),
      memory_handler : memory_handler,
      module : "WizardGraphicalClient.exe",
    )

  method generateBytecode*(self: name, exports: seq[(string, ByteAddress)]): string =
    generator_body & original_code

buildSimpleHook(
  PlayerHook,
  @[("player_struct", 8)],
  0,
  "\xF2\x0F\x10\x40\x58\xF2",
  "\xF2\x0F\x10\x40\x58"
):
  "\x51" & # push rcx
  "\x8B\x88\x74\x04\x00\x00" & #mov ecx, [rax+474]
  "\x83\xF9\x08" & # cmp ecx, 08
  "\x59" & # pop rcx
  "\x0F\x85\x0A\x00\x00\x00" & # jne 10 down
  "\x48\xA3" & exports[0][1].toBytes().toString() # mov [addr], rax

buildSimpleHook(
  PlayerStatHook,
  @[("stat_addr", 8)],
  2,
  "\x2B\xD8\xB8....\x0F\x49\xC3\x48\x83\xC4\x20\x5B\xC3",
  "\x2B\xD8\xB8\x00\x00\x00\x00"
):
  "\x50" & # push rax
  "\x48\x89\xC8" & # mov rax, rcx
  "\x48\xA3" & exports[0][1].toBytes().toString() & # mov qword ptr [stat_export], rax
  "\x58" # pop rax

buildSimpleHook(
  QuestHook,
  @[("cord_struct", 4)],
  4,
  ".........\xF3\x0F\x11\x45\xE0.........\xF3\x0F\x11\x4D\xE4.........\xF3\x0F\x11\x45\xE8\x48",
  "\xF3\x41\x0F\x10\x86\xFC\x0C\x00\x00"
):
  "\x50" & # push rcx
  "\x49\x8D\x86\xFC\x0C\x00\x00" & # lea rcx,[r14+CFC]
  "\x48\xA3" & exports[0][1].toBytes().toString() & # mov [export],rcx
  "\x58" # pop rcx

buildSimpleHook(
  DuelHook,
  @[("current_duel_addr", 8)],
  0,
  "\x48\x89...\x48\x89...\x48\x89...\x89\x4C",
  "\x48\x89\x5C\x24\x58"
):
  "\x50" & # push rax
  "\x49\x8B\x07" & # mov rax,[r15]
  "\x48\xA3" & exports[0][1].toBytes().toString() & # mov [current_duel],rax
  "\x58" # pop rax

method posthook*(self: DuelHook) =
  let
    block_size = 256
    block_bytes = self.memory_handler.readBytes(self.jump_address - block_size, block_size)
  
  let found = block_bytes.find(re"\x7E.\xE8....\xE9")
  if found == -1:
    discard # TODO: Warn user
  else:
    let offset = block_size - found
    self.export_addrs["loglevel"] = self.jump_address - offset
    self.memory_handler.writeBytes(self.export_addrs["loglevel"], "\xEB")

method unhook*(self: DuelHook) =
  if "loglevel" in self.export_addrs:
    self.memory_handler.writeBytes(self.export_addrs["loglevel"], "\x7E")
    self.export_addrs.del("loglevel")
  procCall SimpleHook(self).unhook()

buildSimpleHook(
  ClientHook,
  @[("current_client_addr", 8)],
  2,
  "\x48......\x48\x8B\x7C\x24\x40\x48\x85\xFF\x74\x29\x8B\xC6\xF0\x0F\xC1\x47\x08\x83\xF8\x01\x75\x1D\x48\x8B\x07\x48\x8B\xCF\xFF\x50\x08\xF0\x0F\xC1\x77\x0C",
  "\x48\x8B\x9B\xB8\x01\x00\x00"
):
  "\x50" & # push rax
  "\x48\x8B\xC7" & # mov rax,rdi
  "\x48\xA3" & exports[0][1].toBytes().toString() & # mov [current_client], rax
  "\x58" # pop rax

buildSimpleHook(
  RootWindowHook,
  @[("current_root_window_addr", 8)],
  2,
  ".......\x48\x8B\x01.......\xFF\x50\x70\x84",
  "\x49\x8B\x8F\xD8\x00\x00\x00"
):
  "\x50" & # push rax
  "\x49\x8B\x87\xD8\x00\x00\x00" & # mov rax,[r15+D8]
  "\x48\xA3" & exports[0][1].toBytes().toString() & # mov [current_root_window_addr], rax
  "\x58" # pop rax

buildSimpleHook(
  RenderContextHook,
  @[("current_render_context_addr", 8)],
  4,
  "..................\xF3\x41\x0F\x10\x28\xF3\x0F\x10\x56\x04\x48\x63\xC1",
  "\xF3\x44\x0F\x10\x8B\x98\x00\x00\x00"
):
  "\x50" & # push rax
  "\x48\x89\xd8" & # mov rax,rbx
  "\x48\xA3" & exports[0][1].toBytes().toString() & # mov [current_ui_scale_addr],rax
  "\x58" # pop rax
