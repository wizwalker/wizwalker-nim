import std/asyncdispatch
import std/tables
import std/strformat

import ../src/wizwalker/client
import ../src/wizwalker/client_handler
import ../src/wizwalker/memory/instance_finder

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
    client_handler.close()

waitFor main()
