import std/asyncdispatch

import ../src/client
import ../src/client_handler
import ../src/hotkey
import ../src/constants
import ../src/memory/memory_objects/actor_body
import ../src/memory/memory_objects/quest_position

proc main() {.async.} =
  var
    client_handler = initClientHandler()
    c {.global.} = client_handler.getNewClients()[0]

  try:
    await c.activateHooks(wait_for_ready = false)

    proc handleQuestTpHotkey() {.async.} =
      await c.teleport(c.quest_position.position(), move_after=false)

    let listener = HotkeyListener()
    listener.addHotkey(
      Keycode["Q"],
      handleQuestTpHotkey,
      { Modifier.SHIFT, Modifier.NOREPEAT }
    )

    listener.start()
    echo "Listener started"

    runForever()
  finally:
    echo "Closing"
    await client_handler.close()

waitFor main()
