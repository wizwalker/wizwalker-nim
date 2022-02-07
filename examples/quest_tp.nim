import std/asyncdispatch
import std/tables

import ../src/wizwalker/client
import ../src/wizwalker/client_handler
import ../src/wizwalker/hotkey
import ../src/wizwalker/constants
import ../src/wizwalker/memory/memory_objects/quest_position

proc main() {.async.} =
  var
    client_handler = initClientHandler()
    c {.global.} = client_handler.getNewClients()[0]

  try:
    await c.activateHooks(wait_for_ready = false)

    proc handleQuestTpHotkey() {.async.} =
      await c.teleport(c.quest_position.position())

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
    client_handler.close()

waitFor main()
