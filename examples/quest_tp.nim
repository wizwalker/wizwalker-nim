import std/asyncdispatch
import std/tables

import ../src/wizwalker_nim/client
import ../src/wizwalker_nim/client_handler
import ../src/wizwalker_nim/hotkey
import ../src/wizwalker_nim/constants
import ../src/wizwalker_nim/memory/memory_objects/actor_body
import ../src/wizwalker_nim/memory/memory_objects/quest_position

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
