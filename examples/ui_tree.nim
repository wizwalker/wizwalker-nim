import std/asyncdispatch

import ../src/wizwalker/client
import ../src/wizwalker/client_handler
import ../src/wizwalker/memory/memory_objects/window
import ../src/wizwalker/memory/handler

proc main() {.async.} =
  var
    client_handler = initClientHandler()
    c {.global.} = client_handler.getNewClients()[0]

  try:
    await c.hook_handler.activateRootWindowHook()

    c.root_window.debugPrintUITree()

  finally:
    echo "Closing"
    client_handler.close()

waitFor main()
