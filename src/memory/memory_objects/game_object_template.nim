include common_imports
import behavior_template
import wiz_enums

type WizGameObjectTemplate* = ref object of PropertyClass

proc behaviors*(self: WizGameObjectTemplate): seq[BehaviorTemplate] =
  ## Gets the behaviors of the object template
  for address in self.readDynamicVectorFromOffset(72, ByteAddress):
    if address != 0:
      result.add(self.createDynamicMemoryObject(BehaviorTemplate, address))

buildReadWriteBuilders(WizGameObjectTemplate)

buildStringReadWrite(objectName, 96)
buildValueReadWrite(templateId, uint32, 128)
buildValueReadWrite(visualId, uint32, 132)
buildStringReadWrite(adjectiveList, 248)
buildValueReadWrite(exemptFromAoi, bool, 240)
buildStringReadWrite(displayName, 168)
buildStringReadWrite(description, 136)

buildEnumReadWrite(objectType, ObjectType, 200)

buildStringReadWrite(icon, 208)
buildStringReadWrite(lootTable, 280)
buildStringReadWrite(deathParticles, 296)
buildStringReadWrite(deathSound, 328)
buildStringReadWrite(hitSound, 360)
buildStringReadWrite(castSound, 392)
buildStringReadWrite(aggroSound, 424)
buildStringReadWrite(primarySchoolName, 456)
buildStringReadWrite(locationPreference, 488)
