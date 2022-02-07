import std/asyncdispatch
import std/tables

import ../src/wizwalker_nim/client
import ../src/wizwalker_nim/mouse_handler
import ../src/wizwalker_nim/client_handler
import ../src/wizwalker_nim/memory/memory_objects/window

proc main() {.async.} =
  var
    client_handler = initClientHandler()
    c {.global.} = client_handler.getNewClients()[0]

  try:
    await c.activateHooks(wait_for_ready=false)
    await c.mouse_handler.activateMouseless()    
    await c.mouse_handler.clickWindowWithName("cancelButton")
  finally:
    echo "Closing"
    await client_handler.close()

waitFor main()
