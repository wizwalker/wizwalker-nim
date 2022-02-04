include common_imports

type BehaviorTemplate* = ref object of PropertyClass

proc behaviorName*(self: BehaviorTemplate): string =
  ## Name of this behavior
  self.readStringFromOffset(72)

proc writeBehaviorName*(self: BehaviorTemplate, val: string) =
  ## Write a new name for behavior
  self.writeStringToOffset(72, val)
