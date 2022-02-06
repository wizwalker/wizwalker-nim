import std/asyncdispatch
import std/tables
import std/strformat

import ../src/wizwalker_nim/client
import ../src/wizwalker_nim/client_handler
import ../src/wizwalker_nim/memory/instance_finder

import times

proc main() {.async.} =
  var
    client_handler = initClientHandler()
    c {.global.} = client_handler.getNewClients()[0]

  try:
    let finder = InstanceFinder(memory_handler : c.memory_handler, class_name : "ElasticCamController")
    let start = cpuTime()
    let instances = finder.getInstances()
    echo &"Getting camera instance took {cpuTime() - start}s"
    echo instances

  finally:
    echo "Closing"
    await client_handler.close()

waitFor main()
