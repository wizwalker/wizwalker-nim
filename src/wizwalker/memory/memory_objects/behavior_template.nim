include common_imports

type BehaviorTemplate* = ref object of PropertyClass

buildReadWriteBuilders(BehaviorTemplate)

buildStringReadWrite(behaviorName, 72)
