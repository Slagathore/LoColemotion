class_name WeaponDef
extends Resource

## Per-part weapon anatomy. Tags still make parts searchable in the editor, but
## this resource is the combat contract for damage type and secondary effects.

@export var kind: StringName = &"bludgeon"     # blade | stinger | bludgeon | claw | spike
@export var sharpness: float = 0.0             # cutting efficiency
@export var penetration: float = 0.0           # armor/vital puncture efficiency
@export var impact_multiplier: float = 1.0     # blunt/contact energy multiplier
@export var bleed: float = 0.0                 # reported secondary bleed severity
@export var venom: float = 0.0                 # reported secondary venom severity
@export var reach: float = 0.0                 # meters of effective protrusion/reach
