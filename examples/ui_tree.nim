import std/asyncdispatch
import std/tables

import ../src/wizwalker_nim/client
import ../src/wizwalker_nim/client_handler
import ../src/wizwalker_nim/hotkey
import ../src/wizwalker_nim/constants
import ../src/wizwalker_nim/memory/memory_objects/window
import ../src/wizwalker_nim/memory/handler

import times

proc main() {.async.} =
  var
    client_handler = initClientHandler()
    c {.global.} = client_handler.getNewClients()[0]

  try:
    await c.hook_handler.activateRootWindowHook()

    c.root_window.debugPrintUITree()

  finally:
    echo "Closing"
    await client_handler.close()

waitFor main()
