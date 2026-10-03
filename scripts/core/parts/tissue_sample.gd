class_name TissueSample
extends Resource

## One entry per region inside a PhysicsDescriptor: the integrated contribution of a
## single tissue region to the part's measured physics.

@export var region_name:     StringName
@export var solid_class:     StringName
@export var cavity_function: StringName
@export var volume:          float
@export var surface_area:    float
@export var mass:            float
@export var cavity_volume:   float = 0.0
