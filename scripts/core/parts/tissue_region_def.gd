class_name TissueRegionDef
extends Resource

## One per Blender material slot. Maps a slot to a biological tissue class plus an
## optional enclosed-cavity function. Open StringName registries (H1): new solid/cavity
## classes slot in without touching the evaluator.

@export var solid_class:     StringName = &"metabolic"   # metabolic | structural | inert (open)
@export var cavity_function: StringName = &"none"        # none | respiratory | buoyancy | … (open)
@export var density:         float = 1050.0              # kg/unit³ for this region
@export var wall_thickness:  float = 0.0                 # thin-walled cavities (lung, bladder)
@export var cavity_volume:   float = 0.0                 # explicit enclosed-void override


func _init(p_solid := &"metabolic", p_cavity := &"none", p_density := 1050.0) -> void:
	solid_class = p_solid
	cavity_function = p_cavity
	density = p_density
