include common_imports

type
  RenderContext* = ref object of MemoryObject
  CurrentRenderContext* = ref object of RenderContext

proc readBaseAddress*(self: CurrentRenderContext): ByteAddress =
  self.hook_handler.readCurrentRenderContextHookBase()

proc uiScale*(self: RenderContext): float32 =
  self.readValueFromOffset(152, float32)
