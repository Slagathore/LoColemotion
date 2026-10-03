class_name ActuatorHint
extends Resource

## Problem 2 (actuation/probe) will subtype this. Present but unused now — a named home for
## pose/actuation data so it never has to retrofit the genome later.

@export var hint_type: StringName
@export var params:    Dictionary
