class_name AttachPoint
extends Resource

## Authoring-time attachment target. The evaluator still reads resolved
## SocketDef snapshots; this resource tells the editor/generator what is legal.

@export var id: StringName
@export var local_pose := Transform3D.IDENTITY
@export var hinge_axis := Vector3.ZERO
@export var accepts: Array[StringName] = []
@export var capacity := 1


func accepts_tags(child_tags: Array[StringName]) -> bool:
	if accepts.is_empty():
		return true
	for t in child_tags:
		if accepts.has(t):
			return true
	return false
