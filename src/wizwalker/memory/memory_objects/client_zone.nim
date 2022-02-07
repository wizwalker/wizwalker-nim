include common_imports

type ClientZone* = ref object of PropertyClass

buildReadWriteBuilders(ClientZone)

buildValueReadWrite(zoneId, ByteAddress, 72)
buildStringReadWrite(zoneName, 88)
