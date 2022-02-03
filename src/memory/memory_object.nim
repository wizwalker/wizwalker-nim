import strformat

import memory_handler

type
  MemoryObject* = ref object of RootObj
    base_address: ByteAddress
    memory_handler*: MemoryHandler

proc initMemoryObject*(self: MemoryObject, memory_handler: MemoryHandler, base_address: ByteAddress): MemoryObject =
  ## Creates a new MemoryObject instance
  if base_address == 0:
    # TODO: Confirm if this does what it should
    raise newException(ResourceExhaustedError, &"Dynamic object {$typeof(self)} passed 0 base address")

  self.base_address = base_address
  self.memory_handler = memory_handler

method `==`*(self: MemoryObject, other: MemoryObject): bool {.base.} =
  ## Helper for comparison
  self.base_address == other.base_address

method readBaseAddress*(self: MemoryObject): ByteAddress {.base.} =
  ## Gets the base address so Current* objects can work
  if self.base_address != -1:
    self.base_address
  else:
    quit "Only Current* objects can have a base_address of -1"

proc readValueFromOffset*[T](self: MemoryObject, offset: int, t: typedesc[T]): T =
  ## Read a value, offset from the base of the object. Does not work for containers
  self.memory_handler.read(self.readBaseAddress() + offset, T)

proc writeValueToOffset*[T](self: MemoryObject, offset: int, val: T) =
  ## Write a value, offset from the base of the object. Does not work for containers
  self.memory_handler.write(self.readBaseAddress() + offset, val)

proc readWideStringFromOffset*(self: MemoryObject, offset: int): string =
  ## Read a wide string from object at offset
  self.memory_handler.readWideString(self.readBaseAddress() + offset)

proc writeWideStringToOffset*(self: MemoryObject, offset: int, val: string) =
  ## Write a wide string to object at offset
  self.memory_handler.writeWideString(self.readBaseAddress() + offset, val)

proc readStringFromOffset*(self: MemoryObject, offset: int): string =
  ## Read a string from object offset
  self.memory_handler.readString(self.readBaseAddress() + offset)

proc writeStringToOffset*(self: MemoryObject, offset: int, val: string) =
  ## Write a string to object offset
  self.memory_handler.writeString(self.readBaseAddress() + offset, val)

proc readVectorFromOffset*[T](self: MemoryObject, offset: int, size: int, t: typedesc[T]): seq[T] =
  ## Read a vector from object offset
  self.memory_handler.readVector(self.readBaseAddress() + offset, size, t)

proc writeVectorToOffset*[T](self: MemoryObject, offset: int, val: seq[T]) =
  ## Write a vector to object offset
  self.memory_handler.writeVector(self.readBaseAddress() + offset, val)

proc readSharedVectorFromOffset*(self: MemoryObject, offset: int, max_count: int = 1000): seq[ByteAddress] =
  ## Read a shared vector from object offset
  self.memory_handler.readSharedVector(self.readBaseAddress() + offset, max_count)

proc readDynamicVectorFromOffset*(self: MemoryObject, offset: int): seq[ByteAddress] =
  ## Read a dynamic (pointer) vector from object offset
  self.memory_handler.readDynamicVector(self.readBaseAddress() + offset)

proc readSharedLinkedListFromOffset*(self: MemoryObject, offset: int): seq[ByteAddress] =
  ## Read a shared linked list from object offset
  self.memory_handler.readSharedLinkedList(self.readBaseAddress() + offset)

proc readLinkedListFromOffset*(self: MemoryObject, offset: int): seq[ByteAddress] =
  ## Read a normal linked list from object offset
  self.memory_handler.readLinkedList(self.readBaseAddress() + offset)

# TODO: move this? (comment inherited from WW-py)
type PropertyClass* = ref object of MemoryObject

proc readTypeName*(self: PropertyClass): string =
  ## Read the type name of the PropertyClass object
  let
    vtable = self.readValueFromOffset(0, ByteAddress)
    class_name_getter = self.memory_handler.read(vtable, ByteAddress)
    maybe_jmp = self.memory_handler.readBytes(class_name_getter, 5)
    actual_class_name_getter =
      if maybe_jmp[0] == 0xE9.char: # jmp
        let offset = cast[ptr int32](unsafeAddr maybe_jmp[1])[]
        class_name_getter + offset + 5
      else:
        class_name_getter
    lea_instruction = actual_class_name_getter + 63
    lea_target = actual_class_name_getter + 66
    rip_offset = self.memory_handler.read(lea_target, int32)
    type_name_addr = lea_instruction + rip_offset + 7
  self.memory_handler.readNullTerminatedString(type_name_addr, 60)
