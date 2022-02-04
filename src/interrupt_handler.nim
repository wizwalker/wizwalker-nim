## Module used to handle console interrupts.
## You normally don't want to use this directly, as ClientHandler registers a default handler that raises an exception.
## A reason to use it though would be to get a customized, graceful shutdown.

import asyncdispatch
import threadpool
import os
import winim

proc getch(): cint {.header: "<conio.h>", importc: "_getch".}

var
  is_running_interrupt_loop {.global.} = false
  interrupt_callbacks {.global.}: seq[proc (sig: int)]
  interrupt_channel {.global.}: Channel[int]

proc consoleInterruptThread() =
  while true:
    if getch() == 3:
      interrupt_channel.send(3)

proc consoleInterruptDispatcher() {.async.} =
  while true: 
    let cur = interrupt_channel.tryRecv()
    if cur[0]:
      for cb in interrupt_callbacks:
        cb(cur[1])
    await sleepAsync(50)

proc startConsoleInterruptLoop*() =
  ## Starts the console interrupt loop, meaning the console thread and an async dispatcher on the current thread.
  if not is_running_interrupt_loop:
    is_running_interrupt_loop = true
    var dw_mode: int32
    GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), addr(dw_mode))
    dw_mode = dw_mode and (not ENABLE_PROCESSED_INPUT)
    SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), dw_mode)

    interrupt_channel.open()

    spawn consoleInterruptThread()
    asyncCheck consoleInterruptDispatcher()

proc registerInterruptHandler*(callback: proc (sig: int)) =
  ## Registers a callback that can deal with console interrupts
  interrupt_callbacks.add(callback)

template registerInterruptHandler*(body: untyped) =
  ## Helper to turn body into a handler proc before registering
  proc handler(sig: int) =
    body
  registerInterruptHandler(handler)