import std/tables
import std/marshal
import std/[strformat, strutils]
import std/encodings

import wad

type
  WizFileSystem = ref object # not public because this is a global
    wad_index: Table[string, (WadRef, Table[string, WadFileInfo])] # Table[wad_name, (wad_handle, Table[file_name, info])]
    value_cache: Table[string, string] # Table[name, bytes]

var global_wiz_file_system* {.global.} = WizFileSystem()

proc loadWad*(self: WizFileSystem, wad_name: string) = 
  ## Load a a wad into the wad index
  if not self.wad_index.contains(wad_name):
    var
      handle = wadFromGameData(wad_name)
      info: Table[string, WadFileInfo] 
    for x in handle.infoList():
      info[x.name] = x
    self.wad_index[wad_name] = (handle, info)

proc cacheTrivialValue[T](self: WizFileSystem, path: string, val: T) =
  var bytes = newString(sizeof(T))
  cast[ptr T](addr bytes[0])[] = val
  self.value_cache[path] = bytes

proc readFile*(self: WizFileSystem, wad_name: string, file_name: string): string =
  ## Read a file contained in a wad
  self.loadWad(wad_name)
  self.wad_index[wad_name][0].read(file_name)

proc readLangFile*(self: WizFileSystem, file_name: string, code_key: bool = true): Table[string, string] =
  ## Load a lang file from Root.wad
  let
    contents = self.readFile("Root", file_name).convert("utf-8", "utf-16")
    lines = contents.splitLines()
    header = lines[0]

  var i = 1
  while i + 3 < lines.len():
    let
      code = lines[i+0].strip()
      val = lines[i+2].strip()

    if code_key:
      result[code] = val
    else:
      result[val] = code

    i += 3

template checkTrivialCache(self: WizFileSystem, path: string, T: untyped) =
  if path in self.value_cache:
    return cast[ptr T](addr self.value_cache[path][0])[]

proc makeCacheKey*[T](t: typedesc[T], wad, file_path, val_name: string): string =
  ## Build a cache key from parts
  &"{wad}-.-{file_path}-.-{val_name}-.-{$T}"

proc makeLangKey*(file_name, val: string): string =
  ## Builds a cache key from things required for lang keys
  makeCacheKey(string, "Root", &"Locale/English/{file_name}.lang", val)

proc getTrivialValue*[T](self: WizFileSystem, t: typedesc[T], wad, file_path, val_name: string): T =
  ## Gets easy to understand (for the computer) values from files
  self.loadWad(wad)
  let key = makeCacheKey(T, wad, file_path, val_name)
  self.checkTrivialCache(key, T)
  let ext = file_path.split(".")[^1]
  case ext
  of "lang":
    var lang = self.readLangFile(file_path)
    if not lang.contains(val_name):
      lang = self.readLangFile(file_path, code_key=false)
    if not lang.contains(val_name):
      raise newException(ValueError, &"Could not find lang key {val_name}") 
    self.cacheTrivialValue(key, lang[val_name])
    return lang[val_name]
  else:
    raise newException(ValueError, &"Unsupported file type: {ext}")

proc getTrivialValue*[T](self: WizFileSystem, t: typedesc[T], key: string): T =
  ## Helper to make dealing with key builders easier
  let
    parts = key.split("-.-")
    wad = parts[0]
    file_path = parts[1]
    val_name = parts[2]
  self.getTrivialValue(T, wad, file_path, val_name)

proc getLangValue*(self: WizFileSystem, file_name: string, code: string): string =
  ## Get value from a long file. Key/text agnostic
  self.getTrivialValue(string, makeLangKey(file_name, code)) # Less efficient if code and value are swapped



when isMainModule:
  let a = global_wiz_file_system.getLangValue("Items", "00000004")
  let b = global_wiz_file_system.getLangValue("Items", a)
  echo a
  echo b

  echo global_wiz_file_system.getLangValue("Items", b)
  echo global_wiz_file_system.getLangValue("Items", a)
