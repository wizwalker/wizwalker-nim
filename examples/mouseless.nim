import std/asyncdispatch

import ../src/wizwalker/client
import ../src/wizwalker/mouse_handler
import ../src/wizwalker/client_handler

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
    client_handler.close()

waitFor main()
