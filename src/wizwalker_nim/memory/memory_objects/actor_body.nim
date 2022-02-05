include common_imports

type
  ActorBody* = ref object of PropertyClass
  CurrentActorBody* = ref object of ActorBody

method readBaseAddress*(self: CurrentActorBody): ByteAddress =
  ## Read this objects starting address
  result = self.hook_handler.readCurrentPlayerHookBase()

buildReadWriteBuilders(ActorBody)

buildXYZReadWrite(position, 88)
buildValueReadWrite(pitch, float32, 100)
buildValueReadWrite(roll, float32, 104)
buildValueReadWrite(yaw, float32, 108)
buildValueReadWrite(height, float32, 132)
buildValueReadWrite(scale, float32, 112)
buildValueReadWrite(moduleUpdateScheduled, bool, 136)
