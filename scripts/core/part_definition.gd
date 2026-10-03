class_name PartDefinition
extends Resource

## A part's authored shape + physical properties. SACRED: the evaluator treats
## these as ground truth (never mutates them). Promoted from an inner class of
## CharacteristicsEvaluator in Tier 1 so parts can be authored and saved as .tres.

@export var part_type: StringName = &"box"   # box|sphere|cylinder|capsule (extensible)
@export var density: float = 1000.0          # kg/unit³ — authored, sacred
@export var extents: Vector3 = Vector3.ONE   # half-extents at scale 1.0
@export var centroid_offset: Vector3 = Vector3.ZERO   # part CoM in local frame
